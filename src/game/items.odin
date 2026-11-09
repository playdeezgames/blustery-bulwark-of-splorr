package game

// Things you carry (slice 1 step 3; DESIGN.md "Inventory: faithful to Castle of the Winds"): every
// item has weight (grams) and bulk (cubic centimetres); it lies on the ground, is worn in a slot of
// the paper doll, or sits inside a container (packs and sacks nest, a belt has a few small slots, a
// purse holds only coins). What is worn, and everything inside it, counts toward the load.

Item_Kind :: enum u8 {
	None,
	Jools,
	Torch,
	Dagger,
	Short_Sword,
	Club,
	Padded_Armour,
	Leather_Cap,
	Buckler,
	Boots,
	Bread,
	Pack,
	Sack,
	Belt,
	Purse,
}

Slot :: enum u8 {
	None,
	Weapon,
	Shield,
	Light,
	Helmet,
	Armour,
	Cloak,
	Bracers,
	Gauntlets,
	Boots,
	Ring_Left,
	Ring_Right,
	Amulet,
	Belt,
	Pack,
	Purse,
}

// Short labels for the paper doll, five characters each.
SLOT_LABEL := [Slot]string {
	.None       = "",
	.Weapon     = "Hand ",
	.Shield     = "Off  ",
	.Light      = "Light",
	.Helmet     = "Head ",
	.Armour     = "Body ",
	.Cloak      = "Cloak",
	.Bracers    = "Wrist",
	.Gauntlets  = "Hands",
	.Boots      = "Feet ",
	.Ring_Left  = "Ring ",
	.Ring_Right = "Ring ",
	.Amulet     = "Neck ",
	.Belt       = "Belt ",
	.Pack       = "Back ",
	.Purse      = "Purse",
}

Kind_Info :: struct {
	name:       string,
	gfx:        Gfx,
	color:      u8,
	weight:     int, // grams (per coin for Jools)
	bulk:       int, // cubic centimetres (per coin for Jools)
	slot:       Slot, // where it is worn, if anywhere
	cap_weight: int, // a container's limits (0: not a container)
	cap_bulk:   int,
	belt_slots: int, // a belt holds this many small things
	coins_only: bool,
	fuel:       int, // turns of light in a fresh one
}

BELT_SLOT_BULK :: 1000 // the biggest thing a belt slot holds
CARRY_LIMIT :: 20000 // grams; Strength will change it when attributes arrive
ANCHOR_PERCENT :: 60 // a load this heavy keeps a gust from moving you, and slows you
LIGHT_ITEM :: 300 // grams; things this light on the ground are blown along by gusts

KIND := [Item_Kind]Kind_Info {
	.None          = {},
	.Jools         = {name = "Jools", gfx = .Jools, color = COLOR_YELLOW, weight = 10, bulk = 2},
	.Torch         = {name = "Torch", gfx = .Torch, color = COLOR_ORANGE, weight = 500, bulk = 600, slot = .Light, fuel = TORCH_TURNS},
	.Dagger        = {name = "Dagger", gfx = .Dagger, color = COLOR_LIGHT, weight = 400, bulk = 300, slot = .Weapon},
	.Short_Sword   = {name = "Short sword", gfx = .Short_Sword, color = COLOR_LIGHT, weight = 1200, bulk = 1500, slot = .Weapon},
	.Club          = {name = "Club", gfx = .Club, color = COLOR_BROWN, weight = 1500, bulk = 1800, slot = .Weapon},
	.Padded_Armour = {name = "Padded armour", gfx = .Padded_Armour, color = COLOR_BROWN, weight = 4000, bulk = 8000, slot = .Armour},
	.Leather_Cap   = {name = "Leather cap", gfx = .Leather_Cap, color = COLOR_BROWN, weight = 500, bulk = 1500, slot = .Helmet},
	.Buckler       = {name = "Buckler", gfx = .Buckler, color = COLOR_BROWN, weight = 1500, bulk = 3000, slot = .Shield},
	.Boots         = {name = "Boots", gfx = .Boots, color = COLOR_BROWN, weight = 1000, bulk = 2500, slot = .Boots},
	.Bread         = {name = "Bread", gfx = .Bread, color = COLOR_BROWN, weight = 300, bulk = 800},
	.Pack          = {name = "Pack", gfx = .Pack, color = COLOR_BROWN, weight = 1000, bulk = 5000, slot = .Pack, cap_weight = 12000, cap_bulk = 25000},
	.Sack          = {name = "Sack", gfx = .Sack, color = COLOR_BROWN, weight = 200, bulk = 500, cap_weight = 5000, cap_bulk = 15000},
	.Belt          = {name = "Belt", gfx = .Belt, color = COLOR_BROWN, weight = 300, bulk = 400, slot = .Belt, belt_slots = 4},
	.Purse         = {name = "Purse", gfx = .Purse, color = COLOR_BROWN, weight = 50, bulk = 200, slot = .Purse, cap_weight = 6000, cap_bulk = 1200, coins_only = true},
}

