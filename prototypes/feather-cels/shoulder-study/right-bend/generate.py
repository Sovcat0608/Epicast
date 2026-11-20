"""Submit and retrieve an Epicast leaf render over LocalLLM's async video API."""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import json
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
LOCAL_LLM = Path('E:/Local LLM')
API = 'http://127.0.0.1:9092/v1/videos/jobs'
SETTINGS = {
    "model":"wan2.2-ti2v-5b-native","size":"608x608","fps":16,"num_frames":49,
    "steps":36,"guidance":6,"seed":509029,
    "prompt":("Locked front-facing view of the exact hand-painted orange autumn leaf cluster on a slate-blue matte. "
              "The short stem at upper left stays fixed. A soft breeze gently bows the full length of the leaves "
              "into shallow arcs. The longest lower blade bends through its midrib first, then its end curls a little. "
              "The upper blades follow more softly before the fan settles to rest. Preserve the original length, width, "
              "veins, serrations, warm highlights and shadow."),
    "negative_prompt":"rigid fan rotation, camera movement, folding, wobbly veins, extra leaves, moving stem, heat haze",
}


def main():
    config = json.loads((LOCAL_LLM/'config.json').read_text(encoding='utf-8-sig'))
    headers = {'Authorization': 'Bearer '+config['apiKey']}

    def request(url, data=None, extra=None):
        with urlopen(Request(url, data=data, headers=headers | (extra or {})), timeout=15) as response:
            return response.read()

    output = HERE
    prefix = "wan"
    if len(sys.argv) > 1:
        job_id = sys.argv[1]
    else:
        image = (output/'input.png').read_bytes()
        boundary = uuid.uuid4().hex
        body = b''.join(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
                        for key,value in SETTINGS.items())
        body += (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="input.png"\r\n'
                 f'Content-Type: image/png\r\n\r\n').encode() + image
        body += f'\r\n--{boundary}--\r\n'.encode()
        job = json.loads(request(API, body, {'Content-Type': f'multipart/form-data; boundary={boundary}'}))
        job_id = job['id']
        (output/(prefix+'-submission.json')).write_text(json.dumps({
            'id': job_id, 'input_sha256': hashlib.sha256(image).hexdigest(), 'request': SETTINGS,
        }, indent=2))
    print(f'Local video job {job_id}', flush=True)
    previous = None
    for _ in range(1000):
        job = json.loads(request(f'{API}/{job_id}'))
        state = job['state']
        if state != previous:
            print(state,flush=True)
            previous=state
        if state == 'succeeded':
            artifact = request(f'{API}/{job_id}/artifact')
            assert hashlib.sha256(artifact).hexdigest() == job['artifact_sha256']
            (output/(prefix+'.mp4')).write_bytes(artifact)
            (output/(prefix+'-job.json')).write_text(json.dumps(job, indent=2))
            print(json.dumps(job['result']),flush=True)
            return
        if state not in {'queued','running'}:
            raise SystemExit(job.get('error') or state)
        time.sleep(2)
    raise SystemExit('Polling stopped before the job finished. Resume with its ID.')


if __name__ == '__main__':
    main()

