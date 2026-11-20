# Restoration crown idle motion trial

The six source fans are layers 08–13 in `concepts/restoration-frame146/registered/`. Each has its own Tango render, fixed attachment point, phase offset and receiver-clipped contact shadow.

The motion guide uses seconds 8–10 of [Wind Blowing Leaves in Monochrome, One](https://scenoptica.com/footage/wind-blowing-leaves-in-monochrome-one.html) by Scenoptica, cropped to a leaf cluster, rotated 180 degrees, resized to 448 × 448 and muted. The [Scenoptica footage archive](https://scenoptica.com/footage.html) credits Joaquim Baeta and Lelly Marliana and licenses its content under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) except where otherwise indicated.

The Ludo motion-transfer request uses Tango, a two-second duration, 16 requested frames, 384-pixel sprite size, loop trimming, uniform frame bounds and smooth RGBA export. The local preview plays each frame for 125 ms.

From this folder, `python register_trial.py --remaining` bakes the five new tracks from their downloaded sheets. Each uses a single sweep played out and back with eased turnarounds. The approved layer 08 supplies the starting coverage mask. Open the parent preview and use **Detail** to inspect the whole crown or an individual attachment.
