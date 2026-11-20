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
 "model":"wan2.2-ti2v-5b-native","size":"640x512","fps":16,"num_frames":65,"steps":36,"guidance":6,"seed":509032,
 "prompt":("Orthographic close-up of the same two painted purple wraps on stationary wood. The cloth is fastened "
           "tightly around each branch, with a long worn end hanging down like a flag. A soft slow breeze makes "
           "that full free end curl gently, as one smooth ripple travels from its attachment to its frayed tip. "
           "The tip catches the breeze, follows through softly and settles. Left and right move at slightly different "
           "times. The wood, wrapped upper folds, crescent, and tree print stay perfectly still. Keep the painted "
           "texture, stitching, torn shape, purple folds and neutral slate-blue background."),
 "negative_prompt":"camera movement, rearranged symbols, loose wrap, extra cloth, color shift, rapid flutter, smoke",
}


def render(output, prefix, settings, job_id=None, image_name="input.png"):
    config = json.loads((LOCAL_LLM/'config.json').read_text(encoding='utf-8-sig'))
    headers = {'Authorization': 'Bearer '+config['apiKey']}

    def request(url, data=None, extra=None):
        with urlopen(Request(url, data=data, headers=headers | (extra or {})), timeout=15) as response:
            return response.read()

    if job_id is None:
        image = (output/image_name).read_bytes()
        boundary = uuid.uuid4().hex
        body = b''.join(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
                        for key,value in settings.items())
        body += (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="input.png"\r\n'
                 f'Content-Type: image/png\r\n\r\n').encode() + image
        body += f'\r\n--{boundary}--\r\n'.encode()
        job = json.loads(request(API, body, {'Content-Type': f'multipart/form-data; boundary={boundary}'}))
        job_id = job['id']
        (output/(prefix+'-submission.json')).write_text(json.dumps({
            'id': job_id, 'input_sha256': hashlib.sha256(image).hexdigest(), 'request': settings,
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
            return job
        if state not in {'queued','running'}:
            raise SystemExit(job.get('error') or state)
        time.sleep(2)
    raise SystemExit('Polling stopped before the job finished. Resume with its ID.')


if __name__ == '__main__':
    render(HERE, "wan", SETTINGS, sys.argv[1] if len(sys.argv) > 1 else None)

