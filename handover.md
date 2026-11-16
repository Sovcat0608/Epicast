# Epicast handover

## Current installed and public release: beta.17 (2026-11-16)

User asked for adjacent tabs, an Open effects button in developer mode and any record of lost Restoration tuning. Native tab OnShow/display events shrink widths, exposing the fixed X offsets from beta.16; tab rows now use sibling anchors and natural sizing. Open effects moved to the crest header so Placement and Behavior both expose it. Scoped read-only recovery from the already archived pre-reset Epicast backup found nine exact Restoration layers. They are now the shipped DRUID:restoration bake; no live account files were accessed. See `docs/restoration-recovery.md` and `docs/release-0.1.0-beta.17.md`. Full tests/audit passed. Built and installed83-file beta.17 ZIP (25,933,980bytes, SHA256 `A35F31C6CD9ED8FD444210171F054E5F8DB544A2F4B42E4F1A31D1DFB98DAB0B`):5 changed,78 identical,0 removals; all83 installed hashes and5 backups independently verified. Backup/rollback preflight `artifacts/install-20261116-200109/`. The user accepted the installed result and requested publication. Published https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.17 at20:06:58UTC, prerelease=true/draft=false. Tag `687189e3ee2a19894697ff0dc779d119019828b1` matches all83 payloads; remote tag and both uploaded ZIP/checksum sizes and SHA256 digests verified. No runtime changes/rebuild/reinstall or SavedVariables access for publication. See `docs/release-0.1.0-beta.17.md` and ignored `artifacts/publish-beta17/`.

## Current installed and public release: beta.16 / schema6 (2026-11-16)

Published https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.16 at19:49:20UTC; prerelease=true/draft=false. Tag `8d4577eadf415ae7611bac7fba5aab103983d9db` matches all83 payloads. ZIP25,932,556bytes, SHA256 `A409919DDC6889FFBB28C9713A1CBE834FDD94C61B200F52FF656EDE9162D26C`; uploaded ZIP/checksum sizes/digests and remote tag verified. Installed83 files (10 changed/new,73 unchanged,0 removed),8 backups verified under `artifacts/install-20261116-194722/`. Full tests/audit pass; all49 textures unchanged. Full restart required for new modules.

User explicitly authorized native Warcraft tab styling, authoritative crest-owned effect bakes, build/install and GitHub beta publication. Supersedes all older saved-effect preservation rules below. Normal preferences remain; stale effect arrays/empty overrides no longer mask the approved twelve-layer Arcane bake. Developer edits are RAM-only with effect-only JSON export and validated compiler. All artwork and native trigger/CDM code remain unchanged. See `docs/crest-bakes.md` and `docs/release-0.1.0-beta.16.md`. No SavedVariables files accessed for this work.

## Explicit local configuration reset (2026-11-16)

User requested clearing their Epicast configuration because their friend's beta.14 upgrade retained older effects. Updates intentionally preserve existing saved arrays; newly baked defaults only initialize fresh configurations. The initial guarded attempt found WoW running and made no changes. After the user confirmed exit, verified no WoW process, copied/hash-verified only the active account's Epicast.lua and Epicast.lua.bak into ignored `artifacts/config-reset-20261116-192255/`, then removed those exact two active settings files and verified absence. This explicit request authorizes the one-off backup/reset despite earlier SavedVariables restrictions; unrelated/future access remains prohibited. Full private backups must not enter Git or release packages.

Installed beta.15 ArcanePreset.lua hash matches source, and the approved twelve-layer fixture comparison passes. Next login recreates defaults, including crest selection, placement and global preferences. No other addon settings or installed payloads changed; no publication. Backup README and reset-verification.json contain restoration details. No live default-load acceptance claimed.

## Current installation: beta.15 UI test build (2026-11-16)

