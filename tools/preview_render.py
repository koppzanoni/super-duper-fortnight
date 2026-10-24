"""Render an offline preview of ObsidianUI by running the real addon code in a WoW layout simulator.

Usage: python tools/preview_render.py OUT_DIR [--scene path.jpg]
Writes OUT_DIR/preview_hud.png (vertical bars on), OUT_DIR/preview_inventory.png (inventory open) and
OUT_DIR/preview_blue.png (the HUD in its blue colour).
Icons and portraits come from the reference art (the game provides real ones).
"""
import argparse
import math
import pathlib
import re

from lupa import luajit21
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageChops

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "ObsidianUI"
PREVIEW = ROOT / "tools" / "preview"
REF = ROOT / "Meshy_AI_Dark Fantasy MMORPG HUD.png"
W, H = 1920, 1080
STRATA = {"BACKGROUND": 1, "LOW": 2, "MEDIUM": 3, "HIGH": 4, "DIALOG": 5}
LAYERS = {"BACKGROUND": 1, "BORDER": 2, "ARTWORK": 3, "OVERLAY": 4, "HIGHLIGHT": 5}
FONTS = {"GameFontNormalLarge": (17, "serif", (1, .82, 0)), "GameFontNormal": (14, "serif", (1, .82, 0)),
         "GameFontNormalSmall": (12, "serif", (1, .82, 0)), "GameFontHighlight": (14, "sans", (1, 1, 1)),
         "GameFontHighlightSmall": (12, "sans", (1, 1, 1)), "NumberFontNormalSmall": (11, "sans", (1, 1, 1)),
         "NumberFontNormal": (13, "sans", (1, 1, 1))}
FONT_FILES = {"serif": "C:/Windows/Fonts/georgia.ttf", "sans": "C:/Windows/Fonts/arialbd.ttf"}


def ref_icons():
    ref = Image.open(REF).convert("RGBA")
    icons = []
    for yc in (667, 740):
        for i in range(12):
            xc = 531 + i * 44.8
            icons.append(ref.crop((int(xc - 14), yc - 17, int(xc + 14), yc + 17)).resize((64, 64), Image.LANCZOS))
    portrait = ref.crop((22, 14, 126, 118)).resize((256, 256), Image.LANCZOS)
    hero = ref.crop((690, 270, 850, 440))
    return icons, portrait, hero


ICONS, WOLF, HERO = ref_icons()
_cache = {}


def texture_image(file):
    if file in _cache:
        return _cache[file]
    img = None
    if file.startswith("Interface\\AddOns\\ObsidianUI\\Media\\"):
        p = ADDON / "Media" / (file.split("\\")[-1] + ".tga")
        if p.exists():
            img = Image.open(p).convert("RGBA")
    elif file in (r"Interface\Buttons\WHITE8X8", r"Interface\TargetingFrame\UI-StatusBar"):
        # the game's own bar textures: plain white, and Blizzard's light-topped bar
        img = Image.new("RGBA", (64, 16), (255, 255, 255, 255))
        if "UI-StatusBar" in file:
            for yy in range(16):
                v = 255 if yy < 7 else int(255 - (yy - 7) * 9)
                ImageDraw.Draw(img).line((0, yy, 63, yy), fill=(v, v, v, 255))
    elif file.startswith("ICON:"):
        key = file[5:]
        if key == "bag":
            img = Image.new("RGBA", (64, 64), (92, 64, 36, 255))
            ImageDraw.Draw(img).rounded_rectangle((10, 18, 54, 56), 8, fill=(140, 98, 52, 255), outline=(60, 40, 20, 255), width=3)
        else:
            img = ICONS[int(key) % 24]
    elif file.startswith("PORTRAIT:"):
        img = WOLF if file.endswith("target") else ICONS[{"focus": 18, "pet": 14}.get(file[9:], 22)].resize((256, 256))
    _cache[file] = img
    return img


