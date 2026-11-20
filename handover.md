# Epicast handover

## Rejuvenation Channel opening

The preview and addon source use 12 moving Start poses over 500 ms. The registered fan starts at the exact Idle paint and shadow, picks up the approved Channel sway on the second cel and builds its emission on that moving silhouette. Hold continues at the 13th pose of the 32-frame loop. An interruption during Start retraces the displayed entry poses to rest. The source tip travels about 23 px during entry, compared with 3 px in segments.7. Installed segments.8 in WoW Forever. All 352 files matched the package. The verified rollback covers 55 replacements and one addition in artifacts/install-20261120-094337/. SavedVariables were untouched. Use /reload for the initial test, with a full restart if old textures persist.

## Restoration fabric and Rejuvenation return to Idle

The addon source and desktop preview now draw a single fabric pose through Impact. The final left and right poses match Idle frames 22 and 26 respectively (one-based), and each banner resumes from that frame. Shard contact textures use the same silhouette through the return. All 32 combinations of side, shard material and slide position matched across the handoff.

Rejuvenation retains its approved Wan animation and separate hover. The 32-frame Channel loop has two short release strips at its upright crossings. A stop during entry reverses the entry, and a stop during Hold settles from the displayed frame. Both strips and the final Impact frame match the first Idle painting and contact shadow byte for byte. The native state tests exercise release from every Hold frame, early cancellation and the Impact handoff. Full tests, media audit, desktop preview checks and 3,054 atlas comparisons across six sizes passed. Installed local test build 0.1.0-beta.18.segments.7 in WoW Forever. All 351 installed files matched the verified package. Rollback verification covered 123 replaced files and three additions. The receipt is in artifacts/install-20261120-090805/. SavedVariables were untouched.

## Restoration floating symbol and leaf test build

Version `0.1.0-beta.18.segments.6` adds both preview animations to the native segmented renderer. The crown uses the preview's sampled rock, separation, blue light and collision poses. Its impact starts from the separated Channel pose. Rejuvenation uses the original registered preview cels. Both use independent hover phases and ship Regrowth cast or channel → Channel and Rejuvenation success → Impact artwork mappings. The installed bake comparison found only those two new artwork mappings.

Full tests, media audit and 2,442 atlas cel comparisons passed across all six sizes. The verified 348-file package is under `dist/restoration-floating-test/`. Installation completed after WoW closed and carried forward the newest crest bake. The install receipt and 52 verified rollback copies are under `artifacts/install-20261119-232448/`.

## Restoration solid-jaw test build

Installed `0.1.0-beta.18.segments.5` in WoW Forever. The game bake uses the approved rigid-jaw motion and stronger left green shoulder. The Treant keeps its native rest paint at the edges, plays authored Channel entry and release around the Hold loop, and restarts Idle from the exact rest cel after Channel and Impact. The chin casts onto the stationary centre of the roots, with softened contact edges and separate moving shard and vine regions.

The full suite, media audit and 1,092 atlas cel comparisons across six Lanczos2 and CAS banks passed. The 331-file install changed 51 files, including nine additions, and preserved the installed effect and spell bake. The package is under `dist/restoration-treant-test/`. The installer and rollback files are under `artifacts/install-20261119-231041/`. SavedVariables were outside the install. Live client visual acceptance is pending. The floating crown and Rejuvenation motion continue in the desktop preview.

## Restoration Treant shared rest cycle

The latest desktop pass moves the carved chin as one rigid piece through Idle, Channel and Impact. Its bevels, grain and tip travel together. Fresh Wan runs refine the jaw transitions, and registration preserves the approved upper face and the exact chin pixels after translation. The chin rises 26 px at exhale, drops up to 35 px during Channel, and drops 46 px at the peak roar. Channel and Impact retain their approved mouth dimensions. The contact fields follow the new silhouette, including the moving-shard overlap. The current atlases are in `treant-study/rigid-jaw/`, with the previous `rest-cycle/` preserved. Evidence is in `artifacts/restoration-motion-refinement/treant-rigid-jaw/`.

The desktop preview uses three new local Wan renders conditioned on the stored registered Treant face. Each uses the identical static pose for its first and last key. Registered cels lock the horizontal mouth corners and exposed pupil positions. Wan contributes local painted detail around the moving jaw and brows. The cast field around the jaw is rebuilt for both cheek layouts.

Idle is a four-second breath. Channel runs a 500 ms authored start and release, shortened when the cast is brief, with a 667 ms breathing Hold loop. Ending from either Start or Hold carries the current pose into the release. The one-second Impact keeps the mouth's 108 px measured width and increases its height from 53 to 104 px. Both full brows lower over roughly half of the visible eye area. The face returns to the exact stored rest frame before the Idle clock restarts at zero after Channel or Impact. The crest's other animation clocks carry on independently.

The moving-shard compositor uses compact foreground paint and contact crops from the same selected Treant cel as the rest of the crest. This repairs the two dark rectangles caused by clearing the old face rectangles while trying to draw from an obsolete numeric cel index. Start, Hold and End passed in both cheek layouts, including both sides of the ramp blend. All six primary face atlases remain byte-identical. Before and after captures are under `artifacts/restoration-motion-refinement/treant-rest-cycle/wood-overlap/`.

The Wan guides, receipts, contact sheets and browser checks are under `artifacts/restoration-motion-refinement/treant-rest-cycle/`. Preview assets use the separate `treant-study/rest-cycle/` atlas. The earlier roar is preserved as a review asset.

## Restoration Treant roar and floating crown symbol

The desktop preview replaces the Treant's previous nod with a planted twelve-cel roar over one second. The brow pinches inward and the jaw opens to about 2.8 times the resting visible aperture at peak. The forehead, eye line and nose stay registered. The bake recomputes the contact field around the moving jaw for both cheek layouts.

The crown ball and crescent use their original registered paint as two independent elements. The collected glyph has a separate 6.92-second hover and a 3-second Idle rock and gap cycle. Channel keeps the moon steady at wider separation with a shaking ball and blue emission. Impact immediately scales to 120%, brings the ball into contact with the crescent at 150 ms, then rebounds into the live Idle pose within one second. Channel ramps interpolate a single pair of pieces. The old fixed paint and contact are replaced in the preview, and the moving cast clips to the existing receivers.

