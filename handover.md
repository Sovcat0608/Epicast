# Epicast handover

## Current public release: beta.13 Arcane bake (2026-11-16)

User explicitly requested publishing a beta and clarified: bake the in-game effects and spell binding configuration. This authorizes a one-time read of Epicast's Arcane save, overriding the earlier no-read rule for this task only. Read literal data from the 17:16:05.228 UTC save; source SHA256 `9B061597DACEF50CBA6ED14545D0CD400C09E7F158D68C33A154AD112009F892`. No save writes/full snapshots. Only the twelve Arcane effect rows are retained in `tests/fixtures/arcane-beta13.json`; no personal placement or other classes are baked. See `docs/arcane-preset.md`.

`ArcanePreset.lua` supplies six static/six bound layers for fresh Arcane slots. Existing saved arrays, explicit empties and legacy two-list merge survive; fresh slots no longer incorrectly take the legacy pair defaults. Artwork, schema5, all other defaults and native renderer/reader logic remain unchanged. Full tests including exact export, live preset spell routes, repeated Barrage clears and rapid re-proc during outro pass. `npm ci` and audit passed. All49 media assets are unchanged from beta.12.

Published `dist/Epicast-0.1.0-beta.13.zip`,80 files/25,922,957 bytes/SHA256 `BC55855E02CAD469CEC050B52B3B8F4896C1B32EABE104CA825F19AC35FD0DEF`, with checksum companion at https://github.com/Sovcat0608/Epicast/releases/tag/v0.1.0-beta.13 . Published17:24:33UTC, prerelease=true/draft=false; tag resolves to `36539589b2f9996810342bad4a8f6c652a859cf9`. All80 packaged sources match the release commit; both uploaded sizes/digests verified. Source pushed to main. No reinstall requested; beta.12 remains installed. Source save hash rechecked unchanged. Receipts under `artifacts/arcane-bake-beta13/`; see `docs/release-0.1.0-beta.13.md`. Abandoned `animation-rnd/` and earlier Groveheart experiments remain local and are excluded from publication.

## Latest local installation: beta.12, uncorrected Mage option 1 (2026-11-16)

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
