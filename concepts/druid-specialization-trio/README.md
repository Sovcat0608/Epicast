# Druid specialization sisters — review concepts

**V8 integration update, 2026-11-16:** the user approved the v8 repaint for all three runtime crests. Beta.9 uses that exact source PNG through the existing size-specific conversion pipeline. See `../../docs/class-crests.md` and `../../docs/release-0.1.0-beta.9.md`. Historical review-only statements below describe the earlier review stages.

**Integration update, 2026-11-16:** the user approved v6 for the addon. Its exact PNG is now the source for beta.8's Restoration / Balance / Feral runtime crests. Source artwork and all review versions remain unchanged. Preparation, migration and test evidence are in `../../docs/class-crests.md`; build/install evidence is in `../../docs/release-0.1.0-beta.8.md`. The historical review-only statements below describe the earlier review stages.

## Current review: v8, angular forms and larger painted strokes

The user preferred their supplied reference over v7 and clarified the missing traits: angular root forms, chunky bevels, bigger confident brushstrokes, saturated colour and dramatic warm highlights/cool shadows. `reference-painting-review-v8.md` records an element-by-element comparison of roots, cuffs, leaves, feathers, ivory, stone, fur and symbols.

`Druid-specializations-review-v8.png` uses **only the user's supplied repaint** (`references/v7/Warcraft-style-user-repaint.png`) as the composition, iconography and rendering reference. V6/v7 were not generation inputs. All three crests were repainted together with built-in `image_gen`; the opaque navy backdrop was replaced by generated transparency. The result uses more angular root bends and brush wedges, faceted ivory/stone bevels, grouped material strokes and warm/cool separation. Established focal motifs, ornaments and directional gouges remain visually recognizable; exact pixel identity is not claimed.

Exact prompt: `prompt-v8.txt`. Native output **1882 × 836 RGBA**, copied unchanged. SHA256: `4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8`. All corner alpha values are zero and no canvas-edge pixel reaches alpha 128. Metadata: `verification-v8.json`. Original retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-0b206cf1-b85d-4038-bc28-153977d9f692.png`.

Artwork review only. Installed beta.8 still uses v6. No runtime textures/code, ZIP, installation or SavedVariables were changed for this iteration. Source-art review does not establish in-game acceptance.

## Previous review: v7, smoother and more vibrant painted finish

The user reported that v6 looked too realistic, muted and noisy in game, and supplied a smoother repaint reference. `Druid-specializations-review-v7.png` repaints all three crests together with built-in `image_gen`, using v6 for content/composition and the user's image for painted finish and colour. Research and source links are in `warcraft-style-research.md`.

The new treatment uses broader continuous shading, fewer tiny material marks, grouped fur locks, and stronger green/violet/blue colour relationships. The sprout, moon, paw, six root bracelets, medallions/charms, flowing leaf and feather patterns, and outward stone gouges remain visually recognizable. Wood/ivory/stone identities and the three distinct silhouettes are retained; this is not pixel-identical preservation. The user's opaque navy backdrop was excluded.

Exact prompt: `prompt-v7.txt`. References: `Druid-specializations-review-v6.png` and the exact user attachment copied to `references/v7/Warcraft-style-user-repaint.png`. Native output **1882 × 836 RGBA**, copied without resizing or repainting. SHA256: `B65EE01D01384DC1782DB3A989BC2489503D1CB7F5B3995251CA2CD116F7D688`. All corners are transparent; no canvas-edge pixels have alpha at least 128. Metadata and reference hashes: `verification-v7.json`.

Reviewed visually for smoother surfaces, stronger colour, retained motifs and complete silhouettes. This is **artwork review only**: v6 remains the installed beta.8 source, and no runtime asset, code, ZIP, installation or SavedVariables was changed for this repaint. In-game readability and any later registration adjustments remain unverified.

## Previous review: v6, flowing druidic patterns and outward stone gouges

The user requested organic druidic patterns in place of the isolated symbols on the large leaves and feathers, plus more prominent Feral stone scratches aligned with each outward projection. `Druid-specializations-review-v6.png` edits the complete v5 trio together with built-in `image_gen`.

Restoration's two large purple side leaves now carry pale branching curves following the midribs and lobes. Balance's two large feathers carry elongated teal markings following the shafts and diagonal barbs. Feral's paired stone wings have broad, deep, dark gouges running along their outward stepped projections, with the inner ends partially concealed by the existing frame. The separate central paw scratches, six root bracelets, medallions, charms and other established motifs remain visually preserved. This does not imply exact pixel identity outside the edits.

Exact prompt: `prompt-v6.txt`. Sole reference/edit target: `Druid-specializations-review-v5.png`. Visually inspected for the flowing surface patterns, outward scratch direction and retained major shapes. Native output **1881 × 836 RGBA**, copied without resizing/repainting; all corner alpha values are zero. SHA256: `19B8EF379608373439750C592AFEEECFE9498C2719E2BC9B7B0201AEE5871B8B`. Metadata: `verification-v6.json`. Original retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-9f2585c2-a81e-40b0-8963-d9bc1ba4bcd3.png`.

