"""Draw and package the left autumn crown as an editable Krita raster timeline.

Run in kritarunner with -s autumn_idle -f build and the prototype directory.
All drawing coordinates are in the approved 367 x 329 painting's coordinate space.
"""
from pathlib import Path
import traceback

from krita import Krita
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QBrush, QColor, QImage, QLinearGradient, QPainter, QPainterPath

PAD = 52
# Independent contour landmarks traced for each exposure. The first three
# points describe the broad leading blade (tip, ridge, outer notch). The
# fourth point is the upper blade's finer tip. Fold width is in paint pixels.
# The ridge leads the tip into the gust; it is nearly home on frame 11 while
# the tip is still travelling back. The upper blade settles one beat later.
POSES = [
    ((2,209),(15,166),(24,138),(217,23), 4.0),
    ((2,209),(15,165),(25,137),(217,23), 4.0),
    ((2,208),(16,163),(26,135),(217,23), 4.3),
    ((3,206),(17,161),(27,133),(217,22), 4.8),
    ((4,203),(18,159),(28,132),(218,21), 5.5),
    ((5,200),(18,158),(28,131),(219,19), 6.4),
    ((6,197),(19,158),(28,131),(221,17), 7.2),
    ((7,194),(19,158),(28,132),(222,15), 7.8),
    ((8,193),(19,159),(28,133),(223,14), 8.0),
    ((8,194),(18,161),(27,135),(224,14), 7.7),
    ((7,196),(17,163),(26,137),(224,15), 7.0),
    ((6,199),(16,165),(25,138),(223,16), 6.2),
    ((4,203),(15,167),(24,139),(222,18), 5.4),
    ((3,206),(14,168),(23,139),(220,20), 4.8),
    ((2,209),(14,167),(23,138),(218,22), 4.3),
    ((2,210),(15,166),(24,138),(217,24), 4.0),
]


def canvas(size):
    im = QImage(*size, QImage.Format_ARGB32)
    im.fill(Qt.transparent)
    return im


def wash(x0,y0,x1,y1, stops):
    grad = QLinearGradient(x0,y0,x1,y1)
    for position,color in stops:
        grad.setColorAt(position,QColor(color))
    return QBrush(grad)


def shape(painter, color, start, *lines):
    path = QPainterPath()
    path.moveTo(*start)
    for line in lines:
        if len(line) == 2:
            path.lineTo(*line)
        elif len(line) == 4:
            path.quadTo(*line)
        else:
            path.cubicTo(*line)
    path.closeSubpath()
    painter.fillPath(path,QBrush(color) if isinstance(color,QColor) else color)
    return path


def draw_tips(size, pose):
    im = canvas(size)
    p = QPainter(im)
    p.setRenderHint(QPainter.Antialiasing)
    p.translate(PAD,PAD)
    (tx,ty),(mx,my),(nx,ny),(ux,uy),fold = pose
    copper = wash(30,118,52,168,[(0,'#b72e08'),(.53,'#ed6103'),(.78,'#d94804'),(1,'#651506')])
    silhouette = shape(p,copper,(88,90),(67,92,50,101,36,114),(44,111,52,110),
        (44,115,nx+4,ny-6,nx-4,ny+1),(nx+4,ny-2),
        (mx-4,my-8,tx-4,ty-19,tx,ty),(tx+3,ty-17,mx+16,my+7,52,164),
        (71,157,85,160,91,156))
    p.save()
    p.setClipPath(silhouette)
    shape(p,QColor('#7e2007'),(tx,ty),(tx+4,ty-15,mx+16,my+7,72,149),
          (69,159,49,168,37,173),(tx+8,ty-7,tx,ty))
    shape(p,QColor('#9d2f05'),(tx+1,ty-2),(mx+5,my+5,35,160,54,151),
          (42,154,34,159),(mx,my+8,tx+3,ty-9,tx+1,ty-2))
    shape(p,wash(10,184,66,132,[(0,'#ae3607'),(.52,'#e66808'),(1,'#ffb826')]),
          (tx+1,ty-5),(mx-4,my+3,31,149,68,135),
          (48,146,38,153),(44,148,45,147),(mx+9,my+1,tx+4,ty-16,tx+1,ty-5))
    shape(p,QColor('#bd400a'),(nx-1,ny+10),(nx+4,ny+3,46,127,54,122),
          (46,131,35,140),(38,134),(nx+2,ny+8))
    shape(p,QColor('#f47c0c'),(mx-3,my+13),(mx+1,my+2,27,152,39,145),
          (30,152,mx+3,my+4,mx-3,my+13))
    shape(p,QColor('#e37210'),(tx+.6,ty-1),(tx+.2,ty-7,mx-4,my+14,mx+1,my+7),
          (mx-2,my+8+fold,tx+2,ty-6,tx+.6,ty-1))
    p.restore()

    gold = wash(236,1,241,27,[(0,'#bf5301'),(.36,'#ef8a02'),(.56,'#f9b91b'),(.63,'#a23a05'),(1,'#761e05')])
    upper = shape(p,gold,(274,3),(257,-2,241,1,234,6),
                  (ux+5,uy-11,ux+1,uy-5,ux,uy),
                  (ux+7,uy-9,241,12,253,28),(264,40,269,56,275,58))
    p.setClipPath(upper)
    shape(p,QColor('#8d2404'),(ux,uy),(ux+8,uy-12,240,11,259,25),
          (269,35,276,49),(261,47,249,29),(239,14,ux+6,uy-7,ux,uy))
    shape(p,QColor('#ffb61a'),(ux+1,uy-3),(ux+8,uy-12,236,6,248,7),
          (243,7,238,8),(245,8,254,11),(238,6,ux+4,uy-6,ux+1,uy-3))
    shape(p,QColor('#db5b03'),(236,6),(244,1,258,0,270,5),(259,3,252,4),
          (255,4,259,6),(246,3,241,5,236,6))
    p.end()
    return im


