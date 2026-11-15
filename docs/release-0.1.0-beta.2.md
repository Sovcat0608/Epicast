# Epicast 0.1.0-beta.2

Repository: https://github.com/Sovcat0608/Epicast

Release: https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.2

Tag: `v0.1.0-beta.2`. Type: beta prerelease. The user authorized the source push and publication on 2026-11-15. The previous beta.1 release is retained.

Asset: `Epicast-0.1.0-beta.2.zip`, **45 files**, **7,019,777 bytes**. The accompanying `.zip.sha256` contains:

`d1b3627862c38838f08ea6fbb50275119055b4391ac249793c0a3ca6de25b4c0`

This publishes the exact previously verified test ZIP. All runtime changes and regressions are described in [verification.md](verification.md). Publishing changes no runtime/media payload and does not install into the game or access SavedVariables.

Beta.2 prevents a missing or failing optional Cooldown Manager bridge from interrupting unrelated effect setup and spell triggers. Diagnostics now cover every bound effect and identify the trigger-code revision. The reproduction and regressions pass locally; the cause of the friend's failure and in-game resolution remain unconfirmed.

Install with WoW fully closed, extract the complete `Epicast` folder into `Interface/AddOns`, then restart. Keep Missile Barrage in an enabled, visible native Tracked Buffs or Tracked Bars row. If effects fail, collect the first Lua error and `/epicast triggers` output after casting.
