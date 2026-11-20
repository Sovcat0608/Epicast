# Restoration feather idle

Open [the desktop preview](index.html). The assembled crest and the close-up share a frame clock. **UI size** displays the crest at 162 CSS pixels wide. **Static reference** displays the registered master pose. This prototype uses only local files.

## Motion and registration

The left bound feather cluster comes from the 19-layer [Restoration master](../../concepts/restoration-frame146/registration.json). The socket and first 78 design pixels stay fixed. A short flexible section at the quill lets the feather fan swing inward by 3.3 degrees. Both blades keep their painted shape through the swing. The moving feather receives the stationary bough and shoulder shadows in every pose.

Eight bitmap cels play at 4 fps. Four steps take the fan from rest to the peak at one second. Four steps retrace the arc to rest at two seconds. Five distinct poses form the cycle, with each extreme shown once. The small steps near the extremes ease the turnaround and the loop seam.

## WoW playback

WoW provides a native FlipBook animation that advances through a texture grid. WeakAuras Stop Motion also uses discrete bitmap frames for this kind of effect. For Epicast, load one sheet for an active clip, keep the same registered rectangle across poses, and let the animation group advance it. Start and stop the group with layer visibility. This avoids a per-feather Lua OnUpdate handler. [WoW FlipBook API](https://warcraft.wiki.gg/wiki/UIOBJECT_FlipBook) · [WeakAuras Stop Motion](https://github.com/WeakAuras/WeakAurasStopMotion)

[FeatherIdle.tga](FeatherIdle.tga) is a straight-alpha, uncompressed 32-bit 512 × 512 texture (1 MiB of texels). Its four columns and two rows run left to right, top to bottom. Each 128 × 256 cell represents a 256 × 512 rectangle at (8, 368) on the 1125 × 1400 crest. Position the texture behind the bough. The sheet includes the current fixed caster lighting. Moving a caster independently in the future Studio will require reevaluating those contacts.

The native group configuration for a registered texture is:

```lua
local idle = featherTexture:CreateAnimationGroup()
local flip = idle:CreateAnimation("FlipBook")
flip:SetFlipBookRows(2)
flip:SetFlipBookColumns(4)
flip:SetFlipBookFrames(8)
flip:SetDuration(2)
idle:SetLooping("REPEAT")
idle:Play()
```

The desktop review uses the higher-resolution [review strip](review.png) generated from the same poses. Its pixels include fixed layers crossing the feather. The TGA contains the feather alone for the game layer stack. The client playback snippet and texture have not been exercised in WoW.

For later Channel and Impact experiments, keep the same socket, padded cell rectangle and neutral pose in each sheet. Use spell events to switch states. Author entry and recovery cels at compatible poses and test interrupted channels and consecutive impacts before wiring up Studio controls.

## Rebuild

Run `python bake.py` with Pillow and NumPy. The bake reads the registered artwork and writes both frame sheets and the shared timing/placement metadata in this directory. It checks every generated frame for a fixed attachment and transparent outer gutters. [Static archive with per-file SHA-256 hashes](../../backups/static.zip)

