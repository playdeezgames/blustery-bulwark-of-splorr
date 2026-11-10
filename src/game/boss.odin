package game

// Floor 4 and the end of slice 1 (slice 1 step 8; DESIGN.md beat 3 "Each boss is a boast made
// real", beat 4 "The undead horde"). The lord proclaims the floor guarded by an undead horde: it is
// one skeleton nobody got round to burying, with friends' bones propped up to look like more. A
// carny takes two Jools at the door (or fights if you shove past). The skeleton drops the key to
// floor 5 and a skull; the door to floor 5 opens on scaffolding, because the rest of the bulwark is
// still being built. Reaching the floor opens a windchute from the town gate.

BOSS_INDEX :: 3 // floors[3] is floor 4
BOSS_X :: 20
BOSS_Y :: 14
ADMISSION :: 2
TOPPLE_CHANCE :: 3 // each gust knocks over each standing prop one time in this many

BOSS_MAP := [?]string {
	"#####################",
	"#.........U.........#",
	"#...................#",
	"#..b.....b.....b....#",
	"#.........S.........#",
	"#..b.....b.....b....#",
	"#...................#",
	"##########C##########",
	"#########a..#########",
	"##########..#########",
	"##########D.#########",
	"#####################",
}

// Builds floor 4 by hand, with its tenants: the skeleton, the propped-up bones and the carny at
// the door.
build_boss_floor :: proc(g: ^Game) {
	f := &g.floors[BOSS_INDEX]
	f^ = {}
	f.number = BOSS_INDEX + 1
	f.made = true
	f.wind_from = 2 // from the west: the gusts blow east across the hall
	boss_cells(f)
	for row, y in BOSS_MAP {
		for x in 0 ..< len(row) {
			cx, cy := BOSS_X + x, BOSS_Y + y
			switch row[x] {
			case 'b':
				if !g.no_tenants {
					new_tenant(g, .Bones, BOSS_INDEX, cx, cy)
				}
			case 'S':
				if !g.no_tenants {
					new_tenant(g, .Skeleton, BOSS_INDEX, cx, cy)
				}
			case 'C':
				if !g.no_tenants {
					g.ticket = new_tenant(g, .Carny, BOSS_INDEX, cx, cy)
					g.tenants[g.ticket].still = true
				}
			}
		}
	}
}

// Floor 4's cells and stairs from BOSS_MAP (also used to restore a save).
boss_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in BOSS_MAP {
		for x in 0 ..< len(row) {
			cx, cy := BOSS_X + x, BOSS_Y + y
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

boss_alcove :: proc() -> [2]int {
	return {BOSS_X + 9, BOSS_Y + 8}
}

// Paying the carny at the door: it steps aside into the alcove.
admit :: proc(g: ^Game) {
	g.admitted = true
	t := &g.tenants[g.ticket]
	if t.kind == .Carny {
		a := boss_alcove()
		t.x, t.y = i16(a.x), i16(a.y)
	}
	say(g, "The carny steps aside. \"Right this way! Mind the Horde!\"")
}

// A propped-up skeleton falls over: it leaves old bones and was never a tenant at all.
topple :: proc(g: ^Game, id: int, by_gust: bool) {
	t := g.tenants[id]
	g.tenants[id] = {}
	bones := new_item(g, .Old_Bones)
	if bones != 0 {
		g.items[bones].place, g.items[bones].floor = .Ground, t.floor
		g.items[bones].x, g.items[bones].y = t.x, t.y
	}
	if g.vis[t.y][t.x] {
		say(g, by_gust ? "A gust knocks a skeleton over. It was only bones, propped up." : "You push the skeleton. It falls apart: only bones, propped up.")
	}
}

// The skeleton is gone: the key and a skull drop, and the horde is no more.
boss_falls :: proc(g: ^Game, t: Tenant) {
	g.boss_dead = true
	say(g, "That was the Undead Horde.")
	for k in ([?]Item_Kind{.Key, .Skull}) {
		id := new_item(g, k)
		if id != 0 {
			g.items[id].place, g.items[id].floor = .Ground, t.floor
			g.items[id].x, g.items[id].y = t.x, t.y
		}
	}
}

has_key :: proc(g: ^Game) -> bool {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Key && is_carried(g, i) {
			return true
		}
	}
	return false
}

// The stairs up on floor 4.
door_to_floor_five :: proc(g: ^Game) {
	if has_key(g) {
		say(g, "The key fits. Beyond the door: scaffolding, and a sign. \"Floor 5. Coming soon, by order of His Lordship.\"")
	} else {
		say(g, "The door to floor 5 is locked. The Horde has the key, they say.")
	}
}

// The end of slice 1: shown once, the first time the key is picked up.
NOTICE_Y :: 40

draw_notice :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, 14, NOTICE_Y - 8, VIEW_W * TILE - 28, 84, COLOR_BLACK)
	fill_rect(f, 14, NOTICE_Y - 8, VIEW_W * TILE - 28, 1, COLOR_YELLOW)
	fill_rect(f, 14, NOTICE_Y + 75, VIEW_W * TILE - 28, 1, COLOR_YELLOW)
	print(f, "The key to floor 5.", 24, NOTICE_Y, COLOR_YELLOW)
	print(f, "Here ends the first stretch.", 24, NOTICE_Y + 14, COLOR_LIGHT)
	print(f, "The rest of the bulwark is", 24, NOTICE_Y + 24, COLOR_LIGHT)
	print(f, "still being built.", 24, NOTICE_Y + 34, COLOR_LIGHT)
	print(f, "Thank you for climbing.", 24, NOTICE_Y + 48, COLOR_MID)
	print(f, "Enter/OK or click to go on.", 24, NOTICE_Y + 62, COLOR_YELLOW)
}

// The town gate, once floor 4 has been reached: climb, or ride the windchute up.
gate :: proc(g: ^Game) {
	if g.deepest >= BOSS_INDEX + 1 {
		open_shop(g, .Gate)
		return
	}
	enter_floor(g, 0, .Stairs_Down)
	say(g, "You climb to floor 1. The wind is stronger.")
}