Browser evidence and timing captures are in `artifacts/restoration-motion-refinement/roar-crown/`. The crown uses a full-resolution local patch, with matching pixels for incremental and fresh draws. In headless runs the Channel median was 6 ms in both configurations, with isolated 52–57 ms frames with the crown active. The prototype keeps the historical animation in the base preview path. The game build and saved settings were outside this preview pass.

## Restoration left green shoulder refinement

The stronger-bend pass uses the same approved live Idle attachment and keeps the horizontal pose guide unchanged. Fresh local Wan renders increased measured blade excursion from 2.71 to 4.61 px in Channel and from 5.14 to 9.36 px in Impact. The branch contact remains pixel-locked, and the visible shoulder centre stays within 0.57 px of any Idle pose. The desktop preview now selects `artifacts/restoration-leaf-wan-refinement/left-shoulder-strong-bend/`, with the prior contact-approved pass preserved for comparison.

The previous active clips used the original static shoulder, whose exposed shape sat about five pixels outward from the approved live Idle. Both active clips were rerendered in local Wan from live Idle cel 11, selected as the closest pose to the median Idle silhouette. The 88 px stem guard and a 6 px zone around the registered bough hold the attachment alpha fixed. Bending is concentrated farther out on the blades. Existing Channel and Impact timing carries through.

The contact-approved baseline is `artifacts/restoration-leaf-wan-refinement/left-shoulder-live-anchor/`. Its earlier study and prior preview atlases are preserved. The main preview rebuilds receiver-masked contact shadows for the selected cels. The runtime source baker reads the selection for a later build.

The exposed shoulder centre moved at most 0.565 px between any Idle cel and any active cel. Chromium checked all 16 Idle phases against both active states, exact restoration at Impact completion, and unchanged preload compositing. The contact comparison and verification are in the active review directory. This is a desktop preview update.

## Restoration Channel texture preload

The desktop preview decodes and retains the large source atlases used by Channel and its Idle blend before enabling the Channel button. Canvas geometry, blend order, animation clocks and the 1445 × 1400 backing surface retain the full-resolution settings. The UI shows Preparing Channel while the atlases load.

Three cold Chromium runs cut the longest first-second Channel frame from 377–395 ms to 29–46 ms. Channel became ready about 0.6 seconds after Idle. The retained atlas pixels amount to about 349 MiB as RGBA. Exact comparisons of Idle, the Channel ramp, Channel Hold and Impact matched the previous renderer pixel for pixel in separate browser sessions. All 32 base Idle poses matched. Evidence is under `artifacts/restoration-motion-refinement/`.

## Restoration desktop preview performance rollback

Restored the full-resolution canvas and compositing from before the performance pass after the user reported artifacts. The preview retains the Treant and Rejuvenation motion and contact-shadow updates below. The profiling captures remain under `artifacts/restoration-motion-refinement/`.

## Restoration Treant and Rejuvenation preview

The main desktop preview now uses the reviewed four-second Treant breath and the independent Rejuvenation leaf. The selected Treant pass retains the previous upward inhale and reduces the visible mouth opening by about 72% at exhale. The leaf has a 6.83-second hover against the six-second crest, a four-second Idle wave, a 1⅓-second Channel loop and a one-second Impact. Impact reaches 1.306× the resting fan width on its second frame. The new Channel and Impact guides use the painted green and purple glow references registered to the original leaf.

The contact review found fixed crown shadows on the installed backboard. The desktop preview now removes Rejuvenation's fixed shadow before the moving crown is drawn, then draws the moving leaf contact and reflected light together under the foreground. The chin contact follows the jaw silhouette. Both cheek views, cast interruption and the original 32-frame Idle capture passed browser checks. The installed `segments.4` build and `resto-crest-v1` backup are unchanged. Raw passes, review sheets and validation are under `artifacts/restoration-motion-refinement/`.

## Restoration Wan leaf test build

Installed `0.1.0-beta.18.segments.4` in WoW Forever on 2026-11-19. The six crown and shoulder segments use the reviewed Wan Channel and Impact cels. Channel has 16 cels per third of a second. Impact has 12 cels over one second and peaks on the second cel. The current bake maps Regrowth cast to Channel and Rejuvenation cast success to Impact for all six layers. The build uses the existing in-game contact shading.

The full suite, media audit and all 1,008 cel placements across six size-specific Lanczos2 and CAS banks passed verification. All 322 installed files and 32 rollback copies matched their archives. The package is under `dist/restoration-leaf-wan-test/` and the receipt is under `artifacts/install-20261119-190149/`. The `resto-crest-v1` checksums still match. SavedVariables were left untouched.

## Restoration crest v1 checkpoint

Installed Epicast `0.1.0-beta.18.segments.3` in WoW Forever on 2026-11-19 with the all-state fabric and shard contact shading and the current project bake. The full suite and media audit passed. All 321 installed files matched the package and staged source by SHA-256. The installer replaced three files, added 59 contact atlas pages and verified all three rollback copies. SavedVariables were left untouched.

`artifacts/resto-crest-v1/` contains the exact install ZIP, the 2,491-file artwork and cel backup, the size-specific atlas packer, checksums and the install receipt. The artwork archive includes the registered editable layer paintings, contact fields, raw cels and verification samples. Live visual acceptance is pending.

## Spell Mappings test build

Installed `0.1.0-beta.18.segments.2` in WoW Forever on 2026-11-19. The local test bake maps **Clearcasting (16870) → While buff active → Channel** on both feathers and **Regrowth → While casting → Channel / Cast succeeds → Impact** on Treant Face. The version and test mappings were applied in the staged package. The project bake remains the source for future builds.

