# Orbes com líquido estilo PoE2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the orb contents with a slow, deep, PoE2-style flowing liquid (flipbook animation), four styles selectable in the addon settings, transparent above the liquid.

**Architecture:** `tools/orb_fluid.py` generates looping grayscale flipbook sheets plus glass/spark textures, exported by `tools/export_textures.py`. `Core/Data.lua` holds the style table, palettes and flipbook math (pure, testable). `HUD/Orbs.lua` builds the layers (status bar body, a clip frame that follows the fill, two crossfading flipbook textures per layer, surface, shadow, glass) and drives them from one `OnUpdate`; `Settings/Settings.lua` adds the style dropdown.

**Tech Stack:** Lua (WoW Forever client, Mainline API), Python 3 + numpy + Pillow (textures), pytest + lupa (`tests/wowstub.lua`).

**Spec:** `docs/superpowers/specs/2026-10-22-orbes-liquido-design.md` (prévia aprovada: `.superpowers/brainstorm/4117-1792723670/content/orbs-estilos-v5.html` — its `STYLE`, `COLORS` and layer code are the visual reference).

## Global Constraints

- No Lua arithmetic or comparison on unit values (health/power can be secret in combat): the level comes only from `StatusBar:SetMinMaxValues/SetValue` and anchors to the fill texture. Never read `GetHeight()` of anything anchored to the fill.
- Empty part of the orb is transparent: no background texture behind the liquid.
- Four styles, keys `"a"` (Redemoinho, default), `"b"` (Energia), `"c"` (Névoa), `"d"` (Parado); both orbs always share the style; saved in `ObsidianUIDB.orbStyle`.
- Flipbooks: 8×8 grid of 128 px frames (1024×1024), 64 frames, seamless loop, played at 7 frames/s with crossfade between consecutive frames.
- Palettes (0–255): Vida deep (12,0,2) body (62,2,7) wisp (230,46,30) line (255,150,110); Mana deep (0,3,16) body (5,22,80) wisp (44,130,245) line (170,220,255).
- Style switch applies immediately (no /reload). Style D has no `OnUpdate`.
- Any new event name must exist in the client's API docs (`Blizzard_APIDocumentationGenerated`, branch `forever`); never call Blizzard panel functions.
- New textures need a full game restart: say so in the final report.

## Review Focus

- A saved `orbStyle` that is missing or not one of a/b/c/d (old or edited SavedVariables) → behaves as "a".
- Changing power type mid-session (druid forms, UNIT_DISPLAYPOWER) → resource orb recolors with the new palette and keeps the current style and animation.
- Switching styles repeatedly → exactly one `OnUpdate` per orb (or none for D); B's sparks are not duplicated; switching back from D resumes animation.
- Health at 0 or full → no Lua errors; the clip frame is anchored, never sized from values.
- Setting "orbText" off still hides the numbers after the rebuild (existing test `test_orb_numbers_can_be_hidden` must keep passing).

---

### Task 1: Flipbook and glass textures

**Files:**
- Modify: `tools/orb_fluid.py` (spike → final: keep `frame`, `sheet`, `glass`; add `spark`)
- Modify: `tools/export_textures.py` (register new textures, drop `swirl`)
- Regenerate: `ObsidianUI/Media/*.tga`, `ObsidianUI/Media/manifest.lua`
- Test: `tests/test_orb_fluid.py`

**Interfaces:**
- Produces: textures in `ns.MediaManifest` named `fluid_a`, `fluid_b`, `fluid_c` (1024×1024), `orb_glass` (256×256), `orb_spark` (32×32); `swirl` removed. Python: `orb_fluid.SIZE == 128`, `GRID == 8`, `FRAMES == 64`, `frame(style, t, grids) -> ndarray[SIZE,SIZE] in 0..1`, `sheet(style) -> RGBA Image`, `glass() -> RGBA Image`, `spark(size=32) -> RGBA Image` (soft round dot, white, alpha falls to 0 at the edge).

- [ ] **Step 1: Write the failing tests**

```python
import numpy as np, orb_fluid as of, export_textures as ex

def test_sheet_size_and_grid():
    for s in "abc":
        assert of.sheet(s).size == (1024, 1024)

def test_loop_is_seamless_and_motion_is_slow():
    rng = np.random.default_rng(3); grids = [rng.random((8, 8)), rng.random((8, 8))]
    first, last = of.frame("a", 0.0, grids), of.frame("a", 1.0, grids)
    step = of.frame("a", 1 / of.FRAMES, grids)
    assert np.abs(first - last).max() < 1e-6
    assert np.abs(first - step).mean() < 0.06   # neighbouring frames are close (slow, smooth)

def test_mist_style_is_mostly_dark():
    a = np.asarray(of.sheet("c"))[..., 3] / 255
    assert a.mean() < 0.45

def test_spark_is_a_soft_dot():
    a = np.asarray(of.spark())[..., 3]
    assert a[16, 16] > 200 and a[0, 0] == 0

def test_export_registers_orb_textures_and_drops_swirl(tmp_path):
    e = ex.export_all(tmp_path)
    assert {"fluid_a", "fluid_b", "fluid_c", "orb_glass", "orb_spark"} <= set(e)
    assert e["fluid_a"]["potW"] == 1024 and "swirl" not in e
```

