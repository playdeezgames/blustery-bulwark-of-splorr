#+build !js
package game

import "core:testing"

new_game :: proc(seed: u64 = 12345) -> ^Game {
	g := new(Game)
	init_game(g, seed)
	// Most tests check one rule alone: past creation, with no tenants about. tenants_test.odin
	// brings them back.
	g.mode = .Play
	g.tenants = {}
	g.no_tenants = true
	enter_floor(g, 0, .Stairs_Down) // a new character starts in town; most tests start on floor 1
	return g
}

@(test)
test_start_on_floor_one_stairs_down :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	testing.expect_value(t, floor_of(g).number, 1)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
	testing.expect(t, g.vis[g.y][g.x])
}

@(test)
test_floors_are_connected_over_many_seeds :: proc(t: ^testing.T) {
	f := new(Floor)
	defer free(f)
	path: ^[MAX_PATH][2]int = new([MAX_PATH][2]int)
	defer free(path)
	for seed in u64(1) ..= 300 {
		for number in 1 ..= GENERATED_FLOORS {
			generate_floor(f, floor_seed(seed, number), number)
			testing.expect(t, f.room_count >= 6)
			testing.expect_value(t, f.cells[f.up.y][f.up.x], Cell.Stairs_Up)
			testing.expect_value(t, f.cells[f.down.y][f.down.x], Cell.Stairs_Down)
			// Pretend everything is seen, then ask for a route between the stairs.
			for y in 0 ..< FLOOR_H {
				for x in 0 ..< FLOOR_W {
					f.seen[y][x] = true
				}
			}
			testing.expectf(t, reachable(f, f.down, f.up), "seed %v floor %v: stairs not connected", seed, number)
			// The border is always wall.
			for x in 0 ..< FLOOR_W {
				testing.expect_value(t, f.cells[0][x], Cell.Wall)
				testing.expect_value(t, f.cells[FLOOR_H - 1][x], Cell.Wall)
			}
			for y in 0 ..< FLOOR_H {
				testing.expect_value(t, f.cells[y][0], Cell.Wall)
				testing.expect_value(t, f.cells[y][FLOOR_W - 1], Cell.Wall)
			}
		}
	}
}

// Flood fill without the route-length limit of find_path.
reachable :: proc(f: ^Floor, from, to: [2]int) -> bool {
	done := new([FLOOR_H][FLOOR_W]bool)
	defer free(done)
	stack := make([dynamic][2]int, 0, 64)
	defer delete(stack)
	append(&stack, from)
	done[from.y][from.x] = true
	for len(stack) > 0 {
		c := pop(&stack)
		if c == to {
			return true
		}
		for d in DIRECTIONS {
			n := c + d
			if n.x >= 0 && n.y >= 0 && n.x < FLOOR_W && n.y < FLOOR_H && !done[n.y][n.x] && passable(f.cells[n.y][n.x]) {
				done[n.y][n.x] = true
				append(&stack, n)
			}
		}
	}
	return false
}

@(test)
test_same_seed_same_floor :: proc(t: ^testing.T) {
	a, b := new(Floor), new(Floor)
	defer free(a)
	defer free(b)
	generate_floor(a, floor_seed(99, 2), 2)
	generate_floor(b, floor_seed(99, 2), 2)
	testing.expect(t, a.cells == b.cells)
	generate_floor(b, floor_seed(99, 3), 3)
	testing.expect(t, a.cells != b.cells)
}

@(test)
test_walls_block_and_cost_no_turn :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	// Find a wall next to the player's room and walk into it.
	for d, i in DIRECTIONS {
		if cell_at(g, g.x + d.x, g.y + d.y) == .Wall {
			x, y := g.x, g.y
			command(g, Command(i))
			testing.expect_value(t, g.x, x)
			testing.expect_value(t, g.y, y)
			testing.expect_value(t, g.turn, 0)
			testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "A wall.")
			return
		}
	}
}

// Walks the player to (x, y) on the current floor by the stairs route, as a test helper.
teleport :: proc(g: ^Game, at: [2]int) {
	g.x, g.y = at.x, at.y
	refresh_view(g)
}

@(test)
test_stairs_climb_and_floors_persist :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f1 := floor_of(g)
	teleport(g, f1.up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 2)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
	// Mark something seen on floor 2, go down and back up: it is still remembered.
	floor_of(g).seen[0][0] = true
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 1)
	testing.expect_value(t, [2]int{g.x, g.y}, f1.up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 2)
	testing.expect(t, floor_of(g).seen[0][0])
	// Up to floor 4, where the door to floor 5 is locked.
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 4)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 4)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), " has the key, they say.") // the line wraps
}

@(test)
test_down_from_floor_one_is_the_town :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	command(g, .Confirm)
	testing.expect(t, in_town(g))
	testing.expect_value(t, [2]int{g.x, g.y}, g.town.up + {0, 1})
	// The gate goes back up to floor 1's stairs down.
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect_value(t, g.current, 0)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
}

