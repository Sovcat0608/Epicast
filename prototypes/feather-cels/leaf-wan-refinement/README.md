# Restoration leaf motion review

This study covers the six crown and shoulder leaf layers in both Channel and Impact. The registered leaf paintings in `concepts/restoration-frame146/registered` are the reference source. Existing animation tracks are read for comparison and timing. No existing atlas is an input to Wan.

Channel aims for 1.5× the prior displacement and 1.2× the prior emission gain. It uses 16 cels over a third of a second. Impact aims for 2× the prior bend and 1.3× the prior emission gain. The first cel is already in motion, the second carries the shockwave peak, and the remaining ten settle over the rest of the one-second sequence.

1. Run `guides.py` with the LocalLLM image Python environment to build the fresh registered reference poses.
2. Run `generate.py` with that environment. The renderer uses the existing local Wan 2.2 TI2V-5B checkpoint and LocalLLM GPU reservation. `--trial 2 --steps 32` conditions the intermediate frames more tightly. Use `--segment` or `--state` to narrow a pass.
3. Run `inspect_trial.py --trial 2` for the raw canvas comparison and motion measurements. Record the chosen pass for each state in `review-selection.json`.
4. Run `register_preview.py`, `validate.py` and `gallery.py` in that order. Open `index.html` in the output folder.

The registered preview cels extract Wan's blade frames from their flat background, match exposure to the fresh guide, and retain the exact stem paint and boundary poses. Contact shadows are recomputed for the assembled preview. Raw model clips, references and verification are kept beside the previews under `artifacts/restoration-leaf-wan-refinement`. The cels are review masters for a later size-specific texture bake.

Run `bake_preview.py` after validation to refresh the two leaf tracks and their contact mask in the main `prototypes/feather-cels/index.html` preview. The full-crest Channel and Play impact controls use these tracks.