def lua_runtime():
    rt = luajit21.LuaRuntime(unpack_returned_tuples=True)
    rt.execute(f"PREVIEW_W, PREVIEW_H = {W}, {H}")
    rt.execute((PREVIEW / "engine.lua").read_text(encoding="utf-8"))
    rt.execute((PREVIEW / "fakes.lua").read_text(encoding="utf-8"))
    return rt


def toc_files():
    out = []
    for line in (ADDON / "ObsidianUI.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            out.append(ADDON / line.replace("\\", "/"))
    return out


def run_addon(vbars=True, inventory=False, db=None, pre=None):
    rt = lua_runtime()
    if pre:
        rt.execute(pre)  # stand-ins a test needs before the addon loads
    ns = rt.table()
    rt.globals().PREVIEW_NS = ns  # the addon's namespace, for tests
    loader = rt.eval("function(src, name) return assert(loadstring(src, name)) end")
    for p in toc_files():
        loader(p.read_text(encoding="utf-8"), "@" + p.name)("ObsidianUI", ns)
    rt.execute('PREVIEW_FIRE("ADDON_LOADED", "ObsidianUI")')
    ns.db.vbar1, ns.db.vbar2 = vbars, vbars
    def lua_value(v):  # nested settings (the edit mode's layout) become Lua tables
        if isinstance(v, dict):
            return rt.table_from({k: lua_value(x) for k, x in v.items()})
        if isinstance(v, list):  # a Lua array, 1-based
            return rt.table_from({i + 1: lua_value(x) for i, x in enumerate(v)})
        return v
    for k, v in (db or {}).items():
        ns.db[k] = lua_value(v)
    rt.execute("PREVIEW_FILL_AURAS({5, 2})")
    for ev in ("PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED"):
        rt.execute(f'PREVIEW_FIRE("{ev}")')
    for unit in ("player", "target", "focus", "pet", "targettarget"):
        for ev in ("UNIT_HEALTH", "UNIT_POWER_FREQUENT", "UNIT_PET", "UNIT_AURA"):
            rt.execute(f'PREVIEW_FIRE("{ev}", "{unit}")')
    rt.execute('PREVIEW_FIRE("UNIT_TARGET", "target")')
    if inventory:
        ns.Inventory.Open()
    return rt


def tex_crop(img, tc):
    if not tc:
        return img
    v = list(tc.values())
    if len(v) == 8:
        v = [v[0], v[4], v[1], v[3]]
    l, r, t, b = v[:4]
    if max(l, r, t, b) > 1.001 or min(l, r, t, b) < -0.001:
        return img
    flip = l > r
    l, r = sorted((l, r))
    box = (int(round(l * img.width)), int(round(t * img.height)), max(1, int(round(r * img.width))), max(1, int(round(b * img.height))))
    out = img.crop(box)
    return ImageOps.mirror(out) if flip else out


def circle_mask(size):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, size[0] - 1, size[1] - 1), fill=255)
    return m


def strip_codes(text):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text or "")


def font(face, size):
    return ImageFont.truetype(FONT_FILES[face], size)


