"""Run registered artwork guides through the existing local Wan checkpoint."""
import argparse
from contextlib import ExitStack
import json
from types import SimpleNamespace
import sys
import time

import numpy as np
from PIL import Image
from motion_guides import COUNT, MATTE, OUT, PREVIEW, SIZE

sys.path.insert(0, str(PREVIEW/"leaf-wan-refinement"))
from generate import LOCAL, MODEL, controls, digest


PROMPTS = {
    "treant-idle": ("One isolated exact carved wooden treant face, static front camera. Green eyes retain their "
                    "shape and intensity. A slow single breathing cycle. First retain the slightly upturned inhale. "
                    "Then the lower angular jaw rises during "
                    "exhale until the mouth is nearly closed, a narrow dark slit, then softly opens to the original. "
                    "Smooth succession of wood planes, no speech or repeated chattering. Preserve each bark highlight "
                    "and nose, brow, cheek silhouettes and existing teeth. Match the supplied almost closed midpoint."),
    "rejuvenation-idle": ("Single exact isolated upright green hand-painted maple leaf. Very gentle side to side "
                          "sway, a subtle flowing bend across the full leaf blade, with fixed end of the S-shaped stalk. "
                          "Natural fan flex, original dark greens and yellow high planes, no emission."),
    "rejuvenation-channel": ("Single exact isolated upright green hand-painted maple leaf. Stronger wider swaying with "
                             "a whole-blade bend. The same narrow edge of the blade constantly emits intense "
                             "purple-magenta with soft inward refraction. Full leaf glows green, brighter green is "
                             "concentrated on the central vein and its natural forks. Stable stem, maintain the paint."),
    "rejuvenation-impact": ("Single exact isolated green hand-painted maple leaf. Early unified pulse: full blade fan grows "
                            "30 percent, stalk base stays fixed. Broad pulse of luminous green over the full fan and "
                            "brilliant purple light through the original vein branches. Intense violet-purple leaf edge. "
                            "The pulse rapidly peaks at the first supplied lit pose then smoothly fades and the fan "
                            "returns exactly to its original size and position."),
}
LOCK = (" Lock composition and camera to provided registered artwork. Exact contour and materials. Keep the "
        "unadorned matte background and crisp painted texture. Smooth continuous motion.")
NEGATIVE = ("camera travel, duplication, altered design, blurred veins, film grain, emissive atmosphere, particles, "
            "glitter, added objects, morphing motifs, strobe, loss of contrast, photo, speech, blinking, added teeth")


def render(runtime, model, name, trial):
    folder = OUT/name
    group = folder/f"pass-{trial}"
    if group.with_suffix(".json").is_file():
        return
    job = json.loads((folder/"manifest.json").read_text(encoding="utf-8"))
    with np.load(folder/"guide.npz") as data:
        plate,alpha = data["rgb"],data["alpha"]
    support = np.any(alpha > 18, axis=0)
    if name == "treant-idle":
        # Limit motion to lower facial planes. More context stays available in the latent.
        support[:job["rect"][1]+int(job["rect"][3]*.48)] = False
    freedom = (.63,.42,.32,.25,.19)[min(trial-1,4)]
    encoder,mask,receipt = controls(runtime,plate,job["keys"],support,freedom)
    seed = 64217 + (list(PROMPTS).index(name))*619 + trial*97
    steps = 30 if trial == 1 else 34
    prompt = PROMPTS[name]+LOCK
    with ExitStack() as stack:
        stack.enter_context(encoder)
        stack.enter_context(mask)
        print(f"Rendering {name} pass {trial}",flush=True)
        now=time.monotonic()
        frames=runtime._generate_frames(Image.fromarray(plate[0]),seed,prompt=prompt,negative_prompt=NEGATIVE,
                                       width=SIZE,height=SIZE,num_frames=COUNT,
                                       num_inference_steps=steps,guidance_scale=5.5)
    assert frames.shape==(COUNT,SIZE,SIZE,3)
    assert receipt["encodes"]==receipt["masks"]==1
    raw=np.uint8(np.rint(np.clip(frames*255,0,255)))
    np.savez_compressed(group.with_suffix(".npz"),rgb=raw)
    from diffusers.utils import export_to_video
    export_to_video(frames,str(group.with_suffix(".mp4")),fps=16)
    receipt.update(model=MODEL, seed=seed, steps=steps, prompt=prompt, guideHash=digest(folder/"guide.npz"),
                   revision=model["runtimeArguments"],seconds=round(time.monotonic()-now,2))
    group.with_suffix(".json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(f"Saved {name} pass {trial}, {receipt['seconds']}s",flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("jobs",nargs="+",choices=PROMPTS)
    parser.add_argument("--passes",nargs="+",type=int,default=[1,2])
    args=parser.parse_args()
    if any(trial<1 or trial>(5 if "treant-idle" in args.jobs else 10) for trial in args.passes):
        parser.error("Pass outside the authorized review budget")
    sys.path.insert(0,str(LOCAL/"runtime"))
    from video_jobs import GpuReservation
    from wan_native_backend import NativeRuntime
    registry=json.loads((LOCAL/"model-registry.json").read_text(encoding="utf-8"))
    model=next(row for row in registry["models"] if row["id"]==MODEL)
    for attempt in range(31):
        try:
            reservation=GpuReservation(LOCAL/"data/gpu-reservation.lock")
            break
        except BlockingIOError:
            if attempt==30:
                raise
            if not attempt:
                print("Waiting for the LocalLLM GPU reservation",flush=True)
            time.sleep(4)
    try:
        runner=NativeRuntime(SimpleNamespace(model_id=MODEL,model_path=LOCAL/model["sourcePath"]))
        runner.load()
        for trial in args.passes:
            for name in args.jobs:
                render(runner,model,name,trial)
    finally:
        reservation.close()


if __name__=="__main__":
    main()
