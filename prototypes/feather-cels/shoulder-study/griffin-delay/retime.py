"""Stagger Griffin's registered blade drawings around their common stem."""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
W, H = 376, 400
SWEEP = [0, 1, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 1]


def transition(distance, width):
    t = np.clip(.5 + distance / width, 0, 1)
    return t*t*(3-2*t)


def blade_offsets():
    y, x = np.mgrid[:H, :W]
    # Follow the painted overlap under the upper blade and the seams between
    # hanging blades. Full blade interiors show a single Griffin drawing.
    upper_edge = np.interp(x, [65,115,166,202,244,275,303], [194,155,149,134,122,103,84])
    lower = transition(y-upper_edge, 12)
    long_edge = np.interp(y, [86,119,150,195,245,290], [297,262,228,206,182,166])
    long_blade = transition(long_edge-x, 14)
    rear_edge = np.interp(y, [87,125,160,207], [300,286,269,263])
    rear_blade = transition(x-rear_edge, 14)
    attachment = transition(np.hypot(x-309, y-54)-63, 48)
    # Rear, upper, middle, long: each follows the previous blade by one beat.
    return attachment * ((1-lower) + lower*(2 + long_blade - 2*rear_blade))


def build():
    source = Image.open(HERE / "registered.webp").convert("RGBA")
    poses = []
    for k in SWEEP:
        x, y = k % 7 * W, k // 7 * H
        cel = source.crop((x, y, x+W, y+H))
        poses.append(np.array(cel.convert("RGBa"), dtype=np.float32))
    offset = blade_offsets()
    atlas = Image.new("RGBA", (4*W, 4*H))
    for beat in range(16):
        pixels = np.zeros_like(poses[0])
        for delay in range(4):
            weight = np.maximum(1-np.abs(offset-delay), 0)[:,:,None]
            pixels += weight * poses[(beat-delay) % 16]
        cel = Image.frombytes("RGBa", (W,H), np.rint(pixels).astype("uint8").tobytes()).convert("RGBA")
        atlas.paste(cel, (beat%4*W, beat//4*H))
    atlas.save(HERE / "staggered.webp", lossless=True)


if __name__ == "__main__":
    build()
