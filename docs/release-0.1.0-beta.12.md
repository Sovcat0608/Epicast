# Epicast beta.12 — Mage option 1 installed

Built and installed 2026-11-16 at the user's request. The selected artwork is the **uncorrected first crown/pendant render**, `concepts/mage-reboot/Mage-reboot-trio-v3-initial.png`, SHA256 `5DD9D15C1D72C67EFB83DFA664E235E450B36C8B8C1C3BBC7CC017B2A2D3F5AC`. Neither later correction is integrated.

## Package

- Version `0.1.0-beta.12`, schema5, interface16001.
- ZIP: `F:/Work/WoW Addons/Epicast/dist/Epicast-0.1.0-beta.12.zip`.
- 79 files, 25,921,160 bytes.
- SHA256: `3B4AF3892E50FEE8643394063DFEC108566A446CD5EB0BBF6DB7AA04494208A4`.
- Payload: 23 Lua modules, two XML templates, 49 textures and five metadata/document/license files.

Fire/Frost/Arcane render the selected complete crests, including all floating shards, with six-second native hover and independent placement/size/selection. Existing effect configurations, class preview and Missile Barrage Buff tracking remain. Old layout migration uses historical bounds; no effect reset. Druid's30 textures and the addon icon remain byte-identical. Resources have native effects/meters but no custom artwork. See `mage-reboot-integration.md` for exact asset conversion and runtime details.

## Validation

Full `npm test`, `npm run audit` and `git diff --check` passed. Current-runtime tests cover mapping, geometry, square aspect, UV/physical-pixel size selection, phase/static/hide recovery, no snapping, class/crest isolation, retained bindings and repeated Barrage procs. Asset checks lock the approved source hash, all18 Mage TGA variants and transparent backing. The actual decoded runtime textures were visually reviewed outside the game. No in-game visual acceptance is claimed.

`npm ci` failed due isolated-environment DNS access to npm. The five locked dependencies were restored from matching local package versions; all124 copied file hashes were verified. No permanent cross-addon development/runtime dependency was added. Evidence: `artifacts/mage-reboot-option1/{test.log,audit.log,offline-test-dependencies.json,bake-verification.json,package-verification.json,runtime-preview.png}`.

## Installation

Destination: `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`.

The read-only install plan verified all archive/source payloads before writing. Installed79 payloads:33 new/changed and46 existing files unchanged. The57 explicitly retired Mage textures/renderers were individually backed up and removed. All79 installed hashes were checked by the installer and independently rechecked afterward; all57 retired paths were confirmed absent.

Backup and full report: `F:/Work/WoW Addons/Epicast/artifacts/install-20261116-164602/install-verification.json`. Removal scope is the fixed Epicast AddOns folder and `tools/retired-mage-files.json` only. No recursive destination deletion. **SavedVariables files were not opened, read, hashed, written, copied or deleted.**

Fully restart WoW so the new Lua files load, then open `/epicast` and enable/edit Fire, Frost and Arcane as desired. For another character class, `/epicast dev` → Build class → Mage allows a temporary review. Existing tuned effects may need manual visual adjustment against the new artwork. No commit, push or publication was performed.
