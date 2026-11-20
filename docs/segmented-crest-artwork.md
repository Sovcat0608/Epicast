# Building a segmented Epicast crest

Use this standard for layered crest artwork across Epicast classes. Start with the approved crest for that class and spec. The Restoration study establishes how to construct, register and shade pieces. Its palette, motifs, dimensions and piece count belong to that particular design. Apply the relevant project painting rules alongside this guide. [Druid painting standard](image-generation-style.md)

## Decide what moves together

Before generating art, identify the silhouette, focal motif, material transitions and small identifying details in the reference. Sketch the stack from back to front. For each independently movable piece, record what attaches it, which part passes behind its neighbour, what it can reveal when it moves, and where it casts a shadow. A source sheet can contain several complete pieces. A crest layer can contain several pieces that share a pose.

| Design question | Restoration decision |
| --- | --- |
| What needs its own pose? | The outer vines and central leaf rosette form one moving segment. The leaf-and-moss backboard is complete behind the sprout and contains no duplicate dangling roots. |
| Where would a join break the illusion? | Each bough runs continuously from its curled crown tip through its fabric wrap to the medallion. Generate the boughs, wraps, painted symbols, medallion and hanging charms together. Their grain, folds, fittings and internal shading stay registered. |
| What must remain visible through motion? | Paint the full feather clusters, including the quills concealed by the purple fans. Give the left and right sides individual silhouettes while keeping the crest balanced. |

## Paint and register the pieces

1. **Generate each independent segment in isolation on transparent alpha.** Use the approved crest as a composition and paint reference. A cutout from the finished illustration has missing paint wherever another object covered it. Repaint those hidden surfaces and give the front object a complete silhouette. Cropping empty gutters between independently generated sprites on a sheet is fine.
2. **Paint through the attachment.** Extend a quill under its wrap or a branch end behind its medallion far enough to cover the intended travel. Put a fitting on the piece that physically carries it. Preserve the original carving, brush direction, proportions and lighting at the join. Paint creases and contact *within* a permanently joined segment directly into its materials.
3. **Register the resting pose on one canvas.** Choose recognizable anchors such as a cuff opening, sprout fork or charm eyelet. Apply one scale to both axes of each piece and lock its aspect ratio. Align by translating or rotating the whole piece. If an attachment still needs stretching to fit, revise the painting. Record canvas size, back-to-front order, dimensions and top-left positions so the rest pose can be reproduced.

## Lock placement and painting fidelity

1. **Record the pixel placement before generation.** For each existing asset, record its source, native canvas, pixel rectangle, orientation and pivot or visual anchor. Identify its fixed silhouette and motif landmarks, plus the exact edit region or permitted motion. For a new asset, lock registration once its resting pose is approved. Keep the approved model input and its registration data with every trial.
2. **Use the approved painting for the crest.** Match its material, local colours, brush scale, bevels, highlight direction, shadow colours and motif design. Compare the isolated asset and the assembly at their intended display sizes. Treat each sister or opposing segment as its own design.
3. **Enforce registration on the finished asset.** Check the original and candidate with an overlay or pixel comparison. Correct any global drift against the recorded landmarks. Verify the original canvas, alpha, anchored pixels and motif positions outside the authorized movement. Inside a moving layer, check the attachment point and travel envelope. For lighting-only work, keep the original silhouette and apply the result only through the registered light mask, with the original paint outside it. Verify the end poses and representative samples throughout a video. Retain failed raw trials as review material; correct drift before reusing them as crest assets.

## Make contact shadows follow the artwork

For a branch lying over a leaf, the **branch casts** and the **leaf receives**. Generate a black, variable-alpha shadow field from the clean branch silhouette. Use a tight soft edge for contact and a wider, softer falloff concentrated where the branch approaches the leaf. Keep light direction consistent across the crest. Tune softness and offset at the intended display size. On Restoration’s 660 × 880 working canvas the close edge uses a 1 px right, 3 px down offset and 2.5 px blur, with broader 6–10 px blurs in selected overlap zones. These values are a starting example. [Reference implementation](../concepts/restoration-independent-v2/register.py)

In the editable Figma master, keep **Paint** and **Contact field** registered inside the caster’s **Pose**. On each intended lower receiver, draw its clean paint, then a shadow-only instance of the caster clipped by an alpha-mask instance of that receiver. Draw the caster’s own paint at its level in the stack. Moving the branch now moves its shadow. Moving or hiding the leaf changes where that shadow can appear. Include neighbours the caster can reach across its intended motion. When changing stack order, update the caster/receiver links as well.

