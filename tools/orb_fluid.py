"""Looping fluid flipbooks for the HUD orbs, plus the orb glass and spark textures.

Each style is a grayscale sheet of FRAMES frames (GRID x GRID cells of SIZE px): the bright
wisps of the liquid. In game the body is a dark tinted sphere and the wisps are added on top,
tinted with the bright color, so any power color works. The loop is seamless (time runs on a
circle); the slow overall spin is done in game by rotating the texture.
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image

SIZE, GRID = 128, 8
FRAMES = GRID * GRID


def _noise_grid(cells, rng):
    return rng.random((cells, cells))


def _value_noise(px, py, grid):
    """Tileable smooth value noise; px, py in grid units (any float)."""
    n = grid.shape[0]
    x0, y0 = np.floor(px).astype(int), np.floor(py).astype(int)
    tx, ty = px - x0, py - y0
    sx, sy = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = grid[y0 % n, x0 % n]
    b = grid[y0 % n, (x0 + 1) % n]
    c = grid[(y0 + 1) % n, x0 % n]
    d = grid[(y0 + 1) % n, (x0 + 1) % n]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def _fbm(px, py, grids, octaves=4):
    v, amp, f, total = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        v = v + amp * _value_noise(px * f, py * f, grids[o % len(grids)])
        total += amp
        amp *= 0.5
        f *= 2.0
    return v / total


STYLES = {
    # twist: spiral strength; warp: how much the flow bends; scale: feature size;
    # sharp: how thin the wisps are; drift: how far the warp travels per loop (speed);
    # octaves: fine detail; base: glow left between wisps.
    "a": dict(twist=2.2, warp=1.3, scale=1.3, sharp=6.0, drift=0.35, octaves=3, base=0.0, gamma=1.0),
    "b": dict(twist=2.8, warp=1.5, scale=1.6, sharp=4.5, drift=0.45, octaves=3, base=0.08, gamma=1.1),
    "c": dict(twist=0.9, warp=1.0, scale=0.9, sharp=3.5, drift=0.25, octaves=2, base=0.0, gamma=3.0),
}


def frame(style, t, grids):
    s = STYLES[style]
    y, x = np.mgrid[0:SIZE, 0:SIZE] / (SIZE - 1) * 2 - 1  # -1..1
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x) + s["twist"] * (1 - np.clip(r, 0, 1)) ** 1.5  # spiral toward the center
    px, py = r * np.cos(ang) * s["scale"] + 8, r * np.sin(ang) * s["scale"] + 8
    th = 2 * math.pi * t
    d = s["drift"]
    # Domain warp driven by time on a circle: seamless loop.
    o = s["octaves"]
    qx = _fbm(px + d * math.cos(th), py + d * math.sin(th), grids, o)
    qy = _fbm(px + 5.2 - d * math.sin(th), py + 1.3 + d * math.cos(th), grids, o)
    v = _fbm(px + s["warp"] * qx * 4, py + s["warp"] * qy * 4, grids, o)
    # Ridges: bright thin wisps where the field crosses its middle.
    ridge = 1 - np.abs(v - 0.5) * 2
    w = np.clip(ridge, 0, 1) ** s["sharp"]
    w = s["base"] + (1 - s["base"]) * w
    return np.clip(w, 0, 1)


def sheet(style, seed=3):
    rng = np.random.default_rng(seed)
    grids = [_noise_grid(8, rng), _noise_grid(8, rng)]
    out = np.zeros((SIZE * GRID, SIZE * GRID), np.float32)
    for i in range(FRAMES):
        f = frame(style, i / FRAMES, grids)
        gy, gx = divmod(i, GRID)
        out[gy * SIZE:(gy + 1) * SIZE, gx * SIZE:(gx + 1) * SIZE] = f
    out = ((out - out.min()) / (out.max() - out.min())) ** STYLES[style]["gamma"]
    a = np.zeros(out.shape + (4,), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (out * 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def glass(size=256):
    """Glass sphere light: a crescent reflection at the top-left and a faint rim at the bottom."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    # crescent: inside a circle offset to the top-left, outside a slightly smaller shifted one
    c1 = np.sqrt((x + 0.12) ** 2 + (y + 0.14) ** 2)
    c2 = np.sqrt((x + 0.02) ** 2 + (y + 0.02) ** 2)
    crescent = np.clip((0.86 - c1) / 0.06, 0, 1) * np.clip((c2 - 0.80) / 0.08, 0, 1)
    crescent *= np.clip(-(x + y) * 0.9 + 0.2, 0, 1)  # only toward the top-left
    spot = np.exp(-((x + 0.38) ** 2 + (y + 0.45) ** 2) / 0.02) * 0.6
    rim = np.clip((r - 0.86) / 0.1, 0, 1) * np.clip((1 - r) / 0.04, 0, 1) * np.clip(y, 0, 1) * 0.35
    alpha = np.clip(crescent * 0.55 + spot + rim, 0, 1)
    alpha[r > 1] = 0
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def depth(size=256):
    """Radial deepening of the liquid: clear in the middle, toward the deep tone at the glass."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    alpha = np.clip((r - 0.55) / 0.45, 0, 1) ** 1.6 * 0.85
    alpha[r > 1] = 0
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def spark(size=32):
    """Small soft dot of light (the rising bubbles of the Energia style)."""
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    alpha = np.clip(1 - d, 0, 1) ** 2
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for st in STYLES:
        sheet(st).save(out / f"fluid_{st}.png")
    glass().save(out / "glass.png")
    print("ok", list(STYLES))
