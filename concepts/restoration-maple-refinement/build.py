"""Register the four repainted pieces inside the existing Figma asset bounds."""
from pathlib import Path
import sys

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'restoration-independent-v2'))
import register as reg


def trim_source(image):
    image = image.convert('RGBA')
    image.putalpha(image.getchannel('A').point(lambda a: max(0, min(255, (a - 32) * 255 / 217))))
    return image.crop(image.getbbox())


def alpha_rect(paint, field):
    return ImageChops.lighter(paint.getchannel('A'), field).getbbox()


def save(image, name):
    image.save(HERE / (name + '.png'), optimize=True)


def revise(group, replacements):
    old_group_box = reg.paint[group].getbbox()
    old_field_box = reg.fields[group].getbbox()
    for i, source, anchor, name in replacements:
        old = reg.pieces[group][i]
        x, y, r, b = old.getbbox()
        old_merged_box = alpha_rect(old, reg.piece_shadow(group, old))
        # Preserve the attachment at the cuff or medallion, with uniform fit.
        factor = min((r - x) / source.width, (b - y) / source.height)
        piece = reg.scale_piece(source, max(1, int(source.width * factor + 1e-6)))
        px = x + round((r - x - piece.width) * anchor)
        new = reg.place(piece, (px, y))
        field = reg.piece_shadow(group, new)
        reg.pieces[group][i] = new
        assert new.getbbox()[3] <= b
        save(new.crop((x, y, r, b)), name + '-paint')
        merged = reg.clear()
        merged.putalpha(field)
        merged.alpha_composite(new)
        save(merged.crop(old_merged_box), name + '-merged')

    clean = reg.clear()
    for piece in reg.pieces[group]:
        clean.alpha_composite(piece)
    reg.paint[group] = clean
    reg.fields[group] = reg.piece_shadow(group, clean)
    shade = reg.clear()
    shade.putalpha(reg.fields[group])
    save(clean.crop(old_group_box), group + '-layer')
    save(shade.crop(old_field_box), group + '-field')


if __name__ == '__main__':
    leaves = Image.open(HERE / 'Maple leaf source.png')
    # Empty gutters separate the three complete paintings.
    cuts = [0, 718, 1250, leaves.width]
    maple = [trim_source(leaves.crop((x, 0, r, leaves.height))) for x, r in zip(cuts, cuts[1:])]
    revise('purple', [(0, maple[0], 1, 'maple-left'), (1, maple[1], .5, 'maple-basal'),
                      (2, maple[2], 0, 'maple-right')])
    feather = trim_source(Image.open(HERE / 'Two feather source.png'))
    revise('feathers', [(1, feather, 0, 'feather-right')])
    save(reg.render(), 'Restoration registered master')
