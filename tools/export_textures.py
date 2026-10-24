"""Export the addon textures as power-of-two TGA files plus Media/manifest.lua.

Usage: python tools/export_textures.py
Reads art/processed/*.png, writes ObsidianUI/Media/*.tga and ObsidianUI/Media/manifest.lua
"""
import math
import pathlib

import numpy as np
from PIL import Image

import modern_art

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "processed"
MEDIA = ROOT / "ObsidianUI" / "Media"
GAME_PATH = "Interface\\AddOns\\ObsidianUI\\Media\\"
MAX_POT = 2048

# name -> (source file, crop box or None, max side or None)
ART_SOURCES = {
    "gem_on": ("gem_lit.png", None, 128),
    "gem_off": ("gem_socket.png", None, 128),
}


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


def bar_fill(w=256, h=32):
    v = np.linspace(255, 150, h)[:, None].repeat(w, 1)
    a = np.dstack([v, v, v, np.full_like(v, 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def aura_border(size=64, width=3):
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[:width, :, 3] = a[-width:, :, 3] = a[:, :width, 3] = a[:, -width:, 3] = 255
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


def cursor_ring(size=128, width=0.06):
    # Ring around the mouse: a crisp band near the edge with a soft glow inside; tinted in game.
    y, x = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    outer, inner = 0.92, 0.92 - width * 2
    band = np.clip((outer - d) * c + 0.5, 0, 1) * np.clip((d - inner) * c + 0.5, 0, 1)
    glow = np.clip(1 - (inner - d) / 0.35, 0, 1) ** 2 * 0.35 * (d < inner)
    alpha = np.maximum(band, glow)
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (alpha * 255).round().astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def cursor_dot(size=32):
    # Soft round dot for the trail: solid centre fading to nothing at the edge.
    y, x = np.mgrid[0:size, 0:size]
    c = size / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (c - 1)
    alpha = np.clip(1 - d, 0, 1) ** 1.5
    a = np.zeros((size, size, 4), np.uint8)
    a[..., :3] = 255
    a[..., 3] = (alpha * 255).round().astype(np.uint8)
    return Image.fromarray(a, "RGBA")


# Soft panel pieces (Widgets.Panel), drawn 8x larger and scaled down for smooth corners. All
# white: the addon tints them. Sliced in the game (SetTextureSliceMargins) so the corners keep
# their size on any panel. SOFT_RADIUS and SOFT_MARGIN are read by Core/Widgets.lua.
SOFT_SIZE, SOFT_RADIUS, SOFT_MARGIN = 32, 6, 10


def _rounded(size, inset, radius, ss=8):
    from PIL import ImageDraw
    big = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (inset * ss, inset * ss, (size - inset) * ss - 1, (size - inset) * ss - 1), radius * ss, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def _white(alpha):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def soft_fill():
    return _white(_rounded(SOFT_SIZE, 0, SOFT_RADIUS))


def soft_rim():
    from PIL import ImageChops
    outer = _rounded(SOFT_SIZE, 0, SOFT_RADIUS)
    inner = _rounded(SOFT_SIZE, 1, SOFT_RADIUS - 1)
    return _white(ImageChops.subtract(outer, inner))


def soft_shadow(size=64, spread=16):
    from PIL import ImageFilter
    a = _rounded(size, spread, SOFT_RADIUS + 2)
    a = a.filter(ImageFilter.GaussianBlur(spread / 2.2))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.putalpha(a)
    return img


PROCEDURAL = {
    "mask_circle": mask_circle,
    "bar_fill": bar_fill,
    "aura_border": aura_border,
    "icon_sort": icon_sort,
    "cursor_ring": cursor_ring,
    "cursor_dot": cursor_dot,
    "soft_fill": soft_fill,
    "soft_rim": soft_rim,
    "soft_shadow": soft_shadow,
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
        save(name, defringe(fit(img, max_side)))
    for name, fn in PROCEDURAL.items():
        save(name, fn())
    # The HUD (tools/modern_art.py): each piece in the concept's blue and in the black theme.
    for name, piece in (("mod_unit", modern_art.unit_frame), ("mod_cast", modern_art.cast_bar),
                        ("mod_slot", modern_art.slot_frame), ("mod_map", modern_art.minimap_ring),
                        ("mod_menu", modern_art.menu_band)):
        img = piece()
        save(name, img)
        save(name + "_black", modern_art.blackify(img))
    save("mod_gem_off", modern_art.gem_socket())
    save("mod_gem_off_black", modern_art.blackify(modern_art.gem_socket()))
    save("mod_gem_on", modern_art.gem_lit())
    save("mod_arcane", modern_art.arcane_ring())
    save("mod_gloss", modern_art.gloss())

    write_manifest(entries, out_dir / "manifest.lua")
    return entries


if __name__ == "__main__":
    for name, e in sorted(export_all().items()):
        print(f"{name}: {e['w']}x{e['h']} -> {e['potW']}x{e['potH']}")
