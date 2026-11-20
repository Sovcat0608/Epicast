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
    'model': 'wan2.2-ti2v-5b-native', 'size': '640x608', 'num_frames': 49,
    'steps': 40, 'guidance': 5.5, 'fps': 16, 'seed': 509021,
    'prompt': (
        'Orthographic close-up of this exact isolated painted green leaf cluster, fixed camera. '
        'A soft breeze flows sideways. Each long leaf bends gently across its entire length, from '
        'the midrib through its broad middle and out to its tip. The upper blade leads, its neighbors '
        'follow almost immediately. The lower-left stem remains attached at precisely the same point. '
        'One smooth slow outward bow then an easy return. Keep all original leaf shapes, painted veins, '
        'clean contours, individual leaf count, warm yellow-green highlights and the flat muted violet background.'
    ),
    'negative_prompt': (
        'rigid rotation, tip flicker, strong wind, folding, twitch, camera movement, zoom, new leaves, '
        'background movement, repaint, jitter, perspective swing, particles'
    ),
}


def main():
    config = json.loads((LOCAL_LLM/'config.json').read_text(encoding='utf-8-sig'))
    headers = {'Authorization': 'Bearer '+config['apiKey']}

    def request(url, data=None, extra=None):
        with urlopen(Request(url, data=data, headers=headers | (extra or {})), timeout=15) as response:
            return response.read()

    stronger = '--stronger' in sys.argv
    if stronger:
        sys.argv.remove('--stronger')
        SETTINGS.update(seed=509022, num_frames=33, guidance=6, prompt=(
            'Fixed camera on the same hand-painted golden green foliage sprite. A single directional '
            'gust arrives slowly from left to right and bends every full leaf blade to the right. '
            'The midribs and broad surfaces visibly bow over together, including the big upper leaf, '
            'while the short lower-left stems stay planted. Each blade is pushed over in a slightly '
            'different arc. The breeze lifts the broad middles, then the tips follow. Show the strongest '
            'bow near the end. Preserve leaf silhouettes and texture, original matte background, and lighting.'
        ))
    wave = '--wave' in sys.argv
    if wave:
        sys.argv.remove('--wave')
        SETTINGS.update(seed=509024, num_frames=65, guidance=6, prompt=(
            'Static macro view of the exact painted foliage on a solid slate blue field. A single '
            'sideways breeze ripples through the stationary branch. At first the big upper leaf '
            'bows gently across its whole midrib: its broad middle leans first and its tapered '
            'end follows with a shallow C-shaped curl. In the same gust the middle leaf follows '
            'a little later, then the lower right blade. While the lower blade is still curling, '
            'the upper one softly unfurls. Visible bend across the interiors and midribs, with a '
            'small elastic follow-through of the tips. The stem at lower left never changes its '
            'attachment. Relax back to the original pose. Study of smooth, organic movement. '
            'Retain the identical hand-painted gold green surfaces, serration, veins and blade count.'
        ), negative_prompt=(
            'rigid cluster swing, pendulum, all tips synchronized, stiff blades, sharp kink, severe '
            'fold, flickering highlights, camera movement, zoom, detached pieces, background motion, new leaves'
        ))
    output = HERE/'wave' if wave else HERE
    prefix = 'wan-bend' if stronger else 'wan'
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

