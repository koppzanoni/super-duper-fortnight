from conftest import load_addon_file, toc_files


def test_every_toc_file_loads(lua, ns):
    files = toc_files()
    assert files, "the .toc lists no Lua files"
    for f in files:
        load_addon_file(lua, f, ns)
