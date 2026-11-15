# Epicast handover

Prepared 2026-11-15. Current build: **0.1.0-beta.2**, authorized for GitHub beta publication; initial release: **0.1.0-beta.1**. Saved-settings schema **1**, WoW Forever interface **16001**.

## Delivery and current status

The requested sequence was followed: the small EndCapper Arcane beta was built, checked and linked to the user before work on this fork began.

| Deliverable | Location |
| --- | --- |
| Friends' EndCapper Arcane-only beta | `F:/Work/WoW Addons/EndCapper/artifacts/arcane-only-beta/EndCapper-Arcane-Mage-Beta-1.zip` |
| Independent Epicast source | `F:/Work/WoW Addons/Epicast` |
| Latest local test ZIP | `dist/Epicast-0.1.0-beta.2.zip` |
| Beta.2 release | `https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.2` |
| Published beta.1 | `https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.1` |
| Exact package size, SHA256 and file count | `dist/package-verification.json` |
| Approved media hashes | `tools/media-manifest.json` |
| This handover | `handover.md` |

Epicast contains 20 Lua modules, two XML actor templates and 18 TGA assets. The installable ZIP contains 45 files including its TOC, player README, changelog and license notices. Its compressed size is approximately 7 MB. Development dependencies, tests, source tooling, this handover, old artwork and historical documents are excluded from the installable ZIP.

Local integration, Lua 5.1 parsing, scope and media audits pass. Packaging verifies every archived entry against its source SHA256. The previous scan-fix beta is installed in `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`. The Cooldown Manager beta.1 was subsequently pushed and published to GitHub under user instruction; the user then made the repository public. The About sidebar links to the releases page because GitHub does not feature beta prereleases as Latest. Beta.2 addresses a reproducible trigger-engine failure path after the friend reported all effects stopped; the user subsequently authorized its GitHub publication. The affected client's error/restart evidence remains pending. See `docs/release-0.1.0-beta.2.md` for release identity and asset evidence. No game UI automation or SavedVariables editing was performed.

## Product contract

Epicast owns independent artwork frames under `UIParent`. It does not replace, reparent, anchor to or derive positions from Blizzard endcaps or an action bar. The optional **Hide Blizzard endcaps** setting starts off. It changes only the native decorative texture alpha, preserves external alpha changes and restores the latest external value when disabled. Combat defers reconciliation.

There are two physical locations and two content roles:

| Physical location | Default role | Initially enabled | Placement |
| --- | --- | --- | --- |
| Central set | Spellcasting | Yes | Pair centered near the bottom, with adjustable separation |
| Edge set | Resources | No | Pair near the lower screen edges, with adjustable inset |

Each role occupies exactly one location in the saved configuration, even if that location is disabled. Assigning a role to one location moves the other role to the other location. The UI cannot create two Spellcasting sets or two Resource sets. Normalization also repairs duplicate assignments in malformed saves. Central-only, Edge-only, both-on and both-off are supported.

**Role content follows the role; placement follows the location.** A tuned spell effect stays with Spellcasting when locations swap. Central gap, Edge inset, individual drag offsets and active checkboxes stay with their physical locations. The location's Swap sisters flag remains with that location.

Only the approved **Arcane Tome / Arcane Scroll** design is included. The optional resource pair currently reuses this art: left Health, right Mana by default. This was a stated implementation assumption, not a newly commissioned resource art set. Resource emissions respond to level and an optional small meter shows the percentage. The base artwork remains readable. No additional art was generated.

Mage-only visibility is on by default. This is class gating, not specialization switching: all Mage specializations can show this single design. The `E.Designs.arcane` metadata identifies the intended class/spec but is not a completed multi-spec selection system.

## Starting and testing

1. Fully exit WoW, extract `Epicast` into the game's `Interface/AddOns` directory, restart WoW and enable it.
2. Open `/epicast` or `/epic`. `/epicast dev` toggles developer controls and opens options.
3. Enable the desired locations. Use the role buttons or **Swap spell / resource locations** to move their content.
4. Select Central or Edge, then a sister. Drag the outlines or use set size, separation, offset and height controls.
5. Save commits the complete configuration. Cancel or closing options discards unsaved previews. Save keeps the panel open with a new clean draft.
6. In developer mode, **Open effects** opens the Arcane catalog and effect studio. Custom artwork controls are separate from native effect controls and can dock in the studio.