Artwork review only on `main`. Runtime textures/code, ZIPs, installation and previous concepts remain unchanged. SavedVariables were not accessed. Runtime small-size readability, cutouts and emission masks remain future work.

## Previous review: v5, root bracelets and prominent marked side accents

The user requested the original spiral bracelets on all three designs, wrapping the mid-side roots, plus larger marked feathers on Balance and larger marked purple side leaves on Restoration. `Druid-specializations-review-v5.png` edits the complete v4 trio together using built-in `image_gen`.

Six swept-rim spiral cuffs now wrap the paired root arms: light carved-wood tones for Restoration, pale ivory for Balance and warm carved natural tones for Feral. Restoration has two larger projecting purple side leaves with pale druid symbols, attached beneath the cuffs; its single purple leaf in the lower root tangle remains. Balance has two dominant broad downward-facing ivory/slate-blue feathers with contrasting druid symbols, emerging from its cuffs, with reduced competing side foliage. Feral receives the cuffs while retaining its existing paw, striped fur, fangs, stone scratch groups, medallion, tooth charms and bottom feather taper.

Exact prompt: `prompt-v5.txt`. Direct references: v4 as the edit target; the user's bracelet attachment copied to `references/v5/Root-bracelet.png`; and the two existing glyph references in `references/v3/`. Visually inspected for cuff placement, the two prominent marked purple side leaves, two large downward marked feathers and retained key motifs. This is visual preservation through generation, not exact pixel identity of all untouched regions.

Native output **1882 × 836 RGBA**, copied without resizing/repainting; all corner alpha values are zero. SHA256: `A5B5277B3FBA4F9D153916F391A402CB45C1E46998D7E073B8D2869629EF3A8A`. Metadata: `verification-v5.json`. Original retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-5676392d-8ad4-466f-97fd-2f211c546ad8.png`.

Artwork review only on `main`. No runtime textures/code, ZIPs, installation, previous concepts or SavedVariables were changed. Cutouts, emission masks, runtime registration and in-game readability remain separate future work.

## Previous review: v4, targeted material and lower-silhouette revisions

The user praised v3 and requested minor scoped edits while maintaining its other features. `Druid-specializations-review-v4.png` is a built-in `image_gen` edit of the entire approved trio together, preserving the order, scale, central motifs, medallions/charms and established material/style identities.

- **Restoration:** darker carved-wood top cap with a more organic outline; slightly enlarged purple leaves; lower green leaf skirt replaced by sculptural entangled roots, retaining the central purple leaf beneath the wooden medallion.
- **Balance:** darker interwoven wooden roots; exposed bottom root tail replaced by a pale interlocking ivory flourish. Stone centre, moon medallion, stars and antlers retained.
- **Feral:** lower-middle side feather groups replaced by stepped projecting stone pieces with matching sets of three prominent claw gouges. The bottom central fur tuft becomes an ivory/blue-grey feather taper. Ears, striped upper fur, ivory paw, fangs, medallion and tooth charms retained.

Exact prompt: `prompt-v4.txt`. References: the complete v3 image as the edit target and `references/v4/Stone-side-shape.png` (the user's attachment) for the protruding side-piece shape only; that silhouette is rendered as stone. All three were edited together in one render. This is visual preservation through image editing, not a claim that all unchanged regions are pixel-identical.

Exact generated **1881 × 836 RGBA** output copied without resizing/repainting. SHA256: `72D091AF59A6814415F3FAA4A0F81159E1C80373F40D11C375675DB741C53086`. Metadata: `verification-v4.json`. Corners have alpha zero; no canvas-edge pixels have alpha >=128. Faint generated RGB residues exist in near-transparent pixels (for example a sampled red residue has alpha 1/255); the native alpha channel is preserved. Source retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-ca23571b-d861-4c78-8812-d40aa559bec4.png`.

