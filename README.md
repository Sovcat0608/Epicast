# Epicast — Mage and Druid beta

**0.1.0-beta.7 · WoW Forever (16001)**

Independent artwork for spells and resources. Mages use the Arcane Tome / Arcane Scroll pair with hovering artwork, animated glyphs and gems, a rotating scroll seal, and native Arcane effects. Druids automatically use **Moonwarden / Groveheart** for Spellcasting: the approved lunar and living-oak sisters with gentle six-second hovering.

Druid artwork stays visible with options closed and follows the Spellcasting role when moved between Central and Edge. Druid tuning is separate from Mage tuning. This artwork integration starts with no preset Druid spell effects; add independent bindings through the effect studio when desired. The Resources pair is unchanged.

Close WoW completely before installing or updating. Extract the `Epicast` folder into `Interface/AddOns`, restart WoW, and enable Epicast. A full restart allows newly added Lua files to be discovered. Open **`/epicast`** or **`/epic`**. Epicast has its own settings and does not require EndCapper, an action-bar addon, or WeakAuras. If both Epicast and EndCapper are enabled, their artwork can overlap; disable the unwanted sets in either addon.

- The **Central set** tab controls a centered pair: size, separation, horizontal position and height.
- The **Edge set** tab controls the screen-edge pair: size, inward inset and height.
- Each tab has its own enable toggle, role menu and sister selection. Assign **Spellcasting** and **Resources** to either location, or swap their locations with one button. A role cannot occupy both locations.
- Enable Central only, Edge only, both, or neither. Spellcasting starts in Central; Resources starts disabled in Edge.
- Resource sisters reuse the Arcane artwork, with health on the left and mana on the right. Choose health, mana, energy, rage, focus, runic power or current power per sister. Emission intensity and optional meters follow the current level.
- Select the left or right sister to flip it, enable its animation or choose its resource. Each tab remembers the selected sister. Drag artwork outlines while options are open. **Save both sets** commits all changes; Cancel or Close discards unsaved previews in both tabs.
- **Hide Blizzard endcaps** is optional and off by default. Epicast never uses them for its placement.
- **Restrict Arcane artwork to Mages** is enabled by default and preserves the previous class-filter setting. Druid Spellcasting always uses its own pair on Druids only, regardless of this checkbox. Arcane Resources retain their existing class-filter behavior. Designs are selected by class, not specialization or shapeshift form.

Use **`/epicast dev`** to toggle developer controls. **Edit sister's effects** opens **8,723 native effects filtered for Forever 1.60.1.70938**, including spell and particle effects across classes. Search by name, path, aliases or numeric FileDataID. Numeric searches use the same filtered library. Missing assets, the error cube and empty models are excluded. Preview loading and placeholder checks must pass before an effect can be added. Detected placeholders are blocked for the session. Models load from the game; Epicast does not bundle native model or texture files.

The studio provides placement controls, Static/Bound behaviors, spell/buff/proc bindings, segment previews, and manual trigger tests. Available animation metadata covers 73 inspected models; other models remain labeled unverified. Resource layers follow resources and cannot be bound to spells. Custom artwork controls adjust the Arcane glyph emission and scroll seal.

Bindings use public player events. Some models lack intro/hold/end segments, and some game data may be restricted. Unverified segments are labeled; unavailable resource values display `—`. No guessed projectile timers or synthetic resource readings are used.

Missile Barrage and Druid Clearcasting effects also read Blizzard's Cooldown Manager during combat. Enable the Cooldown Manager and include **Missile Barrage** or **Omen of Clarity / Clearcasting** in **Tracked Buffs** or **Tracked Bars**. Keep the viewer enabled and visible outside Edit Mode. Epicast uses its public active state and does not change your tracking settings. Ordinary readable buff data remains a fallback when native tracking is unavailable.

For Druid Clearcasting, choose **Bound → While buff active**, enter **16870**, click **Bind spell**, then Save. The native tracker may identify it by Omen of Clarity **16864**; Epicast matches both. **While proc glows** tracks action-button overlay signals and is a separate trigger. The studio displays a reminder for the supported buffs. The native tracker must be available when the game restricts direct buff reads; a hidden or disabled tracker cannot supply reliable state.

If an effect fails, run `/epicast triggers` or use **Trigger report** in the Spellcasting tab while the missed buff is active. The report includes the trigger-code version, spell/aura event counts, all bound effects and playback state. It reports Tracked Buffs and Tracked Bars separately for each configured supported buff, including visibility, Clearcasting/Barrage matches, metadata IDs and public active state. Include these native rows as well as the effect lines when reporting a missed proc. A hidden unused row no longer masks an unmatched visible row as `hidden`.

For these buffs, `cooldown=active` or `inactive` confirms native detection. `untracked` means no matching item was found in a readable visible row; `restricted` or `unknown` means no readable state was available. Hidden-row item details are diagnostic only, because hidden viewers may stop updating. `module missing` means the reader was not loaded: extract the entire ZIP and fully restart WoW. Reader/binding errors are isolated from other triggers and included in the report. Barrage and Clearcasting detection changes still need confirmation on the affected clients.

This is a testing build. Local integration and package checks pass; actual client appearance and spell/event availability still need in-game testing. The library's file checks do not verify every animation or appearance in-game.