Both addons can load together because names, saved settings and templates are independent. Their artwork may overlap if both are enabled. Epicast does not automatically change EndCapper's selections or hide its frames.

The EndCapper beta is a separate deliverable, with root folder `EndCapper`, version `1.4.7-arcane-beta.1` and saved variable `EndCapperArcaneBetaDB`. Its README directs testers to move the full EndCapper folder aside before extraction so excluded assets are not left behind. It cannot coexist as a second installation of the same addon folder. The beta retains EndCapper's generic settings framework; Epicast is the separately cleaned fork.

## Source provenance and extraction

The source was the current **working tree**, not just a released commit, at `F:/Work/WoW Addons/EndCapper-GitHub`. Its HEAD was `04ad832c7b5d617370bb3e8fddff0a7e9e12c4fd`; it already contained substantial modified and untracked Arcane, effect-library and Timeworks work. Existing changes were preserved. Do not reset that working tree or assume its HEAD alone can reproduce this fork.

`EndCapper-GitHub/tools/Build-ArcaneBeta.cjs` creates the reduced EndCapper beta. `EndCapper-GitHub/tests/arcane-beta.lua` verifies its scope and settings behavior.

`EndCapper-GitHub/tools/Fork-Epicast.cjs` was the one-time extraction helper. The later one-time pruning helper was archived at `EndCapper/artifacts/arcane-only-beta/epicast-prune-inherited.cjs`. **Do not rerun these over Epicast:** the independent model, core, options, resource implementation, seal renderer and subsequent corrections are authoritative here. Those extraction helpers are not an Epicast build pipeline.

The fork copies the 17 approved Arcane artwork textures without resampling, regenerating or sharpening them again. Existing LICENSE and CAS third-party notices were retained; historical EndCapper names in those notices record provenance. The addon icon uses the user-supplied `C:/Users/info/Downloads/Arcane Magenta Sigil Orb.png` (1254 × 1254, SHA256 `0F57E3A8ED8F34C5CB6A263AF3B840CEE48B4770AB7D9AA7B3B8E025540EA601`), downsampled with high-quality bicubic filtering to a 128 × 128 BGRA TGA.

## Runtime modules and responsibilities

| File | Responsibility |
| --- | --- |
| `ArcaneData.lua` | Exact approved bounds and baked native effect placements, with explicit binding records |
| `Model.lua` | Schema, normalization, independent settings, role assignment, art registry and transactional editing |
| `Effects.lua` | Artwork-relative anchoring, natural-edge native viewport, common effect lifecycle |
| `NativeSmoke.xml` | Namespaced ModelSceneActor load callback template |
| `NativeEffects.lua` | Inherited model loading, overlap, camera projection, calibration and readiness handling |
| `CooldownBuffs.lua` | Read-only Missile Barrage detection from public native tracked-buff state; current metadata mapping and unavailable-state diagnostics |
| `BoundEffects.lua` | Public spell/aura/proc events, state/burst lifetimes, segment transitions and test triggers |
| `AddedEffects.lua` | Per-instance native layer pool and binding configuration |
| `MageBooks.lua` | Arcane-only book/scroll textures, native hover and registered emission atlas playback |
| `Seal.lua` | Arcane scroll's custom rotating seal and its delayed hover phase |
| `Resources.lua` | Resource reads, event updates, emission intensity and optional meters |
| `EffectCatalog.lua` | Eleven allowed native effect records |
| `EffectLibrary.lua` | Search and catalog access; rejects IDs outside this beta's scope |
| `EffectAnimations.lua` | Known animation segment durations for six of the allowed models |
| `EffectAuthoring.lua` | Static/Bound creation and declarative binding defaults |
| `EffectPreview.xml`, `EffectPreview.lua` | Independent preview actor, fitting and segment playback |
| `EffectControls.lua` | Added-layer selection and placement controls |
| `BindingControls.lua` | Trigger kind, spell/buff/proc, lifetime, intro/outro and test controls |
| `EffectBrowser.lua` | Catalog/studio UI and coordination with the selected set/sister |
| `Options.lua` | New Central/Edge configuration UI, custom artwork panel and Save/Cancel |
| `Core.lua` | Independent frames, placement, class visibility, combat deferral, native hide and commands |

The TOC order is significant. It loads definitions before Core starts the addon. Every Lua chunk receives the same private namespace through `local _, E = ...`. No global EndCapper namespace is used. Actor callback fields and XML templates have Epicast-specific names.

