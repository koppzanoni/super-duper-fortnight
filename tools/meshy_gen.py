"""Generate the HUD texture pieces with Meshy image-to-image, using the reference HUD image for style.

Usage: python tools/meshy_gen.py [piece ...]   (no args = all pieces)
The API key comes from the MESHY_API_KEY environment variable, else the file named by MESHY_KEY_FILE,
else .meshy-key.txt in the project root (never committed); with none of them the requests go without
it (a cloud session's network secret adds it). Outputs go to art/meshy/<piece>.png
"""
import base64
import json
import pathlib
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import os

import requests

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _key():
    """The API key, or None: in a cloud session the environment's network secret for api.meshy.ai adds
    it to the requests itself (and a key the script sends is dropped on the way)."""
    if os.environ.get("MESHY_API_KEY"):
        return os.environ["MESHY_API_KEY"].strip()
    path = pathlib.Path(os.environ.get("MESHY_KEY_FILE") or ROOT / ".meshy-key.txt")
    return path.read_text().strip() if path.exists() else None


KEY = _key()
REF = ROOT / "Meshy_AI_Dark Fantasy MMORPG HUD.png"
OUT = ROOT / "art" / "meshy"
API = "https://api.meshy.ai/openapi/v1/image-to-image"
MODEL = "nano-banana-2"
HEADERS = {"Content-Type": "application/json", **({"Authorization": f"Bearer {KEY}"} if KEY else {})}

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

# Vertical action bars, redesign: two styles x one/two columns. The slots must be evenly spaced
# identical squares so the buttons can be laid over them.
VB_SLOTS = {
    1: "exactly ONE single column of exactly 12 identical empty square slots stacked top to bottom, evenly spaced (NOT a grid, only one slot wide)",
    2: "exactly TWO side by side columns of exactly 12 identical empty square slots each (24 slots), evenly spaced in a regular grid",
}
VB_STYLE = {
    "ornate": "Its top and bottom ends are carved end caps with the same organic sculpted dark stone curves and small aged bronze crest as the "
              "3x3 menu panels and orb frames of the attached HUD, so it clearly belongs to the same set; the long sides are slim carved stone rails "
              "with a thin bronze trim line. Ornaments only at the ends and kept small, no gargoyles, no roots.",
    "slim": "A slim, clean carved dark stone frame with a thin aged bronze inner trim around the slots, like the frame of the action bar of the attached HUD; "
            "only tiny bronze corner fittings at the top and bottom ends, no crests, no gargoyles, no roots.",
}
for _style, _desc in VB_STYLE.items():
    for _cols, _slots in VB_SLOTS.items():
        _p = ("9:16",
              "Generate ONLY one tall, NARROW VERTICAL action bar frame for the right edge of the screen, matching exactly the materials and colors "
              "of the attached bottom HUD (carved dark grey stone, blackened iron, aged bronze trim). It holds " + _slots + ". "
              + _desc + " The frame spans most of the image height and is only as wide as it needs to be, centered horizontally; "
              "everything else is flat magenta background. Slots are empty dark recesses with thin bronze edges, no icons.")
        for _suffix in ("", "_b"):
            _n = f"vbar_{_style}{_cols}{_suffix}"
            PIECES[_n] = _p
            REFS_OVERRIDE[_n] = ["art/processed/hud_bottom.png", "art/processed/side_panel.png", "art/processed/action_bar.png"]

# Orb cap redesign: a dragon wing embracing the orb instead of the gargoyle, filling the space
# out to the screen edge. Only the wing is used: the ring and the 3x3 panel are pasted back.
CAP_WING = ("16:9",
    "The FIRST attached image is the left end of a game HUD: a round orb ring frame, a sculpted gargoyle figure on its left, "
    "and a 3x3 menu panel on its right. Redraw it keeping the orb ring and the 3x3 panel EXACTLY as they are (same position, size, shape and details), "
    "but REMOVE the gargoyle figure completely and replace it with ONE large, majestic dragon wing that embraces the orb ring from behind: "
    "the wing's bony arm arches over the top-left of the ring with a small claw near the top, its long finger bones curve down and around the left side of the ring, "
    "and the leathery membrane between them fills ALL the space to the left of and behind the ring. "
    "The wing must fill the left area completely with no gaps: its outer edge is a straight vertical cut exactly at the left image edge, "
    "from the bottom of the image up to the top of the ring, and it fills down to the bottom edge. "
    "Material: carved dark grey stone and blackened iron with thin aged bronze trim on the bones, exactly like the ring, with subtle scales and veins. "
    "The inside of the ring stays flat solid magenta (#FF00FF), and everything above and around that is not part of the HUD is flat magenta too.")
