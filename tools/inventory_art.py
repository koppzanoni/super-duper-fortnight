"""Rework of the inventory art, applied by export_textures.py on art/processed/inventory.png.

- Equipment frames: the 8+8 frames are redrawn bigger (the icons looked tiny next to the
  weapon slots); the 3 weapon frames shrink to the same size, freeing room for the 3D model.
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

# Equipment frames (the column fits 8 of them between y 102 and 668).
FRAME_SRC = (65, 106, 127, 168)
FRAME_SIZE = 69
FRAME_INSET = 2
FRAME_CX = (96.5, 591.5)
FRAME_CY0 = 136.5
FRAME_PITCH = 70.75
FRAME_ROWS = 8

# Weapon frames: same frame as the equipment, bottoms where the old 100px frames ended.
WEAPON_CX = (232, 344, 456)
WEAPON_BOTTOM = 658  # just above the panel's inner bottom (662), level with the last equipment row
WEAPON_CLEAR = (178, 512, 512, 660)  # the old frames, covered with plain stone from above
WEAPON_STONE_DY = 200

# Bag grid: the slot frames are removed (they did not scroll with the items); each item button
# draws its own frame, cut from the original art. The area keeps a darker stone.
GRID_CLEAR = (36, 750, 614, 1216)
GRID_SLOT_SRC = (42, 757, 107, 827)
GRID_STONE_DARKEN = 0.55

# Extra textures cut from the reworked art for the addon's own panels and buttons.
STONE_TILE = (200, 150, 456, 406)  # plain stone of the model panel, 256x256
# One plate of the reworked row (they moved), without the rail under it.
PLATE_TEX_SRC = (PLATES_X[1], 702, PLATES_X[1] + PLATE_W, 741)
PLATE_SIZE = (128, 32)  # about the buttons' shape, so it scales evenly


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

    gx0, gy0, gx1, gy1 = GRID_CLEAR
    dark = Image.eval(img.crop(STONE_TILE).convert("RGB"), lambda v: int(v * GRID_STONE_DARKEN)).convert("RGBA")
    flip = False
    for y in range(gy0, gy1, dark.height):
        for x in range(gx0, gx1, dark.width):
            tile = dark.transpose(Image.FLIP_LEFT_RIGHT) if flip else dark
            img.paste(tile.crop((0, 0, min(dark.width, gx1 - x), min(dark.height, gy1 - y))), (x, y))
            flip = not flip

    wx0, wy0, wx1, wy1 = WEAPON_CLEAR
    img.paste(img.crop((wx0, wy0 - WEAPON_STONE_DY, wx1, wy1 - WEAPON_STONE_DY)), (wx0, wy0))
    for cx in WEAPON_CX:
        img.paste(frame, (round(cx - FRAME_SIZE / 2), WEAPON_BOTTOM - FRAME_SIZE))
    return img


def pieces(reworked, original):
    """Textures for the addon's own widgets (from the reworked art, the bag slot from the original)."""
    plate = nine_slice(reworked.crop(PLATE_TEX_SRC), PLATE_SIZE[0], PLATE_SIZE[1], 8)
    return {"stone_tile": reworked.crop(STONE_TILE), "plate": plate, "inventory_wing": wing(reworked),
            "bag_slot": original.convert("RGBA").crop(GRID_SLOT_SRC)}


# Stats wing: a narrow panel docked left of the window, built from the window's own frame (the
# left strip with its corners and pillar + the right strip), stone inside, a title plate on top.
# Its right pillar hides under the window's left pillar (WING_OVERLAP), so the two read as one.
WING_W = 400
WING_STRIP = WING_W // 2
WING_OVERLAP = 28
WING_INNER = (28, 88, WING_W - 28, 1306)
TITLE_SRC = (187, 31, 502, 70)
WING_TITLE = (40, 33, WING_W - WING_OVERLAP - 40, 70)


def wing(reworked):
    w, h = reworked.size
    out = Image.new("RGBA", (WING_W, h))
    out.paste(reworked.crop((0, 0, WING_STRIP, h)), (0, 0))
    out.paste(reworked.crop((w - (WING_W - WING_STRIP), 0, w, h)), (WING_STRIP, 0))

    stone = reworked.crop(STONE_TILE)
    x0, y0, x1, y1 = WING_INNER
    flip_x = False
    for x in range(x0, x1, stone.width):
        flip_y = False
        for y in range(y0, y1, stone.height):
            tile = stone
            if flip_x:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            if flip_y:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
            out.paste(tile.crop((0, 0, min(stone.width, x1 - x), min(stone.height, y1 - y))), (x, y))
            flip_y = not flip_y
        flip_x = not flip_x

    # Soft inner shadow where the stone meets the frame.
    shadow = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    px = shadow.load()
    for y in range(y1 - y0):
        for x in range(x1 - x0):
            d = min(x, y, x1 - x0 - 1 - x, y1 - y0 - 1 - y)
            if d < 10:
                px[x, y] = (0, 0, 0, int(150 * (1 - d / 10)))
    out.alpha_composite(shadow, (x0, y0))

    tx0, ty0, tx1, ty1 = WING_TITLE
    out.paste(reworked.crop(TITLE_SRC).resize((tx1 - tx0, ty1 - ty0), Image.LANCZOS), (tx0, ty0))
    return out
