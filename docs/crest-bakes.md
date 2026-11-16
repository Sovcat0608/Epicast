# Crest-owned effects — beta.16 / schema6

The user explicitly replaced the old “saved edits win over defaults” policy. Effects, native model fitting, timing and spell bindings are part of a crest's shipped definition. This supersedes historical preservation and legacy two-list effect migration rules. No developer configuration is stored in a player profile.

## Ownership and upgrades

`Model.Normalize` keeps only the normal UI settings: per-crest placement/facing/animation, selections and resource controls, plus global display preferences. Schema1–4 geometry migration remains; schema5 placement is retained directly. Old `addedEffects`, native effect overrides, retired overlays and the obsolete pair backup are discarded in memory. The tools never inspect or edit account SavedVariables files.

`CrestEffects.lua` resolves definitions by `CLASS:spec` or `RESOURCE:left/right`. A weak-key ownership map follows runtime configuration copies without serializing metadata or effects. Pending classes have distinct identities despite sharing `art=none`. `CrestBakes.lua` supplies compiled per-crest overrides; otherwise existing project defaults supply the bake. Arcane's approved twelve-layer `ArcanePreset.lua` remains byte-identical. Empty shipped definitions are intentional: Fire/Frost and currently unbaked Druid/other spec slots have no effect layers. This release does not invent or recover previously unbaked personal tuning. Resource crests retain their static glow.

On every addon load, the installed definition is authoritative; there is no “follow defaults” toggle or saved bake version to get stuck. A future release can change the definition without modifying player preferences. New addon source must still be loaded by WoW: fully restart for this release's new TOC modules, and use `/reload` for subsequent updates where the client permits reloading existing files. Epicast cannot hot-load replaced Lua into a running session without a UI reload.

## Developer workflow

1. Enable Developer mode, select a class and crest, and tune layers in the existing effect library. Editing clones that crest's definition into an in-memory authoring draft. Never mutate the shipped rows directly.
2. Save session retains a RAM checkpoint. Cancel/Close discards uncommitted work. Turning off developer mode or closing the main editor renders shipped definitions during normal play; reopening developer mode restores the saved session checkpoint. Reload/exit loses all developer edits.
3. Before reloading, use **Behavior → Copy crest bake** (or `/epicast bake` with an open developer editor), then Ctrl+C. This exports the selected crest only, including all static/bound layers, fitting, opacity, segment choices and bindings. It contains no account names, player positions or display preferences.
4. Save the copied JSON to a review file and run `node tools/Build-CrestBake.cjs path/to/export.json`. The compiler validates the current class/spec map, every field/range and the inspected Forever model allowlist, rejects private/unknown fields and resource bindings, then updates `tools/crest-bakes.json` and generated `CrestBakes.lua`. Review both files, run the full checks, rebuild and publish normally. Repeat for other changed crests.

WoW addons cannot write their own Lua source files. Export plus compilation is the explicit step that turns a temporary developer preview into a shared, updateable crest bake. Nothing relies on a developer's saved account configuration.

## Verification

`tests/crest-bakes.lua` exercises the real load/normalize/render/UI paths: schema5 stale effects and disabled native flags, retained normal preferences, a simulated future definition over an unchanged save, developer Save/Cancel/Close/toggle/reload, export UI, pending-class and resource isolation, placeholder rejection and native tab state/combat behavior. Existing Arcane regressions still exercise all twelve layers, repeated native Barrage gain/clear/re-proc and pooled no-reload playback. Current migration tests now assert shipped effects while retaining prior geometry coverage; historical schema4 fixtures remain intact.

The real Lua exporter is read back as JSON by `tools/test-crest-bakes.cjs`; all values match the expected tuned twelve rows exactly. Numbers use seventeen significant digits. The compiler is tested for unknown crests, arbitrary/error models, invalid fields/types/ranges, invalid resource bindings, over-capacity arrays, Stand-only166602 and Lua round-trip. Generated source must match its manifest. No game UI automation; native tab appearance and in-game timing remain manual acceptance checks.