def draw_text(canvas, r, region, rect):
    text = strip_codes(region.text)
    if not text:
        return
    size, face, color = FONTS.get(region.font or "", (12, "sans", (1, 1, 1)))
    if region.fsize:
        size = int(region.fsize)
    if region.tcolor:
        color = tuple(region.tcolor.values())[:3]
    f = font(face, size)
    rgb = tuple(int(c * 255) for c in color)
    draw = ImageDraw.Draw(canvas)
    bw, bh = draw.textbbox((0, 0), text, font=f)[2:]
    l, b, w, h = rect
    # the game cuts a text that does not wrap and is wider than its region, with an ellipsis
    if region.nowrap and w > 1 and bw > w:
        while text and draw.textbbox((0, 0), text + "...", font=f)[2] > w:
            text = text[:-1]
        text = text.rstrip() + "..."
        bw, bh = draw.textbbox((0, 0), text, font=f)[2:]
    top = H - (b + h)
    if w > 1 and h > 1:
        x = l + (w - bw) / 2 if region.justify not in ("LEFT", "RIGHT") else (l + 2 if region.justify == "LEFT" else l + w - bw - 2)
        y = top + (h - bh) / 2
    else:
        pts = list(region.points.values())
        point = pts[0].point if pts else "CENTER"
        x = l - bw / 2
        if "LEFT" in point:
            x = l
        elif "RIGHT" in point:
            x = l - bw
        y = top - bh / 2
        if "TOP" in point:
            y = top
        elif "BOTTOM" in point:
            y = top - bh
    draw.text((x, y), text, font=f, fill=rgb + (255,), stroke_width=1, stroke_fill=(0, 0, 0, 230))