The full test suite and media audit passed. A separate run loaded the staged addon and verified both requested mappings with mock game events. All 262 installed files matched the ZIP, with 12 verified rollback copies and six new shard-contact atlases. In-game review is pending. The package is under `dist/restoration-spell-mappings/` and the receipt is under `artifacts/spell-mappings-test-20261119-164246/artifacts/install-20261119-164621/`. SavedVariables were left untouched.

Developer mode starts enabled on the test branch via `defaultDeveloperMode` in `Core.lua`. The toggle still applies to the current session. The Epicast minimap button opens options and is discoverable by OneForAll's **Collect minimap buttons** feature.

## Restoration shard contact shading

Fabric-to-shard contact now follows each banner's Idle, Channel and Impact cels against both resting and extended wood. Channel uses sampled blend levels on its ramps. Hiding a banner removes its contribution from the shard's contact field. The bake derives that field from the registered banner silhouette and uses the existing size-specific Lanczos2 and CAS recipe. All 220 earlier textures retain their hashes.

The renderer tests cover staggered triggers, interruption and retraction, separate left and right states, mirroring and hidden cloth. Decoded verification covers 10,944 cel references across six sizes with identical receiver alpha and no RGB discontinuity at the internal texture cuts or their gutters. See `artifacts/restoration-segments/fabric-contact-state-matrix.png` and `fabric-contact-verification.json` in the same folder. The change awaits an in-game test.

The shard renderer samples seven positions along the approved 28-pixel Channel travel in the registered master. The wood's own contact shade samples the fixed casters in crest coordinates. Each shard independently casts onto the backboard and upper roots. At rest, both receivers use their original atlas frames. During motion, a contact band replaces only the affected area, and the lower vines continue on their own clock. These are baked pixels on the existing Studio layers.

`tools/Build-RestorationSegments.py` now builds the six contact pages with the existing Lanczos2 and CAS recipe. All 214 pre-existing media hashes match. The 360 new cels preserve alpha and match the original RGB along internal tile cuts. The decoded Hold comparison is in `artifacts/restoration-segments/shard-contact-hold-comparison.png`.

## Segmented Restoration studio

**Artwork Config → All** lists the front-to-back stack. Forward and Backward move native effects across locked artwork positions. Restoration has 22 artwork entries, including the two cheek layers in their hidden starting state. The registered contact shading is baked into the artwork frames. The other crests use their existing artwork entries.

Bind mode accepts animated artwork, native effects or both. The gear beside a spell opens the Spell Mappings sidebar. Choose a native game trigger and check the artwork states it should drive. The same panel sets a native effect's trigger. New artwork links wait for mappings. The carved shards support Channel. The feathers, six fans, cloth and treant support Channel and Impact. Test response previews either supported state. The shared spell-event reader supplies aura, proc glow and Cooldown Manager state for both artwork and native effects. Copy crest bake v5 stores explicit artwork mappings and upgrades v4 bindings in memory on load.

`tools/Build-RestorationSegments.py` uses the registered Restoration layers and authored animation sources. Run the desktop idle capture and the size-specific idle bake before it to prepare the crest registration in `artifacts/restoration-idle-cas-build/bake.json`. The segment baker packs 532 cels at each of the six Lanczos2 + CAS sizes. Studio uses the layer renderer for Restoration. In normal play, Restoration selects it when the active bake carries segment settings and otherwise uses the idle atlas.

Source tests cover actual scene frame levels, locked order, mixed spell assignment, Channel interruption, Impact playback and compiler validation. The offline resting comparison is in `artifacts/restoration-segments/resting-comparison.png`. In-game acceptance is pending.

Installed local test build `0.1.0-beta.18.segments.1` in WoW Forever on 2026-11-19. All 256 archive and installed payloads matched by SHA-256, including 59 segment atlases with 3,192 verified cel references. The full test suite and media audit passed. The install updated 75 files and verified 14 rollback copies in `artifacts/install-20261119-145848/`. The ZIP is in `dist/restoration-segments-test/`. Installation stayed inside the Epicast AddOns folder.

## Size-specific Restoration idle test (2026-11-19)

Local build `0.1.0-beta.18.idle.2` uses the same 32 captured idle poses as idle.1. The registered unsharpened cels feed the shared premultiplied Lanczos2 sampler and CAS 1.0 / 0.65 bake at widths 192, 288, 384, 480, 576 and 660. The same physical-pixel size selector chooses the static or animated variant. The animated renderer loads the selected atlas bank, preserves phase when the size changes, and uses 660 when screen metrics are unavailable. The four-second loop at 8 FPS and native six-second hover retain their timing.

The full addon tests and media audit passed. The 195-file ZIP was installed in WoW Forever and independently hash-verified, with 112 changed files and 13 verified rollback copies. Installation stayed inside the Epicast AddOns directory. Build evidence is in `artifacts/restoration-idle-cas-build/bake.json` and the receipt is in `artifacts/install-20261119-143104/independent-verification.json`. In-game visual review is pending.

## Restoration idle test build (2026-11-19)

The approved full-etch shard Channel is archived in `artifacts/restoration-shard-channel-approved/` with 53 verified source, preview and render files. The desktop reference retains 28 px slide travel, the full-etch peak sprites and the shared Channel phase clock.

Local build `0.1.0-beta.18.idle.1` uses the approved desktop idle composition with hidden cheek leaves. `tools/Capture-RestorationIdle.cjs` samples the live compositor at 125 ms. `tools/Build-RestorationIdle.py` verifies the 4-second loop and packs 32 registered poses into eight native TGA pages. The atlas preserves the previous crest’s visible height and centre with uniform scaling. `RestorationIdle.lua` plays the cels within the existing Druid host, alongside native hover and the player’s animation toggle. This build's artwork animation covers Idle only.

Full tests and media audit passed. Installed in WoW Forever with 96 payload hashes verified, 13 changed files and four verified rollback copies. Installation stayed inside the Epicast AddOns directory. The ZIP is in `dist/restoration-idle-test/`. See `artifacts/install-20261119-141250/independent-verification.json` for the receipt and `artifacts/restoration-idle-build/bake.json` for the frame registration. In-game review is pending.

## Restoration inner etch ImageGen comparison (2026-11-19)

