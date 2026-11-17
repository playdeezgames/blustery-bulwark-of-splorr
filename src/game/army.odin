package game

// Floor 8, "an army of a thousand" (slice 2 step 15; DESIGN.md beat 4 "An army of a thousand": a
// thousand of something small, a swarm rather than soldiers). The lord proclaims the floor held by
// an army of a thousand: it is forty rats and a sergeant rat in a tiny hat. A carny takes three
// Jools at the door (or fights if you shove past). The wind blows down the hall from the west and
// sweeps the rats with it. When the sergeant falls the rest scatter, and it drops the key to floor 9,
// whose door opens onto floor 9 (since slice 3 step 17; it opened on scaffolding in slice 2).
// Reaching the floor gives the windchute a second stop.

ARMY_INDEX :: 7 // floors[7] is floor 8
ARMY_X :: 8
ARMY_Y :: 15
ARMY_ADMISSION :: 3

ARMY_MAP := [?]string {
	"################################################",
	"########.......................................#",
	"########......r...r...r...r...r...r...r...r....#",
	"########.......................................#",
	"#....a.#......r...r...r...r...r...r...r...r....#",
	"#......#.......................................#",
	"#.D....C......r...r...r...r...r...r...r...rS..U#",
	"#......#.......................................#",
	"#......#......r...r...r...r...r...r...r...r....#",
	"########.......................................#",
	"########......r...r...r...r...r...r...r...r....#",
	"########.......................................#",
	"################################################",
}

// Builds floor 8 by hand, with its tenants: the rats, the sergeant and the carny at the door.
build_army_floor :: proc(g: ^Game) {
	f := &g.floors[ARMY_INDEX]
	f^ = {}
	f.number = ARMY_INDEX + 1
	f.made = true
	f.w, f.h = floor_size(f.number)
	f.wind_from = 2 // from the west: the gusts blow east down the hall
	army_cells(f)
	if g.no_tenants {
		return
	}
	for row, y in ARMY_MAP {
		for x in 0 ..< len(row) {
			cx, cy := ARMY_X + x, ARMY_Y + y
			switch row[x] {
			case 'r':
				new_tenant(g, .Rat, ARMY_INDEX, cx, cy)
			case 'S':
				new_tenant(g, .Sergeant, ARMY_INDEX, cx, cy)
			case 'C':
				g.army_ticket = new_tenant(g, .Carny, ARMY_INDEX, cx, cy)
				g.tenants[g.army_ticket].still = true
			}
		}
	}
}

// Floor 8's cells and stairs from ARMY_MAP (also used to restore a save).
army_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in ARMY_MAP {
		for x in 0 ..< len(row) {
			cx, cy := ARMY_X + x, ARMY_Y + y
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

army_alcove :: proc() -> [2]int {
	return {ARMY_X + 5, ARMY_Y + 4}
}

// Paying the carny at floor 8's door: it steps aside into the corner.
army_admit :: proc(g: ^Game) {
	g.army_admitted = true
	t := &g.tenants[g.army_ticket]
	if t.kind == .Carny {
		a := army_alcove()
		t.x, t.y = i16(a.x), i16(a.y)
	}
	say(g, "The carny steps aside. \"Right this way! Mind the Army!\"")
}

// The sergeant is gone: the key drops, and the rest of the army scatters into the cracks.
sergeant_falls :: proc(g: ^Game, t: Tenant) {
	g.army_dead = true
	fled := 0
	for i in 1 ..< MAX_TENANTS {
		r := &g.tenants[i]
		if r.kind == .Rat && int(r.floor) == ARMY_INDEX {
			r^ = {}
			fled += 1
		}
	}
	say(g, "That was the Army of a Thousand.")
	if fled > 0 {
		say(g, "Without the hat, the rest are only rats. They scatter into the cracks.")
	}
	id := new_item(g, .Key_Nine)
	if id != 0 {
		g.items[id].place, g.items[id].floor = .Ground, t.floor
		g.items[id].x, g.items[id].y = t.x, t.y
	}
}

// The stairs up on floor 8: the door to floor 9 (slice 3 step 17). Once opened it stays open, as
// on floor 4, so a key lost in a fall up there cannot lock you out.
door_to_floor_nine :: proc(g: ^Game) {
	if ARMY_INDEX in g.unlocked {
		enter_floor(g, ARMY_INDEX + 1, .Stairs_Down)
		say(g, "You climb to floor 9. The wind is stronger.")
	} else if has_kind(g, .Key_Nine) {
		g.unlocked += {ARMY_INDEX}
		enter_floor(g, ARMY_INDEX + 1, .Stairs_Down)
		say(g, "The key turns. The door stays open.")
		say(g, "You climb to floor 9. The wind is stronger.")
	} else {
		say(g, "The door to floor 9 is locked. The army has the key, they say.")
	}
}

// The herald's Medal, the first time it proclaims the army routed.
give_medal :: proc(g: ^Game) {
	id := new_item(g, .Medal)
	if id == 0 {
		return
	}
	if !stow(g, id) {
		g.items[id].place, g.items[id].floor = .Ground, i8(TOWN)
		g.items[id].x, g.items[id].y = i16(g.x), i16(g.y)
	}
	say(g, "The herald pins a Medal on you. \"For attending.\"")
}
