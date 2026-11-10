package game

// Draws the play screen: map view (or the automap), message log and side panel.

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_BLACK)
	switch g.mode {
	case .Automap:
		draw_automap(f, g)
	case .Inventory:
		draw_inventory(f, g)
	case .Play:
		draw_map(f, g)
	case .Create:
		draw_create(f, g)
	case .Dead:
		draw_map(f, g)
		draw_dead(f, g)
	case .Learn:
		draw_learn(f, g)
	case .Cast:
		draw_cast(f, g)
	case .Aim:
		draw_map(f, g)
	}
	draw_log(f, g)
	draw_panel(f, g)
}

// Colours of a cell kind: in sight, and remembered. Remembered floor is left dark.
cell_look :: proc(c: Cell) -> (g: Gfx, lit, remembered: u8) {
	switch c {
	case .Wall:
		return .Wall, COLOR_LIGHT, COLOR_DARK
	case .Floor:
		return .Floor, COLOR_DARK, COLOR_BLACK
	case .Stairs_Up:
		return .Stairs_Up, COLOR_CYAN, COLOR_MID
	case .Stairs_Down:
		return .Stairs_Down, COLOR_YELLOW, COLOR_MID
	}
	return .Floor, COLOR_DARK, COLOR_BLACK
}

draw_map :: proc(f: ^Frame, g: ^Game) {
	fl := floor_of(g)
	ox, oy := view_origin(g)
	for vy in 0 ..< VIEW_H {
		for vx in 0 ..< VIEW_W {
			x, y := ox + vx, oy + vy
			if x < 0 || y < 0 || x >= FLOOR_W || y >= FLOOR_H || !fl.seen[y][x] {
				continue
			}
			gfx, lit, remembered := cell_look(fl.cells[y][x])
			color := g.vis[y][x] ? lit : remembered
			if color != COLOR_BLACK {
				draw_gfx(f, gfx, MAP_X + vx * TILE, MAP_Y + vy * TILE, color)
			}
		}
	}
	// Things on the ground, where they can be seen now (the topmost of a pile).
	for vy in 0 ..< VIEW_H {
		for vx in 0 ..< VIEW_W {
			x, y := ox + vx, oy + vy
			if x < 0 || y < 0 || x >= FLOOR_W || y >= FLOOR_H || !g.vis[y][x] {
				continue
			}
			if id := ground_item_at(g, x, y); id != 0 {
				k := KIND[g.items[id].kind]
				sx, sy := MAP_X + vx * TILE, MAP_Y + vy * TILE
				fill_rect(f, sx, sy, TILE, TILE, COLOR_BLACK)
				draw_gfx(f, k.gfx, sx, sy, item_color(g, id))
			}
		}
	}
	draw_tenants(f, g)
	// A mouse route still to walk, as dots.
	for i in g.path_i ..< g.path_len {
		p := g.path[i]
		sx, sy := MAP_X + (p.x - ox) * TILE, MAP_Y + (p.y - oy) * TILE
		if sx >= MAP_X && sy >= MAP_Y && sx < MAP_X + VIEW_W * TILE && sy < MAP_Y + VIEW_H * TILE {
			fill_rect(f, sx + 5, sy + 5, 2, 2, COLOR_YELLOW)
		}
	}
	px, py := MAP_X + (g.x - ox) * TILE, MAP_Y + (g.y - oy) * TILE
	fill_rect(f, px, py, TILE, TILE, COLOR_BLACK)
	draw_gfx(f, .Player, px, py, COLOR_WHITE)
	draw_magic(f, g)
	if gust_warning(g) {
		draw_streaks(f, g)
	}
}

// Wind streaks across the map view while a gust is coming: short lines along the wind, in new
// places every turn, brighter on the last turn of warning.
STREAKS :: 16

draw_streaks :: proc(f: ^Frame, g: ^Game) {
	d := wind_blow(floor_of(g))
	color: u8 = g.gust_in == 1 ? COLOR_WHITE : COLOR_MID
	r := Rng{u64(g.turn) * 0x9E3779B97F4A7C15 ~ g.seed}
	for _ in 0 ..< STREAKS {
		x := rng_int(&r, VIEW_W * TILE)
		y := rng_int(&r, VIEW_H * TILE)
		length := rng_range(&r, 5, 11)
		for i in 0 ..< length {
			sx, sy := MAP_X + x + d.x * i, MAP_Y + y + d.y * i
			if sx >= MAP_X && sy >= MAP_Y && sx < MAP_X + VIEW_W * TILE && sy < MAP_Y + VIEW_H * TILE {
				set_px(f, sx, sy, color)
			}
		}
	}
}

