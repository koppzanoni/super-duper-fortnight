"""Generate the HUD texture pieces with Meshy image-to-image, using the reference HUD image for style.

Usage: python tools/meshy_gen.py [piece ...]   (no args = all pieces)
Reads the API key from .meshy-key.txt in the project root. Outputs go to art/meshy/<piece>.png
"""
import base64
import json
import pathlib
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import requests

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY = (ROOT / ".meshy-key.txt").read_text().strip()
REF = ROOT / "Meshy_AI_Dark Fantasy MMORPG HUD.png"
OUT = ROOT / "art" / "meshy"
API = "https://api.meshy.ai/openapi/v1/image-to-image"
MODEL = "nano-banana-2"
HEADERS = {"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

STYLE = (
    "Use the attached reference image ONLY as the art style guide: copy exactly its materials "
    "(carved dark grey stone, blackened iron, aged bronze trim, gothic filigree), colors, lighting and level of detail. "
)
ISOLATE = (
    " Front view, perfectly flat and orthographic, perfectly symmetrical where it makes sense, no perspective. "
    "Isolated game UI texture asset on a flat solid pure magenta (#FF00FF) background. "
    "No game scene, no text, no numbers, no letters, no icons, no characters."
)

PIECES = {
    "hud_full": ("16:9",
        "Generate ONLY the bottom HUD bar from the reference, edited as follows: "
        "remove the red and blue potion flasks and the small consumable slots on the left panel and replace them with a neat grid of 3 columns by 3 rows of empty square button slots for menu buttons. "
        "Remove the arched crest and the orange gem above the center action bar: the top edge of the center action bar frame must be a straight horizontal line. "
        "Keep the center action bar with 2 rows of 12 empty square slots and the right panel with 2 rows of 4 empty square slots. "
        "Both orbs are completely EMPTY: no liquid, no glass, the inside of each orb ring is flat solid magenta (#FF00FF). "
        "All slots are empty dark recesses with no icons. The experience bar at the bottom is empty."),
    "orb_frame": ("1:1",
        "Generate ONLY one orb frame like the left health orb frame of the reference: a heavy circular ornate ring with engraved runes, "
        "aged bronze trim, a small bronze crest on top and the sculpted gothic stone figure buttress on its left side. "
        "The orb is completely EMPTY: no liquid and no glass, the entire inside of the ring is flat solid magenta (#FF00FF)."),
    "side_panel": ("1:1",
        "Generate ONLY one side panel like the small panel between the left orb and the center action bar in the reference, "
        "but containing a neat grid of 3 columns by 3 rows of identical empty square button slots (dark recesses with thin bronze edges) for menu buttons. "
        "No potions, no flasks, no items. Curved organic ornate frame edges."),
    "action_bar": ("16:9",
        "Generate ONLY the center action bar frame of the reference: a wide ornate frame holding 2 rows of 12 identical empty square slots. "
        "Its top edge must be a STRAIGHT horizontal line with thin bronze trim: no arch, no crest, no gem on top. Slots are empty dark recesses with no icons."),
    "button_slot": ("1:1",
        "Generate ONLY a single empty square action button frame in the style of the reference slots: a dark recessed square with slightly rounded corners, "
        "a thin aged bronze and blackened iron border with subtle engraved detail. The center is empty dark. Large, centered, filling most of the image."),
    "target_frame": ("16:9",
        "Generate ONLY the enemy target frame from the top-left of the reference: the circular ornate portrait ring (neutral dark iron and bronze, without the purple color and without any portrait inside: "
        "the inside of the ring is flat solid magenta #FF00FF) attached to the long ornate name plate with two EMPTY bar slots (a thick one for health and a thin one below for mana), "
        "the bars are empty dark recesses with no fill."),
    "xp_strip": ("16:9",
        "Generate ONLY a long thin horizontal ornate strip like the bottom edge of the reference HUD that holds the experience bar: "
        "carved dark stone with thin bronze trim, containing one long EMPTY segmented bar groove. It spans the full width of the image and is thin, centered vertically."),
    "base_plate": ("16:9",
        "Generate ONLY a very long, low, continuous carved dark stone base plate that spans the ENTIRE width of the image edge to edge, "
        "its height is about one eighth of the image height, sitting at the very bottom of the image. "
        "Its top edge gently undulates in soft organic curves (no boxy steps) with a thin continuous aged bronze trim line following it, "
        "subtle gothic filigree carved along its face, cracked stone texture. It is a background plate meant to sit BEHIND the orb frames, "
        "side panels and action bar shown in the other attached images, tying them into one continuous HUD. No slots, no holes."),
    "bridge": ("16:9",
        "Generate ONLY a single horizontal connecting piece: a carved dark stone and blackened iron bridge segment, about 4 times wider than tall, "
        "meant to connect two of the attached HUD pieces side by side. Thin aged bronze trim along its top and bottom edges, "
        "a small bronze filigree ornament in the middle, organic slightly curved top edge. Both left and right ends are plain flat cut so they can tuck behind other pieces. "
        "Centered, filling most of the image width."),
}

HUD_LEFT = ("16:9",
    "The FIRST attached image is a rough layout mockup of the LEFT HALF of a symmetrical bottom game HUD; its right image edge is the exact vertical center line of the HUD. "
    "Redraw it as ONE single unified, cohesive, physically connected carved piece in the art style of the other attached images. "
    "Keep this exact layout, order and proportions, filling the full image width: "
    "(1) the round health orb frame at the far left, "
    "(2) next to it a panel with a 3x3 grid of empty square menu slots, "
    "(3) the left half of the center action bar with exactly 9 columns by 2 rows of empty square slots, cut cleanly and straight at the right image edge so it can be mirrored, "
    "(4) ONE single thin experience bar groove along the very bottom under the action bar. There must be NO other bar grooves or segmented strips anywhere else. "
    "Join all parts with a continuous low carved stone backing so nothing floats and there are no empty gaps between parts. "
    "Make all ornaments SMALLER, thinner and more subtle than in the references: the gargoyle on the orb is small and slim, the 3x3 panel has a clean slim frame with no big roots or tentacles. "
    "The inside of the orb ring is flat solid magenta (#FF00FF). All slots are empty dark recesses.")
VBAR = ("9:16",
    "Generate ONLY one VERY NARROW, tall VERTICAL action bar frame, matching exactly the style of the attached unified bottom HUD piece. "
    "It has exactly ONE single column of exactly 12 small identical empty square slots stacked on top of each other, one slot per row, 12 rows. "
    "NOT a grid: only one slot wide. The whole frame is only about one eighth of the image width, centered horizontally, spanning most of the image height; "
    "everything else is flat magenta background. Slim carved dark stone and blackened iron frame, thin aged bronze trim, "
    "small subtle ornaments only at the top and bottom ends. Slots are empty dark recesses.")
PIECES["vertical_bar"] = VBAR
PIECES["vertical_bar_b"] = VBAR
REFS_OVERRIDE_V = ["art/processed/hud_bottom.png", "art/processed/action_bar.png", "Meshy_AI_Dark Fantasy MMORPG HUD.png"]
PIECES["hud_left_a"] = HUD_LEFT
PIECES["hud_left_b"] = HUD_LEFT

# Full reference list override (the first image is the one the prompt calls FIRST)
REFS_OVERRIDE = {
    n: ["art/layout_left.png", "Meshy_AI_Dark Fantasy MMORPG HUD.png", "art/processed/orb_frame.png", "art/processed/action_bar.png", "art/processed/xp_strip.png"]
    for n in ("hud_left_a", "hud_left_b")
}
REFS_OVERRIDE["vertical_bar"] = REFS_OVERRIDE_V
REFS_OVERRIDE["vertical_bar_b"] = REFS_OVERRIDE_V
MINIMAP = ("1:1",
    "Generate ONLY a round MINIMAP frame for the top-right corner of the screen, matching exactly the style of the attached unified bottom HUD piece "
    "(slim carved dark stone and blackened iron, thin aged bronze trim, SMALL subtle ornaments, no big gargoyles). "
    "A circular ring frame whose inside is completely flat solid magenta (#FF00FF) where the map will go. "
    "On top of the ring, a small slim horizontal name plate for the zone name (empty, no text). "
    "Around the lower part of the ring, 4 small empty round button sockets evenly placed. "
    "Front view, centered, filling most of the image.")
PIECES["minimap"] = MINIMAP
PIECES["minimap_b"] = MINIMAP
REFS_OVERRIDE["minimap"] = ["art/processed/hud_bottom.png", "art/processed/orb_frame.png", "Meshy_AI_Dark Fantasy MMORPG HUD.png"]
REFS_OVERRIDE["minimap_b"] = REFS_OVERRIDE["minimap"]
MINIMAP_MIN = ("1:1",
    "Generate ONLY a round MINIMAP frame in a MINIMALIST version of the style of the attached pieces: "
    "a THIN, clean circular ring of blackened iron with a single fine aged bronze line on its inner edge and one on its outer edge, "
    "smooth surface with no engravings, no runes, no filigree, no spikes, no crests, no decorations at all. "
    "The inside of the ring is completely flat solid magenta (#FF00FF). "
    "On top of the ring, a small slim plain rectangular name plate with rounded ends (empty, no text). "
    "Around the lower part of the ring, 4 SMALL plain round button sockets sitting on the ring. "
    "Front view, centered, filling most of the image.")
PIECES["minimap_min"] = MINIMAP_MIN
PIECES["minimap_min_b"] = MINIMAP_MIN
REFS_OVERRIDE["minimap_min"] = ["art/processed/minimap.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["minimap_min_b"] = REFS_OVERRIDE["minimap_min"]
INVENTORY = ("9:16",
    "Generate ONLY one tall vertical INVENTORY WINDOW frame, matching exactly the style of the attached HUD pieces "
    "(slim carved dark stone, blackened iron, thin aged bronze trim) but with SMALL, subtle ornaments only, no big gargoyles, no roots, no spikes. Clean and readable. "
    "Layout from top to bottom: "
    "(1) a slim title plate at the top center (empty, no text); "
    "(2) the CHARACTER section: a tall empty dark recessed area in the center for the 3D character model, with a column of 6 empty square equipment slots on its left and a column of 6 on its right, "
    "and 2 tall empty weapon slots side by side centered below the character area; "
    "(3) a thin horizontal row of 5 small empty tab plates; "
    "(4) the BAGS section: a grid of exactly 8 columns by 6 rows of identical empty square item slots, with a thin vertical scrollbar track on the right side of the grid; "
    "(5) a footer: a row of 5 small empty bag slots on the left and a small empty plate on the right for the gold counter. "
    "All slots are empty dark recesses with thin bronze edges. Front view, flat, centered, filling most of the image height.")
PIECES["inventory"] = INVENTORY
PIECES["inventory_b"] = INVENTORY
REFS_OVERRIDE["inventory"] = ["art/processed/hud_bottom.png", "art/processed/vertical_bar_double.png", "art/processed/target_frame.png"]
REFS_OVERRIDE["inventory_b"] = REFS_OVERRIDE["inventory"]
INVENTORY2 = ("9:16",
    "The FIRST attached image is an inventory window. Redraw it keeping exactly the same style, materials, proportions, tabs row, 8x6 bag grid with scrollbar, and footer, "
    "but change ONLY the character section: it must have exactly 8 identical square equipment slots in a vertical column on the left side and exactly 8 on the right side "
    "(make the slots slightly smaller so 8 fit), with the tall empty dark recessed character model area between them, "
    "and exactly 3 weapon slots side by side centered below the character area (the middle one can be the same size as the others). "
    "Keep ornaments small and subtle. No text anywhere. Flat solid magenta background.")
PIECES["inventory2"] = INVENTORY2
PIECES["inventory2_b"] = INVENTORY2
REFS_OVERRIDE["inventory2"] = ["art/meshy/inventory.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["inventory2_b"] = REFS_OVERRIDE["inventory2"]
INVENTORY3 = ("9:16",
    "The FIRST attached image is an inventory window. Redraw it keeping exactly the same style, materials, proportions, tabs row, 8x6 bag grid with scrollbar, and footer. "
    "Change ONLY the character section: on the LEFT of the character model area put a block of 2 columns by 4 rows of identical square equipment slots (8 slots), "
    "and on the RIGHT of the character model area put another block of 2 columns by 4 rows of identical square equipment slots (8 slots). "
    "The tall empty dark recessed character model area stays in the middle between the two blocks, "
    "and below it exactly 3 square weapon slots side by side, centered. "
    "Keep ornaments small and subtle. No text anywhere. Flat solid magenta background.")
PIECES["inventory3"] = INVENTORY3
PIECES["inventory3_b"] = INVENTORY3
REFS_OVERRIDE["inventory3"] = ["art/meshy/inventory2_b.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["inventory3_b"] = REFS_OVERRIDE["inventory3"]






MIN = "matching exactly the style and colors of the attached HUD pieces (carved dark grey stone, blackened iron, thin aged bronze trim), but MINIMALIST: very small, subtle ornaments only, clean silhouette, no gargoyles, no roots, no spikes, no runes. "
REFS_MIN = ["art/processed/hud_bottom.png", "art/processed/target_frame.png", "art/processed/inventory.png"]
PIECES["unit_small"] = ("16:9", "Generate ONLY a SMALL compact unit frame for a pet or target-of-target, " + MIN +
    "Left: a small circular portrait ring whose inside is flat solid magenta (#FF00FF). Attached to its right: a short slim horizontal plate with "
    "an empty name area on top, one empty health bar groove below it and one thinner empty power bar groove under that. Front view, centered, filling most of the image width.")
PIECES["focus_frame"] = ("16:9", "Generate ONLY a medium unit frame for a focus target, " + MIN +
    "Left: a circular portrait ring whose inside is flat solid magenta (#FF00FF). Attached to its right: a slim horizontal plate with "
    "an empty name area on top, one empty health bar groove and one thinner empty power bar groove under it. It is a simpler, smaller sibling of the attached target frame. Front view, centered, filling most of the image width.")
PIECES["castbar"] = ("16:9", "Generate ONLY a long thin horizontal CAST BAR frame, " + MIN +
    "On the left end, a small square socket for the spell icon (empty dark). To its right, one long slim empty bar groove (dark recess) framed by a thin bronze edge. "
    "Front view, centered, spanning most of the image width, thin.")
PIECES["gem_socket"] = ("1:1", "Generate ONLY one small diamond-shaped (rhombus, rotated square) gem SOCKET for a class resource point, " + MIN +
    "Blackened iron diamond setting with a thin bronze rim, the center is an EMPTY dark recess. Front view, centered, filling most of the image.")
PIECES["gem_lit"] = ("1:1", "Generate ONLY one small diamond-shaped (rhombus, rotated square) GEM set in its socket, " + MIN +
    "Blackened iron diamond setting with a thin bronze rim, holding a glowing faceted golden-amber gem with a soft warm inner glow. Front view, centered, filling most of the image.")
MM_THIN = ("1:1", "Generate ONLY a round MINIMAP frame, " + MIN +
    "The ring is VERY THIN: its thickness is only about 3 percent of its diameter, like a slim border made of blackened iron with a fine aged bronze line on its inner and outer edges and a subtle carved stone texture. "
    "The inside of the ring is completely flat solid magenta (#FF00FF). On top, a small slim stone name plate with bronze edge (empty, no text). "
    "On the lower part of the ring, 4 SMALL round iron button sockets with bronze rims, evenly spaced. Front view, centered, filling most of the image.")
PIECES["minimap_thin"] = MM_THIN
PIECES["minimap_thin_b"] = MM_THIN
for _n in ("unit_small","focus_frame","castbar","gem_socket","gem_lit","minimap_thin","minimap_thin_b"):
    REFS_OVERRIDE[_n] = REFS_MIN

PIECES["connector"] = ("16:9",
    "The FIRST attached image shows part of a game HUD: on the left a 3x3 menu panel, on the right the start of an action bar, and a wide empty magenta GAP between them. "
    "Redraw the image keeping the left panel and the right action bar exactly as they are, and fill the gap with a natural, seamless continuation of the low carved dark stone backing that connects them: "
    "same height as the backing at the gap edges, same flat top edge with a thin continuous aged bronze trim line, cracked dark stone surface with very subtle minimal carved detail, no slots, no ornaments, no gargoyles, no roots. "
    "The fill must be horizontally uniform so it can be tiled. Keep the magenta background everywhere else.")
REFS_OVERRIDE["connector"] = ["art/gap_ref.png", "art/processed/hud_bottom.png"]
PIECES["connector_b"] = PIECES["connector"]
REFS_OVERRIDE["connector_b"] = REFS_OVERRIDE["connector"]

# Extra style references (besides the main HUD image) for pieces that must match the already generated parts
EXTRA_REFS = {
    "base_plate": ["art/processed/orb_frame.png", "art/processed/side_panel.png", "art/processed/action_bar.png"],
    "bridge": ["art/processed/orb_frame.png", "art/processed/side_panel.png", "art/processed/action_bar.png"],
}


def data_uri(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def run(name, ref_uri):
    aspect, desc = PIECES[name]
    body = {
        "ai_model": MODEL,
        "prompt": STYLE + desc + ISOLATE,
        "reference_image_urls": [data_uri(ROOT / p) for p in REFS_OVERRIDE[name]] if name in REFS_OVERRIDE
                                else [ref_uri] + [data_uri(ROOT / p) for p in EXTRA_REFS.get(name, [])],
        "aspect_ratio": aspect,
    }
    r = requests.post(API, headers=HEADERS, data=json.dumps(body), timeout=120)
    if r.status_code >= 300:
        return name, f"create failed {r.status_code}: {r.text[:300]}"
    task = r.json()["result"]
    for _ in range(180):
        time.sleep(5)
        t = requests.get(f"{API}/{task}", headers=HEADERS, timeout=60).json()
        if t["status"] == "SUCCEEDED":
            img = requests.get(t["image_urls"][0], timeout=120).content
            (OUT / f"{name}.png").write_bytes(img)
            return name, f"ok ({t.get('consumed_credits')} credits)"
        if t["status"] in ("FAILED", "CANCELED"):
            return name, f"{t['status']}: {t.get('task_error')}"
    return name, "timeout"


def main():
    names = sys.argv[1:] or list(PIECES)
    OUT.mkdir(parents=True, exist_ok=True)
    ref_uri = data_uri(REF)
    with ThreadPoolExecutor(max_workers=len(names)) as ex:
        for name, status in ex.map(lambda n: run(n, ref_uri), names):
            print(f"{name}: {status}", flush=True)


if __name__ == "__main__":
    main()
