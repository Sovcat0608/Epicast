"""Condition local Wan on the approved full-etch painting and preserve fixed wood."""
from contextlib import ExitStack
import json
from pathlib import Path
import runpy
import sys
import time
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REFERENCE = HERE.parent
EARLIER = runpy.run_path(str(REFERENCE.parent / "midpoint/generate.py"))
LOCAL, SIZE, FRAMES, FPS, MID, SEED, MODEL, digest = (
    EARLIER[key] for key in ("LOCAL", "SIZE", "FRAMES", "FPS", "MID", "SEED", "MODEL", "digest")
)
STYLE = EARLIER["PREVIOUS"]
linear, srgb = (STYLE[key] for key in ("linear", "srgb"))
KEYFRAMES = tuple(range(0, FRAMES, 8))
PROMPT = (
    "A fixed hand-painted game sprite shot of two stationary carved wooden shards. "
    "Every original carved recess gradually emits yellow-lime light across its full width. "
    "The shaded inner walls and soft reflection on the neighboring carved bevels follow "
    "the supplied poses through a smooth rise to full emission in the middle and a smooth "
    "fade to dark wood at the end. The two shards and all original paint stay perfectly still."
)
NEGATIVE = ("camera movement, new glyphs, moving wood, shifting carvings, opaque green fill, "
            "line-only lighting, glow outside the etches, moving streaks, smoke, particles, flicker")


def originals():
    manifest = json.loads((REFERENCE / "registration.json").read_text(encoding="utf-8"))
    dark_path = REFERENCE.parent / "midpoint/opening.png"
    peak_path = REFERENCE / "midpoint.png"
    assert digest(peak_path) == manifest["midpoint_sha256"]
    dark, peak = (Image.open(path).convert("RGB") for path in (dark_path, peak_path))
    assert dark.size == peak.size == SIZE
    return dark, peak, manifest


def target_amount(frame):
    return np.sin(np.pi * frame / (FRAMES - 1)) ** 2


def encode_anchors(runtime, opening, peak, keys):
    import torch
    from torch.nn.functional import max_pool2d
    import wan.textimage2video as wan_native

    vae = runtime.pipeline.vae
    stride_t, stride_y, stride_x = runtime.pipeline.vae_stride
    assert all(frame % stride_t == 0 for frame in keys)
    positions = [frame // stride_t for frame in keys]
    start = np.asarray(opening, dtype=np.float32) / 255
    stop = np.asarray(peak, dtype=np.float32) / 255
    base = linear(start)
    delta = linear(stop) - base
    support = np.any(np.abs(stop - start) > 1 / 255, axis=2)
    encode_native = vae.encode
    masks_native = wan_native.masks_like
    receipt = dict(guide_frames=list(keys), latent_indices=positions, encode_calls=0, mask_calls=0)

    def encode(sources):
        if len(sources) != 1 or sources[0].shape != (3, 1, SIZE[1], SIZE[0]):
            raise RuntimeError("Unexpected first-frame layout in the installed Wan backend")
        guide = np.stack([srgb(np.clip(base + target_amount(f) * delta, 0, 1)) for f in range(FRAMES)])
        # Supply exact endpoint and peak RGB at the three approved keyframes.
        guide[0] = guide[-1] = start
        guide[MID] = stop
        tensor = torch.from_numpy(guide).permute(3, 0, 1, 2).contiguous().to(sources[0])
        tensor.mul_(2).sub_(1)
        latent = encode_native([tensor])[0]
        assert latent.shape[1] == (FRAMES - 1) // stride_t + 1
        assert float((latent[:, positions[len(positions)//2]] - latent[:, 0]).abs().mean()) > 0
        receipt["encode_calls"] += 1
        return [latent]

    def masks(tensors, zero=False, **options):
        one, two = masks_native(tensors, zero=zero, **options)
        if zero:
            # Reserve whole spatial-token groups for the etched region.
            # The narrow rendered mask applied after decode is in native pixels.
            patch_y, patch_x = runtime.pipeline.patch_size[1:]
            stride = (patch_y * stride_y, patch_x * stride_x)
            light = torch.as_tensor(support, device=two[0].device, dtype=torch.float32)[None, None]
            editable = max_pool2d(max_pool2d(light, stride, stride), 3, 1, 1)
            editable = editable[0, 0].repeat_interleave(patch_y, 0).repeat_interleave(patch_x, 1)
            assert editable.shape == two[0].shape[-2:]
            two[0].mul_(editable)
            two[0][:, positions] = 0
            receipt["mask_calls"] += 1
            receipt["editable_spatial_latent_fraction"] = round(float(editable.mean()), 5)
        return one, two

    return patch.object(vae, "encode", encode), patch.object(wan_native, "masks_like", masks), receipt


def run(opening, midpoint, spec):
    sys.path.insert(0, str(LOCAL / "runtime"))
    from diffusers.utils import export_to_video
    from video_jobs import GpuReservation
    from wan_native_backend import NativeRuntime

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
                print("Waiting for LocalLLM GPU reservation", flush=True)
            time.sleep(5)

    try:
        started = time.monotonic()
        runtime = NativeRuntime(args)
        print("Loading local Wan 2.2 under the existing GPU reservation", flush=True)
        runtime.load()
        encoder, mask, receipt = encode_anchors(runtime, opening, midpoint, KEYFRAMES)
        print(f"Conditioning on frames {KEYFRAMES}; full-etch guide is frame {MID}", flush=True)
        with ExitStack() as stack:
            stack.enter_context(encoder)
            stack.enter_context(mask)
            frames = runtime._generate_frames(
                opening, SEED, prompt=PROMPT, negative_prompt=NEGATIVE, width=SIZE[0], height=SIZE[1],
                num_frames=FRAMES, num_inference_steps=36, guidance_scale=6.5,
            )
        assert receipt["encode_calls"] == receipt["mask_calls"] == 1
        assert frames.shape == (FRAMES, SIZE[1], SIZE[0], 3)
        output = HERE / "wan-full-etch-raw.mp4"
        export_to_video(frames, str(output), fps=FPS)
        evidence = dict(model=MODEL, source_revision=model["runtimeArguments"]["sourceRevision"],
                        runtime_revision=model["runtimeArguments"]["runtimeRevision"],
                        fps=FPS, frames=FRAMES, midpoint_frame=MID, seed=SEED,
                        steps=36, guidance=6.5, conditioning=receipt, prompt=PROMPT,
                        negative_prompt=NEGATIVE, midpoint_sha256=spec["midpoint_sha256"],
                        raw_sha256=digest(output), elapsed_seconds=round(time.monotonic()-started, 2))
        (HERE / "trial.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
        print("Saved the conditioned Wan render", flush=True)
    finally:
        reservation.close()


if __name__ == "__main__":
    run(*originals())
