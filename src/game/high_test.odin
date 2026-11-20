#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 24: floors 13 and 14, generated, where a gust pushes three cells.

// The first cell with `n` open cells downwind of it, or {}.
open_run :: proc(f: ^Floor, n: int) -> [2]int {
	d := wind_blow(f)
	for y in 3 ..< f.h - 3 {
		for x in 3 ..< f.w - 3 {
			ok := f.cells[y][x] == .Floor
			for k in 1 ..= n {
				if !ok {
					break
				}
				ok = f.cells[y + k * d.y][x + k * d.x] == .Floor
			}
			if ok {
				return {x, y}
			}
		}
	}
	return {}
}

@(test)
test_the_door_on_floor_twelve_opens_on_floor_thirteen :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, GIANT_INDEX, .Stairs_Down)
	g.unlocked += {GIANT_INDEX}
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	f := floor_of(g)
	testing.expect_value(t, f.number, 13)
	testing.expect_value(t, [2]int{g.x, g.y}, f.down)
	testing.expect_value(t, f.w, 64)
	testing.expect_value(t, f.h, 44)
	testing.expect_value(t, g.gust_in, 6)
	// Up to floor 14, then scaffolding above it.
	teleport(g, f.up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 14)
	testing.expect_value(t, message(&g.last_said), "You climb to floor 14. The wind is stronger.")
	testing.expect_value(t, g.gust_in, 5)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 14)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "Above: scaffolding, and a sign. \"Floor 15."))
	// And back down to floor 12, onto its stairs up.
	teleport(g, floor_of(g).down)
	command(g, .Confirm)
	teleport(g, floor_of(g).down)
	command(g, .Confirm)
	testing.expect_value(t, g.current, GIANT_INDEX)
	testing.expect_value(t, [2]int{g.x, g.y}, floor_of(g).up)
}

@(test)
test_from_floor_thirteen_a_gust_pushes_three_cells :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, GIANT_INDEX + 1, .Stairs_Down)
	f := floor_of(g)
	d := wind_blow(f)
	start := open_run(f, 3)
	testing.expect(t, start != {})
	teleport(g, start)
	g.lit = false
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, start + 3 * d)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "A gust hurls you "))
}

@(test)
test_a_heavy_load_on_floor_thirteen_holds_rarely_and_drags_two :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.attr[.Strength] = 8
	sack := new_item(g, .Sack)
	put_in(g, sack, worn(g, .Pack))
	put_in(g, new_item(g, .Jools, 100), sack)
	testing.expect(t, load_anchors(g))
	floor_of(g).number = 13
	g.lit = false
	held, dragged := 0, 0
	for _ in 0 ..< 300 {
		teleport(g, {20, 20})
		gust(g)
		switch g.x - 20 {
		case 0:
			held += 1
		case 2:
			dragged += 1
		case:
			testing.fail_now(t, "a heavy load on floor 13 moved neither 0 nor 2 cells")
		}
	}
	testing.expect(t, held > 10 && held < 55) // about 10 in 100
	testing.expect_value(t, held + dragged, 300)
}

// Floors 13 and 14 are generated like the others, crowded but in bounds, and survive a save.
@(test)
test_floors_thirteen_and_fourteen_fit_with_all_their_tenants :: proc(t: ^testing.T) {
	for seed in ([?]u64{1, 7, 12345}) {
		g := new_game(seed)
		g.no_tenants = false
		for i in 0 ..< BUILT_FLOORS {
			enter_floor(g, i, .Stairs_Down)
		}
		tenants := 0
		for i in 1 ..< MAX_TENANTS {
			if g.tenants[i].kind != .None {
				tenants += 1
			}
		}
		testing.expectf(t, tenants < MAX_TENANTS * 9 / 10, "seed %v: %v tenants", seed, tenants)
		testing.expect(t, count_tenants(g, GIANT_INDEX + 1) >= 4 + 2 * 13)
		testing.expect(t, count_tenants(g, GIANT_INDEX + 2) >= 4 + 2 * 14)
		before := g.floors[GIANT_INDEX + 2].cells
		g.floors[GIANT_INDEX + 2].cells = {}
		restore_cells(g)
		testing.expect(t, g.floors[GIANT_INDEX + 2].cells == before)
		free(g)
	}
}

// Slice 4 step 25: the three boasts that never got a floor, as ordinary tenants from floor 13.

