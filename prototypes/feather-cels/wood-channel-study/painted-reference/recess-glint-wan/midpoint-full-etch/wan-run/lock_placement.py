"""Recover Wan's timing while holding the approved shard art pixel for pixel."""
import json
import sys

import numpy as np
from PIL import Image

from render import STYLE, HERE, FRAMES, FPS, MID, digest, originals, target_amount, linear, srgb

sys.path.insert(0, str(STYLE["OLD"]["PROJECT"] / "animation-rnd/.deps"))
import cv2


def decode_raw(path):
    reader = cv2.VideoCapture(str(path))
    assert reader.isOpened() and reader.get(cv2.CAP_PROP_FPS) == FPS
    frames = []
    try:
        while True:
            ok, frame = reader.read()
            if not ok:
                break
            frames.append(frame[:, :, ::-1].copy())
    finally:
        reader.release()
    assert len(frames) == FRAMES
    return frames


def normalize_half(raw):
    low, high = raw[0], raw[-1]
    if high - low < .1:
        return target_amount(np.arange(MID + 1))
    scaled = np.clip((raw - low) / (high - low), 0, 1)
    eased = np.maximum.accumulate(scaled)
    eased[0], eased[-1] = 0, 1
    return eased


def smooth_timing(response):
    kernel = np.array((1, 2, 3, 2, 1)) / 9
    filtered = np.convolve(np.pad(response, (2,2), mode="edge"), kernel, mode="valid")
    up = normalize_half(filtered[:MID+1])
    down = normalize_half(filtered[MID:][::-1])[::-1]
    sampled = np.r_[up, down[1:]]
    guide = target_amount(np.arange(FRAMES))
    # Stabilize the timing of the decoded light. A transient from the video
    # may nudge the ramp, but may not create a flicker, plateau, or second peak.
    limited = np.clip(sampled, guide - .18, guide + .18)
    result = .72*guide + .28*limited
    result[0], result[MID], result[-1] = 0, 1, 0
    assert np.all(np.diff(result[:MID+1]) >= 0) and np.all(np.diff(result[MID:]) <= 0)
    return result


def build():
    clip = HERE / "wan-full-etch-raw.mp4"
    trial = json.loads((HERE / "trial.json").read_text(encoding="utf-8"))
    assert trial["raw_sha256"] == digest(clip) and trial["midpoint_frame"] == MID
    dark, peak, registration = originals()
    a, b = np.asarray(dark), np.asarray(peak)
    mask = np.any(a != b, axis=2)
    dark_linear = linear(a.astype(np.float32) / 255)
    peak_linear = linear(b.astype(np.float32) / 255)
    delta = peak_linear - dark_linear
    decoded = decode_raw(clip)
    states = []
    detail = {}
    for sprite in registration["sprites"]:
        name = sprite["side"]
        _, y, _, height = sprite["video_box"]
        local_mask = np.zeros(mask.shape, dtype=bool)
        local_mask[y:y+height] = mask[y:y+height]
        visible = local_mask & (np.max(delta, axis=2) > .04)
        template = delta[visible]
        reference = dark_linear[visible]
        measure = np.array([
            np.sum((linear(frame[visible].astype(np.float32) / 255) - reference) * template) /
            np.sum(template**2) for frame in decoded
        ])
        timing = smooth_timing(measure)
        states.append((local_mask, timing))
        detail[name] = dict(raw=[round(float(n),5) for n in measure],
                            locked=[round(float(n),5) for n in timing],
                            raw_peak_frame=int(np.argmax(measure)))

    frames = []
    for i in range(FRAMES):
        pixels = a.copy()
        if i == MID:
            pixels = b.copy()
        elif i not in (0, FRAMES-1):
            for region, timing in states:
                lit = srgb(np.clip(dark_linear[region] + delta[region]*timing[i], 0, 1))
                pixels[region] = np.rint(lit*255).astype(np.uint8)
        assert np.array_equal(pixels[~mask], a[~mask])
        frames.append(Image.fromarray(pixels))
    durations = [round((i+1)*1000/FPS)-round(i*1000/FPS) for i in range(FRAMES)]
    path = HERE / "wan-full-etch-registered.webp"
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, lossless=True, method=6, exact=True)
    # Re-open the animation, since an encoder error would invalidate the locked plate.
    sample = 0
    with Image.open(path) as rendered:
        for index in range(rendered.n_frames):
            rendered.seek(index)
            rendered.load()
            start = rendered.info["timestamp"]
            stop = start + rendered.info["duration"]
            # WebP merges identical consecutive frames without changing playback.
            while sample < FRAMES and start <= round(sample*1000/FPS) < stop:
                assert rendered.convert("RGB").tobytes() == frames[sample].tobytes()
                sample += 1
    assert sample == FRAMES and stop == sum(durations)

    outside = ~mask & np.any(a != a[0,0], axis=2)
    model_difference = [float(np.mean(np.abs(frame[outside].astype(np.float32) - a[outside])) / 255)
                        for frame in decoded]
    report = dict(anchors=[0, MID, FRAMES-1], presentation_midpoint_ms=sum(durations[:MID]),
                  roundtrip_exact=True, raw_outside_rgb_mean_absolute_difference_midpoint=round(model_difference[MID],5),
                  locked_outside_max_error=0, clip_sha256=digest(path), lights=detail)
    (HERE / "quality.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print({name: values["raw_peak_frame"] for name, values in detail.items()})
    print("Verified all 49 registered frames, exact approved midpoint, and exact unlit endpoints.", flush=True)


if __name__ == "__main__":
    build()
