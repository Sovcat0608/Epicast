# Beta.3: tabs, Missile Barrage investigation and druid review

2026-11-15. Local build only; latest public release remains beta.2. No game automation, installation, Git publication or SavedVariables access.

## User evidence

The friend confirms beta.2 restored other spell triggers. Missile Barrage still fails. While its native icon was visibly active, the supplied report showed both Barrage models ready, enabled, previously started/stopped twice, currently `input=absent`, `cooldown=hidden`, stopped by `UNIT_AURA`. Header: combat=false, spell events=229, aura events=57, last=COOLDOWN_MANAGER_POLL, bridge error=none. Arcane Blast and Missiles cast/channel/pulse paths remained functional.

This points to missing proc input, not a stuck native effect. It does not establish which native row was visible or the exact catalog fields on that client. The older aggregate `hidden` result could come from an unused hidden Bars row masking an unmatched visible Icons row. Do not describe beta.3 as a confirmed live fix.

## Reader changes

- Prefer native `GetItemFrames()` (which resolves the item container), with direct children as a compatibility fallback.
- Accept finite numeric cooldown IDs without imposing a positive-spell-ID rule. Native API documentation specifies a number, not a positive range.
- Exact Barrage spell IDs 400588/400589 in base/override/tooltip/linked metadata identify a Barrage buff item. Removed the extra `selfAura == false` veto: this is catalog metadata, not the item's active state. Barrage is a player proc; arbitrary target buffs are not added.
- If the API provides no readable metadata, use the item's read-only `GetCooldownInfo()` only when its public cached cooldown ID equals its current ID. Released/reassigned or restricted identities remain unusable.
- Keep public `IsActive`/`isActive` booleans as the only native activity input. Hidden viewers, Edit Mode demos and unknown/restricted states remain unusable; no visibility-as-proc inference, aura-instance reads, hooks or native settings changes.
- Report each viewer and its item IDs separately. Hidden-row samples are explicitly diagnostic and never drive effects. A visible untracked row outranks an unused hidden row in the aggregate reason.

Sources inspected: [Blizzard viewer implementation](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua), [item metadata accessors](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua), [API declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CooldownViewerDocumentation.lua), and [ProcDoc author's implementation](https://github.com/wsmaxcy/ProcDoc/blob/main/ProcDoc.lua). No third-party implementation copied. Local downloaded source references under ignored `artifacts/native-source` are evidence, not runtime payload.

## Options and artwork

Two actual page frames under Central set / Edge set tabs. Controls are scoped to the selected location; Edge has no separation slider. Each page has an explicit role menu, enable toggle, placement reset, remembered sister, swap/flip/animation controls and role-specific resource or trigger controls. Shared settings and Save both sets/Cancel remain outside the pages. Delayed role callbacks cannot mutate another tab or edit during combat. Set/sister selection cancels manual effect tests; clicking an artwork outline selects its corresponding tab and sister.

The new druid-only Spellcasting concept is **Moonwarden / Groveheart**, generated together from the user's reference. Exact PNG, prompt and provenance are in `concepts/druid-sisters`. Review only: no runtime art, class-selection changes or dedicated resource pair. The package allowlist excludes concepts; all 18 approved runtime assets remain unchanged.

## Verification and next live check

Full Lua 5.1 integration suite and media/scope audit pass. The new catalog-flag regression fails against the original beta.2 reader and passes with beta.3. Coverage includes repeated gain/clear/regain, zero numeric ID, item-container discovery, strict cached identity, hidden/visible mixed rows and separate reports. Existing missing/failing-reader regressions still protect unrelated triggers. Polling tests assert no model reloads, full Apply calls or mock-settings changes.

New `tests/options-tabs.lua` exercises actual tab and menu handlers, independent placements, remembered selection, combat/delayed-menu guards, resource-label visibility, shared Save/Cancel and preview cancellation. A layout preview rendered from the real mocked widget tree was inspected at `artifacts/options-layout.png`; it is not an in-game screenshot. Native fonts, template skinning and scale still require client review.

Test repeated Barrage procs, including clearing one with Arcane Blast. If it still fails while the native icon is active, capture the complete beta.3 `/epicast triggers` output including both viewer rows and item metadata. That will distinguish absent item discovery, a different spell mapping, native visibility and unavailable active state. Do not change or reset SavedVariables to test this.

Local package: `dist/Epicast-0.1.0-beta.3.zip`, 45 files, 7,022,413 bytes. SHA256: `8063EAFB9F3BE74E9CD55E83E1CAAF229AEA6A0242EA399A4452F595CAE81087`. Source/archive hashes verified by the packager. Comparison against beta.2: 38 payloads identical; only BoundEffects.lua, CooldownBuffs.lua, Core.lua, Options.lua, TOC, README and CHANGELOG changed. No concept assets or development files included.
