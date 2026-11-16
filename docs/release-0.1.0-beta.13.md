# Epicast 0.1.0-beta.13

Repository: https://github.com/Sovcat0608/Epicast

Published: https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.13 — **2026-11-16 17:24:33 UTC**. GitHub reports prerelease=true and draft=false. The annotated tag resolves to source commit `36539589b2f9996810342bad4a8f6c652a859cf9`; all80 packaged sources match that commit. Both uploaded asset sizes and GitHub SHA256 digests match the local ZIP/checksum. Publication receipts are in ignored `artifacts/arcane-bake-beta13/`.

Release tag: `v0.1.0-beta.13`. Release type: beta prerelease. User authorized baking the in-game Arcane effects/bindings and publishing to GitHub on 2026-11-16.

Installable asset: `Epicast-0.1.0-beta.13.zip`, **80 files**, **25,922,957 bytes**. SHA256:

`BC55855E02CAD469CEC050B52B3B8F4896C1B32EABE104CA825F19AC35FD0DEF`

The companion `.zip.sha256` contains the same checksum. Archive entries were checked against their source bytes. Source, tests, artwork and conversion tools are included in Git; dependencies, generated ZIPs, local receipts/backups and the abandoned animation experiment are excluded.

This beta adds the approved twelve-layer Arcane preset, retaining exact static effects, model fitting, placement, opacity and six spell bindings. Existing settings and intentional empty lists remain authoritative; legacy Arcane pair migration is preserved. See [Arcane preset](arcane-preset.md) for precise scope and regression evidence.

Changes since public beta.7 also include independently selected/positioned class crests, the repainted Druid specialization trio, the uncorrected option1 Mage reboot trio, all-class developer preview, preserved Missile Barrage Buff tracking, and verified segment handling for effect166602. Resources await custom artwork; Fire/Frost and Feral start without spell presets. Full details are in CHANGELOG and README.

Validation: `npm ci`, full `npm test`, `npm run audit`, exact exported-preset comparison and source/archive hashes passed. The audit covers26 runtime entries,8,723 inspected Forever models and49 exact RGBA artwork assets. All49 textures are unchanged from beta.12. Current-handler tests cover repeated Barrage clearing and rapid re-procs during outro without model reloads or settings writes. GPU rendering remains client-reviewed.

Only Epicast's saved Arcane effect configuration was read, with explicit user authorization. The source file was not modified. No full saved database or account identifiers are included in Git or the release ZIP. No game UI automation or reinstall was requested for this publication; the locally installed version remains beta.12.

Close WoW fully before extracting the new addon, retain SavedVariables, then restart. Keep the relevant native Cooldown Manager Buffs/Bars viewer visible for restricted combat tracking. The new preset applies to fresh Arcane configurations and does not overwrite existing custom effects.