- [ ] **Step 2: Run** `python -m pytest -q tests/test_orb_fluid.py` — Expected: FAIL (`spark` missing, export lacks fluid_*).

- [ ] **Step 3: Implement** `spark()` in `tools/orb_fluid.py`; in `export_textures.py` import `orb_fluid` and save `fluid_a/b/c` via `orb_fluid.sheet`, `orb_glass` via `orb_fluid.glass`, `orb_spark` via `orb_fluid.spark` (no `defringe`/`fit` on the sheets: frames must stay exactly 128 px); remove `swirl` from `PROCEDURAL`. If the mist test fails, raise `STYLES["c"]["gamma"]`.

- [ ] **Step 4: Run** `python tools/export_textures.py` then `python -m pytest -q tests` — Expected: all pass (fix any test that referenced `swirl`).

- [ ] **Step 5: Commit** `feat: orb fluid flipbooks, glass and spark textures`

### Task 2: Style table, palettes and flipbook math

**Files:**
- Modify: `ObsidianUI/Core/Data.lua` (after `Data.PowerColor`)
- Modify: `ObsidianUI/Core/Init.lua` (`DEFAULTS.orbStyle = "a"`)
- Test: `tests/test_orbs_liquid.py`

**Interfaces:**
- Produces:
  - `Data.ORB_STYLE_ORDER = { "a", "b", "c", "d" }`, `Data.ORB_STYLE_LABELS = { a = "Redemoinho", b = "Energia", c = "Névoa", d = "Parado" }`.
  - `Data.ORB_STYLES[key]` with fields `sheet` (manifest name), `fps`, `wisp`, `wisp2`, `spin`, `spin2`, `core`, `sparks` (bool), `still` (bool), `stillFrame`. Values (from prévia v5): a = fluid_a, 7, 0.62, 0.22, 0.05, -0.03, 0, false, false; b = fluid_b, 7, 0.70, 0.30, 0.08, -0.045, 0.5, true, false; c = fluid_c, 7, 0.55, 0, 0.02, 0, 0, false, false; d = fluid_a, 0, 0.62, 0.22, 0, 0, 0, false, true, stillFrame 21.
  - `Data.OrbStyle(key) -> key` returns key if it is in `ORB_STYLES`, else `"a"`.
  - `Data.FlipbookCoords(i) -> left, right, top, bottom` for frame `i` (0-based, wraps mod 64) in the 8×8 sheet.
  - `Data.OrbPalette(token) -> { deep = {r,g,b}, body = {r,g,b}, wisp = {r,g,b}, line = {r,g,b} }` (0..1). `"HEALTH"` and `"MANA"` return the spec values /255 exactly. Any other token: from `Data.PowerColor(token)` = c: deep = c×0.08, body = c×0.35, wisp = c + (1−c)×0.10, line = c + (1−c)×0.55.

- [ ] **Step 1: Write the failing tests** (use `load_addon_file(rt, "Core/Data.lua", rt.table())` like `tests/test_data.py`)

```python
def test_style_fallback(D):
    assert D.OrbStyle("b") == "b" and D.OrbStyle(None) == "a" and D.OrbStyle("zzz") == "a"

def test_flipbook_coords(D):
    assert tuple(D.FlipbookCoords(0)) == (0, 0.125, 0, 0.125)   # via lua table pack
    assert tuple(D.FlipbookCoords(9)) == (0.125, 0.25, 0.125, 0.25)
    assert tuple(D.FlipbookCoords(64)) == tuple(D.FlipbookCoords(0))

def test_health_and_mana_palettes_are_exact(D):
    h = D.OrbPalette("HEALTH")
    assert [round(v * 255) for v in (h.wisp[1], h.wisp[2], h.wisp[3])] == [230, 46, 30]
    m = D.OrbPalette("MANA")
    assert [round(v * 255) for v in (m.deep[1], m.deep[2], m.deep[3])] == [0, 3, 16]

def test_other_power_palette_is_derived(D):
    p = D.OrbPalette("RAGE")   # ORB_COLORS.RAGE = 0.62, 0.08, 0.05
    assert abs(p.body[1] - 0.62 * 0.35) < 1e-9 and p.deep[1] < p.body[1] < p.wisp[1] <= p.line[1]

def test_still_style(D):
    assert D.ORB_STYLES.d.still and D.ORB_STYLES.d.sheet == "fluid_a"
```

