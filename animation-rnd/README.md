# Epicast Druid bitmap animation R&D

Completed 2026-11-16 on local branch `animation`. This is a standalone experiment, with no runtime integration or installation.

**Start with [the review page](previews/index.html)**. It contains the combined composition, original/animated comparisons, close-ups, masks and mesh previews. [Technical findings](reports/findings.md) describe the results and remaining limitations.

## Source and scope

The brief's “Druid Artwork V2” description refers to the latest accepted crest architecture with leaf symbols and subdued colours. The exact input is `concepts/groveheart-restoration/Groveheart-restoration-v4.png`, copied unchanged into `source/`. It is **1086 × 1448 RGBA**, SHA256 `789d35f8bbf7f55114ff681ea6e5cd9973844eec0d92f15722cbc6bbb331f430`. No illustration was regenerated, repainted, sharpened or downscaled for the frame exports.

| Experiment | Frames | Rate | Duration | Moving content |
| --- | ---: | ---: | ---: | --- |
| A — foliage | 32 | 20 FPS | 1.6 s | Four clearly separated lower leaves, with different bend timing |
| B — moss | 24 | 20 FPS | 1.2 s | Three hanging strands beside the upper-central stone |
| C — leaf | 24 | 20 FPS | 1.2 s | Central leaf and its existing painted cyan contour |

The first and last frames reproduce the exact resting pose. Frame `i` is displayed at `i/20` seconds for 50 ms. Motion is parameterized by `i/(count−1)`, so the final frame is already at rest for the last 50 ms.

## Deliverables

- `source/`: untouched PNG and brief, transparent extracted layers, reconstructed local plates, and `static-base.png`.
- `masks/`: full-coordinate masks, protected foreground, segmentation previews and inspection crops.
- `rigs/`: editable JSON polygons, mesh vertices, triangles and fixed anchors.
- `animations/`: deterministic motion settings, sampled key poses and the combined-preview timing.
- `frames/<experiment>/patch/`: 80 final RGBA replacement-patch frames on the original **1086 × 1448** canvas.
- `frames/<experiment>/isolated/`: 80 corresponding transparent moving-layer frames for inspection and further compositing.
- `atlases/`: cropped native-resolution PNG and uncompressed 32-bit TGA atlases, with JSON frame rectangles, UVs, original-coordinate offsets, timing and three-pixel gutters.
- `previews/`: native-resolution MP4s, lighter GIFs, full-composition previews, side-by-side comparisons and sampled-frame contact sheets. Checkerboards are present only in previews.
- `reports/`: findings, machine-readable validation, manual-review annotation, technique benchmark and retained refinement evidence.

For an exact ordinary-alpha composition, draw `source/static-base.png` and one **patch** frame for each of A, B and C, all at the original origin. Their rectangles do not overlap. Play each motif independently and use frame zero when idle. The base has the three patch rectangles removed, so no stationary original foliage remains beneath a moving patch. Raw `isolated` variants are useful cutouts; the patch variant also preserves local occlusion and the source's partially transparent painted edges.

## Reproduce

Use Python 3.12 and the pinned `requirements.txt`. Dependencies install only into this directory's ignored `.deps/` folder:

```powershell
.\animation-rnd\Build.ps1 -Python 'C:\path\to\python.exe' -InstallDependencies -Validate
```

On the machine used for this experiment, the bundled Python was:

```text
C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt\dependencies\python\python.exe
```

Use `-PrepareOnly` to inspect masks and plates without rendering. The final `rigs/regions.json` and `animations/motion.json` are the authoritative inputs. The three `refine_*.py` scripts document the completed development passes; do not rerun them during a normal build.

After a build, `scripts/finalize.py` refreshes the combined preview, review annotation and file inventory. `scripts/evaluate_techniques.py` is an optional one-pose affine/TPS benchmark; it does not alter animation frames. Timings naturally depend on the host. Core bitmap outputs are deterministic in the recorded environment; other library/platform versions are not claimed byte-identical.

Validation currently passes **463 checks**, including all 80 repeated frame renders, exact rest/loop identity, static landmarks, PNG/TGA atlas round trips and unchanged protected repository/source files. Runtime code, approved assets, existing animations and SavedVariables were not changed or accessed outside the documented source reads. No WoW playback or installation has been performed.
