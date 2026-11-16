# Epicast 0.1.0-beta.14

Published: https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.14 — **2026-11-16 18:05:15 UTC**. GitHub reports prerelease=true and draft=false. The annotated tag resolves to source commit `0103ec4e7c67eb619eb4cbe744ebb71d7d304a54`; all81 packaged sources match that commit. Both uploaded asset sizes and GitHub SHA256 digests match the local ZIP/checksum. Publication receipts are in ignored `artifacts/publish-beta14/`.

Built and installed 2026-11-16. The user accepted the installed build and requested GitHub publication. Release tag: `v0.1.0-beta.14`; release type: beta prerelease. The last verified local installation is beta.14; no reinstall or SavedVariables access was performed for publication.

- Archive: `dist/Epicast-0.1.0-beta.14.zip`
- Files:81; bytes:25,925,680.
- SHA256: `00CB3AE2AECC1B28554F1F7DDA82F0475A109C599B5915D706C1C8EAB7EB986C`.
- Schema5 and all49 artwork textures/Arcane preset unchanged.

The release uses the exact ZIP installed for testing, with a companion `.zip.sha256`. Full regression tests and the audit passed again for publication; evidence is retained in ignored `artifacts/publish-beta14/`. Local backups, effect-only save extracts and abandoned artwork/animation experiments are excluded from Git and the release ZIP.

Adds the optional **Hide Cooldown Manager (keep tracking active)** checkbox and inline requirements. It preserves native shown state and tracking while hiding all four displays cosmetically, reveals them for native Edit Mode/settings, and restores previous opacity/input settings on Cancel or uncheck. See [research and implementation](cooldown-visibility.md).

Validation: locked dependencies restored with `npm ci` (offline sandbox cache missed a package; normal authorized restore succeeded), full regression suite passed, and audit passed27 runtime entries/8,723 catalog models/49 exact assets. Packaging verified every source/archive hash. Comparison to beta.13:73 payloads identical, seven changed plus one new module, zero removals. Regression details and logs are under `artifacts/cooldown-visibility/`.

The audit allows only the two reviewed native Edit Mode references in this visual helper (reading IsShown and registering show/hide callbacks); native layout editing remains excluded. The reader remains unchanged except for its setup hint. Trigger report revision stays beta.13 because the trigger implementation is unchanged.

The initial CDM feature/build did not access SavedVariables. The user's subsequent explicit request to check current Mage/Arcane values authorized a read-only comparison of the 17:43:00.513 UTC Epicast save. All twelve layers and every effect/binding field match the baked beta.13 fixture and runtime preset; no defaults needed changing. Comparison/effect-only export: `artifacts/arcane-defaults-beta14/`. No full-save snapshot or save writes were made.

Installed to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`,81 payloads hash-verified,11 new/changed,0 removals. Nine original beta.12 files were backed up and independently verified; two new files were added. SavedVariables hash was unchanged after installation. Receipt, verified backups and optional `Rollback-to-beta.12.ps1` launcher are under `artifacts/install-20261116-174951/`. Run the launcher with `-Check` to inspect without applying; without that switch it restores the previous addon files. It never touches SavedVariables. The rollback preflight refuses changed installed files or damaged backups, and the isolated rollback regression suite passed. The real nine-restores/two-removals plan was verified but not applied.

No screen/game UI automation. WoW was running during installation: fully restart the client to load the new modules. To test manually, enable Cooldown Manager in WoW settings, track the relevant buff in Tracked Buffs/Bars with its viewer set to Always, enable the new Epicast option and Save. Test repeated procs and native Edit Mode/settings reveal. Mock tests do not establish real client taint or rendering acceptance.
