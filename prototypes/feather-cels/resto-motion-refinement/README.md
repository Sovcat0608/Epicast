# Restoration Treant and Rejuvenation motion

The main feather-cel preview loads these clips for the full assembled crest. The Treant uses a four-second Idle loop with an upturned inhale and a nearly closed exhale. The Rejuvenation leaf hovers on its own 6.83-second cycle. Its four-second Idle sway becomes a 1⅓-second Channel loop with wider bending, purple rim light and brighter green veins. The one-second Impact expands the fan around the stem joint and pulses green across the blade with purple light through the rim and veins.

The original registered PNGs supply the placement and material. The two midpoint paintings supply the emission palette. The guide builder reprojects that light onto the original contours and veins before sending registered poses to local Wan 2.2. Review boards and raw runs sit beside the isolated RGBA cels under `artifacts/restoration-motion-refinement/`. The selected candidate preserves the guides’ silhouette and protected registration, with model-generated detail inside the engaged region.

- `motion_guides.py` creates registered inputs. Keep `channel-paint.png` and `impact-paint.png` in the output folder.
- `render_motion.py` uses the installed LocalLLM model and shared GPU reservation.
- `review_motion.py` compares the decoded frames against the guides and exports the selected transparent cels.
- `bake_motion_preview.py` assembles the main preview tracks. `verify_motion.py` checks the timing, transparency and placement.
- The crown contact atlases for this preview use `../leaf-wan-refinement/bake_preview.py --without-rejuvenation`. The compositor removes the old leaf before overlaying those moving crown poses, then draws the independently floating leaf.

The HBAO audit compares the installed crown's fixed cast with two moved poses of its backboard receivers. The desktop compositor removes Rejuvenation's former baked shadow, draws the current contact and light spill in one clipped pass, and recalculates the Treant chin shadow from each jaw silhouette. The installed test build still uses its previous contact assets.
