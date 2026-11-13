#+build !js
package game

import "core:strings"
import "core:testing"

// An open cell with open cells all round it on the current floor, for the wind to push about in.
open_spot :: proc(g: ^Game) -> [2]int {
	f := floor_of(g)
	for y in 2 ..< FLOOR_H - 2 {
		for x in 2 ..< FLOOR_W - 2 {
			ok := true
			for dy in -2 ..= 2 {
				for dx in -2 ..= 2 {
					if f.cells[y + dy][x + dx] != .Floor {
						ok = false
					}
				}
			}
			if ok && ground_item_at(g, x, y) == 0 && ground_item_at(g, x + 1, y) == 0 {
				return {x, y}
			}
		}
	}
	return {}
}

@(test)
test_gust_comes_on_time_with_warning_and_pushes :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	testing.expect(t, spot != {})
	teleport(g, spot)
	f := floor_of(g)
	period := gust_period(f.number)
	testing.expect_value(t, g.gust_in, period)
	for _ in 0 ..< period - GUST_WARNING {
		command(g, .Wait)
	}
	testing.expect(t, gust_warning(g))
	testing.expect(t, strings.has_prefix(message(&g.log[LOG_LINES - 1]), "The wind picks up from the "))
	command(g, .Wait)
	testing.expect_value(t, [2]int{g.x, g.y}, spot) // still waiting for it
	command(g, .Wait)
	testing.expect_value(t, [2]int{g.x, g.y}, spot + wind_blow(f))
	testing.expect_value(t, g.gust_in, period) // the clock starts again
}

@(test)
test_gust_into_a_wall_does_not_move_you :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	d := wind_blow(f)
	// Find a floor cell whose downwind neighbour is a wall.
	for y in 1 ..< FLOOR_H - 1 {
		for x in 1 ..< FLOOR_W - 1 {
			if f.cells[y][x] == .Floor && f.cells[y + d.y][x + d.x] == .Wall {
				teleport(g, {x, y})
				g.gust_in = 1
				command(g, .Wait)
				testing.expect_value(t, [2]int{g.x, g.y}, [2]int{x, y})
				found := false
				for &m in g.log {
					if message(&m) == "A gust slams you into the wall." {
						found = true
					}
				}
				testing.expect(t, found)
				return
			}
		}
	}
	testing.expect(t, false, "no floor cell beside a downwind wall")
}

@(test)
test_torch_burns_out_and_a_spare_is_lit :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	g.gust_in = 1000
	spares := spare_torches(g)
	testing.expect_value(t, spares, 2) // the starting kit's two on the belt
	g.items[worn(g, .Light)].fuel = 2
	command(g, .Wait)
	testing.expect(t, g.lit)
	command(g, .Wait)
	testing.expect(t, !g.lit)
	testing.expect_value(t, worn(g, .Light), 0) // a burnt-out torch is gone
	testing.expect_value(t, sight_radius(g), DARK_SIGHT)
	// In the dark only the cells next to you are visible.
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if g.vis[y][x] {
				testing.expect(t, abs(x - g.x) <= DARK_SIGHT + 1 && abs(y - g.y) <= DARK_SIGHT + 1)
			}
		}
	}
	// Confirm (with nothing underfoot) takes a spare into the light slot and lights it: a turn.
	turn := g.turn
	command(g, .Confirm)
	testing.expect(t, g.lit)
	testing.expect_value(t, torch_fuel(g), TORCH_TURNS - 1)
	testing.expect_value(t, spare_torches(g), spares - 1)
	testing.expect_value(t, g.turn, turn + 1)
}

