import re

from conftest import ADDON

# A unit value (possibly a secret value in 12.x combat) used in arithmetic or a comparison.
UNSAFE = re.compile(r"\b(UnitHealth|UnitHealthMax|UnitPower|UnitPowerMax)\([^)]*\)\s*([<>+\-*/]|==|~=)")


def test_pattern_ignores_unit_power_type():
    assert not UNSAFE.search('if UnitPowerType("player") == 0 then')
    assert UNSAFE.search('if UnitHealth("player") < 10 then')


def test_no_arithmetic_on_unit_values():
    offenders = []
    for path in ADDON.rglob("*.lua"):
        if "Libs" in path.parts:
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if UNSAFE.search(line):
                offenders.append(f"{path.name}:{n}: {line.strip()}")
    assert not offenders, "\n".join(offenders)


# Assigning a Blizzard global (StaticPopupDialogs = ..., even to itself) taints it, and every
# Blizzard function that reads it afterwards: the addon only adds keys to Blizzard tables.
GLOBAL_ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=[^=]")
ALLOWED_GLOBAL = re.compile(r"^(ObsidianUI|SLASH_|BINDING_)")


def test_no_blizzard_global_is_reassigned():
    offenders = []
    for path in ADDON.rglob("*.lua"):
        depth = 0
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            m = GLOBAL_ASSIGN.match(line)
            if m and line[:len(line) - len(line.lstrip())] == "" and not ALLOWED_GLOBAL.match(m.group(1)):
                offenders.append(f"{path.name}:{n}: {line.strip()}")
    assert not offenders, "\n".join(offenders)