The third trial uses two native ImageGen stills edited from the same shared input, registered to the original wood. Masked linear-light interpolation produces a five-second clip with a single pulse, a dark endpoint in all four carvings and stationary silhouettes. The comparison retains Griffin and Wan as raw outputs. The three-way playback, start/pulse/end overview, saved prompts, native keyframes and timing notes are in `prototypes/feather-cels/wood-channel-study/painted-reference/inner-etch-review/model-comparison/`.

## Restoration inner etch Griffin and Wan comparison (2026-11-19)

The approved inner-etch paintings were rendered together on one shared input with the same motion brief. One Griffin HD render charged 10 credits, and one native Wan 2.2 5B render ran locally. Griffin pulsed the existing cuts and finished dark, with a short green bloom around its peak. Wan increased the green toward the end and introduced bright shapes on neighbouring wood. The shared input, receipts, raw clips, Griffin RGBA sprite sheet and paired playback are in `prototypes/feather-cels/wood-channel-study/painted-reference/inner-etch-review/model-comparison/`. The crest preview still uses the approved frame-controlled lighting.

## Fabric contact shadows during Channel (2026-11-19)

The moving-wood preview uses the same fabric cel for the painted banner and its contact field. The flag field stays in crest coordinates and is clipped to the sliding wood, alongside the remaining fixed casters. The earlier wood overlay used a static field for the entire foreground. Verified all six Hold cels and their visible shadow changes in both cheek layouts.

## Restoration paired lighting on both shards (2026-11-19)

Both wood shards now use registered painted light in the desktop preview. The right shard's ImageGen plates preserve its own rising upper cut and forked lower notch. The transparent paintings, prompts and registered mask are in `prototypes/feather-cels/wood-channel-study/painted-reference/right-glow/`. Both sides share the same Wan-derived Hold curve and Channel Start and End fades. The original shard alpha is preserved, and no colour changes outside each registered lighting mask. Both cheek layouts were checked through Hold, a manual End and interruption by Impact.

## Restoration paired wood lighting test (2026-11-19)

The left shard in the desktop preview fades a registered light pass from the matched ImageGen lit and unlit paintings. Green reflection is transferred onto the original shard pixels inside a fixed mask, with identical alpha at both endpoints. The stronger lit PNG, the unlit edit, both prompts and the registered mask are in `prototypes/feather-cels/wood-channel-study/painted-reference/strong-glow/`. The first 22 frames of the stored Wan trial contribute only a measured Hold brightness curve sampled inside that mask. The preview controls Start, Hold and End, holds the current pulse level at the start of a manual End and extinguishes the light on Impact. These boundaries were verified with both cheek layouts. The existing right-side light treatment is retained for comparison.

## Restoration painted wood glow reference (2026-11-19)

The stronger ImageGen variant in `prototypes/feather-cels/wood-channel-study/painted-reference/strong-glow/` has near-white green cores and broader reflected light on the wood, with 99% silhouette overlap at half alpha. The repeat Wan run used the initial settings and seed for comparison. It dimmed the brighter glow modestly and added stray green trails late in the clip. The transparent still, prompt, input and verified Wan result are retained.

The left shard has a new transparent ImageGen lighting study with green cores in the carved recesses and reflected light painted onto the adjacent bevels. The 1884 × 835 master, exact prompt, matte-backed Wan input, verified local output and job records are in `prototypes/feather-cels/wood-channel-study/painted-reference/`. Wan preserved the stationary composition and dimmed the light slightly. The final frame still glows. The reference remains separate from the crest preview.

## Restoration carved wood Channel (2026-11-19)

The wood shards have one static pose for Idle and Impact. In the desktop preview, Channel Start moves each shard and its contact field 28 pixels outward across the authored 0.5-second ramp. Hold keeps the translation fixed, and End reverses it. A brighter local Wan pose-guided trial supplied the registered green glow profile, palette and slight Hold variation. The preview gates that independent light layer with the same Channel phases. `prototypes/feather-cels/wood-channel-study/` contains the layered assets, bake recipe, raw Wan trials and playback capture. Verified automatic and manual endings, immediate interruption into Impact, and both cheek layouts. The installed game addon has no changes from this study.

## Restoration sprout fork placement (2026-11-19)

The desktop preview places the carved sprout fork and its registered contact field 30 pixels below the original registration on the 1125 × 1400 crest canvas. This is 25 pixels below the first placement pass. The vertical gap from the fork tips to the small leaf cluster now measures 120 pixels against 121 in the supplied reference. The base composites and treant Idle, Channel and Impact overlays use the new position with cheek leaves shown or hidden. The Figma source and isolated animation cels retain their original registration.

## Restoration treant Impact (2026-11-19)

The treant nods once, lowers its inner brows, and shuts its jaw into a downturned seam before easing back to Idle. The 12 cels use the one-second feather Impact schedule. The native Wan trial retained an open jaw, so the preview articulates the original painted face and recomputes its contact shading. `prototypes/feather-cels/treant-study/bake_impact.py` writes independent face cels and registered overlays for both cheek visibility variants. The desktop preview was checked for immediate Channel interruption, repeat playback, and the final Idle handoff.

The 12 approved reverse-curl banner files and recipes are preserved in `artifacts/restoration-banner-impact-approved/`.

## Restoration cloth banner Impact (2026-11-19)

The reverse-tip study ran through the local Wan 2.2 5B Native queue. The plain-image trials introduced objects. The pose-guided left clip produced a strong upturned tip, while the direct and mirrored right trials produced shallower motion. The live crest uses the left curl as a motion reference and bends only the original painted tails, with the underside shaded during the turn. The moon and tree each peak once on frame two at 83 ms and return to their Idle brightness. The raw trials are under `prototypes/feather-cels/fabric-flag-study/wan-impact/`. The previous banner bake is preserved in `artifacts/restoration-banner-impact-v1/`.