@(test)
test_gusts_snuff_torches_and_relighting_keeps_the_fuel :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	snuffed := 0
	for _ in 0 ..< 200 {
		g.x, g.y = spot.x, spot.y
		g.gust_in = 1
		fuel := torch_fuel(g)
		command(g, .Wait)
		if !g.lit {
			snuffed += 1
			testing.expect_value(t, torch_fuel(g), fuel - 1) // blown out, not used up
			g.x, g.y = spot.x, spot.y
			g.gust_in = 1000
			command(g, .Confirm)
			testing.expect(t, g.lit)
			testing.expect_value(t, spare_torches(g), 2)
		}
		g.items[worn(g, .Light)].fuel = TORCH_TURNS
	}
	// Floor 1 snuffs a quarter of the time; 200 gusts give plenty either way.
	testing.expect(t, snuffed > 20 && snuffed < 90)
}

@(test)
test_no_torches_left :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	teleport(g, open_spot(g))
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Torch {
			free_item(g, i)
		}
	}
	g.lit = false
	turn := g.turn
	command(g, .Confirm)
	testing.expect(t, !g.lit)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "You have no torch to light.")
	testing.expect_value(t, g.turn, turn)
}

@(test)
test_each_floor_has_its_own_wind_and_higher_floors_gust_more :: proc(t: ^testing.T) {
	differs := false
	for seed in u64(1) ..= 20 {
		a, b := new(Floor), new(Floor)
		generate_floor(a, floor_seed(seed, 1), 1)
		generate_floor(b, floor_seed(seed, 2), 2)
		if a.wind_from != b.wind_from {
			differs = true
		}
		free(a)
		free(b)
	}
	testing.expect(t, differs)
	// Windier going up, among the generated floors (1 to 3, then 5 to 7) and among the boss
	// floors (4, 8); a boss hall is windier than the floor above it (decided November 13, 2026).
	for pair in ([?][2]int{{1, 2}, {2, 3}, {3, 5}, {5, 6}, {6, 7}, {4, 8}}) {
		testing.expect(t, gust_period(pair[1]) <= gust_period(pair[0]))
		testing.expect(t, snuff_chance(pair[1]) >= snuff_chance(pair[0]))
	}
	testing.expect_value(t, gust_push(4), 1)
	testing.expect_value(t, gust_push(5), 2)
}

@(test)
test_streaks_drawn_only_while_warning :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	fr := new(Frame)
	defer free(fr)
	g.gust_in = GUST_WARNING + 1
	draw_game(fr, g)
	before := fr.px
	g.gust_in = 1
	draw_game(fr, g)
	changed := 0
	for p, i in fr.px {
		if p != before[i] && p == COLOR_WHITE {
			changed += 1
		}
	}
	testing.expect(t, changed > 20)
}

@(test)
test_gusts_push_two_cells_from_floor_five :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, BOSS_INDEX + 1, .Stairs_Down)
	f := floor_of(g)
	d := wind_blow(f)
	// Find a cell with two open cells downwind of it, and a wall-free cell to start from.
	found := false
	for y in 2 ..< f.h - 2 {
		for x in 2 ..< f.w - 2 {
			if f.cells[y][x] == .Floor && f.cells[y + d.y][x + d.x] == .Floor && f.cells[y + 2 * d.y][x + 2 * d.x] == .Floor {
				teleport(g, {x, y})
				found = true
				break
			}
		}
		if found {
			break
		}
	}
	testing.expect(t, found)
	start := [2]int{g.x, g.y}
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, start + 2 * d)
}

@(test)
test_a_gust_slams_you_into_a_tenant_not_onto_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	d := wind_blow(f)
	for y in 2 ..< f.h - 2 {
		for x in 2 ..< f.w - 2 {
			if f.cells[y][x] == .Floor && f.cells[y + d.y][x + d.x] == .Floor && g.x == f.down.x && g.y == f.down.y {
				teleport(g, {x, y})
			}
		}
	}
	id := new_tenant(g, .Beetle, g.current, g.x + d.x, g.y + d.y)
	testing.expect(t, id != 0)
	start := [2]int{g.x, g.y}
	hp := g.health
	gust(g)
	testing.expect_value(t, [2]int{g.x, g.y}, start)
	testing.expect_value(t, g.health, hp - 1)
}
