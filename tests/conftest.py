import pathlib

import pytest
from lupa import luajit21 as lupa_rt

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "ObsidianUI"
STUB = ROOT / "tests" / "wowstub.lua"


def new_runtime(with_stub=True):
    rt = lupa_rt.LuaRuntime(unpack_returned_tuples=True)
    if with_stub:
        rt.execute(STUB.read_text(encoding="utf-8"))
    return rt


def load_addon_file(rt, path, ns):
    """Run an addon file the way WoW does: the chunk receives (addonName, ns)."""
    path = pathlib.Path(path)
    if not path.is_absolute():
        path = ADDON / path
    chunk = rt.eval("function(src, name) return assert(loadstring(src, name)) end")(
        path.read_text(encoding="utf-8"), "@" + str(path.relative_to(ROOT)))
    chunk("ObsidianUI", ns)
    return ns


def toc_files():
    files = []
    for line in (ADDON / "ObsidianUI.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("Libs"):
            continue
        files.append(line.replace("\\", "/"))
    return files


@pytest.fixture
def lua():
    """Lua 5.1-compatible runtime with the WoW API stub loaded."""
    return new_runtime()


@pytest.fixture
def pure():
    """Lua 5.1-compatible runtime with no WoW stub (for pure modules)."""
    return new_runtime(with_stub=False)


@pytest.fixture
def ns(lua):
    return lua.table()


def load_pure(rt, *paths):
    ns = rt.table()
    for p in paths:
        load_addon_file(rt, p, ns)
    return ns
