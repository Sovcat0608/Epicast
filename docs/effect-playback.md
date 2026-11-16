# Native effect replay diagnosis — 166602

Investigated for beta.8 on 2026-11-16 without game UI automation. The user's symptom: the first activation includes an apparent intro, but later activations look like Hold only.

## Confirmed local facts

The installed Forever **1.60.1.70938** CASC model 166602 has SHA256 `86620e6147d3a39b5fcc66c9ff4ba7f8e8c315d1a67823fd43deed73d48587f6`. Its MD20/v272 sequence table contains **only animation 0, variation 0, duration 1000ms, flags 0x820**. There is no animation 158 (Hold) or 159 (End). Eleven global animation periods are 533, 1100, 767, 567, 367, 1067, 700, 433, 1233, 800 and 500ms. The model's animated bone tracks use these global loops. Two particle emitters have constant rates of approximately 11 and 10 particles/second and lifetimes of 0.8 seconds. The compact reproducible inspection is `tools/Inspect-EffectPlayback.cjs`; its report is `docs/166602-playback.json`. Native binaries remain outside the addon payload.

Before beta.8, this model had no verified metadata. The UI allowed arbitrary 158/159 requests, and Intro defaulted to 0.5 seconds. The engine preloads a persistent actor, initializes its main animation, hides/shows its ModelScene for triggers, and calls `SetAnimation(id,0,1,0)` on activation. It never clears the loaded model or particle simulation during a cast. Real intro timers transition to the selected main sequence.

## Diagnosis and limits

Calling 158 on this model cannot select a real Hold segment. This is a confirmed metadata/authoring error, rather than evidence that a subsequent trigger was lost. The likely cause of the visual difference is first-load particle buildup versus reuse of the ongoing global/particle state, possibly combined with a saved unsupported main animation and a premature 0.5-second transition. This causal explanation is an inference from the model and lifecycle; exact GPU behavior has not been observed in-game.

Blizzard's published [actor API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua) exposes sequence selection, speed/offset and blending; it does not document a separate particle/global-clock rewind operation. [Blizzard's actor mixin](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/ModelSceneActorMixin.lua) distinguishes animation kits and sequence selection. Neither source guarantees that repeating SetAnimation resets an emitter's population. These are mirrored Blizzard primary source files; the local Forever asset is the authority for its available sequences.

## Changes in beta.8

- Verified metadata now lists 166602 as Stand-only. Saved/requested 166602 rows normalize to animation 0, with the nonexistent separate Intro/End transitions disabled, preserving bindings and placement. The studio disables Hold/End and explains the global-loop limitation.
- Bound sequence requests optionally disable animation blending before setting the requested ID and zero offset. This is capability-guarded and separately protected so an optional API failure cannot disable triggers. It does not claim to reset particles.
- `/epicast triggers` records the last requested `segment` to distinguish a real 158 request from a visual resemblance to Hold.
- Regressions cover repeat activation of 166602, valid 0→158→159 cycles on 1699091, rapid cancellation/removal and failure of the optional blend API. They assert no cast-time model reloads; mock tests do not simulate GPU particle history.

A guaranteed fresh-load particle intro on every activation is **not fixed or claimed**. That would require a separately evaluated reset/recreation strategy, with loading/performance/combat implications, or an effect with explicit suitable segments. The existing independently pooled/preloaded model contract is retained. In-game testing should compare the first and subsequent 166602 activations with `segment=0`, then compare a model with verified intro/hold/end transitions.
