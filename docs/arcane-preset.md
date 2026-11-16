# Arcane effect bake — beta.13

On 2026-11-16 the user clarified: “Bake the in-game effects and spell binding configuration.” This authorized reading Epicast's saved Arcane configuration without modifying it. Only the twelve `content.classes.MAGE.slots.arcane.addedEffects` rows were exported; personal placement, other classes, account identifiers and the full saved database are not included in the published fixture.

Source save timestamp: **2026-11-16 17:16:05.228 UTC**. Source SHA256: `9B061597DACEF50CBA6ED14545D0CD400C09E7F158D68C33A154AD112009F892`. The source was parsed as literal Lua data, never executed. Local read receipt is ignored under `artifacts/arcane-bake-beta13/`. The source file remains unchanged.

The effect-only fixture is `tests/fixtures/arcane-beta13.json`, SHA256 `B323D4FA99B0803B1D2F30C03C08C8D253DA4DA9764DF345F92C9FBDF52A303E`. `node tools/Build-ArcanePreset.cjs` rebuilds `ArcanePreset.lua` from that fixture without reading game settings. All model fitting, sequence IDs, desaturation, placement, opacity, layer order, behavior, binding text and segment timing are preserved, including inactive binding fields on static rows.

| Layer | Model | Behavior | Size / angle / X / Y / opacity |
| --- | --- | --- | --- |
| 1 | 1713497 Arcane dungeon fog | Static | 70 / 90 / 6 / -46 / 10 |
| 2 | 950917 Arcane hands | Static | 124 / 90 / 11 / 32 / 10 |
| 3 | 1699091 Arcane Blast precast | Arcane Blast cast | 100 / 90 / 2 / 29 / 70 |
| 4 | 5054328 Arcane storm | Missile Barrage Buff | 200 / 90 / 4 / 67 / 100 |
| 5 | 166009 Void glow | Static | 162 / 90 / 4 / 32 / 70 |
| 6 | 2499922 Arcane cannon missile | Static | 69 / 0 / 1 / -30 / 9 |
| 7 | 1712386 Arcane Blast impact | Arcane Blast success | 100 / 90 / 0 / 19 / 70 |
| 8 | 1622612 Arcane barrage impact | Arcane Explosion success | 100 / 90 / 0 / 22 / 70 |
| 9 | 1545158 Arcane shot impact | Arcane Missiles pulse | 100 / 7 / 0 / 43 / 70 |
| 10 | 4637330 Arcane surge precast | Arcane Missiles channel | 174 / 90 / -2 / -24 / 95 |
| 11 | 982934 White Arcane accent | Static | 100 / 90 / -39 / 72 / 20 |
| 12 | 982934 White Arcane accent | Static | 100 / 90 / 41 / 72 / 19 |

All layers are in front of the artwork. Missile Barrage retains Buff tracking and its 0.5-second intro and 0.333-second outro. Existing safe Cooldown Manager matching remains unchanged.

New Arcane slots without legacy content use the preset. Existing class slots keep their effect arrays, including empty arrays. Existing pre-slot Arcane content still merges both old lists once with the established placement reset; the new preset does not replace customized old lists. No schema bump is required. Resource defaults still use their legacy static glow; Fire/Frost stay empty. Personal crest size, position, visibility and facing are not baked.

Tests compare every generated field against the approved export and exercise fresh/missing arrays, idempotence, saved overrides, empty arrays, legacy merge and class/resource isolation. The actual current renderer and event handlers test all six bound routes, four consecutive native Barrage gain/clear cycles, and a rapid re-proc during outro, with no frame allocation, model reload or settings writes during casts. GPU appearance remains in-game tested.