Visually inspected for the requested root/leaf/ivory/stone/feather replacements and matching Feral stone scratch groups. Runtime sampling, mask extraction and future emission effects have not been implemented or tested. Review only on `main`; earlier concepts, runtime assets/code, ZIPs, installation and SavedVariables remain unchanged.

## Previous review: v3, natural medallions and stronger material identities

The user requested a fresh joint regeneration with closer matching size/foundational shape, distinct characteristics, one lower medallion plus two side charms for each crest, and complementary druid glyphs/feathers. `Druid-specializations-review-v3.png` was generated **all three together in one built-in image_gen render**, left to right Restoration, Balance, Feral.

- **Restoration:** retained living sprout/root cradle, with contrasting warm carved wood/bark replacing the metallic-looking fittings. One wooden Rejuvenation maple-leaf medallion, flanked by curled-root charms. Green/plum leaves, feathers and nature glyphs support the healing identity.
- **Balance:** stone central zone and lower moon medallion, paired star charms, ivory antlers with large stylized etched crack channels, small root thorns, feathers and druid arc/dot glyphs.
- **Feral:** prominent paw on an ivory centre, animal ears instead of horns, pale fur with dark tiger-like stripes, larger claws/fangs, one ivory fang-engraved medallion and paired tooth charms. Feathers, leaves, roots, wood and small supporting stone accents preserve the druid family.

The overall crest scale and oval/tapered foundations are closer than v2, while material and silhouette accents remain individual. Visually inspected for the correct medallion/charm allocation, central materials, paw, ears, stripes, antlers and shared strong contrast. Runtime small-size sampling and emission masks remain future work.

Exact prompt: `prompt-v3.txt`. References supplied together: v2 for prior crest context, and all four new user attachments copied unchanged to `references/v3/` (Rejuvenation leaf, two druid glyph examples, and striped pale fur/feathers). No per-sister compositing or separate generation was used.