User explicitly requested installation for testing. Installed the exact verified beta.15 ZIP to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`:81 payloads independently hash-verified,5 changed,76 untouched,0 removals. All five original beta.14 files were backed up and independently verified. Receipt/backup: `artifacts/install-20261116-184749/`; optional `Rollback-to-beta.14.ps1` (append `-Check` for dry run) restores only those five addon files. The real rollback preflight passed without applying it. SavedVariables files never accessed. WoW was not running during preflight; start/restart the client and open `/epicast` for manual review. No commit/push/publication; public beta.14 remains. Beta.15 in-game acceptance is pending.

## Current local source: beta.15 main UI redesign (2026-11-16)

User requested a complete main UI/UX audit and rework, explicitly leaving the effect library window alone. `docs/ui-ux-audit.md` records the configuration model, prioritized critique and resulting flows. Rebuilt Options.lua as an840×632 Crests/Settings panel with a visual Spellcasting/Resources chooser and separate Show controls, Placement/Behavior detail pages, precise numeric input/1-or10-unit nudges/alignment, read-only spell-response summary, clear resource-preview filtering, session-only developer toggle and permanent Save all changes/Cancel footer. Close signals unsaved loss. No new profile/set semantics or schema changes.

Core only changes drag-handle eligibility to Placement and routes the slash-command developer toggle through the shared UI handler. Library source files, all49 textures, Arcane defaults/bindings, CDM helpers and native rendering/trigger code remain unchanged. First-use choice, class preview, shared draft and migration contracts survive. New real-handler tests cover navigation, precise/pending/invalid edits, target isolation, transactions, guarded spell-name lookup, class/visible-state restoration, combat and non-overlapping action bounds across screen sizes. Current compatibility tests were adapted to the exact position inputs and page navigation; historical fixtures are unchanged.

Offline layout previews captured from the actual widget mock were inspected; they use substitute fonts/skins and are not game screenshots. Full tests/audit passed.74 protected runtime/library/artwork files match beta.14 byte-for-byte. Built `dist/Epicast-0.1.0-beta.15.zip`:81 files,25,929,924 bytes,SHA256 `763A857F85E9E1A1A3178C9E864854022AEA5D4335DD4F06F7CEB060DF8C99C5`. Source/archive hashes verified; comparison to beta.14 finds76 identical payloads and only Options/Core/TOC/README/CHANGELOG changed, no additions/removals. Evidence: `artifacts/ui-redesign/`; delivery: `docs/release-0.1.0-beta.15.md`. Local test ZIP only; no install, commit/push or publication. No SavedVariables access. Public and last verified installed build remain beta.14. Manual in-game visual/keyboard acceptance of beta.15 is pending.

## Current public release: beta.14 CDM display hiding (2026-11-16)

The user accepted the installed beta.14 build and explicitly requested publication on GitHub. Published https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.14 at18:05:15UTC, prerelease=true/draft=false. Annotated tag resolves to `0103ec4e7c67eb619eb4cbe744ebb71d7d304a54`; all81 source payloads match that commit. Main and tag pushed. The exact tested ZIP and checksum companion have matching uploaded sizes and GitHub SHA256 digests. Full tests/audit passed again. No runtime/default/art edits, reinstall or SavedVariables access for publication; local backups, comparison extracts and abandoned experiments stay excluded. Receipts: `artifacts/publish-beta14/`; details: `docs/release-0.1.0-beta.14.md`.

## Current installation: beta.14, Arcane defaults checked (2026-11-16)

User explicitly requested comparing current installed Mage/Arcane printed configuration to the defaults and installing with optional rollback. Read-only literal-data extraction of the 17:43:00.513 UTC Epicast save confirmed all twelve Arcane layers exactly match `tests/fixtures/arcane-beta13.json`: model fit, placement, opacity, playback and spell bindings. `node tools/test-arcane-preset.cjs` independently confirms the runtime preset matches this fixture. No default edits were needed. Only effect data was exported; no SavedVariables writes or full-save snapshots. Comparison/evidence lives in ignored `artifacts/arcane-defaults-beta14/`.

Installed the existing beta.14 ZIP to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`:81 payloads verified,11 new/changed,0 retired removals. Nine previous beta.12 files were backed up and independently hash-verified; two files are new. Receipt/backup: `artifacts/install-20261116-174951/`. SavedVariables hash remained unchanged through installation. WoW was running by installation time, so a full restart is required; no live acceptance claimed.

Optional rollback launcher: `artifacts/install-20261116-174951/Rollback-to-beta.12.ps1` (add `-Check` for a dry run). It delegates to `tools/Rollback-Install.ps1`, which validates all current/backup hashes before restoring nine files/removing two new files, refuses later modifications and is idempotent. Real rollback plan passed without applying it; isolated `tools/Test-Rollback.ps1` passed dry-run, restore/remove/retired cases, repeated rollback, drift/corruption and unsafe-path refusal. No game UI automation or Git publication. Public release remains beta.13; the following source-feature record remains applicable.

