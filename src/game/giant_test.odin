#+build !js
package game

import "core:strings"
import "core:testing"

// Floor 12 with its tenants, the player on its stairs down, no gust coming.
giant_game :: proc(seed: u64 = 1) -> ^Game {
	g := new_game(seed)
	g.no_tenants = false
	enter_floor(g, GIANT_INDEX, .Stairs_Down)
	g.gust_in = 1000
	return g
}

find_giant :: proc(g: ^Game) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Giant {
			return i
		}
	}
	return 0
}

// Puts you `n` cells west of the giant, awake and after you.
face_giant :: proc(g: ^Game, n: int) -> int {
	id := find_giant(g)
	t := &g.tenants[id]
	teleport(g, {int(t.x) - n, int(t.y)})
	t.awake = true
	return id
}

@(test)
test_floor_twelve_holds_the_giant_on_its_crate :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	enter_floor(g, GIANT_INDEX - 1, .Stairs_Down)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	f := floor_of(g)
	testing.expect_value(t, f.number, 12)
	testing.expect_value(t, [2]int{g.x, g.y}, f.down)
	testing.expect_value(t, f.wind_from, 2) // from the west, down the hall toward the stairs up
	testing.expect_value(t, gust_period(f.number), 6)
	testing.expect_value(t, snuff_chance(f.number), 75)
	id := find_giant(g)
	testing.expect(t, id != 0 && g.giant_up)
	giant := g.tenants[id]
	crate := loose_crate(g)
	testing.expect(t, crate != 0)
	testing.expect_value(t, [2]i16{g.items[crate].x, g.items[crate].y}, [2]i16{giant.x, giant.y})
	testing.expect_value(t, int(giant.health), 40)
	testing.expect(t, g.giant_ticket != 0 && g.tenants[g.giant_ticket].kind == .Carny)
	inspect_tenant(g, id)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "A giant. An ogre on a crate."))
	// Leaving and coming back does not restock it.
	enter_floor(g, GIANT_INDEX - 1, .Stairs_Up)
	g.turn += 10 * RESTOCK_TURNS
	enter_floor(g, GIANT_INDEX, .Stairs_Down)
	testing.expect_value(t, count_tenants(g, GIANT_INDEX), 2)
}

@(test)
test_the_giant_carny_takes_four_jools :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	c := g.tenants[g.giant_ticket]
	teleport(g, {int(c.x) - 1, int(c.y)})
	before := carried_jools(g)
	command(g, .East)
	testing.expect_value(t, g.shop, Shop.Giant_Door)
	testing.expect(t, choose(g, .Admit))
	testing.expect(t, g.giant_admitted && !g.army_admitted && !g.admitted)
	testing.expect_value(t, carried_jools(g), before - GIANT_ADMISSION)
	testing.expect_value(t, [2]int{int(g.tenants[g.giant_ticket].x), int(g.tenants[g.giant_ticket].y)}, giant_alcove())
	command(g, .East) // the doorway is clear
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{int(c.x), int(c.y)})
}

@(test)
test_on_its_crate_the_giant_strikes_from_two_cells :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	id := face_giant(g, 2)
	lows, highs, hits := 99, 0, 0
	for _ in 0 ..< 400 {
		g.health = max_health(g)
		g.mode = .Play
		before := g.health
		tenant_act(g, id)
		testing.expect(t, g.giant_up)
		testing.expect_value(t, [2]int{g.x, g.y}, [2]int{int(g.tenants[id].x) - 2, int(g.tenants[id].y)}) // it stays put
		if lost := before - g.health; lost > 0 {
			hits += 1
			lows, highs = min(lows, lost), max(highs, lost)
		}
	}
	testing.expect(t, hits > 0)
	testing.expect(t, lows >= GIANT_DMIN && highs <= GIANT_DMAX)
	testing.expect(t, highs == GIANT_DMAX) // it reaches the top of its range
	// Three cells off it cannot reach you.
	teleport(g, {int(g.tenants[id].x) - 3, int(g.tenants[id].y)})
	g.health = max_health(g)
	for _ in 0 ..< 50 {
		tenant_act(g, id)
	}
	testing.expect_value(t, g.health, max_health(g))
	// It acts every turn while up, every other turn once off.
	g.tenants[id].energy = 0
	tenants_act(g)
	testing.expect_value(t, int(g.tenants[id].energy), 0)
}

@(test)
test_a_gust_tips_the_crate_one_time_in_three :: proc(t: ^testing.T) {
	tipped := 0
	for seed in 1 ..= 300 {
		g := giant_game(u64(seed))
		id := face_giant(g, 5)
		blow_tenants(g)
		if !g.giant_up {
			tipped += 1
			crate := g.items[loose_crate(g)]
			// Downwind (east), two cells, out from under it; the giant stays where it stood.
			testing.expect_value(t, [2]i16{crate.x, crate.y}, [2]i16{g.tenants[id].x + 2, g.tenants[id].y})
		}
		free(g)
	}
	testing.expect(t, tipped > 70 && tipped < 130)
}