The two worn banner ends snap outward once, peak on frame two at 83 ms, and ease back to their live Idle pose. They use the feather Impact schedule of 12 cels in one second. The wraps and their glyphs stay fixed. `prototypes/feather-cels/fabric-flag-study/bake_impact.py` writes a separate atlas and contact-aware overlay for each banner. Headless preview verification covered immediate interruption from Channel, final Idle handoff and unclipped atlas coverage. The 11 approved leaf Impact files are preserved in `artifacts/restoration-leaf-impact-approved/`.

## Restoration leaf Impact preview (2026-11-19)

The upper-left autumn fan and left green shoulder use their registered Idle paintings as Impact sources. Their fixed zones extend into the blade bases, and their contact fields follow the revised curl. The other four atlases are byte-identical to the previous pass.

The desktop preview at `prototypes/feather-cels/index.html` plays Impact for all six crown and shoulder leaf fans. Impact immediately interrupts Channel Start, Hold or End. The 12 cels use the feather Impact schedule for one second of playback. Each fan opens its C-shaped curve backward from a fixed stem. The bend and vein flash peak on cel 2 at 83 ms, then ease into the ongoing Idle phase. `leaf-impact-study/bake_impact.py` writes six independent transparent WebP atlases plus the registered composite with receiver-clipped contact shadows. The preview retains the moving feathers behind the leaf region, 3× leaf Channel playback, and the hidden cheek leaves. The prototype is separate from addon runtime assets.

## Restoration faded moon and tree test build (2026-11-18)

The latest assembled Frame 145 export includes the treant face, autumn rosette, both purple side maples and mauve cloth glyphs. The original paint alpha is preserved on both wraps. The exact transparent stage export is `concepts/restoration-autumn-treant/Frame 145 worn wraps.png`. To reproduce `Restoration registered.png`, crop to its alpha bounds, thumbnail to fit 628 × 805 with Pillow Lanczos and alpha-composite centered horizontally at optical Y 444.5 on a transparent 660 × 880 canvas. Then run `tools/Prepare-DruidTrio.ps1` and `node tools/Build-DruidTrio.cjs`. Full tests and media audit passed. All 87 installed files matched the ZIP in `dist/restoration-worn-wraps/`. Seven-file rollback receipt in `artifacts/install-20261118-210348/`.

## Restoration white-veined maple test build (2026-11-18)

Frame 145 and the local beta.18 install now use the first orchid repaint with pale veins on both side maples. The paint and linked contact fields share the same registered sources as the game bake. The existing 19 poses and native bounds are preserved. Both source PNGs are in `concepts/restoration-maple-refinement/` with the suffix `-white-veins.png`. The preparation steps below still apply. The ZIP is in `dist/restoration-white-veins/`, with the six-texture install backup in `artifacts/install-20261118-204403/`.

## Restoration Rejuvenation pose (2026-11-18)

Frame 145 has 19 painted pieces, including the S-stalk leaf and purple backboard. The four rotated pieces retain their angles, and the right maple retains its custom crop. Each source component contains a Pose that controls its paint and linked contact field. The 73 caster instances use 18 receiver masks. The original layout is available as a hidden frame. [Editable crest](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=495-772)

Run `concepts/restoration-rejuvenation/prepare_pose.py`, then `tools/Prepare-DruidTrio.ps1` and `node tools/Build-DruidTrio.cjs`. The pose manifest records the frame dimensions, stack order, transforms and crop. The compositor checks that shadows preserve the complete paint stack’s alpha. The six Restoration textures share the registered 660 × 880 source and the existing whole-crest motion. Native visible bounds are (17, 86) to (642, 803), exclusive.

Local beta.18 test ZIP in `dist/restoration-rejuvenation-pose/`. Full tests and media audit passed. Verified all 87 installed files against the archive and preflighted the seven-file rollback in `artifacts/install-20261118-203243/`. In-game visual acceptance is pending.

## Restoration preferred pose test build (2026-11-18)

The preferred Sovcat frame 481:689 now contains a 20-piece editable master with receiver-masked contact shadows. Edit the Pose inside a source component to move its paint and shadow together. A hidden copy of the previous loose layout is inside the same frame. The new layout uses the author's enlarged side and basal maple leaves. Both cuff-to-maple and maple-to-feather links were moved, verified and restored in Figma. [Preferred layout](https://www.figma.com/design/9GLlCGWEVCrVTLlR644Jt2/Sovcat?node-id=481-689)

Run `concepts/restoration-maple-refinement/prepare_pose.py` to recreate the registered RGBA source from the measured pose, isolated paintings and shadow-ready kit. The Druid trio preparation and bake now read that source for Restoration. Its six runtime textures share the existing whole-crest hover and authored effects. The full suite, media audit and 87-file package verification passed. Installed the beta.18 test ZIP from `dist/restoration-maple-pose/`. The eight-file rollback receipt is in `artifacts/install-20261118-195106/`. This install also includes the existing small-effect clipping change. In-game visual acceptance is pending.

## Segmented crest artwork (2026-11-18)

Restoration is the approved construction reference for future layered crests. The editable study has nine groups assembled from 21 independently painted pieces. Its Figma playground also has 21 loose images with their contact shadows baked in. The project rule and its acceptance checks are in the [segmented crest build guide](docs/segmented-crest-artwork.md).

## Small native effect render surfaces (2026-11-18)

Force of Nature Impact is Forever model 166205. In build 1.60.1.70938 its M2 has two particle emitters, five ribbons and a single 4.034-second Stand sequence. The current Restoration bake requests 158 after the intro. The viewport change preserves animation requests and bake values.

The shared native renderer now gives each effect up to 96 UI units of additional render room per edge, with a 90-degree FOV limit. Screen projection and the authored origin stay registered because viewport width and the tangent of the half FOV increase proportionally. Both the game crest and Artwork Config use this path. The outer Studio preview still bounds its canvas.

The real Studio size controls and current renderer were exercised at 5%, 10%, 27%, 100% and 200% with the Force of Nature Impact fit. The old installed renderer fails the new margin assertion. The new source passes and preserves model instances, animation starts, size and registration. The archive recovery test uses the recorded Restoration fixture so new user bakes can evolve while compiler validation still checks every shipped definition. Full tests and audit passed. The visible result in the WoW client awaits testing.

