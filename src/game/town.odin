package game

// The town at the foot of the bulwark (slice 1 step 7; DESIGN.md beat 2, "Death: town
// checkpoint", "Money: heavy Jools, a bank, trophies"). One hand-built street of doors: a general
// store, the smith, the sage, the temple, the junk shop, the bank and the tavern (the mentor), with
// the herald in the square and the bulwark gate at the top. The town believes every proclamation
// and profits from the wind. No gusts reach the street, no tenants live here, and it is daylight.
// Shops are a list screen: choose a row (Up/Down and Enter/OK, or click), Esc/Back leaves.

TOWN :: -1 // g.current while in town

TOWN_X :: 10 // the map sits here in the floor grid
TOWN_Y :: 14

TOWN_MAP := [?]string {
	"########################################",
	"#..................#^#.................#",
	"#..BBBBB..BBBBB...........BBBBB..BBBBB.#",
	"#..BBBBB..BBBBB.....H.....BBBBB..BBBBB.#",
	"#..BBGBB..BBSBB...........BBABB..BBTBB.#",
	"#......................................#",
	"#......................................#",
	"#..BBJBB..BBKBB...........BBVBB........#",
	"#..BBBBB..BBBBB...........BBBBB........#",
	"#..BBBBB..BBBBB...........BBBBB........#",
	"#......................................#",
	"########################################",
}

Shop :: enum u8 {
	None,
	General,
	Smith,
	Sage,
	Temple,
	Junk,
	Bank,
	Tavern,
	Herald,
	Carny, // a carny's stall on the floors
	Admission, // the carny at floor 4's door
	Gate, // the bulwark gate, once the windchute is open
}

Shop_Info :: struct {
	letter: u8, // on TOWN_MAP
	title:  string,
	sign:   string, // painted over the building
	line:   string, // what the keeper says (the town's believe-and-profit voice)
}

SHOP := [Shop]Shop_Info {
	.None    = {},
	.General = {'G', "The general store", "STORE", "Bread, torches, and charms against His Lordship's breath. He breathes a great deal."},
	.Smith   = {'S', "The smith", "SMITH", "Every gust is His Lordship's. Every dent is mine to mend."},
	.Sage    = {'A', "The sage", "SAGE", "I can tell you what anything is. The wind is His Lordship, of course."},
	.Temple  = {'T', "The temple", "TEMPLE", "His Lordship's breath sickens many. We mend them, for an offering."},
	.Junk    = {'J', "The junk shop", "JUNK", "I buy anything. Mostly what the wind blew in."},
	.Bank    = {'K', "The bank", "BANK", "Jools are heavy. Leave them with us. We never climb."},
	.Tavern  = {'V', "The tavern", "TAVERN", "The mentor sits in the corner, as always."},
	.Herald  = {'H', "The herald", "", "Hear ye! His Lordship commands the wind!"},
	.Carny   = {0, "A carny's stall", "", "\"Step up! Every game a winner, nearly!\""},
	.Admission = {0, "The door to the Horde", "", "\"See the Undead Horde! Two Jools! Terrifying! Mostly!\""},
	.Gate    = {0, "The bulwark gate", "", "A windchute hums beside the stairs. It blows up to floor 4, where you have been."},
}

// What a thing is worth in Jools (shops sell at this, the smith buys gear at half, the junk shop
// buys trophies at this and anything else for a fifth).
VALUE := #partial [Item_Kind]int {
	.Torch           = 8,
	.Dagger          = 10,
	.Short_Sword     = 30,
	.Club            = 20,
	.Padded_Armour   = 30,
	.Leather_Cap     = 15,
	.Buckler         = 25,
	.Boots           = 15,
	.Bread           = 5,
	.Cheese          = 4,
	.Jerky           = 6,
	.Pack            = 40,
	.Sack            = 15,
	.Big_Pack        = 100,
	.Belt            = 20,
	.Purse           = 10,
	.Rat_Tail        = 2,
	.Bat_Wing        = 2,
	.Spider_Leg      = 3,
	.Beetle_Shell    = 4,
	.Kobold_Ear      = 5,
	.Potion_Healing  = 20,
	.Potion_Mana     = 20,
	.Potion_Blight   = 5,
	.Potion_Sight    = 15,
	.Scroll_Return   = 25,
	.Scroll_Identify = 20,
	.Scroll_Uncurse  = 30,
	.Scroll_Decree   = 5,
	.Ring_Guard      = 50,
	.Ring_Draught    = 5,
	.Amulet_Vigour   = 50,
	.Amulet_Hop      = 5,
	.Spellbook       = 60,
	.Wind_Charm      = 5,
	.Skull           = 3,
	.Old_Bones       = 1,
}

