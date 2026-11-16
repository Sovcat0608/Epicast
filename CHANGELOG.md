# Changes

## 0.1.0-beta.13

- Baked the approved in-game Arcane configuration as the defaults for new Arcane slots: 12 layers with exact effect placement, model fitting, opacity and spell bindings.
- Includes six static layers and Arcane Blast cast/success, Missile Barrage Buff with intro/outro, Arcane Explosion success, and Arcane Missiles pulse/channel bindings.
- Preserve existing customized and explicitly empty effect lists, personal crest placement, and the legacy two-list Arcane migration. Fire, Frost, Druid and Resources defaults remain unchanged.
- Added exact-export comparisons and live-handler regressions for fresh defaults, migration, saved tuning, repeated Barrage clears and rapid re-procs during outro. All approved artwork remains unchanged.

## 0.1.0-beta.12

- Integrated the approved uncorrected first crown-and-pendant concept into Fire, Frost and Arcane slots, with all floating crystals included. Eighteen size-specific square textures preserve the source aspect ratio; each complete crest retains six-second native hovering.
- Replaced the retired Mage books/scrolls and removed their custom-overlay controls. Resources remain without custom artwork; native effects and meters remain available.
- Preserved native effect configurations, class selection, independent placement, Druid artwork and Missile Barrage tracking. Added current-runtime artwork/hover/phase/size/class-isolation regressions and exact-source asset checks.
- The local installer backs up and removes an explicit list of retired Mage payload files. SavedVariables files are never accessed.
- Druid artwork, addon branding and their source assets remain unchanged. Existing release entries below describe historical builds.

## 0.1.0-beta.11

- Replaced Central/Edge placement and matched pairs with independently positioned and sized crests. Showing, hiding, resizing or moving one leaves every other crest unchanged.
- Reworked options into Spellcasting/Resources lists with a Show checkbox and name selector per crest. Individual size/X/Y, drag, Flip, animation and Reset controls; shared Save/Cancel transaction. Hidden crests remain editable.
- Replaced the effect studio's Left/Center/Right selector with a crest-name menu. All-class developer authoring and separate scroll controls remain available.
- Schema 5 converts old shared sizes, spacing, ordering, offsets, facing and visibility into per-crest settings once, preserving effects and bindings. Resources also become independent. Migration never accesses SavedVariables files.
- Added current-runtime regressions for layout migration, isolation, UI transactions, dragging, class switching, scroll phase and native spell/buff routes. Runtime artwork remains Mage v3 / Druid v8; Mage v5 repaint is a separate review concept.

## 0.1.0-beta.10

- Integrated Fire, Frost and Arcane spellbook crests with separate symmetrical lower scrolls. The books' former bottom ornaments now belong to the scrolls. Each scroll follows the same six-second vertical hover with a persistent one-second phase delay.
- Added developer scroll size/X/Y and Reset controls per crest, with Save/Cancel and phase-preserving resizing. Added Build class to the effect studio and a Center selector for three-crest editing.
- Added Mage's three selectable spec slots. Schema 4 combines both old Arcane native effect lists into one Arcane crest, preserving every static/bound model and binding while resetting placement to the center. Increased capacity to 32 layers so a full old pair fits. Fire/Frost start empty; Resources and Druid settings remain intact.
- Retained the Missile Barrage Buff/Cooldown Manager fix; regression coverage exercises repeated clears and retriggers on the merged stack, plus all previous cast/channel/pulse paths.
- Added migration, selection, scroll animation/tuning, all-class authoring and asset checks. Built thirty-six size-specific book/scroll textures from the new source pair.

## 0.1.0-beta.9

- Repainted Restoration, Balance and Feral with the approved v8 artwork: angular roots, chunky bevels, broader brushwork, richer colour and strong warm/cool contrast.
- Rebuilt all eighteen size-specific textures and refreshed visible artwork bounds. Crest sizes, hovering, selected crests, effect tuning and bindings are preserved.

## 0.1.0-beta.8

- Integrated the approved Restoration, Balance and Feral crests. Players choose any combination on first use and can change it later; placement supports one, two or three crests. Resources and the Arcane pair remain separate.
- Added three independent spec slots for each Forever class except the existing Arcane pair. Schema 3 migrates Groveheart tuning/effects to Restoration and Moonwarden tuning/effects to Balance without replacing Mage or Resources settings. Feral starts without spell presets.
- Added a temporary developer class selector for building and testing every class. Other classes have independent effect slots awaiting dedicated artwork. Closing options restores the real character class.
- Upgraded existing Missile Barrage Proc bindings to Buff and canonicalized its numeric talent ID to aura 400589, using the same native Cooldown Manager reader as Clearcasting.
- Inspected model 166602: it has one Stand sequence and global loops, with no Hold/End segments. Corrected unsupported selections and studio controls; added segment diagnostics and guarded no-blend playback. A fresh model-global particle intro on every trigger is not guaranteed.
- Added regressions for migration, multi-selection, three-crest placement, class isolation, repeated Barrage and animation lifetimes. New artwork uses eighteen size-specific CAS textures from the exact approved v6 image.

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
