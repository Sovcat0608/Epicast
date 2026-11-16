# Epicast — Mage and Druid crests

**0.1.0-beta.14 · WoW Forever (16001)**

Independent artwork and native effects for spells and resources. Mages choose **Fire, Frost and Arcane** book crests; Druids choose **Balance, Feral and Restoration**. Each complete crest has gentle six-second hovering, with independently adjustable size and position.

The new Mage trio uses icy, molten and knotted-rope crowns with matching pendants and floating crystal accents. It replaces the earlier Mage artwork. Existing effect layers and bindings are retained.

On first use, the Spellcasting page lists your class's crests. Use **Show** for any combination, select a crest by name, and adjust its own size and position. **Save** keeps all changes; Cancel or Close discards unsaved previews. Choices do not follow your talent specialization automatically. Each crest keeps its position, size and effects when hidden. Existing Druid settings migrate **Moonwarden → Balance** and **Groveheart → Restoration**, with those two initially selected. Feral starts with no spell effects.

New Arcane configurations include **12 tuned effect layers**: six static accents and six bindings for Arcane Blast (cast and success), Missile Barrage (Buff), Arcane Explosion (success), and Arcane Missiles (pulse and channel). The Barrage layer includes intro and outro segments. Fire and Frost start with empty effect lists for authoring.

Existing slot tuning is retained, including intentionally empty effect lists. Older Mage upgrades combine both legacy Arcane native effect lists into the **Arcane** slot once, preserving models and spell bindings. Missile Barrage retains its Buff/Cooldown Manager tracking fix. Existing effects may need visual placement adjustments for the new artwork; the new defaults do not overwrite them.

This build replaces shared set placement with independent crests. Existing sizes, screen positions, facing and visibility are converted once into individual settings. Moving, resizing, hiding or showing a crest leaves the others in place. The former linked spacing and set-wide size controls are removed.

Close WoW completely before installing or updating. Extract the `Epicast` folder into `Interface/AddOns`, restart WoW, and enable Epicast. A full restart allows newly added Lua files to be discovered. Open **`/epicast`** or **`/epic`**. Epicast has its own settings and does not require EndCapper, an action-bar addon, or WeakAuras. If both Epicast and EndCapper are enabled, their artwork can overlap; hide the unwanted artwork in either addon.

- **Spellcasting** and **Resources** organize the editor by purpose. Every crest has its own **Show** checkbox and name button, even while hidden.
- Select a name to edit **Crest size**, **Horizontal position**, **Height from bottom**, Flip and animation. X=0 is the screen's horizontal center; Y=0 aligns the crest's outline to the bottom. Size is independent, from 25% to 400%.
- Drag a visible crest's outline to move only that crest. **Reset this crest's placement** affects only the selected artwork. No crest is assigned to a fixed side or paired with another.
- Resource 1 and Resource 2 currently have no custom artwork and start hidden. Each has its own visibility, size, position, resource and meter. Choose health, mana, energy, rage, focus, runic power or current power. Native effect intensity and optional meters follow the current level.
- **Hide Blizzard endcaps** is optional and off by default. Epicast never uses them for its placement.
- **Hide Cooldown Manager (keep tracking active)** is optional and off by default. It makes CDM's four displays transparent while preserving native tracking. Edit Mode and CDM settings temporarily reveal them; Save/Cancel also covers this setting.
- **Restrict resource art to Mages** controls the Resources class filter. Spellcasting crests always belong to your character's class during normal play. Talent specialization and shapeshift form do not alter your selection.

Use **`/epicast dev`** to toggle developer controls. **Build class**, at the top of both the main window and effect studio, previews any of the nine Forever classes for authoring and manual effect tests. Each class has three independent spec slots. Other classes' slots await dedicated artwork and can already hold effects. Close options or turn off developer mode to restore your character's class; the preview class is never saved.

**Edit this crest's effects** opens **8,723 native effects filtered for Forever 1.60.1.70938**, including spell and particle effects across classes. The studio's crest menu selects any artwork by name. Search effects by name, path, aliases or numeric FileDataID. Missing assets, the error cube and empty models are excluded. Preview loading and placeholder checks must pass before adding an effect. Models load from the game; Epicast does not bundle native game files.

The studio provides placement controls, Static/Bound behaviors, spell/buff/proc bindings, segment previews, and manual trigger tests, with up to 32 native layers per crest. Available animation metadata covers 74 inspected models; others remain labeled unverified. Resource layers cannot be bound to spells. The retired Mage scroll, glyph-emission and seal controls have been removed.

Model **166602** contains only Stand (animation 0), with no separate Intro/Hold/End segments. This build corrects unsupported settings for it. Its global animation loops and existing particles may resume on subsequent triggers; a fresh initial particle appearance is not guaranteed. Trigger reports now include the last requested segment ID.

Bindings use public player events. Some models lack intro/hold/end segments, and some game data may be restricted. Unverified segments are labeled; unavailable resource values display `—`. No guessed projectile timers or synthetic resource readings are used.

Missile Barrage and Druid Clearcasting effects also read Blizzard's Cooldown Manager during combat. Enable the Cooldown Manager in WoW settings and include **Missile Barrage** or **Omen of Clarity / Clearcasting** in **Tracked Buffs** or **Tracked Bars**. Set the relevant viewer to **Always** in Edit Mode. You can then use Epicast's **Hide Cooldown Manager** option to hide its display without disabling tracking. Setting a viewer to Hidden or disabling CDM in WoW stops native tracking; Epicast does not change those game settings. Ordinary readable buff data remains a fallback when native tracking is unavailable.

For Druid Clearcasting, choose **Bound → While buff active**, enter **16870**, click **Bind spell**, then Save. The native tracker may identify it by Omen of Clarity **16864**; Epicast matches both. Missile Barrage likewise uses **While buff active**, with aura **400589**; existing Arcane Barrage layers incorrectly saved as Proc are upgraded automatically. **While proc glows** tracks action-button overlay signals and is a separate trigger. The native tracker must remain available when the game restricts direct buff reads.

If an effect fails, run `/epicast triggers` or use **Trigger report** in the Spellcasting tab while the missed buff is active. The report includes the trigger-code version, spell/aura event counts, all bound effects and playback state. It reports Tracked Buffs and Tracked Bars separately for each configured supported buff, including visibility, Clearcasting/Barrage matches, metadata IDs and public active state. Include these native rows as well as the effect lines when reporting a missed proc. A hidden unused row no longer masks an unmatched visible row as `hidden`.

For these buffs, `cooldown=active` or `inactive` confirms native detection. `untracked` means no matching item was found in a readable visible row; `restricted` or `unknown` means no readable state was available. Hidden-row item details are diagnostic only, because hidden viewers may stop updating. `module missing` means the reader was not loaded: extract the entire ZIP and fully restart WoW. Reader/binding errors are isolated from other triggers and included in the report. Barrage and Clearcasting detection changes still need confirmation on the affected clients.

This is a testing build. Local integration and source asset checks pass; actual client appearance and spell/event availability still need in-game testing. The library's file checks do not verify every animation or appearance in-game.
