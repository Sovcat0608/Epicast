# Epicast 0.1.0-beta.9 — Druid repaint delivery

Built and installed 2026-11-16 at the user's request. All three Druid crests use the exact approved v8 repaint. This is a local beta ZIP and installation, with no commit, push or external publication.

## Build identity

- Version **0.1.0-beta.9**, schema **3**, Forever interface **16001**.
- ZIP: `F:/Work/WoW Addons/Epicast/dist/Epicast-0.1.0-beta.9.zip`.
- Payload: **77 files**, **23,849,616 bytes**.
- ZIP SHA256: `025B2AAD106EB775F3EDF9393680CF1DD157537046261C36E4F26D3AF43BB931`.
- Approved source: `concepts/druid-specialization-trio/Druid-specializations-review-v8.png`, native **1882×836 RGBA**, SHA256 `4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8`.

## Artwork and preserved behavior

The source was separated by connected alpha silhouette, retaining the antialiasing and detached details. Each crest keeps the existing 660×880 transparent canvas, 3:4 aspect ratio and vertical registration. All eighteen 192/288/384/480/576/660 textures use the existing premultiplied Lanczos2 + CAS sharpness 1.0 / blend 0.65. No source repaint, blur, upscaling or additional sharpening recipe was introduced. CAS alpha was verified unchanged and no visible source pixels were clipped.

Measured visible bounds were refreshed in Model.lua for the new silhouettes. Frame size, six-second native hover, phase, disabled snapping, class/spec selection, bindings and effect tuning remain unchanged. The Arcane pair, Resources and all thirty other media files match the pre-update payload. No schema change or new settings migration was added. The trigger-code diagnostic revision remains beta.8 because that code did not change; the TOC/package version is beta.9.

Comparison against the pre-update payload identifies **22 changed files**: eighteen Druid textures, Model.lua's three bound records, TOC, README and CHANGELOG. **55 payloads are byte-identical**. Evidence: `artifacts/druid-repaint-v8/payload-comparison.json`. Previous v6 artwork, the beta.8 ZIP and old preparation outputs are retained.

## Verification

- Locked dependencies installed with `npm ci --ignore-scripts`; the initial offline attempt lacked cached packages.
- Full `npm test`, `npm run audit` and `git diff --check` passed. This includes class migration/multi-selection, preserved effect settings, native hover, Barrage/Clearcasting regressions, exact approved source hash, RGBA geometry, transparency and media hashes.
- All eighteen converted textures passed the existing asset checks. The native-size 192-pixel decoded comparison was visually inspected: `artifacts/druid-trio-v8/Runtime-192-comparison.png`.
- `tools/Package.ps1` verified every archive entry against source. `tools/Install-Beta.ps1` repeated archive/source verification and checked all **77 installed hashes**.

Preparation evidence: `artifacts/druid-trio-v8/bake-verification.json`. Test/audit logs and original payload snapshot: `artifacts/druid-repaint-v8/`. Package evidence: `dist/package-verification.json` and its versioned copy in that artifact directory.

## Installation

Installed at `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`; **22 files replaced**, with the previous versions backed up at `F:/Work/WoW Addons/Epicast/artifacts/install-20261116-124456`.

Full installed-file evidence: `artifacts/install-20261116-124456/install-verification.json`. The installer was restricted to the confirmed Epicast AddOns directory and source-verified payload paths. **SavedVariables files were not opened, read, written, copied or deleted.** No game UI automation was used.

Fully close and restart WoW to refresh the cached artwork textures. Review all three crests at your normal in-game size and against your configured effects. Source/texture checks do not establish live GPU appearance or visual effect registration; existing calibration values were preserved.
