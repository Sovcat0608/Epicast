"""Extract transparent review cels from the selected Wan renders and rebuild contact."""
import json
import subprocess

import numpy as np
from PIL import Image, ImageDraw

from guides import MATTE, OUTPUT, SIZE, cv2, leaf_sources
from bake_impact import with_emission
from bake_inner import config, crop_tile
from cheek_placement import composite, registered_stack
from crown import leaf_contact
from scipy.ndimage import distance_transform_edt


CREST = (0, 0, 1125, 1400)
BG = (49, 58, 53, 255)
IMPACT = [3, 4, 7, 10, 13, 16, 19, 22, 25, 28, 30, 32]


def estimate_matte(frame, outside):
    # Use the nearby decoded background instead of assuming Wan preserved a flat RGB.
    weight = outside.astype(np.float32)
    blurred_weight = cv2.GaussianBlur(weight, (0, 0), 14)
    mean = np.median(frame[outside], axis=0)
    channels = []
    for band, fallback in zip(frame.transpose(2, 0, 1), mean):
        total = cv2.GaussianBlur(band * weight, (0, 0), 14)
        channels.append(np.divide(total, blurred_weight, out=np.full_like(band, fallback),
                                  where=blurred_weight > .008))
    return np.stack(channels, axis=2)


def smoothstep(x):
    t = np.clip(x, 0, 1)
    return t * t * (3 - 2 * t)


def extract(frame, plate, mask, bounds):
    frame = frame.astype(np.float32) / 255
    plate = plate.astype(np.float32) / 255
    mask = mask.astype(np.float32) / 255
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    footprint = cv2.dilate((mask > .05).astype(np.uint8), kernel) > 0
    interior = cv2.erode((mask > .99).astype(np.uint8), kernel) > 0
    background = estimate_matte(frame, ~footprint)
    solid = mask >= .98
    nearest = distance_transform_edt(~solid, return_distances=False, return_indices=True)
    expected = (plate[nearest[0], nearest[1]] - np.asarray(MATTE, np.float32) / 255)
    observed = frame - background
    # Use the color component orthogonal to neutral luminance to limit
    # rounding errors in dark creases and local exposure changes.
    expected -= expected.mean(axis=2, keepdims=True)
    observed -= observed.mean(axis=2, keepdims=True)
    strength = (observed * expected).sum(axis=2) / np.maximum(.006, (expected * expected).sum(axis=2))
    edge = smoothstep((strength - .10) / .66)
    alpha = np.where(interior, 1, edge) * footprint * bounds
    color = np.clip((frame - background * (1 - alpha[:, :, None])) /
                    np.maximum(.08, alpha[:, :, None]), 0, 1)
    core = interior & (strength > .45)
    if np.count_nonzero(core) > 64:
        # Suppress leaf-wide exposure flashes introduced by the model. The
        # registered guide retains the intended pulse and spec palette.
        flatten = np.array([.2126, .7152, .0722], dtype=np.float32)
        source_luma = color @ flatten
        target_luma = plate @ flatten
        knots = (15, 32, 50, 72, 88, 97)
        source = np.percentile(source_luma[core], knots)
        target = np.percentile(target_luma[core], knots)
        correction = np.interp(source_luma, source, target - source)
        color = np.clip(color + correction[:, :, None], 0, 1)
    return Image.fromarray(np.rint(np.dstack((color, alpha)) * 255).astype(np.uint8))


