"""Inputs for the Meshy refinement pass of the "Moderno" pieces: each piece from modern_art.py,
drawn without glow and shadow (they would tint the magenta), alone and centered on flat magenta.

Usage: python tools/modern_meshy_inputs.py   (writes art/modern_in_*.png)
"""
import pathlib

from PIL import Image

import modern_art

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAGENTA = (255, 0, 255, 255)


def clean(piece, scale=1):
    """The piece without glow and shadow, rendered at `scale` times its texture size (drawn
    larger, so a small piece stays sharp)."""
    render, ss = modern_art.Canvas.render, modern_art.SS

    def plain(self, glow=0, shadow=0):
        out = self.layers["body"].copy()
        out.alpha_composite(self.layers["lines"])
        out.alpha_composite(self.layers["top"])
        return out.resize((self.w * scale, self.h * scale), Image.LANCZOS)

    modern_art.Canvas.render, modern_art.SS = plain, max(ss, 2 * scale)
    try:
        return piece()
    finally:
        modern_art.Canvas.render, modern_art.SS = render, ss


def opaque(img):
    """Semi-transparent panels laid over dark navy and made opaque (over magenta they turned
    purple); fully clear pixels stay clear."""
    base = Image.new("RGBA", img.size, modern_art.PANEL + (255,))
    base.alpha_composite(img)
    base.putalpha(img.getchannel("A").point(lambda v: 255 if v > 24 else 0))
    return base


def on_magenta(img, size, fill=0.82):
    img = opaque(img)
    k = min(size[0] * fill / img.width, size[1] * fill / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", size, MAGENTA)
    out.alpha_composite(img, ((size[0] - img.width) // 2, (size[1] - img.height) // 2))
    return out.convert("RGB")


def main():
    on_magenta(clean(modern_art.unit_frame, 2), (1376, 768)).save(ROOT / "art" / "modern_in_unit.png")
    on_magenta(clean(modern_art.slot_frame, 6), (1024, 1024), 0.6).save(ROOT / "art" / "modern_in_slot.png")
    on_magenta(clean(modern_art.cast_bar, 2), (1376, 768), 0.9).save(ROOT / "art" / "modern_in_cast.png")


if __name__ == "__main__":
    main()


def placement(piece_size, size, fill):
    """Where on_magenta put a piece of piece_size: (x, y, w, h) on the canvas."""
    k = min(size[0] * fill / piece_size[0], size[1] * fill / piece_size[1])
    w, h = round(piece_size[0] * k), round(piece_size[1] * k)
    return (size[0] - w) // 2, (size[1] - h) // 2, w, h


def refined(name, tex_size, size, fill):
    """Meshy's redraw of a piece, cut back to the piece's own frame and texture size, keyed.
    The redraw keeps the framing of the input, so the piece sits where on_magenta put it."""
    from process_art import key_magenta
    img = Image.open(ROOT / "art" / "meshy" / f"modern3_{name}.png").convert("RGB")
    sx, sy = img.width / size[0], img.height / size[1]
    x, y, w, h = placement(tex_size, size, fill)
    img = img.crop((round(x * sx), round(y * sy), round((x + w) * sx), round((y + h) * sy)))
    return key_magenta(img.resize(tex_size, Image.LANCZOS))
