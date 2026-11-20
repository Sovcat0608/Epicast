# Epicast offline Effect Studio

An isolated browser replica of the in-game Effect Studio, using approved crest artwork and real Forever M2 effects. It does not modify the addon, shipped bakes, game archives or SavedVariables. The root page is now the editor; the earlier renderer laboratory remains at `/lab.html`.

## Run locally

From this directory, run `npm ci` once, then `./Start-Prototype.ps1` and open http://127.0.0.1:4318. Stop it with `./Stop-Prototype.ps1`. Alternatively, run `node server.cjs` in a terminal and stop with Ctrl+C. The server uses Node and pinned Fengari to read the shipped Lua definitions in a fresh mocked environment. It never loads account configuration.

The compiled renderer is already available on this machine. `./Setup.ps1` fetches and verifies the original upstream binaries (retained for negative comparisons). To reproduce the calibrated build, run `./Setup-Compiler.ps1 -Python <python3 executable>`, then `./Build-Renderer.ps1`. These install the pinned portable Emscripten toolchain, CMake and Ninja under ignored `vendor/` only; they do not register a system toolchain. The server checks the built JS/WASM/data hashes and patch recipe before starting.

Rendering uses only loopback requests after setup. Game assets come from `D:/World of Warcraft`; set `EPICAST_GAME_ROOT` to change the client root. The build/root manifest must match Epicast's inspected Forever catalogue; mismatches fail rather than silently substitute retail assets.

## Editor workflow

To refresh the Druid and Mage preview from the last WoW save, run `node sync-game-config.cjs` and restart the local studio. It imports only the six crests' size, position, facing, effects toggle and visibility into the ignored local cache. The preview centers each crest like the game’s Effect Studio and shows its saved game position separately. Synced sessions open in 1:1 using one browser CSS pixel per WoW UI unit. For physical-pixel calibration, run `/run local w,h=GetPhysicalScreenSize(); print(w,h,UIParent:GetWidth(),UIParent:GetHeight())` in WoW and pass the four reported numbers to the sync command. Developer effects edited in WoW are held in memory until explicitly exported and baked.

- **Effect Library:** search all 8,723 Forever-compatible entries by name, path words or FileDataID. Preview, replay/pause, rotate, fit/zoom, change background and inspect supported animation IDs. Add an effect as a new unbound layer. Missing-model placeholders and failed previews cannot be added.
- **Artwork Config:** select layers from the front-to-back sidebar; filter All/Static/Bound and move effects or artwork forward/backward. The preview renders the complete shipped crest. Size, angle, X/Y and opacity have numeric and slider controls; drag the preview to position an effect. Visibility, artwork opacity and optional attachment to the artwork’s six-second hover are editable.
- **Spell waiting room:** add names/IDs before binding; select a spell and signal, then Bind to selected effect. One spell can drive multiple layers. Unbind retains the waiting-room entry; only unbound entries can be removed. Playback controls include main sequence, intro/outro and durations. Test response and Simulate selected spell run offline; no game events are received.
- All nine class banks and 29 crest/resource slots are accessible. Only the six shipped Mage/Druid designs have artwork. Other slots can be configured without inventing art. Resources cannot bind spells.
- **Save session** establishes an in-memory checkpoint across crests; **Discard changes** restores it. Browser reload/close ends that session. **Copy crest bake** copies or downloads version-2 JSON, including depth order, artwork settings, waiting-room spells and motion attachment. Exports pass the existing `tools/Build-CrestBake.cjs` validator and can be given to the project’s Crest Baker. Export does not bake, install or publish anything automatically.

The artwork is currently one complete floating texture per crest; the layer panel exposes that real layer, not fictional separated painted pieces. The preview has Fit, 1:1, zoom, Pause and explicit Reload controls. Reload is for recovery/testing, not a repeated-playback workaround.

