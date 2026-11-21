package game

// Floor 16, the top (slice 4 step 29; DESIGN.md beats 5 and 6). An open roof with a few chimneys, the
// windiest floor in the game: a gust every 4 turns, pushing 3, and after each gust the wind backs a
// quarter round, so no chimney stays a safe one for long. Six guards the herald hired are the only
// tenants. At the far end, in a chair with a cup of tea, sits His Lordship: a very old man who never
// says a word and cannot be harmed.

LORD_INDEX :: 15 // floors[15] is floor 16, the top
LORD_X :: 9
LORD_Y :: 13

LORD_MAP := [?]string {
	"##############################################",
	"#............................................#",
	"#............................................#",
	"#...............g...........##...............#",
	"#.........##................##...............#",
	"#.........##....................g............#",
	"#............................................#",
	"#...................##..............##.......#",
	"#..D................##..g...........##.g..L..#",
	"#............................................#",
	"#............................................#",
	"#.........##.....................g...........#",
	"#.........##................##...............#",
	"#...............g...........##...............#",
	"#............................................#",
	"#............................................#",
	"##############################################",
}

// Builds the roof by hand, with the six hired guards and His Lordship.
build_lord_floor :: proc(g: ^Game) {
	f := &g.floors[LORD_INDEX]
	f^ = {}
	f.number = LORD_INDEX + 1
	f.made = true
	f.w, f.h = floor_size(f.number)
	f.wind_from = 2 // from the west, to begin with
	lord_cells(f)
	if g.no_tenants {
		return
	}
	for row, y in LORD_MAP {
		for x in 0 ..< len(row) {
			cx, cy := LORD_X + x, LORD_Y + y
			switch row[x] {
			case 'g':
				new_tenant(g, .Guard, LORD_INDEX, cx, cy)
			case 'L':
				if id := new_tenant(g, .Lord, LORD_INDEX, cx, cy); id != 0 {
					g.tenants[id].still = true
				}
			}
		}
	}
}

// The roof's cells and stairs down from LORD_MAP (also used to restore a save). There is no way up.
lord_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in LORD_MAP {
		for x in 0 ..< len(row) {
			cx, cy := LORD_X + x, LORD_Y + y
			c: Cell = .Floor
			switch row[x] {
			case '#':
				c = .Wall
			case 'D':
				c = .Stairs_Down
				f.down = {cx, cy}
				f.up = {cx, cy} // nothing above; kept on the stairs so nothing looks for a way up
			}
			f.cells[cy][cx] = c
		}
	}
}

// After every gust on the roof the wind backs a quarter round: from the west to the south, then the
// east, then the north, then the west again.
wind_backs :: proc(f: ^Floor) {
	switch f.wind_from {
	case 0:
		f.wind_from = 2 // N to W
	case 2:
		f.wind_from = 1 // W to S
	case 1:
		f.wind_from = 3 // S to E
	case:
		f.wind_from = 0 // E (or anything else) to N
	}
}

// Bumping His Lordship: he nods. The first time, the notice.
meet_lord :: proc(g: ^Game) {
	say(g, "He looks up, nods, and goes back to his tea.")
	if !g.lord_met {
		g.lord_met = true
		g.notice = .Lord
		g.mode = .Notice
		stop_travel(g)
	}
}

draw_lord_notice :: proc(f: ^Frame) {
	fill_rect(f, 14, NOTICE_Y - 8, VIEW_W * TILE - 28, 50, COLOR_BLACK)
	fill_rect(f, 14, NOTICE_Y - 8, VIEW_W * TILE - 28, 1, COLOR_YELLOW)
	fill_rect(f, 14, NOTICE_Y + 41, VIEW_W * TILE - 28, 1, COLOR_YELLOW)
	print(f, "His Lordship.", 24, NOTICE_Y, COLOR_YELLOW)
	print(f, "He has never said a word.", 24, NOTICE_Y + 14, COLOR_LIGHT)
	print(f, "Enter/OK or click to go on.", 24, NOTICE_Y + 28, COLOR_YELLOW)
}