PIECES["cap_wing"] = CAP_WING
PIECES["cap_wing_b"] = CAP_WING
REFS_OVERRIDE["cap_wing"] = ["art/cap_ref.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["cap_wing_b"] = REFS_OVERRIDE["cap_wing"]
# Second try: the first wings were drawn over the orb. This one stays outside the opening.
CAP_WING2 = ("16:9",
    "The FIRST attached image is the left end of a game HUD: a round orb ring frame, a sculpted gargoyle figure on its left, "
    "and a 3x3 menu panel on its right. Redraw it keeping the orb ring and the 3x3 panel EXACTLY as they are (same position, size, shape and details). "
    "REMOVE the gargoyle and put in its place a SLIM, compact folded dragon wing that occupies only the narrow strip where the gargoyle was, "
    "between the left image edge and the outer edge of the ring: the wing's bony arm comes out from behind the ring at its upper left with a small claw, "
    "runs down the left side, and its finger bones curve along the outside of the ring like a hand holding it; the leathery membrane between the bones "
    "fills that strip completely down to the bottom of the image, with its outer edge a straight vertical line exactly at the left image edge. "
    "The wing may overlap the outer rim of the ring slightly, but it must NEVER enter the round opening of the ring: the whole round opening stays "
    "completely empty flat solid magenta (#FF00FF). The wing is small compared to the ring. "
    "Material: carved dark grey stone and blackened iron with thin aged bronze trim on the bones, exactly like the ring, subtle scales and veins. "
    "Everything that is not part of the HUD is flat solid magenta (#FF00FF).")
PIECES["cap_wing2"] = CAP_WING2
PIECES["cap_wing2_b"] = CAP_WING2
REFS_OVERRIDE["cap_wing2"] = REFS_OVERRIDE["cap_wing"]
REFS_OVERRIDE["cap_wing2_b"] = REFS_OVERRIDE["cap_wing"]
# Third step, from the chosen wing (cap_wing2_b composed): the 3x3 panel's side figures become
# small folded wings, and a stone backing fills the screen edge behind the big wing.
CAP_PANEL = ("16:9",
    "The FIRST attached image is the left end of a game HUD: a dragon wing at the far left wrapping a round orb ring, and a square 3x3 menu panel on the right. "
    "Redraw it keeping the dragon wing, the orb ring and the 3x3 grid of square slots EXACTLY as they are (same position, size, shape and details). Change only two things: "
    "(1) Replace the two twisted sculpted figures on the left and right sides of the 3x3 panel with two SMALL FOLDED dragon wings, one on each side, mirrored, "
    "in exactly the same style and material as the big dragon wing (bony arm with a small claw on top, membrane folded down along the panel side), "
    "framing the panel neatly; keep the panel's top ornament and frame. "
    "(2) Behind the big dragon wing, add a solid backing of carved dark grey stone with thin aged bronze trim that fills ALL the empty space between the wing and the left image edge, "
    "from the bottom edge of the image up to the top of the ring, its outer edge a straight vertical line exactly at the left image edge, so no background shows between the wing and the left edge. "
    "The inside of the ring stays flat solid magenta (#FF00FF); everything that is not part of the HUD is flat solid magenta (#FF00FF).")
PIECES["cap_panel"] = CAP_PANEL
PIECES["cap_panel_b"] = CAP_PANEL
REFS_OVERRIDE["cap_panel"] = ["art/cap_ref2.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["cap_panel_b"] = REFS_OVERRIDE["cap_panel"]

PIECES["connector"] = ("16:9",
    "The FIRST attached image shows part of a game HUD: on the left a 3x3 menu panel, on the right the start of an action bar, and a wide empty magenta GAP between them. "
    "Redraw the image keeping the left panel and the right action bar exactly as they are, and fill the gap with a natural, seamless continuation of the low carved dark stone backing that connects them: "
    "same height as the backing at the gap edges, same flat top edge with a thin continuous aged bronze trim line, cracked dark stone surface with very subtle minimal carved detail, no slots, no ornaments, no gargoyles, no roots. "
    "The fill must be horizontally uniform so it can be tiled. Keep the magenta background everywhere else.")
REFS_OVERRIDE["connector"] = ["art/gap_ref.png", "art/processed/hud_bottom.png"]
PIECES["connector_b"] = PIECES["connector"]
REFS_OVERRIDE["connector_b"] = REFS_OVERRIDE["connector"]

# Whole-screen concept for approval before any piece is redrawn: the inventory window and the
# complete bottom HUD redesigned together, on the game scene (not an isolated asset).
PIECES["concept_full"] = ("16:9",
    "The first attached image is a screenshot of our current game UI: an inventory window (attributes column on the left, "
    "character model with 8 equipment slots on each side and 3 weapon slots below, then a bag grid of 8 columns with "
    "filter tabs, a search box, Reputation and Currency buttons and the gold amount) and, at the bottom of the screen, the HUD "
    "(red health orb on the left, blue mana orb on the right, each embraced by a dragon wing, a 3x3 grid of menu slots beside "
    "each orb, and a central action bar of 2 rows of 18 slots with an experience bar under it). "
    "Redesign BOTH the inventory window and the complete bottom HUD as one cohesive, much more beautiful Path of Exile 2 style "
    "interface: same layout, same number of slots and the same elements in the same places, but refined art: carved dark "
    "stone, blackened iron, thin aged bronze trim, elegant gothic filigree, clean readable panels, consistent borders, "
    "no stretched or mismatched pieces. Keep the orbs filled with red and blue liquid. Show the full 16:9 game screen with the "
    "dark fantasy scene behind, like a polished game screenshot. No text other than the existing labels. "
    "Use the second attached image as the art style guide (materials, colors, lighting, level of detail).")
REFS_OVERRIDE["concept_full"] = ["art/concept_ref.png", "Meshy_AI_Dark Fantasy MMORPG HUD.png"]
# Second try: the screenshot reference made Meshy copy the current UI, so only the style image
# goes along and the layout is described in words, asking for a fresh design.
PIECES["concept_bold"] = ("16:9",
    "Design a brand new, striking dark fantasy game UI in the style of Path of Exile 2, shown as a full 16:9 game screenshot "
    "with a dark gothic graveyard scene behind. Do NOT copy the attached image's layout: it is ONLY a guide for materials and colors "
    "(carved dark stone, blackened iron, aged bronze, deep shadows). Invent new silhouettes and ornaments. "
    "Contents: (1) An open INVENTORY window on the right half of the screen, grand and ornate, shaped like a carved stone reliquary "
    "or gothic altar with a pointed arch crown, chains or spikes on the corners: an attributes column at its left, in the center "
    "the character standing inside an arched alcove with 8 equipment slots down each side and 3 weapon slots below, under it a "
    "bag grid of 8 columns by 6 rows of item slots with a row of filter tabs above, and a footer with 5 bag slots and the gold amount. "
    "(2) The BOTTOM HUD across the full screen width, with a completely new shape: a big red health orb in the bottom left and a big "
    "blue mana orb in the bottom right, each held by a dramatic sculpture (dragon claws, bone wings or a demon skull), "
    "a 3x3 grid of small menu slots next to each orb, and in the center an action bar of 2 rows of 18 square slots with a thin "
    "experience bar below. Slots show skill icons. Rich, detailed, cohesive, premium AAA quality. Minimal text, no watermark.")
REFS_OVERRIDE["concept_bold"] = ["Meshy_AI_Dark Fantasy MMORPG HUD.png"]
NO_ISOLATE = {"concept_full", "concept_bold"}

# Approved redesign (concept_bold): the orb caps at our real layout. The first reference is the
# current cap (orb ring, 3x3 panel, stone to the screen edge) for geometry; the second is the
# concept's orb for style. Both are drawn as the LEFT cap; the mana one is mirrored in game.
CAP_KEEP = (
    "The FIRST attached image is the left end of our game HUD on magenta: a round orb ring, a 3x3 grid of square menu slots on its right, "
    "and dark stone filling the area out to the left image edge. Redraw this whole piece in the art style of the SECOND attached image, "
    "keeping the exact geometry of the first: the round opening of the orb ring at exactly the same position and size, the 9 square slots "
    "at exactly the same positions and sizes, the same overall outline and the same bottom edge. "
    "The round opening of the ring stays completely EMPTY flat solid magenta (#FF00FF): nothing is drawn inside it, no liquid, no glass, no claws, no wings. "
    "The slots are empty dark recesses, no icons. The stone backing still fills all the space out to the left image edge with a straight vertical edge. "
    "Material: carved dark stone, blackened iron, thin aged bronze trim with fine runes on the ring, like the second image. ")
PIECES["cap_claws"] = ("16:9", CAP_KEEP +
    "Ornament: huge dark bone-and-iron CLAWS grip the orb ring FROM ABOVE ONLY, the long curved talons wrapping over the top and the upper left "
    "of the ring like a monster's hand holding it, ending on the outer rim. There are NO claws, fingers or talons at the bottom of the ring: the "
    "lower half of the ring is clean. Everything that is not part of the HUD is flat solid magenta (#FF00FF).")
REFS_OVERRIDE["cap_claws"] = ["art/cap_ref3.png", "art/concept_orb_health.png"]
PIECES["cap_dragon"] = ("16:9", CAP_KEEP +
    "Ornament: a dark stone and iron DRAGON coils around the OUTSIDE of the orb ring: its horned head rests on the top of the ring, "
    "its bat wing spreads along the left side behind the ring, its tail and claws curl around the outer rim at the bottom. The dragon never "
    "enters the round opening. Everything that is not part of the HUD is flat solid magenta (#FF00FF).")
REFS_OVERRIDE["cap_dragon"] = ["art/cap_ref3.png", "art/concept_orb_mana.png"]
NO_ISOLATE |= {"cap_claws", "cap_dragon"}

# Enemy nameplates and party frames, one per theme ("classic" = current art, "reliquary" = the
# approved concept_bold redesign). Bar grooves and the portrait opening are left magenta: the
# addon draws the bars and the portrait inside them.
NAMEPLATE = (
    "Generate ONLY one enemy NAMEPLATE health bar frame for a dark fantasy game, seen flat from the front: a long thin horizontal "
    "frame about 8 times wider than tall, with a long empty groove for the health bar inside it (the groove is flat solid magenta #FF00FF), "
    "a small ornament at each end and a small socket on the left end for a level number. Elegant and readable at small size. "
    "Everything that is not part of the frame is flat solid magenta (#FF00FF). No text, no numbers. ")
PARTY = (
    "Generate ONLY one PARTY MEMBER unit frame for a dark fantasy game, seen flat from the front: a compact horizontal frame about "
    "3 times wider than tall, with a round portrait ring on the left (the inside of the ring is flat solid magenta #FF00FF) and on its "
    "right two stacked empty bar grooves, a thicker one for health and a thinner one for mana (both grooves flat solid magenta #FF00FF), "
    "with a narrow plate above them for the name. Everything that is not part of the frame is flat solid magenta (#FF00FF). "
    "No text, no numbers, no portrait. ")
CLASSIC = ("Match EXACTLY the art style of the attached images (our current HUD): carved dark grey stone, blackened iron, "
           "thin aged bronze trim, small gothic filigree, same colors and lighting.")
RELIQUARY = ("Match EXACTLY the art style of the attached images (our new HUD): carved dark stone, blackened iron, aged bronze "
             "trim with fine runes, spikes and small bone claws, gothic reliquary look, same colors and lighting.")
PIECES["nameplate_classic"] = ("16:9", NAMEPLATE + CLASSIC)
PIECES["nameplate_reliquary"] = ("16:9", NAMEPLATE + RELIQUARY)
PIECES["party_classic"] = ("16:9", PARTY + CLASSIC)
PIECES["party_reliquary"] = ("16:9", PARTY + RELIQUARY)
REFS_OVERRIDE["nameplate_classic"] = ["art/processed/target_frame.png", "art/processed/hud_bottom.png"]
REFS_OVERRIDE["party_classic"] = REFS_OVERRIDE["nameplate_classic"]
REFS_OVERRIDE["nameplate_reliquary"] = ["art/concept_inventory.png", "art/meshy/cap_claws.png"]
REFS_OVERRIDE["party_reliquary"] = REFS_OVERRIDE["nameplate_reliquary"]
NO_ISOLATE |= {"nameplate_classic", "nameplate_reliquary", "party_classic", "party_reliquary"}

# Second try from scratch (the user rejected the first four): one style reference only, so
# Meshy invents the shape instead of copying our frames.
NAMEPLATE2 = (
    "Design from scratch ONE enemy NAMEPLATE for a dark fantasy action RPG like Path of Exile 2: the small health bar that floats above "
    "an enemy's head. It is a very THIN, LONG horizontal bar frame, about 10 times wider than tall, with NO portrait and NO ring: "
    "a slim frame around one long empty health groove (the groove is flat solid magenta #FF00FF), a tiny diamond socket at the left end "
    "for the level, and small pointed ornaments at both ends. Sleek, minimal and readable at small size. Centered, flat front view. ")
PARTY2 = (
    "Design from scratch ONE PARTY MEMBER frame for a dark fantasy action RPG like Path of Exile 2, meant to be stacked 4 in a column "
    "at the top left of the screen: compact, about 4 times wider than tall, clearly different from a big target frame. A small "
    "portrait socket on the left (a rounded square or shield shape, its inside flat solid magenta #FF00FF), and on the right one "
    "health bar groove and a thin mana groove just below it (both flat solid magenta #FF00FF), with a thin strip above for the name. "
    "Clean and elegant, with small ornaments only. Centered, flat front view. ")
TAIL = "Everything that is not part of the frame is flat solid pure magenta (#FF00FF), evenly flat with no gradient. No text, no numbers, no icons. "
CLASSIC2 = ("Use the attached image ONLY as the art style guide (not its shapes): carved dark grey stone, blackened iron, thin aged bronze trim, "
            "small gothic filigree.")
RELIQUARY2 = ("Use the attached image ONLY as the art style guide (not its shapes): carved dark stone, blackened iron, aged bronze trim "
              "with fine runes, small spikes and bone claws, gothic reliquary look.")
for kind, base in (("nameplate", NAMEPLATE2), ("party", PARTY2)):
    PIECES[kind + "2_classic"] = ("16:9", base + TAIL + CLASSIC2)
    PIECES[kind + "2_reliquary"] = ("16:9", base + TAIL + RELIQUARY2)
    REFS_OVERRIDE[kind + "2_classic"] = ["Meshy_AI_Dark Fantasy MMORPG HUD.png"]
    REFS_OVERRIDE[kind + "2_reliquary"] = ["art/meshy/concept_bold.png"]
    NO_ISOLATE |= {kind + "2_classic", kind + "2_reliquary"}

# Third try, from scratch with no art direction (the user asked for a completely new design
# "for World of Warcraft"): the only reference is a blank magenta canvas for the background.
FREE_TAIL = (" The attached image is only the background color: put the frame on that flat solid pure magenta (#FF00FF), "
             "the whole background evenly flat magenta with no scene, no floor, no gradient, no shadow. "
             "Front view, flat, centered. No text, no numbers, no icons, no portrait.")
FREE = {
    "nameplate_free": "A beautiful, high quality enemy nameplate health bar frame for a World of Warcraft UI addon: the bar shown above an enemy's head. "
                      "The empty area where the health fills is flat solid magenta (#FF00FF).",
    "party_free": "A beautiful, high quality party member unit frame for a World of Warcraft UI addon, shown stacked at the top left of the screen: "
                  "room for a portrait, the name, a health bar and a mana bar. The portrait area and the bar areas are flat solid magenta (#FF00FF).",
}
for name, desc in FREE.items():
    for v in ("a", "b"):
        PIECES[f"{name}_{v}"] = ("16:9", desc + FREE_TAIL)
        REFS_OVERRIDE[f"{name}_{v}"] = ["art/blank_magenta.png"]
        NO_ISOLATE.add(f"{name}_{v}")

# Player cast bar matching the chosen unit frame (party frame B); the reference is that frame
# alone on magenta, for style only.
PIECES["castbar_free"] = ("16:9",
    "A beautiful, high quality player CAST BAR frame for a World of Warcraft UI addon, shown above the action bars while casting a spell: "
    "a long thin horizontal bar frame about 9 times wider than tall, with a small ROUND socket at its left end for the spell icon "
    "(the inside of the socket is flat solid magenta #FF00FF) and one long empty groove for the cast progress (flat solid magenta #FF00FF). "
    "Use the attached image ONLY as the art style guide, not its shape: the same aged bronze with celtic knotwork, the same rim and "
    "dark iron, the same small dragon ornament curling around the round socket. "
    "Put the frame on flat solid pure magenta (#FF00FF), the whole background evenly flat magenta with no scene, no floor, no gradient, "
    "no shadow. Front view, flat, centered. No text, no numbers, no icons.")
REFS_OVERRIDE["castbar_free"] = ["art/castbar_style_ref.png"]
NO_ISOLATE.add("castbar_free")

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
        "prompt": desc if name in NO_ISOLATE else STYLE + desc + ISOLATE,
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


# "Moderno" style (2026-10-23): modern, clean, minimal. Only a blank magenta canvas as reference,
# the style is described in words (a style image made Meshy copy its ornaments).
MODERN = (
    "Style: modern, clean and minimal sci-fi fantasy UI, like a premium modern MMO interface. "
    "Flat dark navy blue translucent glass panels with slightly rounded corners, a single thin crisp glowing "
    "light blue edge line with a soft subtle glow, very subtle inner gradient. Almost no gold: at most one very fine "
    "thin gold hairline. NO ornaments, no filigree, no wings, no spikes, no gems, no stone, no metal engravings. "
    "Sharp, high quality, high resolution, perfectly clean vector-like edges. "
    "Put it on flat solid pure magenta (#FF00FF): the whole background evenly flat magenta, no scene, no shadow, "
    "no gradient. Front view, flat, orthographic, centered. No text, no numbers, no letters, no icons.")
PIECES["modern_unit"] = ("16:9",
    "A player unit frame for a World of Warcraft UI addon. On the left a circular portrait ring (thin glowing blue "
    "ring with a very fine gold hairline outside) whose inside is flat solid magenta (#FF00FF), with a tiny round "
    "level badge on its lower left edge. Attached to its right, a slim horizontal panel holding an empty space for "
    "the name on top, one long empty health bar groove and under it one thinner empty mana bar groove; the grooves "
    "are flat solid magenta (#FF00FF) inside, framed by thin blue lines. About 3.5 times wider than tall, filling "
    "most of the image width. " + MODERN)
PIECES["modern_bar"] = ("16:9",
    "A short segment of an action bar for a World of Warcraft UI addon: ONE single horizontal row of exactly 4 "
    "identical empty square button slots with slightly rounded corners, evenly spaced, inside one slim panel, "
    "with a clean left end and a clean right end of the panel (small simple chamfered ends, no decoration). "
    "The inside of each slot is flat solid magenta (#FF00FF), framed by a thin blue line. " + MODERN)
PIECES["modern_cast"] = ("16:9",
    "A player cast bar for a World of Warcraft UI addon: a long thin horizontal bar about 9 times wider than tall. "
    "At its left end a small square socket with slightly rounded corners for the spell icon (inside flat solid "
    "magenta #FF00FF), to its right one long slim empty progress groove (inside flat solid magenta #FF00FF) framed "
    "by a thin glowing blue line, all on one slim dark navy translucent panel. Spanning most of the image width. " + MODERN)
for _n in ("modern_unit", "modern_bar", "modern_cast"):
    REFS_OVERRIDE[_n] = ["art/blank_magenta.png"]
    NO_ISOLATE.add(_n)


# "Moderno" from the concept itself (art/concept_modern.png): each piece cropped from it and
# redrawn at high resolution, empty and isolated.
COPY = ("The attached image is a crop of a game UI concept for a World of Warcraft UI addon. Redraw EXACTLY this "
    "UI piece in exactly the same style, colors, materials, line thickness, glow and proportions, as a clean, sharp, "
    "very high quality, high resolution UI texture asset. ")
EMPTY = (" Put it on flat solid pure magenta (#FF00FF): the whole background evenly flat magenta, no game scene, "
    "no shadow, no gradient. Front view, flat, centered, filling most of the image width. "
    "No text, no numbers, no letters, no icons, no character.")
PIECES["modern2_unit"] = ("16:9", COPY +
    "Only the frame: the round portrait ring (keep its look) whose inside is EMPTY flat solid magenta (#FF00FF) with no "
    "portrait, the small round level badge on the ring (empty, no number), and the two bars to its right as EMPTY "
    "grooves: the health bar groove and the mana bar groove are dark and EMPTY, with no green or blue fill, keeping "
    "their thin frame lines. Keep the empty space above the bars where the name goes. Remove the two small buff icons." + EMPTY)
PIECES["modern2_bar"] = ("16:9", COPY +
    "Only the action bar frame, but simpler and cleaner: REMOVE the curved wing ornaments at both ends, REMOVE the "
    "diamond gems at the top and bottom, REMOVE the gold lines. Keep only the dark navy translucent panel with its "
    "thin glowing blue edge line and the square slot frames exactly as they look. Draw ONE single row of exactly 4 "
    "identical EMPTY square slots (the inside of each slot is flat solid magenta #FF00FF), evenly spaced, with the "
    "panel's clean left end and clean right end. No numbers above the slots." + EMPTY)
PIECES["modern2_cast"] = ("16:9", COPY +
    "Only the cast bar frame: the square spell icon socket on the left (inside EMPTY flat solid magenta #FF00FF, no "
    "icon) and the long thin progress bar groove, EMPTY with no blue fill, keeping its thin frame lines and the dark "
    "translucent panel behind it. About 9 times wider than tall." + EMPTY)
for _n, _ref in (("modern2_unit", "art/ref_modern_unit.png"), ("modern2_bar", "art/ref_modern_bar.png"),
                 ("modern2_cast", "art/ref_modern_cast.png")):
    REFS_OVERRIDE[_n] = [_ref]
    NO_ISOLATE.add(_n)


# "Moderno" refinement pass: our own procedural pieces (tools/modern_meshy_inputs.py) redrawn by
# Meshy with premium materials, the shape kept exactly (prompt reviewed with the user).
REFINE = ("The attached image is a finished game UI element for a World of Warcraft UI addon. Redraw it keeping "
    "EXACTLY the same shape, silhouette, proportions, layout, and the position and size of every part: do not move, "
    "add or remove anything. Only upgrade the rendering quality and materials to a premium, polished, modern MMO "
    "interface. Keep the same colors: near-black dark navy, teal-blue lines, gold only where it already is. All "
    "panels are fully OPAQUE, not see-through. NO new ornaments: no filigree, no wings, no gems, no spikes, no runes. "
    "No text, no numbers, no icons. Every area that is flat magenta (#FF00FF) in the attached image stays perfectly "
    "flat magenta: the background and the holes. Front view, flat, orthographic, same framing, sharp, high resolution. ")
PIECES["modern3_unit"] = ("16:9", REFINE +
    "Round portrait ring: a thick dark navy band with a thin teal outer line and a soft light reflection on its top "
    "edge; its inside is a magenta hole. A small round level badge with a thin gold ring on its lower left, empty and "
    "dark inside. Two horizontal bar grooves to the right, the upper (health) thicker than the lower (mana): each is "
    "a dark recessed groove inside a dark navy rim with a thin teal outline. The grooves stay EMPTY and dark, with no "
    "green or blue fill. Material: smooth dark brushed metal, crisp teal edge lines with a faint glow.")
PIECES["modern3_slot"] = ("1:1", REFINE +
    "A single square action button slot with rounded corners: a steel-teal metal border with a fine light top edge "
    "and a thin black inner line; its inside is a magenta hole for the spell icon.")
PIECES["modern3_cast"] = ("16:9", REFINE +
    "A square spell icon socket on the left with a magenta hole inside and tiny arrow tips on its left and bottom "
    "edges; a dark name tab plate with a rounded top right corner above the bar; a long thin progress groove with a "
    "pointed right end. The groove stays EMPTY and dark.")
for _n in ("unit", "slot", "cast"):
    REFS_OVERRIDE["modern3_" + _n] = ["art/modern_in_" + _n + ".png"]
    NO_ISOLATE.add("modern3_" + _n)


# "Aço" (2026-10-25): crafted but modern and subtle steel. Our own steel pieces (tools/steel_art.py,
# drawn on the screen grid) are the moulds: Meshy keeps their shape exactly and redraws the metal.
STEEL = ("The attached image is a finished game UI element for a World of Warcraft UI addon, in steel. Redraw it "
    "keeping EXACTLY the same shape, silhouette, proportions, layout, and the position and size of every part: do "
    "not move, add or remove anything, keep the corner brackets, rivets and plates where they are. Upgrade only the "
    "material and rendering: crafted, finely machined dark graphite steel with brushed grain, crisp polished silver "
    "bevels catching a soft light from the top, fine engraved lines, subtle wear on the edges. Modern and subtle, "
    "premium MMO interface: NO fantasy ornaments, no filigree, no wings, no spikes, no runes, no gems, no gold, no "
    "blue, no color at all besides neutral steel greys. All panels are fully OPAQUE. No text, no numbers, no icons. "
    "Every area that is flat magenta (#FF00FF) in the attached image stays perfectly flat magenta: the background "
    "and the holes. Front view, flat, orthographic, same framing, sharp, high resolution. ")
STEEL_PIECES = {
    "unit": ("16:9", "A unit frame: round portrait ring with a small steel plate on top, a magenta hole inside; "
             "a round level badge on its bottom; a plate on its right with two empty dark bar grooves."),
    "unit_small": ("16:9", "A small unit frame: round portrait ring with a magenta hole inside and a plate on its "
                   "right with two empty dark bar grooves."),
    "cast": ("16:9", "A cast bar: one long plate holding a square spell icon socket (magenta hole) on the left and "
             "one long empty dark progress groove."),
    "slot": ("1:1", "One square action button slot with four small rivets in its corners; magenta hole inside."),
    "map": ("1:1", "A round minimap ring with a small steel plate on top and a magenta hole inside; a slim name "
            "plate with rounded ends above it."),
    "menu": ("16:9", "A long horizontal band with a rounded left end, for a row of menu buttons."),
}
for _n, (_aspect, _desc) in STEEL_PIECES.items():
    PIECES["steel_" + _n] = (_aspect, STEEL + _desc)
    REFS_OVERRIDE["steel_" + _n] = ["art/steel_in_" + _n + ".png"]
    NO_ISOLATE.add("steel_" + _n)


if __name__ == "__main__":
    if sys.argv[1:] == ["steel"]:  # every steel piece, from fresh moulds
        import modern_meshy_inputs
        modern_meshy_inputs.steel()
        sys.argv[1:] = ["steel_" + n for n in STEEL_PIECES]
    main()
