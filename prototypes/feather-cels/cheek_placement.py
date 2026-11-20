"""Restoration preview registration and receiver-clipped contact shadows."""
import sys
import numpy as np
from PIL import Image, ImageFilter

from bake import HERE, LAYERS, MASTER
from crown import leaf_contact, registered as source_registered, shade

OUTPUT = HERE/"cheek-layout"
CREST_FILE = OUTPUT/"crest.webp"
HIDDEN = OUTPUT/"hidden"
# Pixel offsets on the 1125 x 1400 reference, aligned around the treant's eyes.
OFFSETS = {6: (-19, 16), 7: (20, 23)}
# The carved sprout fork moves with its cast shadow, independently of the leaves.
PLACEMENT = {**OFFSETS, 16: (0, 30)}
ZONE = (230, 529, 676, 870)


def registered(index, kind, slot):
    dx,dy = PLACEMENT.get(index,(0,0))
    return source_registered(index,kind,(slot[0]-dx,slot[1]-dy,*slot[2:]))


def premult(image):
    data=np.asarray(image,dtype=np.float32)/255
    data[:,:,:3] *= data[:,:,3:4]
    return data


def rgba(data):
    a=np.clip(data[:,:,3:4],0,1)
    color=np.clip(data[:,:,:3],0,a)
    np.divide(color,a,out=color,where=a>0)
    return Image.fromarray(np.rint(255*np.concatenate((color,a),axis=2)).astype(np.uint8))


def cheek_contact(front, slot, index):
    # Tight contact under the brow and charms, opening out gently across each
    # shifted fan. The source field follows the face in its animation cels.
    w,h=front.size
    y,x=np.ogrid[slot[1]:slot[1]+h,slot[0]:slot[0]+w]
    cheek_x=452 if index==6 else 704
    focus=np.exp(-.5*(((x-cheek_x)/70)**2+((y-958)/67)**2))
    soft=front.filter(ImageFilter.GaussianBlur(7))
    return .34*focus*np.asarray(soft,dtype=np.float32)/255


def composite(paints, fields, slot, placed=True):
    w,h=slot[2:]
    result=Image.new("RGBA",(w,h))
    for index,row in enumerate(LAYERS):
        if not paints[index].getbbox():
            continue
        light=np.ones((h,w),dtype=np.float32)
        for caster in row["casters"]:
            strength=row["contactStrength"].get(LAYERS[caster]["name"],1)
            light*=1-strength*np.asarray(fields[caster],dtype=np.float32)/255
        if placed and index in OFFSETS:
            light*=1-cheek_contact(fields[18],slot,index)
        filtered=Image.fromarray(np.rint(light*255).astype(np.uint8)).convert("RGB")
        result.alpha_composite(shade(paints[index],filtered))
    return result


def registered_stack(slot, placement=True, hide_cheeks=False):
    register=registered if placement else source_registered
    paints=[register(i,"paint",slot) for i in range(len(LAYERS))]
    fields=[register(i,"field",slot).getchannel("A") for i in range(len(LAYERS))]
    for i in OFFSETS:
        if hide_cheeks:
            paints[i]=Image.new("RGBA",slot[2:])
            fields[i]=Image.new("L",slot[2:])
        elif placement:
            fields[i]=leaf_contact(paints[i].getchannel("A")).getchannel("A")
    return paints,fields


def crest_path(hide_cheeks):
    return HIDDEN/"crest.webp" if hide_cheeks else CREST_FILE


def make_crest(hide_cheeks=False):
    path=crest_path(hide_cheeks)
    path.parent.mkdir(parents=True,exist_ok=True)
    before=composite(*registered_stack(ZONE,False),ZONE,False)
    after=composite(*registered_stack(ZONE,hide_cheeks=hide_cheeks),ZONE)
    difference=np.max(np.abs(premult(after)-premult(before)),axis=2)
    # Recompose the moved shapes from their full paint and receivers. Feather
    # the change only outside its actual support to retain the Figma export.
    support=Image.fromarray((difference>1/255).astype(np.uint8)*255)
    assert support.getbbox() is not None
    soft=support.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(2.5))
    mask=Image.fromarray(np.maximum(np.asarray(support),np.asarray(soft)))
    original=Image.open(MASTER/"Figma crest.png").convert("RGBA")
    x,y,w,h=ZONE
    old=original.crop((x,y,x+w,y+h))
    weight=np.asarray(mask,dtype=np.float32)[:,:,None]/255
    moved=rgba(premult(old)*(1-weight)+premult(after)*weight)
    original.paste(moved,(x,y))
    original.save(path,lossless=True)


if __name__=="__main__":
    make_crest("--hide-cheeks" in sys.argv)