@(test)
test_fov_stops_at_walls :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if g.vis[y][x] {
				testing.expect(t, f.seen[y][x])
				testing.expect(t, abs(x - g.x) <= SIGHT + 1 && abs(y - g.y) <= SIGHT + 1) // walls beside sight count
			}
		}
	}
	// A cell of the far stairs room is not visible from the start.
	testing.expect(t, !g.vis[f.up.y][f.up.x])
}

@(test)
test_mouse_route_walks_over_seen_cells :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	// Pick the farthest visible floor cell and click it.
	target := [2]int{g.x, g.y}
	best := 0
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			d := abs(x - g.x) + abs(y - g.y)
			if g.vis[y][x] && passable(f.cells[y][x]) && d > best && abs(x - g.x) <= VIEW_W / 2 && abs(y - g.y) <= VIEW_H / 2 {
				target, best = {x, y}, d
			}
		}
	}
	testing.expect(t, best >= 2)
	g.gust_in = 1000 // no gust may push the walker off the route in this test
	ox, oy := view_origin(g)
	pointer(g, MAP_X + (target.x - ox) * TILE + 6, MAP_Y + (target.y - oy) * TILE + 6, .Mouse_Primary)
	testing.expect(t, g.path_len > 0)
	for _ in 0 ..< 2000 {
		if !(g.path_i < g.path_len) {
			break
		}
		tick(g)
	}
	testing.expect_value(t, [2]int{g.x, g.y}, target)
	// A key press stops a route.
	pointer(g, MAP_X + 6, MAP_Y + 6, .Mouse_Primary) // top-left cell: unseen or far, either way no crash
	command(g, .Wait)
	testing.expect_value(t, g.path_len, 0)
}

@(test)
test_unseen_cells_cannot_be_inspected :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	inspect(g, f.up.x, f.up.y)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "You have not seen that.")
	inspect(g, g.x, g.y)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "You. Windswept.")
}

@(test)
test_automap_opens_and_any_input_closes :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	command(g, .Map)
	testing.expect_value(t, g.mode, Mode.Automap)
	x := g.x
	command(g, .East)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.x, x) // the closing key does not also move
	command(g, .Map)
	pointer(g, 10, 10, .Touch)
	testing.expect_value(t, g.mode, Mode.Play)
}

@(test)
test_log_and_itoa :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	buf: [8]u8
	testing.expect_value(t, itoa(buf[:], 0), "0")
	testing.expect_value(t, itoa(buf[:], 407), "407")
	testing.expect_value(t, itoa(buf[:], -12), "-12")
	long := "0123456789012345678901234567890123456789012345678901234567890123456789"
	say(g, long)
	testing.expect(t, message(&g.log[LOG_LINES - 2]) == long[:LOG_WIDTH])
	testing.expect(t, message(&g.log[LOG_LINES - 1])[1:] == long[LOG_WIDTH:])
	// Words wrap at spaces, and every line fits.
	say(g, "The gust blows out yer torch. Confirm to relight.")
	testing.expect_value(t, message(&g.log[LOG_LINES - 2]), "The gust blows out yer torch. Confirm to")
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), " relight.")
	for &m in g.log {
		testing.expect(t, m.n <= LOG_WIDTH)
	}
}

@(test)
test_frames_draw :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := new(Frame)
	defer free(f)
	draw_game(f, g)
	lit := 0
	cx, cy := MAP_X + (VIEW_W / 2) * TILE, MAP_Y + (VIEW_H / 2) * TILE
	for yy in 0 ..< TILE {
		for xx in 0 ..< TILE {
			if get_px(f, cx + xx, cy + yy) == COLOR_WHITE {
				lit += 1
			}
		}
	}
	testing.expect(t, lit > 10)
	command(g, .Map)
	draw_game(f, g)
	testing.expect_value(t, get_px(f, AUTOMAP_X + g.x * AUTOMAP_CELL + 1, AUTOMAP_Y + g.y * AUTOMAP_CELL + 1), COLOR_WHITE)
}

@(test)
test_a_repeated_line_shows_once_with_a_count :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	say(g, "Before.")
	for _ in 0 ..< 4 {
		say(g, "A wall.")
	}
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "A wall. (x4)")
	testing.expect_value(t, message(&g.log[LOG_LINES - 2]), "Before.")
	say(g, "Something else.")
	say(g, "A wall.")
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "A wall.")
	// A message that wraps onto two lines is not folded.
	long := "The wind picks up from the north and carries on for quite a while."
	say(g, long)
	say(g, long)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), message(&g.log[LOG_LINES - 3])) // both copies, in full
	testing.expect_value(t, message(&g.log[LOG_LINES - 2]), message(&g.log[LOG_LINES - 4]))
}
