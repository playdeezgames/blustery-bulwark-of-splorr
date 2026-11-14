#+build !js
package game

import "core:testing"

has_row :: proc(g: ^Game, act: Act, arg: int) -> bool {
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for i in 0 ..< n {
		if rows[i].act == act && rows[i].arg == arg {
			return true
		}
	}
	return false
}

@(test)
test_the_shops_stock_more_after_the_horde :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	g.shop = .Smith
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Mace)))
	g.shop = .General
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Lantern)))
	g.boss_dead = true
	g.shop = .Smith
	for k in SMITH_LATER {
		testing.expect(t, has_row(g, .Buy, int(k)))
	}
	g.shop = .General
	for k in GENERAL_LATER {
		testing.expect(t, has_row(g, .Buy, int(k)))
	}
}

@(test)
test_the_sage_sells_what_you_have_named :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	g.boss_dead = true
	g.shop = .Sage
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Potion_Healing)))
	identify_kind(g, .Potion_Healing)
	identify_kind(g, .Potion_Blight)
	testing.expect(t, has_row(g, .Buy, int(Item_Kind.Potion_Healing)))
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Potion_Blight))) // never the bad ones
	receive_jools(g, 50)
	go_in(g, .Sage)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Potion_Healing)))
	found := false
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Potion_Healing && is_carried(g, i) {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_the_temple_restores_drained_strength :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	g.attr[.Strength] -= 2
	g.drained[.Strength] = 2
	st := g.attr[.Strength]
	receive_jools(g, 2 * TEMPLE_RESTORE)
	go_in(g, .Temple)
	testing.expect(t, choose(g, .Restore, int(Attr.Strength)))
	testing.expect_value(t, g.attr[.Strength], st + 1)
	testing.expect_value(t, int(g.drained[.Strength]), 1)
	testing.expect(t, choose(g, .Restore, int(Attr.Strength)))
	testing.expect_value(t, int(g.drained[.Strength]), 0)
	testing.expect(t, !has_row(g, .Restore, int(Attr.Strength)))
}

// A lantern in the light slot: burns oil, runs dry without going away, fills from a flask.
@(test)
test_a_lantern_burns_oil :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	torch := worn(g, .Light)
	unplace(g, torch)
	put_in(g, torch, worn(g, .Pack))
	lantern := new_item(g, .Lantern)
	testing.expect(t, wear(g, lantern, .Light))
	testing.expect_value(t, int(g.items[lantern].fuel), OIL_TURNS)
	testing.expect(t, light_torch(g))
	testing.expect(t, g.lit)
	testing.expect_value(t, light_name(g), "lantern")
	g.items[lantern].fuel = 1
	g.gust_in = 1000
	command(g, .Wait)
	testing.expect(t, !g.lit)
	testing.expect_value(t, worn(g, .Light), lantern) // still there, dry
	testing.expect_value(t, light_fuel(g), 0)
	// No oil: nothing to light it with.
	light_torch(g)
	testing.expect(t, !g.lit)
	oil := give(g, .Oil_Flask)
	testing.expect_value(t, light_spares(g), 1)
	light_torch(g) // a turn passes, so a turn of oil burns
	testing.expect(t, g.lit)
	testing.expect_value(t, light_fuel(g), OIL_TURNS - 1)
	testing.expect_value(t, g.items[oil].kind, Item_Kind.None) // used up
}

@(test)
test_a_tinderbox_lights_with_no_turn :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.lit = false
	turn := g.turn
	light_torch(g)
	testing.expect_value(t, g.turn, turn + 1)
	g.lit = false
	give(g, .Tinderbox)
	turn = g.turn
	light_torch(g)
	testing.expect(t, g.lit)
	testing.expect_value(t, g.turn, turn)
}

// Gusts snuff a lantern a third as often as a torch (counted over many gusts on floor 4).
@(test)
test_gusts_snuff_a_lantern_less_often :: proc(t: ^testing.T) {
	count :: proc(lantern: bool) -> int {
		g := new_game()
		defer free(g)
		enter_floor(g, BOSS_INDEX, .Stairs_Down)
		if lantern {
			torch := worn(g, .Light)
			free_item(g, torch)
			wear(g, new_item(g, .Lantern), .Light)
		}
		snuffed := 0
		for _ in 0 ..< 600 {
			g.lit = true
			g.items[worn(g, .Light)].fuel = 500
			teleport(g, floor_of(g).down)
			gust(g)
			if !g.lit {
				snuffed += 1
			}
		}
		return snuffed
	}
	torch, lantern := count(false), count(true)
	testing.expectf(t, lantern * 2 < torch, "torch %v, lantern %v", torch, lantern)
}
