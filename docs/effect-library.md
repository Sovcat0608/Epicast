# Full native effect library

Current **beta.6** filters this source index to **8,723 models inspected in Forever 1.60.1.70938**, with runtime placeholder rejection. Numeric lookup obeys the same filter; arbitrary unlisted previews are no longer supported. See [Forever compatibility](forever-effects.md) for the file checks, regression coverage and delivery evidence. Schema 2 and existing saved layers remain unchanged.

The sections below preserve beta.5's source/provenance history. The user first removed the Arcane-only scope, then requested Forever filtering after encountering error-cube placeholders. `tools/Build-EffectCatalog.cjs` now applies `tools/forever-effects.json` to those same pinned source inputs and records the availability-manifest hash in its output manifest.

## Catalog and provenance

9,768 unique entries: all 9,763 `.m2` paths under `spells/` and `particles/` in the refreshed source, plus five supporting world-effect models with existing preview calibrations. These are filename/ID mappings, not 9,768 verified Forever renders. The native preview must load before Add static / Add bound is enabled; unavailable assets are reported normally. No game model/texture binaries are shipped or downloaded by the addon.

Primary source: [wowdev community listfile](https://github.com/wowdev/wow-listfile), pinned revision `69b61e99aaa1bb767ad8e42288780d23eeb15bea`, dated 2026-11-14. Downloaded the [spells partition](https://raw.githubusercontent.com/wowdev/wow-listfile/69b61e99aaa1bb767ad8e42288780d23eeb15bea/parts/spells.csv) and [misc partition](https://raw.githubusercontent.com/wowdev/wow-listfile/69b61e99aaa1bb767ad8e42288780d23eeb15bea/parts/misc.csv), which contains particle paths. The source filenames can change; runtime loading uses FileDataID.

`tools/Build-EffectCatalog.cjs` generates the standalone Lua catalog from those local CSVs and `tools/effect-preview-presets.json`. Input hashes, revision, row counts and generated output hash are recorded in `tools/effect-catalog-manifest.json`. Run `node tools/Build-EffectCatalog.cjs <source-directory>` with `spells.csv`, `misc.csv` and the pinned `source.json` metadata. The current downloaded inputs are under ignored `artifacts/catalog-source`.

The 32 friendly names/aliases and preview-only calibrations were extracted from the workspace's original full effect viewer catalog. They affect isolated previews, never current artwork placement or bindings. Five world-model entries cover Kirin Tor Seal, Gentle Whirlwind, Skywall Swirl, Water Ripples and Candle Flame. Animation metadata expands from six to 73 already-inspected local records; the original six are unchanged. There is no runtime or build dependency on another addon folder.

## Behavior and checks

- The text index is built lazily; searching does not create or preload native actors for catalog entries.
- Numeric search accepts integer IDs from 1 through 4,294,967,295, returning a generic preview entry for unnamed models. Added-effect normalization accepts the same range so a successfully previewed effect survives Save/reload. Invalid, fractional, infinite and out-of-range IDs remain rejected.
- Player artwork choices are unchanged. Resource bindings remain prohibited; the sixteen-layer limit and combat edit guards remain.
- Known animation IDs retain their inspected availability; unknown models remain unverified rather than treated as unsupported.
- `tests/effect-library.lua` first failed against beta.4's eleven-model catalog. It now exercises catalog uniqueness and multi-class searches, aliases, literal punctuation, numeric limits, adding a non-Arcane model to a Druid, persistence, unknown IDs, failed/loading previews and stale callback isolation. It also verifies no actor allocation during search and resource-bound rejection.
- Audit validates generated catalog identity and format separately from artwork/namespace checks. Game paths may legitimately contain names also used by retired artwork; only the catalog's string data is excluded from that legacy-name scan.

Full test suite, media audit, package and installed-file hashes are checked for delivery. Actual native model availability and appearance remain client-tested. SavedVariables files are not accessed or edited.

## Beta.5 delivery

`dist/Epicast-0.1.0-beta.5.zip`: 58 files, 13,256,100 bytes, SHA256 `A60A815BCB22110D985C8EAB6FC5B19570C6559011DACBD9781EB8263C1CAC23`. All source/archive hashes verified. Installed to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`; all 58 hashes verified, eight payloads changed. Backups/install report: `artifacts/install-20261115-201733`. All 30 artwork assets, configured default effects and schema 2 are unchanged. No SavedVariables access, Git commit/push or public release.
