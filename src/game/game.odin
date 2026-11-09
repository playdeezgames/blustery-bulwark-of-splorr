package game

// The rules, independent of the platform. Slice 1 step 1 (PLAN.md): three generated floors that
// persist for the character, stairs, fog of war, an automap, and walking by keys, gamepad, touch
// d-pad and mouse. Wind, light, inventory and the rest arrive in later steps.

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
	Map,
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
	.Map        = {0, 0},
}

FLOOR_COUNT :: 3 // generated floors in slice 1; floor 4 (the first boss) is hand-built in step 8

Mode :: enum u8 {
	Play,
	Automap,
}

LOG_CAP :: 64 // characters per remembered message

Message :: struct {
	text: [LOG_CAP]u8,
	n:    int,
}

TRAVEL_FRAMES :: 4 // frames between steps when walking a mouse route

Game :: struct {
	seed:        u64,
	floors:      [FLOOR_COUNT]Floor,
	current:     int, // index into floors (floor number - 1)
	x, y:        int,
	turn:        int,
	mode:        Mode,
	vis:         Visible,
	log:         [LOG_LINES]Message, // oldest first
	path:        [MAX_PATH][2]int,
	path_len:    int,
	path_i:      int,
	travel_wait: int,
	rng:         Rng, // gusts and other chances during play (floors use their own seeds)
	gust_in:     int, // turns until the next gust
	lit:         bool,
	torch:       int, // turns left in the torch in hand
	spare_torches: int,
}

floor_of :: proc(g: ^Game) -> ^Floor {
	return &g.floors[g.current]
}

init_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.seed = seed
	g.rng = Rng{seed ~ 0x5EED_B1A5_7E2F_0001}
	g.lit, g.torch, g.spare_torches = true, TORCH_TURNS, START_SPARE_TORCHES
	enter_floor(g, 0, .Stairs_Down)
	say(g, "The wind howls round the bulwark.")
	say(g, "You climb in from the town gate.")
}

// Moves to floor index `i`, standing on its stairs of kind `arrive`. A floor is generated the first
// time it is entered and kept after that.
enter_floor :: proc(g: ^Game, i: int, arrive: Cell) {
	g.current = i
	f := floor_of(g)
	if !f.made {
		generate_floor(f, floor_seed(g.seed, i + 1), i + 1)
	}
	at := arrive == .Stairs_Up ? f.up : f.down
	g.x, g.y = at.x, at.y
	g.gust_in = gust_period(f.number)
	stop_travel(g)
	refresh_view(g)
}

// Adds a line to the message log, cut to the log's width.
say :: proc(g: ^Game, parts: ..string) {
	for i in 0 ..< LOG_LINES - 1 {
		g.log[i] = g.log[i + 1]
	}
	m := &g.log[LOG_LINES - 1]
	m^ = {}
	width := min(LOG_CAP, (VIEW_W * TILE - LOG_X) / GLYPH_W)
	for s in parts {
		for i in 0 ..< len(s) {
			if m.n < width {
				m.text[m.n] = s[i]
				m.n += 1
			}
		}
	}
}

message :: proc(m: ^Message) -> string {
	return string(m.text[:m.n])
}

// Decimal text of a whole number, in a caller's buffer.
itoa :: proc(buf: []u8, v: int) -> string {
	n := v < 0 ? -v : v
	i := len(buf)
	for {
		i -= 1
		buf[i] = u8('0' + n % 10)
		n /= 10
		if n == 0 || i == 0 {
			break
		}
	}
	if v < 0 && i > 0 {
		i -= 1
		buf[i] = '-'
	}
	return string(buf[i:])
}

cell_at :: proc(g: ^Game, x, y: int) -> Cell {
	return floor_cell(floor_of(g), x, y)
}

stop_travel :: proc(g: ^Game) {
	g.path_len, g.path_i, g.travel_wait = 0, 0, 0
}

// One step of the player, then the turn passes (the wind may move them again); false when a wall
// is in the way (no turn passes).
step_player :: proc(g: ^Game, d: [2]int) -> bool {
	if !passable(cell_at(g, g.x + d.x, g.y + d.y)) {
		return false
	}
	g.x += d.x
	g.y += d.y
	end_turn(g)
	return true
}

