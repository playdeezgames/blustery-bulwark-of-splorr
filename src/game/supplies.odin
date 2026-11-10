package game

// Hunger and identification (slice 1 step 6; DESIGN.md "Hunger: a slow clock", "Identification
// and curses: all of it"). Hunger rises a point a turn; food takes it down. Potions, scrolls, rings
// and amulets go by a look (shuffled per character) until identified: by using one, by the Identify
// spell or scroll, or (step 7) by the sage. A cursed ring or amulet will not come off once worn
// until an Uncurse scroll (or, in step 7, the temple) lifts it, and it now and then casts a bad
// spell on you.

// Tuning (PLAN.md step 6; to review).
HUNGER_PECKISH :: 800
HUNGER_HUNGRY :: 900
HUNGER_STARVING :: 1000
STARVE_PERIOD :: 10 // starving costs a point of health this often
DRAUGHT_CHANCE :: 25 // one turn in this many, a Draught ring blows out yer torch
HOP_CHANCE :: 30 // one turn in this many, a Hop amulet hops you
VIGOUR_HEAL :: 2 // a Vigour amulet heals this many times as fast
SIGHT_TURNS :: 60

Look :: struct {
	name:  string,
	color: u8,
}

POTION_LOOKS := [4]Look{{"Murky potion", 6}, {"Fizzy potion", 10}, {"Amber potion", COLOR_ORANGE}, {"Ruddy potion", COLOR_RED}}
SCROLL_LOOKS := [4]Look{{"WHEREAS scroll", COLOR_LIGHT}, {"HEREBY scroll", COLOR_LIGHT}, {"NOTICE scroll", COLOR_LIGHT}, {"DECREE scroll", COLOR_LIGHT}}
RING_LOOKS := [2]Look{{"Brass ring", COLOR_YELLOW}, {"Bone ring", COLOR_LIGHT}}
AMULET_LOOKS := [2]Look{{"Tin amulet", COLOR_MID}, {"Glass amulet", 10}}

// Which look each kind wears for this character: a shuffle within each group, from the seed.
shuffle_looks :: proc(g: ^Game) {
	r := Rng{g.seed ~ 0x100C_5_0F_7E1E}
	for group in Group {
		if group == .None {
			continue
		}
		kinds: [8]Item_Kind
		n := 0
		for k in Item_Kind {
			if KIND[k].group == group {
				kinds[n] = k
				n += 1
			}
		}
		order := [8]u8{0, 1, 2, 3, 4, 5, 6, 7}
		for i := n - 1; i > 0; i -= 1 {
			j := rng_int(&r, i + 1)
			order[i], order[j] = order[j], order[i]
		}
		for i in 0 ..< n {
			g.look[kinds[i]] = order[i]
		}
	}
}

kind_look :: proc(g: ^Game, k: Item_Kind) -> Look {
	i := int(g.look[k])
	#partial switch KIND[k].group {
	case .Potion:
		return POTION_LOOKS[i]
	case .Scroll:
		return SCROLL_LOOKS[i]
	case .Ring:
		return RING_LOOKS[i]
	case .Amulet:
		return AMULET_LOOKS[i]
	}
	return {KIND[k].name, KIND[k].color}
}

look_name :: proc(g: ^Game, k: Item_Kind) -> string {
	return kind_look(g, k).name
}

// The colour an item is drawn in (a potion keeps its look's colour once known).
item_color :: proc(g: ^Game, id: int) -> u8 {
	k := g.items[id].kind
	if KIND[k].group != .None {
		return kind_look(g, k).color
	}
	return KIND[k].color
}

// Learns what a kind is; says so the first time.
identify_kind :: proc(g: ^Game, k: Item_Kind) {
	if KIND[k].group == .None || k in g.ident {
		return
	}
	g.ident += {k}
	say(g, "(", look_name(g, k), " is a ", KIND[k].name, ".)")
}

hunger_word :: proc(g: ^Game) -> (string, u8) {
	switch {
	case g.hunger >= HUNGER_STARVING:
		return "Starving", COLOR_RED
	case g.hunger >= HUNGER_HUNGRY:
		return "Hungry", COLOR_ORANGE
	case g.hunger >= HUNGER_PECKISH:
		return "Peckish", COLOR_YELLOW
	}
	return "Fed", COLOR_LIGHT
}

// Once a turn (end_turn): hunger, and what worn jewellery does.
supplies_turn :: proc(g: ^Game) {
	if g.hunger < HUNGER_STARVING {
		g.hunger += 1
		switch g.hunger {
		case HUNGER_PECKISH:
			say(g, "You are peckish.")
		case HUNGER_HUNGRY:
			say(g, "You are hungry. Eat something.")
		case HUNGER_STARVING:
			say(g, "You are starving!")
		}
	} else if g.turn % STARVE_PERIOD == 0 {
		hurt(g, 1, "hunger")
		if g.mode == .Dead {
			return
		}
	}
	if ring := worn_kind(g, .Ring_Draught); ring != 0 && g.lit && rng_int(&g.rng, DRAUGHT_CHANCE) == 0 {
		g.lit = false
		say(g, "A draught from yer ", item_name(g, ring), " blows out yer torch.")
		identify_kind(g, .Ring_Draught)
		refresh_view(g)
	}
	if amulet := worn_kind(g, .Amulet_Hop); amulet != 0 && rng_int(&g.rng, HOP_CHANCE) == 0 {
		say(g, "Yer ", item_name(g, amulet), " twitches.")
		identify_kind(g, .Amulet_Hop)
		hop(g)
	}
}

