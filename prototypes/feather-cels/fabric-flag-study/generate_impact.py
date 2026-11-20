"""Ask the local Wan model for one reverse-hook cloth strike per banner."""
import argparse

from PIL import Image

from generate import render
from bake_flag import HERE, FRONT
from bake_batch import axes, registered_stack
from bake_impact import reverse_fold

OUTPUT = HERE / "wan-impact"
INPUTS = {
    "left": ((68, 545, 320, 400), 509137),
    "right": ((737, 545, 320, 400), 509139),
}
SIZE = (512, 640)


def build_input(side, slot, hook=False):
    paint = registered_stack(slot)[0][FRONT]
    if hook:
        index = 0 if side == "left" else 1
        x, y = axes(slot)
        paint, _ = reverse_fold(index, slot)(1, x, y, paint, Image.new("L", paint.size))
    background = Image.new("RGBA", paint.size, (51, 70, 82, 255))
    background.alpha_composite(paint)
    prefix = f"{side}-hook" if hook else side
    background.convert("RGB").resize(SIZE, Image.Resampling.LANCZOS).save(OUTPUT / f"{prefix}-input.png")


def request(side, seed, hook=False):
    glyph = "crescent moon" if side == "left" else "tree"
    settings = {
        "model": "wan2.2-ti2v-5b-native", "size": "512x640", "fps": 16,
        "num_frames": 49, "steps": 38, "guidance": 6, "seed": seed,
        "prompt": (
            f"Fixed orthographic close-up of one hand-painted purple cloth flag with a {glyph} on a still wooden "
            "branch, in a game sprite animation study. Show one forceful snap like the tip of a cracking cloth whip. "
            f"Only the lower free tail flicks outward toward screen {side}, then the last quarter of the tail "
            "flips back UP sharply into an open J-shaped hook. The very end points UP toward its own attachment, "
            "revealing a narrow darker violet underside along the curled hem. There is a visible air gap in the "
            "open hook between the lifted tip and the upper cloth. Achieve this curved silhouette early in the "
            "clip with one quick strike, then slowly unroll to the original hanging position. The top folds, "
            f"{glyph} print, wood and rope stay absolutely still. Preserve the frayed seams and bold stylized "
            "brushstrokes. Perfectly stationary camera and uniform blue-gray backdrop."
        ),
        "negative_prompt": (
            "side-to-side swinging, barely moving, elastic stretching, whole shape translating, flutter loop, "
            "extra flaps, curling inward toward the wood, nondescript wiggling, model redraw, shaky camera, "
            "zoom, blurred texture, changing glyph, new objects, sparks, glowing glyph, scenery"
        ),
    }
    if hook:
        settings.update(
            seed=seed + 29,
            prompt=(
                "A static orthographic game-art sprite study from this exact reference. Only the attached purple cloth "
                f"tip on screen {side} moves. Its short upturned fold progressively unfurls downward and ends in a "
                "relaxed pointed hang. One continuous release, preserving the purple textile, dark underside, and "
                f"gold-frayed edge from the first frame. The ivory {glyph}, upper purple fabric and all surrounding "
                "pixels remain frozen in place. Fixed image composition and solid blue-gray background."
            ),
            negative_prompt=(
                "new objects, ropes moving, weapons, hands, additional material, cloth detaching, morphing, pulling, "
                "camera movement, oscillation, color changes, glowing, sparkles, blurred surface"
            ),
        )
    return settings


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("side", choices=INPUTS)
    parser.add_argument("job_id", nargs="?")
    parser.add_argument("--hook", action="store_true")
    parser.add_argument("--input-only", action="store_true")
    args = parser.parse_args()
    side = args.side
    slot, seed = INPUTS[side]
    OUTPUT.mkdir(exist_ok=True)
    prefix = f"{side}-hook" if args.hook else side
    if args.job_id is None:
        build_input(side, slot, args.hook)
    if not args.input_only:
        render(OUTPUT, prefix, request(side, seed, args.hook), args.job_id, f"{prefix}-input.png")
