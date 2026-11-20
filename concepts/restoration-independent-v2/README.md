# Restoration crest repaint

Open **Restoration-layers.svg** in Figma to inspect the nine transparent groups at their resting positions. For the movement test, use the native Figma setup below. **Restoration-shadow-comparison.png** shows the same painting on the same gray background with contact shading off and on.

## Test the overlap in Figma

1. Extract the ZIP. In Figma Desktop, use **Plugins → Development → Import plugin from manifest** and choose **Figma contact shadows/manifest.json**. Run **Epicast Restoration · layered repaint** in a Design file.
2. Expand **Purple leaves**, then its **source** component. Select the **Pose** frame. Nudge it sideways or rotate it slightly. The nearby white feather keeps its quill and vane, and the contact shadow travels with the purple leaves. Hide **Pose** to reveal the whole feather and remove the shadow it receives from the purple leaves.
3. Move **Pose** inside **Dangling roots** to test the roots independently. Toggle **Night elf boughs, medallion and charms** to lift away the whole branch and jewelry painting.
4. Toggle a receiver's **Contact shadows · linked** group to compare the shading on just that layer. Pose the artwork inside the source components so Figma updates all their linked instances.

The SVG includes resting contact shadows as individual images inside the casting groups. Those images retain their resting receiver shapes. The native Figma setup re-masks the shading to the visible receivers when an object moves. The native setup has been checked locally for its mask links. Visual acceptance in Figma Desktop is pending.

## Artwork

| Back to front | Group | Construction |
| --- | --- | --- |
| 1 | Dangling roots | Two curling olive vines flank a tapered rosette of layered green leaves. The whole segment moves independently. |
| 2 | Leaf and moss backboard | Carved crown, pressed green leaves and settled moss under the sprout. |
| 3 | Crown and understory foliage | Separate sprays around the crown, shoulders and sides. |
| 4 | Central sprout | Two green blades above a continuous stem. |
| 5 | Striped white feather clusters | Three overlapping white feathers per side with muted violet bars. |
| 6 | Purple leaves | Two side fans and one basal purple leaf. |
| 7 | Carved sprout fork | Short fork with an incised spiral beneath the sprout. |
| 8 | Night elf boughs, medallion and charms | One painted segment includes violet cloth, white moon and tree glyphs, the maple stamp and both gold charms. |
| 9 | Crown glyph | Raised dot and crescent. |

All registered PNGs use a **660 × 880** canvas and align at **X 0, Y 0**. **PNG layers** contains the nine clean groups. Follow the paint order above when stacking the PNGs. **Individual pieces** breaks the multi-piece groups into clean registered paintings for moving a single feather, leaf or branch. Use one copy of the target group or its pieces. The original generation sheets, exact prompts and reference crops are under **sources**.

Every registered piece uses one scale for both axes. Placement is adjusted independently to keep the quills beneath the bracers, the sprout stem behind the fork, and the charm hooks aligned with the carrying branch.

The current repaint sources are `sources/night-elf-boughs.png`, `sources/striped-feather-clusters.png` and `sources/moss-backboard.png`. The independent root painting is `sources/vines-and-foliar-rosette.png`. [Editable Figma crest](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=449-140)

Contact shading uses a soft close edge plus broader localized soft shade around the shoulder foliage, bracer and leaf overlaps, fork, feathers and jewelry. Each field follows its caster. Only visible receiving paint beneath it is darkened. The dark bark recesses and leaf folds belong to the individual paintings. **Restoration-pose-check.png** shows two offset poses, an independent root offset and a view beneath the branch and jewelry painting. **Restoration-layer-guide.png** shows all nine groups alone.

Rebuild the PNGs, plates, SVG and native setup with `python -B export.py` in this folder using Pillow and NumPy. The plate labels use Segoe UI on Windows. `register.py` records the whole-sprite registration and local shadow settings. `sources/verification.json` contains the export checks and paint-source hashes.

