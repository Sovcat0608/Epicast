# Epicast beta.15 — local main UI test build

Built and installed 2026-11-16 for the requested main UI audit/redesign. The user subsequently requested installation for testing. All81 installed payloads were independently hash-verified in `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`:5 changed,0 removals. The five previous beta.14 files were backed up and independently hash-verified. Receipt/backup and optional `Rollback-to-beta.14.ps1`: `artifacts/install-20261116-184749/`. The rollback plan was verified without applying it. SavedVariables files were not accessed. No commit, push or publication; public release remains beta.14.

- ZIP: `dist/Epicast-0.1.0-beta.15.zip`
- Files:81; bytes:25,929,924.
- SHA256: `763A857F85E9E1A1A3178C9E864854022AEA5D4335DD4F06F7CEB060DF8C99C5`.
- Schema5; artwork/defaults/bindings and native effect code unchanged.

The new main window has Crests / Settings, artwork cards with independent Show checkboxes, Placement / Behavior pages, precise numeric placement, contextual resource visibility, session-only developer controls, read-only spell-response summaries and a persistent shared Save/Cancel footer. The effect library window remains unchanged. See [the full UI audit](ui-ux-audit.md).

Full `npm test` and `npm run audit` passed. New regressions exercise the real main UI handlers, numeric edits and invalid input, draft ownership, navigation, Save/Cancel/Close, class preview, resource filtering, combat and viewport/hit-area bounds. Prior native trigger/animation and migration regressions remain green.74 protected runtime/library/artwork files are byte-identical to beta.14, including all49 textures.

Package source hashes verified. Independent archive comparison against beta.14 found76 identical payloads and exactly five changed: `Options.lua`, `Core.lua`, `Epicast.toc`, `README.md`, `CHANGELOG.md`. No additions or removals. Receipts and logs: `artifacts/ui-redesign/`.

Offline layout illustrations were rendered from the actual mocked widget tree and inspected. They are not game screenshots; native font metrics and widget skins require manual in-game acceptance. For testing, check first-use multi-selection, hidden-crest editing, precise fields/keyboard and drag placement, global settings/Cancel, class preview restoration and the existing library entry point.
