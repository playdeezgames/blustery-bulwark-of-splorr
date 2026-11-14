package game

// Earlier climbers (slice 2 step 12; DESIGN.md beat 3, "Every floor holds traces of people who
// believed and climbed"). Floors 5 to 7 each have a camp: a cold fire and a bedroll that stay put,
// a note that hints at the top without saying, and a piece of heavy gear worth taking and costly to
// carry. On floor 6 a climber who stopped there still lives in her camp: the hermit, who trades.

CAMP_FLOORS :: [2]int{5, 7}

// The camp's piece of gear, by floor number.
camp_gear :: proc(number: int) -> Item_Kind {
	switch number {
	case 5:
		return .Iron_Helm
	case 6:
		return .Tower_Shield
	}
	return .Chain_Mail
}

NOTES := [3]string {
	"Day 40. The wind is louder up here. Nobody is louder than His Lordship. Not even the wind.",
	"Rules of this camp: wipe yer feet. Leave the kettle. Do not mention His Lordship.",
	"Day 112. From the stairwell I saw a lamp lit, very high up. Somebody up there keeps late hours and has no visitors.",
}

HERMIT_LINES := [?]string {
	"\"Tell the one in the tavern I still have their kettle.\"",
	"\"We climbed together, years back. They went down. I went sideways.\"",
	"\"Up there? I stopped wondering. Wondering is heavy.\"",
	"\"The wind never stops up here. So I did.\"",
}

HERMIT_MARKUP :: 2 // she sells at twice the town's price

fixed_line :: proc(k: Item_Kind) -> string {
	#partial switch k {
	case .Campfire:
		return "A cold campfire. Someone camped here, long ago."
	case .Bedroll:
		return "Someone's bedroll, rolled tight. It stays where it is."
	}
	return "It stays where it is."
}

read_note :: proc(g: ^Game, which: int) {
	say(g, "The note reads: \"", NOTES[clamp(which, 1, len(NOTES)) - 1], "\"")
}

// Lays out a floor's camp (floors 5 to 7) from the floor's seed, after its other things: in a room
// that is neither the arrival room nor the stairs up. The hermit joins floor 6's when tenants are on.
make_camp :: proc(g: ^Game, index: int) {
	f := &g.floors[index]
	if f.number < CAMP_FLOORS[0] || f.number > CAMP_FLOORS[1] || f.room_count < 3 {
		return
	}
	r := Rng{floor_seed(g.seed, f.number) ~ 0xCA4B_F12E}
	room: Room
	for _ in 0 ..< 20 {
		room = f.rooms[1 + rng_int(&r, f.room_count - 1)]
		c := room_centre(room)
		if !(f.up.x >= room.x && f.up.x < room.x + room.w && f.up.y >= room.y && f.up.y < room.y + room.h) && f.cells[c.y][c.x] == .Floor {
			break
		}
	}
	c := room_centre(room)
	put :: proc(g: ^Game, f: ^Floor, index: int, kind: Item_Kind, at: [2]int) -> int {
		if f.cells[at.y][at.x] != .Floor {
			return 0
		}
		id := new_item(g, kind)
		if id != 0 {
			it := &g.items[id]
			it.place, it.floor, it.x, it.y = .Ground, i8(index), i16(at.x), i16(at.y)
		}
		return id
	}
	put(g, f, index, .Campfire, c)
	put(g, f, index, .Bedroll, c + {1, 0})
	if note := put(g, f, index, .Note, c + {0, 1}); note != 0 {
		g.items[note].fuel = i32(f.number - CAMP_FLOORS[0] + 1)
	}
	put(g, f, index, camp_gear(f.number), c + {-1, 0})
	if f.number == 6 && !g.no_tenants && f.cells[c.y - 1][c.x] == .Floor {
		h := new_tenant(g, .Hermit, index, c.x, c.y - 1)
		if h != 0 {
			g.tenants[h].still = true
		}
	}
}

// The hermit's trades: food and torches at twice the town's price, and she buys trophies at their
// worth, as the junk shop does.
hermit_rows :: proc(g: ^Game, rows: ^[MAX_ROWS]Row, n: ^int) {
	for k in ([?]Item_Kind{.Bread, .Cheese, .Jerky, .Torch}) {
		add_row(rows, n, .Buy, int(k), HERMIT_MARKUP * VALUE[k], "Buy ", KIND[k].name)
	}
	for i in 1 ..< MAX_ITEMS {
		if sellable(g, i) && KIND[g.items[i].kind].trophy {
			add_row(rows, n, .Sell, i, -junk_price(g, i), "Sell ", item_name(g, i))
		}
	}
	add_row(rows, n, .Talk, 0, 0, "Talk to the hermit")
}