Removed from the fork: native Edit Mode profiles, old schema migrations, Blizzard cap ownership and geometry, Bartender integration, non-Arcane artwork registries and media, other custom artwork renderers, historical built-in effect profiles, old hardcoded CastEffects binding engine, compatibility aliases to EndCapper saved settings and release/CurseForge automation. Internal generic function names such as `UpdateNativeSmoke`, `MageBooks` and `CropNativeEffect` remain for the inherited rendering contracts; they do not load retired artwork.

## Saved settings and editing

Only `EpicastDB` is read/written. There is no automatic import from EndCapper or its beta, and no dependency on either addon's SavedVariables. Settings are currently account-wide; native layout/profile switching is intentionally absent.

Abbreviated schema:

```lua
EpicastDB = {
  version = 1,
  hideBlizzard = false,
  classOnly = true,
  sets = {
    central = { role="spells", enabled=true, size=100, gap=480,
      x=0, y=0, swapped=false, leftX=0, leftY=0, rightX=0, rightY=0 },
    edge = { role="resources", enabled=false, size=100, gap=480,
      x=0, y=0, swapped=false, leftX=0, leftY=0, rightX=0, rightY=0 },
  },
  content = {
    spells = { left=sideConfig, right=sideConfig },
    resources = { left=sideConfig, right=sideConfig },
  },
}
```

A side config contains its Arcane art ID, role, size, facing, effects/native flags, emission settings, scroll seal settings, optional resource/meter fields and a flat `addedEffects` array. Resource configs forcibly strip binding records and normalize layers to Static. Explicit empty effect arrays remain empty; only missing arrays initialize defaults. Unknown art/model IDs are discarded or replaced with the appropriate Arcane default. Numeric input is bounded and rejects NaN/infinity. At most 16 native layers are accepted per sister.

`E.Begin` creates a normalized draft; `E.Config` returns draft or saved state; `E.HasChanges` compares normalized settings; `E.Commit` writes only EpicastDB; `E.Cancel` drops the draft. Higher saved schema versions leave this build inactive instead of silently downgrading settings.

`E.GetSide(db, setKey, side)` resolves physical side through the location's sister swap. Its config follows content; its second return identifies the content-side key. `E.GetEffectLibraryTarget` returns the config, physical side and physical set. Manual tests include the physical set in their identity so identical art in the other location cannot receive the trigger.

## Rendering and animation invariants

Follow `AGENTS.md` here and the original `EndCapper/docs/artwork-fidelity.md` standard for any future artwork work. Preserve approved assets, registrations and timing unless explicitly retuned by the user.

- Native Translation hover is six seconds: two three-second IN_OUT legs.
- Arcane hover amplitude uses the accepted book width relationship, `width * 0.012 + 2`.
- Pixel-grid snapping is disabled and texel snapping bias is zero on moving custom textures.
- Size-specific TGA variants retain the accepted maximum CAS bake. Do not add sharpening again at runtime or rebuild from compressed previews.
- No rocking is introduced for this Arcane pair. The broader project standard allows independent ±3-degree/seven-second rocking where appropriate; that is not permission to alter approved Arcane motion.
- The scroll's seal retains its 24-second default revolution, six-second hover and one-second lag behind the artwork. Native phase/registration is preserved through routine updates.
- Emission atlases use two registered textures to blend adjacent frames, with the inherited 32-frame layout. These are masked original glyph/symbol/gem pixels, not newly painted art.
- Native effects retain the enlarged natural-edge viewport, camera projection, model origin compensation and overlap handling. There is no new straight bottom clipping mask.
- Resource intensity multiplies emission hosts and native scene alpha after normal rendering. It does not fade the physical book/scroll base.

Media inventory includes seven square size variants (192, 288, 384, 480, 576, 768, 887) for each of ArcaneTome and ArcaneScroll, one emission atlas each, `ArcaneSigilCASSize256.tga`, and `EpicastIcon.tga`. Exact byte lengths and SHA256 are in `tools/media-manifest.json`. The client provides native models by file ID.

## Native effect defaults and binding behavior

The model whitelist contains eleven IDs. Thirteen default placements use them:

