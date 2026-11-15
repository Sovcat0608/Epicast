# Moonwarden / Groveheart integration

Approved and authorized for build/reinstall on 2026-11-15. Beta.4, schema 2, Forever interface 16001. No Git publication requested for this build.

## Artwork and rendering

Exact approved source: `concepts/druid-sisters/Moonwarden-Groveheart-review.png`, 1536 × 1024 RGBA, SHA256 `926C6CC974FCD6015A1AE576E52123C7C4F2A157DECADD3F0CB5F92DCA157034`. No regeneration or repaint. Split at x=768 into equal 768 × 1024 canvases, keeping the source's relative scale, antlers, lower silhouettes and registration. Left is Moonwarden; right is Groveheart.

`tools/Prepare-Druid.ps1` verifies the source hash, decodes exact BGRA pixels with System.Drawing, then runs `tools/Build-Druid.cjs`. Copied, unchanged artwork utilities in `tools/artwork` are the approved size/CAS implementations from the existing project: premultiplied-alpha Lanczos2 reduction, two-texel transparent RGB bleed, linear-light CAS sharpness 1.0/blend 0.65 with protected transparency boundaries and unchanged alpha. Existing CAS notices retained. These tools have no runtime dependency on another addon.

Six content widths per sister: 192, 288, 384, 480, 576 and 768; heights are width × 4/3. Each is padded transparently to power-of-two backing dimensions. The 768 × 1024 full-source fallback is not upscaled. Source bounds at alpha >=8: Moonwarden `[42,14,751,998]`; Groveheart `[15,81,730,976]`, exclusive right/bottom. Bounds affect frame geometry only; source alpha is retained.

`DruidSisters.lua` renders at 162 × 216 UI units at default size, with effective-screen-size texture selection, correctly cropped UVs, disabled pixel-grid and texel snapping, and native six-second Translation hover (two 3s IN_OUT legs, ±1.2% of artwork height). No rocking or additional emissions. Hide/show, resize and configuration preserve phase. Disabling animation places art at its static registered center. Front-facing Druid art retains its orientation in Edge placement; explicit Flip still works.

Decoded runtime preview inspected: `artifacts/druid/runtime-preview.png`. Machine-readable bake evidence: `artifacts/druid/bake-verification.json`. All 18 previous runtime assets remain byte-for-byte unchanged; twelve Druid TGAs are added.

## Class and saved configuration

Schema 2 adds `content.druid.left/right` alongside the existing `content.spells` Mage bank and `content.resources` bank. Normalization preserves both existing banks and all placements; there is no settings reset or manual SavedVariables editing. Normal addon loading upgrades schema 1 in memory. Older beta builds reject schema 2 rather than silently discarding the Druid bank.

`E.GetSide` chooses the Druid bank only when the player's class is DRUID and the physical slot's role is Spellcasting. It follows role and sister swaps, with tuning isolated from Mages. Other classes cannot select Druid art, even when the legacy Arcane class restriction is disabled. Mage and Resources behavior remains as before. The renamed checkbox describes that existing Arcane restriction; it never suppresses a Druid's Spellcasting design. All Druid specializations/forms use the pair.

No Druid Resources pair or native spell-effect preset has been commissioned. Druid added effects start empty, avoiding Mage bindings and unapproved effect calibration. The existing developer studio can create Druid-specific bindings independently. Arcane glyph/seal controls are hidden/disabled for Druid art because these sprites do not contain those separate layers.

## Validation

`tests/druid-sisters.lua` uses real modules and handlers: schema-1 preservation, options-closed visibility, Mage/Druid/other-class transitions, no retired Mage playback, role/sister swaps, settings isolation, explicit binding playback, Save/Cancel, hidden custom controls, aspect/UV selection, native timing/amplitude, phase recovery, mirrored texture coordinates, static fallback and oversized/missing-display-metric fallback.

`tools/test-druid-assets.cjs` validates the approved PNG identity and twelve RGBA textures, power-of-two transparent padding and silhouette coverage. Existing Mage, resource, tabs, Barrage and optional-reader isolation regressions remain in the full suite. Native visual appearance and motion require user testing; no game UI automation performed.

## Build and installation

All tests, 21-module Lua 5.1 parsing and the 30-texture scope/media audit passed. ZIP: `dist/Epicast-0.1.0-beta.4.zip`, 58 files, 13,149,430 bytes; SHA256 `701FA71EE9F7EE35ED22D4F45AB6223FE3E8783AF93D760607B54EF627C7D647`. Every archive payload was checked against source.

Installed under the user's explicit instruction to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`. The installer verified all 58 installed hashes; 23 payloads were added/changed. Replaced addon files and exact install report: `artifacts/install-20261115-190051`. The operation only read/wrote the package's addon payload paths and never accessed SavedVariables or WTF. Existing Arcane media were unchanged. Start/restart WoW before testing because the package adds a Lua module and textures. No commit, push or public release performed.
