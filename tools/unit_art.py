"""Unit frame art (target, focus, target-of-target, pet, and later the party): the first frame of
the Meshy sheet art/meshy/party_free_b.png (a round portrait ring with a small dragon, a name
plate, a health groove and a mana groove), keyed and trimmed.

The name plate and the bar grooves are holes in the art: they get a dark backing so the world
never shows behind a bar that is not full. The portrait ring's opening stays empty (the portrait
fills it). HOLES are the openings, in px of the processed art; Data.UNIT places regions in them.
Used by export_textures.py for the "unit_frame" texture.

The player cast bar (art/meshy/castbar_free.png, same style) is processed the same way: its
round icon socket stays open, its progress groove gets the dark backing.

Usage: python tools/unit_art.py   (writes art/processed/unit_frame.png and castbar_b.png)
"""
import pathlib

import numpy as np
from PIL import Image

from process_art import key_magenta

ROOT = pathlib.Path(__file__).resolve().parent.parent
MESHY = ROOT / "art" / "meshy" / "party_free_b.png"
OUT = ROOT / "art" / "processed" / "unit_frame.png"
# The player cast bar in the same style: a round icon socket and the progress groove.
CASTBAR_MESHY = ROOT / "art" / "meshy" / "castbar_free.png"
CASTBAR_OUT = ROOT / "art" / "processed" / "castbar_b.png"
BACKING = (14, 11, 10, 235)


def holes(a):
    """Enclosed see-through openings of the art, as (x, y, w, h), left to right then top to bottom."""
    from scipy import ndimage
    labels, n = ndimage.label(a[..., 3] < 128)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    found = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if i in border or sl is None:
            continue
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if w > 40 and h > 15:
            found.append((sl[1].start, sl[0].start, w, h))
    return sorted(found)


def trimmed(meshy=MESHY):
    """The top frame of the sheet, keyed and trimmed, holes still open."""
    img = key_magenta(Image.open(meshy))
    a = np.asarray(img)
    rows = np.nonzero((a[..., 3] > 40).sum(axis=1) > 20)[0]
    gaps = np.nonzero(np.diff(rows) > 1)[0]
    end = rows[gaps[0]] + 1 if len(gaps) else rows[-1] + 1
    img = img.crop((0, int(rows[0]), img.width, int(end)))
    return img.crop(img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())


def fill(img):
    """Dark backing in every hole but the portrait's (the tallest opening); the magenta tint left
    on the rims removed."""
    from scipy import ndimage
    a = np.asarray(img).astype(np.float32)
    labels, _ = ndimage.label(a[..., 3] < 128)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    px, py, pw, ph = max(holes(a.astype(np.uint8)), key=lambda b: b[3])
    portrait = labels[py + ph // 2, px + pw // 2]
    inside = (labels > 0) & ~np.isin(labels, list(border)) & (labels != portrait)
    inside = ndimage.binary_dilation(inside, iterations=2) & (a[..., 3] < 255)
    k = a[..., 3:] / 255
    back = np.array(BACKING, np.float32)
    a[inside, :3] = a[inside, :3] * k[inside] + back[:3] * (1 - k[inside])
    a[inside, 3] = np.maximum(a[inside, 3], BACKING[3])
    spill = np.clip(np.minimum(a[..., 0], a[..., 2]) - a[..., 1] - 4, 0, None)
    a[..., 0] -= spill
    a[..., 2] -= spill
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def build(meshy=MESHY):
    return fill(trimmed(meshy))


# The Meshy cast bar's groove is as tall as a unit frame's: right of the icon socket (x >= SPLIT),
# the uniform middle rows of the bar (MIDDLE) are squeezed to MIDDLE_TO rows and the bar is
# centered on the socket. The socket's plate pieces sticking out above and below the thin bar are
# cut off outside the ring (center RING_C, outer radius RING_R).
# Then the socket (x < SPLIT) is scaled by RING_SCALE (the icon was too big next to the bar), and
# the empty rows are trimmed.
SPLIT, MIDDLE, MIDDLE_TO = 300, (70, 180), 25
RING_C, RING_R = (170, 123), 122
RING_SCALE = 0.65


def castbar_open():
    """The thin cast bar, holes still open."""
    a = np.asarray(trimmed(CASTBAR_MESHY)).copy()
    right = a[:, SPLIT:]
    m0, m1 = MIDDLE
    middle = np.asarray(Image.fromarray(right[m0:m1]).resize((right.shape[1], MIDDLE_TO), Image.LANCZOS))
    thin = np.concatenate([right[:m0], middle, right[m1:]])
    out = np.zeros_like(a)
    out[:, :SPLIT] = a[:, :SPLIT]
    top = (a.shape[0] - thin.shape[0]) // 2
    out[top:top + thin.shape[0], SPLIT:] = thin
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    outside = (xs < SPLIT) & (xs > RING_C[0]) & (np.hypot(xs - RING_C[0], ys - RING_C[1]) > RING_R)
    out[outside & ((ys < top + 30) | (ys >= top + thin.shape[0] - 30))] = 0
    socket = Image.fromarray(out[:, :SPLIT])
    sw, sh = round(socket.width * RING_SCALE), round(socket.height * RING_SCALE)
    socket = socket.resize((sw, sh), Image.LANCZOS)
    bar = Image.fromarray(out[:, SPLIT:])
    img = Image.new("RGBA", (sw + bar.width, out.shape[0]))
    img.paste(bar, (sw, 0))
    img.alpha_composite(socket, (0, (out.shape[0] - sh) // 2))
    return img.crop(img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())


def castbar():
    return fill(castbar_open())


if __name__ == "__main__":
    build().save(OUT)
    print("unit frame openings:", holes(np.asarray(trimmed())))
    castbar().save(CASTBAR_OUT)
    print("cast bar openings:", holes(np.asarray(castbar_open())), castbar().size)
