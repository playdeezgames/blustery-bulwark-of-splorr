#+build !js
package game

import "core:testing"

// Floor 8 with its tenants, the player on its stairs down, no gust coming.
army_game :: proc() -> ^Game {
	g := new_game()
	g.no_tenants = false
	enter_floor(g, ARMY_INDEX, .Stairs_Down)
	g.gust_in = 1000
	return g
}

count_army :: proc(g: ^Game, k: Tenant_Kind) -> int {
	n := 0
	for &t in g.tenants {
		if t.kind == k && int(t.floor) == ARMY_INDEX {
			n += 1
		}
	}
	return n
}

find_army :: proc(g: ^Game, k: Tenant_Kind) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == k && int(g.tenants[i].floor) == ARMY_INDEX {
			return i
		}
	}
	return 0
}

@(test)
test_floor_seven_climbs_to_the_army :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, ARMY_INDEX - 1, .Stairs_Down)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	f := floor_of(g)
	testing.expect_value(t, f.number, 8)
	testing.expect_value(t, [2]int{g.x, g.y}, f.down)
	testing.expect_value(t, f.wind_from, 2) // from the west, down the hall
	testing.expect_value(t, gust_period(f.number), 8)
	testing.expect_value(t, snuff_chance(f.number), 65)
}

@(test)
test_floor_eight_holds_the_army :: proc(t: ^testing.T) {
	g := army_game()
	defer free(g)
	testing.expect_value(t, count_army(g, .Rat), 40)
	testing.expect_value(t, count_army(g, .Sergeant), 1)
	testing.expect(t, g.army_ticket != 0 && g.tenants[g.army_ticket].kind == .Carny)
	testing.expect(t, TENANT[.Rat].light && !TENANT[.Sergeant].light) // gusts sweep the rats, not the sergeant
	// Leaving and coming back does not restock it.
	g.tenants[find_army(g, .Rat)] = {}
	enter_floor(g, ARMY_INDEX - 1, .Stairs_Up)
	g.turn += 10 * RESTOCK_TURNS
	enter_floor(g, ARMY_INDEX, .Stairs_Down)
	testing.expect_value(t, count_army(g, .Rat), 39)
}

@(test)
test_the_army_carny_takes_three_jools :: proc(t: ^testing.T) {
	g := army_game()
	defer free(g)
	c := g.tenants[g.army_ticket]
	teleport(g, {int(c.x) - 1, int(c.y)})
	before := carried_jools(g)
	command(g, .East)
	testing.expect_value(t, g.shop, Shop.Army_Door)
	testing.expect(t, choose(g, .Admit))
	testing.expect(t, g.army_admitted)
	testing.expect(t, !g.admitted) // floor 4's ticket is its own
	testing.expect_value(t, carried_jools(g), before - ARMY_ADMISSION)
	testing.expect_value(t, [2]int{int(g.tenants[g.army_ticket].x), int(g.tenants[g.army_ticket].y)}, army_alcove())
	command(g, .East) // the doorway is clear
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{int(c.x), int(c.y)})
}

@(test)
test_the_sergeant_drops_the_key_and_the_rats_scatter :: proc(t: ^testing.T) {
	g := army_game()
	defer free(g)
	id := find_army(g, .Sergeant)
	s := g.tenants[id]
	kill_tenant(g, id)
	testing.expect(t, g.army_dead)
	testing.expect_value(t, count_army(g, .Rat), 0)
	testing.expect_value(t, count_army(g, .Carny), 1) // the carny stays
	if g.mode == .Learn {
		command(g, .Confirm)
	}
	teleport(g, {int(s.x), int(s.y)})
	testing.expect_value(t, g.items[ground_item_at(g, g.x, g.y)].kind, Item_Kind.Key_Nine)
	command(g, .Confirm)
	for g.mode == .Learn {
		command(g, .Confirm) // the sergeant's XP can bring another spell to choose
	}
	testing.expect(t, has_kind(g, .Key_Nine))
	testing.expect_value(t, g.mode, Mode.Play) // no notice since step 17: the stretch goes on
	key := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Key_Nine {
			key = i
		}
	}
	// The key cannot be sold.
	testing.expect(t, !sellable(g, key))
}

@(test)
test_the_door_to_floor_nine_opens_and_stays_open :: proc(t: ^testing.T) {
	g := army_game()
	defer free(g)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, g.current, ARMY_INDEX)
	testing.expect_value(t, message(&g.last_said), "The door to floor 9 is locked. The army has the key, they say.")
	id := new_item(g, .Key_Nine)
	testing.expect(t, stow(g, id))
	command(g, .Confirm)
	testing.expect_value(t, g.current, ARMY_INDEX + 1) // floor 9
	testing.expect_value(t, message(&g.last_said), "You climb to floor 9. The wind is stronger.")
	testing.expect(t, ARMY_INDEX in g.unlocked)
	// Floor 9's stairs down come back to the door.
	teleport(g, floor_of(g).down)
	command(g, .Confirm)
	testing.expect_value(t, g.current, ARMY_INDEX)
	testing.expect_value(t, [2]int{g.x, g.y}, floor_of(g).up)
	free_item(g, id) // lost: the door stays open
	command(g, .Confirm)
	testing.expect_value(t, g.current, ARMY_INDEX + 1)
}

@(test)
test_the_herald_proclaims_the_rout_and_pins_a_medal :: proc(t: ^testing.T) {
	g := army_game()
	defer free(g)
	g.army_dead = true
	g.told = {g.deepest, g.level, g.kills, g.deaths, g.boss_dead}
	enter_town(g, .Gate)
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has routed an army of a thousand, as foretold.")
	testing.expect(t, has_kind(g, .Medal))
	testing.expect(t, KIND[.Medal].trophy)
	testing.expect_value(t, VALUE[.Medal], 5)
	// Once.
	enter_floor(g, 0, .Stairs_Down)
	enter_town(g, .Gate)
	medals := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Medal {
			medals += 1
		}
	}
	testing.expect_value(t, medals, 1)
}

@(test)
test_the_windchute_reaches_floor_eight :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	g.deepest = 7
	enter_town(g, .Gate)
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect_value(t, g.shop, Shop.Gate)
	n := 0
	rows: [MAX_ROWS]Row
	n = shop_rows(g, &rows)
	chutes := 0
	for r in rows[:n] {
		if r.act == .Chute {
			chutes += 1
		}
	}
	testing.expect_value(t, chutes, 1) // floor 4 only
	leave_shop(g)
	g.deepest = 8
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect(t, choose(g, .Chute, ARMY_INDEX))
	testing.expect_value(t, g.current, ARMY_INDEX)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
	testing.expect_value(t, message(&g.last_said), "The windchute blows you up to floor 8.")
}