AUTOMAP_CELL :: 4
AUTOMAP_X :: MAP_X + (VIEW_W * TILE - FLOOR_W * AUTOMAP_CELL) / 2
AUTOMAP_Y :: MAP_Y + 12

draw_automap :: proc(f: ^Frame, g: ^Game) {
	fl := floor_of(g)
	buf: [8]u8
	x := print(f, "Floor ", AUTOMAP_X, 2, COLOR_CYAN)
	x += print(f, itoa(buf[:], fl.number), AUTOMAP_X + x, 2, COLOR_CYAN)
	print(f, " - any key or click to close", AUTOMAP_X + x, 2, COLOR_MID)
	for y in 0 ..< FLOOR_H {
		for xx in 0 ..< FLOOR_W {
			if !fl.seen[y][xx] {
				continue
			}
			color: u8
			switch fl.cells[y][xx] {
			case .Wall:
				color = COLOR_MID
			case .Floor:
				color = COLOR_DARK
			case .Stairs_Up:
				color = COLOR_CYAN
			case .Stairs_Down:
				color = COLOR_YELLOW
			}
			fill_rect(f, AUTOMAP_X + xx * AUTOMAP_CELL, AUTOMAP_Y + y * AUTOMAP_CELL, AUTOMAP_CELL, AUTOMAP_CELL, color)
		}
	}
	fill_rect(f, AUTOMAP_X + g.x * AUTOMAP_CELL, AUTOMAP_Y + g.y * AUTOMAP_CELL, AUTOMAP_CELL, AUTOMAP_CELL, COLOR_WHITE)
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
	buf: [12]u8
	print(f, "Blustery Bulwark", x, 4, COLOR_CYAN)
	print(f, "of SPLORR!!", x, 13, COLOR_CYAN)
	draw_gfx(f, .Torch, x, 26, COLOR_ORANGE)
	w := print(f, "Floor ", x + 16, 28, COLOR_LIGHT)
	print(f, itoa(buf[:], floor_of(g).number), x + 16 + w, 28, COLOR_LIGHT)
	y := 46
	hp, top := g.health, max_health(g)
	w = print(f, "Health  ", x, y, COLOR_MID)
	w += print(f, itoa(buf[:], hp), x + w, y, hp * 3 <= top ? COLOR_RED : hp * 3 <= top * 2 ? COLOR_ORANGE : COLOR_WHITE)
	w += print(f, "/", x + w, y, COLOR_DARK)
	print(f, itoa(buf[:], top), x + w, y, COLOR_DARK)
	y += 10
	w = print(f, "Mana    ", x, y, COLOR_MID)
	w += print(f, itoa(buf[:], g.mana), x + w, y, COLOR_CYAN)
	w += print(f, "/", x + w, y, COLOR_DARK)
	print(f, itoa(buf[:], max_mana(g)), x + w, y, COLOR_DARK)
	y += 10
	word, wc := hunger_word(g)
	w = print(f, "Food    ", x, y, COLOR_MID)
	print(f, word, x + w, y, wc)
	y += 10
	// Light: turns left in the torch in hand, and spare torches carried.
	w = print(f, "Light   ", x, y, COLOR_MID)
	fuel, spares := torch_fuel(g), spare_torches(g)
	if g.lit {
		w += print(f, itoa(buf[:], fuel), x + w, y, fuel <= 30 ? COLOR_ORANGE : COLOR_YELLOW)
	} else {
		w += print(f, fuel > 0 || spares > 0 ? "out" : "none", x + w, y, COLOR_RED)
	}
	w += print(f, " +", x + w, y, COLOR_DARK)
	print(f, itoa(buf[:], spares), x + w, y, COLOR_DARK)
	y += 10
	// Wind: where it comes from, and turns to the next gust (bright while it warns).
	fl := floor_of(g)
	w = print(f, "Wind    ", x, y, COLOR_MID)
	w += print(f, COMPASS[fl.wind_from], x + w, y, COLOR_LIGHT)
	w += print(f, " gust ", x + w, y, COLOR_DARK)
	print(f, itoa(buf[:], g.gust_in), x + w, y, gust_warning(g) ? COLOR_WHITE : COLOR_DARK)
	y += 10
	// Load: kilograms carried and the limit; orange when it anchors (and slows) you, red when too much.
	kb1, kb2: [16]u8
	load := carried_weight(g)
	w = print(f, "Load    ", x, y, COLOR_MID)
	w += print(f, kg(kb1[:], load), x + w, y, overloaded(g) ? COLOR_RED : load_anchors(g) ? COLOR_ORANGE : COLOR_LIGHT)
	print(f, "/" , x + w, y, COLOR_DARK)
	print(f, kg(kb2[:], carry_limit(g)), x + w + GLYPH_W, y, COLOR_DARK)
	y += 10
	w = print(f, "Jools   ", x, y, COLOR_MID)
	print(f, itoa(buf[:], carried_jools(g)), x + w, y, COLOR_YELLOW)
	y += 10
	// Level, and XP toward the next.
	w = print(f, "Level   ", x, y, COLOR_MID)
	w += print(f, itoa(buf[:], g.level), x + w, y, COLOR_LIGHT)
	w += print(f, " xp ", x + w, y, COLOR_DARK)
	w += print(f, itoa(buf[:], g.xp), x + w, y, COLOR_LIGHT)
	w += print(f, "/", x + w, y, COLOR_DARK)
	print(f, itoa(buf[:], xp_for_level(g.level + 1)), x + w, y, COLOR_DARK)
	y += 10
	w = print(f, "Turn    ", x, y, COLOR_MID)
	print(f, itoa(buf[:], g.turn), x + w, y, COLOR_MID)
	y += 12
	// The four attributes, short.
	short := [Attr]string{.Strength = "St", .Dexterity = "Dx", .Intelligence = "In", .Constitution = "Co"}
	ax := x
	for a in Attr {
		ax += print(f, short[a], ax, y, COLOR_DARK)
		ax += print(f, itoa(buf[:], g.attr[a]), ax, y, COLOR_LIGHT) + 4
	}
	// Spells still running, a line each.
	if g.ward_turns > 0 {
		y += 9
		w = print(f, "Ward    ", x, y, COLOR_CYAN)
		print(f, itoa(buf[:], g.ward_turns), x + w, y, COLOR_CYAN)
	}
	if g.sense_turns > 0 {
		y += 9
		w = print(f, "Sense   ", x, y, COLOR_CYAN)
		print(f, itoa(buf[:], g.sense_turns), x + w, y, COLOR_CYAN)
	}
	if g.anchor_spell {
		y += 9
		print(f, "Anchor  till gust", x, y, COLOR_CYAN)
	}
	if g.mode == .Inventory {
		hints := [?]string{"Enter: take/put", "Right: open", "Left: back", "Esc/I: close"}
		for h, i in hints {
			print(f, h, x, SCREEN_H - 52 + i * 9, COLOR_DARK)
		}
	} else {
		for h in PANEL_HINTS {
			print(f, h.text, PANEL_X + 2 + h.x, PANEL_HINT_Y, COLOR_MID)
		}
	}
	print(f, "Slice 1, step 6", x, SCREEN_H - 12, COLOR_DARK)
}

// The panel's key hints, which a click or tap also uses.
Panel_Hint :: struct {
	text: string,
	x:    int,
	c:    Command,
}

PANEL_HINT_Y :: SCREEN_H - 30
PANEL_HINTS := [?]Panel_Hint{{"M map", 0, .Map}, {"I pack", 6 * GLYPH_W, .Inventory}, {"C cast", 13 * GLYPH_W, .Cast}}

panel_hint_at :: proc(sx, sy: int) -> (Command, bool) {
	if sy < PANEL_HINT_Y - 3 || sy >= PANEL_HINT_Y + GLYPH_H + 3 {
		return .Wait, false
	}
	for h in PANEL_HINTS {
		x := PANEL_X + 2 + h.x
		if sx >= x - 2 && sx < x + text_width(h.text) + 2 {
			return h.c, true
		}
	}
	return .Wait, false
}
