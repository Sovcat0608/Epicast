# Artwork conversion helpers

These three files are exact copies of the existing project's approved size/CAS utilities, inspected and reused for the Druid integration on 2026-11-15:

- `Build-SkycutterSizes.cjs`: premultiplied-alpha Lanczos2 downsampling and power-of-two TGA padding.
- `Build-SkycutterCAS.cjs`: linear-light CAS, sharpness 1.0, blend 0.65, alpha-boundary protection. See the root `THIRD-PARTY-CAS.txt` notice.
- `Build-HaloMipmaps.cjs`: reused only for transparent RGB bleed; generated mip levels are discarded by the size builder. Runtime Druid textures are plain TGA.

Imported as libraries by `../Build-Druid.cjs`. Use `../Prepare-Druid.ps1` to rebuild the Druid assets, rather than running these historical standalone entry points. There is no runtime or development dependency on another addon directory.