def map_image(size):
    img = Image.new("RGBA", size, (38, 52, 34, 255))
    d = ImageDraw.Draw(img)
    w, h = size
    d.ellipse((w * .1, h * .1, w * .5, h * .5), fill=(72, 90, 58, 255))
    d.ellipse((w * .5, h * .45, w * .95, h * .9), fill=(60, 76, 48, 255))
    d.line((w * .2, h * .95, w * .8, h * .05), fill=(90, 74, 50, 255), width=max(2, w // 18))
    d.polygon([(w / 2, h / 2 - 7), (w / 2 - 5, h / 2 + 6), (w / 2 + 5, h / 2 + 6)], fill=(255, 209, 0, 255))
    return img


def render(rt, scene, out_path):
    canvas = scene.copy()
    regions = list(rt.globals().REGIONS.values())
    items = []
    for r in regions:
        if r.kind not in ("texture", "font", "frame") or not r.IsVisible(r):
            continue
        owner = r if r.kind == "frame" else r.parent
        if owner is None:
            continue
        rect = tuple(r.Rect(r).values())
        if rect[2] <= 0.5 or rect[3] <= 0.5:
            if r.kind != "font":
                continue
        if r.kind == "frame" and not (r.isMinimap or r.ftype == "PlayerModel"):
            continue
        key = (STRATA.get(owner.GetStrata(owner), 3), owner.GetFrameLevel(owner),
               0 if r.kind == "frame" else LAYERS.get(r.layer or "ARTWORK", 3), r.sub or 0, r.order)
        items.append((key, r, rect))
    items.sort(key=lambda t: t[0])

    for _, r, rect in items:
        l, b, w, h = rect
        box = (int(round(l)), int(round(H - (b + h))), max(1, int(round(w))), max(1, int(round(h))))
        if r.kind == "font":
            # a scroll frame or a clipping frame cuts its texts too
            clip = r.parent
            while clip is not None and not clip.clips:
                clip = clip.parent
            if clip is None:
                draw_text(canvas, rt, r, rect)
            else:
                cr = tuple(clip.Rect(clip).values())
                cbox = (int(round(cr[0])), int(round(H - (cr[1] + cr[3]))), int(round(cr[0] + cr[2])), int(round(H - cr[1])))
                layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                draw_text(layer, rt, r, rect)
                keep = Image.new("L", (W, H), 0)
                keep.paste(255, cbox)
                layer.putalpha(ImageChops.multiply(layer.getchannel("A"), keep))
                canvas.alpha_composite(layer)
            continue
        if r.kind == "frame":
            img = map_image((box[2], box[3])) if r.isMinimap else HERO.resize((box[2], box[3]), Image.LANCZOS)
            if r.isMinimap:
                img.putalpha(circle_mask(img.size))
            canvas.alpha_composite(img, (box[0], box[1]))
            continue
        if r.color:
            c = list(r.color.values())
            img = Image.new("RGBA", (box[2], box[3]), tuple(int(v * 255) for v in c[:3]) + (int(c[3] * 255),))
        elif r.file:
            src = texture_image(str(r.file))
            if src is None:
                continue
            img = tex_crop(src, r.tc).resize((box[2], box[3]), Image.LANCZOS)
        else:
            continue
        if r.grad and r.color:
            _, lo, hi = list(r.grad.values())
            col = [[c.r, c.g, c.b, c.a] for c in (lo, hi)]
            grad = Image.new("RGBA", (1, box[3]))
            for yy in range(box[3]):
                f = 1 - yy / max(1, box[3] - 1)  # 0 at the bottom (minColor), 1 at the top
                grad.putpixel((0, yy), tuple(int((col[0][i] + (col[1][i] - col[0][i]) * f) * 255) for i in range(4)))
            img = grad.resize((box[2], box[3]))
        if r.rot:
            img = img.rotate(math.degrees(r.rot), resample=Image.BICUBIC)
        vc = list(r.vc.values())
        if r.desat:
            img = Image.merge("RGBA", (*[ImageOps.grayscale(img)] * 3, img.getchannel("A")))
        if vc[:3] != [1, 1, 1]:
            tint = Image.new("RGBA", img.size, tuple(int(v * 255) for v in vc[:3]) + (255,))
            rgb = ImageChops.multiply(img.convert("RGB"), tint.convert("RGB"))
            img = Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))
        alpha = (r.alpha or 1) * (vc[3] if len(vc) > 3 else 1)
        if alpha < 1:
            img.putalpha(img.getchannel("A").point(lambda v: int(v * alpha)))
        if r.mask:
            m = r.mask
            mr = tuple(m.Rect(m).values())
            mbox = (int(round(mr[0])), int(round(H - (mr[1] + mr[3]))), max(1, int(round(mr[2]))), max(1, int(round(mr[3]))))
            full = Image.new("L", (W, H), 0)
            full.paste(circle_mask((mbox[2], mbox[3])), (mbox[0], mbox[1]))
            local = full.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
            img.putalpha(ImageChops.multiply(img.getchannel("A"), local))
        clipper = r.parent
        while clipper is not None and not clipper.clips:
            clipper = clipper.parent
        if clipper is not None:
            cr = tuple(clipper.Rect(clipper).values())
            cbox = (int(round(cr[0])), int(round(H - (cr[1] + cr[3]))), int(round(cr[2])), int(round(cr[3])))
            keep = Image.new("L", (W, H), 0)
            keep.paste(255, (cbox[0], cbox[1], cbox[0] + cbox[2], cbox[1] + cbox[3]))
            local = keep.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
            img.putalpha(ImageChops.multiply(img.getchannel("A"), local))
        if r.blend == "ADD":
            layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            layer.alpha_composite(img, (box[0], box[1]))
            a = layer.getchannel("A")
            add = Image.composite(layer, Image.new("RGBA", (W, H), (0, 0, 0, 0)), a)
            base = canvas.convert("RGB")
            canvas = Image.merge("RGBA", (*ImageChops.add(base, add.convert("RGB")).split(), canvas.getchannel("A")))
        else:
            canvas.alpha_composite(img, (box[0], box[1]))
    canvas.convert("RGB").save(out_path, quality=92)
    return out_path


def scene_image(path):
    img = Image.open(path).convert("RGBA")
    if path == REF:
        img = img.crop((0, 135, 1536, 520))
    return ImageOps.fit(img, (W, H), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("--scene", default=str(REF))
    args = ap.parse_args()
    out = pathlib.Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    scene = scene_image(pathlib.Path(args.scene))
    print(render(run_addon(vbars=True), scene, out / "preview_hud.png"))
    print(render(run_addon(vbars=True, inventory=True), scene, out / "preview_inventory.png"))
    print(render(run_addon(vbars=False, db={"modernColor": "blue"}), scene, out / "preview_blue.png"))


if __name__ == "__main__":
    main()
