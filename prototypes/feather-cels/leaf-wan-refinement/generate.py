"""Render the isolated, registered leaf guides using the existing local Wan model."""
import argparse
import json
import sys
import time
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np
from PIL import Image

from guides import COUNT, OUTPUT, SIZE, digest


LOCAL = Path("E:/Local LLM")
MODEL = "wan2.2-ti2v-5b-native"
PROMPT = (
    "Front view, one isolated cluster of hand-painted fantasy foliage, exact composition "
    "and paint of the keyframes. Locked camera, flat blue-grey studio matte. Identical "
    "leaves, stem joins absolutely still, readable continuous veins and strong painted "
    "texture. Each full leaf blade flexes from its midrib with distributed curvature, "
    "slight natural stagger between overlapping blades. Match registered endpoint and "
    "peak poses and their localized leaf lighting. "
)
DIRECTIONS = {
    "channel": "Energetic wind shuffle, bow and release with a silky continuous cadence, lively "
               "green light along the blades which remains readable, seamless periodic closure.",
    "impact": "Single decisive shockwave, immediate strong backwards curl of the whole blades, "
              "bright brief green flash at the peak. Soft slower recovery to the original pose.",
}
NEGATIVE = ("camera motion, translation at stem, rigid rotation, flicker, mesh ripple, rubber, "
            "jelly, smeared texture, blur, crawling veins, extra leaves, detached pieces, "
            "recolored foliage, floating particles, background lighting, neon outline")


def controls(runtime, guide, keys, support, freedom):
    import torch
    from torch.nn.functional import max_pool2d
    import wan.textimage2video as engine

    vae = runtime.pipeline.vae
    temporal, stride_y, stride_x = runtime.pipeline.vae_stride
    patch_y, patch_x = runtime.pipeline.patch_size[1:]
    positions = [index // temporal for index in keys]
    assert all(index % temporal == 0 for index in keys)
    encode_original = vae.encode
    mask_original = engine.masks_like
    receipt = {"guideFrames": keys, "latentKeys": positions, "encodes": 0, "masks": 0,
               "interpolationFreedom": freedom}

    def encode(sources):
        assert len(sources) == 1 and sources[0].shape == (3, 1, SIZE[1], SIZE[0])
        tensor = torch.from_numpy(guide.astype(np.float32) / 127.5 - 1)
        tensor = tensor.permute(3, 0, 1, 2).contiguous().to(sources[0])
        latent = encode_original([tensor])[0]
        assert latent.shape[1] == (COUNT - 1) // temporal + 1
        receipt["encodes"] += 1
        return [latent]

    def masks(tensors, zero=False, **options):
        one, two = mask_original(tensors, zero=zero, **options)
        if zero:
            size = (patch_y * stride_y, patch_x * stride_x)
            region = torch.as_tensor(support, device=two[0].device, dtype=torch.float32)[None, None]
            region = max_pool2d(max_pool2d(region, size, size), 3, 1, 1)[0, 0]
            region = region.repeat_interleave(patch_y, 0).repeat_interleave(patch_x, 1)
            two[0].mul_(region * freedom)
            two[0][:, positions] = 0
            receipt["masks"] += 1
        return one, two

    return patch.object(vae, "encode", encode), patch.object(engine, "masks_like", masks), receipt


def generate(runtime, model, job, trial, steps):
    from diffusers.utils import export_to_video
    from guides import MATTE

    folder = OUTPUT / job["name"] / job["state"]
    stem = f"trial-{trial:02}"
    guide_path = folder / "guide.npz"
    guide_hash = digest(guide_path)
    receipt_path = folder / f"{stem}.json"
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if (receipt["guideSha256"] == guide_hash and
                (folder / f"{stem}.npz").exists() and (folder / f"{stem}.mp4").exists()):
            return
        raise RuntimeError(f"Existing trial receipt does not match inputs in {folder}")
    with np.load(guide_path) as data:
        guide = data["rgb"]
    support = np.any(guide != np.asarray(MATTE), axis=(0, 3))
    # The first trial lets Wan generate freely between its temporal keys.
    # Follow-up trials retain more of the pose and exposure guide in each
    # intermediate latent to reduce color shimmer and anchor drift.
    freedom = {1: 1.0, 2: .52, 3: .34, 4: .24, 5: .20}[trial]
    guidance = 6.0 if trial == 1 else 5.0
    encoder, mask, receipt = controls(runtime, guide, job["keys"], support, freedom)
    seed = 382511 + job["index"] * 101 + trial * 17 + (0 if job["state"] == "channel" else 5000)
    prompt = PROMPT + DIRECTIONS[job["state"]]
    started = time.monotonic()
    print(f"Rendering {job['name']} {job['state']} trial {trial}", flush=True)
    with ExitStack() as stack:
        stack.enter_context(encoder)
        stack.enter_context(mask)
        frames = runtime._generate_frames(
            Image.fromarray(guide[0]), seed, prompt=prompt, negative_prompt=NEGATIVE,
            width=SIZE[0], height=SIZE[1], num_frames=COUNT, num_inference_steps=steps,
            guidance_scale=guidance,
        )
    assert frames.shape == (COUNT, SIZE[1], SIZE[0], 3)
    assert receipt["encodes"] == receipt["masks"] == 1
    raw = np.uint8(np.clip(frames * 255 + .5, 0, 255)) if frames.dtype.kind == "f" else frames
    np.savez_compressed(folder / f"{stem}.npz", rgb=raw)
    export_to_video(frames, str(folder / f"{stem}.mp4"), fps=16)
    receipt.update(model=MODEL, backend=model["runtimeArguments"], modelSource=model["sourcePath"],
                   guideSha256=guide_hash, seed=seed, steps=steps, guidance=guidance,
                   prompt=prompt, negativePrompt=NEGATIVE, elapsedSeconds=round(time.monotonic()-started, 2))
    receipt_path.write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print(f"Saved {job['name']} {job['state']} in {receipt['elapsedSeconds']} s", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--segment", nargs="*")
    parser.add_argument("--state", choices=DIRECTIONS)
    parser.add_argument("--trial", type=int, choices=range(1, 6), default=1)
    parser.add_argument("--steps", type=int, default=28)
    options = parser.parse_args()
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    jobs = [job for job in jobs if (not options.segment or job["name"] in options.segment)
            and (not options.state or job["state"] == options.state)]
    if not jobs:
        parser.error("No matching segment and state")
    sys.path.insert(0, str(LOCAL / "runtime"))
    from video_jobs import GpuReservation
    from wan_native_backend import NativeRuntime

    registry = json.loads((LOCAL / "model-registry.json").read_text(encoding="utf-8"))
    model = next(entry for entry in registry["models"] if entry["id"] == MODEL)
    for attempt in range(25):
        try:
            reservation = GpuReservation(LOCAL / "data/gpu-reservation.lock")
            break
        except BlockingIOError:
            if attempt == 24:
                raise
            if attempt == 0:
                print("Waiting for the shared LocalLLM GPU reservation", flush=True)
            time.sleep(5)
    try:
        runtime = NativeRuntime(SimpleNamespace(model_id=MODEL, model_path=LOCAL / model["sourcePath"]))
        print(f"Loading {MODEL} for {len(jobs)} queued renders", flush=True)
        runtime.load()
        for job in jobs:
            generate(runtime, model, job, options.trial, options.steps)
    finally:
        reservation.close()


if __name__ == "__main__":
    main()