GENERAL_STOCK := [?]Item_Kind{.Bread, .Cheese, .Jerky, .Torch, .Sack, .Big_Pack, .Wind_Charm}
SMITH_STOCK := [?]Item_Kind{.Dagger, .Club, .Short_Sword, .Leather_Cap, .Boots, .Buckler, .Padded_Armour}

// Tuning (PLAN.md step 7; to review).
SAGE_FEE :: 10
TEMPLE_UNCURSE :: 30
MEAL_PRICE :: 3
TRAIN_PRICE :: 10 // times yer level
TRAIN_XP :: 5
RING_TOSS :: 2
RING_TOSS_ODDS :: 8 // one toss in this many wins
UNKNOWN_JUNK :: 2 // what the junk shop pays for a thing nobody has named

MENTOR_LINES := [?]string {
	"\"Lead yer bolts into the wind. Or don't. It leads them anyway.\"",
	"\"A heavy pack holds you down. That's both the good and the bad of it.\"",
	"\"Snuff yer torch to slip past. They see a light from far off.\"",
	"\"Eat before yer hungry. Hungry is late.\"",
	"\"I went up. I came back down. Pass the bread.\"",
	"\"Bank yer Jools. The floor keeps what you drop when you fall.\"",
}

HERALD_LINES := [?]string {
	"\"His Lordship blew down a farm last week. As foretold.\"",
	"\"His Lordship's breath is the wind. Who else's could it be?\"",
	"\"His Lordship sees all from the top. He has said so. Through me.\"",
}

// Builds the town once (it never changes).
build_town :: proc(f: ^Floor) {
	f^ = {}
	f.number = 0
	f.made = true
	town_cells(f)
	f.down = door_of(.Temple) + {0, 1} // where you wake: outside the temple
}

// The town's cells and gate from TOWN_MAP (also used to restore a save).
town_cells :: proc(f: ^Floor) {
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			f.cells[y][x] = .Wall
		}
	}
	for row, y in TOWN_MAP {
		for x in 0 ..< len(row) {
			c: Cell
			switch row[x] {
			case '#':
				c = .Wall
			case 'B':
				c = .Building
			case '.':
				c = .Floor
			case '^':
				c = .Stairs_Up
				f.up = {TOWN_X + x, TOWN_Y + y}
			case:
				c = .Door
			}
			f.cells[TOWN_Y + y][TOWN_X + x] = c
		}
	}
}

door_of :: proc(s: Shop) -> [2]int {
	for row, y in TOWN_MAP {
		for x in 0 ..< len(row) {
			if row[x] == SHOP[s].letter {
				return {TOWN_X + x, TOWN_Y + y}
			}
		}
	}
	return {}
}

shop_at :: proc(x, y: int) -> Shop {
	tx, ty := x - TOWN_X, y - TOWN_Y
	if ty < 0 || ty >= len(TOWN_MAP) || tx < 0 || tx >= len(TOWN_MAP[0]) {
		return .None
	}
	for s in Shop {
		if s != .None && SHOP[s].letter == TOWN_MAP[ty][tx] {
			return s
		}
	}
	return .None
}

in_town :: proc(g: ^Game) -> bool {
	return g.current == TOWN
}

Town_Arrival :: enum u8 {
	Gate, // down the stairs from floor 1, or the Return spell or scroll
	Temple, // waking after a fall
	Start, // a new character
}

enter_town :: proc(g: ^Game, how: Town_Arrival) {
	if !g.town.made {
		build_town(&g.town)
	}
	g.current = TOWN
	at := how == .Temple ? g.town.down : g.town.up + {0, 1}
	g.x, g.y = at.x, at.y
	g.trained = false
	stop_travel(g)
	refresh_view(g)
	if how != .Start {
		proclaim(g)
	}
}

