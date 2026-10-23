"""Rework of the inventory art, applied by export_textures.py on art/processed/inventory.png.

- Equipment frames: the 8+8 frames are redrawn bigger (the icons looked tiny next to the
  weapon slots).
- Tab row: the five tab plates move left, all the same plate (the raised "selected" plate is
  gone; the addon marks the active tab), and a square plate for the sort button follows them.
"""
from PIL import Image

# Tab row. A plain tab plate (the second one) is the template for every plate.
PLATE_SRC = (184, 701, 287, 743)
PLATE_W = PLATE_SRC[2] - PLATE_SRC[0]
PLATE_INSET = 4  # border around the clickable/text area
PLATES_X = [38, 147, 256, 365, 474]
SORT_BOX = (585, 701, 627, 743)
CLEAR = (30, 690, 614, 741)  # stone band under the old plates
STONE_SRC = (31, 690, 74, 741)  # clean stone from the left margin, tiled over CLEAR

# Equipment frames.
FRAME_SRC = (65, 106, 127, 168)
FRAME_SIZE = 68
FRAME_INSET = 3
FRAME_CX = (96.5, 591.5)
FRAME_CY0 = 137
FRAME_PITCH = 70.75
FRAME_ROWS = 8


def nine_slice(src, w, h, margin):
    """Resize keeping the borders: corners kept, edges and center stretched."""
    sw, sh = src.size
    m = margin
    out = Image.new("RGBA", (w, h))
    xs = [(0, m, 0, m), (m, sw - m, m, w - m), (sw - m, sw, w - m, w)]
    ys = [(0, m, 0, m), (m, sh - m, m, h - m), (sh - m, sh, h - m, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            piece = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS)
            out.paste(piece, (dx0, dy0))
    return out


def rework(img):
    img = img.convert("RGBA").copy()

    plate = img.crop(PLATE_SRC)
    stone = img.crop(STONE_SRC)
    x0, y0, x1, y1 = CLEAR
    flip = False
    for x in range(x0, x1, stone.width):
        tile = stone.transpose(Image.FLIP_LEFT_RIGHT) if flip else stone
        img.paste(tile.crop((0, 0, min(stone.width, x1 - x), y1 - y0)), (x, y0))
        flip = not flip
    for x in PLATES_X:
        img.paste(plate, (x, PLATE_SRC[1]))
    sx0, sy0, sx1, sy1 = SORT_BOX
    img.paste(nine_slice(plate, sx1 - sx0, sy1 - sy0, 10), (sx0, sy0))

    frame = img.crop(FRAME_SRC).resize((FRAME_SIZE, FRAME_SIZE), Image.LANCZOS)
    for cx in FRAME_CX:
        for i in range(FRAME_ROWS):
            cy = FRAME_CY0 + i * FRAME_PITCH
            img.paste(frame, (round(cx - FRAME_SIZE / 2), round(cy - FRAME_SIZE / 2)))
    return img
