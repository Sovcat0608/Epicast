# Main UI audit and redesign — beta.15

> Current beta.16/schema6 supersedes effect-save ownership described below: crest effects are shipped definitions, developer edits are session-only, and only normal UI preferences persist. See [crest bakes](crest-bakes.md). Main tabs use native Warcraft attached tabs; library layout is unchanged.

## Scope and evidence

Audited the beta.14 main options window, schema/model, first-use setup, class selection, draft transactions, drag handlers, resources, animation switches and effect-library handoff. Findings come from the actual Lua handlers, fixed layout dimensions and executable widget mocks. No game UI automation or SavedVariables access. The effect library window and its controls are outside this redesign and remain byte-identical to beta.14.

## How configurations actually work

| Concept | Source of truth | User meaning |
|---|---|---|
| Spellcasting crest | `content.classes[CLASS].slots[spec]` | One fixed artwork identity with its own size, X/Y, facing, animation and effect layers. All nine classes have three slots. |
| Active crests | Class bank `active` map | Any combination, including none. Selecting a card for editing does not activate it. Talent specialization does not select artwork. |
| Resource crests | `content.resources.left/right` | Two independent, shared resource configurations. The keys are compatibility identifiers; neither is constrained to a screen side. |
| Sets | Editor categories only | Spellcasting and Resources organize the interface. Schema5 has no linked placement set or reusable layout preset. Old set data is used only for migration. |
| Artwork | Spec-to-art mapping | Mage and Druid have current dedicated art. Pending classes/resources can still hold native effects. Existing legacy Druid source assets are not interchangeable spec selectors. |
| Placement | Each crest's size/X/Y/flip | Horizontal0 is screen center; height0 is the crest frame's bottom at the screen floor. Changing one crest never rearranges its neighbors. |
| Animation | Each crest's `effects` flag | One existing switch controls both hovering and native effects. This redesign does not pretend these are independent controls. |
| Global settings | `hideBlizzard`, `hideCooldownManager`, `classOnly` | Endcaps, CDM display and the resource class filter apply across crests. |
| Save transaction | Normalized in-memory draft | Save commits all edited crests/classes/settings together. Cancel/Close rolls back. Developer mode, class preview and editor navigation are session-only. |

## Critique and resolution

| Priority | Observed issue | Consequence | Implemented resolution |
|---|---|---|---|
| High | One 640×824 panel mixes choosing artwork, placement, playback, global settings and diagnostics. | Competing scopes and excessive vertical scanning; the panel scales down on shorter displays. | 840×632 panel with Crests / Settings, a persistent chooser, and Placement / Behavior for the selected crest. Fits both screen dimensions. |
| High | Show checkbox, name button and numerical row summary have similar visual weight. | Editing a crest can be mistaken for enabling it. | Thumbnail cards, explicit Show checkbox, selected-card marker, and selected-crest Shown/Hidden status. Hidden configurations remain editable. |
| High | A 270px horizontal slider spans 16,000 position units. | Small adjustments are difficult to target and values are not directly editable. | Signed/decimal inputs, one-unit nudges, Shift-ten-unit nudges, keyboard traversal, drag outlines and explicit alignment actions. Size retains a slider plus exact input. |
| High | Resource preview bypasses the Mage-only display restriction. | Resources can seem to work only while options are open. | Contextual Preview only status, an explanation in Behavior, and a clearly scoped resource visibility setting. |
| Medium | Close does not communicate loss of pending changes; Save applies more than the selected crest. | Transaction scope is easy to misunderstand. | Always-visible Save all changes / Cancel, cross-tab dirty status and Discard & close text. Pending typed values participate in Save and remain associated with their original crest. |
| Medium | Developer tools depend on discovering a slash command. | Effect editing and cross-class authoring are difficult to find. | Session-only Developer mode in Settings; class preview above the cards; effect-library entry point in Behavior. |
| Medium | The animation switch sounds narrower than its actual behavior. | Turning off hovering unexpectedly also stops spell effects. | Explicit Enable animation and effects label and a description of both consequences. No renderer or schema change. |
| Medium | Main UI offers little explanation of the current effect configuration. | Users must open the library or infer what a crest responds to. | Read-only grouped spell-response summary, layer counts, static-only/empty/paused states and guarded spell-name lookup. |
| Medium | Drag outlines stay active throughout configuration. | Browsing settings or effects can inadvertently move artwork. | Outlines and drag updates are active only in Crests / Placement, and stop immediately when leaving it. |

## Interaction design

**Crests:** choose Spellcasting or Resources, then select a card. Show checkboxes independently control visibility. The first-use prompt explains multi-selection and that talent changes do not switch crests.

**Placement:** size slider/exact size; horizontal and bottom-relative inputs; +/- nudges; Center horizontally / Align to bottom; Mirror crest; Reset placement. Reset changes only the selected size/X/Y and is reversible through Cancel. It does not reset effect tuning, bindings, mirror state or another crest.

**Behavior:** animation/effects switch and its scope; a grouped overview of spell responses, or resource type/meter and visibility guidance. Developer mode adds Open effect library and Print trigger report. The existing library UI and shared transaction contracts are preserved.

**Settings:** Game interface, Resource visibility and Developer tools. The CDM requirement stays beside its toggle: enabled in WoW, relevant buff tracked, viewer Always; Epicast hides the display without disabling tracking.

Tab navigation does not commit, reset or dirty configurations. Enter/focus loss applies a valid numeric edit to the draft; Escape reverts unfinished text. Tab/Shift+Tab moves between numeric fields. Invalid/non-finite input retains the previous value and explains why. Combat discards unfinished field text and disables mutations; Close remains available and existing renderer deferral applies. Developer preview ends on Close or disabling developer mode.

## Verification and remaining acceptance

`tests/options-redesign.lua` executes the real current modules and real UI callbacks. It covers first use, pure navigation, separate selection/visibility, inactive editing, decimal/bounded/invalid input, guarded name lookup, focus/Enter/Escape/Tab, nudges, exact alignment, scoped reset, pending-text Save/Cancel/Close, cross-tab transactions, class previews, resource restrictions, combat and the unchanged library handoff. Layout checks assert non-overlapping visible action targets, persistent footer access and viewport bounds at1920×1080,1280×720 and800×600. Existing migration, Arcane preset, repeated Barrage/Clearcasting and artwork regressions remain required.

Offline previews under `artifacts/ui-redesign/` are rendered from the actual mock widget tree and existing textures. They were inspected for hierarchy, spacing and readable labels. They are layout illustrations, not game screenshots: native font metrics, slider chrome and widget skins can differ. Live visual/keyboard acceptance remains a manual client check.

Delivery: local beta.15 test ZIP, subsequently installed at the user's explicit request with all81 payloads verified and a verified beta.14 backup/rollback. No Git commit/push/publication, asset regeneration, binding/default edits, schema migration or settings-file access. Public release remains beta.14; installed test build is beta.15. See `release-0.1.0-beta.15.md` for the install receipt.
