# Restoration contact-shadow assets

[Open the Figma playground](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=483-262)

The 21 pieces use the current Restoration crest at its native 660 × 880 registration. Each piece has three matching PNGs, cropped to the same rectangle including space for the soft shadow. All dimensions are in pixels.

- **Paint** contains the clean artwork and its painted material shading.
- **Contact shadows** contains black with variable alpha. The close edge and soft shadow were generated from that individual piece.
- **Receiver masks** contains white with the exact alpha of the paint. Use a mask from the receiving piece and a shadow from the piece above it.

## Assemble a pair in Figma

1. Import a piece's Paint and Contact shadows PNGs. Align their horizontal and vertical centers at their original size. Put Paint on top and group the pair. Moving or rotating the group keeps the shadow registered. Reduce the shadow layer's opacity to soften it.
2. For contact confined to an underlying leaf, place the leaf paint first. Duplicate its alpha with the matching Receiver masks PNG, aligned exactly over the leaf. In a separate mask group, place this receiver mask beneath the bough's shadow and set the mask type to Alpha. Place the clean bough paint above that mask group.
3. Use **Rest positions.csv** to rebuild the full layout. Each X/Y is the top-left corner of the matched PNGs, measured from the crest's top-left. Stack by increasing number, back to front.

The Figma playground presents each loose piece as one transparent image with its individual contact shadow baked in. Use the separate PNGs in the ZIP to adjust shadow opacity or offset. In the assembled crest, move a **Pose** frame inside a source component so its linked shadows follow.