## Opt-in bind mode and spell assignments (2026-11-18)

Ordinary Effect Studio clicks select one layer or spell and show linked rows in blue or green. **Enter bind mode** enables staged multi-selection. **Save binding** creates the links, and Save or Cancel exits the mode. Expand a spell to see every linked effect, then click a child row to choose that link's trigger. New links default to Cast succeeds and existing links keep their trigger when restaged. Trigger edits reuse the current bake format and change only the selected pairing.

The full suite and audit passed, including mixed channel/success playback for one spell, trigger preservation across rebinding, v3 compilation, and pagination of a 32-effect spell branch. Installed beta.18 from `dist/bind-mode/Epicast-0.1.0-beta.18.zip` with all 87 payloads and four rollback backups independently verified. The rollback dry run passed. The install receipt is under `artifacts/install-20261118-002342/`. The installer did not access SavedVariables. In-game testing is pending.

## In-game Effect Studio quick bind (2026-11-18)

Artwork, Static and Bound now filter distinct layer types. Quick bind starts from an effect or waiting spell and stages multiple targets in the other panel. Existing links are highlighted separately in blue for spells and green for effects. A staged panel displays selection styling. One native scene per effect placement responds to multiple spells and remains active when another sustained trigger still applies. The Playback spell menu edits and tests each response. Multi-trigger bakes use v3. The compiler still supports v1/v2, and player preferences use the existing schema.

Built and installed the Quick Bind beta.18 from `dist/quick-bind/Epicast-0.1.0-beta.18.zip` at the user's request. All 87 installed files match the ZIP, and all 12 replacement backups were verified. The rollback dry run passed. Receipt: `artifacts/install-20261118-000655/install-verification.json`. Full tests and audit passed. The Restoration compiler test now expects the existing two-second Rejuvenation burst. The installer did not access SavedVariables. In-game testing is pending.

## In-game size controls and crest draw order (2026-11-17)

Crest placement and effect-layer size controls now start at 5%, including the bake compiler's effect range. Selecting a static effect clears the waiting-room selection, and selecting a bound effect highlights its assigned spell. Live crest frames use the High draw layer so artwork and effects appear above the action bars and the frames pass mouse input through during play. The addon suite and audit pass. Built and installed beta.18 from `dist/crest-controls/Epicast-0.1.0-beta.18.zip` at the user's request. All 87 installed files and seven replacement backups independently match their hashes. The receipt is in `artifacts/install-20261117-230221/`. In-game visual review is pending.

## Crest Baker installs for reload (2026-11-17)

The desktop tool now compiles the pasted crest into the project and installs its generated `CrestBakes.lua` into the confirmed WoW Forever Epicast folder. It verifies the existing TOC, backs up and hashes the old installed bake, atomically replaces the file and verifies the result. Success instructs `/reload`. The updated executable is `artifacts/crest-baker/Epicast Crest Baker - Bake and Reload.exe`; the original executable was open and preserved. Tests used a temporary installed folder to verify replacement, backup, repeat behavior and incompatible-TOC rejection. No real bake or installed file was changed during these tests. No player profile or SavedVariables access.

## Offline web Effect Studio replica (2026-11-17)

User requested a full replica of the current in-game Effect Library / Artwork Config UI. The isolated prototype now opens that editor at http://127.0.0.1:4318; `/lab.html` retains the earlier renderer laboratory. Start/stop scripts remain under `prototypes/renderer/`.

The web studio reads shipped definitions only: all9 classes,29 crest/resource slots and8723 Forever effects. Both main tabs, paginated selectable layer/artwork stack, depth ordering, full-crest preview, whole-step numeric/sliders/chevrons, drag placement, visibility/opacity, playback timing, per-crest spell waiting room and binding/unbinding, simulated signals, artwork-motion attachment, Save/Discard checkpoints and version-2 Copy/Download exports are implemented. Exports validate with the existing bake compiler and are suitable for the Crest Baker; the web tool does not bake/install/publish automatically. Save session is RAM-only; download/copy is required before browser reload/close. Artwork remains the actual complete Mage/Druid texture layer.

The full renderer uses one WebGL/WASM context for up to32 persistent M2 scenes plus artwork; library preview has one separate context. Full-stage targets and premultiplied GPU composition preserve native additive RGB. Complete12-effect Arcane rendering exposed an upstream uniform-buffer indexing bug across multiple scene arrays; the reproducible patch fixes its range traversal. Targets are privately owned rather than reused through the upstream screenshot pool. The native model/shader/animation data remains unchanged. The newly installed beta.18 FOV differs from the earlier lab calibration; projection was updated to match the current installed Lua, and264 numerical comparisons now pass.

Verification: existing44 renderer regressions passed, including sustained5054328 Hold,166602 replays, clipping/resize/depth/attachment and no asset reloads during ordinary playback. New studio browser tests cover full Arcane/Restoration, real effect pixels independent of artwork, editor workflows, session rollback, binding, all29 compiler-valid exports, resource restrictions and32-layer capacity. Full addon suite and audit also passed. Evidence is under ignored `prototypes/renderer/results/`; details in `prototypes/renderer/studio-notes.md`. Installed payload hashes were checked before/after tests. No SavedVariables, installation, media or shipped bakes were modified by this task; concurrent addon/baker changes were preserved. Browser material/easing parity and every catalogue entry still need user acceptance; no game UI automation was used.

## Windows Crest Baker (2026-11-17)

Open `artifacts/crest-baker/Epicast Crest Baker.exe`, paste the export from the Epicast studio and click Bake. The desktop tool sends the paste to the existing compiler on stdin and updates the selected crest in `tools/crest-bakes.json` and generated `CrestBakes.lua`. The tool can be rebuilt with `tools/Build-CrestBaker.ps1`. Tested with the real WinForms controls and a temporary project copy, including UTF-8 round trip, invalid/private field rejection, preservation of another crest and rollback on a failed Lua replacement. Full tests and audit passed. The real bake files retained their original hashes during verification. No player data access.