Place :: enum u8 {
	Nowhere, // a free entry in the pool
	Ground,
	Worn,
	Inside,
}

Item :: struct {
	kind:   Item_Kind,
	place:  Place,
	floor:  i8, // Ground: floor index
	x, y:   i16, // Ground: cell
	slot:   Slot, // Worn
	parent: i16, // Inside: the container's item id
	count:  i32, // Jools: how many; 1 for anything else
	fuel:   i32, // Torch: turns of light left
}

MAX_ITEMS :: 256 // id 0 is never used, so 0 means "no item"

is_container :: proc(k: Item_Kind) -> bool {
	return KIND[k].cap_weight > 0 || KIND[k].belt_slots > 0
}

new_item :: proc(g: ^Game, kind: Item_Kind, count := 1) -> int {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Nowhere {
			g.items[i] = Item{kind = kind, count = i32(count), fuel = i32(KIND[kind].fuel)}
			return i
		}
	}
	return 0 // full: the caller gets nothing
}

free_item :: proc(g: ^Game, id: int) {
	// Anything inside goes with it (only called for burnt torches and merged coins, which hold nothing).
	g.items[id] = {}
}

// The worn item in a slot, or 0.
worn :: proc(g: ^Game, s: Slot) -> int {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Worn && g.items[i].slot == s {
			return i
		}
	}
	return 0
}

// Weight and bulk of an item with everything inside it.
weight_of :: proc(g: ^Game, id: int) -> int {
	it := &g.items[id]
	w := KIND[it.kind].weight * int(it.count)
	if is_container(it.kind) {
		for i in 1 ..< MAX_ITEMS {
			if g.items[i].place == .Inside && int(g.items[i].parent) == id {
				w += weight_of(g, i)
			}
		}
	}
	return w
}

bulk_of :: proc(g: ^Game, id: int) -> int {
	it := &g.items[id]
	b := KIND[it.kind].bulk * int(it.count)
	if is_container(it.kind) {
		b += contents_bulk(g, id)
	}
	return b
}

contents_weight :: proc(g: ^Game, id: int) -> int {
	return weight_of(g, id) - KIND[g.items[id].kind].weight * int(g.items[id].count)
}

contents_bulk :: proc(g: ^Game, id: int) -> int {
	b := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Inside && int(g.items[i].parent) == id {
			b += bulk_of(g, i)
		}
	}
	return b
}

contents_count :: proc(g: ^Game, id: int) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Inside && int(g.items[i].parent) == id {
			n += 1
		}
	}
	return n
}

// The load: everything worn, with what is inside it.
carried_weight :: proc(g: ^Game) -> int {
	w := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Worn {
			w += weight_of(g, i)
		}
	}
	return w
}

anchored :: proc(g: ^Game) -> bool {
	return carried_weight(g) * 100 >= CARRY_LIMIT * ANCHOR_PERCENT
}

overloaded :: proc(g: ^Game) -> bool {
	return carried_weight(g) > CARRY_LIMIT
}

// True when `id` is `container` or holds it somewhere inside (a bag cannot go into itself).
holds :: proc(g: ^Game, id, container: int) -> bool {
	for c := container; c != 0; {
		if c == id {
			return true
		}
		it := &g.items[c]
		if it.place != .Inside {
			return false
		}
		c = int(it.parent)
	}
	return false
}

// True when the item is carried: worn, or inside something carried.
is_carried :: proc(g: ^Game, id: int) -> bool {
	for c := id; c != 0; {
		it := &g.items[c]
		switch it.place {
		case .Worn:
			return true
		case .Inside:
			c = int(it.parent)
		case .Ground, .Nowhere:
			return false
		}
	}
	return false
}