(`FlipbookCoords` returns 4 values; in the test wrap with `rt.eval("function(i) return {Data.FlipbookCoords(i)} end")` or equivalent.)

- [ ] **Step 2: Run** `python -m pytest -q tests/test_orbs_liquid.py` — Expected: FAIL.
- [ ] **Step 3: Implement** the Data fields and functions above; add `orbStyle = "a"` to `DEFAULTS` in `Core/Init.lua`.
- [ ] **Step 4: Run** `python -m pytest -q tests` — Expected: all pass.
- [ ] **Step 5: Commit** `feat: orb styles, palettes and flipbook coordinates`

### Task 3: Rebuild the orbs

**Files:**
- Modify: `ObsidianUI/HUD/Orbs.lua` (replace `makeOrb` layers and `SetColor`; keep texts, events, `ApplyTextVisibility`)
- Test: `tests/test_orbs_liquid.py`

**Interfaces:**
- Consumes: Task 1 manifest names; Task 2 `Data.ORB_STYLES`, `Data.OrbStyle`, `Data.FlipbookCoords`, `Data.OrbPalette`.
- Produces:
  - `orb:SetPalette(pal)` (pal from `Data.OrbPalette`), `orb:SetStyle(key)`, `orb:Step(elapsed)` (advances the animation; what `OnUpdate` calls).
  - Fields for tests: `orb.well`, `orb.bar`, `orb.clip` (frame anchored TOPLEFT/TOPRIGHT to the fill texture's top and BOTTOMLEFT/BOTTOMRIGHT to `well`, `SetClipsChildren(true)`), `orb.wisp = { tex1, tex2 }`, `orb.wisp2 = { tex1, tex2 }`, `orb.core`, `orb.sparks` (array of 6 textures), `orb.glass`, `orb.t` (seconds).
  - `ns.Orbs.SetStyle(key)` applies `Data.OrbStyle(key)` to both orbs and stores it in `ns.db.orbStyle`; called on `PLAYER_ENTERING_WORLD` with `ns.db.orbStyle`.
  - Health palette `OrbPalette("HEALTH")`; resource palette from the power token in `updatePowerColor` (replaces `power:SetColor(ns.Data.PowerColor(token))`).

Layers (bottom → top; all regions get the circular mask; reference: prévia v5 `drawOrb`):
1. No background texture (the old `bg` goes).
2. `bar` (vertical StatusBar) with the `liquid` texture, vertex color = palette.body.
3. `clip` frame (child of `well`) holding: `wisp` pair and `wisp2` pair (texture = style sheet, blend `ADD`, size = well × 1.08 for wisp and × 1.25 for wisp2, centered on `well`, vertex color = palette.wisp; wisp2 color = palette.body × 1.8 clamped); `core` (ring_glow or orb_spark scaled to 60% of the well, ADD, palette.wisp); `sparks` (orb_spark 6–10 px, ADD, palette.line, hidden unless style.sparks); a darkening gradient to the bottom (`SetGradient` black alpha 0 → 0.5).
4. `wave` anchored to the fill top as today, vertex color palette.line, scroll speed halved (0.025/s).
5. `shade` (vignette) and `glass` (`orb_glass`, ADD, alpha 0.8) over the whole well.

`orb:Step(elapsed)` (algorithm the tests pin): `t = t + elapsed`; `f = (t × fps) mod 64`, `i = floor(f)`, `k = f − i`; `wisp.tex1` coords = `FlipbookCoords(i)`, alpha = `wisp × (1 − k)`; `wisp.tex2` coords = `FlipbookCoords(i + 1)`, alpha = `wisp × k`; both `SetRotation(t × spin)`. `wisp2` the same with frame offset 32, `spin2`, `wisp2` alpha (hidden when `wisp2 == 0`). `core` alpha = `core × (0.6 + 0.4 × sin(t × 0.8))`. Sparks: each has its own phase, rises from the well bottom to the well top over 12–20 s at a fixed x, wobble ±3 px, loops (the clip hides the part above the liquid). Style `still`: set frame `stillFrame` with alpha `wisp`/0, rotation 0, sparks hidden, and `well:SetScript("OnUpdate", nil)`; other styles set `OnUpdate` to call `Step`.

- [ ] **Step 1: Write the failing tests** (boot like `tests/test_improvements.py`; extend `CreateFrame` in `pre` so textures record `SetTexCoord`, `SetRotation`, `SetAlpha`, `SetVertexColor`, `SetShown`, and frames record `SetClipsChildren`, `SetPoint`)

```python
def test_empty_part_is_transparent(lua, ns):           # no bg texture anymore
    boot(lua, ns); assert ns.Orbs.health.bg is None

def test_liquid_is_clipped_to_the_fill(lua, ns):
    # clip.clips == True; its TOP points are anchored to bar:GetStatusBarTexture()
def test_step_plays_the_flipbook_with_crossfade(lua, ns):
    # SetStyle("a"); Step(1.0) -> t=1: f=7 -> tex1 coords == FlipbookCoords(7), tex2 == FlipbookCoords(8),
    # tex1 alpha == 0.62 (k=0) ; rotation == 0.05
def test_still_style_has_no_onupdate_and_resumes(lua, ns):
    # SetStyle("d") -> well OnUpdate is nil, wisp tex1 coords == FlipbookCoords(21)
    # SetStyle("a") -> OnUpdate set again (one handler)
def test_sparks_only_in_energy_style(lua, ns):
    # SetStyle("b") -> all sparks shown; SetStyle("a") -> all hidden; count stays 6 after switching 3 times
def test_saved_style_applied_on_login_with_fallback(lua, ns):
    # db orbStyle "zzz" -> after PLAYER_ENTERING_WORLD both orbs use style "a"
def test_power_type_change_recolors_and_keeps_style(lua, ns):
    # SetStyle("c"); UnitPowerType returns RAGE; fire UNIT_DISPLAYPOWER for "player"
    # -> power wisp vertex color == OrbPalette("RAGE").wisp ; power style still "c"
def test_health_uses_the_health_palette(lua, ns):
    # health wisp tex1 vertex color == OrbPalette("HEALTH").wisp
```

Write each as full assertions with these exact values.

- [ ] **Step 2: Run** `python -m pytest -q tests/test_orbs_liquid.py` — Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the layers, `SetPalette`, `SetStyle`, `Step`, `ns.Orbs.SetStyle` in `HUD/Orbs.lua` as specified.
- [ ] **Step 4: Run** `python -m pytest -q tests` — Expected: all pass (including `test_orb_numbers_can_be_hidden` and `test_orb_update_survives_secret_formatting_errors`).
- [ ] **Step 5: Render** `python tools/preview_render.py <scratch dir>` and look at `preview_hud.png`: liquid inside the ring, nothing drawn outside the circle, empty part transparent at partial values (preview stub values). Fix if not.
- [ ] **Step 6: Commit** `feat: PoE2-style flowing liquid in the orbs`

### Task 4: Style setting

**Files:**
- Modify: `ObsidianUI/Settings/Settings.lua` (after the "orbText" checkbox)
- Test: `tests/test_orbs_liquid.py`

**Interfaces:**
- Consumes: `Data.ORB_STYLE_ORDER`, `Data.ORB_STYLE_LABELS`, `ns.Orbs.SetStyle`.
- Produces: a dropdown "Estilo dos orbes" bound to `ns.db.orbStyle` (string setting, default `"a"`), options in `ORB_STYLE_ORDER` order labelled "A — Redemoinho", "B — Energia", "C — Névoa", "D — Parado", tooltip "Como o líquido dos orbes de vida e recurso se mexe. D fica parado."; changing it calls `ns.Orbs.SetStyle(value)`.

- [ ] **Step 1: Write the failing test**: stub `Settings` (`RegisterVerticalLayoutCategory` returning a category with `GetID` and a layout, `RegisterAddOnSetting` returning a setting object that records `SetValueChangedCallback`, `CreateDropdown` recording `(setting, optionsFn, tooltip)`, `CreateControlTextContainer` returning a container whose `Add(value, label)` records and `GetData()` returns the list); after `PLAYER_LOGIN`, assert the dropdown exists with values `["a","b","c","d"]` and the labels above, and that invoking the recorded callback with `"c"` makes `ns.Orbs.SetStyle` receive `"c"`.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** with `Settings.RegisterAddOnSetting(category, "ObsidianUI_orbStyle", "orbStyle", ns.db, "string", "Estilo dos orbes", "a")`, `Settings.CreateControlTextContainer`, `Settings.CreateDropdown`.
- [ ] **Step 4: Run** `python -m pytest -q tests` — Expected: all pass.
- [ ] **Step 5: Commit** `feat: orb style option in the settings`

### Task 5: Hand-off

- [ ] **Step 1:** Update memory (`obsidianui-open-issues.md`): orbs redesigned, unconfirmed in game; note textures added (restart needed).
- [ ] **Step 2:** Report to the user in Portuguese: what changed, close and reopen the game (new textures), where the option is, and ask for screenshots of each style.