def registered_cels(job, trial):
    name, state = job["name"], job["state"]
    folder = OUTPUT / name / state
    with np.load(folder / f"trial-{trial:02}.npz") as data:
        actual = data["rgb"]
    with np.load(folder / "guide.npz") as data:
        native, guide = data["native"], data["rgb"]
    x, y, w, h = job["modelRect"]
    native_width, native_height = job["registered"][2:]
    xx, yy = np.meshgrid(np.arange(native_width), np.arange(native_height))
    spine = np.asarray(job["direction"])
    along = (xx - job["stem"][0]) * spine[0] + (yy - job["stem"][1]) * spine[1]
    freedom = smoothstep((along - job["rootLength"]) / 26).astype(np.float32)
    locked = Image.fromarray(np.uint8(freedom == 0) * 255)
    bounds = np.zeros((SIZE[1], SIZE[0]), dtype=bool)
    bounds[y:y+h, x:x+w] = True
    indices = list(range(0, 32, 2)) if state == "channel" else IMPACT
    cels = []
    for index in indices:
        exact = Image.fromarray(native[index])
        if index in (0, 32):
            cels.append(exact)
            continue
        reference = Image.new("L", SIZE)
        reference.paste(exact.getchannel("A").resize((w, h), Image.Resampling.LANCZOS), (x, y))
        generated = extract(actual[index], guide[index], np.asarray(reference), bounds)
        recovered = generated.crop((x, y, x+w, y+h)).resize(exact.size, Image.Resampling.LANCZOS)
        distance = min(index, 32-index) if state == "channel" else 32-index
        keep_model = Image.fromarray(np.uint8(freedom * smoothstep(distance / 5) * 255))
        # This fixed span stays under the crest hardware. The blade beyond
        # it retains the generated frame and may extend outside the base art.
        merged = Image.composite(recovered.convert("RGBa"), exact.convert("RGBa"), keep_model).convert("RGBA")
        merged.paste(exact, (0, 0), locked)
        cels.append(merged)
    cols = 4
    sheet = Image.new("RGBA", (cols * native_width, ((len(cels)+cols-1)//cols)*native_height))
    for index, cel in enumerate(cels):
        sheet.paste(cel, ((index%cols)*native_width, (index//cols)*native_height))
    sheet.save(folder / "registered-cels.webp", lossless=True)
    return cels


def video(path, frames, fps):
    import imageio_ffmpeg

    width, height = frames[0].size
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo",
               "-pix_fmt", "rgb24", "-s", f"{width}x{height}", "-r", str(fps), "-i", "-",
               "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags",
               "+faststart", str(path)]
    subprocess.run(command, input=b"".join(frame.tobytes() for frame in frames), check=True)


def current_cels(state):
    if state == "channel":
        return {i: (slot, [with_emission(cel, i, .83 + .17*np.sin(2*np.pi*(frame/16-.073*(i-8))))
                           for frame, cel in enumerate(cels)])
                for i, (slot, cels) in leaf_sources().items()}
    impact = config("leaf-impact-study/track.js")
    result = {}
    for track in impact["segments"]:
        x, y, w, h = track["slot"]
        path = OUTPUT.parent.parent / "prototypes/feather-cels" / track["sheet"]
        sheet = Image.open(path).convert("RGBA")
        count, columns = impact["frames"], impact["columns"]
        cels = []
        for frame in range(count):
            left, top = frame % columns * w, frame // columns * h
            cels.append(sheet.crop((left, top, left+w, top+h)))
        result[track["layer"]] = ([x,y,w,h], cels)
    return result


def scene(prepared, slot, paints, fields, base):
    for index, (registration, cel) in prepared.items():
        canvas = crop_tile(cel, registration, slot)
        paints[index] = canvas
        fields[index] = leaf_contact(canvas.getchannel("A")).getchannel("A")
    crest = base.copy()
    crest.paste(composite(paints, fields, slot), (0, 0))
    return crest


def build(selection):
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    for state, fps, count in (("channel", 48, 16), ("impact", 12, 12)):
        selected = [job for job in jobs if job["state"] == state]
        if any(not (OUTPUT / job["name"] / state /
                   f"trial-{selection[job['name']+'/'+state]['trial']:02}.json").exists() for job in selected):
            raise RuntimeError(f"Missing selected Wan renders for {state}")
        cels = [registered_cels(job, selection[job["name"]+"/"+state]["trial"]) for job in selected]
        slot = (0, 0, CREST[2], 624)
        # Only the crown changes. The lower stack is evaluated once at its
        # existing registered placement so the contacts and chin stay intact.
        base = composite(*registered_stack(CREST, hide_cheeks=True), CREST)
        paints, fields = registered_stack(slot, hide_cheeks=True)
        current = current_cels(state)
        before = []
        for frame in range(count):
            prepared = {index: (registration, track[frame]) for index, (registration, track) in current.items()}
            before.append(scene(prepared, slot, paints, fields, base).resize((256, 319), Image.Resampling.LANCZOS))
        after = []
        for frame in range(count):
            prepared = {job["index"]: (job["registered"], column[frame]) for job, column in zip(selected, cels)}
            after.append(scene(prepared, slot, paints, fields, base))
        frames = []
        small = [crest.resize((256,319), Image.Resampling.LANCZOS) for crest in after]
        large = [crest.resize((442,550), Image.Resampling.LANCZOS) for crest in after]
        cycle = count * 2 if state == "channel" else count
        for frame in range(cycle):
            views = Image.new("RGBA", (1004, 592), BG)
            labels = ImageDraw.Draw(views)
            for x, y, caption in ((25, 107, "Current · 256 px"), (294, 107, "Refinement · 256 px"),
                                  (561, 9, "Refinement · enlarged")):
                labels.text((x, y), caption, fill=(237, 242, 232, 255))
            old_index = frame//2 if state == "channel" else frame
            views.alpha_composite(before[old_index], (14, 129))
            views.alpha_composite(small[frame % count], (283, 129))
            views.alpha_composite(large[frame % count], (555, 28))
            frames.append(views.convert("RGB"))
        repetition = 6 if state == "channel" else 2
        strip = frames * repetition if state == "channel" else (frames + [frames[-1]]*10)*repetition
        video(OUTPUT / f"crest-{state}.mp4", strip, fps)
        print(f"{state}: {count} registered RGBA cels for each of six leaves", flush=True)


if __name__ == "__main__":
    cv2.setNumThreads(2)
    build(json.loads((OUTPUT / "review-selection.json").read_text(encoding="utf-8")))
