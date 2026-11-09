package game

// Draws the play screen: map view, message log and side panel.

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_BLACK)
	draw_map(f, g)
	draw_log(f, g)
	draw_panel(f, g)
}

draw_map :: proc(f: ^Frame, g: ^Game) {
	ox, oy := view_origin(g)
	for vy in 0 ..< VIEW_H {
		for vx in 0 ..< VIEW_W {
			x, y := ox + vx, oy + vy
			sx, sy := MAP_X + vx * TILE, MAP_Y + vy * TILE
			if x < 0 || y < 0 || x >= ROOM_W || y >= ROOM_H {
				continue
			}
			switch g.cells[y][x] {
			case .Floor:
				draw_gfx(f, .Floor, sx, sy, COLOR_DARK)
			case .Wall:
				draw_gfx(f, .Wall, sx, sy, COLOR_LIGHT)
			case .Stairs_Up:
				draw_gfx(f, .Stairs_Up, sx, sy, COLOR_CYAN)
			case .Stairs_Down:
				draw_gfx(f, .Stairs_Down, sx, sy, COLOR_MID)
			}
		}
	}
	px, py := MAP_X + (g.x - ox) * TILE, MAP_Y + (g.y - oy) * TILE
	fill_rect(f, px, py, TILE, TILE, COLOR_BLACK)
	draw_gfx(f, .Player, px, py, COLOR_WHITE)
}

draw_log :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, 0, VIEW_H * TILE, VIEW_W * TILE, SCREEN_H - VIEW_H * TILE, COLOR_BLACK)
	fill_rect(f, 0, VIEW_H * TILE, VIEW_W * TILE, 1, COLOR_DARK)
	for i in 0 ..< LOG_LINES {
		color: u8 = i == LOG_LINES - 1 ? COLOR_WHITE : COLOR_MID
		print(f, message(&g.log[i]), LOG_X, LOG_Y + i * GLYPH_H, color)
	}
}

draw_panel :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, PANEL_X - 2, 0, 1, SCREEN_H, COLOR_DARK)
	x := PANEL_X + 2
	print(f, "Blustery Bulwark", x, 4, COLOR_CYAN)
	print(f, "of SPLORR!!", x, 13, COLOR_CYAN)
	draw_gfx(f, .Torch, x, 26, COLOR_ORANGE)
	print(f, "The town gate", x + 16, 28, COLOR_LIGHT)
	rows := [?]string{"Health  --", "Mana    --", "Food    --", "Light   --", "Wind    --", "Load    --", "Jools   --"}
	for r, i in rows {
		print(f, r, x, 46 + i * 10, COLOR_MID)
	}
	print(f, "Slice 1, step 0", x, SCREEN_H - 12, COLOR_DARK)
}