// The herald claims yer deeds for the lord each time you come back, if there is anything new.
proclaim :: proc(g: ^Game) {
	buf: [8]u8
	told := &g.told
	text: [96]u8
	n := 0
	add :: proc(text: []u8, n: ^int, parts: ..string) {
		for s in parts {
			n^ += copy(text[n^:], s)
		}
	}
	switch {
	case g.boss_dead && !told.boss:
		add(text[:], &n, "His Lordship has destroyed the Undead Horde, as foretold.")
	case g.deepest > told.deepest:
		add(text[:], &n, "His Lordship has conquered floor ", itoa(buf[:], g.deepest), " of his own bulwark, as foretold.")
	case g.level > told.level:
		add(text[:], &n, "His Lordship has grown wiser, as foretold.")
	case g.kills > told.kills:
		add(text[:], &n, "His Lordship has evicted ", itoa(buf[:], g.kills - told.kills), g.kills - told.kills == 1 ? " tenant" : " tenants", " for late rent.")
	case g.deaths > told.deaths:
		add(text[:], &n, "His Lordship notes that a climber fell. It was a lesson to us all.")
	case:
		return
	}
	told^ = {g.deepest, g.level, g.kills, g.deaths, g.boss_dead}
	g.proclamation_n = copy(g.proclamation[:], text[:n])
	say(g, "The herald reads: \"", string(g.proclamation[:g.proclamation_n]), "\"")
	say(g, "The town cheers the lord.")
}

// Coins carried, paid out of the purse first. False (and nothing taken) when there are too few.
pay :: proc(g: ^Game, amount: int) -> bool {
	if carried_jools(g) < amount {
		say(g, "You have too few Jools.")
		return false
	}
	left := amount
	for pass in 0 ..< 2 {
		for i in 1 ..< MAX_ITEMS {
			it := &g.items[i]
			if left == 0 || it.kind != .Jools || !is_carried(g, i) {
				continue
			}
			in_purse := it.place == .Inside && g.items[it.parent].kind == .Purse
			if (pass == 0) != in_purse {
				continue
			}
			take := min(left, int(it.count))
			it.count -= i32(take)
			left -= take
			if it.count == 0 {
				free_item(g, i)
			}
		}
	}
	return true
}

// Coins into the purse (or wherever they fit). False when there is no room.
receive_jools :: proc(g: ^Game, amount: int) -> bool {
	if amount <= 0 {
		return true
	}
	id := new_item(g, .Jools, amount)
	if id == 0 {
		return false
	}
	if !stow(g, id) {
		free_item(g, id)
		say(g, "You have no room for the Jools.")
		return false
	}
	return true
}

// A new thing of a kind, carried. False (nothing made) when there is no room.
receive_item :: proc(g: ^Game, k: Item_Kind) -> bool {
	id := new_item(g, k)
	if id == 0 {
		return false
	}
	if !stow(g, id) {
		free_item(g, id)
		say(g, "You have no room for it.")
		return false
	}
	return true
}

// Puts on a new Big pack in place of the pack worn, moving everything in it over (the old pack goes
// to the store). False when there is no free item slot.
swap_pack :: proc(g: ^Game) -> bool {
	id := new_item(g, .Big_Pack)
	if id == 0 {
		say(g, "You have no room for it.")
		return false
	}
	if old := worn(g, .Pack); old != 0 {
		for i in 1 ..< MAX_ITEMS {
			if g.items[i].place == .Inside && int(g.items[i].parent) == old {
				g.items[i].parent = i16(id)
			}
		}
		free_item(g, old)
	}
	return wear(g, id, .Pack)
}

// A row on a shop screen.
Act :: enum u8 {
	Leave,
	Buy, // arg: an Item_Kind
	Sell, // arg: an item id
	Repair, // arg: an item id
	Identify, // arg: an item id
	Heal,
	Uncurse,
	Deposit,
	Withdraw, // arg: how many (0: all)
	Meal,
	Talk,
	Train,
	Hear,
	Ask,
	Toss,
	Shove,
	Admit,
	Climb,
	Chute,
}

Row :: struct {
	text:  [32]u8,
	n:     int,
	price: int, // shown when above 0; negative: what they pay you
	act:   Act,
	arg:   int,
}

