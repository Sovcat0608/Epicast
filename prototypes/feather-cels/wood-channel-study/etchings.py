"""Registration of the four carved grooves in the original wood paintings."""
from math import dist

from PIL import Image, ImageDraw

RUNES = (
    (
        ((115, 39), (131, 40), (142, 44), (155, 47), (162, 52), (174, 49),
         (184, 56), (192, 53), (200, 54), (198, 47), (224, 54), (240, 52)),
        ((169, 125), (181, 119), (191, 113), (195, 106), (203, 110),
         (200, 115), (211, 111), (226, 111)),
    ),
    (
        ((92, 63), (114, 57), (132, 58), (140, 52), (162, 55), (177, 47),
         (184, 51), (201, 47), (217, 45)),
        ((65, 118), (83, 116), (101, 112), (110, 110), (119, 105),
         (124, 107), (135, 101), (147, 105)),
    ),
)
POSITIONS = ((36, 182), (407, 182))


def mask(size, side, charge=1.0, width=3):
    scale = 3
    full = Image.new("L", (size[0] * scale, size[1] * scale))
    draw = ImageDraw.Draw(full)
    for rune in RUNES[side]:
        # The first light starts close to the crest and travels to the outside.
        if side == 0:
            rune = rune[::-1]
        pairs = list(zip(rune, rune[1:]))
        remaining = charge * sum(dist(a, b) for a, b in pairs)
        points = [rune[0]]
        for a, b in pairs:
            if remaining <= 0:
                break
            length = dist(a, b)
            fraction = min(1, remaining / length)
            points.append((a[0] + (b[0] - a[0]) * fraction, a[1] + (b[1] - a[1]) * fraction))
            remaining -= length
        if len(points) > 1:
            draw.line([(round(x * scale), round(y * scale)) for x, y in points],
                      fill=255, width=round(width * scale), joint="curve")
    return full.resize(size, Image.Resampling.LANCZOS)