describe_arrival :: proc(g: ^Game) {
	#partial switch cell_at(g, g.x, g.y) {
	case .Stairs_Up:
		say(g, "Stairs up. Confirm to climb.")
	case .Stairs_Down:
		say(g, "Stairs down. Confirm to descend.")
	}
}

command :: proc(g: ^Game, c: Command) {
	stop_travel(g)
	if g.mode == .Automap {
		g.mode = .Play // any command closes the map
		return
	}
	switch c {
	case .North, .South, .West, .East, .North_West, .North_East, .South_West, .South_East:
		if step_player(g, DIRECTION[c]) {
			describe_arrival(g)
		} else {
			say(g, "A wall.")
		}
	case .Wait:
		say(g, "You wait. The wind does not.")
		end_turn(g)
	case .Confirm:
		use_here(g)
	case .Cancel:
	case .Map:
		g.mode = .Automap
	}
}

// Confirm on the spot: take the stairs, or nothing.
use_here :: proc(g: ^Game) {
	buf: [8]u8
	#partial switch cell_at(g, g.x, g.y) {
	case .Stairs_Up:
		if g.current + 1 < FLOOR_COUNT {
			enter_floor(g, g.current + 1, .Stairs_Down)
			say(g, "You climb to floor ", itoa(buf[:], g.current + 1), ". The wind is stronger.")
		} else {
			say(g, "The stairs above are not built yet.")
		}
	case .Stairs_Down:
		if g.current > 0 {
			enter_floor(g, g.current - 1, .Stairs_Up)
			say(g, "You go down to floor ", itoa(buf[:], g.current + 1), ".")
		} else {
			say(g, "Below is the town. It is not built yet.")
		}
	case:
		if !light_torch(g) {
			say(g, "Nothing here to use.")
		}
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

Pointer :: enum i32 {
	Mouse_Primary,
	Mouse_Secondary,
	Touch,
}

// A click or tap at a screen pixel. A mouse click walks there (one step, or a route over seen
// cells); a right click or a tap inspects (touch moves with the d-pad; DESIGN.md).
pointer :: proc(g: ^Game, sx, sy: int, kind: Pointer) {
	stop_travel(g)
	if g.mode == .Automap {
		g.mode = .Play
		return
	}
	x, y, ok := screen_to_cell(g, sx, sy)
	if !ok {
		return
	}
	f := floor_of(g)
	if kind != .Mouse_Primary {
		inspect(g, x, y)
		return
	}
	if x == g.x && y == g.y {
		use_here(g)
		return
	}
	if abs(x - g.x) <= 1 && abs(y - g.y) <= 1 {
		if step_player(g, {x - g.x, y - g.y}) {
			describe_arrival(g)
		} else {
			say(g, "A wall.")
		}
		return
	}
	g.path_len = find_path(f, {g.x, g.y}, {x, y}, &g.path)
	if g.path_len == 0 {
		say(g, "You know no way there.")
	}
}

inspect :: proc(g: ^Game, x, y: int) {
	f := floor_of(g)
	if x < 0 || y < 0 || x >= FLOOR_W || y >= FLOOR_H || !f.seen[y][x] {
		say(g, "You have not seen that.")
		return
	}
	if x == g.x && y == g.y {
		say(g, "You. Windswept.")
		return
	}
	switch f.cells[y][x] {
	case .Wall:
		say(g, "A wall of the bulwark.")
	case .Floor:
		say(g, "Floor.")
	case .Stairs_Up:
		say(g, "Stairs up.")
	case .Stairs_Down:
		say(g, "Stairs down.")
	}
}

// Called once per frame by the platform; walks a mouse route. True when something changed.
tick :: proc(g: ^Game) -> bool {
	if g.path_i >= g.path_len {
		return false
	}
	g.travel_wait += 1
	if g.travel_wait < TRAVEL_FRAMES {
		return false
	}
	g.travel_wait = 0
	next := g.path[g.path_i]
	g.path_i += 1
	d := next - [2]int{g.x, g.y}
	if abs(d.x) > 1 || abs(d.y) > 1 || !step_player(g, d) {
		stop_travel(g)
		return true
	}
	if g.path_i >= g.path_len {
		stop_travel(g)
		describe_arrival(g)
	}
	return true
}