## Current local source/test ZIP: beta.14 cosmetic CDM hiding (2026-11-16)

User requested research into proc/buff tracking without visible/enabled CDM, with a hide-but-keep-enabled fallback and disclaimer. No reliable general disabled-CDM path for restricted Forever buffs was verified. Primary Forever API/viewer sources and JustAC's author research support alpha0 while leaving native frames shown; native Hide unregisters UNIT_AURA. Never force native refreshes or change CDM's Lua fields. Full sources/rationale: `docs/cooldown-visibility.md`.

Added default-off `hideCooldownManager` to schema5, shared Save/Cancel/Close setting and inline requirements: enable CDM in WoW, track the buff, viewer Always; Epicast hides display only. `CooldownVisibility.lua` owns reversible alpha/input bookkeeping, handles allfour viewers and pooled grandchildren, native Edit Mode/settings reveal, external visual intent, late loads/reparenting/replacement, secret values and protected combat deferral. No native Show/Hide, CVar/config changes, native refresh calls, Lua-field writes, new polling or OnUpdate. The buff reader itself stays read-only and rejects truly hidden viewers; only its setup hint changes.

Full tests pass including alpha-zero Barrage/Clearcasting, repeated gains/clears, real Save/Cancel, original opacity/input restoration, native pool callbacks and forbidden-call guards. `npm ci`/audit passed;27 runtime entries and49 unchanged artwork assets. All effects/presets/art/placement remain unchanged. No SavedVariables access, UI automation or live appearance acceptance claimed.

Local `dist/Epicast-0.1.0-beta.14.zip`:81 files/25,925,680 bytes/SHA256 `00CB3AE2AECC1B28554F1F7DDA82F0475A109C599B5915D706C1C8EAB7EB986C`. Source/archive hashes verified;73 payloads identical to beta.13, seven changed plus one new module. Evidence `artifacts/cooldown-visibility/`; delivery record `docs/release-0.1.0-beta.14.md`. Subsequently installed at the user's request as recorded above. No commit/push/publication; public release remains beta.13. Trigger diagnostic revision stillbeta.13 because BoundEffects.lua is unchanged. Abandoned experiments remain local/untracked.

## Previous public release: beta.13 Arcane bake (2026-11-16)

User explicitly requested publishing a beta and clarified: bake the in-game effects and spell binding configuration. This authorizes a one-time read of Epicast's Arcane save, overriding the earlier no-read rule for this task only. Read literal data from the 17:16:05.228 UTC save; source SHA256 `9B061597DACEF50CBA6ED14545D0CD400C09E7F158D68C33A154AD112009F892`. No save writes/full snapshots. Only the twelve Arcane effect rows are retained in `tests/fixtures/arcane-beta13.json`; no personal placement or other classes are baked. See `docs/arcane-preset.md`.

`ArcanePreset.lua` supplies six static/six bound layers for fresh Arcane slots. Existing saved arrays, explicit empties and legacy two-list merge survive; fresh slots no longer incorrectly take the legacy pair defaults. Artwork, schema5, all other defaults and native renderer/reader logic remain unchanged. Full tests including exact export, live preset spell routes, repeated Barrage clears and rapid re-proc during outro pass. `npm ci` and audit passed. All49 media assets are unchanged from beta.12.

Published `dist/Epicast-0.1.0-beta.13.zip`,80 files/25,922,957 bytes/SHA256 `BC55855E02CAD469CEC050B52B3B8F4896C1B32EABE104CA825F19AC35FD0DEF`, with checksum companion at https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.13 . Published17:24:33UTC, prerelease=true/draft=false; tag resolves to `36539589b2f9996810342bad4a8f6c652a859cf9`. All80 packaged sources match the release commit; both uploaded sizes/digests verified. Source pushed to main. No reinstall requested; beta.12 remains installed. Source save hash rechecked unchanged. Receipts under `artifacts/arcane-bake-beta13/`; see `docs/release-0.1.0-beta.13.md`. Abandoned `animation-rnd/` and earlier Groveheart experiments remain local and are excluded from publication.

