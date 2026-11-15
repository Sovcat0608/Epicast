# Trigger isolation test build — 2026-11-15

Build: **0.1.0-beta.2** / schema 1 / interface 16001. Verified test ZIP; GitHub beta publication subsequently authorized. See [release-0.1.0-beta.2.md](release-0.1.0-beta.2.md).

- User reports that all triggers stopped in their friend's test of beta.1. The first Lua error and full-restart history have been requested but not received; the client's root cause is unconfirmed.
- Reproduced setup and cast-event failures with the new Cooldown Manager module omitted: a nil `IsCooldownBuffBinding` call aborted setup at Tome layer 4 and prevented creation of the Scroll. Injecting an exception from the native reader also aborted setup/event processing. The same reproduction now creates both sisters and starts Arcane Blast successfully in all three cases.
- `npm test`: full existing suite plus four fresh-VM regressions pass, covering absent module, absent reader, thrown reader and thrown binding detector. Each exercises repeated Blast, Explosion, Missiles channel/pulse and public Barrage fallback; diagnostics and reader recovery; zero Apply/model reload calls and unchanged mock settings.
- `npm run audit` and `git diff --check`: passed. All 20 Lua modules parse as Lua 5.1, all 22 runtime entries remain in the TOC, all 18 media hashes and the eleven-model scope are unchanged.
- `tools/Package.ps1`: all **45** ZIP entries verified against source SHA256. Compared with the published beta.1, **41 payloads are identical**; only BoundEffects.lua, TOC, README and CHANGELOG changed.
- Archive: `dist/Epicast-0.1.0-beta.2.zip`, **7,019,777 bytes**.
- SHA256: **`D1B3627862C38838F08EA6FBB50275119055B4391AC249793C0A3CA6DE25B4C0`**.

SavedVariables were not accessed. Test by fully exiting WoW before extracting the complete ZIP, then restarting. `/epicast triggers` now reports all bindings and identifies trigger revision beta.2. Live confirmation remains pending.

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
