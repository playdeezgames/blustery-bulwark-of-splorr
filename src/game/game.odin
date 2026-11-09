package game

// The rules, independent of the platform. Step 0 of slice 1 (PLAN.md): a placeholder room to prove
// the layout and every input path. Floors, wind, inventory and the rest arrive in later steps.

// Commands the page sends for keys, gamepad buttons and the touch d-pad (keep in step with
// web/index.html). Directions are the eight compass moves.
Command :: enum i32 {
	North,
	South,
	West,
	East,
	North_West,
	North_East,
	South_West,
	South_East,
	Wait,
	Confirm,
	Cancel,
}

DIRECTION := [Command][2]int {
	.North      = {0, -1},
	.South      = {0, 1},
	.West       = {-1, 0},
	.East       = {1, 0},
	.North_West = {-1, -1},
	.North_East = {1, -1},
	.South_West = {-1, 1},
	.South_East = {1, 1},
	.Wait       = {0, 0},
	.Confirm    = {0, 0},
	.Cancel     = {0, 0},
}

Cell :: enum u8 {
	Floor,
	Wall,
	Stairs_Up,
	Stairs_Down,
}

ROOM_W :: 40
ROOM_H :: 28

LOG_CAP :: 64 // characters per remembered message

Message :: struct {
	text: [LOG_CAP]u8,
	n:    int,
}

Game :: struct {
	cells: [ROOM_H][ROOM_W]Cell,
	x, y:  int,
	turn:  int,
	log:   [LOG_LINES]Message, // oldest first
}

init_game :: proc(g: ^Game) {
	g^ = {}
	// A walled room with a few pillars, so the view can be seen to scroll.
	for y in 0 ..< ROOM_H {
		for x in 0 ..< ROOM_W {
			edge := x == 0 || y == 0 || x == ROOM_W - 1 || y == ROOM_H - 1
			pillar := x % 6 == 3 && y % 5 == 2
			g.cells[y][x] = edge || pillar ? .Wall : .Floor
		}
	}
	g.cells[3][ROOM_W - 4] = .Stairs_Up
	g.cells[ROOM_H - 4][3] = .Stairs_Down
	g.x, g.y = ROOM_W / 2, ROOM_H / 2
	say(g, "The wind howls round the bulwark.")
	say(g, "(Step 0: a placeholder room.)")
}

// Adds a line to the message log, cut to the log's width.
say :: proc(g: ^Game, text: string) {
	for i in 0 ..< LOG_LINES - 1 {
		g.log[i] = g.log[i + 1]
	}
	m := &g.log[LOG_LINES - 1]
	m^ = {}
	m.n = min(len(text), LOG_CAP, (VIEW_W * TILE - LOG_X) / GLYPH_W)
	copy(m.text[:m.n], text[:m.n])
}

message :: proc(m: ^Message) -> string {
	return string(m.text[:m.n])
}

cell_at :: proc(g: ^Game, x, y: int) -> Cell {
	if x < 0 || y < 0 || x >= ROOM_W || y >= ROOM_H {
		return .Wall
	}
	return g.cells[y][x]
}

command :: proc(g: ^Game, c: Command) {
	switch c {
	case .North, .South, .West, .East, .North_West, .North_East, .South_West, .South_East:
		d := DIRECTION[c]
		if cell_at(g, g.x + d.x, g.y + d.y) == .Wall {
			say(g, "A wall.")
			return
		}
		g.x += d.x
		g.y += d.y
		g.turn += 1
		#partial switch cell_at(g, g.x, g.y) {
		case .Stairs_Up:
			say(g, "Stairs up. (Not yet.)")
		case .Stairs_Down:
			say(g, "Stairs down. (Not yet.)")
		}
	case .Wait:
		g.turn += 1
		say(g, "You wait. The wind does not.")
	case .Confirm:
		say(g, "Confirm.")
	case .Cancel:
		say(g, "Cancel.")
	}
}

// The map cell under a screen pixel, if the pixel is on the map view.
screen_to_cell :: proc(g: ^Game, sx, sy: int) -> (x, y: int, ok: bool) {
	if sx < MAP_X || sy < MAP_Y || sx >= MAP_X + VIEW_W * TILE || sy >= MAP_Y + VIEW_H * TILE {
		return 0, 0, false
	}
	ox, oy := view_origin(g)
	return ox + (sx - MAP_X) / TILE, oy + (sy - MAP_Y) / TILE, true
}

// Top-left map cell of the view, which keeps the player in the middle.
view_origin :: proc(g: ^Game) -> (x, y: int) {
	return g.x - VIEW_W / 2, g.y - VIEW_H / 2
}

// A click or tap at a screen pixel (button 0 primary, 2 secondary). Step 0 only reports it; walking
// by mouse and inspecting arrive with the map in step 1.
pointer :: proc(g: ^Game, sx, sy: int, button: int) {
	x, y, ok := screen_to_cell(g, sx, sy)
	if !ok {
		return
	}
	names := [Cell]string {
		.Floor       = "floor",
		.Wall        = "a wall",
		.Stairs_Up   = "stairs up",
		.Stairs_Down = "stairs down",
	}
	name := names[cell_at(g, x, y)]
	if x == g.x && y == g.y {
		name = "you"
	}
	buf: [LOG_CAP]u8
	n := 0
	prefix := button == 2 ? "Inspect: " : "Click: "
	for s in ([2]string{prefix, name}) {
		for i in 0 ..< len(s) {
			if n < LOG_CAP {
				buf[n] = s[i]
				n += 1
			}
		}
	}
	say(g, string(buf[:n]))
}
