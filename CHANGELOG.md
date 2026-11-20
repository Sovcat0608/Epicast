# Changes

## 0.1.0-beta.18.segments.8

- The Rejuvenation leaf starts swaying on the second Channel frame while its glow builds, then carries that motion into Hold.

## 0.1.0-beta.18.segments.7

- Fixed the doubled fabric tip near the end of Impact. Each banner and its contact shadow now settle into the same Idle pose.
- Rejuvenation now returns to its first Idle frame after Channel and Impact while its independent hover continues.

## 0.1.0-beta.18.segments.6

- Added independent hover and spell-driven Channel and Impact animation to the Restoration crown symbol and Rejuvenation leaf.

## 0.1.0-beta.18.segments.5

- Updated the Restoration Treant's Idle, Channel and Impact animations with solid jaw motion and contact shading that follows the chin.
- Added authored Channel entry and release for the Treant, with an exact return to the resting face after Channel and Impact.
- Increased the left green shoulder's Channel and Impact bend while keeping it attached to the branch.

## 0.1.0-beta.18.segments.4

- Baked the six reviewed Restoration crown and shoulder leaf animations at all six texture sizes. Channel loops twice as fast with a stronger shuffle and glow. Impact peaks on its second frame, then settles back to Idle.

## 0.1.0-beta.18.segments.1

- Added **All** to Artwork Config. Move native effects between locked Restoration artwork segments in the live preview.
- Bind a spell to individual animated segments and choose Channel or Impact where supported. Copy crest bake includes those bindings and the mixed layer order.

## 0.1.0-beta.18.idle.2

- Baked the animated Restoration crest at six size-specific resolutions with Lanczos2 and CAS. The existing four-second idle loop and native hover retain their timing.

## 0.1.0-beta.18.idle.1

- Local Restoration animation test. The crest plays the approved four-second idle loop at 8 FPS, including feather, foliage, treant, banner and vine motion.

## 0.1.0-beta.18

- Rebuilt the developer studio with adjacent **Effect Library / Artwork Config** tabs. Search and isolated previews now lead to one **Add effect layer** action; binding is optional afterward.
- Added a full selectable layer sidebar containing effects and actual artwork, with front/back ordering, visibility and opacity. Each crest's existing complete floating artwork appears as one real layer.
- Added a large live crest preview using the game renderer, with Fit/zoom, native viewport cropping and isolated response tests. Placement and Playback controls include exact inputs, wheel nudging, animation presets and segment timing.
- Added a per-crest spell waiting room. Queue spells before effects exist, choose a signal, then bind to the selected effect. Unbinding retains the spell for reuse; one spell can drive multiple layers.
- Effects can follow a selected artwork layer's native six-second hover, with matching phase and independent placement offsets. Effects remain independently pooled; casts do not reload models or write configuration.
- Extended crest bake exports/compiler to include stable layer identities, order, artwork settings and waiting-room spells. Developer changes remain session-only; player preferences and all shipped effect/artwork defaults are preserved.
- Added workflow, ordering, motion, preview isolation, capacity, input, combat, layout and bake round-trip regressions. Local test build only; installation and publication are separate.

## 0.1.0-beta.17

- Grouped each main tab row side by side. Relative anchors follow Warcraft's automatic tab resizing instead of leaving fixed gaps.
- Moved **Open effects** beside the crest title in developer mode, available from both Placement and Behavior. Opening it applies pending placement text to the draft without saving preferences.
- Recovered the nine recorded Restoration effect layers and bindings from the pre-reset backup and baked them into the crest. Exact tuning is retained for Regrowth, Healing Touch, Rejuvenation, Swiftmend and two static accents. Arcane and artwork are unchanged.
- Added regressions for native tab resizing, developer button access and the recovered Restoration effects. Normal player preferences remain separate from crest bakes.

## 0.1.0-beta.16

- Effects and spell bindings now belong to each shipped crest. Updates apply the latest bake to existing installations automatically; old saved effect copies and empty lists no longer override it. Arcane uses the approved twelve-layer configuration for everyone.
- Retain player crest selections, size, position, facing, animation/visibility and resource/global preferences. Schema6 stores only these player settings; no manual SavedVariables deletion is needed.
- Developer effect edits are temporary previews. Save session keeps them until reload; Copy crest bake exports them for inclusion in an addon release. Added a validated effect-only bake compiler and regression tests for upgrades, precision, session isolation and normal player settings.
- Changed the main UI tabs to Warcraft's native raised gold/bronze style. Includes the Crests/Settings UI redesign from the unpublished beta.15 test build; library layout and all artwork remain unchanged.

## 0.1.0-beta.15

- Rebuilt the main UI around Crests and Settings, with artwork thumbnail cards, separate Show toggles, and Placement / Behavior pages for the selected crest.
- Replaced wide position sliders with exact signed/decimal fields, 1/10-unit nudges, keyboard navigation and selected-crest alignment/reset. Size supports both a slider and exact input.
- Added a read-only overview of configured spell responses, explicit resource preview restrictions, and a discoverable session-only Developer mode toggle. The effect library window is unchanged.
- Kept Save all changes / Cancel visible across pages; Close identifies when it discards unsaved work. Typed values stay with their original crest; navigation alone does not change saved settings.
- Reduced panel height from 824 to 632 and fit both screen dimensions. Drag outlines appear only while placing crests. Added regressions for transactions, precision inputs, class previews, combat, library handoff and layout bounds. Artwork, bindings, defaults and schema 5 are unchanged.

## 0.1.0-beta.14

- Added **Hide Cooldown Manager (keep tracking active)**, off by default, with an inline explanation of the WoW setting, tracked-buff and Always-visible viewer requirements.
- Cosmetic transparency keeps native aura updates running. Mouse interaction on invisible CDM widgets is suppressed; Edit Mode and CDM settings reveal the displays. Save, Cancel and closing options restore the appropriate state.
- Preserve native visibility, CVars, tracking choices, previous opacity and input settings. Handle late loading and pooled widgets without calling Blizzard's data refresh methods or writing native Lua fields.
- Added regressions for alpha-zero Barrage/Clearcasting tracking, repeated procs, Save/Cancel, Edit Mode, native layout rebuilds, restricted values and protected input changes during combat. No artwork, effect preset or player-placement changes.

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
