#+build !js
package game

import "core:testing"

// Floor 1 opened up into one big room with the wind blowing east (from the west), the player at
// (20, 20), no ground items, a full gust_in so no gust interferes. Spells known: all of them.
open_room :: proc() -> ^Game {
	g := new_game()
	f := floor_of(g)
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			edge := x == 0 || y == 0 || x == FLOOR_W - 1 || y == FLOOR_H - 1
			f.cells[y][x] = edge ? .Wall : .Floor
		}
	}
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Ground {
			g.items[i] = {}
		}
	}
	f.wind_from = 2 // W, so it blows east
	g.gust_in = 1000
	g.known = ~bit_set[Spell]{}
	teleport(g, {20, 20})
	return g
}

@(test)
test_first_spell_is_chosen_after_creation :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g, 3)
	g.create_row = CREATE_BEGIN_ROW
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Learn)
	command(g, .Cancel) // must choose
	testing.expect_value(t, g.mode, Mode.Learn)
	command(g, .South)
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.known, bit_set[Spell]{.Gust_Ball})
	testing.expect_value(t, g.mana, max_mana(g))
}

@(test)
test_every_spell_is_offered :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	list: [len(Spell)]Spell
	testing.expect_value(t, learnable(g, &list), len(Spell))
}

@(test)
test_a_kill_can_raise_a_level :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.known = {}
	g.attr[.Dexterity] = 100 // never miss
	g.xp = xp_for_level(2) - 1
	id := new_tenant(g, .Rat, g.current, 21, 20)
	g.tenants[id].health = 1
	before := max_health(g)
	for _ in 0 ..< 50 {
		if g.tenants[id].kind == .None {
			break
		}
		g.health = max_health(g)
		command(g, .East)
	}
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.None)
	testing.expect_value(t, g.level, 2)
	testing.expect_value(t, max_health(g), before + LEVEL_HEALTH)
	testing.expect_value(t, g.mode, Mode.Learn)
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, card(g.known), 1)
}

@(test)
test_bolt_drifts_downwind :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	// North across an east wind: 7 cells, a cell east after the 3rd and the 6th.
	cast_spell(g, .Magic_Bolt, {0, -1})
	testing.expect_value(t, g.fx[g.fx_len - 1], [2]int{22, 13})
	testing.expect_value(t, g.fx_len, 9)
	// A rat where it ends takes the bolt.
	g.mana = max_mana(g)
	id := new_tenant(g, .Beetle, g.current, 22, 13)
	cast_spell(g, .Magic_Bolt, {0, -1})
	testing.expect(t, g.tenants[id].kind == .None || g.tenants[id].health < i16(TENANT[.Beetle].health))
	testing.expect(t, g.tenants[id].kind == .None || g.tenants[id].awake)
}

@(test)
test_bolt_goes_farther_with_the_wind :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	cast_spell(g, .Magic_Bolt, {1, 0})
	testing.expect_value(t, g.fx[g.fx_len - 1], [2]int{20 + BOLT_RANGE + 1, 20})
	cast_spell(g, .Magic_Bolt, {-1, 0})
	testing.expect_value(t, g.fx[g.fx_len - 1], [2]int{20 - BOLT_RANGE + 1, 20})
}

@(test)
test_gust_ball_into_a_wall_catches_you :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	teleport(g, {1, 20}) // the west wall beside you
	id := new_tenant(g, .Beetle, g.current, 2, 21)
	cast_spell(g, .Gust_Ball, {-1, 0})
	testing.expect(t, g.fx_blast)
	testing.expect_value(t, g.fx_at, [2]int{1, 20})
	testing.expect(t, g.health < max_health(g))
	testing.expect(t, g.tenants[id].kind == .None || g.tenants[id].health < i16(TENANT[.Beetle].health))
}

@(test)
test_casting_short_of_mana_costs_health :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.mana = 1
	g.mode = .Cast
	g.menu_row = 0 // Magic Bolt, 3 mana
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Aim)
	command(g, .North)
	testing.expect_value(t, g.mana, 0)
	testing.expect_value(t, g.health, max_health(g) - 2)
	testing.expect_value(t, g.turn, 1)
	// With too little health left, it kills.
	g.health = 2
	cast_spell(g, .Ward, {0, 0})
	testing.expect_value(t, g.mode, Mode.Dead)
	testing.expect_value(t, g.killed_by, "casting past yer mana")
}

@(test)
test_cast_and_aim_by_keys_and_pointer :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	command(g, .Cast)
	testing.expect_value(t, g.mode, Mode.Cast)
	command(g, .Confirm) // Magic Bolt
	testing.expect_value(t, g.mode, Mode.Aim)
	command(g, .Cancel)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.mana, max_mana(g))
	command(g, .Cast)
	command(g, .Confirm)
	// A click up and to the right of you aims north-east.
	sx := MAP_X + (VIEW_W / 2 + 3) * TILE + 2
	sy := MAP_Y + (VIEW_H / 2 - 1) * TILE + 2
	pointer(g, sx, sy, .Mouse_Primary)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.mana, max_mana(g) - SPELL[.Magic_Bolt].cost)
	testing.expect_value(t, g.fx[0], [2]int{21, 19})
	testing.expect_value(t, g.turn, 1)
}

@(test)
test_panel_hint_opens_cast :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	h := PANEL_HINTS[2]
	pointer(g, PANEL_X + 2 + h.x + 3, PANEL_HINT_Y + 2, .Touch)
	testing.expect_value(t, g.mode, Mode.Cast)
}

@(test)
test_ward_raises_armour_then_fades :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	before := armour_worn(g)
	cast_spell(g, .Ward, {0, 0})
	testing.expect_value(t, armour_worn(g), before + WARD_ARMOUR)
	for _ in 0 ..< WARD_TURNS {
		command(g, .Wait)
		g.items[worn(g, .Light)].fuel = TORCH_TURNS
	}
	testing.expect_value(t, armour_worn(g), before)
}

@(test)
test_anchor_holds_through_one_gust :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	cast_spell(g, .Anchor, {0, 0})
	testing.expect(t, anchored(g))
	testing.expect(t, !load_anchors(g)) // and it does not slow you
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{20, 20})
	testing.expect(t, !anchored(g))
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{21, 20})
}

@(test)
test_kindle_takes_no_turn :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = false
	cast_spell(g, .Kindle, {0, 0})
	testing.expect(t, g.lit)
	testing.expect_value(t, g.turn, 0)
	testing.expect_value(t, g.mana, max_mana(g) - SPELL[.Kindle].cost)
	choose_spell(g, .Kindle) // already burning: nothing is spent
	testing.expect_value(t, g.mana, max_mana(g) - SPELL[.Kindle].cost)
}

@(test)
test_mana_comes_back :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.mana = 0
	for _ in 0 ..< mana_period(g) {
		command(g, .Wait)
	}
	testing.expect_value(t, g.mana, 1)
}

@(test)
test_return_hop_mend_and_sense :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, 2, .Stairs_Down)
	g.known = ~bit_set[Spell]{}
	g.mana = 100
	start := [2]int{g.x, g.y}
	cast_spell(g, .Hop, {0, 0})
	testing.expect(t, [2]int{g.x, g.y} != start)
	testing.expect(t, passable(cell_at(g, g.x, g.y)))
	g.health = 1
	cast_spell(g, .Mend, {0, 0})
	testing.expect(t, g.health >= 5)
	cast_spell(g, .Sense_Tenants, {0, 0})
	testing.expect(t, g.sense_turns > 0)
	cast_spell(g, .Return, {0, 0})
	testing.expect_value(t, g.current, 0)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
}
