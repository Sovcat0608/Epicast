# Mage reboot — option 1 integration, beta.12

The user selected the first uncorrected crown/pendant render and authorized building and installing it. Approved source: `concepts/mage-reboot/Mage-reboot-trio-v3-initial.png`, native2172×724RGBA, SHA256 `5DD9D15C1D72C67EFB83DFA664E235E450B36C8B8C1C3BBC7CC017B2A2D3F5AC`. The subsequent symbol-clearance and framing edits are unselected. No new image generation occurred during integration.

## Conversion

`tools/Prepare-MageReboot.ps1` verifies the exact source hash/dimensions and decodes straight BGRA. `tools/Build-MageReboot.cjs` separates the Frost / Fire / Arcane 724×724 source columns, retaining every source pixel once. No visible pixel intersects an internal column seam. Each column gets 22px transparent padding on a 768×768 canvas; the source is not stretched, retouched or upscaled. Existing source-edge pixels remain exactly as selected; none are reconstructed.

Six square sizes per crest: 192, 288, 384, 480, 576 and 768. Existing premultiplied-alpha Lanczos2 and CAS sharpness1.0/blend0.65 are applied once from the source canvas. CAS preserves alpha. Power-of-two backing and transparent margins remain; all 18 media hashes are in `tools/media-manifest.json`. Names use `MageRebootFire`, `MageRebootFrost`, `MageRebootArcane`, avoiding the retired asset paths.

`artifacts/mage-reboot-option1/bake-verification.json` records exact source/canvas hashes, bounds and source-pixel counts. The decoded runtime preview is `runtime-preview.png` in that folder, produced from the actual 384px TGA textures at approximately default1080p display size. No game UI/screen automation.

## Runtime

`MageRebootData.lua` contains generated bounds/texture metadata. `MageReboot.lua` renders each complete square crest at216×216 UI units before per-crest scaling. All floating shards are included in the approved composite. Native Translation uses two3s IN_OUT legs, ±1.2% height around the registered center, with phase retained through hide/show/reconfiguration. Pixel-grid and texel snapping are disabled. No rocking, separate scroll/seal/pendant animation, or per-frame positioning is introduced.

Mage's existing `mageFire`, `mageFrost`, `mageArcane` IDs, class banks, selection, placement and effect arrays remain. No settings reset or effect recalibration. Existing schema1–4 placement uses the historical migration geometry, not the new sprite bounds; existing schema5 layout is not migrated again. Buff/Cooldown Manager tracking and the 166602 fix remain. Resources retain pending artwork with native effects/meters. Druid rendering and all30 Druid textures plus the addon icon are unchanged.

## Validation and delivery

Full `npm test` and `npm run audit` pass. Current-runtime tests cover correct artwork/slot mapping, geometry, square aspect ratio, size selection/UV/flip, no snapping, six-second native hover, phase/static fallback, class/crest isolation, retained bindings and repeated Missile Barrage clears. Asset tests lock the uncorrected option1 hash and validate18 transparent RGBA textures.

`npm ci` could not reach registry.npmjs.org from the isolated environment (ENOTFOUND). All five test dependencies were restored offline from existing local copies with versions exactly matching package-lock.json; every copied file hash was checked. Evidence: `offline-test-dependencies.json`. No permanent dependency on another addon was introduced.

The installer verifies archive/source equality before writing and installed payload hashes afterward. `tools/retired-mage-files.json` is an explicit57-path allowlist of retired custom textures/renderers; they are individually backed up, hash-checked and removed only inside the fixed Epicast AddOns destination. No recursive destination deletion or settings-file access. Use `-VerifyOnly` for the read-only install plan. Package/install evidence is recorded in `docs/release-0.1.0-beta.12.md` after delivery. In-game appearance and effect calibration remain user-reviewed.
