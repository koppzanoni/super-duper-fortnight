"""Key out the magenta background of the Meshy pieces, crop them and save transparent PNGs.

Usage: python tools/process_art.py [name ...]   (no names: every piece)
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
}
# Images with two separate pieces whose outlines overlap vertically: keep only the topmost
# piece by its outline (a straight crop cut the bottom of the target frame's portrait ring).
TOP_PIECE = {"target_frame"}
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


def keep_top_piece(img):
    from scipy import ndimage
    a = np.asarray(img).copy()
    labels, n = ndimage.label(a[..., 3] > 40)
    if n > 1:
        tops = [np.where(labels == i)[0].min() for i in range(1, n + 1)]
        top = 1 + int(np.argmin(tops))
        a[..., 3] = np.where(labels == top, a[..., 3], 0)
    return Image.fromarray(a, "RGBA")


def main(names=None):
    DST.mkdir(parents=True, exist_ok=True)
    for path in sorted(SRC.glob("*.png")):
        name = path.stem
        if name in SKIP or (names and name not in names):
            continue
        img = Image.open(path)
        if name in REGIONS:
            img = img.crop(REGIONS[name])
        out = key_magenta(img)
        if name in TOP_PIECE:
            out = keep_top_piece(out)
        out = out.crop(out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        out.save(DST / f"{name}.png")
        print(f"{name}: {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
