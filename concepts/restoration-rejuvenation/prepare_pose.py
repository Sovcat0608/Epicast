"""Register the 19 painted pieces in Frame 145 and bake receiver-clipped contact shadows."""
import csv
import json
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / 'artifacts/restoration-rejuvenation-pose'
REVISED = HERE.parent / 'restoration-maple-refinement'
REPLACEMENTS = {'Purple fan - left': 'maple-left', 'Purple fan - right': 'maple-right',
                'Feather cluster - right': 'feather-right'}


def clean_source(name, archive, rows):
    if name == 'Rejuvenation leaf':
        return Image.open(HERE / 'Leaf registered - S stalk.png').convert('RGBA')
    if name == 'Leaf and moss backboard':
        raw = Image.open(HERE / 'Purple backboard.png').convert('RGBA')
        alpha = raw.getchannel('A').point(lambda a: a if a >= 8 else 0)
        raw.putalpha(alpha)
        board = raw.crop(alpha.getbbox()).resize((802, 1262), Image.Resampling.LANCZOS)
        registered = Image.new('RGBA', (822, 1292))
        registered.paste(board, (8, 4))
        return registered
    tile = Image.open(BytesIO(archive.read(f'Paint/{rows[name]:02d} - {name}.png'))).convert('RGBA')
    if name in REPLACEMENTS:
        box = tile.getbbox()
        art = Image.open(REVISED / (REPLACEMENTS[name] + '-paint.png')).convert('RGBA')
        assert art.size == (box[2] - box[0], box[3] - box[1])
        tile = Image.new('RGBA', tile.size)
        tile.paste(art, box[:2])
    return tile


def registered_tile(source, part):
    width, height = part['w'] * 2, part['h'] * 2
    if part['fit'] == 'CROP':
        transform = np.array(part['crop']) * [[source.width / width, source.width / height, source.width],
                                               [source.height / width, source.height / height, source.height]]
        return source.transform((width, height), Image.Transform.AFFINE, tuple(transform.flat), Image.Resampling.BICUBIC)
    scale = (min if part['fit'] == 'FIT' else max)(width / source.width, height / source.height)
    art = source.resize((round(scale * source.width), round(scale * source.height)), Image.Resampling.LANCZOS)
    result = Image.new('RGBA', (width, height))
    result.alpha_composite(art, ((width - art.width) // 2, (height - art.height) // 2))
    return result


def contact_field(alpha, part):
    def blur(dx, dy, radius):
        shifted = Image.new('L', alpha.size)
        shifted.paste(alpha, (dx, dy))
        return np.asarray(shifted.filter(ImageFilter.GaussianBlur(radius)), dtype=float) / 255
    # All distances are measured in frame pixels, so light direction stays consistent across rotated parts.
    radius = 12.5 if part == 'Rejuvenation leaf' else 7
    tight = .36 * blur(1, 3, 2.5)
    soft = (.38 if part in ('Boughs, wraps and jewelry', 'Rejuvenation leaf') else .29) * blur(2, 6, radius)
    return Image.fromarray(np.rint(255 * (1 - (1 - tight) * (1 - soft))).astype('uint8'))


def white_veined_maple(slot, side):
    """Match blade height and stalk attachment within the original rotated slot."""
    source = Image.open(REVISED / f'maple-{side}-white-veins.png').convert('RGBA')
    def bounds(image):
        return image.getchannel('A').point(lambda a: 255 if a > 10 else 0).getbbox()
    left, top, right, bottom = bounds(slot)
    x, y, end_x, end_y = bounds(source)
    scale = 2 * (bottom - top) / (end_y - y)
    resized = source.resize((round(source.width * scale), round(source.height * scale)), Image.Resampling.LANCZOS)
    offset_x = 2 * right - scale * end_x if side == 'left' else 2 * left - scale * x
    tile = Image.new('RGBA', (2 * slot.width, 2 * slot.height))
    tile.alpha_composite(resized, (round(offset_x), round(2 * top - scale * y)))
    return tile


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    pose = json.loads((HERE / 'figma-pose.json').read_text())
    size = tuple(pose['size'])
    result = Image.new('RGBA', size)
    coverage = Image.new('RGBA', size)
    with ZipFile(HERE.parent / 'restoration-shadow-playground/Restoration-contact-shadow-assets.zip') as archive:
        rows = {r['part']: int(r['back_to_front']) for r in csv.DictReader(archive.read('Rest positions.csv').decode().splitlines())}
        for index, part in enumerate(pose['parts']):
            tile = registered_tile(clean_source(part['part'], archive, rows), part)
            if part['part'] in ('Purple fan - left', 'Purple fan - right'):
                tile = white_veined_maple(tile, part['part'].split()[-1])
            tile.save(OUT / f'{index}-paint.png')
            inverse = np.linalg.inv(np.vstack((part['matrix'], [0, 0, 1])))[:2]
            pixels_per_unit = tile.width / part['w']
            paint = tile.transform(size, Image.Transform.AFFINE, tuple((pixels_per_unit * inverse).flat), Image.Resampling.BICUBIC)
            alpha = paint.getchannel('A')
            field = contact_field(alpha, part['part'])
            box = field.getbbox()
            assert box and alpha.getbbox()
            shadow = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]))
            shadow.putalpha(field.crop(box))
            shadow.save(OUT / f'{index}-field.png')
            part.update(field=box, bounds=alpha.getbbox())
            shaded = ImageChops.multiply(result.convert('RGB'), ImageChops.invert(field).convert('RGB')).convert('RGBA')
            shaded.putalpha(result.getchannel('A'))
            result = Image.alpha_composite(shaded, paint)
            coverage.alpha_composite(paint)
    assert result.getchannel('A').tobytes() == coverage.getchannel('A').tobytes()
    box = result.getbbox()
    assert 0 < box[0] < box[2] < size[0] and 0 < box[1] < box[3] < size[1]
    result.save(OUT / 'frame.png')
    (OUT / 'layers.json').write_text(json.dumps(pose['parts']))
    art = result.crop(box)
    art.thumbnail((628, 805), Image.Resampling.LANCZOS)
    registered = Image.new('RGBA', (660, 880))
    registered.alpha_composite(art, ((660 - art.width) // 2, round(444.5 - art.height / 2)))
    registered.save(HERE / 'Restoration registered.png', optimize=True)
    print('Visible bounds:', registered.getchannel('A').point(lambda a: 255 if a >= 8 else 0).getbbox())


if __name__ == '__main__':
    build()
