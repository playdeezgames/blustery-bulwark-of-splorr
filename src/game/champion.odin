package game

// Floor 15, "His Lordship's champion, undefeated" (slice 4 step 28; DESIGN.md beats 4 and 5). A
// very tidy hall with an empty trophy cabinet and no carny: nobody sells tickets, because nobody has
// ever come. The champion has never fought anyone. His aim starts poor and improves with every turn
// he fights, so a quick fight is a kind one. At a quarter of his health he sits down instead of
// dying, gives up the key to floor 16, says nobody has been higher, and goes down to the tavern,
// where he sits with yer mentor from then on. The door above was never locked.

CHAMPION_INDEX :: 14 // floors[14] is floor 15
CHAMPION_X :: 11
CHAMPION_Y :: 16
CHAMPION_HIT :: 30 // his chance to hit at first
CHAMPION_LEARN :: 5 // more for every turn he fights
CHAMPION_BEST :: 75 // and no more than this
CHAMPION_YIELD :: 15 // he sits down at this much health or less (a quarter of his 60)

CHAMPION_MAP := [?]string {
	"##########################################",
	"#....#................T..................#",
	"#....#...................................#",
	"#....#...................................#",
	"#....#...................................#",
	"#.D...............................C...U..#",
	"#....#...................................#",
	"#....#...................................#",
	"#....#...................................#",
	"#....#...................................#",
	"##########################################",
}

CHAMPION_LINES := [?]string { // in the tavern, after
	"\"Nineteen years and not one challenger. I did a great deal of polishing.\"",
	"\"Undefeated is easy. You only have to live very far up.\"",
	"\"Yer mentor and I stopped on fifteen together. I stayed. Somebody had to look undefeated.\"",
}

// Builds floor 15 by hand: the champion before the stairs up, and the trophy cabinet.
build_champion_floor :: proc(g: ^Game) {
	f := &g.floors[CHAMPION_INDEX]
	f^ = {}
	f.number = CHAMPION_INDEX + 1
	f.made = true
	f.w, f.h = floor_size(f.number)
	f.wind_from = 2 // from the west: the gusts blow east down the hall, toward him and the stairs up
	champion_cells(f)
	for row, y in CHAMPION_MAP {
		for x in 0 ..< len(row) {
			cx, cy := CHAMPION_X + x, CHAMPION_Y + y
			switch row[x] {
			case 'C':
				if !g.no_tenants {
					new_tenant(g, .Champion, CHAMPION_INDEX, cx, cy)
				}
			case 'T':
				id := new_item(g, .Trophy_Cabinet)
				if id != 0 {
					g.items[id].place, g.items[id].floor = .Ground, i8(CHAMPION_INDEX)
					g.items[id].x, g.items[id].y = i16(cx), i16(cy)
				}
			}
		}
	}
}

// Floor 15's cells and stairs from CHAMPION_MAP (also used to restore a save).
champion_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in CHAMPION_MAP {
		for x in 0 ..< len(row) {
			cx, cy := CHAMPION_X + x, CHAMPION_Y + y
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

// The champion's chance to hit you: poor at first, better with every turn he has fought.
champion_hit :: proc(g: ^Game) -> int {
	return min(CHAMPION_BEST, CHAMPION_HIT + CHAMPION_LEARN * g.champion_fights)
}

// A turn of fighting teaches him something.
champion_learns :: proc(g: ^Game) {
	if champion_hit(g) >= CHAMPION_BEST {
		return
	}
	g.champion_fights += 1
	if champion_hit(g) >= CHAMPION_BEST {
		say(g, "He is getting the hang of this.")
	}
}

// At a quarter of his health the champion sits down: he never dies. He gives you the key to floor
// 16 (at yer feet if yer hands are full) and is worth his XP all the same.
champion_yields :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	t.health = max(t.health, 1)
	t.kind = .Champion_Seated
	t.awake = false
	t.still = true
	g.champion_yielded = true
	g.xp += TENANT[.Champion].xp
	check_level(g) // first, so his words and the key are the last lines in the log
	say(g, "The champion sits down. \"Thank you. Nineteen years undefeated. It was heavy.\"")
	if key := new_item(g, .Key_Sixteen); key != 0 {
		if stow(g, key) {
			say(g, "He gives you the key to floor 16.")
		} else {
			g.items[key].place, g.items[key].floor = .Ground, i8(g.current)
			g.items[key].x, g.items[key].y = i16(g.x), i16(g.y)
			say(g, "He sets the key to floor 16 at yer feet.")
		}
	}
}

// Bumping the champion once he has yielded: nobody has been higher, and he goes down to town.
champion_talks :: proc(g: ^Game, id: int) {
	say(g, "\"Nobody has been higher. Not yer mentor either. We stopped here together, and they went down.\"")
	say(g, "He dusts where he sat and goes to town.")
	g.tenants[id] = {}
}

// He leaves for town once you leave his floor, too.
champion_leaves :: proc(g: ^Game) {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Champion_Seated {
			g.tenants[i] = {}
		}
	}
}

// The stairs up on floor 15: the door to floor 16, the roof. It opens with the key or without it;
// it was never locked, and nothing says so.
door_to_floor_sixteen :: proc(g: ^Game) {
	opened := ""
	if CHAMPION_INDEX not_in g.unlocked {
		g.unlocked += {CHAMPION_INDEX}
		opened = has_kind(g, .Key_Sixteen) ? "The key turns." : "The door opens."
		play_sound(g, .Key)
	}
	enter_floor(g, LORD_INDEX, .Stairs_Down)
	if opened != "" {
		say(g, opened)
	}
	say(g, "You climb out onto the roof. The wind is strongest here.")
}
