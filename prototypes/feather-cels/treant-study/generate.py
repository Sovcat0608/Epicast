from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import base64, hashlib, json, sys, uuid

root=Path('treant-study')
config=json.loads(Path('E:/Local LLM/config.json').read_text(encoding='utf-8-sig'))
settings={
    'model':'wan2.2-ti2v-5b-native','size':'608x704','num_frames':49,'steps':40,
    'guidance':5,'fps':16,'seed':48617,
    'prompt':('Locked front camera. Animate this exact isolated hand-painted carved wooden treant face on a flat blue gray background. '
              'An extremely subtle slow inhale. The whole face tips up just a few degrees while the lower jaw goes down a few pixels, '
              'making the existing dark mouth slightly wider open. One gentle continuous motion, not talking. '
              'The face remains centered with its brow and eyes aligned. Preserve every original angular wood facet, glowing green eyes, '
              'shape of the nose, chin, and painted highlights. Keep color and illumination constant.'),
    'negative_prompt':('camera movement, zoom, yaw, roll, talking, teeth added, tongue, blinking, eye movement, glow changing, '
                       'photorealism, repaint, new texture, morphing silhouette, exaggerated action, particles, smoke, detailed background'),
}
trial = sys.argv[1] if len(sys.argv) > 1 else 'wan'
if trial == 'wan-breath':
    settings.update(seed=84321, num_frames=33, guidance=6, prompt=(
        'Front-facing game sprite, static camera. A carved wooden treant face comes to life. '
        'Over two seconds its wooden lower jaw slowly hinges downward, making the existing dark open mouth visibly taller. '
        'The nose and the glowing green eyes lift as its head leans back for a deep, deliberate inhale. '
        'Hold the inhale at the end of the shot. Individual faceted bark plates smoothly articulate. '
        'The outer cheeks stay aligned, and the blue gray background and lighting stay constant.'),
        negative_prompt='sideways turn, zoom, cuts, speech, added objects, smoke, text, changing background, new colors')
boundary=uuid.uuid4().hex
raw=(root/'input.png').read_bytes()
body=b''.join(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode() for key,value in settings.items())
body+=f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="input.png"\r\nContent-Type: image/png\r\n\r\n'.encode()+raw+f'\r\n--{boundary}--\r\n'.encode()
request=Request('http://127.0.0.1:9092/v1/videos/generations',data=body,headers={'Content-Type':f'multipart/form-data; boundary={boundary}','Authorization':'Bearer '+config['apiKey']})
(root/(trial+'.json')).write_text(json.dumps({'request':settings,'inputSha256':hashlib.sha256(raw).hexdigest()},indent=2))
print('Submitting native 5B treant generation',flush=True)
try:
    with urlopen(request,timeout=1800) as response:
        result=json.load(response)
except HTTPError as error:
    raise SystemExit(f'Video API HTTP {error.code}: {error.read().decode()}')
(root/(trial+'.mp4')).write_bytes(base64.b64decode(result.pop('data')[0]['b64_json'],validate=True))
manifest=json.loads((root/(trial+'.json')).read_text())
manifest['result']=result
(root/(trial+'.json')).write_text(json.dumps(manifest,indent=2))
print(json.dumps(result),flush=True)
