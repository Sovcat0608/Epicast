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
STUDIES = {
    "treant": dict(size="608x704", num_frames=33, seed=509025,
        prompt=("Orthographic front view of the exact painted wooden treant. Its heavy carved eyebrows tighten into "
                "an angrier scowl. Its luminous green eyes brighten, with small concentrated light inside the sockets. "
                "It holds its mouth wide open, taking two quick, rhythmic breaths. The wooden lower jaw moves down and "
                "back up slightly on each breath. Stable forehead attachment, fixed camera, retain the existing bark "
                "shapes, carved planes, colors and solid blue-gray background."),
        negative_prompt="speech, added teeth, tongue, flashing light, eye beam, zoom, camera movement, rotation, smoke"),
    "vines": dict(size="640x640", num_frames=49, seed=509026,
        prompt=("Locked front view of the painted ornament. Two hanging green vine tendrils sway freely in a soft "
                "cross-breeze. The left curl swings first; the right vine responds a moment later and hangs a little "
                "heavier. The existing curls ease in separate phases, with their small ends trailing the sway. "
                "The center wood and upper vine attachments remain planted exactly. Preserve the original vines, "
                "texture, shape, and solid matte background."),
        negative_prompt="new vines, mirror-synchronized movement, violent wind, rotating wood, camera movement"),
    "fabric": dict(size="640x544", num_frames=49, seed=509028,
        prompt=("Two stationary carved wood boughs side by side. Each is wrapped in printed purple cloth. Keep wood, "
                "the tight wrap and the painted crescent and tree perfectly fixed. Only the frayed free hem at the "
                "bottom of each thick cloth lifts and relaxes in a soft wind. Small sequential ripples cross the "
                "worn triangular ends, softly curling the tips. The cloth moves as fabric with visible folds, "
                "retaining its cut edge, paint, color and strong broad highlights, on the solid blue-gray background."),
        negative_prompt="unwrapping, fabric replacement, moving symbols, stretching wood, camera movement, new banner"),
}


def make_inputs():
    vines = Image.open(MASTER/"03-paint.png").convert("RGBA")
    bough = Image.open(MASTER/"18-paint.png").convert("RGBA")
    plate=Image.new("RGBA",(640,640),"#314657")
    plate.alpha_composite(vines.resize((462,472),Image.Resampling.LANCZOS),(89,84))
    plate.convert("RGB").save(ROOT/"vines-input.png")
    plate=Image.new("RGBA",(640,544),"#314657")
    for rect,x in [((0,291,230,652),53),((583,291,817,652),352)]:
        cloth = bough.crop(rect)
        plate.alpha_composite(cloth.resize((235,370),Image.Resampling.LANCZOS),(x,83))
    plate.convert("RGB").save(ROOT/"fabric-input.png")


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
            path = ROOT.parent/"treant-study/input.png" if name=="treant" else ROOT/(name+"-input.png")
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

