# HUD "Moderno" — design

Approved by the user in the interactive sketch (2026-10-23). Concept: the user's Meshy agent image
`art/concept_modern.png`; the art is drawn by `tools/modern_art.py`, copying the concept's look.

## Intent
A second HUD style next to the stone one (which stays exactly as it is): clean, modern, black
see-through panels with thin neutral lines, round portraits with straight bars. Highly configurable,
like WoW's Edit Mode.

## Decided by the user
- Never replace the other designs: "Moderno" is a setting (`hudTheme`), stone stays the default.
- Black see-through theme everywhere (blue only as an alternative colour, setting `modernColor`).
- Player frame top left; target beside it, mirrored; target of target small, mirrored, under the
  target's portrait; health and mana bars each in their own thick rim (no extra space between).
- Optional purple arcane ring turning in the player's portrait (setting `arcaneRing`).
- Action bar with NO background: only the slots, the key numbers above the first row and small
  diamonds between them. Rows × columns configurable (1–4 × 4–18, at most 36 buttons).
- Cast bar: blue fill, clean animation, latency zone in GREEN at the end (time from
  UNIT_SPELLCAST_SENT to UNIT_SPELLCAST_START, fallback GetNetStats), a thin white mark at the spell
  queue window (CVar SpellQueueWindow, 400 ms), and the latency in ms.
- Round thin minimap with the zone plate, micro menu row bottom right, money under it.
- Wide inventory: character (left) and bags (right) in one frosted black window.
- Edit mode: drag every element, mouse wheel resizes, rows/columns for the bar, reset.

## Mistakes of the stone HUD this must not repeat
- No Blizzard panel functions (HideUIPanel, ShowUIPanel, ToggleCharacter...): reuse the secure
  menu buttons (test_round6 keeps enforcing it).
- Events only through ns.On (an unknown event stopped a whole file once).
- Blizzard re-anchors the cast bar and the minimap: keep ns.Pin and the SetLook / icon hooks.
- Unit values and cast times can be secret in combat: no arithmetic outside pcall (test_static);
  the latency zone hides itself when its math fails.
- Secure buttons move only out of combat (ns.RunOutOfCombat); buttons outside the grid lose their
  key bindings (obEnabled = false).
- New texture files need a full game restart, not /reload.

## Phases
1. Theme setting, art export, frames (player/target/ToT/focus/pet), action bar grid, cast bar with
   latency, minimap, menu row, XP bar, status icons. Preview scene "modern".
2. Edit mode (movers, scale, rows/columns, saved per element).
3. Inventory in the Moderno style.

## Left to the builder
Exact pixel positions of the default layout (from the sketch), how the stone pieces are hidden.
