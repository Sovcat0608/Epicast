# Epicast rules

- Independent addon: only `EpicastDB`, `/epicast`, `/epic`, Epicast frame/template/callback names and media paths. Never read/write EndCapper saves or depend on its runtime.
- Central and Edge are placement slots. Spellcasting and Resources are exclusive roles, with at most one of each. Swap assignments atomically. Keep placement in `sets`, artwork/effect tuning in `content` so tuning follows the role.
- Only the approved Arcane Tome / Arcane Scroll art and eleven catalog models belong in this beta. No other art, effect presets, migrations or source-only binary models. Don't import the full EndCapper model/catalog.
- Resource sets cannot carry spell-bound layers. Secret/unavailable game values must not be compared or used in arithmetic. No simulated channel ticks or fabricated resource levels.
- Artwork rendering: six-second native Translation hover, two 3s IN_OUT legs, existing book amplitude `width*.012+2`; scroll seal lags by one second. No rocking for this approved pair. Disable both pixel-grid and texel snapping. Preserve size-specific maximum-CAS TGA assets, transparent padding, frame registration, crossfade emissions and phase through reconfiguration. No regeneration without user authorization.
- Future sister art is generated together in one render. Smooth sculpted painterly treatment and clean silhouettes; avoid granular microtexture. See handover.md for provenance and fidelity details.
- Native ModelScenes remain independently pooled and preloaded. Bindings change visibility/timelines only; no model reloads or configuration writes during casts. Keep late-load, generation and timer-token guards.
- No game UI/screen automation. Test with `npm ci`, `npm test`, `npm run audit`; package with `./tools/Package.ps1`. Live appearance remains user-tested.
- No commit, push, public release, automatic install or CurseForge setup without user instruction. `handover.md` is the detailed continuation record.