## Previous local installation: beta.12, uncorrected Mage option 1 (2026-11-16)

The user preferred **the first uncorrected crown/pendant option** and explicitly requested baking/building/installing it. Integrated exact `concepts/mage-reboot/Mage-reboot-trio-v3-initial.png`, SHA256 `5DD9D15C1D72C67EFB83DFA664E235E450B36C8B8C1C3BBC7CC017B2A2D3F5AC`. The corrected/framed v3 versions were not chosen. Do not silently replace the approved source with either later image.

New MageRebootData.lua / MageReboot.lua render three independent complete square crests with all floating shards, native six-second phase-preserving hover and no snapping. Eighteen size-specific CAS textures derive from exact source columns with transparent padding, no dropped pixels, no repaint/upscale. Default216×216; native effect arrays/bindings/placement retained. Schema remains5; historical migration geometry remains unchanged. No separate scroll/pendant/shard animation. Resources retain pending art. Druid renderer/media and addon icon are unchanged. See `docs/mage-reboot-integration.md`.

Full tests/audit pass, including live-handler mock Barrage rearming and new artwork/geometry/phase/class-isolation checks. `npm ci` hit isolated DNS failure; five matching locked dependency versions were restored offline and all124 file hashes checked. Runtime texture preview inspected; in-game acceptance remains separate. All31 Druid/icon hashes unchanged. Evidence under `artifacts/mage-reboot-option1`.

Built `dist/Epicast-0.1.0-beta.12.zip`,79 files/25,921,160 bytes/SHA256 `3B4AF3892E50FEE8643394063DFEC108566A446CD5EB0BBF6DB7AA04494208A4`. Installed in `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`:33 new/changed,46 unchanged,57 retired files individually backed up/removed via explicit guarded list. All79 installed payloads and57 removals independently rechecked. Backup/report `artifacts/install-20261116-164602/`. SavedVariables files never accessed. No commit/push/publication. Fully restart WoW for new modules; last public release remains beta.7. See `docs/release-0.1.0-beta.12.md`.

## Previous artwork review: Mage reboot v3 crowns/pendants (2026-11-16)

User approved v2 centers as perfect and requested localized changes: icy sharded Cold Snap crown and low icicle base, molten sharded Combustion crown, knotted-rope Kirin Tor crown with central shard, and crafted matching pendants replacing the lower framed gems. All floating shards and approved centers are preservation requirements.

Built-in imagegen edited v2. First pass obscured Frost upper rays, so a targeted correction restored their crown clearance. A final framing pass fixed 57 intermediate edge pixels at alpha>=128. Selected `concepts/mage-reboot/Mage-reboot-trio-v3-framed.png`, native2172×724RGBA, SHA256 `7DE3FB0505A5B4CAD0108F80A685836E90D8665ECA5482E4CF55DC57487AAA2B`. Final entire edge alpha0; native copy hashes match. Visual center/shard preservation checked without claiming pixel identity. All three native outputs, exact prompts and verification-v3.json retained; no programmatic image edits. V3 additions await review. No runtime/build/install/publication or SavedVariables access.

## Previous artwork review: Mage reboot v2 sculpted centers (2026-11-16)

User accepts the new trio foundations but wants the symbols sculpted/intertwined into the center crest rather than copied onto a panel. Outlines may adapt while staying recognizable; centers should be crystallized and dimensional as in the newly attached Warcraft reference. Built-in imagegen edited v1 with that reference: raised ice ribs/ring, dimensional flame and supported rune rim, faceted Kirin Tor eye/pupil/rays. Surrounding books, crystals, crowns/bases and drapery remain the visual foundations.

Final `concepts/mage-reboot/Mage-reboot-trio-v2.png`, native2172×724RGBA, SHA256 `EC318B8D6C79C6C40FC26FEC2B6F836981F740EFDF8C8847179BCF4D548ACE43`. Copied unchanged from native output; no programmatic image edits. Edge alpha max26, one edge pixel at alpha>=8 and none at>=128. Exact prompt, copied user reference and verification-v2.json retained alongside v1. User subsequently approved the center designs and requested their preservation during crown/pendant edits. No runtime/build/install/publication or SavedVariables access. Central-sculpture direction recorded in AGENTS and concept README.

## Previous artwork review: Mage reboot v1 (2026-11-16)