MAX_ROWS :: 40

row_text :: proc(r: ^Row) -> string {
	return string(r.text[:r.n])
}

add_row :: proc(rows: ^[MAX_ROWS]Row, n: ^int, act: Act, arg: int, price: int, parts: ..string) {
	if n^ >= MAX_ROWS {
		return
	}
	r := &rows[n^]
	r^ = {act = act, arg = arg, price = price}
	for s in parts {
		r.n += copy(r.text[r.n:], s)
	}
	n^ += 1
}

// What the junk shop pays for a thing.
junk_price :: proc(g: ^Game, id: int) -> int {
	it := &g.items[id]
	k := it.kind
	if KIND[k].trophy {
		return VALUE[k]
	}
	if KIND[k].group != .None && k not_in g.ident {
		return UNKNOWN_JUNK
	}
	return max(1, VALUE[k] / 5)
}

repair_price :: proc(g: ^Game, id: int) -> int {
	return KIND[g.items[id].kind].durability - int(g.items[id].dur)
}

// Things carried that a shop could take: not worn, not coins, not a container with anything in it.
sellable :: proc(g: ^Game, id: int) -> bool {
	it := &g.items[id]
	return it.kind != .None && it.kind != .Jools && it.kind != .Key && it.place == .Inside && is_carried(g, id) && !(is_container(it.kind) && contents_count(g, id) > 0)
}

shop_rows :: proc(g: ^Game, rows: ^[MAX_ROWS]Row) -> int {
	n := 0
	buf: [12]u8
	switch g.shop {
	case .None:
	case .General:
		for k in GENERAL_STOCK {
			if k == .Big_Pack && g.items[worn(g, .Pack)].kind == .Big_Pack {
				continue // one is enough
			}
			add_row(rows, &n, .Buy, int(k), VALUE[k], "Buy ", KIND[k].name)
		}
	case .Smith:
		for i in 1 ..< MAX_ITEMS {
			if is_carried(g, i) && KIND[g.items[i].kind].durability > 0 && repair_price(g, i) > 0 {
				add_row(rows, &n, .Repair, i, repair_price(g, i), "Mend ", item_name(g, i))
			}
		}
		for k in SMITH_STOCK {
			add_row(rows, &n, .Buy, int(k), VALUE[k], "Buy ", KIND[k].name)
		}
		for i in 1 ..< MAX_ITEMS {
			if sellable(g, i) && KIND[g.items[i].kind].durability > 0 {
				add_row(rows, &n, .Sell, i, -max(1, VALUE[g.items[i].kind] / 2), "Sell ", item_name(g, i))
			}
		}
	case .Sage:
		for i in 1 ..< MAX_ITEMS {
			k := g.items[i].kind
			if is_carried(g, i) && KIND[k].group != .None && k not_in g.ident {
				add_row(rows, &n, .Identify, i, SAGE_FEE, "Name ", item_name(g, i))
			}
		}
		if n == 0 {
			add_row(rows, &n, .Talk, 0, 0, "Ask about the wind")
		}
	case .Temple:
		if g.health < max_health(g) {
			add_row(rows, &n, .Heal, 0, max_health(g) - g.health, "Be healed")
		}
		for i in 1 ..< MAX_ITEMS {
			if g.items[i].place == .Worn && g.items[i].cursed {
				add_row(rows, &n, .Uncurse, 0, TEMPLE_UNCURSE, "Lift a curse")
				break
			}
		}
		if n == 0 {
			add_row(rows, &n, .Talk, 0, 0, "Pray for calm")
		}
	case .Junk:
		for i in 1 ..< MAX_ITEMS {
			if sellable(g, i) {
				add_row(rows, &n, .Sell, i, -junk_price(g, i), "Sell ", item_name(g, i))
			}
		}
	case .Bank:
		have := carried_jools(g)
		if have > 0 {
			add_row(rows, &n, .Deposit, 0, 0, "Bank all ", itoa(buf[:], have), " carried")
		}
		if g.bank >= 10 {
			add_row(rows, &n, .Withdraw, 10, 0, "Take out 10")
		}
		if g.bank >= 50 {
			add_row(rows, &n, .Withdraw, 50, 0, "Take out 50")
		}
		if g.bank > 0 {
			add_row(rows, &n, .Withdraw, 0, 0, "Take out all ", itoa(buf[:], g.bank))
		}
	case .Tavern:
		add_row(rows, &n, .Meal, 0, MEAL_PRICE, "A hot meal")
		add_row(rows, &n, .Talk, 0, 0, "Talk to the mentor")
		if !g.trained {
			add_row(rows, &n, .Train, 0, TRAIN_PRICE * g.level, "Train with the mentor")
		}
	case .Herald:
		if g.proclamation_n > 0 {
			add_row(rows, &n, .Hear, 0, 0, "Hear the proclamation again")
		}
		add_row(rows, &n, .Ask, 0, 0, "Ask about His Lordship")
	case .Carny:
		add_row(rows, &n, .Toss, 0, RING_TOSS, "Ring toss (win a prize)")
		add_row(rows, &n, .Buy, int(Item_Kind.Wind_Charm), VALUE[.Wind_Charm], "Buy a Wind charm")
		add_row(rows, &n, .Shove, 0, 0, "Shove past")
	case .Admission:
		add_row(rows, &n, .Admit, 0, ADMISSION, "Pay to see the Horde")
		add_row(rows, &n, .Shove, 0, 0, "Shove past")
	case .Gate:
		add_row(rows, &n, .Climb, 0, 0, "Climb to floor 1")
		add_row(rows, &n, .Chute, 0, 0, "Ride the windchute to floor 4")
	}
	add_row(rows, &n, .Leave, 0, 0, "Leave")
	return n
}

