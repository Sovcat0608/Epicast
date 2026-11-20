"""Build an evenly eased, cyclic idle from the quiet opening of the Griffin render."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "griffin-delay"))
from retime import H, W, blade_offsets


def build():
    sheet = Image.open(HERE / "registered.webp").convert("RGBA")
    poses = []
    for k in range(1, 6):
        cel = sheet.crop((k*W, 0, (k+1)*W, H))
        poses.append(np.asarray(cel.convert("RGBa"), dtype=np.float32))

    # Parameterize the sweep by how far the paint moves between drawings.
    # This prevents a large source-frame interval from creating a fast beat.
    steps = [np.abs(b-a).mean() for a,b in zip(poses, poses[1:])]
    distance = np.r_[0, np.cumsum(steps)]
    delay = blade_offsets() * .75
    atlas = Image.new("RGBA", (4*W, 4*H))
    for beat in range(16):
        phase = (beat-delay) * (2*np.pi/16)
        position = np.interp((1-np.cos(phase))*.5*distance[-1], distance, np.arange(len(poses)))
        # Interpolate neighboring painted exposures in premultiplied alpha.
        # The same continuous phase spans the last and first playback beats.
        pixels = np.zeros_like(poses[0])
        for i, pose in enumerate(poses):
            weight = np.maximum(1 - np.abs(position-i), 0)
            pixels += pose * weight[:,:,None]
        cel = Image.frombytes("RGBa", (W,H), np.rint(pixels).astype("uint8").tobytes()).convert("RGBA")
        atlas.paste(cel, (beat%4*W, beat//4*H))
    atlas.save(HERE / "quiet.webp", lossless=True)


if __name__ == "__main__":
    build()
