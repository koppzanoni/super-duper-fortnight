"""Unit frame art (target, focus, target-of-target, pet, and later the party): the first frame of
the Meshy sheet art/meshy/party_free_b.png (a round portrait ring with a small dragon, a name
plate, a health groove and a mana groove), keyed and trimmed.

The name plate and the bar grooves are holes in the art: they get a dark backing so the world
never shows behind a bar that is not full. The portrait ring's opening stays empty (the portrait
fills it). HOLES are the openings, in px of the processed art; Data.UNIT places regions in them.
Used by export_textures.py for the "unit_frame" texture.

Usage: python tools/unit_art.py   (writes art/processed/unit_frame.png)
"""
import pathlib

import numpy as np
from PIL import Image

from process_art import key_magenta

ROOT = pathlib.Path(__file__).resolve().parent.parent
MESHY = ROOT / "art" / "meshy" / "party_free_b.png"
OUT = ROOT / "art" / "processed" / "unit_frame.png"
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


def build(meshy=MESHY):
    """Dark backing in every hole but the portrait's; the magenta tint left on the rims removed."""
    from scipy import ndimage
    a = np.asarray(trimmed(meshy)).astype(np.float32)
    labels, _ = ndimage.label(a[..., 3] < 128)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    px, py, pw, ph = max(holes(a.astype(np.uint8)), key=lambda b: b[3])  # the portrait: tallest opening
    portrait = labels[py + ph // 2, px + pw // 2]
    fill = (labels > 0) & ~np.isin(labels, list(border)) & (labels != portrait)
    fill = ndimage.binary_dilation(fill, iterations=2) & (a[..., 3] < 255)
    k = a[..., 3:] / 255
    back = np.array(BACKING, np.float32)
    a[fill, :3] = a[fill, :3] * k[fill] + back[:3] * (1 - k[fill])
    a[fill, 3] = np.maximum(a[fill, 3], BACKING[3])
    spill = np.clip(np.minimum(a[..., 0], a[..., 2]) - a[..., 1] - 4, 0, None)
    a[..., 0] -= spill
    a[..., 2] -= spill
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    build().save(OUT)
    print("openings:", holes(np.asarray(trimmed())))
