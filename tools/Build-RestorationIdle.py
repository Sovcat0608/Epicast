"""Register the original desktop idle poses for the shared Lanczos2 and CAS bake."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts/restoration-idle-build"
FRAME = (660, 880)
STILL = ROOT / "Media/DruidRestorationCASSize660.tga"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def alpha_union(frames):
    alpha = np.maximum.reduce([np.asarray(frame.getchannel("A")) for frame in frames])
    return Image.fromarray(alpha).getbbox()


def target_size():
    # The static runtime texture is POT-padded. Its actual registered canvas is 660x880.
    still = Image.open(STILL).convert("RGBA").crop((0, 0, 660, 880))
    alpha = still.getchannel("A").point(lambda value: 255 if value >= 8 else 0)
    return alpha.getbbox()


def register(frames, bounds, old_bounds):
    x0, y0, x1, y1 = bounds
    a0, b0, a1, b1 = old_bounds
    scale = min((a1-a0)/(x1-x0), (b1-b0)/(y1-y0))
    ox = (a0+a1)/2 - scale*(x0+x1)/2
    oy = (b0+b1)/2 - scale*(y0+y1)/2
    to_source = (1/scale, 0, -ox/scale, 0, 1/scale, -oy/scale)
    cels = [frame.convert("RGBa").transform(
        FRAME, Image.Transform.AFFINE, to_source, Image.Resampling.BICUBIC,
    ).convert("RGBA") for frame in frames]
    u0, v0, u1, v1 = alpha_union(cels)
    # Transparent edge pixels are the sampling guard between atlas cells.
    assert u0 >= 3 and v0 >= 3 and u1 <= FRAME[0]-3 and v1 <= FRAME[1]-3
    return cels, [scale, ox, oy], [u0, v0, u1, v1]


def build():
    info = json.loads((CAPTURE/"capture.json").read_text(encoding="utf-8"))
    assert (info["fps"], info["period"]) == (8, 4000)
    paths = [CAPTURE / f"pose-{index:02}.png" for index in range(32)]
    frames = [Image.open(filename).convert("RGBA") for filename in paths]
    assert all(im.size == tuple(info["canvas"]) for im in frames)
    bounds, old_bounds = alpha_union(frames), target_size()
    cels, transform, crop = register(frames, bounds, old_bounds)
    assert len({sha256(frame.tobytes()) for frame in cels}) == len(cels)
    for index, cel in enumerate(cels):
        (CAPTURE/f"registered-{index:02}.bgra").write_bytes(cel.tobytes("raw", "BGRA"))
    evidence = dict(preview=info, preview_alpha_union=bounds, previous_static_bounds=old_bounds,
                    source_size=FRAME, frame_count=len(cels), transform=transform,
                    registered_alpha_union=crop, input_sha256=[sha256(p.read_bytes()) for p in paths])
    (CAPTURE/"registration.json").write_text(
        json.dumps(evidence, indent=2)+"\n", encoding="utf-8", newline="\n",
    )
    subprocess.run(["node", str(ROOT/"tools/Build-RestorationIdle.cjs"), str(CAPTURE.resolve())],
                   cwd=ROOT, check=True)


if __name__ == "__main__":
    build()
