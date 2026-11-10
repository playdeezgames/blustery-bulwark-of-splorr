package game

// One floor of the bulwark: generated from a seed (rooms joined by corridors), remembered as seen,
// and kept for the character's whole life (floors persist; DESIGN.md).

FLOOR_W :: 60
FLOOR_H :: 40

Cell :: enum u8 {
	Wall,
	Floor,
	Stairs_Up,
	Stairs_Down,
	Building, // the town's houses
	Door, // a way into a town shop (or the herald's spot)
}

Room :: struct {
	x, y, w, h: int,
}

MAX_ROOMS :: 14

Floor :: struct {
	number:     int, // 1 is the lowest floor, above the town
	made:       bool,
	cells:      [FLOOR_H][FLOOR_W]Cell,
	seen:       [FLOOR_H][FLOOR_W]bool, // remembered (fog of war)
	rooms:      [MAX_ROOMS]Room,
	room_count: int,
	up, down:   [2]int, // stairs
	wind_from:  int, // index into DIRECTIONS and COMPASS: where this floor's wind comes from
}

passable :: proc(c: Cell) -> bool {
	return c != .Wall && c != .Building
}

floor_cell :: proc(f: ^Floor, x, y: int) -> Cell {
	if x < 0 || y < 0 || x >= FLOOR_W || y >= FLOOR_H {
		return .Wall
	}
	return f.cells[y][x]
}

room_centre :: proc(r: Room) -> [2]int {
	return {r.x + r.w / 2, r.y + r.h / 2}
}

// Fills a floor from its seed. Rooms are placed apart (with every attempt bounded), each joined to
// the one before by an L-shaped corridor, with an occasional extra corridor for a loop. Stairs down
// are in the first room, stairs up in the room farthest from them.
generate_floor :: proc(f: ^Floor, seed: u64, number: int) {
	f^ = {}
	f.number = number
	r := Rng{seed}
	for attempt := 0; attempt < 400 && f.room_count < MAX_ROOMS; attempt += 1 {
		room := Room{w = rng_range(&r, 4, 11), h = rng_range(&r, 3, 7)}
		room.x = rng_range(&r, 1, FLOOR_W - room.w - 2)
		room.y = rng_range(&r, 1, FLOOR_H - room.h - 2)
		clear := true
		for other in f.rooms[:f.room_count] {
			// Keep a wall of at least one cell between rooms.
			if room.x - 1 <= other.x + other.w && other.x - 1 <= room.x + room.w &&
			   room.y - 1 <= other.y + other.h && other.y - 1 <= room.y + room.h {
				clear = false
				break
			}
		}
		if !clear {
			continue
		}
		f.rooms[f.room_count] = room
		f.room_count += 1
	}
	assert(f.room_count >= 2)
	for room in f.rooms[:f.room_count] {
		for y in room.y ..< room.y + room.h {
			for x in room.x ..< room.x + room.w {
				f.cells[y][x] = .Floor
			}
		}
	}
	for i in 1 ..< f.room_count {
		dig_corridor(f, &r, room_centre(f.rooms[i - 1]), room_centre(f.rooms[i]))
	}
	for _ in 0 ..< f.room_count / 4 {
		a, b := rng_int(&r, f.room_count), rng_int(&r, f.room_count)
		if a != b {
			dig_corridor(f, &r, room_centre(f.rooms[a]), room_centre(f.rooms[b]))
		}
	}
	f.down = room_centre(f.rooms[0])
	far, best := 1, -1
	for i in 1 ..< f.room_count {
		c := room_centre(f.rooms[i])
		d := abs(c.x - f.down.x) + abs(c.y - f.down.y)
		if d > best {
			far, best = i, d
		}
	}
	f.up = room_centre(f.rooms[far])
	f.cells[f.down.y][f.down.x] = .Stairs_Down
	f.cells[f.up.y][f.up.x] = .Stairs_Up
	f.wind_from = rng_int(&r, len(DIRECTIONS))
	f.made = true
}

dig_corridor :: proc(f: ^Floor, r: ^Rng, a, b: [2]int) {
	corner := rng_int(r, 2) == 0 ? [2]int{b.x, a.y} : [2]int{a.x, b.y}
	dig_line(f, a, corner)
	dig_line(f, corner, b)
}

