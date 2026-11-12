#+build !js
package game

import "core:testing"

// Puts a new item on the ground at the player's feet.
lay :: proc(g: ^Game, kind: Item_Kind, count := 1) -> int {
	id := new_item(g, kind, count)
	g.items[id].place, g.items[id].floor, g.items[id].x, g.items[id].y = .Ground, i8(g.current), i16(g.x), i16(g.y)
	return id
}

clear_ground :: proc(g: ^Game) {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Ground {
			free_item(g, i)
		}
	}
}

@(test)
test_starting_kit :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	testing.expect_value(t, g.items[worn(g, .Weapon)].kind, Item_Kind.Dagger)
	testing.expect_value(t, g.items[worn(g, .Armour)].kind, Item_Kind.Padded_Armour)
	testing.expect_value(t, g.items[worn(g, .Light)].kind, Item_Kind.Torch)
	testing.expect_value(t, g.items[worn(g, .Pack)].kind, Item_Kind.Pack)
	testing.expect(t, g.lit)
	testing.expect_value(t, carried_jools(g), 25)
	testing.expect_value(t, spare_torches(g), 2)
	testing.expect_value(t, carried_weight(g), 400 + 4000 + 1000 + 500 + 1000 + 600 + 300 + 1000 + 50 + 25 * 50)
	testing.expect(t, !anchored(g))
}

@(test)
test_get_puts_things_in_the_right_place :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	clear_ground(g)
	lay(g, .Jools, 7)
	command(g, .Confirm)
	testing.expect_value(t, carried_jools(g), 32)
	testing.expect_value(t, contents_count(g, worn(g, .Purse)), 1) // merged into one pile
	torch := lay(g, .Torch)
	command(g, .Confirm)
	testing.expect_value(t, int(g.items[torch].parent), worn(g, .Belt))
	sword := lay(g, .Short_Sword) // too bulky for the belt
	command(g, .Confirm)
	testing.expect_value(t, int(g.items[sword].parent), worn(g, .Pack))
	cap := lay(g, .Leather_Cap) // fits the pack, so it goes there rather than on yer head
	command(g, .Confirm)
	testing.expect_value(t, g.items[cap].place, Place.Inside)
	testing.expect_value(t, ground_item_at(g, g.x, g.y), 0)
}

@(test)
test_container_rules :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	pack, belt, purse := worn(g, .Pack), worn(g, .Belt), worn(g, .Purse)
	bread := new_item(g, .Bread)
	ok, why := can_put_in(g, bread, purse)
	testing.expect(t, !ok)
	testing.expect_value(t, why, "A purse holds only coins.")
	sword := new_item(g, .Short_Sword)
	ok, why = can_put_in(g, sword, belt)
	testing.expect_value(t, why, "Too bulky for a belt.")
	// The belt has four slots; two torches are on it.
	put_in(g, new_item(g, .Dagger), belt)
	put_in(g, new_item(g, .Bread), belt)
	ok, why = can_put_in(g, new_item(g, .Bread), belt)
	testing.expect_value(t, why, "The belt is full.")
	// Bags nest, but not inside themselves.
	sack := new_item(g, .Sack)
	testing.expect(t, put_in(g, sack, pack))
	ok, why = can_put_in(g, pack, sack)
	testing.expect_value(t, why, "It will not go inside itself.")
	// The pack's weight limit.
	ok, why = can_put_in(g, new_item(g, .Jools, 1200), pack)
	testing.expect_value(t, why, "Too heavy for that.")
}

@(test)
test_inventory_screen_moves_things :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	clear_ground(g)
	turn := g.turn
	command(g, .Inventory)
	testing.expect_value(t, g.mode, Mode.Inventory)
	testing.expect_value(t, g.inv.view, worn(g, .Pack)) // nothing underfoot: the pack is open
	// Right pane, first item (bread), hold it, back to the left pane, down to the floor row, put.
	command(g, .East)
	testing.expect_value(t, g.inv.pane, 1)
	command(g, .South)
	command(g, .Confirm)
	bread := g.inv.held
	testing.expect_value(t, g.items[bread].kind, Item_Kind.Bread)
	command(g, .West)
	testing.expect_value(t, g.inv.pane, 0)
	for g.inv.cursor[0] < GROUND_ROW {
		command(g, .South)
	}
	testing.expect_value(t, g.inv.cursor[0], GROUND_ROW)
	command(g, .Confirm)
	testing.expect_value(t, g.inv.held, 0)
	testing.expect_value(t, g.items[bread].place, Place.Ground)
	// Open the floor view and pick it back into the belt: hold it, open the belt slot, put.
	command(g, .East)
	testing.expect_value(t, g.inv.view, 0)
	command(g, .Confirm)
	testing.expect_value(t, g.inv.held, bread)
	command(g, .West)
	for _ in 0 ..< LEFT_ROWS {
		command(g, .North)
	}
	for g.inv.cursor[0] < 12 { // the belt row
		command(g, .South)
	}
	command(g, .East)
	testing.expect_value(t, g.inv.view, worn(g, .Belt))
	command(g, .Confirm)
	testing.expect_value(t, int(g.items[bread].parent), worn(g, .Belt))
	// Moving things takes no time; Escape closes.
	command(g, .Cancel)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.turn, turn)
}