## Current installation — beta.18 Size and Angle sliders (2026-11-16)

Placement now has whole-step sliders, chevrons and numeric fields for Size and Angle as well as X, Y and Opacity. The new controls preview changes immediately and Save session applies them to the game crest. Tests cover size and angle changes through Save. The full suite and audit passed. Installed the verified `Epicast-Size-Angle-Sliders` ZIP at the user's request. Independently verified all 87 installed files and the `EffectControls.lua` backup. The receipt and backup are under `artifacts/install-20261116-235248/`. Use `/reload` to test the new controls in WoW.

## Offline renderer camera, Hold and clipping follow-up (2026-11-16)

User authorized fixing prototype5054328 Hold, camera/scale and clipping, explicitly excluding installed addon and SavedVariables changes. Work is isolated to `prototypes/renderer/` plus this handover/AGENTS note. No runtime Lua, bakes or assets edited by this task. Concurrent addon changes in this shared checkout were observed and left alone.

The old camera reproduces blank frames while Hold158, all seven emitters and live particles remain active. Its auto-fit uses tiny Intro sequence bounds and places the camera roughly0.465 model units from their centre, behind a1-unit near plane. The header's sentinel collision bounds were an early hypothesis, ruled out by tracing the actual sequence-bounds path. Explicit Epicast camera calibration resolves the blank samples without sequence/particle changes or timed model reloads. Final sustained comparison: original binary49/75 blank, rebuilt engine/old camera49/75 blank, calibrated0/75 blank over three12.5-second Holds. Actual cameras and sample diagnostics: `prototypes/renderer/results/ab-probe.json`.

Native-equivalent model scale/origin, azimuth/elevation/roll, near/far planes, anchor offsets, art-relative sizing and doubled viewport FOV are implemented in `projection.js` and `native/EpicastCamera.h`. Full-panel framebuffers and off-centre projection replace per-effect384px boxes; only the outer preview panel clips. Zoom supports20–150%; resize/paused edits update the projection without model reloads.264 numerical cases run the installed Lua code read-only, rather than comparing two copies of browser math.44 browser checks cover real pixels, interleaved depth, hover attachment, repeated166602 and5054328, cold reload, extended particles beyond the old square, resize and HTTP/network restrictions. The root test suite/audit passed after concurrent edits settled; one earlier run caught a transient effect-studio assertion during those edits.

Reproducible renderer source is Marlamin/WebWowViewerCpp wtl4017528, built with portable Emscripten6.0.11. Pinned original shaders remain byte-identical; only camera/diagnostic/build adapters are patched. `Setup-Compiler.ps1`, `Build-Renderer.ps1`, and the binary/recipe manifest reproduce/validate the ignored local build. Original binaries remain available solely for negative controls. See prototype README/renderer-notes/THIRD-PARTY for details. Start/stop remain loopback-only on4318. No renderer redistribution, bake exporter, installation or SavedVariables access. Game material/lighting fidelity remains manual; web IN_OUT easing approximation and lack of particle/global-clock rewind claims remain. Broader effects and32-layer performance are not certified.

## Previous installation — beta.18 preview scale and artwork lock (2026-11-16)

The studio uses the same full square model viewport, field of view and actor geometry as the game for every layer, including Dungeon Fog. A scroll viewport bounds the stage separately. Zoom scales the complete crest, and the 1:1 control uses the game crest’s effective UI scale. Follow artwork motion reads the artwork’s native animation phase and eased progress and updates the real ModelScene anchors with one shared update frame for visible attached effects. Whole-number placement controls carry forward. Automated checks cover all twelve Arcane viewports across zoom levels, save parity, artwork lock and unlock, bound playback cleanup and permanent bake motion. Installed the verified `Epicast-Shared-Viewport` ZIP at the user's request. All 87 installed files and six previous-file backups verified independently. Receipt and backups are under `artifacts/install-20261116-234409/`. Use `/reload` to test the 1:1 scale, artwork lock and native particle clipping at the scroll viewport edge.

## Local beta.18 whole steps and Dungeon Fog preview (2026-11-16)

Origin X, Origin Y and Opacity accept whole numbers. Sliders and chevrons step by one. Existing fractional bake values are preserved until edited. Read-only inspection of the local Forever 1.60.1.70938 assets confirmed that all ten catalogued `7fx dungeonfog` variants have meshes and no ribbons or particle emitters. Their studio scenes keep the game camera and square viewport at each zoom level. A separate clip frame limits fog to the preview stage. The regression compares fog camera, viewport and anchor at Fit and higher zoom, and checks that a reused scene returns to the regular particle path. Full tests and audit passed. The verified 87-file ZIP is in `Epicast-Fog-Preview`. Install preflight found five replacements and no removals. This build awaits installation and in-game visual verification.

## Previous installation — beta.18 placement sliders (2026-11-16)

Origin X, Origin Y and Opacity use native sliders with 0.1-step chevrons and exact numeric fields. Dragging and nudging update the studio preview. Save session applies the previewed values to the game crest. Automated checks cover saved X/Y projection and opacity, and saved bound opacity on a spell event. The full suite and audit passed. The verified 87-file build from `Epicast-Placement-Sliders` was installed at the user's request. All 87 files and eight previous file backups were independently verified. The receipt and backups are under `artifacts/install-20261116-231634/`. Use `/reload` to load the update. In-game visual comparison is pending.

## Local beta.18 live placement controls (2026-11-16)

Placement previews valid numeric edits as the user types. Enter or focus loss applies them to the game and the session draft. Escape restores the applied value. Placement shows the selected bound effect in its main animation so it can be adjusted without casting. Playback restores normal spell behavior in the preview and offers the existing response test. Full tests and audit passed. The verified 87-file ZIP in `Epicast-Live-Placement` also includes the preview alignment fix below. Install preflight found eight replacements and no removals. The build awaits installation and in-game verification.

## Local beta.18 preview alignment fix (2026-11-16)

