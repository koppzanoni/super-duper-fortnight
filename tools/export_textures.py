"""Export the addon textures as power-of-two TGA files plus Media/manifest.lua.

Usage: python tools/export_textures.py
Reads art/processed/*.png, writes ObsidianUI/Media/*.tga and ObsidianUI/Media/manifest.lua
"""
import math
import pathlib

import numpy as np
from PIL import Image

import cap_art
import inventory_art
import orb_fluid
import relic_art
import vbar_art

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "processed"
MEDIA = ROOT / "ObsidianUI" / "Media"
GAME_PATH = "Interface\\AddOns\\ObsidianUI\\Media\\"
MAX_POT = 2048

# name -> (source file, crop box or None, max side or None)
ART_SOURCES = {
    "hud_cap": ("hud_bottom.png", (0, 0, 656, 381), None),
    "hud_bar": ("hud_bottom.png", (662, 0, 1346, 381), None),
    "hud_connector": ("hud_connector.png", None, None),
    "target_frame": ("target_frame.png", None, None),
    "unit_small": ("unit_small.png", None, None),
    "focus_frame": ("focus_frame.png", None, None),
    "castbar": ("castbar.png", None, None),
    "gem_on": ("gem_lit.png", None, 128),
    "gem_off": ("gem_socket.png", None, 128),
    "minimap_ring": ("minimap_thin.png", None, None),
    "inventory": ("inventory.png", None, None),
    "slot": ("button_slot.png", None, 128),
}
# Changes drawn on top of a processed piece before export.
REWORK = {"inventory": inventory_art.rework, "hud_cap": cap_art.build}


def next_pot(n):
    p = 1
    while p < n:
        p *= 2
    return p


def pad_pot(img):
    """Pad to power-of-two sides (top-left anchored); returns (padded, original w, original h)."""
    w, h = img.size
    pw, ph = next_pot(w), next_pot(h)
    if max(pw, ph) > MAX_POT:
        raise ValueError(f"texture {w}x{h} exceeds {MAX_POT}")
    out = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    out.paste(img.convert("RGBA"), (0, 0))
    return out, w, h


def defringe(img):
    """Remove the magenta tint left on semi-transparent edge pixels by the chroma key."""
    a = np.asarray(img.convert("RGBA")).astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    edge = (al > 0) & (al < 255)
    spill = np.where(edge, np.clip(np.minimum(r, b) - g, 0, None), 0)
    a[..., 0] = r - spill
    a[..., 2] = b - spill
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def fit(img, max_side):
    if max_side and max(img.size) > max_side:
        s = max_side / max(img.size)
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    return img


