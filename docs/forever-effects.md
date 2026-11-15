# Forever effect compatibility — beta.6

The user reported blue-and-white placeholder cubes after beta.5 expanded the cross-build name index. They authorized Forever filtering, preventing placeholder additions, rebuilding and reinstalling, with SavedVariables untouched.

## Actual client evidence

Read-only inspection of `D:/World of Warcraft/.build.info` selected product `wowf`, version **1.60.1.70938**, build key `3627b099867bfde3e37a17cf44f69cdc`. Its build configuration identifies root content MD5 `f5e8b398da97f055c74ee9898857af83`. The reader uses this product's root, never the installed Retail product's root.

Of 9,768 source candidates, **8,723** passed. Rejected: **995 absent root entries**, **one ErrorCube**, **49 empty models** with no vertices, ribbons or particle emitters. All retained models and **22,849 distinct dependency ID/type checks** were readable with valid BLTE/content hashes. Dependencies include skin, texture, animation, bone and skeleton references. Texture-quality variants are considered: a missing high-resolution copy must not exclude a valid resident alternate. All 32 preview presets remain available.

`spells/errorcube.m2`, FileDataID **166046**, has internal name `ErrorCube`, 24 vertices, no ribbons/particles and exact minimum/maximum coordinates **±0.1388888955116272 on each axis**. Its content MD5 is `79101f2c85c9e2908c6478afa8385673`. No other candidate matched that bounds fingerprint during inspection.

The reproducible build inputs are `tools/forever-effects.json` (allowed IDs, rejected groups, build/root provenance and inspection digest), the pinned listfile inputs and preview metadata described in `effect-library.md`. Full per-model findings are in ignored `artifacts/forever-source/inspection.json`; native models are not shipped. The single research ErrorCube copy also stays in ignored artifacts. The scanner reads only `.build.info`, build config, local indexes and data archives. It performs no network access or game writes and never opens WTF/SavedVariables.

Rebuild inventory with `node tools/Scan-ForeverEffects.cjs 'D:/World of Warcraft'`, then `node tools/Build-EffectCatalog.cjs`. This deliberately fails closed on unavailable, unreadable, encrypted or unsupported data. Reinspect when updating the supported build. Format references consulted: [wow.export's local CASC reader](https://github.com/Kruithne/wow.export/blob/main/src/js/casc/casc-source-local.js), its [root/encoding reader](https://github.com/Kruithne/wow.export/blob/main/src/js/casc/casc-source.js), and [CascLib's WoW root parser](https://github.com/ladislav-zezula/CascLib/blob/master/src/CascRootFile_WoW.cpp). Epicast's small reader is development-only and is not an addon dependency.

## Runtime safeguards

- Both text and numeric lookup expose the filtered catalog. Unlisted numeric IDs cannot create synthetic entries or be loaded directly by the preview. The model addition function independently checks catalog/session eligibility.
- Before declaring a preview ready, check successful loading, requested ID, returned ErrorCube ID/path and the known cube bounds. Bounds support native Vector3 tables and six-number fixtures. Unreadable validation fails closed; normal transient failures can be retried.
- Repeat validation at Add static / Add bound click time. A late actor replacement cannot add the previous ready selection. Session-detected placeholders leave the result list and cannot be re-added.
- A no-result query clears the previous selection/actor and disables both Add buttons. Generation guards still prevent stale completion callbacks from reviving another selection.
- Session exclusions are memory-only. Existing saved layers, including historical numeric IDs, remain intact; normalization does not delete user settings. Default artwork/effect files, trigger logic and schema 2 are unchanged.

The runtime uses the public [Forever ModelSceneActor API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua). That API does not promise a separate reliable missing-model flag. The verified catalog plus ID/path/bounds checks cover the observed error cube; they are not proof of every possible driver/render failure. Bounds are checked before display and at addition. All appearances and animation choices still require user in-game review; no game UI automation was performed.

## Regression evidence

The regression first failed on numeric FileDataID **166046**, which beta.5 could synthesize despite its removal from the catalog. Tests now cover missing/out-of-range numeric searches, stale selection clearing, direct preview/add bypasses, accepted-but-placeholder loads by ID/path/bounds, native Vector3 results, unreadable metadata/retry, add-time fallback, stale callbacks, preservation of historical IDs, Save/reload and Resource binding restrictions. The build reader test checks BLTE checksum failures and resident texture-variant fallback. The audit requires exact agreement between the catalog and the Forever inspection manifest.

`npm ci --ignore-scripts --no-audit --no-fund`, `npm test`, `npm run audit` and `git diff --check` passed. The dependency restore needed network access after sandbox DNS failed. All 21 Lua modules loaded in TOC order; all 30 approved media hashes are unchanged.

`dist/Epicast-0.1.0-beta.6.zip`: **58 files, 13,245,033 bytes**, SHA256 `897953A1FAC03D2667DA6A454D1B021A61ED631E29A5F1270A9B6320A4D49DD7`. Archive/source hashes and all 58 installed hashes verified. Installed to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`; eight payloads changed. Backups/report: `artifacts/install-20261115-215645`. SavedVariables were not accessed. No Git commit, push or release. These checks do not claim live game acceptance.
