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
	// Trophies (step 4): sold in town.
	Rat_Tail,
	Bat_Wing,
	Spider_Leg,
	Beetle_Shell,
	Kobold_Ear,
	// Food, potions, scrolls, jewellery and a book (step 6). Potions, scrolls, rings and amulets
	// go by their look until identified.
	Cheese,
	Jerky,
	Potion_Healing,
	Potion_Mana,
	Potion_Blight,
	Potion_Sight,
	Scroll_Return,
	Scroll_Identify,
	Scroll_Uncurse,
	Scroll_Decree,
	Ring_Guard,
	Ring_Draught,
	Amulet_Vigour,
	Amulet_Hop,
	Spellbook,
	// Sold in town (step 7).
	Wind_Charm,
	// Floor 4 (step 8).
	Skull,
	Old_Bones,
	Key,
}

// Kinds that go by a look until identified; the looks are shuffled per character.
Group :: enum u8 {
	None,
	Potion,
	Scroll,
	Ring,
	Amulet,
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
	dmin, dmax: int, // a weapon's damage
	armour:     int, // how much a worn piece turns blows aside
	durability: int, // uses before it breaks (0: never wears out)
	trophy:     bool, // a monster's leavings, picked up into the pack before the belt
	food:       int, // hunger an eaten one takes away
	group:      Group,
	cursed:     bool, // will not come off once worn, until uncursed
}

BELT_SLOT_BULK :: 1000 // the biggest thing a belt slot holds
CARRY_PER_STRENGTH :: 2500 // grams of load limit per point of Strength (10 Strength carries 25 kg; 2 kg until November 12, 2026)
ANCHOR_PERCENT :: 75 // a load this heavy keeps a gust from moving you, and slows you
LIGHT_ITEM :: 300 // grams; things this light on the ground are blown along by gusts