open_shop :: proc(g: ^Game, s: Shop) {
	stop_travel(g)
	g.mode = .Shop
	g.shop = s
	g.menu_row = 0
	g.shop_scroll = 0
	say(g, SHOP[s].title, ". Esc/Back to leave.")
}

leave_shop :: proc(g: ^Game) {
	g.mode = .Play
	g.shop = .None
	open_learn_if_owed(g)
}

shop_command :: proc(g: ^Game, c: Command) {
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	#partial switch c {
	case .North, .North_West, .North_East:
		g.menu_row = (g.menu_row + n - 1) % n
	case .South, .South_West, .South_East:
		g.menu_row = (g.menu_row + 1) % n
	case .Confirm:
		shop_act(g, &rows[min(g.menu_row, n - 1)])
	case .Cancel:
		leave_shop(g)
		return
	}
	keep_shop_row(g)
}

keep_shop_row :: proc(g: ^Game) {
	if g.mode != .Shop {
		return
	}
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	g.menu_row = clamp(g.menu_row, 0, n - 1)
	if g.menu_row < g.shop_scroll {
		g.shop_scroll = g.menu_row
	} else if g.menu_row >= g.shop_scroll + SHOP_ROWS {
		g.shop_scroll = g.menu_row - SHOP_ROWS + 1
	}
}