def fixed_plate(ref):
    plate = ref.copy()
    p = QPainter(plate)
    p.translate(PAD,PAD)
    p.setCompositionMode(QPainter.CompositionMode_DestinationOut)
    # Brush the junction into existing paint. The original bough-side surface
    # stays on the front layer, covering the full underlap of the moving cels.
    for left,right,top,bottom in [(-20,81,90,219),(196,268,-5,54)]:
        edge = QLinearGradient(right-23,0,right,0)
        edge.setColorAt(0,QColor(0,0,0,255))
        edge.setColorAt(1,QColor(0,0,0,0))
        p.fillRect(left,top,right-left,bottom-top,QBrush(edge))
    p.end()
    return plate


def raw_pixels(im):
    im = im.convertToFormat(QImage.Format_ARGB32)
    return im.constBits().asstring(im.sizeInBytes())


def add_paint(doc,name,im):
    node = doc.createNode(name,"paintlayer")
    doc.rootNode().addChildNode(node,None)
    assert node.setPixelData(raw_pixels(im),0,0,im.width(),im.height())
    return node


def author(base):
    out = base/"crown-krita"
    cache = base/"__pycache__"/"krita-trial"
    cache.mkdir(parents=True,exist_ok=True)
    src = QImage(str(base.parents[1]/"concepts/restoration-frame146/registered/08-paint.png"))
    assert not src.isNull()
    size = (src.width()+2*PAD,src.height()+2*PAD)
    ref = canvas(size)
    p = QPainter(ref)
    p.drawImage(PAD,PAD,src)
    p.end()
    plate = fixed_plate(ref)
    files = []
    for frame,pose in enumerate(POSES):
        f = cache/f"tip-{frame:02}.png"
        assert draw_tips(size,pose).save(str(f))
        files.append(str(f))

    app = Krita.instance()
    app.setBatchmode(True)
    doc = app.createDocument(*size,"Left autumn crown - Idle","RGBA","U8","",72)
    doc.setBatchmode(True)
    original = add_paint(doc,"Approved painting - reference",ref)
    original.setVisible(False)
    original.setLocked(True)
    for i, file in enumerate(files):
        cel = add_paint(doc,f"Cel {i:02}", QImage(file))
        if i == 0:
            cel.enableAnimation()
            moving = cel
        else:
            cel.setVisible(False)
    fixed = add_paint(doc,"Stem and inner fan",plate)
    fixed.setLocked(True)
    doc.setActiveNode(moving)
    doc.setFramesPerSecond(8)
    doc.setFullClipRangeStartTime(0)
    doc.setFullClipRangeEndTime(15)
    doc.setCurrentTime(0)
    doc.refreshProjection()
    doc.waitForDone()
    path = cache/"native-paint-stack.kra"
    assert doc.saveAs(str(path))
    doc.waitForDone()
    return str(path)


def verify(base):
    cache = base/"__pycache__"/"krita-trial"
    path = base/"crown-krita"/"Left autumn crown - Idle.kra"
    app = Krita.instance()
    app.setBatchmode(True)
    reopened = app.openDocument(str(cache/"registered-timeline.kra"))
    size = (reopened.width(),reopened.height())
    assert reopened.framesPerSecond()==8 and reopened.fullClipRangeEndTime()==15
    moving = next(n for n in reopened.rootNode().childNodes() if n.animated())
    assert all(moving.hasKeyframeAtTime(i) for i in range(16))
    reopened.setActiveNode(moving)
    assert reopened.saveAs(str(path))
    reopened.waitForDone()
    # Export the actual reopened timeline used by the preview.
    for i in range(16):
        reopened.setCurrentTime(i)
        reopened.waitForDone()
        reopened.refreshProjection()
        reopened.waitForDone()
        buf=bytes(reopened.pixelData(0,0,*size))
        img=QImage(buf,*size,4*size[0],QImage.Format_ARGB32)
        assert img.save(str(cache/f"cel-{i:02}.png"))
    return str(path)


def build(args):
    base = Path(args[0])
    status = base/"__pycache__"/"krita-build.txt"
    try:
        status.write_text(verify(base) if args[1:] == ["verify"] else author(base))
    except BaseException:
        status.write_text(traceback.format_exc())

