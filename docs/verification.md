# Cooldown Manager rebuild — 2026-11-15

Build: 0.1.0-beta.1 / schema 1 / interface 16001. This supersedes the initial package evidence below.

- `npm test`: passed the full integration, buff re-trigger and new Cooldown Manager regressions; 20 runtime Lua modules parsed as Lua 5.1 and loaded in TOC order.
- The new restricted-aura/native-activation regression failed against the prior runtime before implementation. Native activation without a subsequent aura event now starts both Barrage layers.
- Coverage includes repeated procs, consumption/expiry, Clearcasting exclusion, Missiles channel/pulses, both native buff viewers, metadata aliases and pooled reuse, hidden/edit/demo/secret/unknown/error/conflicting states, native tracking disappearing/loading late, public aura fallback, localized/numeric bindings, diagnostic output, death and disabled/removed effects.
- Assertions verify zero model reloads, zero full Apply calls and unchanged mock settings during the trigger tests. Native mutation/refresh methods are guarded against invocation.
- `npm run audit`: passed all 22 runtime entries, independent namespace, eleven approved models and the exact hashes of all 18 approved TGA textures.
- `tools/Package.ps1`: verified all 45 archive entries against their source SHA256. Only the TOC, README, CHANGELOG and BoundEffects.lua changed from the previous ZIP; CooldownBuffs.lua is new. The other 40 payloads are identical.
- Archive: `dist/Epicast-0.1.0-beta.1.zip`, **7,018,987 bytes**.
- SHA256: **`B8EA6D17FA10EAE3B3AE5CEEABB56962CC2B43B5AC44B6007935663C02A7A910`**.
- Machine-readable reports: `dist/package-verification.json` and `artifacts/cooldown-manager/package-comparison.json`. The previous ZIP is preserved beside the comparison report.

ZIP-only delivery; no install, publication or SavedVariables access/modification. For live testing, enable native Cooldown Manager tracking for Missile Barrage in an enabled, visible Tracked Buffs or Tracked Bars row. The packaged README explains `/epicast triggers` diagnostics. Actual client behavior remains user-tested.

# Initial fork verification — 2026-11-15

Build: 0.1.0-beta.1 / schema 1 / interface 16001.

- `npm test`: passed all seven integration groups and Lua 5.1 parsing of 19 modules loaded in TOC order.
- `npm run audit`: passed independent namespace, runtime allowlist, legacy-code exclusion, eleven-model scope and 18 exact approved RGBA textures.
- Direct SHA256 comparison: all 18 media files match the Arcane beta source assets byte for byte.
- `tools/Package.ps1`: verified all 44 ZIP entries against source SHA256; no development dependencies, tests or historical assets packaged.
- Archive: `dist/Epicast-0.1.0-beta.1.zip`, 7,003,645 bytes.
- Archive SHA256: `1BC24B432AAE321B4EE47141755661516E0AF0BAF3E1F1E2385B203B497D5939`.
- EndCapper Arcane beta: complete Lua-load/scope/persistence tests passed and all 45 archived entries match its staging source. Archive is 7,041,227 bytes, SHA256 `348B9F4E23B4047222B61B48323CE855D598F732AC4BF7C43F3FB3A436427B23`.

The integration harness exercises actual options/studio callbacks, assignment uniqueness, resource updates, event-driven casts/channels/procs, manual test targeting, removed/disabled-layer timers, combat deferral, drag rollback, independent settings and optional native hiding. It does not render native particles or prove the game exposes any particular spell event. Live acceptance remains pending.

No game installation, SavedVariables mutation, source-control commit/push or publication was performed. See `handover.md` for scope, architecture and the live acceptance checklist. Rebuild verification metadata after any future runtime change; these hashes describe this build only.
