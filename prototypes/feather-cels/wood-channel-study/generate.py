"""Render a stationary wood-glyph light study on the local Wan queue."""
import argparse
from pathlib import Path
import sys

from PIL import Image, ImageFilter

from etchings import POSITIONS, mask

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path[:0] = [str(PREVIEW / "fabric-flag-study"), str(PREVIEW)]
from generate import render
from bake import MASTER

SIZE = (768, 512)


def build_input(filename, lit=False):
    board = Image.new("RGBA", SIZE, (42, 50, 56, 255))
    for side, pos in enumerate(POSITIONS):
        with Image.open(MASTER / "registered" / f"{4 + side:02d}-paint.png") as source:
            wood = source.convert("RGBA")
        etch = mask(wood.size, side)
        board.alpha_composite(wood, pos)
        if lit:
            for radius, color, opacity in ((7, (133, 193, 33), .90), (2.2, (188, 235, 62), .90)):
                halo = Image.new("RGBA", wood.size, color + (0,))
                halo.putalpha(etch.filter(ImageFilter.GaussianBlur(radius)).point(lambda a: round(a * opacity)))
                board.alpha_composite(halo, pos)
        light = Image.new("RGBA", wood.size, ((239, 255, 159) if lit else (169, 212, 77)) + (0,))
        light.putalpha(etch.filter(ImageFilter.GaussianBlur(.45)).point(lambda a: round(a * (.96 if lit else .26))))
        board.alpha_composite(light, pos)
    board.convert("RGB").save(HERE / filename)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("job_id", nargs="?")
    parser.add_argument("--lit", action="store_true")
    args = parser.parse_args()
    prefix = "wan-lit" if args.lit else "wan"
    filename = prefix + "-input.png"
    if not args.job_id:
        build_input(filename, args.lit)
    settings = {
        "model": "wan2.2-ti2v-5b-native", "size": "768x512", "fps": 16, "num_frames": 65,
        "steps": 38, "guidance": 6, "seed": 509289,
        "prompt": (
            "Locked orthographic camera, two fixed side-by-side painted wooden game-art panels. "
            "Only the dim yellow-green light already visible INSIDE the original four engraved zigzag marks changes. "
            "In the first second the existing hairline etchings ignite, bright light traveling along each original "
            "thin line until it fills in. For the middle two seconds they remain steadily lit with a very gentle "
            "pulse, pale green at their narrow cores and soft leaf green only next to the cuts. In the last "
            "second the light extinguishes into the existing grooves. Every wooden pixel, outline, chisel mark "
            "and seam keeps exactly the same position. Preserve the chunky hand-painted bark and plain slate backdrop."
        ),
        "negative_prompt": (
            "camera movement, zoom, moving wood, moving objects, particles, dust, sparks, smoke, "
            "flying fragments, new symbols, text, lightning in the air, background change, magical objects, repaint"
        ),
    }
    if args.lit:
        settings.update(num_frames=49, steps=32, seed=509321, prompt=(
            "Still orthographic close-up of two carved wooden game-art pieces. The four thin bright lime-green "
            "inscriptions are already illuminated. Light moves very gently along the thin lines, remaining "
            "confined to them, then fades in place like a lamp dimming until the incisions are dark. The wood "
            "itself stays still and camera-locked. Show the evening out of the lights and their soft green edges."
        ))
    render(HERE, prefix, settings, args.job_id, filename)
