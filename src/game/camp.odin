package game

// Earlier climbers (slice 2 step 12; DESIGN.md beat 3, "Every floor holds traces of people who
// believed and climbed"). Floors 5 to 7 each have a camp: a cold fire and a bedroll that stay put,
// a note that hints at the top without saying, and a piece of heavy gear worth taking and costly to
// carry. On floor 6 a climber who stopped there still lives in her camp: the hermit, who trades.
// Floors 9 to 11 have camps too (slice 3 step 19), fewer climbers' and further apart; on floor 10
// the cartographer lives in hers and sells maps of the floors you have reached.

CAMP_FLOORS :: [2]int{5, 7}
DEEP_CAMP_FLOORS :: [2]int{9, 11}
CARTOGRAPHER_FLOOR :: 10
MAP_PRICE :: 15

is_camp_floor :: proc(number: int) -> bool {
	return (number >= CAMP_FLOORS[0] && number <= CAMP_FLOORS[1]) || (number >= DEEP_CAMP_FLOORS[0] && number <= DEEP_CAMP_FLOORS[1])
}

// Which note a camp holds (1 to 6), by floor number.
camp_note :: proc(number: int) -> int {
	if number >= DEEP_CAMP_FLOORS[0] {
		return number - DEEP_CAMP_FLOORS[0] + 4
	}
	return number - CAMP_FLOORS[0] + 1
}

// The camp's piece of gear, by floor number.
camp_gear :: proc(number: int) -> Item_Kind {
	switch number {
	case 5:
		return .Iron_Helm
	case 6:
		return .Tower_Shield
	case 7:
		return .Chain_Mail
	case 9:
		return .War_Hammer
	case 10:
		return .Pack_Holding
	}
	return .Scale_Mail
}

NOTES := [6]string {
	"Day 40. The wind is louder up here. Nobody is louder than His Lordship. Not even the wind.",
	"Rules of this camp: wipe yer feet. Leave the kettle. Do not mention His Lordship.",
	"Day 112. From the stairwell I saw a lamp lit, very high up. Somebody up there keeps late hours and has no visitors.",
	"Day 160. Fewer camps up here. Fewer climbers, or fewer who stop to cook.",
	"Ogres on this floor. The big one upstairs is an ogre too, they say, only taller. I did not go up to measure.",
	"Someone on fifteen calls himself undefeated. I did not ask him to prove it.",
}

CARTOGRAPHER_LINES := [?]string {
	"\"I mapped up to ten. Ten was enough.\"",
	"\"Floor fifteen? I hear it is very tidy.\"",
	"\"The wind redraws nothing. The tenants move the furniture.\"",
}

HERMIT_LINES := [?]string {
	"\"Tell the one in the tavern I still have their kettle.\"",
	"\"We climbed together, years back. They went down. I went sideways.\"",
	"\"Up there? I stopped wondering. Wondering is heavy.\"",
	"\"The wind never stops up here. So I did.\"",
}

MENTOR_KETTLE :: "\"She kept the kettle? Of course she did.\"" // the mentor, once you have talked to the hermit

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

// Lays out a floor's camp (floors 5 to 7 and 9 to 11) from the floor's seed, after its other things:
// in a room that is neither the arrival room nor the stairs up. The hermit joins floor 6's and the
// cartographer floor 10's when tenants are on.
make_camp :: proc(g: ^Game, index: int) {
	f := &g.floors[index]
	if !is_camp_floor(f.number) || f.room_count < 3 {
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
		g.items[note].fuel = i32(camp_note(f.number))
	}
	put(g, f, index, camp_gear(f.number), c + {-1, 0})
	keeper := Tenant_Kind.None
	switch f.number {
	case 6:
		keeper = .Hermit
	case CARTOGRAPHER_FLOOR:
		keeper = .Cartographer
	}
	if keeper != .None && !g.no_tenants && f.cells[c.y - 1][c.x] == .Floor {
		h := new_tenant(g, keeper, index, c.x, c.y - 1)
		if h != 0 {
			g.tenants[h].still = true
		}
	}
}

// The cartographer's maps: one for each floor you have reached and not yet had mapped.
cartographer_rows :: proc(g: ^Game, rows: ^[MAX_ROWS]Row, n: ^int) {
	buf: [12]u8
	for i in 0 ..< FLOOR_COUNT {
		f := &g.floors[i]
		if f.made && f.number >= 1 && f.number <= g.deepest && i not_in g.mapped {
			add_row(rows, n, .Map, i, MAP_PRICE, "Map of floor ", itoa(buf[:], f.number))
		}
	}
	add_row(rows, n, .Talk, 0, 0, "Talk to the cartographer")
}

// A bought map: the floor's whole automap is filled in, walls and all.
map_floor :: proc(g: ^Game, index: int) {
	f := &g.floors[index]
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if f.cells[y][x] != .Wall {
				for dy in -1 ..= 1 {
					for dx in -1 ..= 1 {
						if nx, ny := x + dx, y + dy; nx >= 0 && ny >= 0 && nx < FLOOR_W && ny < FLOOR_H {
							f.seen[ny][nx] = true
						}
					}
				}
			}
		}
	}
	g.mapped += {index}
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
