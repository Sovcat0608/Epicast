# Epicast Druid image-generation style

**User-approved Druid painting rule, 2026-11-16.** Read this file before Druid image generation, regeneration or editing. The user has discarded the Mage artwork and its art direction; this guide does not prescribe the Mage restart. A new Mage brief must come from the user. See [Mage reset](mage-artwork-reset.md). Current explicit user direction takes precedence. This rule governs painting style; it does not authorize changing existing approved artwork or integrating review concepts.

## Approved direction

When revising or animating approved artwork, carry the original pixel registration and paint into the brief. Follow the [mandatory placement and paint checks](segmented-crest-artwork.md#lock-placement-and-painting-fidelity) before using the result.

The user's exact direction:

> World of Warcraft–style hand-painted fantasy illustration: Bold, exaggerated silhouettes, chunky bevelled forms, rich saturated colours, stylised painterly textures, dramatic warm highlights and cool shadows. Simplify micro-details into confident brushstrokes, emphasise material definition and strong visual readability. Preserve the original composition and iconography while replacing photorealistic rendering with Blizzard-inspired painterly shading.

The accepted result is [Druid trio v8](../concepts/druid-specialization-trio/Druid-specializations-review-v8.png), SHA256 `4D592A779782DD20FA9B0BCBD38CE7B018613397EA53A53E0ABC77E4C76CBFC8`, integrated in beta.9. The user's preferred [painted reference](../concepts/druid-specialization-trio/references/v7/Warcraft-style-user-repaint.png), SHA256 `2C439D4478F405F82D7861581C7D8A32D910FFC02ADD345F12E8F628FB023162`, remains the direct finish benchmark. See the [element-by-element review](../concepts/druid-specialization-trio/reference-painting-review-v8.md) and [successful prompt](../concepts/druid-specialization-trio/prompt-v8.txt).

V6 was too realistic, muted and granular in game. V7 increased colour and smoothness but rounded the forms too much. **Do not use either as a rendering benchmark.** This rule supersedes earlier Epicast prompt language where “smooth sculpted” was interpreted as polished round forms or continuous airbrushed gradients.

## Form, paint and readability

- Lead with a bold, slightly exaggerated silhouette and one unmistakable focal motif. Preserve purposeful asymmetry and distinct character.
- Build chunky bevelled forms from broad angular planes. Organic forms can bend and taper, but their lit faces should have deliberate flat facets and irregular turns rather than inflated tube-like shading.
- Use large, confident, tapered brush shapes. Let brush direction describe material and growth. Broad strokes supply the texture; avoid covering every surface with tiny marks.
- Keep coherent light, midtone and shadow masses. Use rich local colour, warm selective highlights and cool hue-shifted shadows. Adapt this relationship to the theme: icy materials can remain predominantly cold.
- Leave quiet surfaces between details. Concentrate crisp accents around the focal motif, silhouette breaks, carvings, bevels and a few structural seams.
- Keep clean antialiased contours and precise shape design. Smoothness means clean, coherent painted shapes, not blur or polished CGI. Visible brushwork is desirable.
- Judge the design at its intended small UI size (current Druid crests approximately 162×216 UI units), as well as full source size. The primary motif and material groups must survive reduction.
- Keep emission local and restrained so material and carved shapes remain visible. Do not substitute bloom, sparks or fog for the artwork; future reactive effects need readable underlying surfaces.

## Material treatment

| Material | Required approach |
| --- | --- |
| Wood, roots, branches | Crooked angular bends, flatter lit faces, long broken wedge-like highlights and a few deep growth channels; avoid ropy tubes and dense bark flakes |
| Leather, cloth, parchment | Broad folds and layered edges, decisive seams, chunky page stacks and curled corners; no fine grain or tiny text texture |
| Metal and carved fittings | Thick bevels, distinct plane changes, broad coloured faces, dark carved recesses and selected sharp light edges; no chrome/PBR reflections |
| Stone, ivory, bone | Substantial facets, a few selected fractures or worn corners, broad shadow planes; no surface-wide crackle or mottled pebbles |
| Ice, crystals, gems | Large angular facets, clear light/dark and hue separation, limited internal marks and controlled luminous cores; avoid noisy refraction |
| Leaves and feathers | Broad folded/lance-shaped groups, confident taper and a few readable veins/barbs; patterns should follow the material's shape |
| Fur, hair, flames, water | Large directional tufts, locks, tongues or sweeps; grouped light/shadow, very few stray strands or particles |
| Runes and symbols | Legible integral carvings or painted marks, aligned with the form; avoid unrelated little icon badges and miniature filigree |

These are rendering rules, not a demand to add all materials. Do not transfer Druid leaves, horns, roots, paw marks or feathers into unrelated class designs merely because they appear in the benchmark.

## Avoid

Photorealism; granular or speckled microtexture; evenly scattered tiny chips/highlights; hair-by-hair rendering; pervasive fine vein networks; noisy miniature filigree; muddy brushwork; uniform saturation filters; blur masquerading as smoothness; inflated rounded forms; glossy plastic/CGI; generic mobile-game icon polish; flat vector art; dithering, pixel-art edges or crunchy sharpening.

## Reference and generation workflow

1. Use the imagegen skill and built-in image-generation tool. Inspect every supplied local image first.
2. Explicitly label each image's role: content/composition, material/iconography or painting-style reference. A source with an unsuitable finish may supply content only. The approved finish benchmark supplies brushwork and form treatment, not unrelated motifs.
3. For a new Druid design, research the relevant lore, visual language and associated spells from primary sources where possible. Record factual sources separately from artistic interpretation. Do not assume historical or retail spell mechanics apply to Forever.
4. Generate sister sets together in one render unless the user explicitly asks otherwise. Match finish, light direction, visual weight, overall size and framing, while varying each sister's construction and identity. They should not be simple recolours.
5. For asset sheets, use genuine transparent alpha, including interior gaps; clear spacing between sisters, outer margin and complete tips/tapers. No baked checkerboard, scenery, background, labels, watermark or cast shadow unless requested.
6. Preserve native output dimensions and alpha. Keep the exact source PNG, versioned concepts, prompt, reference provenance and verification metadata. Never upscale and call it native detail or overwrite earlier concepts casually.
7. Visually inspect the generated image for brush scale, angular construction, clear materials, retained motifs, clean contours and full silhouettes. If it drifts toward round glossy forms or noisy detail, correct that specific issue before presenting it as meeting the standard.
8. Keep source painting separate from deterministic runtime conversion. For shipped segments and their animation cels, use the [size-specific Lanczos2 + CAS standard](segmented-crest-artwork.md#bake-size-specific-runtime-textures). Do not programmatically repaint approved artwork during conversion.
9. Art-review requests deliver concepts only. Integrate, rebuild, install or publish when authorized by the user; do not infer those actions from artwork approval alone.

## Prompt foundation

Include the user's approved direction above or a faithful theme-specific adaptation. Add:

> Match the approved reference's actual painting method: broad angular planes, chunky bevels, visible large tapered brushstrokes, rich local colour, selective warm highlights and cool shadows. Keep quiet midtone regions between purposeful carved details. Preserve material definition and small-size readability. Smoothness means coherent clean paint shapes, not round glossy rendering or airbrushed gradients. No granular microtexture, dense tiny marks, plastic CGI, pixel art or bloom that hides the forms.

Then specify the current subject, reference roles, distinctive motifs, palette, composition and requested invariants. Do not let a long ingredient list crowd out the focal design or painting direction.

## Separable crest artwork

Apply the painting direction above to every isolated segment. Use the project-wide guide for grouping motifs, painting under overlaps, registering at a locked aspect ratio, linking contact shadows and exporting the editable crest and merged loose assets. [Segmented crest build guide](segmented-crest-artwork.md)
