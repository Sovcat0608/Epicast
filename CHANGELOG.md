# Changes

## 0.1.0-beta.7

- Added Druid Clearcasting/Omen of Clarity support to the read-only Cooldown Manager bridge for While buff active bindings. Matches aura 16870 and native talent entry 16864, with class-aware names and localized aliases.
- Keep sampled states separate per proc while sharing each sample between its effect layers. Missile Barrage and Druid/Mage Clearcasting cannot be confused.
- Trigger reports now include the configured supported buff's native tracking rows. Studio guidance explains visible native tracking and the While buff active trigger.
- Added regressions for repeated Clearcasting gains/clears, restricted aura reads, hidden/editing/unknown native state, localization, pooled row reassignment, public fallback and unrelated healing triggers. No artwork, catalog or saved-setting changes.

## 0.1.0-beta.6

- Filtered the effect library to 8,723 models inspected in Forever 1.60.1.70938, including their referenced files. Removed 995 missing models, the error cube and 49 empty models.
- Numeric FileDataID searches now obey the same filter. A search with no results clears the old preview and disables Add.
- Block missing-model placeholders by returned ID, path and exact error-cube bounds; recheck before adding. Detected placeholders are hidden for the session.
- Added regressions for numeric bypasses, failed/stale previews, placeholder detection, click-time changes and archive integrity. Existing artwork, bindings and saved-setting normalization are unchanged.

## 0.1.0-beta.5

- Expanded the effect library from eleven Arcane models to 9,768 named native spell/particle and supporting effect models, with direct FileDataID lookup for unlisted models.
- Removed the eleven-ID restriction from added-effect persistence, allowing the full library on Mage, Druid and resource artwork; resource layers remain Static only.
- Restored 32 preview calibrations and animation metadata for 73 inspected models. Current artwork and configured effects are unchanged.
- Added regressions for full catalog search, aliases, direct IDs, Save/reload, lazy model loading and unavailable/stale previews.

## 0.1.0-beta.4

- Integrated the approved Moonwarden / Groveheart sisters as the automatic Druid-only Spellcasting design, in either Central or Edge.
- Added independent Druid tuning while preserving existing Mage effects, resource choices and placement settings on upgrade.
- Preserved source proportions and transparency with twelve size-specific CAS textures, native six-second hover, phase recovery and static fallback.
- Added regressions for class selection, old-save preservation, separate tuning, swaps, rendering lifecycle and texture padding. No Druid spell-effect presets or new Resources artwork were added.

## 0.1.0-beta.3

- Split options into Central set / Edge set tabs with contextual placement controls, explicit role menus, remembered sister selection and shared Save/Cancel.
- Cancel manual effect previews when switching sets or sisters, including artwork selection.
- Improved Missile Barrage item matching: native item lists, numeric cooldown IDs, exact spell identity independent of catalog selfAura flags, and validated cached metadata fallback.
- Added per-viewer/item trigger diagnostics and a Trigger report button. A hidden unused row no longer masks a visible unmatched row.
- Added regressions for tab transactions, role menus, combat guards, repeated Barrage transitions and native matching/reporting. Live Barrage confirmation remains pending.

## 0.1.0-beta.2

- Prevented a missing or failing Cooldown Manager bridge from aborting effect setup and unrelated spell triggers. Public buff reads remain available as a fallback.
- Added isolated startup and repeated-cast regressions with the native bridge missing or failing.
- Expanded `/epicast triggers` to report every binding, the trigger-code version, spell-event counts, enable/visibility flags and native bridge errors.
- Updated installation instructions to require a full WoW restart after an update that adds files.

## 0.1.0-beta.1

- Added Missile Barrage detection through Blizzard's Cooldown Manager for combat-restricted buff data, with repeated-proc regressions and tracking diagnostics. Requires Barrage in an enabled native Tracked Buffs or Tracked Bars row.
- Fixed buff scans stopping at an unreadable aura before reaching later readable buffs, and added `/epicast triggers` for buff/proc diagnostics.
- Created independent Epicast addon and settings, retaining the approved Arcane artwork and rendering.
- Added Central/Edge slots with exclusive Spellcasting/Resources assignments, swaps and independent enable controls.
- Added resource-reactive emissions and optional per-sister health/power meters.
- Retained in-game effect authoring, spell/buff/proc bindings, native animation segments and manual tests.
- Added optional Blizzard endcap hiding, disabled by default.
- Removed unrelated artwork, effects, migrations, legacy trigger engine, native layout/action-bar dependencies and old cap-selection UI.