After the reset, the user supplied four new references and requested a new sister trio. Cold Snap, Combustion and Kirin Tor are the central symbol foundations; the fourth reference defines the prominent central crest, book/page wings, crown/base, floating crystals and lower drapery. This new brief supersedes the blank Mage direction below; none of the discarded art or prompts was reused.

Built-in imagegen produced a Frost / Fire / Arcane review sheet. One targeted correction changed Frost's seven upper rays to six paired rays as in the supplied symbol. Final `concepts/mage-reboot/Mage-reboot-trio-v1.png`, native2172×724RGBA, SHA256 `942E4E17AE12B669BAA195B61F1891C3D7AFFA17DB0DB7B5C0849050009183DE`. Final/source copies match; image visually inspected, edge alpha max4 with zero edge pixels at alpha>=8. Exact initial/correction prompts, four references and native provenance are in the new concept directory. No programmatic image edits.

Artwork review only. No runtime/code, package, installation or SavedVariables changes. The source remains the reset beta.11/schema5 described below, awaiting artwork approval and an integration request.

## Previous source: Mage artwork reset (2026-11-16)

The user explicitly discarded all prior Mage artwork and art direction to start over. Do not revive requirements from that discarded work in chat history, backups or test fixtures. The subsequent fresh brief and review are recorded above. The general painting guide remains scoped to Druid; the new Mage references supply its current direction. See `docs/mage-artwork-reset.md` for reset scope.

Deleted the Mage concept workstream (89 files including paintings, references, prompts and research), its bake/preview directory, 36 Mage trio textures and 17 legacy Arcane textures. Removed the active custom Mage renderers, overlay controls, asset tools and media-manifest entries. Resources previously reused Arcane artwork; they now display as Resource 1 / Resource 2 without that art. Druid's 30 textures and the addon icon remain unchanged.

Mage's Fire/Frost/Arcane slots remain independently editable, labeled artwork pending, with native effects and bindings intact. No retired Mage texture paths are requested. Stable slot/art IDs and numeric legacy geometry survive only for compatibility. In-memory normalization drops retired custom-overlay settings; no SavedVariables files were accessed. No replacement artwork was generated.

`npm test` and `npm run audit` passed after the reset. Current-runtime tests cover pending art, preserved placement/selection/native tuning, Druid rendering, every class preview, and repeated Missile Barrage gain/clear alongside cast/channel/pulse triggers. Historical software fixtures preserve earlier trigger regressions but do not ship and are not art references. The manifest now contains 31 textures; TOC has 21 Lua modules plus two XML templates.

## Historical build and installation status before beta.12

Current working code remains beta.11 / schema 5 with this unbuilt reset. No rebuild, installation, commit, push or publication was requested or performed for the reset.

- Last local ZIP: `dist/Epicast-0.1.0-beta.11.zip`, 116 files, SHA256 `3C6308466FAABBBEE6CF4D5098D06DCCD04E55996B4A73B178F5D8CF7F14C302`. It predates the reset and still includes old Mage art.
- Last installed: beta.10 / schema 4 at `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`. ZIP SHA256 `6963C452E40E253F8A2E1C16FCCF3CCC68E3892F0AD4640951D7BA2BFCFED1A7`. Installation backup/report: `artifacts/install-20261116-133621/`.
- Last public release: beta.7. Existing release records, ZIPs and install backups are historical; none are a current Mage art brief. Never reinstall them expecting this reset.

## Current product and layout

Epicast is standalone and uses only Epicast namespaces and its own settings. `/epicast` or `/epic` opens options; `/epicast dev` enables the developer studio. Never access SavedVariables files, including for migration, backups, hashing or installation. No game UI/screen automation.

Schema 5 has independent size/X/Y/visibility for every class/spec and resource slot. Spellcasting and Resources are editor categories, not linked layout groups. No automatic rearrangement, paired sizes, shared gaps or Central/Edge placement. Selecting, showing or editing one crest does not move another. Stable class/spec frame pools prevent cross-class reuse. See `docs/independent-crests.md`.

All nine Forever classes have three slots. Players select any combination for their class on first use and later; talent spec changes do not alter selection. Dev Build class menus in both editors preview any class temporarily. Preview ends when options close or dev mode ends. Combat guards defer reconciliation. Save/Cancel covers the complete draft; no settings files are read by tools.

