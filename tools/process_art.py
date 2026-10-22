"""Key out the magenta background of the Meshy pieces, crop them and save transparent PNGs.

Usage: python tools/process_art.py
Reads art/meshy/*.png, writes art/processed/*.png
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "meshy"
DST = ROOT / "art" / "processed"

# Region (x0, y0, x1, y1) to keep before trimming, for images where Meshy added extra content.
REGIONS = {
    "action_bar": (0, 100, 1376, 470),
    "target_frame": (0, 20, 1376, 458),
}
SKIP = {"hud_full"}


def key_magenta(img):
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # How much more magenta than green the pixel is
    m = np.minimum(r, b) - g
    alpha = 1.0 - np.clip((m - 40.0) / (140.0 - 40.0), 0.0, 1.0)
    # Remove magenta spill from the edges
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1.0 - alpha * 0.5)
    spill = np.where(m > 10, spill, 0)
    r = np.clip(r - spill, 0, 255)
    b = np.clip(b - spill, 0, 255)
    out = np.dstack([r, g, b, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    DST.mkdir(parents=True, exist_ok=True)
    for path in sorted(SRC.glob("*.png")):
        name = path.stem
        if name in SKIP:
            continue
        img = Image.open(path)
        if name in REGIONS:
            img = img.crop(REGIONS[name])
        out = key_magenta(img)
        out = out.crop(out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        out.save(DST / f"{name}.png")
        print(f"{name}: {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
