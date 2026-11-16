# Cooldown Manager display hiding

Research and implementation: 2026-11-16, beta.14 / schema5. Local feature; no publication or installation authorized for this change.

## Finding

No verified CDM-independent route was found for reliably identifying all restricted Missile Barrage / Clearcasting gains and losses in Forever combat. This is narrower than claiming every buff requires CDM. Epicast already uses readable aura data and spell-overlay signals when available.

The Forever [aura API declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) mark direct spell lookups as requiring a non-secret aura. Iteration and duration-display APIs do not guarantee a readable identity or boolean for a restricted aura. The [spell overlay API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellActivationOverlayDocumentation.lua) supplies activation events, but those are not a general aura-presence API. Earlier user reports showed these proc bindings inactive while the corresponding buff was present. Inferring an RNG proc from a successful cast would not reliably handle the observed Arcane Blast clear.

[JustAC's author investigation](https://github.com/wealdly/JustAC/blob/main/Documentation/AURA_IDENTITY_12.0.md) describes a public non-secret-aura route and a native-CDM route. Their experiments found that transparency preserves populated tracking, whereas disabling/hiding viewers breaks it; attempted native refreshes and Lua-field setters caused errors. This is author-reported evidence, not an Epicast in-game measurement. [JustAC's implementation](https://github.com/wealdly/JustAC/blob/main/MaintenanceTracker.lua) also applies cosmetic suppression. Epicast implements its own reversible visual-state handling; no third-party code is bundled.

The [Forever viewer source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua) independently explains the behavior: OnShow registers UNIT_AURA, OnHide unregisters it, and ShouldBeShown rejects a disabled CVar or a Hidden viewer setting. Merely keeping the feature enabled is insufficient if its buff viewer is Hidden. Native acquisition also resets tooltip/mouse state when rebuilding pooled items. The [widget API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua) exposes independent mouse-motion/click controls, with protection checks required in combat.

**Conclusion:** leave CDM enabled and the relevant tracked-buff viewer set to Always, then make its display transparent. This has stronger support than a guessed cast-to-aura association or forced native refresh. New client changes and exact live appearance still need player testing.

## Player setting

Checkbox: **Hide Cooldown Manager (keep tracking active)**.

Inline explanation:

> Buff/proc effects that use Cooldown Manager require it to be enabled in WoW settings, with the buff tracked and its viewer set to Always. This option hides the display without disabling tracking. CDM is revealed in Edit Mode and its settings.

The option is shared by the two editor categories, starts off, and uses the existing Save/Cancel/Close transaction. It affects Essential Cooldowns, Utility Cooldowns, Tracked Buffs and Tracked Bars. It does not enable CDM, change tracked spells or alter Blizzard's layout visibility setting. The supported proc must still be added to Tracked Buffs/Bars by the player. Other cast/channel/success effects are independent of this option.

## Implementation

`CooldownVisibility.lua` stores all bookkeeping in its own weak-key tables. It uses alpha0 on the four viewer roots, leaving shown state and native event subscriptions intact. The reader still rejects genuinely hidden native viewers and edit previews. Public active flags remain the source of truth, not alpha or icon visibility.

Direct widget mouse-motion/click setters suppress input on nested CDM children, including pooled grandchildren. Original values are remembered independently; subsequent native or other-addon setter requests update the restoration values. Uncheck, Cancel, Close, native Edit Mode or CDM settings restore the prior state. Reparented/replaced widgets are released. Protected mouse setters are deferred during combat and reconciled afterward. Secret/unavailable properties are skipped.

Secure post-hooks observe native SetAlpha/mouse changes and RefreshLayout completion; Epicast never calls that refresh itself. OnShow/OnHide hooks reveal/reapply cosmetics. Addon-load, world-entry, CVar/layout notifications and combat-end events cover late loading. There is no new OnUpdate loop or periodic polling. Existing buff polling is unchanged.

Never call viewer Show/Hide, SetTooltipsShown, UpdateSystemSettingValue or RefreshData; never write native Lua fields or alter native event registration. These would change native lifecycle or risk tainting its restricted-data processing.

## Validation

`tests/cooldown-visibility.lua` exercises actual current runtime/UI handlers with native-method guards: default-off behavior, all four roots, nested input controls, exact restoration (including initially disabled input and non-unit alpha), latest external visual intent, Save/Cancel/Close, Edit Mode/settings reveal, pool rebuilds, reparenting/replacement, delayed addon loading, secret properties, combat guards and persistence.

The same test runs repeated Missile Barrage gains/losses through the real native reader and bound-effect handler at alpha0 and tests Druid Clearcasting reading at alpha0. A truly hidden viewer remains rejected, and no force-enable, CVar write, native data refresh or native Lua-field mutation is allowed by the mock. Existing regression and asset audits remain required. These checks do not prove client taint behavior or visual results; enable CDM/Always, toggle Epicast's option, and test repeated gains/clears in game for acceptance.