dig_line :: proc(f: ^Floor, a, b: [2]int) {
	x, y := a.x, a.y
	for {
		if f.cells[y][x] == .Wall {
			f.cells[y][x] = .Floor
		}
		if x == b.x && y == b.y {
			break
		}
		x += sign(b.x - x)
		y += sign(b.y - y)
	}
}

sign :: proc(v: int) -> int {
	return v > 0 ? 1 : v < 0 ? -1 : 0
}

// Field of view: a cell is visible when the straight line to it from (px, py) meets no wall before it.
SIGHT :: 7 // with a lit torch

Visible :: [FLOOR_H][FLOOR_W]bool

compute_fov :: proc(f: ^Floor, px, py, sight: int, vis: ^Visible) {
	vis^ = {}
	for y in max(0, py - sight) ..= min(FLOOR_H - 1, py + sight) {
		for x in max(0, px - sight) ..= min(FLOOR_W - 1, px + sight) {
			dx, dy := x - px, y - py
			if dx * dx + dy * dy > sight * sight + sight {
				continue
			}
			if line_clear(f, px, py, x, y) {
				vis[y][x] = true
				f.seen[y][x] = true
			}
		}
	}
	// Walls touching a visible open cell are visible too, so room corners are not left out.
	for y in max(1, py - sight) ..= min(FLOOR_H - 2, py + sight) {
		for x in max(1, px - sight) ..= min(FLOOR_W - 2, px + sight) {
			if !vis[y][x] || !passable(f.cells[y][x]) {
				continue
			}
			for d in DIRECTIONS {
				n := [2]int{x, y} + d
				if f.cells[n.y][n.x] == .Wall {
					vis[n.y][n.x] = true
					f.seen[n.y][n.x] = true
				}
			}
		}
	}
}

// Bresenham from (x0, y0) to (x1, y1): true when no wall stands strictly between them.
line_clear :: proc(f: ^Floor, x0, y0, x1, y1: int) -> bool {
	dx, dy := abs(x1 - x0), -abs(y1 - y0)
	sx, sy := sign(x1 - x0), sign(y1 - y0)
	err := dx + dy
	x, y := x0, y0
	for {
		if x == x1 && y == y1 {
			return true
		}
		if (x != x0 || y != y0) && floor_cell(f, x, y) == .Wall {
			return false
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x += sx
		}
		if e2 <= dx {
			err += dx
			y += sy
		}
	}
}

// A walking route over cells the player has seen, by breadth-first search with eight-way steps.
// Returns the number of steps written into `out` (0 when there is no route or it is too long).
MAX_PATH :: 256

find_path :: proc(f: ^Floor, from, to: [2]int, out: ^[MAX_PATH][2]int) -> int {
	if from == to || floor_cell(f, to.x, to.y) == .Wall || !f.seen[to.y][to.x] {
		return 0
	}
	@(static) prev: [FLOOR_H][FLOOR_W][2]int
	@(static) done: [FLOOR_H][FLOOR_W]bool
	@(static) queue: [FLOOR_W * FLOOR_H][2]int
	done = {}
	head, tail := 0, 0
	queue[tail] = from
	tail += 1
	done[from.y][from.x] = true
	found := false
	for head < tail && !found {
		c := queue[head]
		head += 1
		for d in DIRECTIONS {
			n := c + d
			if n.x < 0 || n.y < 0 || n.x >= FLOOR_W || n.y >= FLOOR_H || done[n.y][n.x] {
				continue
			}
			if !passable(f.cells[n.y][n.x]) || !f.seen[n.y][n.x] {
				continue
			}
			done[n.y][n.x] = true
			prev[n.y][n.x] = c
			queue[tail] = n
			tail += 1
			if n == to {
				found = true
				break
			}
		}
	}
	if !found {
		return 0
	}
	n := 0
	for c := to; c != from; c = prev[c.y][c.x] {
		n += 1
	}
	if n > MAX_PATH {
		return 0
	}
	i := n
	for c := to; c != from; c = prev[c.y][c.x] {
		i -= 1
		out[i] = c
	}
	return n
}

// The eight compass steps, straight ones first so routes prefer them.
DIRECTIONS := [8][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
