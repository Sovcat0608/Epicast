# Restoration crest · independent layers

Drag **Restoration-layers.svg** onto a Figma Design canvas for the seven editable paint groups. Move a group, or hide the purple leaves to reveal the complete ivory leaves. Hide the static front to see the stems, the sprout foot and the wood behind the medallion. Each file in **PNG layers** also aligns at X = 0, Y = 0 on a 660 × 880 frame.

## Contact shadows in Figma

The plain SVG and PNGs contain the seven clean paintings. To pose the crest with live contact shading in Figma Desktop, extract the kit, then use **Plugins → Development → Import plugin from manifest** and select **Figma contact shadows/manifest.json**. Run **Epicast Restoration layer study** in a Design file. It creates a separate native frame with the seven paintings and closes. Each source component drives its instances using Figma's own component system.

Within the new frame, expand a named layer, expand its **source** component, and **move, rotate or hide its Paint child**. This changes both the visible artwork and its shadow masks. For the hand-and-paper test, move the purple Paint while the ivory Paint stays at rest. Then hide the purple Paint. The exposed white blade has its own painted volume and the contact shade from the purple disappears. The outer organizational frames and the locked contact groups establish the registration.

Each contact shadow is a softly blurred, offset silhouette visible only on a receiving surface beneath the caster. The neutral review setting uses 27% opacity, 2.35 px blur and a 1 px right / 3 px down offset. Local lighting on the wood or folds of a leaf is part of that object's own paint.

## Paint order

| Back to front | Layer | What the overlap does |
| --- | --- | --- |
| 1 | Static wood backdrop | Continuous crown, green backing, lower flank foliage, crossed roots and basal braid. |
| 2 | Upper green leaves | Complete upper and lateral sprays, inner foliage and centerline shoots. Their stems pass underneath the front branches. |
| 3 | Lower ivory leaves | Two entire pale leaves, from stem to tip. |
| 4 | Purple leaves | Both side pendants and the basal purple leaf. The side blades overlap the ivory and the basal petiole tucks under the medallion. |
| 5 | Central sprout | Two blades share a full stem. Its foot tucks behind the small wooden fork. |
| 6 | Crown glyph | A complete raised dot and crescent sit on the wood. |
| 7 | Static front | Grooved branch shoulders and center fork, both bracers, and the leaf medallion with two curled charms. |

The installed Restoration texture supplied the composition and painting reference. Each movable group came from its own transparent generation. The static front combines independently painted timber and fittings. Registration uses whole generated pieces, with scaling, placement and a uniform approximation of Epicast's 7% Druid desaturation. The generation originals, with their complete attachment ends, are included under **sources**.

**Restoration-pose-check.png** shows the resting stack, two opposing poses, the ivory reveal and the stack with the static front hidden. All 14 sampled stem and sprout attachment points stay covered across every integer translation from −8 to +8 px horizontally and −6 to +6 px vertically. The crown glyph sits on the face of the crest and has no hidden attachment. The source alpha, layer registration and overlap checks were verified locally. The native Figma result awaits a visual check in the desktop editor.

