"""Contact fields for the registered Restoration master."""
import numpy as np
from PIL import Image, ImageFilter

# Profiles are measured in pixels of the 1125 x 1400 rest pose. Zone centres
# are local to the caster so the wider shade travels with the corresponding joint.
def contact_field(alpha, name, x, y):
    profiles = {
        'Boughs, printed wraps, charms and treant': (
            (2, 5, 3, .70), (4, 10, 8, .44), (7, 18, 19, .38),
            [(130, 230, 125, 138), (684, 235, 128, 140),
             (133, 527, 109, 139), (686, 528, 109, 139),
             (407, 814, 166, 132), (413, 933, 110, 109)]),
        'Carved sprout fork': ((1, 4, 3, .65), (3, 9, 7, .43),
                               (4, 13, 14, .28), [(185, 159, 157, 115)]),
        'Forehead shoot': ((1, 3, 2, .61), (2, 6, 5, .35),
                           (3, 9, 10, .22), [(76, 56, 56, 38)]),
        'Ivory crown glyph': ((1, 3, 1.8, .62), (2, 5, 3.5, .31),
                              (2, 7, 6, .12), []),
        'Rejuvenation leaf': ((1, 3, 2.6, .46), (3, 7, 6, .27),
                              (4, 11, 10, .16), []),
    }
    key = name.lower()
    if 'cheek' in key or 'inner crown' in key or 'shoulder' in key or 'autumn crown' in key or 'green crown' in key:
        typical = ((1, 3, 2.3, .59), (3, 7, 6, .37), (4, 12, 12, .22), [])
    elif 'slats' in key:
        typical = ((1, 4, 2.5, .63), (3, 8, 6, .39), (4, 13, 12, .22), [])
    else:
        typical = ((1, 3, 2.3, .51), (2, 6, 6, .34), (4, 10, 13, .20), [])
    tight, middle, broad, zones = profiles.get(name, typical)
    transmission = np.ones((alpha.height, alpha.width), np.float32)
    for dx, dy, radius, weight in (tight, middle, broad):
        shifted = Image.new('L', alpha.size)
        shifted.paste(alpha, (dx, dy))
        band = np.asarray(shifted.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255
        if zones and radius == broad[2]:
            yy, xx = np.ogrid[:alpha.height, :alpha.width]
            focus = np.zeros_like(band)
            for cx, cy, rx, ry in zones:
                np.maximum(focus, np.exp(-.5 * (((xx-x-cx)/rx)**2 + ((yy-y-cy)/ry)**2)), out=focus)
            band *= .30 + .70 * focus
        transmission *= 1 - weight * band
    if name == 'Boughs, printed wraps, charms and treant':
        # Sample the pointed jaw itself. Project its silhouette down over the
        # recessed roots, keeping a soft opening on each side of the chin.
        yy, xx = np.ogrid[:alpha.height, :alpha.width]
        focus = np.exp(-.5 * (((xx-x-410)/64)**2 + ((yy-y-955)/58)**2))
        for dx, dy, radius, strength in [(2, 25, 6, .64), (3, 43, 12, .79), (4, 54, 21, .46)]:
            displaced = Image.new('L', alpha.size)
            displaced.paste(alpha, (dx,dy))
            jaw = np.asarray(displaced.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)/255
            transmission *= 1 - strength * focus * jaw
    return Image.fromarray(np.rint(255 * (1 - transmission)).astype(np.uint8))
