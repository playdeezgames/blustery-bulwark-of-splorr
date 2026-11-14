#+build !js
package game

import "core:testing"

camp_items :: proc(g: ^Game, index: int) -> (fire, bedroll, note, gear: int) {
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place != .Ground || int(it.floor) != index {
			continue
		}
		#partial switch it.kind {
		case .Campfire:
			fire = i
		case .Bedroll:
			bedroll = i
		case .Note:
			note = i
		case .Iron_Helm, .Tower_Shield, .Chain_Mail:
			gear = i
		}
	}
	return
}

@(test)
test_floors_five_to_seven_have_a_camp :: proc(t: ^testing.T) {
	for seed in u64(1) ..= 30 {
		g := new_game(seed)
		for i in 0 ..< BUILT_FLOORS {
			enter_floor(g, i, .Stairs_Down)
			fire, bedroll, note, gear := camp_items(g, i)
			number := g.floors[i].number
			if number >= 5 {
				testing.expectf(t, fire != 0 && bedroll != 0 && note != 0 && gear != 0, "seed %v floor %v: camp incomplete", seed, number)
				testing.expect_value(t, g.items[gear].kind, camp_gear(number))
				testing.expect_value(t, int(g.items[note].fuel), number - 4)
			} else {
				testing.expect(t, fire == 0 && note == 0)
			}
		}
		free(g)
	}
}

@(test)
test_a_camp_fire_stays_and_a_note_reads :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, 4, .Stairs_Down)
	fire, _, note, _ := camp_items(g, 4)
	teleport(g, {int(g.items[fire].x), int(g.items[fire].y)})
	command(g, .Confirm)
	testing.expect_value(t, g.items[fire].place, Place.Ground)
	testing.expect_value(t, message(&g.last_said), "A cold campfire. Someone camped here, long ago.")
	// The inventory's ground pane will not hold it either.
	command(g, .Inventory)
	testing.expect_value(t, g.inv.view, 0) // the ground underfoot
	g.inv.pane = 1
	g.inv.cursor[1] = 1
	testing.expect_value(t, row_item(g, 1, 1), fire)
	command(g, .Confirm)
	testing.expect_value(t, g.inv.held, 0)
	command(g, .Cancel)
	command(g, .Cancel)
	// The note is picked up and read.
	teleport(g, {int(g.items[note].x), int(g.items[note].y)})
	command(g, .Confirm)
	testing.expect(t, is_carried(g, note))
	turn := g.turn
	testing.expect(t, use_item(g, note))
	testing.expect(t, is_carried(g, note)) // kept
	testing.expect_value(t, g.turn, turn + 1)
}

@(test)
test_the_hermit_trades_on_floor_six :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	enter_floor(g, 5, .Stairs_Down)
	h := 0
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Hermit && int(g.tenants[i].floor) == 5 {
			h = i
		}
	}
	testing.expect(t, h != 0)
	hx, hy := int(g.tenants[h].x), int(g.tenants[h].y)
	// She stays put.
	for _ in 0 ..< 20 {
		tenant_act(g, h)
	}
	testing.expect_value(t, [2]int{int(g.tenants[h].x), int(g.tenants[h].y)}, [2]int{hx, hy})
	// Clear her neighbours so nothing else is in the way, then bump her from the south.
	for i in 1 ..< MAX_TENANTS {
		if i != h && int(g.tenants[i].floor) == 5 {
			g.tenants[i] = {}
		}
	}
	teleport(g, {hx, hy + 1})
	give(g, .Rat_Tail)
	receive_jools(g, 20)
	command(g, .North)
	testing.expect_value(t, g.mode, Mode.Shop)
	testing.expect_value(t, g.shop, Shop.Hermit)
	before := carried_jools(g)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Bread)))
	testing.expect_value(t, carried_jools(g), before - HERMIT_MARKUP * VALUE[.Bread])
	tail := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Rat_Tail && is_carried(g, i) {
			tail = i
		}
	}
	before = carried_jools(g)
	testing.expect(t, choose(g, .Sell, tail))
	testing.expect_value(t, carried_jools(g), before + VALUE[.Rat_Tail])
	testing.expect(t, !g.met_hermit)
	testing.expect(t, choose(g, .Talk))
	testing.expect(t, g.met_hermit)
	// Back in town, the mentor answers her, among the usual lines.
	command(g, .Cancel)
	enter_town(g, .Gate)
	go_in(g, .Tavern)
	heard := false
	for _ in 0 ..< len(MENTOR_LINES) + 1 {
		choose(g, .Talk)
		if message(&g.last_said) == "The mentor: \"She kept the kettle? Of course she did.\"" {
			heard = true
		}
	}
	testing.expect(t, heard)
}