Shading can darken existing paint while preserving its alpha. Gaps between vines, spaces between feathers and the transparent area beyond the crest should stay open. A soft shadow permanently painted onto a movable neighbour will leave a dark stain when the pieces separate.

When both the caster and receiver move, sample their poses independently. Restoration uses the current banner cel to cast onto each shard at its current slide position. Idle and Impact follow their cel timelines. Channel uses its own cel timeline and sampled blend levels during its ramps. A hidden banner uses a contact variant with its shadow removed. Each variant keeps the receiver's alpha.

## Keep the master editable and the loose assets portable

- **Editable crest.** Retain the isolated source paintings, clean registered layers, rest positions and linked contact fields. The master is the source for future repositioning, animation and rebakes. [Restoration master](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=449-140)
- **Shadow-ready assets.** Export clean RGBA paint, the piece’s own black-alpha shadow, and a white receiver mask with exactly the paint’s alpha. Crop all three to the same rectangle covering both paint and shadow, including the soft falloff. Record that rectangle’s top-left canvas coordinate and stacking position. Generate a fresh field for each individually movable loose piece, including pieces grouped together in the full crest. [Asset exporter](../concepts/restoration-shadow-playground/export.py)
- **Merged loose artwork.** For a copy-ready gallery, composite each piece’s paint over its own shadow on transparency at native size. Keep its dimensions and registration. In this version the shadow is part of the image and travels with it, including over empty space. Use clean paint in the linked master so a baked shadow and a linked shadow never darken the same contact twice. [Restoration playground](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=483-262)

## Bake size-specific runtime textures

Use the approved Restoration bake for every shipped segment, including still pieces and each authored Idle, Channel and Impact cel. Work from the same unsharpened registered source for every size. Resolve the segment's contact shading before sampling so it stays in register with the paint.

1. Downsample with premultiplied-alpha **Lanczos2**. Then apply one pass of the shared linear-light **CAS at sharpness 1.0 and blend 0.65**. Keep the sampler's alpha byte-for-byte through sharpening, with the existing CAS protection around transparency. Reuse the [shared sampler](../tools/artwork/Build-SkycutterSizes.cjs) and [CAS implementation](../tools/artwork/Build-SkycutterCAS.cjs).
2. Scale every registered crop in proportion to the crest’s canvas. Restoration uses full-crest widths of **192, 288, 384, 480, 576 and 660 pixels**. Use the crest’s own canvas and supported sizes for other artwork. Pack the finished cels into power-of-two RGBA TGA atlases with transparent gutters and explicit UV coordinates. [Restoration segment packer](../tools/Pack-RestorationSegments.cjs)
3. Select the smallest bank that covers the requested physical-pixel width, using effective UI scale and the existing screen-height conversion. Use the largest bank when display metrics are unavailable or the requested width exceeds the bank. Keep registration, animation time, and native hover phase through a size switch.
4. Verify every bank’s frame count, alpha, atlas gutters, and alignment. Check the decoded art at representative UI sizes for clean contours, readable details, and flicker between cels. Record the source, recipe, and media hashes with the bake.

## Check the build

1. Compare the assembled rest pose with the approved reference at working size and actual UI size. Restoration was checked at 162 × 216. Look for lost glyphs, stretched medallions, floating attachments, noisy detail and visible seams.
2. Solo each clean layer. Hide, translate and slightly rotate overlapping pieces through their intended travel. Check that concealed paint is complete, attachments still meet, and the backboard contains no second copy of a movable motif.
3. Toggle contact shadows at the same pose. Move the caster, then move or hide the receiver. Verify that the shade follows the caster, respects the receiver silhouette and disappears from empty space. Inspect edges over both light and dark backgrounds for matte fringes or clipped falloff.
4. Reassemble the exported art from its recorded coordinates. Verify native proportions, back-to-front order and transparent bounds. For a merged gallery, check that each loose asset copies as one image. For a linked Figma crest, verify an actual pose change and inspect the rendered result. [Restoration build and verification](../concepts/restoration-independent-v2/README.md)

This standard covers artwork authoring and review. Runtime integration, spell bindings and animation timing follow the brief for the individual crest.
