#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 29: floor 16, the top.

roof_game :: proc(seed: u64 = 1) -> ^Game {
	g := new_game(seed)
	g.no_tenants = false
	enter_floor(g, LORD_INDEX, .Stairs_Down)
	return g
}

find_on_roof :: proc(g: ^Game, k: Tenant_Kind) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == k {
			return i
		}
	}
	return 0
}

@(test)
test_the_roof_holds_six_guards_and_the_lord :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	enter_floor(g, CHAMPION_INDEX, .Stairs_Down)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	f := floor_of(g)
	testing.expect_value(t, f.number, 16)
	testing.expect_value(t, [2]int{g.x, g.y}, f.down)
	testing.expect_value(t, gust_period(16), 4)
	testing.expect_value(t, gust_push(16), 3)
	testing.expect_value(t, g.gust_in, 4)
	guards := 0
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Guard && int(g.tenants[i].floor) == LORD_INDEX {
			guards += 1
		}
	}
	testing.expect_value(t, guards, 6)
	testing.expect_value(t, count_tenants(g, LORD_INDEX), 7)
	gd := TENANT[.Guard]
	testing.expect_value(t, [5]int{gd.health, gd.dmin, gd.dmax, gd.hit, gd.defence}, [5]int{20, 2, 7, 60, 15})
	testing.expect_value(t, VALUE[.Contract], 6)
	// No stairs up: the top.
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			testing.expect(t, f.cells[y][x] != .Stairs_Up)
		}
	}
	g.mana = 99
	cast_spell(g, .Find_Stairs, {})
	testing.expect_value(t, message(&g.last_said), "The spell finds no way up from here.")
	// No restocking; saves rebuild the roof.
	enter_floor(g, CHAMPION_INDEX, .Stairs_Up)
	g.turn += 10 * RESTOCK_TURNS
	enter_floor(g, LORD_INDEX, .Stairs_Down)
	testing.expect_value(t, count_tenants(g, LORD_INDEX), 7)
	before := f.cells
	f.cells = {}
	restore_cells(g)
	testing.expect(t, f.cells == before)
}

@(test)
test_on_the_roof_the_wind_backs_round_after_every_gust :: proc(t: ^testing.T) {
	g := roof_game()
	defer free(g)
	f := floor_of(g)
	testing.expect_value(t, COMPASS[f.wind_from], "W")
	want := [?]string{"S", "E", "N", "W", "S"}
	for w in want {
		g.gust_in = 1
		g.mode = .Play
		g.health = max_health(g)
		end_turn(g)
		testing.expect_value(t, COMPASS[f.wind_from], w)
	}
	said := false
	for i in 0 ..< LOG_LINES {
		if message(&g.log[i]) == "The wind backs round." {
			said = true
		}
	}
	testing.expect(t, said)
	// And the next gust blows from where it now comes from: from the south, so north.
	teleport(g, f.down + {6, 0})
	g.lit = false
	for i in 1 ..< MAX_TENANTS {
		if int(g.tenants[i].floor) == LORD_INDEX {
			g.tenants[i] = {}
		}
	}
	start := [2]int{g.x, g.y}
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, start + 3 * wind_blow(f))
	testing.expect_value(t, wind_blow(f), [2]int{0, -1})
	// Elsewhere the wind holds its direction.
	b := new_game()
	defer free(b)
	enter_floor(b, GIANT_INDEX + 1, .Stairs_Down)
	from := floor_of(b).wind_from
	b.gust_in = 1
	end_turn(b)
	testing.expect_value(t, floor_of(b).wind_from, from)
}

@(test)
test_his_lordship_nods_and_cannot_be_harmed :: proc(t: ^testing.T) {
	g := roof_game()
	defer free(g)
	g.gust_in = 1000
	id := find_on_roof(g, .Lord)
	testing.expect(t, id != 0)
	lord := g.tenants[id]
	inspect_tenant(g, id)
	testing.expect_value(t, message(&g.last_said), "A very old man in a chair, with a cup of tea.")
	teleport(g, {int(lord.x) - 1, int(lord.y)})
	turn := g.turn
	command(g, .East)
	testing.expect_value(t, g.mode, Mode.Notice)
	testing.expect_value(t, g.notice, Notice_Kind.Lord)
	testing.expect(t, g.lord_met)
	testing.expect_value(t, message(&g.last_said), "He looks up, nods, and goes back to his tea.")
	testing.expect_value(t, g.turn, turn) // no blow, no turn
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	command(g, .East) // again: the nod, but the notice only once
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, int(g.tenants[id].health), 1)
	inspect_tenant(g, id)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "His Lordship. A very old man"))
	// Spells will not touch him, and he never moves.
	g.mana = 99
	spell_hit(g, id, 50, "magic bolt")
	testing.expect_value(t, message(&g.last_said), "You cannot bring yerself to.")
	cast_gale(g, {1, 0}, true)
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.Lord)
	testing.expect_value(t, [2]i16{g.tenants[id].x, g.tenants[id].y}, [2]i16{lord.x, lord.y})
	for _ in 0 ..< 30 {
		tenant_act(g, id)
	}
	testing.expect_value(t, [2]i16{g.tenants[id].x, g.tenants[id].y}, [2]i16{lord.x, lord.y})
	// The guards come for you; they are ordinary.
	gid := find_on_roof(g, .Guard)
	kill_tenant(g, gid)
	testing.expect_value(t, g.tenants[gid].kind, Tenant_Kind.None)
}

@(test)
test_the_lord_and_the_champion_always_find_room :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	for i in 1 ..< MAX_TENANTS {
		g.tenants[i] = {kind = .Rat, floor = 2, x = 1, y = 1, health = 3}
	}
	testing.expect_value(t, new_tenant(g, .Goblin, LORD_INDEX, 5, 5), 0)
	id := new_tenant(g, .Lord, LORD_INDEX, 5, 5)
	testing.expect(t, id != 0 && g.tenants[id].kind == .Lord)
	c := new_tenant(g, .Champion, CHAMPION_INDEX, 5, 5)
	testing.expect(t, c != 0 && c != id && g.tenants[c].kind == .Champion)
}