Corrected the studio crop offset to use UI coordinates, preserving the in-game effect origin and projection at Fit and other zoom levels. The studio crest takes its hover phase from the visible in-game crest. Resource opacity updates use the same native alpha calculation and crop checks as the renderer. The studio regression verifies that editing X, Y and opacity through the controls gives both scenes the same placement and opacity values. Full tests and audit passed. The `Epicast-Preview-Parity` artifact contains the verified 87-file ZIP. Install preflight found six replacements and no removals. In-game visual verification is pending.

## Offline renderer prototype, 2026-11-16

User authorized a local browser renderer proof of concept using a full crest, multiple effects, floating movement and repeated playback including166602, with installed addon and SavedVariables explicitly untouched. Implemented only under `prototypes/renderer/`, plus this continuation record/AGENTS. No addon build/install/publication or runtime changes.

`Start-Prototype.ps1` / `Stop-Prototype.ps1` manage a hidden local Node server at127.0.0.1:4318. `Setup.ps1` verifies pinned wow.tools.local revision3b1df6a6908cd06629625cb55a900f3267895920 JS/WASM/shader-data hashes. Actual Forever1.60.1.70938 M2/SKIN/BLP dependencies are verified/read in memory through existing LocalCASC; no native binaries exported or shipped. No account settings access. Browser rendering is offline after initial dependencies. Complete existing CAS textures are decoded directly without changing source art.

Restoration uses166694/166602/1519919; Arcane uses166009/5054328/1699091. Three isolated WASM contexts per scene, front/behind controls, six-second ±1.2% hover and optional attachment, real available sequence IDs plus baked Intro/Main/End durations, five-cycle show/play/release/hide and cold-scene comparison.33 headless WebGL checks include framebuffer/screenshot differences, each layer's visible contribution, depth, registration, repeated166602, no cast-time scene loads or new asset requests, loopback-only network and HTTP read restrictions. Both source and installed87-file payload hashes are unchanged; root npm test/audit passed. Evidence in ignored `prototypes/renderer/results/verification.json`, restoration.png, arcane.png and recorded WebM. Test uses SwiftShader, not a hardware performance benchmark.

Material limitation:5054328 produced visible pixels in the first diagnostic probe but is unreliable/blank across subsequent playback runs, including sustained Hold. It explicitly fails the compatibility assessment, separately from passed prototype checks. UI and report flag this; do not call it fully compatible or infer a native-game bug.166602 remains Stand-only and sequence reselection does not establish emitter/global-clock rewind. Hidden prototype layers continue simulation. Native camera/FOV/origin/roll mapping is not exact; current preview uses upstream auto-fit and rough bake-derived screen placement, so there is deliberately no config export. A production editor still needs shared multi-model rendering, exact camera mapping, broader material/animation coverage, native comparisons and bake round-trip integration. No game UI automation. Installed beta.18/public beta.17 remain as below. Prior uncommitted beta.18 work and abandoned animation directories remain untouched.

## Current installation — beta.18 Layers filters (2026-11-16)

Artwork Config now has All, Static and Bound pills. All shows the complete stack, including crest artwork. Static and Bound show effects of the chosen type. Static rows read “Static · always active”. A new effect added from the library is revealed even if Bound was active. Full tests and audit passed. The 87-file Layers filter ZIP from `Epicast-Layer-Filters` was installed in the WoW Forever Epicast folder at the user's request. All 87 installed payloads and the three backups were independently verified. The receipt and rollback files are under `artifacts/install-20261116-224550/`. Use `/reload` to load the update in the open client. In-game testing is pending.

## Previous installation — beta.18 studio test build (2026-11-16)

User explicitly requested installing beta.18. Installed the unchanged87-file ZIP (SHA25632F24CC60A912DDB35573D408D455B1348CF9CAAAFDD54633A6B4AD5A2AF2704) to D:/World of Warcraft/_forever_/Interface/AddOns/Epicast. Independent verification passed for all87 payloads and15 original addon backups;19 changed (15 replaced +4 new),68 identical,0 removed. Receipt/backups: artifacts/install-20261116-221739/; independent-verification.json records checks. WoW was closed at preflight. SavedVariables never accessed; no runtime source changes, game UI automation, commit, push or publication. Public beta.17 remains. Start/restart the client for new TOC entries; native visual acceptance is still pending. See docs/release-0.1.0-beta.18.md.


## Current local source: beta.18 developer effect studio (2026-11-16)

Implemented the requested UI audit/rework. User confirmed waiting-room spells belong to each crest and its bake. Effect Library now searches/previews/adds one unbound effect layer; Artwork Config has the full selectable artwork/effect stack, interleaved depth, full-crest live native preview, Placement/Playback controls, and spell waiting room with optional binding/unbinding. Motion attachment follows the selected real artwork's native six-second hover with matching phase. Current crests have one complete artwork layer; no art was separated or regenerated.

Player preference schema6 and approved Arcane/Restoration defaults are unchanged. Studio metadata is developer RAM/shipped bake only. V2 export/compiler validates stable IDs/order, artwork properties, waiting spells and motion targets; legacy v1 remains supported. Preview is separately pooled, tests are preview-only, live events work, close/tab cleanup removes preview bindings. Native projection cropping avoids generic child clipping. No cast-time model loads or config writes.

Full tests/audit passed plus focused final UI checks. All49 artwork assets unchanged. The87-file source/archive-verified ZIP is dist/Epicast-0.1.0-beta.18.zip,25,940,501 bytes,SHA25632F24CC60A912DDB35573D408D455B1348CF9CAAAFDD54633A6B4AD5A2AF2704. Offline handler-based layout previews under artifacts/studio-ui are approximate skins without GPU particles. Audit/architecture: docs/effect-studio-audit.md; test-build receipt/manual checks: docs/release-0.1.0-beta.18.md.

No installation, commit, push or publication authorized/requested in this turn. Public and installed beta.17 remain unchanged. No SavedVariables access or game UI automation. New TOC modules require a full restart after a later installation. In-game particle stacking/cropping and hover alignment remain manual acceptance. Abandoned animation-rnd and concepts/groveheart-restoration directories remain untouched and untracked.


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
