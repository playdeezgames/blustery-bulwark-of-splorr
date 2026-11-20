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
