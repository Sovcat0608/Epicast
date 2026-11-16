# Restoration recovery — beta.17

The user reported losing Restoration effects after the preference/bake separation and asked whether a record remained. The existing pre-reset archive contains nine Restoration rows. Recovered only `content.classes.DRUID.slots.restoration.addedEffects` with a literal-only Lua AST reader; no Lua execution, live account files, other class configuration or player preferences were extracted. The original archive was not modified.

- Archived source: ignored `artifacts/config-reset-20261116-192255/Epicast.lua`, modified2026-11-16 19:22:24.684UTC.
- Source SHA256: `05C8544124708773FC9503A0EDF9F9C9A74CF4F1EB5530509C26560D2D21E4BD`; matched the reset receipt before extraction and rechecked afterward.
- Effect-only fixture: `tests/fixtures/restoration-recovered.json`, SHA256 `82BD788182107333631C0FC06A45E12A4294CC9B03CE662D64DA281390CA40E9`.
- Compiler: `node tools/Build-CrestBake.cjs artifacts/restoration-recovery/restoration-export.json` updates only the `DRUID:restoration` definition. All fields, row order, model fitting, opacity, animation segments and bindings are retained exactly.

| Layer | Model | Behavior |
|---|---:|---|
| 1 |1519919|Regrowth success|
| 2 |6693303|Healing Touch cast, intro/main/outro|
| 3 |4417916|Healing Touch success|
| 4 |6035609|Static nature aura|
| 5 |646589|Rejuvenation success|
| 6 |166602|Regrowth cast, Stand-only|
| 7 |166694|Rejuvenation success|
| 8 |1598214|Swiftmend success|
| 9 |5593590|Static green glow|

These are the recorded nine rows, not a reconstruction from screenshots. No missing spell configuration was invented. All models pass the inspected Forever allowlist. Balance/Feral and the approved twelve-layer Arcane preset remain unchanged.

The real runtime test checks exact normalized rows, class isolation, preferences retained over an existing empty array, static accents, repeated cast/success routes, intro/outro and Stand-only166602 playback, no cast-time model loading and no preference writes. The build test compares the manifest to the independent recovered fixture and the generated Lua to the manifest. Full private backups and recovery tooling/evidence stay under ignored artifacts; only effect-only data belongs in source.
