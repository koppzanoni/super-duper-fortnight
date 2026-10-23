"""Orb cap redrawn with dragon wings (Meshy art/meshy/cap_panel.png): a wing with a stone
backing in place of the gargoyle by the orb, and small folded wings beside the 3x3 menu panel.

The right half of the original orb ring (with its top and bottom crests, which hide the seam)
and the original block of the 9 menu slots are pasted back over the Meshy image, so the orb and
the menu buttons stay exactly where the addon places them. The orb opening is always cut out.
Used by export_textures.py for the "hud_cap" texture.

Usage: python tools/cap_art.py   (keys the Meshy image into art/processed/cap_wing.png)
"""
import pathlib

import numpy as np
from PIL import Image

from process_art import key_magenta

ROOT = pathlib.Path(__file__).resolve().parent.parent
MESHY = ROOT / "art" / "meshy" / "cap_panel.png"
WING = ROOT / "art" / "processed" / "cap_wing.png"  # keyed, at the cap size
# The Meshy reference was the cap on a 678x381 canvas (scaled 2x).
CANVAS = (678, 381)
CAP_W, CAP_H = 656, 381
# Orb ring in cap px: center, opening radius, outer radius of the ring.
CX, CY, OPENING, RING = 192, 180, 127, 165
CRESTS = [(168, 0, 218, 30), (165, 335, 222, 381)]  # top and bottom crests (x0, y0, x1, y1)
# The 3x3 menu slots with the iron grid between them (x0, y0, x1, y1).
SLOTS = (418, 132, 594, 314)
EDGE_MARGIN = 2  # empty columns Meshy left at the screen edge


def keep_original_mask():
    ys, xs = np.mgrid[0:CAP_H, 0:CAP_W]
    r = np.hypot(xs - CX, ys - CY)
    keep = (r <= RING) & (xs >= CX)
    for x0, y0, x1, y1 in CRESTS + [SLOTS]:
        keep |= (xs >= x0) & (xs < x1) & (ys >= y0) & (ys < y1)
    return keep, r <= OPENING


def prepare(meshy=MESHY, out=WING):
    """Key the Meshy image and bring it to the cap size (no trimming: it must stay aligned).
    Meshy left a thin margin at the left: the first solid column is repeated out to the edge."""
    img = key_magenta(Image.open(meshy)).resize(CANVAS, Image.LANCZOS).crop((0, 0, CAP_W, CAP_H))
    a = np.asarray(img).copy()
    a[:, :EDGE_MARGIN] = a[:, EDGE_MARGIN:EDGE_MARGIN + 1]
    Image.fromarray(a, "RGBA").save(out)


def build(cap, wing_path=WING):
    w = np.asarray(Image.open(wing_path).convert("RGBA")).astype(np.float32)
    o = np.asarray(cap.convert("RGBA")).astype(np.float32)
    keep, opening = keep_original_mask()
    w[opening] = 0
    out = np.where(keep[..., None], o, w)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    prepare()
