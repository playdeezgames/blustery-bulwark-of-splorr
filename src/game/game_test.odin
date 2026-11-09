#+build !js
package game

import "core:testing"

@(test)
test_start_in_the_middle :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	testing.expect_value(t, g.x, ROOM_W / 2)
	testing.expect_value(t, g.y, ROOM_H / 2)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Floor)
}

@(test)
test_moves_in_eight_directions :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	x, y := g.x, g.y
	command(g, .North_East)
	testing.expect_value(t, g.x, x + 1)
	testing.expect_value(t, g.y, y - 1)
	command(g, .South_West)
	testing.expect_value(t, g.x, x)
	testing.expect_value(t, g.y, y)
	testing.expect_value(t, g.turn, 2)
}

@(test)
test_walls_block :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	g.x, g.y = 1, 1
	command(g, .North)
	command(g, .West)
	command(g, .North_West)
	testing.expect_value(t, g.x, 1)
	testing.expect_value(t, g.y, 1)
	testing.expect_value(t, g.turn, 0)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "A wall.")
}

@(test)
test_log_keeps_the_newest :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	for _ in 0 ..< LOG_LINES + 2 {
		command(g, .Wait)
	}
	say(g, "last")
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "last")
	long := "0123456789012345678901234567890123456789012345678901234567890123456789"
	say(g, long)
	testing.expect(t, message(&g.log[LOG_LINES - 1]) == long[:(VIEW_W * TILE - LOG_X) / GLYPH_W])
}

@(test)
test_pointer_maps_to_cells :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	// The player is drawn in the middle cell of the view.
	x, y, ok := screen_to_cell(g, MAP_X + (VIEW_W / 2) * TILE + 5, MAP_Y + (VIEW_H / 2) * TILE + 5)
	testing.expect(t, ok)
	testing.expect_value(t, x, g.x)
	testing.expect_value(t, y, g.y)
	_, _, ok = screen_to_cell(g, PANEL_X + 10, 10)
	testing.expect(t, !ok)
	pointer(g, MAP_X + (VIEW_W / 2) * TILE + 5, MAP_Y + (VIEW_H / 2) * TILE + 5, 2)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "Inspect: you")
}

@(test)
test_frame_draws_player_in_the_middle :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	f := new(Frame)
	defer free(f)
	init_game(g)
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
	resolve(f)
	testing.expect_value(t, f.rgba[0] >> 24, 0xFF)
}
