# Developer effect studio audit and redesign

2026-11-16 · local beta.18 · player preference schema6 unchanged.

## Audit findings

The previous 1150×700 window mixed catalog discovery, isolated model inspection, a five-row layer list, and three narrow control pages. A developer had to decide between Add static and Add bound before an effect existed. Previous/next buttons made the current layer difficult to recognize, especially with duplicate model names. The behind-art checkbox offered only two depth buckets, with no selectable artwork in the layer list. The preview showed a single candidate model, so changes to existing layers could only be judged on the in-game crest behind the editor.

Binding was embedded in each effect row. Developers repeatedly typed spell names or IDs and could not prepare spells before finding a model. The selected trigger type was visually distant from the selected effect. Custom artwork was a separate dormant path rather than part of a coherent stack. File IDs and animation IDs were available, but precise edits, model inspection, binding and composition review competed for space.

The data model was stronger than the UI: class/spec identities already isolate crests, native actors are pooled, and shipped crest bakes are authoritative. The redesign keeps those contracts. Normal UI preferences still own crest selection, screen position, size, facing, the effects switch and resource choices. No per-account developer profile is introduced.

## Resulting workflow

The 1220×790 studio keeps class and crest menus visible above two adjacent native Warcraft tabs. It fits both screen dimensions and responds to display/UI scale changes.

1. **Effect Library:** search the inspected Forever catalog, select a result, inspect the isolated native model and choose its fit/animation. One Add effect layer action creates an unbound layer and takes the developer to Artwork Config. Loading, availability, placeholder and capacity checks still run at click time.
2. **Artwork Config:** a full-height layer list on the left, full-crest live preview and selected-layer controls in the middle, and a full-height spell waiting room on the right. The filters are Artwork, Static and Bound. The top of each list is the front of the scene. Forward/Backward moves through the full ordered stack, including layers outside the current filter. Selection follows the layer across page boundaries.
3. **Placement / Playback:** placement uses exact signed/decimal inputs, Enter/focus-loss application, Escape cancellation and mouse-wheel nudging (Shift ×10). Playback contains main sequence presets/ID, burst length, intro/end controls and timing. Model166602 remains Stand-only. Selected-layer tests run only in the editor preview.
4. **Spell waiting room:** add a name or exact ID independently of effects. Existing baked bindings appear here automatically. Select a layer to highlight its spells in blue, or select a spell to highlight its layers in green. Use Enter bind mode to stage several links, then Save binding or Cancel binding to return to single selection. An expanded spell lists each linked layer and its trigger. Click a linked layer to change that pairing's trigger. New links start with Cast succeeds. Unbinding removes a single link and retains the waiting spell. The waiting room holds up to 64 spells per crest.
5. **Save and export:** the footer explains RAM-only developer edits. Save session checkpoints all crests, Discard changes returns to the checkpoint, and Copy crest bake exports only the selected crest. Closing the studio leaves its applied draft available in the main editor; unfinished numeric text is discarded by Escape. Main-editor close/toggle restores shipped runtime definitions. Reload loses developer RAM.

## Artwork and rendering

Approved Mage and Druid art is currently one flattened floating texture per crest. The layer list shows that real **Crest artwork** layer; it does not pretend that painted crystals, roots or pendants are separately addressable. Pending-art classes and Resources have no fabricated artwork layers. Artwork visibility and opacity are bake properties; its overall size/position continue to follow the normal crest settings.

`StudioModel.lua` exposes artwork descriptors and stable effect identities, derived legacy order and per-crest waiting spells. Explicit order assigns interleaved native scene/artwork frame levels. Existing v1 bakes retain their previous rendering until edited, and all approved defaults remain unchanged.

**Follow artwork motion** uses the selected artwork layer’s existing six-second native hover. Epicast samples that animation’s phase and eased progress and moves the actual ModelScene anchor. A shared frame update runs while attached layers are visible. A new spell response joins the current artwork phase, and a hidden layer releases its frame updates. Default attachments are off.

`StudioPreview.lua` owns a separate pooled entry. It reads the selected draft even when that crest is hidden in normal play. Player spell signals and isolated tests reach the preview. The game and studio use the same model viewport, camera and placement. A scroll viewport bounds the stage separately, and zoom scales the whole composition. The 1:1 button uses the game crest’s effective UI scale. Closing or changing tabs disables preview entries, unregisters bindings and cancels tests. Late model completions reconcile only the currently visible preview.

## Bake format and ownership

Untouched v1 definitions and exports remain valid. The first structural edit creates optional studio metadata beside the effect array in developer RAM: bottom-to-top `order`, `artwork` settings and `spells`. Each effect gains a stable `layerID`; optional `enabled` and `followArtwork` are normalized. The player preference schema contains none of these fields.

Version 2 exports contain `effects` plus `studio`. Version 3 uses the same structure and adds a `bindings` list to layers with multiple spell responses. Each response has its own signal and timing. The compiler validates versions 1–3, including exact identities and order, artwork targets, waiting-room membership, the Forever model allowlist, resource exclusions and supported segments. The normal renderer loads the compiled overrides.

## Verification and limits

`tests/effect-studio.lua` exercises the real controls: navigation without mutation, waiting spells before layers, add/bind/unbind, live and preview-only triggers, native hover phase, depth across artwork, visibility/opacity, stable IDs after removal, pending/invalid input ownership, Save/Cancel, combat, close cleanup and a subsequent shipped v2 definition. It checks no native actor reloads or frame allocations during repeated spell responses.

`tests/studio-layout.lua` checks action bounds, native tab resizing, layer and spell pagination, display scaling, and preview viewport containment. `tests/quick-bind.lua` covers both binding directions, multi-selection and cancellation, selection versus highlights, independent triggers on one scene, overlapping auras and per-spell unbinding. `tools/test-crest-bakes.cjs` validates real Lua v1–v3 exports and compilation round trips.

Offline previews under `artifacts/studio-ui/` are generated from actual mock UI handlers and approved textures. They use substitute fonts/skins and cannot render the game's GPU particle models. In-game particle cropping, stacking, input feel and hover registration still require manual client review. No game UI automation or SavedVariables access occurred.