def mask_circle(size=256):
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2)
    alpha = np.clip(c - d + 0.5, 0, 1) * 255
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def liquid(size=256):
    # Grayscale body tinted in game with SetVertexColor: a lit sphere of liquid, brighter toward
    # the top and the upper-left light, darker (never black) toward the bottom.
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    vertical = 1.0 - 0.38 * y
    d2 = ((x - 0.5) ** 2 + (y - 0.5) ** 2) / 0.25
    sphere = 0.78 + 0.22 * np.sqrt(np.clip(1.0 - d2, 0, 1))
    light = 0.10 * np.exp(-((x - 0.36) ** 2 + (y - 0.32) ** 2) / 0.03)
    v = np.clip(vertical * sphere + light, 0.5, 1.0) * 255
    a = np.dstack([v, v, v, np.full_like(v, 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def wave(w=256, h=32):
    x = np.arange(w) / w * 2 * math.pi
    top = (np.sin(x * 2) * 0.35 + 0.5) * (h - 1)
    yy = np.arange(h)[:, None]
    alpha = np.clip(yy - top[None, :] + 0.5, 0, 1) * 255
    a = np.zeros((h, w, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def bar_fill(w=256, h=32):
    v = np.linspace(255, 150, h)[:, None].repeat(w, 1)
    a = np.dstack([v, v, v, np.full_like(v, 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def aura_border(size=64, width=3):
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[:width, :, 3] = a[-width:, :, 3] = a[:, :width, 3] = a[:, -width:, 3] = 255
    return Image.fromarray(a, "RGBA")


def vignette(size=256):
    # Thin inner shadow for the orbs where the liquid meets the ring (no reflection).
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    alpha = np.clip((d - 0.84) / 0.16, 0, 1) ** 1.4 * 200
    alpha[d > 1] = 0  # outside the circle: clear (the square's corners showed as black triangles)
    a = np.zeros((size, size, 4), np.uint8)
    a[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def icon_sort(size=64):
    # "Sort" glyph: three bars getting shorter and a down arrow; tinted gold in game.
    a = np.zeros((size, size), np.float32)
    for top, length in ((14, 34), (28, 25), (42, 16)):
        a[top:top + 7, 6:6 + length] = 1
    a[10:40, 47:53] = 1
    for i in range(12):
        a[38 + i, 50 - 11 + i:50 + 11 - i + 1] = 1
    img = np.zeros((size, size, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def map_rim(size=512):
    # Inner rim drawn over the minimap's outer edge: dark stone from 0.885 R outwards, a bronze
    # line at its inner edge and a soft shadow on the map just inside it.
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    inner, line = 0.885, 0.015
    a = np.zeros((size, size, 4), np.float32)
    stone = (d >= inner) & (d <= 1.0)
    shade = 0.10 + 0.05 * np.clip((d - inner) / (1 - inner), 0, 1)
    a[stone, 0], a[stone, 1], a[stone, 2] = shade[stone], shade[stone], shade[stone] * 1.1
    a[stone, 3] = 1
    bronze = (d >= inner) & (d < inner + line)
    a[bronze, :3] = (0.62, 0.48, 0.27)
    shadow = (d >= inner - 0.03) & (d < inner)
    a[shadow, 3] = ((d[shadow] - (inner - 0.03)) / 0.03) * 0.6
    return Image.fromarray((a * 255).astype(np.uint8), "RGBA")


def ring_glow(size=256):
    # Thin soft ring at the rim; tinted by classification (elite purple, rare silver).
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    alpha = np.exp(-((d - 0.93) / 0.045) ** 2) * 255
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(a, "RGBA")


PROCEDURAL = {
    "ring_glow": ring_glow,
    "vignette": vignette,
    "mask_circle": mask_circle,
    "liquid": liquid,
    "wave": wave,
    "bar_fill": bar_fill,
    "aura_border": aura_border,
    "icon_sort": icon_sort,
    "map_rim": map_rim,
}


def write_manifest(entries, path):
    lines = ["-- Generated by tools/export_textures.py. Do not edit.", "local _, ns = ...", "ns.MediaManifest = {"]
    for name in sorted(entries):
        e = entries[name]
        lines.append(f'  {name} = {{ file = "{GAME_PATH.replace(chr(92), chr(92) * 2)}{name}", '
                     f'w = {e["w"]}, h = {e["h"]}, potW = {e["potW"]}, potH = {e["potH"]} }},')
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def export_all(out_dir=MEDIA):
    out_dir = pathlib.Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    entries = {}

    def save(name, img):
        padded, w, h = pad_pot(img)
        padded.save(out_dir / f"{name}.tga")
        entries[name] = {"w": w, "h": h, "potW": padded.width, "potH": padded.height}

    for name, (src, box, max_side) in ART_SOURCES.items():
        img = Image.open(ART / src).convert("RGBA")
        if box:
            img = img.crop(box)
        original = img
        if name in REWORK:
            img = REWORK[name](img)
        if name == "inventory":
            for piece, piece_img in inventory_art.pieces(img, original).items():
                save(piece, piece_img)
        save(name, defringe(fit(img, max_side)))
    vbar = Image.open(ART / vbar_art.SOURCE).convert("RGBA")
    save("vbar1", defringe(vbar_art.build(vbar, 1)))
    save("vbar2", defringe(vbar_art.build(vbar, 2)))
    # "Relicário" HUD style: a frame and an over-the-orb overlay per cap.
    for cap in relic_art.CAPS:
        save(f"hud_cap_{cap}", defringe(relic_art.frame(cap)))
        save(f"hud_cap_{cap}_over", defringe(relic_art.overlay(cap)))
    for name, fn in PROCEDURAL.items():
        save(name, fn())
    # Orb liquid: flipbook sheets saved as they are (frames must stay exactly 128 px).
    for style in orb_fluid.STYLES:
        save(f"fluid_{style}", orb_fluid.sheet(style))
    save("orb_glass", orb_fluid.glass())
    save("orb_spark", orb_fluid.spark())
    save("orb_depth", orb_fluid.depth())

    write_manifest(entries, out_dir / "manifest.lua")
    return entries


if __name__ == "__main__":
    for name, e in sorted(export_all().items()):
        print(f"{name}: {e['w']}x{e['h']} -> {e['potW']}x{e['potH']}")