// The worn item of a kind, or 0.
worn_kind :: proc(g: ^Game, k: Item_Kind) -> int {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Worn && g.items[i].kind == k {
			return i
		}
	}
	return 0
}

// A worn cursed thing will not come off. Says so (and what it is) and returns true.
stuck_on :: proc(g: ^Game, id: int) -> bool {
	it := &g.items[id]
	if it.place != .Worn || !it.cursed {
		return false
	}
	say(g, "Yer ", item_name(g, id), " will not come off! It is cursed.")
	identify_kind(g, it.kind)
	return true
}

// Things to eat, drink or read.
usable :: proc(k: Item_Kind) -> bool {
	return KIND[k].food > 0 || k == .Spellbook || KIND[k].group == .Potion || KIND[k].group == .Scroll
}

// Eats, drinks or reads an item from the inventory. A turn passes (Return excepted). False when it
// is not something to use.
use_item :: proc(g: ^Game, id: int) -> bool {
	it := g.items[id]
	k := it.kind
	info := KIND[k]
	name_buf: [32]u8
	n := copy(name_buf[:], item_name(g, id))
	name := string(name_buf[:n])
	if info.food > 0 {
		free_item(g, id)
		g.hunger = max(0, g.hunger - info.food)
		say(g, "You eat the ", name, ".")
		end_turn(g)
		return true
	}
	if k == .Spellbook {
		free_item(g, id)
		list: [len(Spell)]Spell
		count := learnable(g, &list)
		if count == 0 {
			say(g, "The book teaches nothing you lack. It blows away.")
		} else {
			s := list[rng_int(&g.rng, count)]
			g.known += {s}
			say(g, "You read the ", name, " and learn ", SPELL[s].name, ". It blows away.")
		}
		end_turn(g)
		return true
	}
	if info.group != .Potion && info.group != .Scroll {
		say(g, "You cannot use the ", name, ".")
		return false
	}
	free_item(g, id)
	say(g, info.group == .Potion ? "You drink the " : "You read the ", name, ".")
	identify_kind(g, k)
	turn := true
	#partial switch k {
	case .Potion_Healing:
		before := g.health
		g.health = min(max_health(g), g.health + rng_range(&g.rng, 8, 12))
		buf: [8]u8
		say(g, "You heal ", itoa(buf[:], g.health - before), ".")
	case .Potion_Mana:
		g.mana = min(max_mana(g), g.mana + 10)
		say(g, "Yer head clears.")
	case .Potion_Blight:
		say(g, "It tastes of rent arrears.")
		hurt(g, rng_range(&g.rng, 3, 6), "a bad potion")
	case .Potion_Sight:
		g.sense_turns = SIGHT_TURNS
		say(g, "You see every tenant on the floor.")
	case .Scroll_Return:
		g.mode = .Play
		say(g, "The wind sets you down at the town gate.")
		enter_town(g, .Gate)
		turn = false
	case .Scroll_Identify:
		start_identify(g)
	case .Scroll_Uncurse:
		lifted := false
		for i in 1 ..< MAX_ITEMS {
			if g.items[i].place == .Worn && g.items[i].cursed {
				g.items[i].cursed = false
				lifted = true
			}
		}
		say(g, lifted ? "A weight lifts. What you wear will come off now." : "Nothing you wear was cursed.")
	case .Scroll_Decree:
		say(g, "You read it aloud: all tenants to report at once. They come.")
		for &t in g.tenants {
			if t.kind != .None && int(t.floor) == g.current {
				t.awake = true
				t.tx, t.ty = i16(g.x), i16(g.y)
			}
		}
	}
	if turn && g.mode != .Dead {
		end_turn(g)
	}
	return true
}

// The Identify spell or scroll: the inventory opens and the next thing chosen is named.
start_identify :: proc(g: ^Game) {
	if g.mode != .Inventory {
		open_inventory(g)
	}
	g.inv.identify = true
	g.inv.held = 0
	say(g, "Choose a thing to identify.")
}

identify_item :: proc(g: ^Game, id: int) {
	g.inv.identify = false
	k := g.items[id].kind
	if KIND[k].group == .None {
		say(g, "It is a ", item_name(g, id), ", plain as it looks.")
		return
	}
	if k in g.ident {
		say(g, "You already knew: ", KIND[k].name, ".")
		return
	}
	identify_kind(g, k)
	if KIND[k].cursed {
		say(g, g.items[id].cursed ? "It is cursed." : "Its curse is lifted.")
	}
}
