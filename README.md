# Epicast — Arcane Mage beta

**0.1.0-beta.2 · WoW Forever (16001)**

Independent reactive artwork for spells and resources. This first beta includes the Arcane Tome / Arcane Scroll pair: hovering artwork, animated glyphs and gems, a rotating scroll seal, and native Arcane effects.

Close WoW completely before installing or updating. Extract the `Epicast` folder into `Interface/AddOns`, restart WoW, and enable Epicast. A full restart allows newly added Lua files to be discovered. Open **`/epicast`** or **`/epic`**. Epicast has its own settings and does not require EndCapper, an action-bar addon, or WeakAuras. If both Epicast and EndCapper are enabled, their artwork can overlap; disable the unwanted sets in either addon.

- **Central set** positions the pair around the screen center, near the bottom.
- **Edge set** positions the pair at the lower screen edges.
- Assign **Spellcasting** and **Resources** to either location. Swap their locations with one button. A role cannot be assigned to both locations.
- Enable Central only, Edge only, both, or neither. Spellcasting starts in Central; Resources starts disabled in Edge.
- Resource sisters reuse the Arcane artwork, with health on the left and mana on the right. Choose health, mana, energy, rage, focus, runic power or current power per sister. Emission intensity and optional meters follow the current level.
- Drag artwork outlines while options are open. Adjust set size, separation, horizontal offset and height. Save commits both sets; Cancel restores the saved configuration.
- **Hide Blizzard endcaps** is optional and off by default. Epicast never uses them for its placement.
- **Show only on Mage characters** is enabled by default. This beta has one Arcane design; it does not automatically choose designs by specialization.

Use **`/epicast dev`** to toggle developer controls. **Open effects** provides the Arcane effect catalog, placement controls, Static/Bound behaviors, spell/buff/proc bindings, segment previews, and manual trigger tests. Resource layers follow resources and cannot be bound to spells. Custom artwork controls adjust the glyph emission and scroll seal.

Bindings use public player events. Some models lack intro/hold/end segments, and some game data may be restricted. Unverified segments are labeled; unavailable resource values display `—`. No guessed projectile timers or synthetic resource readings are used.

Missile Barrage effects also read Blizzard's Cooldown Manager during combat. Enable the Cooldown Manager, include Missile Barrage in **Tracked Buffs** or **Tracked Bars**, and keep that row enabled and visible outside Edit Mode. Epicast uses the native active state and does not change your tracking settings. Ordinary readable buff data remains a fallback when native tracking is unavailable.

If an effect fails, run `/epicast triggers` after casting (or while the missed buff is active). The report includes the trigger-code version, spell/aura event counts, all bound effects, enable/visibility flags and native playback state. For Barrage, `cooldown=active` or `inactive` confirms native detection; `hidden`, `untracked` or `unavailable` means the native tracking needs checking. `restricted` or `unknown` means no readable native state was available. `module missing` means the new reader was not loaded: check that the entire ZIP was extracted and fully restart WoW. `reader error` or `binding error` includes the last bridge error in the report. Include the report and the first Lua error when describing a failure.

This is a testing build. Local integration and package checks pass; actual client appearance and spell/event availability still need in-game testing. It has not been installed or published automatically.