**5054328 Hold now renders reliably in the tested cases.** The old auto-fit camera reproduces blank frames while sequence158 and all seven emitters remain active. The calibrated camera produces visible pixels throughout three12.5-second Hold cycles and five show/release/replay cycles. No animation tracks, material shaders or game assets were rewritten; no periodic model reload workaround was added. See [renderer-notes.md](renderer-notes.md) for the diagnosis and exact projection mapping.

Effects use the entire preview framebuffer, eliminating the old384px local clipping square. The panel itself remains the intentional preview boundary; zoom down to20% to inspect wider effects. Attachment initially follows each shipped row. Complete game material fidelity is not claimed.

## Test scope

- Studio: full twelve-effect Arcane and nine-effect Restoration bakes, including **166602** and **5054328**; capacity exercised with32 simultaneous native layers.
- Legacy laboratory: three-effect Restoration and Arcane scenes, retained for the original rendering regressions.
- Native particle/material rendering through a pinned WebWowViewerCpp source build, with an explicit Epicast camera and read-only diagnostics; actual M2/SKIN/BLP dependencies come from the local client.
- Browser composition above/below artwork, independent model instances and matched six-second hover. The web easing approximates native IN_OUT; amplitude matches ±1.2% of displayed art height.
- Model-supported Intro/Main/End requests using the shipped binding durations. **166602 only has sequence 0**, so it never receives nonexistent Hold/End requests.

For automated tests, also run `npm ci` in the repo root, set `PLAYWRIGHT_BROWSERS_PATH` to this directory's `.browsers`, and run `npx playwright install chromium` once. `npm test` runs264 projection comparisons, the44 legacy browser checks and the studio workflow/GPU checks. `npm run test:studio` runs the editor tests alone; `npm run test:hold` runs the longer negative-control Hold regression. Tests use loopback ports4319/4320/4321 and the installed addon only for read-only projection comparisons and payload hashes. No account settings are read.

Evidence is written to ignored `results/verification.json`, `results/studio-verification.json`, screenshots and a browser recording. Editor tests exercise real controls, binding, session rollback, exports, class isolation, 32 layers and real GPU pixels. Outgoing browser requests other than the local server are blocked. Software-rendered headless runs are not hardware performance benchmarks.

## Important preview limits

The prototype imports effect IDs, animation IDs, binding timing, opacity and native placement from shipped bakes. Actor scale/origin, camera azimuth/elevation/roll, near/far planes, artwork-relative placement and compensated viewport FOV now use Epicast's geometry.264 point comparisons execute the installed Lua implementation and compare its captured native camera calls against the browser projection. This verifies the math, not a side-by-side game screenshot. Browser lighting/materials, alpha composition and more effect types still need manual game comparison. Model bytes and shader blend functions remain unchanged.

Replay reasserts sequences and reuses ongoing simulation. It does **not** prove particle/global-clock rewind. Hidden test layers keep simulating. Cold scene recreation is a separate comparison and is not a proposed change to Epicast's in-game pooling. A browser result cannot establish or fix the client's first-load versus subsequent-playback behaviour.

The studio uses one WASM/WebGL context for up to32 persistent native scenes, with full-stage framebuffer targets composited in the exact artwork/effect order. GPU composition preserves additive RGB even when native alpha is zero. The library has one separate preview context. The old lab still uses one iframe per effect for controlled comparisons. Shared rendering exposed and fixed an upstream uniform-buffer flush indexing error across scene arrays; the reproducible patch and private framebuffer ownership are documented in `studio-notes.md`.

The catalogue is verified for the Forever client, not exhaustively for this browser renderer. Wider material/model coverage, native easing fidelity and side-by-side game appearance remain manual acceptance items. The current projection matches the newer installed beta.18 FOV (`2 atan(3/8)`); this differs from the earlier lab calibration and is checked by the264 numerical comparisons. No game UI automation is used.

See `THIRD-PARTY.txt` for pinned dependency provenance. `vendor/`, `.browsers/`, `node_modules/`, cached output and recordings are ignored and never enter the addon package.
