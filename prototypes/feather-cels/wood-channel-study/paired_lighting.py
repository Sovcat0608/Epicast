"""Register the painted light difference and sample Wan only inside that light."""
import numpy as np
from PIL import Image, ImageChops, ImageFilter

from bake_batch import cv2

PULSE_MS = 1440


def linear(srgb):
    return np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055)**2.4)


def srgb(linear_rgb):
    linear_rgb = np.clip(linear_rgb, 0, 1)
    return np.where(linear_rgb <= .0031308, 12.92 * linear_rgb, 1.055 * linear_rgb**(1/2.4) - .055)


def green(rgb):
    return rgb[:, :, 1] - .65 * rgb[:, :, 0] - .35 * rgb[:, :, 2]


def registered_light(base, reference, side):
    with Image.open(reference / f"{side}-wood-lit.png") as lit, Image.open(reference / f"{side}-wood-unlit.png") as unlit:
        if lit.size != unlit.size:
            raise ValueError("The illuminated and unlit plates have different registrations")
        on = lit.convert("RGBA").resize(base.size, Image.Resampling.LANCZOS)
        off = unlit.convert("RGBA").resize(base.size, Image.Resampling.LANCZOS)
        reference_size = lit.size
    on_rgb, off_rgb, base_rgb = (np.asarray(im.convert("RGB"), dtype=np.float32) / 255 for im in (on,off,base))
    gain = green(on_rgb) - green(off_rgb)
    brighter = on_rgb[:, :, 1] - off_rgb[:, :, 1]
    # Grow around the green spill to keep the painted transition into the brown bevels.
    seed = (gain > .055) & (brighter > .035)
    core = Image.fromarray(seed.astype(np.uint8) * 255)
    soft = core.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(2.2))
    matte = ImageChops.lighter(soft, core)
    # The original wood is the geometry and colour source. Transfer only
    # the painted change in lighting, in linear light, at those same pixels.
    matte = ImageChops.multiply(matte, base.getchannel("A"))
    weight = np.asarray(matte, dtype=np.float32) / 255
    light = np.maximum(0, linear(on_rgb) - linear(off_rgb))
    # An emissive pass cannot darken the base. Limit blue from mismatched
    # brush marks while retaining the near-white cores in the on plate.
    light[:, :, 2] = np.minimum(light[:, :, 2], .72 * light[:, :, 1])
    result = srgb(linear(base_rgb) + light * weight[:, :, None])
    plate = Image.fromarray(np.rint(result * 255).astype(np.uint8))
    plate.putalpha(base.getchannel("A"))
    if matte.getbbox() is None:
        raise ValueError("The two paintings did not produce a usable light matte")
    return plate, matte, reference_size


def hold_response(matte, reference_size, video):
    # Match the exact letterbox used for the 704 x 384 Wan image-to-video input.
    size = Image.new("L", reference_size)
    size.thumbnail((642,320))
    roi = Image.new("L", (704,384))
    roi.paste(matte.resize(size.size, Image.Resampling.LANCZOS), ((704-size.width)//2, (384-size.height)//2))
    weight = np.asarray(roi, dtype=np.float32) / 255
    limit = 22
    clip = cv2.VideoCapture(str(video))
    samples = []
    try:
        for _ in range(limit):
            ok, frame = clip.read()
            if not ok:
                break
            rgb = frame[:, :, ::-1].astype(np.float32) / 255
            samples.append(float(np.average(np.maximum(0, green(rgb)), weights=weight)))
    finally:
        clip.release()
    if len(samples) != limit:
        raise ValueError("The masked Wan Hold source is incomplete")
    # Use the variation, with a seamless return to the exact painted light.
    samples = np.convolve(np.pad(samples, (1,1), mode="edge"), (.25,.5,.25), mode="valid")
    sampled = np.interp(np.linspace(0,len(samples)-1,13), np.arange(len(samples)), samples)
    relative = sampled / max(sampled.max(), 1e-6)
    ripple = 1 - np.minimum(.055,(1 - relative) * .60) * np.hanning(len(relative))
    return dict(period=PULSE_MS, levels=[round(float(v),5) for v in ripple])
