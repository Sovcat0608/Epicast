"""Extract model motion for a cyclic, fixed-stem repaint of the green crown fan."""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from prepare import cv2
from prepare import H, LEAF, LAYERS, SLOT, VIDEO_CROP, W, registered, smoothstep

OUTPUT = Path(__file__).resolve().parent / "wave"


def read_frames(path):
    video = cv2.VideoCapture(str(path))
    try:
        frames = []
        while (sample := video.read())[0]:
            lab = cv2.cvtColor(sample[1], cv2.COLOR_BGR2LAB)
            frames.append(lab[:,:,0])
        return frames
    finally:
        video.release()


def extract():
    frames = read_frames(OUTPUT/"wan.mp4")
    if len(frames) < 33:
        raise ValueError("The Wan motion clip is incomplete")
    x, y, width, height = VIDEO_CROP
    row = LAYERS[LEAF]
    x_grid, y_grid = np.meshgrid(np.arange(W,dtype=np.float32),np.arange(H,dtype=np.float32))
    local_x, local_y = row["x"]-SLOT[0],row["y"]-SLOT[1]
    alpha = np.asarray(registered(LEAF,"paint",SLOT).getchannel("A"),dtype=np.float32)/255
    exposure = np.zeros(frames[0].shape,dtype=np.float32)
    exposure[y:y+height,x:x+width] = cv2.resize(
        alpha[local_y:local_y+row["h"],local_x:local_x+row["w"]],(width,height))
    anchor = (slice(484,524),slice(136,169))
    weight = cv2.GaussianBlur(exposure,(0,0),12)
    denominator = np.maximum(weight,.055)[:,:,None]
    radius = np.hypot(x_grid-(719-SLOT[0]),y_grid-343)
    stem_fade = smoothstep(21,103,radius)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    fields = []
    for index in range(0,len(frames),2):
        vectors = dis.calc(frames[0],frames[index],None)
        local_anchor = vectors[anchor][exposure[anchor]>.75]
        vectors -= np.median(local_anchor,axis=0)
        vectors = cv2.GaussianBlur(vectors*exposure[:,:,None],(0,0),12)/denominator
        native = cv2.resize(vectors[y:y+height,x:x+width],(row["w"],row["h"]))
        native *= (row["w"]/width,row["h"]/height)
        slot = cv2.remap(native,x_grid-local_x,y_grid-local_y,
                         cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)
        fields.append(slot*stem_fade[:,:,None])
    return x_grid,y_grid,alpha,np.asarray(fields,dtype=np.float32)


if __name__=="__main__":
    x,y,alpha,fields=extract()
    regions = [(189,107),(225,132),(278,77),(211,226),(272,205),(343,211)]
    for i,field in enumerate(fields):
        if i%2==0:
            motion=np.linalg.norm(field,axis=2)
            samples=[np.round(np.median(field[cy-9:cy+9,cx-9:cx+9],axis=(0,1)),1).tolist()
                     for cx,cy in regions]
            print(i*2,np.round(np.percentile(motion[alpha>.88],[50,90,99]),1).tolist(),samples)

