from conftest import load_pure

FAKE = """
MANIFEST_CALLS = {}
function fakeTexture()
  local t = { calls = {} }
  function t:SetTexture(f) self.file = f end
  function t:SetTexCoord(...) self.coords = { ... } end
  return t
end
"""


def make(pure):
    pure.execute(FAKE)
    ns = load_pure(pure, "Core/Media.lua")
    ns.MediaManifest = pure.eval('{ hud_cap = { file = "X/hud_cap", w = 656, h = 381, potW = 1024, potH = 512 } }')
    return ns


def test_apply_sets_file_and_texcoords(pure):
    ns = make(pure)
    tex = pure.eval("fakeTexture()")
    ns.Media.Apply(tex, "hud_cap")
    assert tex.file == "X/hud_cap"
    assert list(tex.coords.values()) == [0, 656 / 1024, 0, 381 / 512]


def test_apply_mirror_flips_x(pure):
    ns = make(pure)
    tex = pure.eval("fakeTexture()")
    ns.Media.Apply(tex, "hud_cap", True)
    assert list(tex.coords.values()) == [656 / 1024, 0, 0, 381 / 512]


def test_apply_partial_width(pure):
    ns = make(pure)
    tex = pure.eval("fakeTexture()")
    ns.Media.Apply(tex, "hud_cap", False, 0.5)
    assert list(tex.coords.values()) == [0, 0.5 * 656 / 1024, 0, 381 / 512]
