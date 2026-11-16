# Independent crests — beta.11 / schema 5

> Current beta.16/schema6 supersedes effect-save ownership described below: crest effects are shipped definitions, developer edits are session-only, and only normal UI preferences persist. See [crest bakes](crest-bakes.md). Main tabs use native Warcraft attached tabs; library layout is unchanged.

The user removed the corner/edge/center implementation, shared spacing/sizing and matched pairs. Every Spellcasting spec and each Resource artwork now has its own position, size and visibility. A crest's identity is its class/spec key (or resource key), never its screen position. Hiding another crest, changing selections or resizing a neighbor cannot move it.

## Data and migration

Class configurations remain in `content.classes[CLASS].slots[spec]` and selection in that bank's `active` map. Each slot stores `size`, `x`, `y`. Resource configs remain under `content.resources.left/right` as compatibility identifiers, with independent `enabled`, size/X/Y; their UI names are Resource 1 / Resource 2, without left/right restrictions. There is no saved `sets` layout in schema 5. The dormant `content.spells` backup is retained for earlier Arcane migration only.

X is an offset from UIParent's horizontal center. Y is the visible crest frame's bottom above UIParent's bottom; negative Y is allowed. Limits: size 25–400%, X ±8000, Y -2000..3000. The enlarged size range preserves the effective 50–200% individual × 50–200% set size from older builds. The X range also retains valid old combinations of set offsets, gaps and per-side offsets.

`IndependentLayout.lua` is a migration adapter, not an active layout engine. For schema <5 it resolves old exclusive role assignments, active order/reversal, old frame bounds, shared size/gap, global offsets, individual offsets and Edge-facing inversion. It writes the resulting effective scale and position onto each named crest. Disabled groups become disabled individual crests. Existing active positions use the current UIParent width for old edge alignment. Inactive crests receive independent starting locations and retain their effect settings. Import is input-immutable and idempotent; schema-5 normalization never repeats it. It runs only on the in-memory addon namespace; no tools access SavedVariables files.

Earlier Druid artwork-aware migration and Arcane effect consolidation still run before placement import. Existing schema-4 Arcane effects are not merged or centered again. Binding and intrinsic model settings remain unchanged.

## UI and rendering

The beta.15 main UI supersedes the original layout below: Crests / Settings, thumbnail card selection, Placement / Behavior pages, precise inputs, and a persistent shared Save/Cancel footer. Categories, per-crest ownership and transactions are unchanged. See [the audit and current interaction design](ui-ux-audit.md).

The main window has **Spellcasting / Resources** categories, three or two named rows with individual Show checkboxes, and one selected-crest editor. Size/X/Y, Flip, animation, Reset and dragging affect only the selected config. Hidden crests remain selectable and editable. Resource kind/meter controls appear in Resources. Save commits the whole draft transaction; Cancel/Close rolls it back. First-use Save can accept defaults directly.

The effect studio replaces physical-side buttons with a named crest dropdown, including Resource artwork. Both editor headers retain all-nine-class Build class menus in developer mode. Mage custom artwork controls were removed with the artwork reset; native effect controls remain. Class preview remains session-only and is removed on Close or leaving developer mode, with combat deferral and immediate hiding of foreign preview frames.

Core frame pools use stable class/spec keys, and each frame anchors independently to UIParent. Old class entries are hidden and stopped on class changes; selecting one spec never reuses another spec's native effect instance. Existing pooled model readiness/timer guards remain in force. Trigger reports enumerate independent instances and identify e.g. `spells/arcane`.

## Validation and delivery scope

`tests/independent-crests.lua` loads the real current TOC without fixture overrides. It checks actual schema-2/4 imports, swapped/mixed-size/edge layouts, inactive/disabled flags, extreme valid positions, repeated normalization, named UI handlers, stable neighbors, independent Resource controls, drag, reset, Save/Cancel, hidden editing, pending-art rendering, all nine class banks, combat/preview restoration, and current static/cast/success/channel/pulse/Barrage routes including repeated native buff clears and disable/re-enable.

Historical tests use explicitly archived schema-4 UI/layout/renderer code under `tests/fixtures/schema4`, while continuing to use the current shared effect/reader modules. The test runner labels both sections. Historical UI results are not current-UI proof. No game screen automation is used; in-game visual acceptance remains separate.

Beta.12 integrates the approved uncorrected Mage reboot option1 as three complete square crests. Druid v8 remains unchanged. See `mage-reboot-integration.md`; prior packages retain their historical artwork.
