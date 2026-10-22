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
