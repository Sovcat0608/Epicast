# Epicast beta.11 — independent-crest UI test build

**Historical package record.** This ZIP predates the Mage artwork reset and is not the current working source. Mage concepts, conversion outputs and art direction were removed on 2026-11-16; see `mage-artwork-reset.md`.


Built 2026-11-16 following the user's request to remove shared corner/edge/center placement, matched pairs and linked sizing/spacing. The same turn also generated Mage v5 review artwork. This ZIP implements the UI/layout request using the existing Mage v3 / Druid v8 runtime textures; v5 sources remain separate for review.

- Version **0.1.0-beta.11**, schema **5**, interface **16001**.
- ZIP: `F:/Work/WoW Addons/Epicast/dist/Epicast-0.1.0-beta.11.zip`.
- **116 files**, **38,811,533 bytes**.
- SHA256: `3C6308466FAABBBEE6CF4D5098D06DCCD04E55996B4A73B178F5D8CF7F14C302`.
- 25 Lua modules, two XML templates, 84 unchanged runtime images, five metadata/document/license files.

Every class/spec and resource artwork owns its position, size and visibility. Main UI selects crests by name under Spellcasting/Resources; the effect studio uses a crest-name dropdown. All-class dev preview, scroll tuning, native effects, bindings, class restriction and Save/Cancel remain. Schema 5 migrates old effective layout into individual coordinates once, with no shared layout afterward. See `independent-crests.md` for exact semantics and tests.

Full `npm test`, `npm run audit` and `git diff --check` passed. The test runner explicitly distinguishes historical schema-4 integration fixtures from the new current-runtime independent-crest suite; current regressions include migration, extreme placements, stable neighbors, named handlers, independent Resources, dragging, Save/Cancel, all-class preview, scroll phase and repeated native Missile Barrage clears. All 84 runtime image hashes match the unchanged manifest. Package verification checked all 116 ZIP payloads against source.

Evidence: `artifacts/independent-crests-test.log`, `artifacts/independent-crests-audit.log`, `artifacts/independent-crests-package.json`. The previous beta.10 ZIP remains intact.

This turn created a local test ZIP; it did not install or publish. The latest installed version remains beta.10. SavedVariables files were not accessed. In-game UI/visual acceptance is pending. A full WoW restart is required when installing the ZIP so the new migration module loads.