KIND := [Item_Kind]Kind_Info {
	.None          = {},
	.Jools         = {name = "Jools", gfx = .Jools, color = COLOR_YELLOW, weight = 50, bulk = 2},
	.Torch         = {name = "Torch", gfx = .Torch, color = COLOR_ORANGE, weight = 500, bulk = 600, slot = .Light, fuel = TORCH_TURNS},
	.Dagger        = {name = "Dagger", gfx = .Dagger, color = COLOR_LIGHT, weight = 400, bulk = 300, slot = .Weapon, dmin = 1, dmax = 4, durability = 30},
	.Short_Sword   = {name = "Short sword", gfx = .Short_Sword, color = COLOR_LIGHT, weight = 1200, bulk = 1500, slot = .Weapon, dmin = 2, dmax = 6, durability = 50},
	.Club          = {name = "Club", gfx = .Club, color = COLOR_BROWN, weight = 1500, bulk = 1800, slot = .Weapon, dmin = 2, dmax = 7, durability = 40},
	.Padded_Armour = {name = "Padded armour", gfx = .Padded_Armour, color = COLOR_BROWN, weight = 4000, bulk = 8000, slot = .Armour, armour = 2, durability = 40},
	.Leather_Cap   = {name = "Leather cap", gfx = .Leather_Cap, color = COLOR_BROWN, weight = 500, bulk = 1500, slot = .Helmet, armour = 1, durability = 30},
	.Buckler       = {name = "Buckler", gfx = .Buckler, color = COLOR_BROWN, weight = 1500, bulk = 3000, slot = .Shield, armour = 1, durability = 40},
	.Boots         = {name = "Boots", gfx = .Boots, color = COLOR_BROWN, weight = 1000, bulk = 2500, slot = .Boots, armour = 1, durability = 50},
	.Bread         = {name = "Bread", gfx = .Bread, color = COLOR_BROWN, weight = 300, bulk = 800, food = 400},
	.Pack          = {name = "Pack", gfx = .Pack, color = COLOR_BROWN, weight = 1000, bulk = 5000, slot = .Pack, cap_weight = 12000, cap_bulk = 25000},
	.Sack          = {name = "Sack", gfx = .Sack, color = COLOR_BROWN, weight = 200, bulk = 500, cap_weight = 5000, cap_bulk = 15000},
	.Belt          = {name = "Belt", gfx = .Belt, color = COLOR_BROWN, weight = 300, bulk = 400, slot = .Belt, belt_slots = 4},
	.Purse         = {name = "Purse", gfx = .Purse, color = COLOR_BROWN, weight = 50, bulk = 200, slot = .Purse, cap_weight = 6000, cap_bulk = 1200, coins_only = true},
	.Rat_Tail      = {name = "Rat tail", gfx = .Rat_Tail, color = COLOR_LIGHT, weight = 20, bulk = 30, trophy = true},
	.Bat_Wing      = {name = "Bat wing", gfx = .Bat_Wing, color = COLOR_MID, weight = 15, bulk = 40, trophy = true},
	.Spider_Leg    = {name = "Spider leg", gfx = .Spider_Leg, color = COLOR_RED, weight = 10, bulk = 20, trophy = true},
	.Beetle_Shell  = {name = "Beetle shell", gfx = .Beetle_Shell, color = COLOR_ORANGE, weight = 150, bulk = 200, trophy = true},
	.Kobold_Ear    = {name = "Kobold ear", gfx = .Kobold_Ear, color = 5, weight = 10, bulk = 15, trophy = true},
	.Cheese          = {name = "Cheese", gfx = .Cheese, color = COLOR_YELLOW, weight = 200, bulk = 300, food = 250},
	.Jerky           = {name = "Jerky", gfx = .Jerky, color = COLOR_RED, weight = 100, bulk = 150, food = 300},
	.Potion_Healing  = {name = "Healing potion", gfx = .Potion, weight = 250, bulk = 250, group = .Potion},
	.Potion_Mana     = {name = "Mana potion", gfx = .Potion, weight = 250, bulk = 250, group = .Potion},
	.Potion_Blight   = {name = "Blight potion", gfx = .Potion, weight = 250, bulk = 250, group = .Potion},
	.Potion_Sight    = {name = "Sight potion", gfx = .Potion, weight = 250, bulk = 250, group = .Potion},
	.Scroll_Return   = {name = "Return scroll", gfx = .Scroll, color = COLOR_LIGHT, weight = 30, bulk = 100, group = .Scroll},
	.Scroll_Identify = {name = "Identify scroll", gfx = .Scroll, color = COLOR_LIGHT, weight = 30, bulk = 100, group = .Scroll},
	.Scroll_Uncurse  = {name = "Uncurse scroll", gfx = .Scroll, color = COLOR_LIGHT, weight = 30, bulk = 100, group = .Scroll},
	.Scroll_Decree   = {name = "Decree scroll", gfx = .Scroll, color = COLOR_LIGHT, weight = 30, bulk = 100, group = .Scroll},
	.Ring_Guard      = {name = "Guard ring", gfx = .Ring, color = COLOR_YELLOW, weight = 10, bulk = 5, slot = .Ring_Left, armour = 2, group = .Ring},
	.Ring_Draught    = {name = "Draught ring", gfx = .Ring, color = COLOR_YELLOW, weight = 10, bulk = 5, slot = .Ring_Left, group = .Ring, cursed = true},
	.Amulet_Vigour   = {name = "Vigour amulet", gfx = .Amulet, color = COLOR_YELLOW, weight = 30, bulk = 20, slot = .Amulet, group = .Amulet},
	.Amulet_Hop      = {name = "Hop amulet", gfx = .Amulet, color = COLOR_YELLOW, weight = 30, bulk = 20, slot = .Amulet, group = .Amulet, cursed = true},
	.Spellbook       = {name = "Spellbook", gfx = .Spellbook, color = 9, weight = 800, bulk = 1200},
	.Wind_Charm      = {name = "Wind charm", gfx = .Amulet, color = COLOR_CYAN, weight = 20, bulk = 20, slot = .Amulet},
	.Skull           = {name = "Skull", gfx = .Skull, color = COLOR_WHITE, weight = 600, bulk = 1500, trophy = true},
	.Old_Bones       = {name = "Old bones", gfx = .Bone_Pile, color = COLOR_LIGHT, weight = 1500, bulk = 3000},
	.Key             = {name = "Key to floor 5", gfx = .Key, color = COLOR_YELLOW, weight = 50, bulk = 30},
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
	dur:    i16, // Weapons and armour: uses left before it breaks
	pile:   bool, // dropped when you died; lost if you die again before picking it up
	cursed: bool, // from its kind; an Uncurse scroll clears it
}

