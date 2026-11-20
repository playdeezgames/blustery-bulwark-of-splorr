package game

// Floor 12, "a giant" (slice 3 step 22; DESIGN.md beat 4 "A giant": an ordinary ogre standing on a
// box; knock the box away, and the wind can too, and the fight changes). A carny takes four Jools at
// the door (or fights if you shove past). On its crate the giant clubs you from two cells away, so it
// hits you as you close in. The crate is empty, so the wind catches it: a gust tips it one time in
// three, and a gale, a gust ball or a squall knocks it away at once. Off the crate the giant is an
// ogre of ordinary height that walks back to the crate and climbs up, unless the crate is gone:
// a loose crate blows downwind, and you can pick it up yerself. It drops the key to floor 13.

GIANT_INDEX :: 11 // floors[11] is floor 12
GIANT_X :: 10
GIANT_Y :: 15
GIANT_ADMISSION :: 4
GIANT_REACH :: 2 // on its crate, it strikes from this far
GIANT_DMIN :: 4 // and this hard
GIANT_DMAX :: 10
CRATE_TIP :: 3 // a gust tips the crate one time in this many
GIANT_LIFT :: 6 // pixels the giant is drawn above its cell while on its crate

GIANT_MAP := [?]string {
	"############################################",
	"#....#######################################",
	"#....#.....................................#",
	"#.a..#.....................................#",
	"#....#.....................................#",
	"#....#.....................................#",
	"#.D..C....................G..............U.#",
	"#....#.....................................#",
	"#....#.....................................#",
	"#....#.....................................#",
	"#....#.....................................#",
	"#....#######################################",
	"############################################",
}

// Builds floor 12 by hand, with its tenants: the giant on its crate and the carny at the door.
build_giant_floor :: proc(g: ^Game) {
	f := &g.floors[GIANT_INDEX]
	f^ = {}
	f.number = GIANT_INDEX + 1
	f.made = true
	f.w, f.h = floor_size(f.number)
	f.wind_from = 2 // from the west: the gusts blow east down the hall, toward the stairs up
	giant_cells(f)
	if g.no_tenants {
		return
	}
	for row, y in GIANT_MAP {
		for x in 0 ..< len(row) {
			cx, cy := GIANT_X + x, GIANT_Y + y
			switch row[x] {
			case 'G':
				new_tenant(g, .Giant, GIANT_INDEX, cx, cy)
				g.giant_up = true
				crate := new_item(g, .Crate)
				if crate != 0 {
					g.items[crate].place, g.items[crate].floor = .Ground, i8(GIANT_INDEX)
					g.items[crate].x, g.items[crate].y = i16(cx), i16(cy)
				}
			case 'C':
				g.giant_ticket = new_tenant(g, .Carny, GIANT_INDEX, cx, cy)
				g.tenants[g.giant_ticket].still = true
			}
		}
	}
}

// Floor 12's cells and stairs from GIANT_MAP (also used to restore a save).
giant_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in GIANT_MAP {
		for x in 0 ..< len(row) {
			cx, cy := GIANT_X + x, GIANT_Y + y
			c: Cell = .Floor
			switch row[x] {
			case '#':
				c = .Wall
			case 'U':
				c = .Stairs_Up
				f.up = {cx, cy}
			case 'D':
				c = .Stairs_Down
				f.down = {cx, cy}
			}
			f.cells[cy][cx] = c
		}
	}
}

giant_alcove :: proc() -> [2]int {
	return {GIANT_X + 2, GIANT_Y + 3}
}

// Paying the carny at floor 12's door: it steps aside into the corner.
giant_admit :: proc(g: ^Game) {
	g.giant_admitted = true
	t := &g.tenants[g.giant_ticket]
	if t.kind == .Carny {
		a := giant_alcove()
		t.x, t.y = i16(a.x), i16(a.y)
	}
	say(g, "The carny steps aside. \"Right this way! Mind yer head!\"")
}

// The crate lying loose on floor 12's floor (not carried), or 0.
loose_crate :: proc(g: ^Game) -> int {
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.kind == .Crate && it.place == .Ground && int(it.floor) == GIANT_INDEX {
			return i
		}
	}
	return 0
}

// The giant is on its crate.
giant_on_crate :: proc(g: ^Game, t: ^Tenant) -> bool {
	return t.kind == .Giant && g.giant_up
}

