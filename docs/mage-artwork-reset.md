# Mage artwork reset — 2026-11-16

**Historical reset record.** Beta.12 now integrates and installs the user's newly approved, uncorrected Mage reboot option1. See [current integration](mage-reboot-integration.md) and [release evidence](release-0.1.0-beta.12.md). The retired pre-reboot art remains removed; Resources still await custom artwork.

The user discarded all existing Mage artwork and its art direction to start over. At reset there was no approved replacement brief. The subsequent fresh reference-driven brief and first review are recorded in [Mage reboot](../concepts/mage-reboot/README.md). Do not reuse the retired books, scrolls, lecterns, pendants or their prompts as a starting brief. The Druid artwork and its style standard remain approved separately. New review artwork is not yet approved for integration.

Removed from the working project:

- The Mage concept directory, including source paintings, reference copies, prompts, research and design notes.
- The Mage bake/preview directory and conversion tools.
- All 36 Mage trio runtime textures and 17 legacy Arcane textures, including those formerly reused by Resources.
- Active Mage sprite, emission, seal and scroll renderers, custom artwork controls and package entries.

Fire, Frost and Arcane remain independent class slots with **artwork pending**. Resources retain two independently editable slots labeled Resource 1 and Resource 2. Native game effects, selection, placement, meters and bindings remain available. Stable IDs are retained for compatibility; they no longer resolve to Mage texture files. Old overlay settings are retired during in-memory normalization. No SavedVariables files are accessed.

The one-time Arcane effect merge, Missile Barrage Buff/Cooldown Manager repair, Druid migration and all-class developer preview remain. Numeric retired frame bounds are retained only for importing schema-1–4 placement. Historical software fixtures support regression tests but are not packaged or an art brief.

This is a source reset, not a new release or installation. Previously built ZIPs, install backups, the installed beta.10 and public releases are historical and still contain their original payloads. Chat attachments and the shared image-generation cache are outside the project reset. Do not reinstall old packages expecting this reset.

Validation covers `npm test`, `npm run audit` and a before/after hash comparison of all 30 Druid textures plus the addon icon. Current-runtime tests cover pending art without retired texture requests, retained effect tuning, repeated Missile Barrage gain/clear, Druid rendering and class switching.