MAX_ITEMS :: 256 // id 0 is never used, so 0 means "no item"

is_container :: proc(k: Item_Kind) -> bool {
	return KIND[k].cap_weight > 0 || KIND[k].belt_slots > 0
}

new_item :: proc(g: ^Game, kind: Item_Kind, count := 1) -> int {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Nowhere {
			g.items[i] = Item{kind = kind, count = i32(count), fuel = i32(KIND[kind].fuel), dur = i16(KIND[kind].durability), cursed = KIND[kind].cursed}
			return i
		}
	}
	return 0 // full: the caller gets nothing
}

free_item :: proc(g: ^Game, id: int) {
	// Anything inside goes with it.
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Inside && int(g.items[i].parent) == id {
			free_item(g, i)
		}
	}
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

carry_limit :: proc(g: ^Game) -> int {
	return CARRY_PER_STRENGTH * g.attr[.Strength]
}

// A load heavy enough to hold you against gusts (and slow you).
load_anchors :: proc(g: ^Game) -> bool {
	return carried_weight(g) * 100 >= carry_limit(g) * ANCHOR_PERCENT
}

// Held against the next gust: by yer load, or by the Anchor spell (which does not slow you).
anchored :: proc(g: ^Game) -> bool {
	return load_anchors(g) || g.anchor_spell
}

overloaded :: proc(g: ^Game) -> bool {
	return carried_weight(g) > carry_limit(g)
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
	it.pile = false // handled again: no longer part of a death pile
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
		say(g, "Enter/OK to light it.")
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
		if KIND[it.kind].group != .None && it.kind not_in g.ident {
			add(buf[:], &n, look_name(g, it.kind))
		} else {
			add(buf[:], &n, KIND[it.kind].name)
		}
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
	if !stow(g, id) {
		say(g, "No room to carry ", name, ".")
	} else if g.items[id].kind == .Key && !g.slice_done {
		say(g, "You pick up the ", name, ".")
		g.slice_done = true
		g.mode = .Notice
	} else if g.items[id].place == .Worn {
		say(g, "You pick up ", name, " and wear it.")
	} else {
		say(g, "You pick up ", name, ".")
	}
	return true
}

// Puts a thing where it is best carried: coins to the purse, small things to the belt, the rest
// to the pack (trophies to the pack before the belt); a wearable thing goes on if nothing holds it
// and its slot is free. False when there is no room anywhere.
stow :: proc(g: ^Game, id: int) -> bool {
	order := [?]Slot{.Purse, .Belt, .Pack}
	if KIND[g.items[id].kind].trophy {
		order = {.Purse, .Pack, .Belt} // keep belt slots for things you reach for
	}
	for s in order {
		c := worn(g, s)
		if c == 0 {
			continue
		}
		if ok, _ := can_put_in(g, id, c); ok {
			put_in(g, id, c)
			return true
		}
	}
	if s := KIND[g.items[id].kind].slot; s != .None && worn(g, s) == 0 {
		wear(g, id, s)
		return true
	}
	return false
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
	// Step 6: more food, potions, a scroll, a piece of jewellery, and a spellbook on floor 3.
	place(g, f, &r, index, rng_int(&r, 2) == 0 ? .Cheese : .Jerky, 1)
	for _ in 0 ..< 2 {
		place(g, f, &r, index, Item_Kind(int(Item_Kind.Potion_Healing) + rng_int(&r, 4)), 1)
	}
	place(g, f, &r, index, Item_Kind(int(Item_Kind.Scroll_Return) + rng_int(&r, 4)), 1)
	place(g, f, &r, index, Item_Kind(int(Item_Kind.Ring_Guard) + rng_int(&r, 4)), 1)
	if f.number == 3 {
		place(g, f, &r, index, .Spellbook, 1)
	}
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