shop_act :: proc(g: ^Game, r: ^Row) {
	buf, buf2: [12]u8
	switch r.act {
	case .Leave:
		leave_shop(g)
	case .Buy:
		k := Item_Kind(r.arg)
		if carried_jools(g) < r.price {
			say(g, "You have too few Jools.")
		} else if k == .Big_Pack {
			if swap_pack(g) {
				pay(g, r.price)
				say(g, "The store takes yer old pack and moves yer things into a Big pack.")
			}
		} else if receive_item(g, k) {
			pay(g, r.price)
			say(g, "You buy a ", KIND[k].name, ".")
		}
	case .Sell:
		name_buf: [32]u8
		nn := copy(name_buf[:], item_name(g, r.arg))
		if stuck_on(g, r.arg) {
			return
		}
		free_item(g, r.arg)
		receive_jools(g, -r.price)
		say(g, "You sell the ", string(name_buf[:nn]), " for ", itoa(buf[:], -r.price), ".")
	case .Repair:
		if pay(g, r.price) {
			g.items[r.arg].dur = i16(KIND[g.items[r.arg].kind].durability)
			say(g, "The smith mends yer ", item_name(g, r.arg), ". \"The wind will have it again.\"")
		}
	case .Identify:
		if pay(g, r.price) {
			k := g.items[r.arg].kind
			identify_kind(g, k)
			if KIND[k].cursed {
				say(g, "\"Cursed, that. His Lordship's doing.\"")
			}
		}
	case .Heal:
		if pay(g, r.price) {
			g.health = max_health(g)
			say(g, "You are healed. \"His Lordship's breath is hard on climbers.\"")
		}
	case .Uncurse:
		if pay(g, r.price) {
			for i in 1 ..< MAX_ITEMS {
				if g.items[i].place == .Worn {
					g.items[i].cursed = false
				}
			}
			say(g, "The priest lifts the curse. What you wear will come off now.")
		}
	case .Deposit:
		have := carried_jools(g)
		pay(g, have)
		g.bank += have
		say(g, "You bank ", itoa(buf[:], have), " Jools. The bank holds ", itoa(buf2[:], g.bank), ".")
	case .Withdraw:
		amount := r.arg == 0 ? g.bank : min(r.arg, g.bank)
		if receive_jools(g, amount) {
			g.bank -= amount
			say(g, "You take out ", itoa(buf[:], amount), " Jools.")
		}
	case .Meal:
		if pay(g, r.price) {
			g.hunger = 0
			say(g, "You eat a hot meal. The cook thanks His Lordship for the weather.")
		}
	case .Talk:
		switch g.shop {
		case .Tavern:
			say(g, "The mentor: ", MENTOR_LINES[g.talk % len(MENTOR_LINES)])
		case .Sage:
			say(g, "\"The wind is His Lordship's breath. I have identified it.\"")
		case .Temple:
			say(g, "You pray for calm. The priest prays for His Lordship's health.")
		case .None, .General, .Smith, .Junk, .Bank, .Herald, .Carny, .Admission, .Gate:
		}
		g.talk += 1
	case .Train:
		if pay(g, r.price) {
			g.trained = true
			g.xp += TRAIN_XP
			say(g, "You spar with the mentor. \"Again. Lower.\"")
			check_level(g)
		}
	case .Hear:
		say(g, "The herald reads: \"", string(g.proclamation[:g.proclamation_n]), "\"")
	case .Ask:
		say(g, "The herald: ", HERALD_LINES[g.talk % len(HERALD_LINES)])
		g.talk += 1
	case .Toss:
		if pay(g, r.price) {
			if rng_int(&g.rng, RING_TOSS_ODDS) == 0 {
				k := Item_Kind(int(Item_Kind.Potion_Healing) + rng_int(&g.rng, 4))
				if receive_item(g, k) {
					say(g, "The ring lands! You win a ", look_name(g, k), ".")
				}
			} else {
				say(g, "The ring bounces off. \"So close! Again?\"")
			}
		}
	case .Admit:
		if pay(g, r.price) {
			leave_shop(g)
			admit(g)
		}
	case .Climb:
		leave_shop(g)
		enter_floor(g, 0, .Stairs_Down)
		say(g, "You climb to floor 1. The wind is stronger.")
	case .Chute:
		leave_shop(g)
		enter_floor(g, BOSS_INDEX, .Stairs_Down)
		say(g, "The windchute blows you up to floor 4.")
	case .Shove:
		id := g.shop_tenant
		leave_shop(g)
		if id != 0 && g.tenants[id].kind == .Carny {
			player_attack(g, id)
		}
	}
}

// Shop screen layout (in the map area).
SHOP_TOP :: 48 // room for a three-line keeper's line above the rows
SHOP_ROW_H :: 10
SHOP_ROWS :: (VIEW_H * TILE - SHOP_TOP - 2) / SHOP_ROW_H
SHOP_PRICE_X :: VIEW_W * TILE - 8

shop_pointer :: proc(g: ^Game, sx, sy: int) {
	if sx >= VIEW_W * TILE || sy < SHOP_TOP - 2 {
		return
	}
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	r := (sy - SHOP_TOP + 2) / SHOP_ROW_H + g.shop_scroll
	if r < n && r - g.shop_scroll < SHOP_ROWS {
		g.menu_row = r
		shop_act(g, &rows[r])
		keep_shop_row(g)
	}
}

