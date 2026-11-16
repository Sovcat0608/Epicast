# Epicast beta.16 — crest-owned bakes and native tabs

User authorized implementation, build, installation and GitHub beta publication on2026-11-16. This includes the previously local beta.15 main UI redesign. Schema6 deliberately supersedes preservation of old personal developer effect lists; normal player preferences remain.

Shipped effects/bindings now resolve from the crest definition at every load. The approved twelve-layer Arcane bake, including Missile Barrage Buff tracking, is unchanged. Developer authoring is RAM-only, with a copyable effect-only JSON export and validated source compiler. Main Crests/Settings, category and Placement/Behavior tabs use Warcraft's native `PanelTopTabButtonTemplate`. The library layout is unchanged; its Save button now says Save session. All49 artwork payloads and native effect/CDM mechanics are unchanged.

Full tests and audit passed, including old/current preference migration, stale and empty effect arrays, simulated future bakes, retained placements/selections/global preferences, dev draft/session isolation, exact-precision export/compiler round-trip, native tab state/combat guards and repeated Arcane/Barrage playback. Offline layout previews from the real mocked widget tree were inspected; these are not game screenshots or live appearance acceptance. Evidence is under ignored `artifacts/beta16-*`, `artifacts/crest-bakes/` and `artifacts/beta16-ui/`.

Installation and publication receipts follow below when verified. No SavedVariables files were read or modified by the tools. The addon performs schema normalization in memory when loaded and WoW later saves normal preferences. Fully restart WoW for the two new TOC modules; no manual deletion of settings is needed.

## Build and installation

- ZIP: `dist/Epicast-0.1.0-beta.16.zip`;83 files;25,932,556 bytes.
- SHA256: `A409919DDC6889FFBB28C9713A1CBE834FDD94C61B200F52FF656EDE9162D26C`.
- Installed to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`:10 changed/new,73 unchanged,0 removed. All83 installed hashes and8 original backup hashes independently verified.
- Backup/receipt: `artifacts/install-20261116-194722/`; optional `Rollback-to-beta.15.ps1 -Check` checks without applying. File rollback preflight passed. After WoW has saved schema6, beta.15's deliberate newer-schema guard will make that older build inactive; file rollback does not downgrade saved preferences.
- Independent ZIP comparison to beta.15:8 changed existing payloads,2 added modules,73 identical payloads,0 removals. All49 media files and12 protected preset/native/library modules byte-identical.
- `artifacts/beta16-package-comparison.json`, `beta16-install-independent.json`, `beta16-test.log`, `beta16-audit.log` hold verification evidence. No SavedVariables access or game UI automation.

## Publication

Published [v0.1.0-beta.16](https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.16) on2026-11-16 at19:49:20UTC, prerelease=true/draft=false. Annotated tag targets `8d4577eadf415ae7611bac7fba5aab103983d9db`; every one of the83 packaged payloads matches its committed Git blob. Main/tag were pushed atomically. The exact installed/tested ZIP and SHA256 companion were uploaded; both sizes and GitHub SHA256 digests were verified before and after publication. Remote tag was independently checked. No private artifacts, full-save backups or abandoned experiments were tracked. Receipts: `artifacts/publish-beta16/`. No live-client visual acceptance claimed.