// Whether `id` may go into `container`; the reason when not.
can_put_in :: proc(g: ^Game, id, container: int) -> (ok: bool, why: string) {
	k := g.items[id].kind
	ck := KIND[g.items[container].kind]
	if !is_container(g.items[container].kind) {
		return false, "That holds nothing."
	}
	if holds(g, id, container) {
		return false, "It will not go inside itself."
	}
	if ck.coins_only && k != .Jools {
		return false, "A purse holds only coins."
	}
	if ck.belt_slots > 0 {
		if bulk_of(g, id) > BELT_SLOT_BULK {
			return false, "Too bulky for a belt."
		}
		if contents_count(g, container) >= ck.belt_slots {
			return false, "The belt is full."
		}
		return true, ""
	}
	if contents_weight(g, container) + weight_of(g, id) > ck.cap_weight {
		return false, "Too heavy for that."
	}
	if contents_bulk(g, container) + bulk_of(g, id) > ck.cap_bulk {
		return false, "There is no room in that."
	}
	return true, ""
}

// Leaves the item's old place (putting out a torch that leaves the light slot).
unplace :: proc(g: ^Game, id: int) {
	it := &g.items[id]
	if it.place == .Worn && it.slot == .Light {
		g.lit = false
	}
}

put_in :: proc(g: ^Game, id, container: int) -> bool {
	ok, why := can_put_in(g, id, container)
	if !ok {
		say(g, why)
		return false
	}
	unplace(g, id)
	// Coins join coins already there.
	if g.items[id].kind == .Jools {
		for i in 1 ..< MAX_ITEMS {
			if i != id && g.items[i].kind == .Jools && g.items[i].place == .Inside && int(g.items[i].parent) == container {
				g.items[i].count += g.items[id].count
				free_item(g, id)
				return true
			}
		}
	}
	it := &g.items[id]
	it.place, it.parent = .Inside, i16(container)
	return true
}

// Whether `id` can be worn in slot `s` (rings fit either ring slot).
fits_slot :: proc(k: Item_Kind, s: Slot) -> bool {
	ks := KIND[k].slot
	return ks == s || (ks == .Ring_Left && s == .Ring_Right)
}

wear :: proc(g: ^Game, id: int, s: Slot) -> bool {
	if !fits_slot(g.items[id].kind, s) {
		say(g, "That is not worn there.")
		return false
	}
	other := worn(g, s)
	if other == id {
		return true
	}
	if other != 0 {
		say(g, "Take off the ", item_name(g, other), " first.")
		return false
	}
	unplace(g, id)
	it := &g.items[id]
	it.place, it.slot = .Worn, s
	if s == .Light {
		say(g, "Confirm to light it.")
	}
	return true
}

drop :: proc(g: ^Game, id: int) {
	unplace(g, id)
	it := &g.items[id]
	it.place, it.floor, it.x, it.y = .Ground, i8(g.current), i16(g.x), i16(g.y)
	// Coins join a pile already there.
	if it.kind == .Jools {
		for i in 1 ..< MAX_ITEMS {
			o := &g.items[i]
			if i != id && o.kind == .Jools && o.place == .Ground && int(o.floor) == g.current && int(o.x) == g.x && int(o.y) == g.y {
				o.count += it.count
				free_item(g, id)
				return
			}
		}
	}
}

// The name shown for an item: "25 Jools", "Torch (212)", "Pack".
item_name :: proc(g: ^Game, id: int) -> string {
	@(static) buf: [32]u8
	it := &g.items[id]
	n := 0
	add :: proc(buf: []u8, n: ^int, s: string) {
		for i in 0 ..< len(s) {
			if n^ < len(buf) {
				buf[n^] = s[i]
				n^ += 1
			}
		}
	}
	num: [12]u8
	#partial switch it.kind {
	case .Jools:
		add(buf[:], &n, itoa(num[:], int(it.count)))
		add(buf[:], &n, " Jools")
	case .Torch:
		add(buf[:], &n, "Torch (")
		add(buf[:], &n, itoa(num[:], int(it.fuel)))
		add(buf[:], &n, ")")
	case:
		add(buf[:], &n, KIND[it.kind].name)
	}
	return string(buf[:n])
}

