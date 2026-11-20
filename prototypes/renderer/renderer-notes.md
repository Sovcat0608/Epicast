# Camera, Hold and clipping investigation — 2026-11-16

Scope: isolated browser prototype only. The installed addon, bakes, textures, game archives and SavedVariables are not modified. Account settings are never read. Concurrent addon development is outside this change.

## Why 5054328 disappeared

The blank frames are reproducible with the original binary and with the rebuilt engine using its original auto-fit camera. In the latter, diagnostics report sequence158, advancing/wrapping sequence time, seven enabled emitters and live particles even when the framebuffer is blank. Changing to the explicit Epicast camera resolves these samples without changing animation logic or reloading the model between cycles.

The upstream method named `getColissionAABB()` actually uses the first animation's bounds when animations exist. For5054328 these are only approximately X0.00029–0.02904, Y−0.17120–0.14908, Z−0.15584–0.16444. Auto-fit uses this tiny Intro box, placing the camera roughly0.465 model units from the bounds centre along the X axis (observed camera X≈0.480), with a1-unit near plane. This is unsuitable for the larger animated meshes/particles. The model header also contains sentinel collision bounds, but those are **not** the bounds chosen in this path; an early hypothesis about those sentinels was ruled out by source tracing.

The calibrated camera uses the shipped row's scale1.1889712736559 and origin, viewed along the actual native basis, at the equivalent distance8/scale≈6.7285 model units. Near/far are0.01/scale and100/scale. Auto-fit cannot overwrite the explicit camera during asynchronous load completion.

Initial controlled comparison:75 samples per mode, three12.5-second Hold cycles with Intro/End transitions. Original binary:48 blank samples. Rebuilt engine plus old auto-fit:49 blank. Calibrated camera:0 blank. Counts depend on particle timing; the regression asserts a reproduced negative control and no blank calibrated samples, rather than exact counts. `results/ab-probe.json` records current samples, actual camera positions and emitter/sequence diagnostics.

## Projection equivalence

The mapping follows `NativeEffects.lua`, `Effects.lua`, `DruidSisters.lua` and `MageReboot.lua`. `test-projection.cjs` executes the installed camera/actor code in Fengari with captured native API calls; it does not read SavedVariables or start the game.

- Base effect anchor frame:225 UI units at100% crest size.
- Visible art width: Restoration162; Arcane216. Their artwork centre is30 units above the anchor centre.
- Native scene side length: `864 × crestSize × trailSize/100`, after the existing doubled viewport compensation. FOV: `2 atan(3/4)`.
- The client transforms the actor as `(vertex − origin) × modelScale`. The browser renders unchanged model vertices using the equivalent camera `origin − forward × 8/modelScale`.
- Browser view rows are native right, up and negative forward. The projection carries native viewport scale and an off-centre anchor into the full preview framebuffer. CPU billboards, frustum tests and sorting receive the same camera as the GPU.
- CSS artwork scale and framebuffer pixel density are separate. Resizing or zooming changes projection without replacing models. Paused placement/zoom changes redraw with zero simulation delta.
- Six-second motion amplitude is±1.2% of art height. Web cosine easing remains an approximation of the native IN_OUT easing; attachment is an explicit test toggle.

The264 numerical cases cover the shipped effect calibrations, both facings, multiple crest sizes, panel aspect ratios and zoom. They do not certify shader/lighting fidelity against screenshots from the live game.

## Clipping

Previously each effect rendered into384×384 and was then moved/scaled with CSS. Pixels outside that local square were irretrievably cut off. Each effect now renders into a framebuffer matching the complete preview panel, using an asymmetric projection to retain its calibrated anchor and apparent size. There are no individual CSS scale/translate boxes or local scissor rectangles.

The browser regression compares a deliberately extended native effect against an imposed384px square crop. Visible pixels beyond that former square survive in the fixed renderer. Panel resizing updates all framebuffers with unchanged scene counts. Only the outer preview panel clips; reducing the zoom reveals more of the effect.

## Reproduction and source provenance

Pinned source: [Marlamin/WebWowViewerCpp wtl](https://github.com/Marlamin/WebWowViewerCpp/tree/4017528a7edf10a06714643716cf4a5fc56854cf), Emscripten6.0.11. `native/patch-source.cjs` applies the small camera/diagnostic/build patch idempotently to this revision. Original pinned wow.tools.local shaders are retained byte-for-byte. Compiler dependencies remain local and ignored. `vendor/build_packed/manifest.json` records binary and recipe hashes, checked on server startup.

`npm test`: projection plus full-crest GPU tests, repeated166602 and5054328, depth, attachment, clipping, resize, cold comparison, request restrictions and87 source/installed payload hashes. `npm run test:hold`: the sustained negative-control comparison. Headless tests use SwiftShader; these are correctness tests, not hardware performance measurements.

Remaining limits: six selected effects, separate WASM instance per effect, no universal material compatibility claim, no reliable emitter/global-clock rewind, hidden layers continue simulating, no exporter or game-event bridge. In-game visual acceptance remains manual.
