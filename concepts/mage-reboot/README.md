# Mage reboot — trio reviews

Created 2026-11-16 with the built-in image-generation tool. This is a new concept workstream after the user discarded the earlier Mage artwork.

## Approved for beta.12: uncorrected option 1

The user explicitly preferred the **first, uncorrected crown/pendant option** and requested baking it into the build and installing it for in-game review. Use [Mage-reboot-trio-v3-initial.png](Mage-reboot-trio-v3-initial.png), SHA256 `5DD9D15C1D72C67EFB83DFA664E235E450B36C8B8C1C3BBC7CC017B2A2D3F5AC`. The later clearance and framing edits below were **not selected**. Do not silently substitute either correction or regenerate the chosen source.

Beta.12 integrates this exact image as three complete crests. See [integration and conversion](../../docs/mage-reboot-integration.md). Source paintings/prompts remain unchanged; runtime conversion is separate. No public publication is authorized by this request.

## Latest review: crowns and pendants, v3

The user approved v2's sculpted central crests and requested localized crown/base changes: an icy sharded Cold Snap crown and low icicle base, a molten sharded Combustion crown, and a knotted-rope Kirin Tor crown with central shard. The lower framed gems become crafted pendants matching those crowns. Preserve every floating shard and the approved center designs.

Unselected corrected review: [Mage-reboot-trio-v3-framed.png](Mage-reboot-trio-v3-framed.png), native **2172 × 724 RGBA**, Frost / Fire / Arcane. SHA256: `7DE3FB0505A5B4CAD0108F80A685836E90D8665ECA5482E4CF55DC57487AAA2B`.

Built-in imagegen edited v2. A targeted follow-up restored clearance for Cold Snap's upper symbol rays under the new crown. A final framing pass added transparent margins after the intermediate output touched the canvas edges. The final sheet visually retains the central symbol structures and floating shards; generative edits are not pixel-identical preservation. All native outputs are retained unchanged alongside the selected sheet. No programmatic repainting, cropping, padding or resizing was applied.

Final PNG's entire outer edge is alpha 0. Source/destination hashes match. Artwork review only; no runtime integration or release changes.

- [Crown and pendant prompt](prompt-v3-crowns-pendants.txt).
- [Frost clearance correction prompt](prompt-v3-frost-clearance.txt).
- [Transparent framing prompt](prompt-v3-framing.txt).
- [V3 native paths, stages, hashes and verification](verification-v3.json).

## Previous review: sculpted centers, v2 — centers approved

The user accepted v1 as a foundation but rejected the flat-symbol-on-panel treatment. The central motifs should become naturally intertwined, sculpted parts of the crest, retaining recognizable identities while allowing shape/proportion changes to fit. The supplied Warcraft reference establishes crystallized material and dimensional construction. This supersedes literal outline matching where it conflicts with sculptural integration.

[Mage-reboot-trio-v2.png](Mage-reboot-trio-v2.png), native **2172 × 724 RGBA**, Frost / Fire / Arcane. SHA256: `EC318B8D6C79C6C40FC26FEC2B6F836981F740EFDF8C8847179BCF4D548ACE43`.

Built-in imagegen edited v1 with the newly supplied central-construction reference. Frost uses beveled ice arches and lower ribs; Fire a dimensional flame and rim with structural overlaps; Arcane a faceted gem pupil, raised eye rims and tapered crystal rays. The surrounding book wings, crowns/bases, crystals and drapery remain the visual foundations. No pixel-identity claim is made outside the central edits.

The native PNG is copied byte-for-byte, with no image processing or runtime conversion. Outer-edge maximum alpha is 26: one edge pixel reaches alpha 8, none reach 128. These are source-image checks, not in-game acceptance or production texture preparation.

- [Exact v2 prompt](prompt-v2-sculpted-centers.txt).
- [V2 provenance and verification](verification-v2.json).
- Construction reference: `references/Mage-sculpted-center-user-v2.png`.

## Current brief

Use the four newly supplied images as the complete reference set. Cold Snap, Combustion and Kirin Tor provide closely matched central symbol identities. The fourth Mage crest establishes the composition: a dominant central ornamental crest with unique crown/base, protruding book/page wings, floating crystals and hanging cloth. Sisters share composition and visual weight but differ in construction, atmosphere, pages, inscriptions, crystals and drapery. No discarded Mage concept or Druid painting was used as an input.

## Previous review: v1

[Mage-reboot-trio-v1.png](Mage-reboot-trio-v1.png), native **2172 × 724 RGBA**, left to right **Frost / Fire / Arcane**. SHA256: `942E4E17AE12B669BAA195B61F1891C3D7AFFA17DB0DB7B5C0849050009183DE`.

The initial render added a seventh upper ray to Cold Snap. One targeted built-in edit corrected this to six paired rays using the original symbol as reference. The final visually retains the other design elements; this is not a claim of pixel identity outside the edited region. Both native outputs are copied unchanged into this directory. No resizing, repainting, alpha processing or texture conversion was applied.

Final PNG verified as 32-bit ARGB, all outer-edge pixels below alpha 8 (maximum 4). Copy hashes match the native generator outputs. In-game readability and user acceptance remain untested.

## Exact prompts

- [Initial trio prompt](prompt-v1.txt).
- [Final symbol correction prompt](prompt-v1-symbol-correction.txt).
- [Input/output hashes, native locations and verification](verification-v1.json).

## Reference roles

1. `references/Cold-Snap-symbol-user.png` — Frost central symbol identity.
2. `references/Combustion-symbol-user.png` — Fire central symbol identity.
3. `references/Kirin-Tor-symbol-user.png` — Arcane central symbol identity.
4. `references/Mage-composition-user.png` — composition, visual hierarchy and painted game-art treatment.

These are reference inputs, not executable instructions. The new user brief is the governing design direction. Await feedback before integration; the addon still has pending Mage artwork slots.