// The crate goes out from under the giant along `d` (as far as the push carries it, stopping at a
// wall), and the giant comes down to ogre height where it stood.
tip_crate :: proc(g: ^Game, id: int, d: [2]int, by_gust: bool) {
	t := &g.tenants[id]
	g.giant_up = false
	if crate := loose_crate(g); crate != 0 {
		it := &g.items[crate]
		f := &g.floors[GIANT_INDEX]
		for _ in 0 ..< gust_push(f.number) {
			nx, ny := int(it.x) + d.x, int(it.y) + d.y
			if !passable(floor_cell(f, nx, ny)) {
				break
			}
			it.x, it.y = i16(nx), i16(ny)
		}
	}
	if g.vis[t.y][t.x] {
		say(g, by_gust ? "A gust tips the crate. The giant comes down to ogre height." : "The crate flies out from under the giant. It is only an ogre.")
	}
}

// The giant's turn. On its crate it stays put and clubs you from up to two cells away. Off it, it
// clubs you if yer next to it; otherwise it goes back for its crate and spends a turn climbing up.
// False when the crate is gone (carried off): then it is only an ogre, and fights like one.
giant_act :: proc(g: ^Game, id: int) -> bool {
	t := &g.tenants[id]
	if g.giant_up {
		far := max(abs(int(t.x) - g.x), abs(int(t.y) - g.y))
		if t.awake && far <= GIANT_REACH && line_clear(floor_of(g), int(t.x), int(t.y), g.x, g.y) {
			tenant_attack(g, id)
		}
		return true
	}
	crate := loose_crate(g)
	if crate == 0 {
		return false
	}
	if abs(int(t.x) - g.x) <= 1 && abs(int(t.y) - g.y) <= 1 {
		tenant_attack(g, id)
		return true
	}
	it := g.items[crate]
	if t.x == it.x && t.y == it.y {
		g.giant_up = true
		if g.vis[t.y][t.x] {
			say(g, "The giant climbs back onto its crate.")
		}
		return true
	}
	best, best_d := [2]int{}, dist2(int(t.x), int(t.y), int(it.x), int(it.y))
	for d in DIRECTIONS {
		nd := dist2(int(t.x) + d.x, int(t.y) + d.y, int(it.x), int(it.y))
		if nd < best_d && tenant_can_enter(g, int(t.x) + d.x, int(t.y) + d.y) {
			best, best_d = d, nd
		}
	}
	if best != {} {
		tenant_step(g, id, best)
	}
	return true
}

// The giant is gone: an ogre tooth and the key drop (the key last, so it lies on top).
giant_falls :: proc(g: ^Game, t: Tenant) {
	g.giant_dead = true
	g.giant_up = false
	say(g, "That was the Giant.")
	for k in ([?]Item_Kind{.Ogre_Tooth, .Key_Thirteen}) {
		id := new_item(g, k)
		if id != 0 {
			g.items[id].place, g.items[id].floor = .Ground, t.floor
			g.items[id].x, g.items[id].y = t.x, t.y
		}
	}
}

// The stairs up on floor 12: the door to floor 13 (slice 4 step 24). Once opened it stays open, as
// on floors 4 and 8.
door_to_floor_thirteen :: proc(g: ^Game) {
	if GIANT_INDEX in g.unlocked {
		enter_floor(g, GIANT_INDEX + 1, .Stairs_Down)
		say(g, "You climb to floor 13. The wind is stronger.")
	} else if has_kind(g, .Key_Thirteen) {
		g.unlocked += {GIANT_INDEX}
		enter_floor(g, GIANT_INDEX + 1, .Stairs_Down)
		say(g, "The key turns. The door stays open.")
		say(g, "You climb to floor 13. The wind is stronger.")
	} else {
		say(g, "The door to floor 13 is locked. The giant has the key, they say.")
	}
}

// The herald's Certificate, the first time it proclaims the giant felled.
give_certificate :: proc(g: ^Game) {
	id := new_item(g, .Certificate)
	if id == 0 {
		return
	}
	if !stow(g, id) {
		g.items[id].place, g.items[id].floor = .Ground, i8(TOWN)
		g.items[id].x, g.items[id].y = i16(g.x), i16(g.y)
	}
	say(g, "The herald hands you a Certificate. \"Giant felled. Height not recorded.\"")
}
