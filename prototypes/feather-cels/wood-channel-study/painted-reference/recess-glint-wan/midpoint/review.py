"""Check Wan's decoded midpoint and compare it with the actual paint target."""
import hashlib
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

from generate import HERE, MID, FRAMES, FPS, SLATS, PREVIOUS

sys.path.insert(0, str(PREVIOUS["OLD"]["PROJECT"] / "animation-rnd/.deps"))
import cv2


def load_frames():
    cap = cv2.VideoCapture(str(HERE / "wan-midpoint.mp4"))
    all_frames = []
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        all_frames.append(frame[:, :, ::-1].copy())
    cap.release()
    assert len(all_frames) == FRAMES
    return all_frames


def chroma(rgb):
    return rgb[:, :, 1] - .65 * rgb[:, :, 0] - .35 * rgb[:, :, 2]


def compare():
    audit = json.loads((HERE / "trial.json").read_text(encoding="utf-8"))
    video = HERE / "wan-midpoint.mp4"
    assert audit["output_sha256"] == hashlib.sha256(video.read_bytes()).hexdigest()
    assert audit["guide_frames"] == [0, MID, FRAMES-1]
    unlit = np.asarray(Image.open(HERE / "opening.png"), dtype=np.float32) / 255
    lit = np.asarray(Image.open(HERE / "midpoint.png"), dtype=np.float32) / 255
    frames = load_frames()
    input_chroma = chroma(unlit)
    delta = chroma(lit) - input_chroma
    focus = np.max(np.abs(lit-unlit), axis=2) > .06
    outside = (~focus) & (np.max(np.abs(unlit - unlit[0,0]), axis=2) > .10)
    entries = {}
    for side, _, y, *_ in SLATS:
        roi = focus.copy()
        roi[:y] = False
        roi[y + 296:] = False
        template = delta[roi]
        response = [((chroma(pixels / 255) - input_chroma)[roi] * template).sum() /
                    np.sum(template**2) for pixels in frames]
        entries[side] = dict(start=round(float(response[0]), 3),
                             midpoint=round(float(response[MID]), 3),
                             end=round(float(response[-1]), 3),
                             peak_frame=int(np.argmax(response)),
                             lowest_frame=int(np.argmin(response)),
                             response=[round(float(v), 3) for v in response])
    drift = [round(float(np.mean(np.abs(pixels / 255 - unlit)[outside])), 4) for pixels in frames]
    metrics = dict(rule="Exact paint yields 1.0, clean paint yields 0.0",
                   glint_response=entries, full_clip_wood_rgb_difference=drift)
    (HERE / "quality.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    shots = (
        ("Opening", frames[0]),
        (f"{FRAMES//4 / FPS:.2f}s", frames[FRAMES//4]),
        ("Wan midpoint", frames[MID]),
        (f"{3 * FRAMES//4 / FPS:.2f}s", frames[3 * FRAMES//4]),
        ("Ending", frames[-1]),
        ("Exact midpoint guide", np.rint(lit * 255).astype(np.uint8)),
    )
    sheet = Image.new("RGB", (1056, 752), "#202729")
    draw = ImageDraw.Draw(sheet)
    for n, (title, pixels) in enumerate(shots):
        x, y = n % 3 * 352, n // 3 * 376
        draw.text((x + 10, y + 5), title, fill="white")
        sheet.paste(Image.fromarray(pixels).resize((352, 352), Image.Resampling.LANCZOS), (x, y + 24))
    sheet.save(HERE / "midpoint-comparison.png")
    for side, entry in entries.items():
        print(side, {key: val for key, val in entry.items() if key != "response"})
    print("Opening, midpoint and end off-mask difference:", drift[0], drift[MID], drift[-1])


if __name__ == "__main__":
    compare()