| Sister | Effect / ID | Default behavior |
| --- | --- | --- |
| Tome | Arcane dungeon fog, 1713497 | Static |
| Tome | Kirin Tor seal, 243044 | Static |
| Tome | State arcane hands, 950917 | Static |
| Tome | Arcane Blast targetprecast, 1699091 | While casting Arcane Blast |
| Tome | Arcane storm channel, 5054328 | While Missile Barrage buff is present |
| Tome | Large Void Glow, 166009 | While Missile Barrage buff is present |
| Scroll | Large Void Glow, 166009 | Static |
| Scroll | Arcane dungeon fog, 1713497 | Static |
| Scroll | Jaina arcane cannon missile, 2499922 | Static |
| Scroll | Arcane Blast impact, 1712386 | Arcane Blast cast success, 1.333 s |
| Scroll | Arcane Barrage impactchest, 1622612 | Arcane Explosion success, 1.033 s |
| Scroll | Arcane Shot impactchest, 1545158 | Observed Arcane Missiles pulse, 0.667 s |
| Scroll | Arcane Surge precast, 4637330 | While channeling Arcane Missiles |

The effect's asset name is independent of the spell bound to it. In particular, Arcane Barrage impact art responds to Arcane Explosion, while the book's proc is **Missile Barrage**, as the user explicitly clarified.

Each layer stores file ID, model scale/origin, camera azimuth/elevation, desaturation, front/back order, UI size/angle/X/Y/opacity, animation and behavior. Bound layers add kind, spell/name-or-ID, duration, intro/outro flags and durations. Trigger kinds are Cast, Success, Channel, Pulse, Buff and Proc overlay. The current English default names can be replaced with localized names or numeric spell IDs in the studio; defaults are not automatically localized in this beta.

State triggers stay active while the public state is active. Success/Pulse triggers are bounded bursts. Repeated procs can start again after the prior buff ends. Interrupt/failure cancels channel and pulse state. Token-guarded callbacks prevent removed/reconfigured/disabled layers from being revived by old intro/end timers. Models are played only after readiness checks; long-lived states reconcile after loading, while a transient success arriving before its model is ready is not retrospectively replayed.

The event engine listens to player UNIT_SPELLCAST events, UNIT_AURA, spell activation overlay events, entering world/death/resurrection and combat start. Enabled Missile Barrage buff bindings additionally share a 0.1-second native-state poll, described below. Arcane Missiles pulses use observed successful channel subcasts, with public ID/name matching and short duplicate suppression. It does **not** synthesize five pulses on a guessed timer. A client that withholds those subcast events or exposes only restricted identifiers may not show pulse effects. This requires live acceptance on the target Forever build.

Animation IDs 0 / 158 / 159 are treated as intro/hold/end choices where known. Not every model has all three or uses those semantics identically. Known segment durations are included for six models; unknown availability is labeled unverified. Preview the actual model before enabling intro/outro. A model's own particle/global timeline may not behave like a simple finite sprite animation. No claim is made that every model can seamlessly loop every segment.

Manual trigger tests are available only for bound layers, last a bounded duration, target the selected physical sister/set, stop on context changes or combat, and return to actual live state afterward.

### Repeated Missile Barrage investigation, 2026-11-15

The user reports that Barrage effects trigger once and then fail, while Blast, Explosion, Missiles pulses and channel effects continue to work. They also observe Arcane Blast removing the actual Barrage buff. The current Epicast save retains both default Barrage layers as `buff` bindings with intro/outro disabled. Source and installed `BoundEffects.lua` matched when inspected.

`tests/buff-retrigger.lua` exercises three buff gain → Arcane Blast → buff removal → subsequent gain cycles in combat through real event handlers. Both effects stop and rearm, with no model reloads, full Apply calls or settings writes. This sequence already passed before the patch. Epicast contains no buff-cancellation calls. The game's reason for clearing Barrage remains unverified.

A separate regression failed before the patch when the direct name lookup missed and an earlier aura list entry was restricted. The safe reader collapsed that entry to nil and the scan stopped. The scan now distinguishes readable end-of-list from an unreadable entry and can reach later public aura identities. API errors stop the scan, and it retains the 255-entry bound. Restricted data never establishes a buff match. This is a confirmed code defect and a possible explanation for the live report. The failing live event sequence has not been captured.

`/epicast triggers` prints in-memory diagnostics for buff/proc layers, including lookup outcome, start/stop counts, native readiness, visibility, playback failure and the event associated with the last stop. It works without opening options or developer mode. Run it while a later Barrage buff is active but its effect is absent. A `matched` input with a visible ready scene points toward native visual playback, while `restricted`, `error` or `absent` identifies a detection limitation. The added tests cover those diagnostics, restricted values/tables/fields, repeated clearing/reapplication and recovery after an actor playback error.