@(test)
test_the_three_boasts_live_from_floor_thirteen :: proc(t: ^testing.T) {
	for k in ([?]Tenant_Kind{.Lizard, .Goat, .Peacock}) {
		testing.expect_value(t, TENANT[k].first, 13)
	}
	testing.expect(t, !TENANT[.Lizard].light) // heavy: gusts do not move it
	testing.expect_value(t, TENANT[.Lizard].health, 32)
	testing.expect_value(t, TENANT[.Lizard].xp, 18)
	testing.expect(t, TENANT[.Peacock].light && TENANT[.Peacock].rare && TENANT[.Peacock].speed == 20)
	testing.expect_value(t, VALUE[.Name_Tag], 15)
	testing.expect_value(t, VALUE[.Goat_Horn], 10)
	testing.expect_value(t, VALUE[.Peacock_Feather], 12)
	testing.expect(t, KIND[.Name_Tag].trophy && KIND[.Goat_Horn].trophy && KIND[.Peacock_Feather].trophy)
	// None of them below floor 13; all of them on floors 13 and 14, over a few seeds.
	seen: [Tenant_Kind]int
	for seed in ([?]u64{1, 2, 3, 4, 5}) {
		g := new_game(seed)
		g.no_tenants = false
		for i in 0 ..< BUILT_FLOORS {
			enter_floor(g, i, .Stairs_Down)
		}
		for i in 1 ..< MAX_TENANTS {
			tn := g.tenants[i]
			if tn.kind == .Lizard || tn.kind == .Goat || tn.kind == .Peacock {
				testing.expect(t, int(tn.floor) >= GIANT_INDEX + 1)
				seen[tn.kind] += 1
			}
		}
		free(g)
	}
	testing.expect(t, seen[.Lizard] > 0 && seen[.Goat] > 0 && seen[.Peacock] > 0)
	testing.expect(t, seen[.Peacock] < seen[.Goat]) // picked half as often
	g := open_room()
	defer free(g)
	id := new_tenant(g, .Lizard, g.current, 24, 20)
	inspect_tenant(g, id)
	testing.expect_value(t, message(&g.last_said), "A Dragon. A very large lizard. Its name tag says Dragon.")
}

@(test)
test_the_demon_charges_and_butts_you_back :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = true
	charged, butted := 0, 0
	for _ in 0 ..< 200 {
		teleport(g, {20, 20})
		g.health = max_health(g)
		g.mode = .Play
		for i in 1 ..< MAX_TENANTS {
			g.tenants[i] = {}
		}
		id := new_tenant(g, .Goat, g.current, 17, 20) // three cells west, in line
		g.tenants[id].awake = true
		g.tenants[id].tx, g.tenants[id].ty = 20, 20
		hp := g.health
		tenant_act(g, id)
		testing.expect_value(t, [2]i16{g.tenants[id].x, g.tenants[id].y}, [2]i16{19, 20}) // it rushed up
		charged += 1
		if g.health < hp {
			butted += 1
			testing.expect_value(t, [2]int{g.x, g.y}, [2]int{21, 20}) // a cell back, away from it
			testing.expect_value(t, message(&g.last_said), "The demon butts you E.")
		} else {
			testing.expect_value(t, [2]int{g.x, g.y}, [2]int{20, 20})
		}
	}
	testing.expect(t, butted > 60 && butted < 180)
	// Not in a straight line (a knight's move off): it walks instead.
	for i in 1 ..< MAX_TENANTS {
		g.tenants[i] = {}
	}
	teleport(g, {20, 20})
	id := new_tenant(g, .Goat, g.current, 17, 19)
	g.tenants[id].awake = true
	g.tenants[id].tx, g.tenants[id].ty = 20, 20
	tenant_act(g, id)
	testing.expect_value(t, [2]i16{g.tenants[id].x, g.tenants[id].y}, [2]i16{18, 20})
	// Against a wall: a slam that hurts more.
	slammed := false
	for _ in 0 ..< 100 {
		for i in 1 ..< MAX_TENANTS {
			g.tenants[i] = {}
		}
		teleport(g, {FLOOR_W - 2, 20})
		g.health = max_health(g)
		gid := new_tenant(g, .Goat, g.current, FLOOR_W - 4, 20)
		g.tenants[gid].awake = true
		g.tenants[gid].tx, g.tenants[gid].ty = i16(g.x), 20
		tenant_act(g, gid)
		if g.health < max_health(g) {
			testing.expect_value(t, g.x, FLOOR_W - 2)
			testing.expect_value(t, message(&g.last_said), "The demon butts you into the wall.")
			slammed = true
			break
		}
	}
	testing.expect(t, slammed)
}

@(test)
test_the_hundred_eyed_beast_screams_and_wakes_the_floor :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = true
	p := new_tenant(g, .Peacock, g.current, 24, 20)
	near := new_tenant(g, .Goblin, g.current, 30, 25) // 6 cells from it, out of yer sight
	far := new_tenant(g, .Goblin, g.current, 40, 35) // 16 cells from it
	friend := new_tenant(g, .Carny, g.current, 26, 22) // peaceful: it does not care
	tenant_act(g, p)
	testing.expect(t, g.tenants[p].awake)
	testing.expect(t, g.tenants[near].awake)
	testing.expect_value(t, [2]i16{g.tenants[near].tx, g.tenants[near].ty}, [2]i16{20, 20})
	testing.expect(t, !g.tenants[far].awake)
	testing.expect(t, !g.tenants[friend].awake)
	said := false
	for i in 0 ..< LOG_LINES {
		if strings.has_prefix(message(&g.log[i]), "The hundred-eyed beast screams.") {
			said = true
		}
	}
	testing.expect(t, said)
	// Once awake it does not scream again.
	g.tenants[far].awake = false
	g.tenants[far].x, g.tenants[far].y = 30, 26
	tenant_act(g, p)
	testing.expect(t, !g.tenants[far].awake)
}