@(test)
test_a_gale_or_a_gust_ball_knocks_it_off_and_a_bolt_does_not :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	id := face_giant(g, 2)
	g.mana = 99
	cast_spell(g, .Magic_Bolt, {1, 0})
	testing.expect(t, g.giant_up)
	cast_spell(g, .Gale, {1, 0})
	testing.expect(t, !g.giant_up)
	testing.expect_value(t, message(&g.last_said), "The crate flies out from under the giant. It is only an ogre.")
	crate := g.items[loose_crate(g)]
	testing.expect(t, crate.x > g.tenants[id].x) // away from you
	// Back on, then a gust ball.
	g.giant_up = true
	g.items[loose_crate(g)].x, g.items[loose_crate(g)].y = g.tenants[id].x, g.tenants[id].y
	g.gust_in = 99
	cast_spell(g, .Gust_Ball, {1, 0})
	testing.expect(t, !g.giant_up)
	// And a squall.
	g.giant_up = true
	g.items[loose_crate(g)].x, g.items[loose_crate(g)].y = g.tenants[id].x, g.tenants[id].y
	g.gust_in = 99
	cast_spell(g, .Squall, {1, 0})
	testing.expect(t, !g.giant_up)
}

@(test)
test_off_its_crate_the_giant_climbs_back :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	id := face_giant(g, 3) // near enough to see it climb
	tip_crate(g, id, {1, 0}, true)
	testing.expect(t, !g.giant_up)
	inspect_tenant(g, id)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "A giant. An ogre. Exactly as tall as an ogre."))
	climbed := false
	for _ in 0 ..< 10 {
		tenant_act(g, id)
		if g.giant_up {
			climbed = true
			break
		}
	}
	testing.expect(t, climbed)
	crate := g.items[loose_crate(g)]
	testing.expect_value(t, [2]i16{crate.x, crate.y}, [2]i16{g.tenants[id].x, g.tenants[id].y})
	testing.expect_value(t, message(&g.last_said), "The giant climbs back onto its crate.")
}

@(test)
test_a_loose_crate_blows_and_a_carried_one_ends_the_climbing :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	id := face_giant(g, 8)
	tip_crate(g, id, {1, 0}, true)
	crate := loose_crate(g)
	x := g.items[crate].x
	blow_items(g)
	testing.expect_value(t, g.items[crate].x, x + 2) // 4 kg, but empty: the wind takes it
	// Picked up, it is out of the giant's reach for good: it fights as an ogre.
	teleport(g, {int(g.items[crate].x), int(g.items[crate].y)})
	pick_up(g, crate)
	testing.expect(t, is_carried(g, crate))
	testing.expect_value(t, KIND[.Crate].weight, 4000)
	testing.expect_value(t, loose_crate(g), 0)
	g.tenants[id].x, g.tenants[id].y = i16(g.x - 3), i16(g.y)
	for _ in 0 ..< 20 {
		g.health = max_health(g)
		tenant_act(g, id)
		testing.expect(t, !g.giant_up)
	}
	testing.expect(t, abs(int(g.tenants[id].x) - g.x) <= 1) // it came for you instead
}

@(test)
test_the_giant_drops_the_key_and_the_stretch_ends :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	id := face_giant(g, 1)
	at := [2]int{int(g.tenants[id].x), int(g.tenants[id].y)}
	kill_tenant(g, id)
	testing.expect(t, g.giant_dead && !g.giant_up)
	key, tooth := 0, 0
	for i in 1 ..< MAX_ITEMS {
		it := g.items[i]
		if it.place == .Ground && int(it.x) == at.x && int(it.y) == at.y {
			#partial switch it.kind {
			case .Key_Thirteen:
				key = i
			case .Ogre_Tooth:
				tooth = i
			}
		}
	}
	testing.expect(t, key != 0 && tooth != 0 && key > tooth) // the key on top
	// The door is locked until the key is carried.
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The door to floor 13 is locked."))
	teleport(g, at)
	pick_up(g, key)
	testing.expect_value(t, g.mode, Mode.Notice)
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	pick_up(g, key) // only once
	testing.expect_value(t, g.mode, Mode.Play)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect(t, GIANT_INDEX in g.unlocked)
	testing.expect_value(t, message(&g.last_said), "You climb to floor 13. The wind is stronger.")
	testing.expect_value(t, g.current, GIANT_INDEX + 1)
}

@(test)
test_the_herald_proclaims_the_giant_and_hands_a_certificate :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	g.giant_dead = true
	g.army_told = true
	g.told = {g.deepest, g.level, g.kills, g.deaths, g.boss_dead}
	enter_town(g, .Gate)
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has felled a giant, as foretold.")
	testing.expect(t, has_kind(g, .Certificate))
	testing.expect(t, KIND[.Certificate].trophy)
	testing.expect_value(t, VALUE[.Certificate], 5)
	enter_floor(g, 0, .Stairs_Down)
	enter_town(g, .Gate)
	n := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Certificate {
			n += 1
		}
	}
	testing.expect_value(t, n, 1)
	// The windchute reaches floor 12.
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect(t, choose(g, .Chute, GIANT_INDEX))
	testing.expect_value(t, g.current, GIANT_INDEX)
	testing.expect_value(t, message(&g.last_said), "The windchute blows you up to floor 12.")
}

@(test)
test_floor_twelve_survives_a_save :: proc(t: ^testing.T) {
	g := giant_game()
	defer free(g)
	before := g.floors[GIANT_INDEX].cells
	g.floors[GIANT_INDEX].cells = {}
	restore_cells(g)
	testing.expect(t, g.floors[GIANT_INDEX].cells == before)
}
