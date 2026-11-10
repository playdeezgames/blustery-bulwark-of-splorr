#+build !js
package game

import "core:testing"

// A new character past creation, standing in town.
town_game :: proc(seed: u64 = 12345) -> ^Game {
	g := new(Game)
	init_game(g, seed)
	g.mode = .Play
	g.no_tenants = true
	return g
}

go_in :: proc(g: ^Game, s: Shop) {
	teleport(g, door_of(s))
	command(g, .Confirm)
}

// Chooses the first row of a shop that does `act` (and, when given, for `arg`). False if none.
choose :: proc(g: ^Game, act: Act, arg := -1) -> bool {
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for i in 0 ..< n {
		if rows[i].act == act && (arg < 0 || rows[i].arg == arg) {
			g.menu_row = i
			command(g, .Confirm)
			return true
		}
	}
	return false
}

@(test)
test_a_new_character_starts_in_town :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g, 9)
	testing.expect(t, in_town(g))
	testing.expect_value(t, [2]int{g.x, g.y}, g.town.up + {0, 1})
	testing.expect_value(t, cell_at(g, g.town.up.x, g.town.up.y), Cell.Stairs_Up)
}

@(test)
test_every_door_is_reachable_and_its_own :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	path: ^[MAX_PATH][2]int = new([MAX_PATH][2]int)
	defer free(path)
	for s in Shop {
		if s == .None || s == .Carny {
			continue
		}
		d := door_of(s)
		testing.expect_value(t, cell_at(g, d.x, d.y), Cell.Door)
		testing.expect_value(t, shop_at(d.x, d.y), s)
		testing.expect(t, find_path(floor_of(g), {g.x, g.y}, d, path) > 0)
	}
	testing.expect(t, find_path(floor_of(g), {g.x, g.y}, g.town.down, path) > 0)
}

@(test)
test_buying_at_the_general_store :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	go_in(g, .General)
	testing.expect_value(t, g.mode, Mode.Shop)
	testing.expect_value(t, g.shop, Shop.General)
	before := carried_jools(g)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Cheese)))
	testing.expect_value(t, carried_jools(g), before - VALUE[.Cheese])
	found := false
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Cheese && is_carried(g, i) {
			found = true
		}
	}
	testing.expect(t, found)
	// Too few Jools: nothing changes hands.
	pay(g, carried_jools(g))
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Bread)))
	testing.expect_value(t, carried_jools(g), 0)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "You have too few Jools.")
	command(g, .Cancel)
	testing.expect_value(t, g.mode, Mode.Play)
}

@(test)
test_the_smith_mends :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	dagger := worn(g, .Weapon)
	for _ in 0 ..< 5 {
		wear_down(g, dagger)
	}
	go_in(g, .Smith)
	before := carried_jools(g)
	testing.expect(t, choose(g, .Repair, dagger))
	testing.expect_value(t, int(g.items[dagger].dur), KIND[.Dagger].durability)
	testing.expect_value(t, carried_jools(g), before - 5)
	testing.expect(t, !choose(g, .Repair, dagger)) // nothing left to mend
}

@(test)
test_the_sage_and_the_temple :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	ring := give(g, .Ring_Draught)
	go_in(g, .Sage)
	testing.expect(t, choose(g, .Identify, ring))
	testing.expect(t, .Ring_Draught in g.ident)
	command(g, .Cancel)
	wear(g, ring, .Ring_Left)
	g.health = 5
	receive_jools(g, 100)
	go_in(g, .Temple)
	testing.expect(t, choose(g, .Heal))
	testing.expect_value(t, g.health, max_health(g))
	testing.expect(t, choose(g, .Uncurse))
	testing.expect(t, !g.items[ring].cursed)
}

@(test)
test_the_junk_shop_buys_trophies :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	ear := give(g, .Kobold_Ear)
	go_in(g, .Junk)
	before := carried_jools(g)
	testing.expect(t, choose(g, .Sell, ear))
	testing.expect_value(t, carried_jools(g), before + VALUE[.Kobold_Ear])
	testing.expect_value(t, g.items[ear].kind, Item_Kind.None)
}

@(test)
test_banked_jools_are_safe :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	have := carried_jools(g)
	go_in(g, .Bank)
	testing.expect(t, choose(g, .Deposit))
	testing.expect_value(t, g.bank, have)
	testing.expect_value(t, carried_jools(g), 0)
	command(g, .Cancel)
	enter_floor(g, 0, .Stairs_Down)
	hurt(g, 1000, "a test")
	command(g, .Confirm)
	testing.expect_value(t, g.bank, have)
	go_in(g, .Bank)
	testing.expect(t, choose(g, .Withdraw, 10))
	testing.expect_value(t, carried_jools(g), 10)
	testing.expect_value(t, g.bank, have - 10)
}

@(test)
test_the_tavern_feeds_and_trains :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	g.hunger = 950
	go_in(g, .Tavern)
	testing.expect(t, choose(g, .Meal))
	testing.expect_value(t, g.hunger, 0)
	testing.expect(t, choose(g, .Train))
	testing.expect_value(t, g.xp, TRAIN_XP)
	testing.expect(t, !choose(g, .Train)) // once a visit
	testing.expect(t, choose(g, .Talk))
}

@(test)
test_the_herald_claims_yer_deeds :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	testing.expect_value(t, g.proclamation_n, 0)
	enter_floor(g, 0, .Stairs_Down)
	use_here(g) // back down to town
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has conquered floor 1 of his own bulwark, as foretold.")
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "The town cheers the lord.")
	// Nothing new: no proclamation.
	n := g.proclamation_n
	enter_floor(g, 0, .Stairs_Down)
	g.log = {}
	use_here(g)
	testing.expect(t, message(&g.log[LOG_LINES - 1]) != "The town cheers the lord.")
	testing.expect_value(t, g.proclamation_n, n)
	// Kills are evictions.
	g.kills = 3
	enter_floor(g, 0, .Stairs_Down)
	use_here(g)
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has evicted 3 tenants for late rent.")
}

@(test)
test_town_is_calm_and_daylit :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	fuel := torch_fuel(g)
	start := [2]int{g.x, g.y}
	for _ in 0 ..< 40 {
		command(g, .Wait)
	}
	testing.expect_value(t, torch_fuel(g), fuel)
	testing.expect_value(t, [2]int{g.x, g.y}, start)
	testing.expect(t, g.vis[g.town.down.y][g.town.down.x])
}

@(test)
test_the_carny_ring_toss :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	receive_jools(g, 200)
	spot := open_spot(g)
	teleport(g, spot)
	new_tenant(g, .Carny, g.current, spot.x + 1, spot.y)
	command(g, .East)
	testing.expect_value(t, g.shop, Shop.Carny)
	won := false
	for _ in 0 ..< 60 {
		choose(g, .Toss) // a prize is a potion
		for i in 1 ..< MAX_ITEMS {
			if KIND[g.items[i].kind].group == .Potion && is_carried(g, i) {
				won = true
			}
		}
		if won {
			break
		}
	}
	testing.expect(t, won)
	testing.expect(t, choose(g, .Leave))
	testing.expect_value(t, g.mode, Mode.Play)
}
