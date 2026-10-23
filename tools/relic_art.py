"""Orb caps of the "Relicário" HUD style (Meshy art/meshy/cap_claws.png and cap_dragon.png): bone
claws gripping the health orb from above, a dragon coiled around the mana orb. Both were drawn as
the left cap at our cap geometry (orb opening and 3x3 slots match tools/cap_art.py).

Each cap gives two textures: the frame (the orb opening cut out, see-through holes filled with
dark stone) and an overlay with the parts of the claws / dragon that lie over the orb opening,
drawn above the liquid so they grip the glass. Used by export_textures.py.

Usage: python tools/relic_art.py   (keys the Meshy images into art/processed/relic_<name>.png)
"""
import pathlib

import numpy as np
from PIL import Image

import cap_art
from process_art import key_magenta

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAPS = ("claws", "dragon")
# The orb glass (Data.HUD.orb, 130 px radius) is a bit larger than the opening: the overlay also
# carries the art of this band around the opening, so the glass shine stays under ring and claws.
RIM_BAND = 6


def meshy(name):
    return ROOT / "art" / "meshy" / f"cap_{name}.png"


def processed(name):
    return ROOT / "art" / "processed" / f"relic_{name}.png"


def prepare(name):
    """Key the Meshy image and bring it to the cap size, like cap_art.prepare."""
    cap_art.prepare(meshy(name), processed(name))


def _opening(extra=0):
    ys, xs = np.mgrid[0:cap_art.CAP_H, 0:cap_art.CAP_W]
    return np.hypot(xs - cap_art.CX, ys - cap_art.CY) < cap_art.OPENING + extra


def _claws(a):
    """Inside the claws' opening Meshy painted a dark purple void around the claws. The claws are
    neutral grey: the solid shapes of neutral pixels (no specks, holes closed), softly outlined."""
    from scipy import ndimage
    rgb = a[..., :3]
    tint = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    solid = (tint <= 2) & (rgb.max(axis=2) >= 10) & _opening()
    labels, n = ndimage.label(solid)
    sizes = ndimage.sum(solid, labels, range(1, n + 1))
    keep = np.isin(labels, 1 + np.nonzero(sizes > 300)[0])
    keep = ndimage.binary_fill_holes(ndimage.binary_closing(keep, iterations=3))
    return ndimage.gaussian_filter(keep.astype(np.float32), 0.8)


def frame(name):
    a = np.asarray(Image.open(processed(name)).convert("RGBA")).astype(np.float32)
    a[_opening()] = 0
    a = cap_art.fill_holes(a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def overlay(name):
    art = np.asarray(Image.open(processed(name)).convert("RGBA")).astype(np.float32)
    a = art.copy()
    if name == "claws":
        a[..., 3] = 255 * _claws(a)
    # the dragon's wing membrane is see-through over magenta: its keyed alpha is kept as it is
    a[..., 3] *= _opening()
    rim = _opening(RIM_BAND) & ~_opening()
    a[rim] = art[rim]
    a[a[..., 3] < 8] = 0
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    for n in CAPS:
        prepare(n)
