"""Bake a registered one-shot feather impact and its exact handoff to Idle."""
import json

import numpy as np
from PIL import Image, ImageFilter

from bake import (CLUSTERS, H, HERE, MASTER, TRACKS, W, contact_light, register,
                  wind_cel)
from channel import illuminate

FPS = 12
MOTION_RANGE = .5  # Fraction of the full stroke measured from the idle pose.
# A single outward stroke. The whole fan flashes at the apex and releases.
BEND = (.08, .69, 1., .94, .79, .60, .41, .25, .13, .055, .015, 0.)
FLASH = (.15, .82, 1., .83, .60, .38, .21, .105, .045, .015, 0., 0.)


def flash(cel, strength):
    if not strength:
        return cel
    rgba = np.array(cel)
    rgb = rgba[..., :3].astype(float) / 255
    # Keep the painted barbs legible at the brightest exposure.
    luma = rgb @ np.array([.21,.72,.07])
    color = np.array([.77,1.,.84]) + luma[...,None]*np.array([.21,0,.13])
    rgba[..., :3] = np.uint8(np.rint(255*(rgb + (color-rgb)*(.86*strength))))
    fan = Image.fromarray(rgba)
    coverage = cel.getchannel("A")
    halo = Image.new("RGBA", cel.size, (125,255,161))
    halo.putalpha(coverage.filter(ImageFilter.GaussianBlur(6)).point(lambda a: round(.55*strength*a)))
    halo.alpha_composite(fan)
    return halo


def build():
    assert len(BEND) == len(FLASH) == FPS
    clusters = []
    for cluster in CLUSTERS:
        # Double the width on the outward side so the hooked tips have room.
        pad = W if cluster.nib_orientation == 1 else 0
        width = 2*W
        slot_x, y = cluster.slot
        x = slot_x-pad
        cover = Image.open(MASTER/"Figma crest.png").crop((x,y,x+width,y+H))
        cover.paste(Image.open(HERE/(cluster.prefix+"fixed-front.png")), (pad,0))
        cover_name = cluster.prefix+"impact-cover.png"
        cover.save(HERE/cover_name)
        sheet = Image.open(HERE/cluster.sheet)
        light = np.pad(contact_light(cluster),((0,0),(pad,W-pad)),constant_values=1)
        clips = []
        for track, tip, crop in zip(TRACKS,cluster.tips,cluster.crops):
            name = cluster.prefix + track["name"]
            model = register(sheet.crop(crop),cluster,tip)
            radiant = illuminate(model,name,.35)
            # At idle time zero the delayed rear blade is still on its last cel.
            rest_index = (-track["delay"]//125) % 16
            rest_swing = -np.cos(2*np.pi*rest_index/16)
            idle_atlas = Image.open(HERE/(name+".png"))
            u, v = rest_index%4*W, rest_index//4*H
            rest = idle_atlas.crop((u,v,u+W,v+H))
            # Keep the seated quill fixed; ease into the moving section below the lip.
            lock = np.clip((np.arange(H)-cluster.pivot[1]-19)/14,0,1)
            hinge = Image.fromarray(np.tile(np.uint8(np.rint(255*lock*lock*(3-2*lock)))[:,None],(1,width)))
            fixed = Image.new("RGBA",(width,H))
            fixed.paste(rest,(pad,0))
            atlas = Image.new("RGBA",(4*width,3*H))
            game = Image.new("RGBA",(4*width//2,4*H//2))
            for i,(bend,glow) in enumerate(zip(BEND,FLASH)):
                cel = Image.new("RGBA",(width,H))
                if i == len(BEND)-1:
                    cel.paste(rest,(pad,0))
                else:
                    paint = Image.new("RGBa",cel.size)
                    paint.paste(Image.blend(model,radiant,glow),(pad,0))
                    outward = -cluster.nib_orientation
                    excursion = MOTION_RANGE * bend
                    settings = dict(track,
                        swing=(1-excursion)*track["swing"]*rest_swing + outward*4*excursion,
                        curl=outward*90*excursion)
                    cel = wind_cel(paint,cluster,tip,settings,i,light,swing=1,canvas_offset=(pad,0))
                    cel = Image.composite(cel,fixed,hinge)
                    cel = flash(cel,glow)
                alpha = cel.getchannel("A")
                x0,y0,x1,y1 = alpha.getbbox()
                assert 0 < x0 < x1 < width and 0 < y0 < y1 < H
                cx,cy = cluster.pivot
                for depth in range(19):
                    assert alpha.getpixel((pad+cx-cluster.nib_orientation*round(depth*.25),cy+depth)) > 200
                col,row = i%4,i//4
                atlas.paste(cel,(col*width,row*H))
                game.paste(cel.resize((width//2,H//2),Image.Resampling.LANCZOS),(col*width//2,row*H//2))
            filename = name+"-impact"
            atlas.save(HERE/(filename+".png"))
            game.save(HERE/(filename+".tga"))
            edges = [round(i*1000/FPS) for i in range(FPS+1)]
            clips.append(dict(sheet=filename+".png",delay=0,
                         frames=[dict(cel=i,ms=b-a) for i,(a,b) in enumerate(zip(edges,edges[1:]))]))
        clusters.append(dict(slot=[x,y,width,H],cover=cover_name,tracks=clips))
    data = dict(columns=4,fps=FPS,nextState="Idle",clusters=clusters)
    (HERE/"impact.js").write_text("const impact = "+json.dumps(data,indent=2)+";\n")
    print("Impact: verified nib attachments, clear gutters and registered return on four blades.")


if __name__ == "__main__":
    build()

