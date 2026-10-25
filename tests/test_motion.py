"""Movement and glow effects over the real addon (tools/preview): the leading-edge spark (D),
the low-health pulse (E), the frame fade on appear (B), the cast finish/interrupt flash (C) and
the resource gem pop (F). The preview runs the addon with real unit values, so these exercise the
actual draw code, and the OnUpdate drivers are ticked by hand."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def run(db=None, pre=None):
    rt = preview_render.run_addon(vbars=True, db=db, pre=pre)
    return rt, rt.globals().PREVIEW_NS


def fire(rt, ev, *args):
    argtext = "".join(', "%s"' % a for a in args)
    rt.execute(f'PREVIEW_FIRE("{ev}"{argtext})')


def tick(frame, dt):
    frame.handlers.OnUpdate(frame, dt)


# --------------------------------------------------------------------------- D: spark
def test_spark_shows_on_health_and_power_by_default():
    _, ns = run()
    p = ns.UnitFrames.frames.player
    assert p.health.obSpark.shown is True
    assert p.power.obSpark.shown is True
    assert p.health.obSpark.blend == "ADD"


def test_spark_setting_off_hides_it():
    _, ns = run({"barSpark": False})
    p = ns.UnitFrames.frames.player
    assert p.health.obSpark.shown is False
    assert p.power.obSpark.shown is False


# --------------------------------------------------------------------------- E: low-health pulse
def test_pulse_breathes_when_low_and_stops_when_recovered():
    rt, ns = run()
    p = ns.UnitFrames.frames.player
    rt.execute("function UnitHealthPercent(u) return 15 end")
    ns.UnitFrames.UpdatePulse(p)
    assert p.obLowGlow.shown is True
    tick(ns.UnitFrames.pulseDriver, 0.12)
    assert p.obLowGlow.alpha > 0           # the breath raised the glow

    rt.execute("function UnitHealthPercent(u) return 80 end")
    ns.UnitFrames.UpdatePulse(p)
    assert p.obLowGlow.shown is False       # recovered: hidden
    tick(ns.UnitFrames.pulseDriver, 0.12)
    assert p.obLowGlow.alpha == 0           # and the driver leaves it alone


def test_pulse_setting_off_never_shows():
    rt, ns = run({"lowHpPulse": False})
    p = ns.UnitFrames.frames.player
    rt.execute("function UnitHealthPercent(u) return 10 end")
    ns.UnitFrames.UpdatePulse(p)
    assert p.obLowGlow.shown is False


# --------------------------------------------------------------------------- B: frame fade
def test_frame_fades_in_on_appear():
    _, ns = run()
    t = ns.UnitFrames.frames.target
    ns.UnitFrames.FadeIn(t)
    assert t.alpha == 0
    drv = ns.UnitFrames.fadeDriver
    tick(drv, 0.1)
    assert 0 < t.alpha < 1
    tick(drv, 0.3)
    assert t.alpha == 1


def test_frame_fade_off_is_instant():
    _, ns = run({"frameFade": False})
    t = ns.UnitFrames.frames.target
    ns.UnitFrames.FadeIn(t)
    assert t.alpha == 1


# --------------------------------------------------------------------------- C: cast flash
def test_cast_flash_green_on_finish():
    rt, ns = run()
    fire(rt, "UNIT_SPELLCAST_START", "player")
    fire(rt, "UNIT_SPELLCAST_STOP", "player")
    ff = ns.CastBar.flashFrame
    assert ff.shown is True
    vc = ns.CastBar.flash.vc           # pale green: green channel brightest
    assert vc[2] > vc[1] and vc[2] > vc[3]
    tick(ff, 0.5)                      # past the 0.35 s fade
    assert ff.shown is False


def test_cast_flash_red_on_interrupt():
    rt, ns = run()
    fire(rt, "UNIT_SPELLCAST_START", "player")
    fire(rt, "UNIT_SPELLCAST_INTERRUPTED", "player")
    ff = ns.CastBar.flashFrame
    assert ff.shown is True
    vc = ns.CastBar.flash.vc           # red: red channel brightest
    assert vc[1] > vc[2] and vc[1] > vc[3]


def test_cast_flash_suppressed_after_interrupt_stop():
    rt, ns = run()
    fire(rt, "UNIT_SPELLCAST_START", "player")
    fire(rt, "UNIT_SPELLCAST_INTERRUPTED", "player")
    fire(rt, "UNIT_SPELLCAST_STOP", "player")  # must not overwrite the red with a green "finish"
    assert ns.CastBar.flash.vc[1] > ns.CastBar.flash.vc[2]


def test_cast_flash_off():
    rt, ns = run({"castFlash": False})
    fire(rt, "UNIT_SPELLCAST_START", "player")
    fire(rt, "UNIT_SPELLCAST_STOP", "player")
    assert ns.CastBar.flashFrame is None


# --------------------------------------------------------------------------- F: gem pop
def test_gem_pops_on_gaining_a_point():
    rt, ns = run()
    # the preview's rogue sits at 3 combo points; take it to 4 and the 4th gem should pop
    rt.execute("function UnitPower(u, t) if t == 4 then return 4 end return 11000 end")
    fire(rt, "UNIT_POWER_FREQUENT", "player")
    pop = ns.ClassResource.pops[4]
    assert pop.shown is True
    tick(ns.ClassResource.popDriver, 0.05)
    assert pop.alpha > 0
    tick(ns.ClassResource.popDriver, 0.4)   # past the 0.28 s burst
    assert pop.shown is False


def test_gem_pop_off():
    rt, ns = run({"gemPop": False})
    rt.execute("function UnitPower(u, t) if t == 4 then return 4 end return 11000 end")
    fire(rt, "UNIT_POWER_FREQUENT", "player")
    assert ns.ClassResource.pops[4].shown is False
