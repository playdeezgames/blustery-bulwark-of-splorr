#+build !js
package game

import "core:testing"

// Slice 3 step 20: the town after the army.

@(test)
test_the_smith_stocks_more_after_the_army :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	go_in(g, .Smith)
	for k in SMITH_ARMY {
		testing.expect(t, !choose(g, .Buy, int(k)))
	}
	g.army_dead = true
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for k in SMITH_ARMY {
		found := false
		for r in rows[:n] {
			if r.act == .Buy && r.arg == int(k) {
				found = true
				testing.expect_value(t, r.price, VALUE[k])
			}
		}
		testing.expect(t, found)
	}
	testing.expect_value(t, [3]int{VALUE[.War_Hammer], VALUE[.Scale_Mail], VALUE[.Spear]}, [3]int{70, 90, 45})
	spear := KIND[.Spear]
	testing.expect_value(t, [2]int{spear.dmin, spear.dmax}, [2]int{2, 8})
	testing.expect(t, spear.weight < KIND[.Mace].weight)
	receive_jools(g, 45)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Spear)))
	testing.expect_value(t, message(&g.last_said), "You buy a Spear.")
}

// A floor cell whose downwind neighbour is a wall, to be slammed from.
slam_spot :: proc(g: ^Game) -> [2]int {
	f := floor_of(g)
	d := wind_blow(f)
	for y in 1 ..< FLOOR_H - 1 {
		for x in 1 ..< FLOOR_W - 1 {
			if f.cells[y][x] == .Floor && f.cells[y + d.y][x + d.x] == .Wall && tenant_at(g, x, y) == 0 {
				return {x, y}
			}
		}
	}
	return {}
}

@(test)
test_gust_insurance_pays_two_a_slam_while_it_runs :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	receive_jools(g, 250)
	go_in(g, .General)
	testing.expect(t, !choose(g, .Insure))
	g.army_dead = true
	before := carried_jools(g)
	testing.expect(t, choose(g, .Insure))
	testing.expect_value(t, carried_jools(g), before - INSURANCE_PRICE)
	testing.expect_value(t, g.insured_to, g.turn + INSURANCE_TURNS)
	// A second buys another 1000 turns on top.
	testing.expect(t, choose(g, .Insure))
	testing.expect_value(t, g.insured_to, g.turn + 2 * INSURANCE_TURNS)
	command(g, .Cancel)
	enter_floor(g, 0, .Stairs_Down)
	g.health = max_health(g)
	spot := slam_spot(g)
	testing.expect(t, spot != {})
	teleport(g, spot)
	before = carried_jools(g)
	g.gust_in = 1
	command(g, .Wait)
	testing.expect_value(t, carried_jools(g), before + INSURANCE_PAYS)
	testing.expect_value(t, message(&g.last_said), "Yer gust insurance pays 2 Jools.")
	// Run out, it pays nothing.
	g.insured_to = g.turn
	teleport(g, spot)
	before = carried_jools(g)
	g.gust_in = 1
	command(g, .Wait)
	testing.expect_value(t, carried_jools(g), before)
}
