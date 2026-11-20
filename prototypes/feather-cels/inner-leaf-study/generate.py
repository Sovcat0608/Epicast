"""Queue the three Restoration motion references using LocalLLM."""
import hashlib
import json
import sys
import time
import uuid
from pathlib import Path
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parent
MASTER = ROOT.parents[2]/"concepts/restoration-frame146/registered"
API = "http://127.0.0.1:9092/v1/videos/jobs"
DEFAULT = dict(model="wan2.2-ti2v-5b-native", fps=16, steps=36, guidance=6)
PROMPT = (
    "Fixed front-facing close-up of this exact hand-painted yellow-green leaf fan on a flat slate-blue matte. "
    "In a gentle breeze the long leaf blades bow in a single clean shallow curve through their midribs. "
    "The broad surfaces, paint grain, veins, serrations and silhouette keep their shape. "
    "The short stem remains planted. The fan relaxes back to its original pose."
)
STUDIES = {
    "left":dict(size="512x512", num_frames=33, seed=509030,
                prompt=PROMPT+" The fixed attachment is at the upper left."),
    "right":dict(size="512x512", num_frames=33, seed=509031,
                 prompt=PROMPT+" The fixed attachment is at the upper right."),
}
for settings in STUDIES.values():
    settings["negative_prompt"] = (
        "mesh wobble, heat-wave distortion, fluttering serrations, moving camera, moving stem, "
        "extra leaves, changing texture, changing light, lens zoom"
    )


def make_inputs():
    for side, index in [("left",12),("right",13)]:
        art=Image.open(MASTER/f"{index:02}-paint.png").convert("RGBA")
        plate=Image.new("RGBA",(512,512),"#394b60")
        width,height=art.size
        plate.alpha_composite(art.resize((2*width,2*height),Image.Resampling.LANCZOS),(81,85))
        plate.convert("RGB").save(ROOT/(side+"-input.png"))


def main():
    cfg = json.loads(Path("E:/Local LLM/config.json").read_text(encoding="utf-8-sig"))
    auth = {"Authorization":"Bearer "+cfg["apiKey"]}

    def request(url, data=None, headers=None):
        with urlopen(Request(url,data=data,headers=auth|(headers or {})),timeout=15) as response:
            return response.read()

    manifest = ROOT/"batch.json"
    if "--resume" in sys.argv:
        batch = json.loads(manifest.read_text())
    else:
        make_inputs()
        batch = {}
        for name, options in STUDIES.items():
            params = DEFAULT|options
            boundary = uuid.uuid4().hex
            path = ROOT/(name+"-input.png")
            image = path.read_bytes()
            body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
                            for key,value in params.items())
            body += (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}.png"\r\n'
                     f'Content-Type: image/png\r\n\r\n').encode()+image+f'\r\n--{boundary}--\r\n'.encode()
            job = json.loads(request(API,body,{"Content-Type":f"multipart/form-data; boundary={boundary}"}))
            batch[name] = {"id":job["id"],"input_sha256":hashlib.sha256(image).hexdigest(),"request":params}
            manifest.write_text(json.dumps(batch,indent=2)+"\n")
            print(name,job["id"],job["state"],flush=True)
    prior = {}
    pending = dict(batch)
    for _ in range(360):
        for name, record in list(pending.items()):
            endpoint = API+"/"+record["id"]
            job = json.loads(request(endpoint))
            state = job["state"]
            if prior.get(name)!=state:
                print(name,state,flush=True)
                prior[name] = state
            if state == "succeeded":
                blob = request(endpoint+"/artifact")
                assert hashlib.sha256(blob).hexdigest()==job["artifact_sha256"]
                (ROOT/(name+".mp4")).write_bytes(blob)
            if state not in {"running","queued"}:
                (ROOT/(name+"-job.json")).write_text(json.dumps(job,indent=2)+"\n")
                del pending[name]
        if not pending:
            if any(state!="succeeded" for state in prior.values()):
                raise SystemExit(str(prior))
            return
        time.sleep(2)
    raise SystemExit("Batch still active. Resume using --resume.")


if __name__=="__main__":
    main()