`IndependentLayout.lua` imports schema-1–4 effective layout once, retaining old scale, gaps/order, facing, offsets and disabled flags as independent coordinates. Bounds for removed art are migration data only. Existing schema-5 placement is not re-migrated. Druid Moonwarden maps to Balance and Groveheart to Restoration; effect/tuning arrays remain intact. Missing Mage Arcane slots merge both legacy native lists once, including duplicates and explicit empties, retaining intrinsic model fitting and bindings while centering the five placement fields. Limit: 32 native layers.

## Druid artwork

The approved trio is v8, integrated in beta.9. Exact source: `concepts/druid-specialization-trio/Druid-specializations-review-v8.png`, SHA256 `4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8`. Eighteen size-specific textures plus the original Moonwarden/Groveheart twelve remain. `DruidSisters.lua` retains native six-second hover and phase, transparent padding, disabled pixel/texel snapping and the approved CAS bake. `docs/image-generation-style.md` governs Druid painting. No Druid repaint or animation change was requested in the Mage reset.

## Effects, bindings and known limitations

The library lists 8,723 locally inspected Forever 1.60.1.70938 effects. Missing/error/empty models and the placeholder cube are excluded; Add requires a successful preview. `tools/forever-effects.json` and `docs/forever-effects.md` record evidence. Do not ship native game binaries or substitute arbitrary IDs. Existing saved native effects remain normalized losslessly except documented fixes.

`BoundEffects.lua` uses public spell/aura/overlay events; `CooldownBuffs.lua` additionally polls readable public Cooldown Manager state for supported Buff bindings. Models remain pooled/preloaded with generation and timer-token guards. No cast-time reloads, guessed missile ticks or fabricated resources. Resources support native intensity and optional meters; bound layers are excluded.

Missile Barrage uses Buff, not Proc overlay: aura 400589, talent/tracker 400588. Druid Clearcasting uses Buff 16870 and Omen of Clarity tracker 16864. Both share the safe reader. Public `IsActive()` / `isActive` is preferred; unreadable identity/aura data cannot establish a match. Missing readers/errors must not disable other triggers. Hidden native rows are diagnostic only; a hidden unmatched row must not mask an active visible one. Blizzard's relevant Tracked Buffs/Bars viewer must remain enabled/visible during restricted combat reads.

The user confirmed Clearcasting worked after switching to Buff/native tracking, then requested the same path for Missile Barrage. Existing Arcane bindings saved as Proc/name/talent ID normalize to Buff; numeric IDs become 400589. Repeated gain, Arcane Blast clear, and subsequent gain tests pass locally. This does not establish live client acceptance for every case or explain the game's buff-clear mechanic. `/epicast triggers` includes native viewer matches/metadata/read state and each layer's starts/stops/playback; request the full report while a missed proc is active if the issue returns.

Effect 166602 has only Stand (0), no independent Intro/Hold/End; normalization disables unsupported segment choices. Global particle timelines can still differ after first playback. `docs/effect-playback.md` and `docs/166602-playback.json` contain binary evidence. Never claim mock timing tests establish GPU particle restart behavior.

## Verification and delivery

Run `npm test` and `npm run audit`; package only when requested using `tools/Package.ps1`. The allowlist derives from TOC and `tools/media-manifest.json`; test fixtures, concepts and source tools do not ship. Install only on user request using the guarded addon-only installer, leaving SavedVariables completely alone. Prior ZIPs are not rebuilt automatically. No automatic commit/push/publishing.

The latest full tests include real current UI and runtime handlers, schema migration/idempotence, class isolation, independent placement, Save/Cancel, native trigger rearming, reader fault isolation, model segment guards, Druid source/texture checks and absence of retired Mage payloads. In-game visual acceptance is always separate.

Beta.16 build/install verified:83 files,25,932,556 bytes,SHA256 `A409919DDC6889FFBB28C9713A1CBE834FDD94C61B200F52FF656EDE9162D26C`. Installed10 changed/new,73 identical,0 removed; all83 hashes and8 backups independently verified. Backup/rollback preflight: `artifacts/install-20261116-194722/`. No SavedVariables access. Full tests/audit and exact Arcane bake checks pass; all49 textures unchanged. Publication receipt: `docs/release-0.1.0-beta.16.md`.