// The topmost item on the ground at a cell of the current floor, or 0.
ground_item_at :: proc(g: ^Game, x, y: int) -> int {
	for i := MAX_ITEMS - 1; i >= 1; i -= 1 {
		it := &g.items[i]
		if it.place == .Ground && int(it.floor) == g.current && int(it.x) == x && int(it.y) == y {
			return i
		}
	}
	return 0
}

// Picks up the top item underfoot into the best place: coins to the purse, small things to the
// belt, the rest to the pack (or anything worn that holds it). False when nothing is here.
get_here :: proc(g: ^Game) -> bool {
	id := ground_item_at(g, g.x, g.y)
	if id == 0 {
		return false
	}
	name_buf: [32]u8
	n := copy(name_buf[:], item_name(g, id))
	name := string(name_buf[:n])
	order := [?]Slot{.Purse, .Belt, .Pack}
	for s in order {
		c := worn(g, s)
		if c == 0 {
			continue
		}
		if ok, _ := can_put_in(g, id, c); ok {
			put_in(g, id, c)
			say(g, "You pick up ", name, ".")
			return true
		}
	}
	// A wearable thing goes on if its slot is free.
	if s := KIND[g.items[id].kind].slot; s != .None && worn(g, s) == 0 {
		wear(g, id, s)
		say(g, "You pick up ", name, " and wear it.")
		return true
	}
	say(g, "No room to carry ", name, ".")
	return true
}

// A few things lying about on a floor, made once from the floor's seed when it is first entered.
populate_floor :: proc(g: ^Game, index: int) {
	f := &g.floors[index]
	r := Rng{floor_seed(g.seed, f.number) ~ 0x17E5_0F_F100}
	place :: proc(g: ^Game, f: ^Floor, r: ^Rng, index: int, kind: Item_Kind, count: int) {
		for _ in 0 ..< 100 {
			room := f.rooms[rng_int(r, f.room_count)]
			x, y := room.x + rng_int(r, room.w), room.y + rng_int(r, room.h)
			if f.cells[y][x] != .Floor {
				continue
			}
			id := new_item(g, kind, count)
			if id == 0 {
				return
			}
			it := &g.items[id]
			it.place, it.floor, it.x, it.y = .Ground, i8(index), i16(x), i16(y)
			return
		}
	}
	for _ in 0 ..< 2 + f.number {
		place(g, f, &r, index, .Jools, rng_range(&r, 3, 10 * f.number))
	}
	place(g, f, &r, index, .Torch, 1)
	place(g, f, &r, index, .Bread, 1)
	finds := [?]Item_Kind{.Short_Sword, .Club, .Leather_Cap, .Buckler, .Sack}
	for _ in 0 ..< 2 {
		place(g, f, &r, index, finds[rng_int(&r, len(finds))], 1)
	}
}

// The kit a new character starts with.
give_starting_kit :: proc(g: ^Game) {
	put_on :: proc(g: ^Game, kind: Item_Kind, s: Slot) -> int {
		id := new_item(g, kind)
		g.items[id].place, g.items[id].slot = .Worn, s
		return id
	}
	put_on(g, .Dagger, .Weapon)
	put_on(g, .Padded_Armour, .Armour)
	put_on(g, .Boots, .Boots)
	put_on(g, .Torch, .Light)
	pack := put_on(g, .Pack, .Pack)
	belt := put_on(g, .Belt, .Belt)
	purse := put_on(g, .Purse, .Purse)
	for _ in 0 ..< 2 {
		put_in(g, new_item(g, .Bread), pack)
		put_in(g, new_item(g, .Torch), belt)
	}
	put_in(g, new_item(g, .Jools, 25), purse)
	g.lit = true
}

// A gust carries light things on the ground one cell downwind (each moves once per gust).
blow_items :: proc(g: ^Game) {
	f := floor_of(g)
	d := wind_blow(f)
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place != .Ground || int(it.floor) != g.current || weight_of(g, i) > LIGHT_ITEM {
			continue
		}
		nx, ny := int(it.x) + d.x, int(it.y) + d.y
		if passable(floor_cell(f, nx, ny)) {
			it.x, it.y = i16(nx), i16(ny)
		}
	}
}

// Jools carried anywhere about yer person.
carried_jools :: proc(g: ^Game) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Jools && is_carried(g, i) {
			n += int(g.items[i].count)
		}
	}
	return n
}
