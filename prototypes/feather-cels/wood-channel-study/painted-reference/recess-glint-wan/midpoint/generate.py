"""Run the installed Wan 2.2 model with three actual temporal anchors for this study."""
import hashlib
import json
from pathlib import Path
import runpy
import sys
import time
from types import SimpleNamespace
from unittest.mock import patch

from PIL import Image

HERE = Path(__file__).resolve().parent
GLINT = HERE.parent
PREVIOUS = runpy.run_path(str(GLINT / "prepare.py"))
CREST = PREVIOUS["CREST"]
SLATS = PREVIOUS["SLATS"]
LOCAL = Path("E:/Local LLM")
SIZE = (704, 704)
FRAMES = 49
FPS = 16
MID = (FRAMES - 1) // 2
SEED = 509429
MODEL = "wan2.2-ti2v-5b-native"
PROMPT = (
    "Fixed orthographic closeup of stationary, hand-painted wooden slats. "
    "The wood, its paint, outlines and cut shapes are still. A fine pale mint "
    "reflection in the original carved bevels rises gently, meets its brightest "
    "painted pose in the middle, then fades to the original dark carved wood. "
    "Most of each recess remains dark; the reflection stays narrow and fixed in place."
)
NEGATIVE = ("camera motion, moving wood, new cracks, detached streaks, colored fill, "
            "green slime, fog, bloom, liquid, repaint, sparks, flicker")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_plates():
    clean = Image.new("RGBA", SIZE, "#30363b")
    glow = clean.copy()
    sources = []
    for side, index, y, _ in SLATS:
        plain_path = CREST / "registered" / f"{index:02}-paint.png"
        lit_path = GLINT / f"{side}-glint.png"
        plain = Image.open(plain_path).convert("RGBA")
        lit = Image.open(lit_path).convert("RGBA")
        assert plain.size == lit.size and plain.getchannel("A").tobytes() == lit.getchannel("A").tobytes()
        w, h = (dim * 2 for dim in plain.size)
        for plate, paint in ((clean, plain), (glow, lit)):
            plate.alpha_composite(paint.resize((w, h), Image.Resampling.LANCZOS), (27, y))
        sources.append(dict(side=side, still_sha256=digest(plain_path), midpoint_sha256=digest(lit_path),
                            video_box=[27, y, w, h]))
    clean.convert("RGB").save(HERE / "opening.png")
    glow.convert("RGB").save(HERE / "midpoint.png")
    return clean.convert("RGB"), glow.convert("RGB"), sources


def install_conditioning(runtime, glow_image):
    """Reuse native sampling, but clamp the chosen temporal latents at every step."""
    import torch
    from torchvision.transforms.functional import to_tensor
    import wan.textimage2video as wan_native

    pipeline = runtime.pipeline
    stride = pipeline.vae_stride[0]
    assert MID % stride == (FRAMES - 1) % stride == 0
    anchor_indices = (0, MID // stride, (FRAMES - 1) // stride)
    encode_native = pipeline.vae.encode
    masks_native = wan_native.masks_like
    record = {"latent_indices": anchor_indices, "encode_calls": 0, "mask_calls": 0}

    def encode_keyframes(images):
        if len(images) != 1 or images[0].shape != (3, 1, SIZE[1], SIZE[0]):
            raise RuntimeError("Wan changed the layout of its still-image conditioning")
        opening = images[0]
        middle = to_tensor(glow_image).to(opening.device).mul(2).sub(1).unsqueeze(1)
        opening_latent = encode_native([opening])[0]
        # A causal VAE encodes frame zero differently. Use a steady five-frame
        # window for the later anchors and take the corresponding second latent.
        middle_latent, last_latent = encode_native([
            middle.repeat(1, stride + 1, 1, 1),
            opening.repeat(1, stride + 1, 1, 1),
        ])
        shape = list(opening_latent.shape)
        shape[1] = anchor_indices[-1] + 1
        target = torch.zeros(shape, dtype=opening_latent.dtype, device=opening_latent.device)
        target[:, 0] = opening_latent[:, 0]
        target[:, anchor_indices[1]] = middle_latent[:, 1]
        target[:, anchor_indices[2]] = last_latent[:, 1]
        record["encode_calls"] += 1
        record["midpoint_latent_delta"] = round(float((middle_latent[:, 1] - last_latent[:, 1]).abs().mean()), 8)
        assert record["midpoint_latent_delta"] > 0
        return [target]

    def mask_keyframes(tensors, zero=False, **options):
        mask1, mask2 = masks_native(tensors, zero=zero, **options)
        if zero:
            mask2[0][:, list(anchor_indices)] = 0
            record["mask_calls"] += 1
        return mask1, mask2

    return (patch.object(pipeline.vae, "encode", encode_keyframes),
            patch.object(wan_native, "masks_like", mask_keyframes), record)


def generate():
    opening, glow, sources = make_plates()
    sys.path.insert(0, str(LOCAL / "runtime"))
    from video_jobs import GpuReservation
    from wan_native_backend import NativeRuntime
    from diffusers.utils import export_to_video

    registry = json.loads((LOCAL / "model-registry.json").read_text(encoding="utf-8"))
    model = next(entry for entry in registry["models"] if entry["id"] == MODEL)
    checkpoint = LOCAL / model["sourcePath"]
    args = SimpleNamespace(model_id=MODEL, model_path=checkpoint)
    for attempt in range(24):
        try:
            reservation = GpuReservation(LOCAL / "data/gpu-reservation.lock")
            break
        except BlockingIOError:
            if attempt == 23:
                raise
            if attempt == 0:
                print("Waiting for the existing GPU reservation", flush=True)
            time.sleep(5)
    runtime = NativeRuntime(args)
    try:
        print("Loading the installed Wan checkpoint under the shared GPU reservation", flush=True)
        started = time.monotonic()
        runtime.load()
        from contextlib import ExitStack
        encoder, mask, conditioning = install_conditioning(runtime, glow)
        print("Generating with the exact edited paint as the frame-24 condition", flush=True)
        with ExitStack() as stack:
            stack.enter_context(encoder)
            stack.enter_context(mask)
            frames = runtime._generate_frames(
                opening, SEED, prompt=PROMPT, negative_prompt=NEGATIVE, width=SIZE[0], height=SIZE[1],
                num_frames=FRAMES, num_inference_steps=36, guidance_scale=6.5,
            )
        assert conditioning["encode_calls"] == conditioning["mask_calls"] == 1
        assert frames.shape == (FRAMES, SIZE[1], SIZE[0], 3)
        result = HERE / "wan-midpoint.mp4"
        export_to_video(frames, str(result), fps=FPS)
        receipt = dict(model=MODEL, source_revision=model["runtimeArguments"]["sourceRevision"],
                       runtime_revision=model["runtimeArguments"]["runtimeRevision"],
                       prompt=PROMPT, negative_prompt=NEGATIVE, fps=FPS, size=list(SIZE),
                       frames=FRAMES, guide_frames=[0, MID, FRAMES-1], steps=36, guidance=6.5, seed=SEED,
                       sources=sources, opening_sha256=digest(HERE / "opening.png"),
                       midpoint_sha256=digest(HERE / "midpoint.png"),
                       conditioning=conditioning, output_sha256=digest(result),
                       elapsed_seconds=round(time.monotonic() - started, 2))
        (HERE / "trial.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(f"Saved {result.name} and the exact conditioning receipt", flush=True)
    finally:
        del runtime
        reservation.close()


if __name__ == "__main__":
    if sys.argv[1:] == ["--prepare-only"]:
        make_plates()
    else:
        generate()
