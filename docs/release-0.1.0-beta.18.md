# Beta.18 local developer studio test build

2026-11-16. Requested scope: audit and implement the developer effects UI, with per-crest waiting-room spells included in the bake. The user subsequently requested installation for testing; beta.18 is now installed. Public beta.17 remains unchanged. No commit, push or publication requested.

## Changes

See [the complete UX audit and architecture](effect-studio-audit.md). Two primary tabs separate catalog discovery from composition. Artwork Config provides an ordered artwork/effect sidebar, a full-crest native preview, Placement/Playback controls and a per-crest spell waiting room. New effects start unbound. Optional attachment follows the chosen artwork's native hover phase. Version2 bake exports/compiler carry the studio data; v1 bakes and player schema6 remain supported.

The approved twelve Arcane and nine Restoration effect rows are unchanged, including the Missile Barrage Buff signal. All49 artwork payloads are unchanged. No artwork generation, account-save access or game UI automation occurred.

## Verification

- `npm test`: full historical/current suite passed, including new studio workflow/layout tests and v1/v2 compiler round-trips. Focused studio tests also passed after final UI polish.
- `npm run audit`:33 runtime entries,8,723 Forever-filtered catalog models and49 exact approved RGBA artwork assets passed.
- `git diff --check`: clean.
- Offline layouts from actual UI handlers and approved textures inspected under `artifacts/studio-ui/`; fonts/skins are approximations and native particles are not rendered offline.
- `tools/Package.ps1`: all87 allowlisted archive payloads independently hashed against source.

ZIP: `dist/Epicast-0.1.0-beta.18.zip`  
Size:25,940,501 bytes  
SHA256:`32F24CC60A912DDB35573D408D455B1348CF9CAAAFDD54633A6B4AD5A2AF2704`

The ZIP contains four additional Lua modules (StudioModel, StudioRender, StudioPreview and StudioWidgets). Start/restart the client after installation so WoW loads the new TOC entries.

## Installation

Installed the exact ZIP to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast` at the user's request. Preflight verified the source/archive match and found WoW closed. All87 installed payload hashes were independently verified:19 changed (15 replaced and4 new),68 identical,0 removed. The15 original addon-file backups also match their pre-install hashes. Receipt and backups: `artifacts/install-20261116-221739/`; independent checks: `independent-verification.json` in that folder. SavedVariables were never accessed. No game UI automation or Git publication occurred.

## Manual client review

Open Settings → Developer mode → select a crest → Open effects. Try searching/adding a model, preparing a spell before binding, moving a layer across the artwork, disabling/re-enabling it, and comparing attached versus stationary effects. Confirm the full preview's native particles stay within its stage and its artwork/effect stacking matches the game crest. Check hover phase on repeated responses, resizing, hiding/reopening and effects-off. Test response is preview-only; ordinary spell signals still reach both views. Save session is RAM-only; Copy crest bake is required to deliver tuning for an addon release.

These visual/native acceptance checks remain pending; installation does not establish an in-game result.