The inspected Forever API declares conditional restrictions on aura lookup and enumeration. [Forever UnitAura declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)

The updated beta.1 passed the full integration suite, the new Barrage regressions and the media/scope audit. Its ZIP contains 44 verified source files, 7,016,724 bytes, SHA256 `D07B6B3CB6C718B6701750A4A4221B66CB165725E3C27A130EED390DCF7A6ED0`. Four changed files were installed and all 44 installed hashes matched the ZIP. Epicast SavedVariables matched the pre-install SHA256. The previous files are in `artifacts/barrage-before-926e1fea3245469f920c915e4d898158`. **Subsequent user feedback: their friend tested and Missile Barrage still did not trigger. The scan fix did not resolve the reported live failure.**

### Online investigation after the failed live test, 2026-11-15

Combat-time aura access is the leading explanation, not yet a captured diagnosis on the affected client. Epicast's `buff` path in `BoundEffects.lua` uses direct name/ID aura lookup and indexed aura enumeration. The current scan correction can reach a later readable aura but cannot identify Missile Barrage if that aura itself is restricted. Other successful cast/channel triggers use different inputs, so their continued operation does not establish that buff reads work. No live `/epicast triggers` output was supplied in this follow-up.

Primary evidence reviewed:

- [ProcDoc v4.14.0 release notes, November 10](https://www.curseforge.com/wow/addons/procdoc/files/9538564/additional-files) explicitly report fixing Missile Barrage and other procs failing during combat. The author switched to matching Forever's Cooldown Manager entries using game data and corrected several spell IDs.
- [ProcDoc source](https://github.com/wsmaxcy/ProcDoc/blob/main/ProcDoc.lua) maps Barrage aura `400589` to its Cooldown Manager/talent spell `400588`. `CDM.Active` prefers a readable boolean from the icon's `IsActive()` or `isActive`; comments describe direct aura access/hooks as the cause of its earlier regression. Its other fallbacks infer activity from restricted aura-instance presence or icon visibility. Those fallbacks are not a verified signal for Epicast and must not be copied as proof of an active buff. Its settings/layout mutations and synthetic duration/stack tracking are also outside this proposed solution.
- [Missile Barrage Glow](https://www.curseforge.com/wow/addons/missile-barrage-glow), updated November 11, explains that direct buff reads are hidden in combat and uses Arcane Missiles' mana cost. Its author documents delayed detection when Clearcasting was already active, since both procs make Missiles free. Mana cost alone is therefore not an exact, immediate Barrage signal.
- [Forever aura API declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) mark name lookup and indexed reads with conditional aura restrictions. The restriction applies to the data, independently of whether the addon receives an event.
- [Blizzard's November 2 development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-november-2/2360696/9) specify consumption of Barrage at the start of Arcane Missiles and preservation of Clearcasting when both are active. They do not establish that Arcane Blast is intended to consume Barrage. The user's reported Blast removal remains a separate unconfirmed game issue.

Recommended next implementation investigation: a read-only bridge to the matching native Cooldown Manager buff icon, accepting only an actually public active/inactive boolean, with explicit unknown/unavailable diagnostics and no alteration of the player's native layout or settings. Verify whether that icon exists and updates on the affected client; absent/hidden native tracking may limit this route. Do not equate restricted data with a proc or silently invent a proc timer. Keep normal public aura reads as a supported input. Regression coverage must include restricted Barrage data together with repeated native active/inactive transitions, expiration, consumption, missing tracking and unrelated Clearcasting.

At research time the test fixture labeled its synthetic Barrage aura `400588`; the external implementations identify the actual aura as `400589`. Those tests bind by name, so this mismatch does not explain their successful results or the name-bound live failure. The subsequent implementation below corrects the fixture. The research itself changed only this handover.

### Cooldown Manager implementation, 2026-11-15

User authorized implementation, regression tests and a rebuilt beta ZIP, with SavedVariables untouched. `CooldownBuffs.lua` now reads only `BuffIconCooldownViewer` and `BuffBarCooldownViewer`. It resolves each child's current cooldown ID through `C_CooldownViewer.GetCooldownViewerCooldownInfo`, matching Barrage's talent/entry spell `400588` or aura `400589` in base, override, tooltip or linked spell fields. Metadata is re-read each sample so released/reassigned icons cannot retain a cached identity. English default names, current localized Barrage names and either numeric spell ID select this bridge; other buff/proc bindings keep their existing behavior.

Only a public boolean from `IsActive()` or `isActive` establishes native activity. The reader excludes hidden viewers, native editing/demo state, cleared IDs and explicit non-player aura metadata. It never reads aura instances, infers activity from an icon being shown, hooks native functions, changes CVars/layouts, or enables tracking on the user's behalf. Conflicting duplicate native states are unknown. If native detection is unavailable, ordinary safe aura lookup remains the fallback.

`BoundEffects.lua` shares one native snapshot across both layers in each event/poll pass. A single 0.1-second timer samples while a usable Barrage buff layer exists; it catches native updates occurring after Epicast's aura handler and still works when event payloads are restricted. Polling stops when no eligible layers remain or the player dies, and resumes through normal effect/lifecycle reconciliation. No model reload, full Apply or settings write occurs during polling. `/epicast triggers` adds `cooldown=active/inactive/hidden/untracked/unavailable/preview/restricted/error/unknown/conflict` diagnostics.

Testing prerequisite: enable Blizzard's Cooldown Manager, track Missile Barrage under Tracked Buffs or Tracked Bars, and leave that native row enabled and visible outside Edit Mode. A hidden native viewer unregisters aura events and can hold stale state, so it is not used. These requirements are also in the packaged README. No external addon is required. Native public-state availability on the affected client's build is still a live test, not proven by mocks.

`tests/cooldown-buff.lua` first failed against the previous runtime when a native activation followed a restricted aura event without a second event. It now passes alongside the full existing suite. It exercises both book layers, repeated clears/re-procs, consumption, expiry, unchanged Missiles channel/pulses, unrelated Clearcasting, both native viewer types, spell aliases/localization, identity reuse, hidden/edit/demo/unknown/secret/error/conflicting data, missing and late native tracking, public aura fallback, diagnostics, death/resurrection and disabled/removed effects. It asserts zero model reloads or Apply calls and deep equality of mock settings. Existing aura fixtures now use `400589`.

Implementation source reference: [Blizzard Forever CooldownViewer.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua) (`IsActive`, buff `ShouldBeActive`, `OnHide`, pool reset and layout), [native viewer XML](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml), and [CooldownViewer API declarations](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CooldownViewerDocumentation.lua). ProcDoc informed the investigation; no third-party implementation was copied.

Current package verification is in `dist/package-verification.json`; build evidence is in `docs/verification.md`. This rebuild was not installed or published. SavedVariables were neither opened nor modified for this implementation.

### Beta.2 trigger isolation, 2026-11-15

After publication the user reported that their friend now sees no effect triggers at all. Asked for the first Lua error/stack, whether artwork remains visible, and whether installation was followed by a full client restart or only `/reload`. No answer had arrived when this test build was prepared. Do not claim the affected client's root cause is confirmed.

A clean harness loading the release with `CooldownBuffs.lua` omitted reproduces a concrete integration defect: `E.SyncBoundEffect` calls the missing `E.IsCooldownBuffBinding` for every kind of effect, aborting setup at the Tome's fourth layer before the Scroll is created. Cast events subsequently hit the same nil call. A thrown native-reader error can also abort setup/event iteration. The former tests always loaded all modules and only simulated failures inside individual native API calls.

Beta.2 gates the optional bridge by buff kind and guards both its binding detector and its reader with protected calls. Missing/error results use readable aura fallback with explicit diagnostics; unrelated cast/channel/success/pulse paths continue. The new `tests/trigger-isolation.lua` runs in fresh Lua VMs for missing module, missing reader, thrown reader and thrown binding detector. It first failed against beta.1, then passed repeated Blast/Explosion/Missiles/buff cycles, diagnostics and reader recovery with no model reloads, full Apply calls or mock-settings changes. The existing full suite also passes.

`/epicast triggers` now reports trigger-code revision `0.1.0-beta.2`, spell-event counts and every bound effect, including enabled/artwork-visible flags. `module missing`, `reader error` and `binding error` distinguish optional bridge failures; the header retains the latest reader/detector error. Corrected installation instructions require closing WoW completely before extraction and restarting, so newly added files can be discovered. No automatic settings reset, game installation, commit, push or new public release was made as part of this local diagnosis/build. SavedVariables were not accessed.

## Resources

Supported sources: Health, Mana (0), Energy (3), Rage (1), Focus (2), Runic power (6), and Current power via `UnitPowerType`. Defaults are Health/Mana. The source can be changed per resource sister.

Resource updates listen to player UNIT_HEALTH, UNIT_MAXHEALTH, UNIT_POWER_UPDATE, UNIT_POWER_FREQUENT, UNIT_MAXPOWER and UNIT_DISPLAYPOWER. They do not poll on a per-frame loop. Values are protected-call reads; secret/non-numeric/unavailable data or non-positive maxima yield unknown state. Unknown meters show `—` and use minimum emission intensity rather than stale or invented data.

For a known ratio, intensity is `0.12 + 0.88 * ratio`. Book glyphs, the scroll seal and native ambient layers follow it; the art itself remains opaque. The optional percentage meter is independent of the animation checkbox. Resource layers cannot be given spell bindings, even through malformed saved data. Swapping locations retains resource selection and tuning.

## Development and verification

Run from `F:/Work/WoW Addons/Epicast`:

```powershell
npm ci --ignore-scripts --no-audit --no-fund
npm test
npm run audit
./tools/Package.ps1
```

Only Fengari and luaparse are development dependencies. None are installed into WoW. The lockfile is included in the source workspace. Network access is needed for a fresh npm dependency installation unless cached.

`tools/test.cjs` parses all 20 modules as Lua 5.1, then loads them in real TOC order under a UI/game-event mock. Tests run real option, studio and renderer handlers. Covered cases include fresh defaults; all assignment/activation combinations; duplicate-role repair; content-following swaps; Save/Cancel; resource changes and restricted data; authoring bindings/segments; resource binding rejection; repeated buffs and native Cooldown Manager detection; cast/channel/pulse events; interruption; combat deferral; hide/restore; independent settings and frames; inherited animation settings; manual test isolation; stale timer cancellation; disabled-set events; empty arrays; malformed numbers; and individual drag rollback.

`tools/audit.cjs` checks that every runtime Lua/XML file is in the TOC, checks independent names and excluded legacy names, rejects dynamic script execution, verifies the eleven-model catalog, and validates every approved texture's hash, byte length and uncompressed 32-bit TGA format.

`tools/Package.ps1` uses a positive file allowlist from the TOC, five metadata files and the media manifest. It checks archive entry count and each entry's SHA256 against its source, then writes `dist/package-verification.json`. It does not install, publish, access SavedVariables or invoke Git. Rerun tests/audit before packaging after any change. For deliberate asset changes, review the new source before updating the media manifest; do not regenerate the manifest merely to silence a mismatch.

## Remaining live acceptance

1. Load Epicast without EndCapper; confirm no Lua errors and correct Tome/Scroll registration, hover, emissions and seal.
2. Exercise Central-only, Edge-only and both; swap roles while both are enabled; verify sizes, offsets, sister swaps, Save/Cancel and reload persistence.
3. Test optional native endcap hiding and restoring with the target action-bar configuration. Its path currently targets Forever's `MainActionBar.EndCaps` textures.
4. Test all default Arcane bindings, several consecutive Missile Barrage procs, interrupted Missiles and individual pulse visibility. The local test supplies observed pulses and does not prove the client emits them.
5. Verify Health/Mana meters and glow intensity while changing levels, including low/zero mana and unsupported resource choices.
6. Preview intro/hold/end on intended models; test a bound layer; remove it during playback; verify no later ghost activation.
7. Check options/studio placement on the player's resolution/UI scale. The main panel scales to screen height; unusually narrow screens may require moving the studio/custom panel.

Do not describe local mock validation as live client acceptance. No per-spec art switcher, profile manager, dedicated resource artwork, automatic settings import, new Epicast icon, CurseForge project or release pipeline is configured. These are explicit future work, not hidden dependencies.

## Reference implementation sources

- [Blizzard Forever UnitFrame resource implementation](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitFrame.lua) — public health/power reads and event-driven updates.
- [WeakAuras custom triggers](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Triggers) and [GenericTrigger implementation](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/GenericTrigger.lua) — event/state trigger reference from the preceding EndCapper work. Epicast has no WeakAuras runtime dependency.
- [Blizzard Forever ModelSceneActor API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua) — native actor API reference.

Future work should extend the independent design/content model rather than restoring action-bar ownership or legacy EndCapper migrations. Preserve role uniqueness, explicit public-event restrictions, per-instance lifecycle ownership, exact asset registrations and Save/Cancel integrity.
