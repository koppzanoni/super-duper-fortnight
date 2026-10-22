from conftest import load_pure


def test_first_existing_name(pure):
    ns = load_pure(pure, "Core/Resolve.lua")
    env = pure.table_from({"B": 1})
    obj, name = ns.Resolve.First(pure.table_from(["A", "B"]), env)
    assert obj == 1
    assert name == "B"


def test_none_exists(pure):
    ns = load_pure(pure, "Core/Resolve.lua")
    obj = ns.Resolve.First(pure.table_from(["A", "C"]), pure.table())
    assert obj is None
