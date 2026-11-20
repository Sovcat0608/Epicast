"""Group Krita's native paint tiles into one editable raster animation channel."""
from pathlib import Path
from xml.dom import minidom
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent
CACHE = ROOT.parent/"__pycache__"/"krita-trial"


def pack():
    with ZipFile(CACHE/"native-paint-stack.kra") as src:
        doc = minidom.parseString(src.read("maindoc.xml"))
        leaves = {e.getAttribute("name"):e for e in doc.getElementsByTagName("layer")}
        leaves["Background"].setAttribute("visible","0")
        leaves["Background"].setAttribute("intimeline","0")
        lead = leaves["Cel 00"]
        lead.setAttribute("name","Wind - two blade tips")
        lead.setAttribute("intimeline","1")
        lead.setAttribute("selected","true")
        prefix = doc.getElementsByTagName("IMAGE")[0].getAttribute("name")+"/layers/"
        key_file = prefix+lead.getAttribute("keyframes")
        keys = minidom.parseString(src.read(key_file))
        channel = keys.createElement("channel")
        channel.setAttribute("name","content")
        keys.documentElement.appendChild(channel)
        for i in range(16):
            layer = leaves[f"Cel {i:02}"]
            key = keys.createElement("keyframe")
            key.setAttribute("time",str(i))
            key.setAttribute("frame",layer.getAttribute("filename"))
            key.setAttribute("color-label",str({0:3,7:2,11:4}.get(i,0)))
            offset = keys.createElement("offset")
            for k,v in (("type","point"),("x","0"),("y","0")):
                offset.setAttribute(k,v)
            key.appendChild(offset)
            channel.appendChild(key)
            if i:
                layer.parentNode.removeChild(layer)
        changes = {"maindoc.xml":doc.toxml(encoding="utf-8"),key_file:keys.toxml(encoding="utf-8")}
        with ZipFile(CACHE/"registered-timeline.kra","w") as dst:
            for entry in src.infolist():
                dst.writestr(entry,changes.get(entry.filename,src.read(entry)))


if __name__ == "__main__":
    pack()
