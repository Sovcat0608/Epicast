"""Remove the whole-fan swing from the rendered drawings around the painted stem."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
W, H = 376, 400
PIVOT = (309, 54)


def stem(cel):
    y, x = np.where(np.asarray(cel.getchannel("A")) > 128)
    # Restrict to the stem end. A moving blade can reach above it farther left.
    end = x > 288
    row = int(y[end].min() + 2)
    return int(np.median(x[end & (abs(y-row) <= 1)]) + .5), row


def build(directory=HERE):
    source = Image.open(directory / "result/shoulder-1.png").convert("RGBA")
    atlas = Image.new("RGBA", source.size)
    assert source.size == (7*W, 7*H)
    for i in range(49):
        x, y = i % 7 * W, i // 7 * H
        cel = source.crop((x, y, x+W, y+H))
        px, py = stem(cel)
        registered = Image.new("RGBA", cel.size)
        registered.paste(cel, (PIVOT[0]-px, PIVOT[1]-py))
        alpha = registered.getchannel("A")
        if i == 0:
            rest = np.asarray(alpha) > 128
        def mismatch(degrees):
            rotated = alpha.rotate(float(degrees), Image.Resampling.BILINEAR, center=PIVOT)
            return np.count_nonzero((np.asarray(rotated) > 128) != rest)
        coarse = min(range(-15, 16), key=mismatch)
        angle = min(np.arange(coarse-1, coarse+1.01, .1), key=mismatch)
        aligned = registered.convert("RGBa").rotate(float(angle), Image.Resampling.BICUBIC, center=PIVOT)
        atlas.paste(aligned.convert("RGBA"), (x,y))
    atlas.save(directory / "registered.webp", lossless=True)


if __name__ == "__main__":
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else HERE)
