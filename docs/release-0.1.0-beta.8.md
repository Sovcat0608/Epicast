# Epicast 0.1.0-beta.8 — local test delivery

Built and installed 2026-11-16. User authorized implementation, a test build and installation; no commit/push/public release was requested for this iteration. Latest public release remains beta.7.

## Build identity

- Version: **0.1.0-beta.8**, schema **3**, Forever interface **16001**.
- ZIP: `F:/Work/WoW Addons/Epicast/dist/Epicast-0.1.0-beta.8.zip`.
- Payload: **77 files**, **24,101,861 bytes**.
- SHA256: `33DB2729EB4A9F4C38D2C1CE7F5716E97D5C18F4DEE88F147DEB092960BA56B3`.
- Runtime inventory: 22 Lua modules, two actor XML templates, 48 RGBA TGA assets, plus TOC/README/CHANGELOG/license notices. The 18 new textures and ClassSpecs.lua account for all added payload entries. All 30 previous media assets remain unchanged.

## Installation

Installed into `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast` using the restricted `tools/Install-Beta.ps1` installer. It verified every ZIP entry against source, backed up replaced addon files, copied only changes, then verified **all 77 installed hashes**. **33 payloads changed**.

Backup and detailed evidence: `artifacts/install-20261116-120142/install-verification.json`. Package evidence: `dist/package-verification.json`. No SavedVariables files were opened, read, changed, copied or deleted. No game UI automation was used. Restart WoW fully to load the new Lua module and textures.

## Validation and scope

`npm ci --ignore-scripts`, `npm test`, `npm run audit` and `git diff --check` passed. Locked dependencies were fetched after sandbox DNS restrictions prevented the first attempt. Tests/audit transcripts are `artifacts/beta8-test-results.txt` and `artifacts/beta8-audit-results.txt`. The package excludes concepts, animation R&D, development dependencies, tests, tools and local native-model inspection bytes.

See `docs/class-crests.md` for multi-selection, class banks, migration, temporary developer class selection, layouts and artwork preparation. See `docs/effect-playback.md` for the 166602 diagnosis and the explicit fresh-particle-restart limitation. Barrage legacy Proc→Buff migration and repeated native gain/clear cycles are covered by regression tests.

## In-game acceptance

1. Fully restart WoW. Druid's initial chooser starts with Balance and Restoration. Save directly to accept, or select Feral too. Check 1/2/3 crests, swapping, moving Spellcasting to Edge, and Save/Cancel.
2. Confirm old Moonwarden/Groveheart layer settings now live on Balance/Restoration. Calibration numbers are preserved; visual registration against new artwork still needs user review.
3. `/epicast dev` → Build class allows all nine Forever classes. Other classes' three slots are ready for effects but await dedicated artwork. Close restores the actual class.
4. Arcane Missile Barrage needs visible native Tracked Buffs/Bars. Check repeated procs, including gains after Arcane Blast clears the buff; capture `/epicast triggers` if it still fails.
5. Test 166602 repeatedly. It has only Stand (0), not real Hold/End segments; reports should show `segment=0`. Global particle startup may still differ on reuse. Verified multi-segment models have separate intro/hold/end regression coverage, but no GPU visual result is claimed.
