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
	f.w, f.h = 60, 40
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
	// The Skull first and the Key last, so the Key lies on top (new_item takes the lowest free
	// slot and the topmost thing on a cell is the highest slot): you see it, and Enter takes it.
	for k in ([?]Item_Kind{.Skull, .Key}) {
		id := new_item(g, k)
		if id != 0 {
			g.items[id].place, g.items[id].floor = .Ground, t.floor
			g.items[id].x, g.items[id].y = t.x, t.y
		}
	}
}

has_key :: proc(g: ^Game) -> bool {
	return has_kind(g, .Key)
}

has_kind :: proc(g: ^Game, kind: Item_Kind) -> bool {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == kind && is_carried(g, i) {
			return true
		}
	}
	return false
}

// The stairs up on floor 4.
door_to_floor_five :: proc(g: ^Game) {
	if BOSS_INDEX in g.unlocked {
		enter_floor(g, BOSS_INDEX + 1, .Stairs_Down)
		say(g, "You climb to floor 5. The wind is stronger.")
	} else if has_key(g) {
		// Once opened it stays open: a key lost in a fall up there cannot lock you out.
		g.unlocked += {BOSS_INDEX}
		enter_floor(g, BOSS_INDEX + 1, .Stairs_Down)
		say(g, "The key turns. The door stays open. You climb to floor 5. The wind is stronger.")
		play_sound(g, .Key)
	} else {
		say(g, "The door to floor 5 is locked. The Horde has the key, they say.")
	}
}

// The notice box (Notice mode). Since the step 29 review (November 22, 2026) the only notice is
// meeting His Lordship (top.odin); the end-of-stretch notices for the keys to floors 5, 9 and 13 are
// gone.
NOTICE_Y :: 40

draw_notice :: proc(f: ^Frame, g: ^Game) {
	draw_lord_notice(f)
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