draw_shop :: proc(f: ^Frame, g: ^Game) {
	info := SHOP[g.shop]
	buf: [12]u8
	print(f, info.title, 6, 2, COLOR_CYAN)
	// Jools carried (and banked, at the bank), right-aligned on the title line.
	right: [40]u8
	rn := copy(right[:], "Jools ")
	rn += copy(right[rn:], itoa(buf[:], carried_jools(g)))
	if g.shop == .Bank {
		rn += copy(right[rn:], "  Banked ")
		rn += copy(right[rn:], itoa(buf[:], g.bank))
	}
	print(f, string(right[:rn]), VIEW_W * TILE - 6 - text_width(string(right[:rn])), 2, COLOR_YELLOW)
	// The keeper's line, wrapped at spaces.
	line := info.line
	y := 14
	width := (VIEW_W * TILE - 12) / GLYPH_W
	for len(line) > 0 && y < SHOP_TOP - 8 {
		end := min(len(line), width)
		if end < len(line) {
			for b := end; b > 0; b -= 1 {
				if line[b] == ' ' {
					end = b
					break
				}
			}
		}
		print(f, line[:end], 6, y, COLOR_MID)
		line = line[end:]
		for len(line) > 0 && line[0] == ' ' {
			line = line[1:]
		}
		y += 9
	}
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for i in g.shop_scroll ..< min(n, g.shop_scroll + SHOP_ROWS) {
		r := &rows[i]
		ry := SHOP_TOP + (i - g.shop_scroll) * SHOP_ROW_H
		if i == g.menu_row {
			fill_rect(f, 2, ry - 2, VIEW_W * TILE - 4, SHOP_ROW_H, COLOR_DARK)
			print(f, ">", 4, ry, COLOR_YELLOW)
		}
		print(f, row_text(r), 12, ry, COLOR_LIGHT)
		if r.price != 0 {
			pb: [14]u8
			p := itoa(buf[:], abs(r.price))
			if r.price < 0 { // what they pay you
				pb[0] = '+'
				p = string(pb[:1 + copy(pb[1:], p)])
			}
			color: u8 = r.price < 0 ? COLOR_CYAN : carried_jools(g) >= r.price ? COLOR_YELLOW : COLOR_MID
			print(f, p, SHOP_PRICE_X - text_width(p), ry, color)
		}
	}
	if g.shop_scroll > 0 {
		print(f, "^", VIEW_W * TILE - 8, SHOP_TOP - 10, COLOR_MID)
	}
	if g.shop_scroll + SHOP_ROWS < n {
		print(f, "v", VIEW_W * TILE - 8, SHOP_TOP + SHOP_ROWS * SHOP_ROW_H - 2, COLOR_MID)
	}
}

// Signs over the buildings and the herald in the square.
draw_town :: proc(f: ^Frame, g: ^Game) {
	ox, oy := view_origin(g)
	for s in Shop {
		if SHOP[s].letter == 0 {
			continue
		}
		d := door_of(s)
		sx, sy := MAP_X + (d.x - ox) * TILE, MAP_Y + (d.y - oy) * TILE
		if s == .Herald {
			if sx >= MAP_X && sy >= MAP_Y && sx < MAP_X + VIEW_W * TILE && sy < MAP_Y + VIEW_H * TILE {
				fill_rect(f, sx, sy, TILE, TILE, COLOR_BLACK)
				draw_gfx(f, .Herald, sx, sy, COLOR_YELLOW)
			}
			continue
		}
		// The sign goes on the building's middle row (above a bottom-face door, below a top-face one).
		up := TOWN_MAP[d.y - TOWN_Y - 1][d.x - TOWN_X] == 'B'
		ty := sy + (up ? -TILE : TILE) + 2
		tw := text_width(info_sign(s))
		tx := sx + TILE / 2 - tw / 2
		if ty >= MAP_Y && ty < MAP_Y + VIEW_H * TILE - 8 && tx >= MAP_X && tx + tw <= MAP_X + VIEW_W * TILE {
			fill_rect(f, tx - 1, ty - 1, tw + 2, 10, COLOR_BLACK)
			print(f, info_sign(s), tx, ty, COLOR_YELLOW)
		}
	}
}

info_sign :: proc(s: Shop) -> string {
	return SHOP[s].sign
}
