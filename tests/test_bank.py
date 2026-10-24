"""The bank in the Moderno look: one bank pane in three places (bankStyle), Blizzard's window hidden."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def at_bank(style, open_bank=True):
    rt = preview_render.run_addon(vbars=False, db={"installed": True, "bankStyle": style})
    if open_bank:
        rt.execute("PREVIEW_BANK(true)")
    return rt, rt.globals().PREVIEW_NS


def shown(f):
    return f.IsVisible(f)


def visible_bank_buttons(ns):
    return [b for b in ns.Bank.Buttons().values() if shown(b)]


def test_opening_the_bank_opens_the_inventory_and_hides_blizzards_window():
    rt, ns = at_bank("side")
    bf = rt.globals().BankFrame
    assert shown(ns.Inventory.frame)
    assert bf.GetAlpha(bf) == 0
    assert bf.GetLeft(bf) < 0  # off screen
    # character bank: two bags, 28 + 16 slots
    assert len(visible_bank_buttons(ns)) == 44


def test_side_style_takes_the_character_half():
    _, ns = at_bank("side")
    assert shown(ns.Bank.pane)
    assert not shown(ns.Inventory.model) and not shown(ns.Inventory.statsPanel)
    assert shown(ns.Inventory.gridArea)  # the bags stay
    pane, inv = ns.Bank.pane, ns.Inventory.frame
    assert pane.GetRight(pane) < ns.Inventory.gridArea.GetLeft(ns.Inventory.gridArea)
    assert pane.GetLeft(pane) >= inv.GetLeft(inv)


def test_closing_the_bank_brings_the_character_back():
    rt, ns = at_bank("side")
    rt.execute("PREVIEW_BANK(false)")
    assert not shown(ns.Bank.pane)
    assert shown(ns.Inventory.model)


def test_closing_the_inventory_closes_the_bank():
    rt, ns = at_bank("side")
    ns.Inventory.Close()
    assert rt.globals().PREVIEW_BANK_CLOSED == 1


def test_window_style_sits_left_of_a_smaller_inventory():
    rt, ns = at_bank("window", open_bank=False)
    inv = ns.Inventory.frame
    ns.Inventory.Open()
    alone = inv.GetHeight(inv)
    rt.execute("PREVIEW_BANK(true)")
    win = ns.Bank.window
    assert shown(win) and shown(ns.Bank.pane)
    assert inv.GetHeight(inv) < alone
    assert win.GetRight(win) <= inv.GetLeft(inv)
    assert win.GetLeft(win) >= 0 and inv.GetRight(inv) <= 1920
    assert shown(ns.Inventory.model)  # the inventory keeps its character side
    # closing the bank window closes the bank, and the inventory gets its size back
    win.Hide(win)
    assert rt.globals().PREVIEW_BANK_CLOSED == 1
    rt.execute("PREVIEW_BANK(false)")
    assert abs(inv.GetHeight(inv) - alone) < 0.5


def test_inside_style_switches_bags_bank_and_account():
    rt, ns = at_bank("inside")
    assert ns.Bank.view == "bank"
    assert shown(ns.Bank.pane) and not shown(ns.Inventory.gridArea)
    assert shown(ns.Inventory.searchBox)  # one search for bags and bank
    labels = [b.text.GetText(b.text) for b in ns.Bank.switch.values() if shown(b)]
    assert labels == ["Bolsas", "Banco", "Conta"]
    ns.Bank.SetView("account")
    assert len(visible_bank_buttons(ns)) == 98
    assert rt.globals().BankFrame.activeType == 2  # right clicks now deposit into the account bank
    ns.Bank.SetView("bags")
    assert not shown(ns.Bank.pane) and shown(ns.Inventory.gridArea)


def test_inside_style_shows_the_last_visit_away_from_the_banker():
    rt, ns = at_bank("inside")
    rt.execute("PREVIEW_BANK(false)")
    assert ns.Bank.view == "bags" and not shown(ns.Bank.pane)
    ns.Bank.SetView("bank")
    assert shown(ns.Bank.pane)
    assert not visible_bank_buttons(ns)
    cached = [b for b in ns.Bank.cacheButtons.values() if shown(b)]
    assert len(cached) == 44
    assert any(b.link for b in cached)
    assert "última visita" in ns.Bank.pane.free.GetText(ns.Bank.pane.free)


def test_personagem_conta_switch_follows_blizzards_tab():
    rt, ns = at_bank("side")
    kinds = list(ns.Bank.kindButtons.values())
    assert [shown(b) for b in kinds] == [True, True]
    kinds[1].GetScript(kinds[1], "OnClick")(kinds[1])
    assert ns.Bank.type == 2
    assert rt.globals().BankFrame.activeType == 2
    assert shown(ns.Bank.pane.deposit)  # the account bank takes everything at once
    ns.Bank.pane.sort.GetScript(ns.Bank.pane.sort, "OnClick")(ns.Bank.pane.sort)
    assert rt.globals().PREVIEW_BANK_SORTED == 2


def test_bank_bags_and_buy_slot_in_the_foot():
    _, ns = at_bank("side")
    slots = [b for b in ns.Bank.bagSlots.values() if shown(b)]
    # camelot: the first bank bag comes with the bank, so one bag slot plus "+"
    assert len(slots) == 2
    assert slots[0].icon.file == "ICON:bag" and slots[1].buy
    assert ns.Bank.pane.free.GetText(ns.Bank.pane.free).startswith("Livres:")


def test_style_changes_live():
    _, ns = at_bank("side")
    ns.db.bankStyle = "window"
    ns.Bank.ApplyStyle()
    assert shown(ns.Bank.window) and shown(ns.Inventory.model)
    ns.db.bankStyle = "inside"
    ns.Bank.ApplyStyle()
    assert not shown(ns.Bank.window) and ns.Bank.view == "bank" and not shown(ns.Inventory.gridArea)


def test_cache_is_not_part_of_a_profile():
    _, ns = at_bank("side")
    assert ns.db.bankCache is not None
    assert ns.Profiles.Snapshot().bankCache is None
