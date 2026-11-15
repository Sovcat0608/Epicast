# Changes

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
