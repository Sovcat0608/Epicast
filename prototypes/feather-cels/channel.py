"""Bake the half-second channel loop using the approved idle registration."""
import json

import numpy as np
from PIL import Image

from bake import (CLUSTERS, H, HERE, TRACKS, W, contact_light, register,
                  wind_cel)

FPS, FRAMES, COLUMNS = 12, 6, 4

# Traces follow the pale painted rachis at 32-design-pixel intervals, from y=128.
SHAFT_X = {
    "rear": [180, 175, 169, 163, 156, 146, 137, 132, 135],
    "front": [181, 165, 148, 129, 110, 92, 76, 62, 50, 43, 42],
    "right-rear": [74, 89, 100, 108, 114, 117, 119, 118],
    "right-front": [75, 94, 115, 138, 161, 182, 197, 207, 212, 211],
}
# Both shafts follow the same swing. The rear follows within one frame.
SHUFFLE = (-.48, .68, 1.0, .25, -.67, -.92)
REAR_DELAY_MS = 30


def illuminate(model, name, phase):
    rgba = np.array(model.convert("RGBA"))
    yy, xx = np.indices((H, W), dtype=float)
    trace = SHAFT_X[name]
    rows = 128 + 32*np.arange(len(trace))
    # Smooth the trace tangent through its sample points.
    shaft_x = sum(np.interp(yy + delta, rows, trace) for delta in (-3, 0, 3)) / 3
    across = xx - shaft_x
    distance = np.abs(across)
    reach = np.clip((yy - 128) / (rows[-1] - 128), 0, 1)
    # Barbs sweep towards the tip as they fan away from the shaft.
    root_y = yy - .96*distance - .012*distance**2 + np.sign(across)*4
    spacing = 23 + 4*reach
    rib_phase = root_y / spacing + .16*np.sin(root_y / 43)
    ribs = (.5 + .5*np.cos(2*np.pi*rib_phase))**3
    arrival = .55*reach + .012*distance
    pulse = (.5 + .5*np.cos(2*np.pi*(phase-arrival)))**2
    spine = np.exp(-.5*(distance/2.5)**2)
    spill = np.exp(-distance/14)
    fibers = ribs * (1-np.exp(-distance/4)) * np.exp(-distance/46)
    # Preserve original barb shading, particularly the dark gaps in the fan.
    rgb = rgba[..., :3].astype(float)/255
    luma = rgb @ np.array([.21,.72,.07])
    intensity = ((.54*spine + .18*spill)*(.60 + .40*pulse)
                 + (.40*spill + fibers*(.52+.48*luma))*pulse)
    tint = np.array([.37, 1., .49]) + spine[...,None]*np.array([.52,0,.18])
    emitted = 1 - np.exp(-2.4*intensity[...,None]*tint)
    # Screen light into the painted color without changing silhouette coverage.
    rgba[..., :3] = np.uint8(np.rint(255*(rgb + (1-rgb)*emitted)))
    return Image.fromarray(rgba).convert("RGBa")


def build():
    clusters = []
    for cluster in CLUSTERS:
        sheet = Image.open(HERE/cluster.sheet)
        light = contact_light(cluster)
        clips = []
        for track, tip, crop in zip(TRACKS, cluster.tips, cluster.crops):
            name = cluster.prefix + track["name"]
            model = register(sheet.crop(crop), cluster, tip)
            atlas = Image.new("RGBA", (COLUMNS*W, 2*H))
            game = Image.new("RGBA", (COLUMNS*128, 512))
            settings = dict(track, swing=3.4, curl=.9)
            for i, swing in enumerate(SHUFFLE):
                lit = illuminate(model, name, i/FRAMES)
                cel = wind_cel(lit, cluster, tip, settings, i, light, swing=swing)
                alpha = cel.getchannel("A")
                x0, y0, x1, y1 = alpha.getbbox()
                assert 0 < x0 < x1 < W and 0 < y0 < y1 < H
                cx, cy = cluster.pivot
                for depth in range(19):
                    assert alpha.getpixel((cx-cluster.nib_orientation*round(depth*.25),cy+depth)) > 200
                col, row = i%COLUMNS, i//COLUMNS
                atlas.paste(cel,(col*W,row*H))
                game.paste(cel.resize((128,256),Image.Resampling.LANCZOS),(col*128,row*256))
            filename = name + "-channel"
            atlas.save(HERE/(filename+".png"))
            game.save(HERE/(filename+".tga"))
            # Round boundaries so integer frame holds sum to exactly 500 ms.
            edges = [round(i*1000/FPS) for i in range(FRAMES+1)]
            delay = REAR_DELAY_MS if track["name"] == "rear" else 0
            clips.append(dict(sheet=filename+".png", delay=delay,
                         frames=[dict(cel=i,ms=edges[i+1]-edges[i]) for i in range(FRAMES)]))
        clusters.append(dict(slot=[*cluster.slot,W,H],pivot=cluster.pivot,
                             cover=cluster.prefix+"fixed-front.png",tracks=clips))
    data = dict(columns=COLUMNS,fps=FPS,clusters=clusters)
    (HERE/"channel.js").write_text("const channel = "+json.dumps(data,indent=2)+";\n")
    print(f"Channel: both clusters, {FRAMES} cels per blade at {FPS} fps.")


if __name__ == "__main__":
    build()

