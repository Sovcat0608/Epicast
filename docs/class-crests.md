# Class crest slots — beta.10 / schema 4

**Historical layout description.** Beta.11/schema 5 replaces shared set placement and physical-side selection with independent crests. See [independent-crests.md](independent-crests.md) for the current model, UI and migration. The binding migration history below remains relevant. Mage artwork and direction were subsequently discarded; see `mage-artwork-reset.md`.

The user approved trio v6 and requested integration, three spec slots per class (Arcane excepted), effect migration, developer class switching and a local test build/install. They clarified that players must **multi-select the crests they want active**, on first use and later, with class restriction. There is no automatic talent-specialization switching.

Beta.9 replaced the three Druid textures with the approved v8 repaint. Beta.10 removed the earlier Mage exception: Fire/Frost/Arcane use the same three-slot selection model. The one-time Arcane effect merge remains; the later artwork reset removed custom Mage overlays.

## Model and selection

`ClassSpecs.lua` defines the nine Forever classes. Druid has Balance, Feral and Restoration; Mage has Fire, Frost and Arcane. The other classes have their three traditional talent-tree slots, initially with no dedicated artwork. Their native effects can be authored now. `content.resources.left/right` is unchanged. The old Mage `content.spells.left/right` is retained as inactive compatibility data; normal Mage rendering uses its class bank exclusively.

Each class has `content.classes[CLASS] = {slots={specKey=sideConfig,...}, active={specKey=boolean,...}, configured=boolean}`. These account-wide settings are isolated across classes. Selection and effects follow Spellcasting between physical sets. Placements, offsets and the reverse-order flag remain in `sets`.

The first-use Spellcasting page opens out of combat, deferring if necessary. Checkbox choices preview immediately; Save commits all class banks/sets, while Cancel/Close discards the draft. Save is enabled for the initial selection even without toggling a checkbox, so players can accept the defaults directly. Selecting no crests is supported. There are at most 32 native layers per spec slot, allowing both old Arcane lists to migrate without dropping valid layers.

Central arranges active crests in a centered row with the requested gap between their actual frame edges. One crest is centered; two retain left/right; three use left/middle/right. Edge places two at the edges, or a third at center; a single crest is centered. Existing left/right offsets remain, and `middleX/middleY` start at zero. Reverse/Swap reverses the active order. Resources remain two-sided.

## Migration

Schema 2 Druid configs are identified by their artwork IDs, even if the content-side IDs were reversed: Moonwarden becomes `slots.balance`, Groveheart becomes `slots.restoration`. Effects, bindings, sizes, facing, visibility and calibration are normalized through the established side model. Empty effect arrays remain empty. Feral starts empty. Balance/Restoration are initially selected. Schema 4 merges old Mage native layers into Arcane, resets their five placement controls/front layer, and retains intrinsic model fitting and bindings. Arcane starts selected; Fire/Frost start empty and unselected. Resources remain unchanged. No migration script reads or edits SavedVariables files; WoW performs its normal namespace upgrade at load.

Druid source calibration is retained. That earlier migration centered Mage effects once; subsequent artwork retirement preserves existing effect tuning.

## Developer scope

`/epicast dev` reveals **Build class** in both the main window and effect studio. It edits the chosen class bank within the same transaction and allows native effect tests on all selected positions, including the middle. It does not replace or copy another class's effects. The class override is memory-only, applies only with the editor open, and is cleared on Close or leaving dev mode. Combat prevents class/selection edits. Tests use real mock UI handlers, not only model helpers.

## Approved artwork and build

Current source: `concepts/druid-specialization-trio/Druid-specializations-review-v8.png`, 1882×836 RGBA, SHA256 `4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8`. Original PNG/prompts and all earlier concepts remain intact. Beta.8 used v6, hash `19B8EF379608373439750C592AFEEECFE9498C2719E2BC9B7B0201AEE5871B8B`; the old ZIP and preparation evidence are preserved.

Run `tools/Prepare-DruidTrio.ps1`, then `node tools/Build-DruidTrio.cjs`. The source has three disconnected silhouettes whose leaf tips overlap equal-width column boundaries. Nearest-connected-silhouette separation preserves those tips and antialiasing; a simple three-column crop would cut visible pixels. Each crest is registered on a 660×880 transparent canvas without upscaling, preserving the established size and vertical source offset. Output widths 192/288/384/480/576/660 use the established premultiplied Lanczos2 and CAS sharpness 1.0 / blend 0.65, with unchanged alpha and power-of-two backing. V8 visible bounds baked into Model.lua are Restoration `{16,42,644,847}`, Balance `{30,29,630,847}` and Feral `{22,37,638,848}`. No visible source pixels (alpha >=8) were clipped. The new and old 192-pixel runtime TGAs were decoded at native size and visually compared for clipping, colour and readability in `artifacts/druid-trio-v8/Runtime-192-comparison.png`. Current preparation evidence is `artifacts/druid-trio-v8/bake-verification.json`; the v6 preparation remains under `artifacts/druid-trio`.

Native six-second Translation hover, disabled snapping, static fallback, effect anchor geometry and calibration units remain. Old Moonwarden/Groveheart media are retained as legacy assets; no new resources or emissions were invented.

## Validation

`tests/class-crests.lua` covers schema-2 migration by artwork identity, exact effect tuning, empty arrays, first-use selection, 0–3 crests, middle editing, placement, swaps, Save/Cancel, class isolation, combat guards and developer restoration. Existing Druid/Arcane/resource/lifecycle tests are retained with the new schema paths. `tools/test-druid-assets.cjs` verifies the exact source hash, eighteen textures, dimensions, alpha coverage and padding. See `docs/effect-playback.md` for the separate 166602 diagnosis. Live appearance remains user-tested.
