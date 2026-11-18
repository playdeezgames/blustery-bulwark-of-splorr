#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 3 step 19: the camps on floors 9 to 11, the cartographer and the pack of holding.

@(test)
test_the_deep_camps_hold_their_gear_and_notes :: proc(t: ^testing.T) {
	testing.expect_value(t, camp_gear(9), Item_Kind.War_Hammer)
	testing.expect_value(t, camp_gear(10), Item_Kind.Pack_Holding)
	testing.expect_value(t, camp_gear(11), Item_Kind.Scale_Mail)
	testing.expect(t, !is_camp_floor(8) && !is_camp_floor(12) && is_camp_floor(9) && is_camp_floor(11))
	hammer, mail := KIND[.War_Hammer], KIND[.Scale_Mail]
	testing.expect_value(t, [3]int{hammer.dmin, hammer.dmax, hammer.weight}, [3]int{3, 10, 5000})
	testing.expect_value(t, [2]int{mail.armour, mail.weight}, [2]int{5, 14000})
	g := new_game()
	defer free(g)
	read_note(g, camp_note(9))
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The note reads: \"Day 160. Fewer camps up here."))
	read_note(g, camp_note(11))
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The note reads: \"Someone on fifteen"))
}

@(test)
test_a_pack_of_holding_counts_half_and_holds_no_other :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	pack := worn(g, .Pack)
	holding := new_item(g, .Pack_Holding)
	testing.expect(t, put_in(g, holding, pack))
	before := carried_weight(g)
	mail := new_item(g, .Chain_Mail)
	testing.expect(t, put_in(g, mail, holding))
	testing.expect_value(t, carried_weight(g), before + KIND[.Chain_Mail].weight / 2)
	testing.expect_value(t, contents_weight(g, holding), KIND[.Chain_Mail].weight) // its limit counts it all
	// Not one inside another, nor by way of a sack.
	other := new_item(g, .Pack_Holding)
	testing.expect(t, put_in(g, other, pack)) // placed, so its slot is not handed out again
	ok, _ := can_put_in(g, other, holding)
	testing.expect(t, !ok)
	sack := new_item(g, .Sack)
	testing.expect(t, put_in(g, sack, holding))
	ok, _ = can_put_in(g, other, sack)
	testing.expect(t, !ok)
	sack2 := new_item(g, .Sack)
	testing.expect(t, put_in(g, sack2, pack))
	testing.expect(t, put_in(g, other, sack2))
	ok, _ = can_put_in(g, sack2, holding)
	testing.expect(t, !ok)
	testing.expect(t, !put_in(g, other, holding))
	testing.expect_value(t, message(&g.last_said), "A pack of holding will not hold another.")
}

@(test)
test_the_cartographer_sells_maps_on_floor_ten :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	for i in 0 ..< CARTOGRAPHER_FLOOR {
		enter_floor(g, i, .Stairs_Down)
	}
	index := CARTOGRAPHER_FLOOR - 1
	c := 0
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Cartographer {
			testing.expect_value(t, int(g.tenants[i].floor), index)
			c = i
		} else if int(g.tenants[i].floor) == index {
			g.tenants[i] = {}
		}
	}
	testing.expect(t, c != 0)
	cx, cy := int(g.tenants[c].x), int(g.tenants[c].y)
	for _ in 0 ..< 20 {
		tenant_act(g, c)
	}
	testing.expect_value(t, [2]int{int(g.tenants[c].x), int(g.tenants[c].y)}, [2]int{cx, cy})
	teleport(g, {cx, cy + 1})
	receive_jools(g, 50)
	command(g, .North)
	testing.expect_value(t, g.mode, Mode.Shop)
	testing.expect_value(t, g.shop, Shop.Cartographer)
	rows: [MAX_ROWS]Row
	maps := 0
	n := shop_rows(g, &rows)
	for r in rows[:n] {
		if r.act == .Map {
			maps += 1
		}
	}
	testing.expect_value(t, maps, CARTOGRAPHER_FLOOR) // floors 1 to 10, all reached
	f := &g.floors[2]
	testing.expect(t, !f.seen[f.up.y][f.up.x])
	before := carried_jools(g)
	testing.expect(t, choose(g, .Map, 2))
	testing.expect_value(t, carried_jools(g), before - MAP_PRICE)
	testing.expect(t, f.seen[f.up.y][f.up.x])
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The cartographer hands you a map of floor 3."))
	testing.expect(t, !choose(g, .Map, 2)) // one map a floor
	testing.expect(t, choose(g, .Talk))
	testing.expect_value(t, message(&g.last_said), "The cartographer: \"I mapped up to ten. Ten was enough.\"")
}

@(test)
test_the_sage_sells_one_pack_of_holding_after_the_army :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	receive_jools(g, 200)
	before := carried_jools(g)
	go_in(g, .Sage)
	testing.expect(t, !choose(g, .Buy, int(Item_Kind.Pack_Holding)))
	g.army_dead = true
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Pack_Holding)))
	testing.expect(t, g.sage_holding)
	testing.expect_value(t, carried_jools(g), before - VALUE[.Pack_Holding])
	held := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Pack_Holding && is_carried(g, i) {
			held += 1
		}
	}
	testing.expect_value(t, held, 1)
	testing.expect(t, !choose(g, .Buy, int(Item_Kind.Pack_Holding)))
}