@(test)
test_wearing_needs_the_right_empty_slot :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	sword := lay(g, .Short_Sword)
	testing.expect(t, !wear(g, sword, .Helmet))
	testing.expect(t, !wear(g, sword, .Weapon)) // the dagger is there
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "Take off the Dagger first.")
	buckler := lay(g, .Buckler)
	testing.expect(t, wear(g, buckler, .Shield))
	testing.expect(t, carried_weight(g) > 0)
}

@(test)
test_taking_the_torch_out_puts_it_out :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	testing.expect(t, g.lit)
	put_in(g, worn(g, .Light), worn(g, .Pack))
	testing.expect(t, !g.lit)
	testing.expect_value(t, worn(g, .Light), 0)
}

@(test)
test_a_heavy_load_anchors_and_slows_and_too_much_stops_you :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	clear_ground(g)
	g.attr[.Strength] = 8 // a 20 kg limit, so this load is easy to reckon
	sack := new_item(g, .Sack)
	put_in(g, sack, worn(g, .Pack))
	put_in(g, new_item(g, .Jools, 100), sack) // 5 kg more: 15.3 kg, at least 75% of 20
	testing.expect(t, anchored(g))
	g.gust_in = 1
	command(g, .Wait)
	testing.expect_value(t, [2]int{g.x, g.y}, spot)
	testing.expect_value(t, message(&g.log[LOG_LINES - 2]), "A gust tugs at you. Yer load holds you")
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), " down.")
	g.gust_in = 1000
	turn := g.turn
	for d, i in DIRECTIONS {
		if passable(cell_at(g, g.x + d.x, g.y + d.y)) {
			command(g, Command(i))
			break
		}
	}
	testing.expect_value(t, g.turn, turn + 2) // slowed
	// Over the limit nothing moves.
	put_in(g, new_item(g, .Jools, 500), worn(g, .Pack))
	lay(g, .Club)
	for _ in 0 ..< 6 {
		c := new_item(g, .Club)
		g.items[c].place, g.items[c].slot = .Worn, .Cloak // any slot: only the weight matters here
	}
	testing.expect(t, overloaded(g))
	x, y := g.x, g.y
	for i in 0 ..< 8 {
		command(g, Command(i))
	}
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{x, y})
}

@(test)
test_gusts_blow_light_things_along :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	clear_ground(g)
	bread := lay(g, .Bread)
	sword := lay(g, .Short_Sword)
	// Make the player heavy, so only the things move.
	put_in(g, new_item(g, .Jools, 400), worn(g, .Pack))
	g.gust_in = 1
	command(g, .Wait)
	d := wind_blow(floor_of(g))
	testing.expect_value(t, [2]int{int(g.items[bread].x), int(g.items[bread].y)}, spot + d)
	testing.expect_value(t, [2]int{int(g.items[sword].x), int(g.items[sword].y)}, spot)
}

@(test)
test_mouse_drag_drops :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	clear_ground(g)
	command(g, .Inventory)
	dagger := worn(g, .Weapon)
	// Press on the hand row, let go on the floor row.
	pointer(g, INV_LEFT_X + 20, INV_TOP + 0 * INV_ROW_H + 3, .Mouse_Primary)
	testing.expect_value(t, g.inv.held, dagger)
	inventory_release(g, INV_LEFT_X + 20, INV_TOP + GROUND_ROW * INV_ROW_H + 3)
	testing.expect_value(t, g.items[dagger].place, Place.Ground)
	testing.expect_value(t, g.inv.held, 0)
	// A click on an open marker opens the container.
	pointer(g, INV_LEFT_X + INV_PANE_W - 4, INV_TOP + 13 * INV_ROW_H + 3, .Mouse_Primary)
	testing.expect_value(t, g.inv.view, worn(g, .Pack))
	testing.expect_value(t, g.inv.held, 0)
}

@(test)
test_floors_have_things_lying_about :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	n := 0
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place == .Ground && it.floor == 0 {
			n += 1
			testing.expect_value(t, g.floors[0].cells[it.y][it.x], Cell.Floor)
		}
	}
	testing.expect(t, n >= 5)
	// The same seed lays the same things.
	h := new_game()
	defer free(h)
	testing.expect(t, g.items == h.items)
}

@(test)
test_inventory_draws :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := new(Frame)
	defer free(f)
	command(g, .Inventory)
	draw_game(f, g)
	lit := 0
	for p in f.px[:SCREEN_W * 20] {
		if p == COLOR_CYAN {
			lit += 1
		}
	}
	testing.expect(t, lit > 20)
	buf: [16]u8
	testing.expect_value(t, kg(buf[:], 9100), "9.1")
	testing.expect_value(t, kg(buf[:], 20000), "20.0")
}

@(test)
test_ground_items_are_drawn_where_seen :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	clear_ground(g)
	g.x += 1
	lay(g, .Bread)
	g.x -= 1
	refresh_view(g)
	f := new(Frame)
	defer free(f)
	draw_game(f, g)
	cx, cy := MAP_X + (VIEW_W / 2 + 1) * TILE, MAP_Y + (VIEW_H / 2) * TILE
	brown := 0
	for yy in 0 ..< TILE {
		for xx in 0 ..< TILE {
			if get_px(f, cx + xx, cy + yy) == COLOR_BROWN {
				brown += 1
			}
		}
	}
	testing.expect(t, brown > 10)
}