Exact native output **1881 × 836 RGBA**, copied without resizing or repainting. SHA256: `A197D2048E3397F96A739E056B23DB58D04B718B469DD5CFDCCD0FCC97242C89`. All four corner alpha values are zero; no pixels on the four canvas edges have alpha >=128. Metadata: `verification-v3.json`. Original retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-0a71b55b-a064-427f-874d-176ad02fc7e9.png`.

Artwork review only on `main`. Previous concepts, approved/runtime assets, code, build ZIPs and installation remain unchanged. SavedVariables were not accessed; nothing was committed or published.

## Previous review: v2, installed-pair structure and Feral paw

The user found v1 too similar in direct shape/structure, requested review of the current installed sister pair as the Restoration/Balance foundation, and specified a paw for Feral's central zone.

Read-only review confirmed that installed `MoonwardenCASSize768.tga` and `GroveheartCASSize768.tga` exactly match the repository runtime assets; their build provenance points to `../druid-sisters/Moonwarden-Groveheart-review.png`. That full original source was inspected and supplied as the sole generation reference. Hash evidence is in `live-pair-review.json`. No game UI/screen automation or SavedVariables access was performed.

`Druid-specializations-review-v2.png` was generated **all three together in one built-in image_gen render**, left to right:

- **Restoration:** original Groveheart's broader rounded root cradle, living sprout, green foliage and substantial braided lower taper.
- **Balance:** original Moonwarden's taller, narrower flowing structure, asymmetrical sweeping branch crown, crescent and layered violet foliage.
- **Feral:** a lower, broader angular stone/root structure with a clear central animal paw (large pad plus four toe pads), fur, ivory fangs, supporting scratches and green leaves. Its short outward crown branches distinguish its silhouette.

The shared materials and painterly finish connect the trio while crown, shoulders and lower structure vary. Visually inspected for three complete crests, recognizable original-pair identities, a readable central paw and distinct silhouettes. Small-size runtime readability and actual in-game rendering remain untested. No exact pixel reuse of the original pair is claimed; this is a new concept render based on them.

Exact prompt: `prompt-v2.txt`. Native source **1881 × 836 RGBA**, copied without resizing or repainting. SHA256: `680F62C6C633687D16748E130CC08FA810B54014AC7AC4366BD620ECF522F02C`. All four corner alpha values are zero; metadata is in `verification-v2.json`. Original output retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-1573d3c2-69ab-4396-92f6-ef3f5f2c1be0.png`.

Review only on `main`. Existing approved/runtime artwork, code, ZIPs, installation and SavedVariables remain unchanged. V1 is retained below as the previous concept.

## Previous review: v1

Created 2026-11-16 with built-in `image_gen`, **all three together in one render** at the user's explicit request. Left to right: **Restoration, Balance, Feral**. This follows the user's decision to reduce the complexity/intensity of Groveheart restoration v5 and distribute thematic identity across three matching sisters.

## Artwork

`Druid-specializations-review-v1.png` is the exact generated **1881 × 836 RGBA** source, copied without resizing or repainting. SHA256: `4DF558647A644CAB1BCFFBBFF50C6A8456780FFE50D698BE7ACDFE6E379B8131`.

- **Restoration:** prominent three-leaf/sprout heart, warm wood and green stone, a few large green/violet leaves and one pale flower.
- **Balance:** prominent ivory crescent, violet-grey stone, restrained stars/arcane accents, root framing and broad dusk-coloured leaves.
- **Feral:** prominent claw gouges, ivory fangs, grouped tawny fur, rugged carved wood, stone, roots and substantial green leaves.

Shared horned crest proportions, crown height, lower taper, material treatment, lighting and weight establish the family. Each uses larger focal forms, fewer trinkets and quieter surfaces than v5. All three retain branches, leaves, wood and stone. The specific branch/root curves, foliage and supporting accents vary by sister.

The source was visually inspected for three complete distinct crests, coherent shared scale/registration, clear central motifs, material separation and reduced ornamental density. The designs aim to read at the existing 162 × 216 UI size; actual runtime sampling and in-game readability have not been verified.

## Provenance and transparency

Exact prompt: `prompt-v1.txt`. Sole image reference: `../groveheart-restoration/Groveheart-restoration-v5.png`, explicitly used for the Warcraft crest family and painterly material fidelity, with its density identified as something to reduce. No separate per-sister generation or compositing was used.

Original generated file retained at `C:/Users/info/.codex/generated_images/01a1df15-f1c7-7d50-acd4-1cfa1c7e3f2d/exec-bb54765b-51f6-4501-9f40-2ee268fa8fea.png`. Metadata: `verification-v1.json`. All four corner alpha values are zero. Visual separator columns near x=634 and x=1240 have maximum alpha 1/255 from faint generated residual pixels; no pixels reach alpha 8 there. The original alpha is preserved. Individual cutouts and runtime texture preparation are future work.

## Scope

Artwork review only on `main`. No production assets, code, settings, ZIPs or installation were changed. SavedVariables were not accessed. Previous concepts and the retired animation R&D files remain preserved. No additional animation work, commit or publication was performed.
