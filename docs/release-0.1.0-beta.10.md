# Epicast 0.1.0-beta.10 — Mage trio and floating scrolls

**Historical package record.** This ZIP predates the Mage artwork reset and is not the current working source. Mage concepts, conversion outputs and art direction were removed on 2026-11-16; see `mage-artwork-reset.md`.


Built and installed 2026-11-16 at the user's request. Local test release only; no commit, push or public publication.

## Build identity

- Version **0.1.0-beta.10**, schema **4**, Forever interface **16001**.
- ZIP: `F:/Work/WoW Addons/Epicast/dist/Epicast-0.1.0-beta.10.zip`.
- **115 files**, **38,811,452 bytes**.
- SHA256: `6963C452E40E253F8A2E1C16FCCF3CCC68E3892F0AD4640951D7BA2BFCFED1A7`.
- Payload consists of 24 Lua modules, two XML templates, 84 media files and five metadata/document/license files.

## Included behavior

Fire/Frost/Arcane now have independent selectable Mage slots. Books use the v3 repaint; each symmetrical lower scroll is a separate overlay carrying the former lower ornament. Native six-second vertical hover uses the same amplitude on both layers, with the scroll one second behind. Developer controls expose per-crest scroll size/X/Y/Reset, with phase-preserving edits and Save/Cancel. Build class is available in both editor headers for all nine Forever classes; the studio supports Center selection.

Schema 4 merges the old Arcane left and right native effect lists into the new Arcane slot once, including static/bound rows and duplicates. Five placement fields and front/back layer reset to the centered defaults; intrinsic model fitting and spell bindings remain. Default migration yields 13 layers, with 32-layer capacity for fully populated old pairs. Fire/Frost begin empty. Resources and Druid v8 remain unchanged. Missile Barrage keeps the shared Cooldown Manager Buff fix and is exercised in the real merged configuration. The trigger diagnostic revision remains beta.8 because BoundEffects.lua is unchanged.

The class-slot and binding migration are documented in `class-crests.md`. The former Mage artwork documentation has been retired.

## Verification

- Full `npm test` and `npm run audit` passed with beta.10 metadata: migration, 32-row capacity, repeated Barrage gain/clear in combat, cast/success/channel/pulse paths, first-use multi-selection, class isolation, scroll phase/tuning/Save/Cancel, combat guards and every existing regression suite.
- Exact source hash/dimension checks and 36 new RGBA TGA checks passed, including transparent backing and no clipped canvas edges. Source separation reports zero clipped pixels at alpha >=8; CAS preserves alpha. All 84 media hashes match the manifest.
- Offline decoded texture composite visually reviewed at default UI-unit size and 2× inspection scale: `artifacts/mage-trio-v3/Runtime-composite-v3.png`. No game screen automation or live GPU appearance claim.
- `tools/Package.ps1` verified all 115 ZIP entries against source. `tools/Install-Beta.ps1` repeated source/archive checks and verified every installed hash.

Evidence: `artifacts/mage-trio-v3/bake-verification.json`, versioned `package-verification.json`, `install-summary.json`, and the full install report below. `git diff --check` passed.

## Installation

Destination: `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`.

**47 changed payloads: 38 new files and nine replacements; 68 existing files byte-identical.** All previous media, including Druid v8 and the old Resources pair, were unchanged. Backups/report: `F:/Work/WoW Addons/Epicast/artifacts/install-20261116-133621/`, with `install-verification.json` listing all old/new hashes. Installer only accessed the source-verified Epicast AddOns payload. **SavedVariables files were not opened, read, written, copied or deleted.** The migration runs in memory when WoW loads the addon and WoW retains its normal settings-saving lifecycle.

This installation remains historical. The artwork reset has not been installed.
