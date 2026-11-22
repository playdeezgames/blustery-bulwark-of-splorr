package game

// Tenants (slice 1 step 4; DESIGN.md "The monsters are tenants", "Combat rolls: hidden", "Gear wears
// out"). The bulwark's creatures live here and pay the lord rent; they attack because yer
// trespassing. Each floor gets its tenants once, from the floor's seed, and they stay where they
// are while you are elsewhere. They wander until they see you (a lit torch shows you from afar),
// then chase and bite. To-hit and damage are rolled out of sight; the log says only what happened.

Tenant_Kind :: enum u8 {
	None,
	Rat,
	Bat,
	Beetle,
	Spider,
	Kobold,
	Slime,
	Carny,
	Skeleton, // floor 4's boss, the Undead Horde (boss.odin)
	Bones, // the rest of the Horde, propped up
	// From floor 5 (slice 2 step 11).
	Crow,
	Ant, // placed in threes
	Goblin,
	Bear, // heavy: gusts do not move it; a maul can take a point of Strength
	Bailiff, // does not fight: takes Jools from yer purse and runs
	Hermit, // floor 6's camp (camp.odin): trades when bumped
	Sergeant, // floor 8's boss, the Army of a Thousand (army.odin): a rat in a tiny hat
	// From floor 9 (slice 3 step 18).
	Ogre, // heavy and slow; meeting plain ogres first sets up floor 12's giant
	Wisp, // light and fast; its touch puts out yer light and does no harm
	Mimic, // looks like a pack until you are next to it
	Draught, // never fights; pushes you away from it; blows pass through, any spell seals it
	Cartographer, // floor 10's camp (camp.odin): sells maps when bumped
	Giant, // floor 12's boss (giant.odin): an ogre on a crate
	// From floor 13 (slice 4 step 25): the boasts that never got a floor (DESIGN.md beat 4).
	Lizard, // the "Dragon": heavy, hits hard
	Goat, // the "demon": charges from 2 or 3 cells in a line and butts you back a cell
	Peacock, // the "hundred-eyed beast": light and fast; its scream wakes the floor
	// Floor 15 (slice 4 step 28; champion.odin).
	Champion, // learns as he fights; yields at a quarter of his health, never dies
	Champion_Seated, // the champion after he yields: peaceful; bumping him, he talks and leaves
	// Floor 16, the top (slice 4 step 29; top.odin).
	Guard, // hired by the herald
	Lord, // His Lordship: never speaks, cannot be harmed
}

Tenant_Info :: struct {
	name:       string, // "rat"
	a:          string, // "a rat" (said when it brings you down)
	gfx:        Gfx,
	color:      u8,
	health:     int,
	hit:        int, // chance in 100 before yer armour and Dexterity
	dmin, dmax: int,
	defence:    int, // taken off yer chance to hit it
	speed:      int, // 10 acts once a turn, 20 twice, 5 every other turn
	xp:         int,
	light:      bool, // gusts carry it along
	erratic:    bool, // flits about even when it means to bite
	peaceful:   bool, // leaves you be until you strike it
	prop:       bool, // never moves or fights; a gust or a push knocks it over
	rare:       bool, // picked half as often when a floor is stocked
	trophy:     Item_Kind,
	chance:     int, // in 100, that it leaves its trophy
	first:      int, // the lowest floor it lives on
	verb:       string, // "bites"
	line:       string, // said when you look at it
}

TENANT := [Tenant_Kind]Tenant_Info {
	.None   = {},
	.Rat    = {name = "rat", a = "a rat", gfx = .Rat, color = COLOR_LIGHT, health = 3, hit = 50, dmin = 1, dmax = 2, speed = 10, xp = 1, light = true, trophy = .Rat_Tail, chance = 50, first = 1, verb = "bites", line = "Pays rent on the second Tuesday."},
	.Bat    = {name = "bat", a = "a bat", gfx = .Bat, color = 10, health = 2, hit = 45, dmin = 1, dmax = 2, defence = 10, speed = 20, xp = 1, light = true, erratic = true, trophy = .Bat_Wing, chance = 50, first = 1, verb = "bites", line = "Sublets the ceiling."},
	.Beetle = {name = "beetle", a = "a beetle", gfx = .Beetle, color = COLOR_ORANGE, health = 6, hit = 45, dmin = 1, dmax = 3, defence = 15, speed = 5, xp = 2, trophy = .Beetle_Shell, chance = 50, first = 1, verb = "nips", line = "Has lived here longer than the lord, it says."},
	.Spider = {name = "spider", a = "a spider", gfx = .Spider, color = COLOR_RED, health = 5, hit = 60, dmin = 1, dmax = 4, defence = 5, speed = 10, xp = 3, light = true, trophy = .Spider_Leg, chance = 50, first = 2, verb = "bites", line = "Was promised a view."},
	.Kobold = {name = "kobold", a = "a kobold", gfx = .Kobold, color = 5, health = 8, hit = 55, dmin = 1, dmax = 5, defence = 10, speed = 10, xp = 4, trophy = .Kobold_Ear, chance = 40, first = 2, verb = "stabs", line = "Reads every proclamation aloud, slowly."},
	.Slime  = {name = "slime", a = "a slime", gfx = .Slime, color = 6, health = 12, hit = 50, dmin = 2, dmax = 4, speed = 5, xp = 5, first = 3, verb = "burns", line = "Owes three months. Nobody asks."},
	.Skeleton = {name = "skeleton", a = "the Undead Horde", gfx = .Skeleton, color = COLOR_LIGHT, health = 20, hit = 55, dmin = 1, dmax = 5, defence = 5, speed = 10, xp = 15, first = 99, verb = "rattles at", line = "Nobody got round to burying it."},
	.Bones    = {name = "skeleton", a = "a skeleton", gfx = .Skeleton, color = COLOR_LIGHT, health = 1, peaceful = true, prop = true, first = 99, line = "It stands very still."},
	.Crow    = {name = "crow", a = "a crow", gfx = .Crow, color = COLOR_MID, health = 4, hit = 55, dmin = 1, dmax = 3, defence = 15, speed = 20, xp = 3, light = true, erratic = true, trophy = .Crow_Feather, chance = 50, first = 5, verb = "pecks", line = "Rents by the perch. Pays in shiny things."},
	.Ant     = {name = "giant ant", a = "a giant ant", gfx = .Ant, color = COLOR_RED, health = 7, hit = 55, dmin = 1, dmax = 4, defence = 15, speed = 10, xp = 3, trophy = .Ant_Feeler, chance = 40, first = 5, verb = "bites", line = "Works for the colony. The colony owes the rent."},
	.Goblin  = {name = "goblin", a = "a goblin", gfx = .Goblin, color = 6, health = 12, hit = 60, dmin = 2, dmax = 6, defence = 15, speed = 10, xp = 6, trophy = .Goblin_Ear, chance = 40, first = 5, verb = "slashes", line = "Hopes to be a landlord one day."},
	.Bear    = {name = "cave bear", a = "a cave bear", gfx = .Bear, color = COLOR_BROWN, health = 26, hit = 55, dmin = 3, dmax = 8, defence = 10, speed = 5, xp = 12, rare = true, trophy = .Bear_Hide, chance = 60, first = 5, verb = "mauls", line = "Hibernates through rent day, every year."},
	.Bailiff = {name = "bailiff", a = "a bailiff", gfx = .Bailiff, color = 9, health = 8, hit = 70, defence = 15, speed = 15, xp = 5, rare = true, trophy = .Eviction_Notice, chance = 50, first = 5, verb = "frisks", line = "\"Collecting His Lordship's rent.\""},
	.Hermit  = {name = "hermit", a = "the hermit", gfx = .Hermit, color = 10, health = 14, hit = 60, dmin = 1, dmax = 4, defence = 10, speed = 10, xp = 4, peaceful = true, first = 99, verb = "thumps", line = "She stopped here years ago. She seems fine with it."},
	.Sergeant = {name = "sergeant", a = "the Army of a Thousand", gfx = .Rat, color = COLOR_YELLOW, health = 24, hit = 60, dmin = 2, dmax = 5, defence = 10, speed = 10, xp = 20, first = 99, verb = "bites", line = "A rat in a tiny hat. The hat means everything."},
	.Ogre    = {name = "ogre", a = "an ogre", gfx = .Ogre, color = COLOR_LIGHT, health = 30, hit = 55, dmin = 3, dmax = 9, defence = 10, speed = 5, xp = 15, trophy = .Ogre_Tooth, chance = 50, first = 9, verb = "clubs", line = "An ogre. Exactly as tall as an ogre."},
	.Wisp    = {name = "wisp", a = "a wisp", gfx = .Wisp, color = COLOR_WHITE, health = 5, hit = 65, defence = 25, speed = 20, xp = 4, light = true, erratic = true, trophy = .Wisp_Glass, chance = 50, first = 9, verb = "touches", line = "Owes rent from before. Long before."},
	.Mimic   = {name = "mimic", a = "a mimic", gfx = .Mimic, color = COLOR_RED, health = 16, hit = 60, dmin = 2, dmax = 7, defence = 10, speed = 5, xp = 8, rare = true, trophy = .Mimic_Hinge, chance = 60, first = 9, verb = "bites", line = "Pays rent as furniture. Is furniture, mostly."},
	.Cartographer = {name = "cartographer", a = "the cartographer", gfx = .Cartographer, color = COLOR_LIGHT, health = 14, hit = 60, dmin = 1, dmax = 4, defence = 10, speed = 10, xp = 4, peaceful = true, first = 99, verb = "swats", line = "She mapped up to ten. She seems content with ten."},
	.Draught = {name = "draught", a = "a draught", gfx = .Draught, color = COLOR_CYAN, health = 1, speed = 10, xp = 3, peaceful = true, rare = true, first = 9, line = "A wind spirit, the town says. It is a draught."},
	.Giant   = {name = "giant", a = "the Giant", gfx = .Ogre, color = COLOR_LIGHT, health = 40, hit = 55, dmin = 3, dmax = 9, defence = 10, speed = 5, xp = 40, first = 99, verb = "clubs", line = "An ogre on a crate. From down here it looks very tall."},
	.Lizard  = {name = "Dragon", a = "a lizard called Dragon", gfx = .Lizard, color = 6, health = 32, hit = 60, dmin = 3, dmax = 10, defence = 15, speed = 10, xp = 18, trophy = .Name_Tag, chance = 50, first = 13, verb = "bites", line = "A very large lizard. Its name tag says Dragon."},
	.Goat    = {name = "demon", a = "His Lordship's demon", gfx = .Goat, color = COLOR_LIGHT, health = 22, hit = 65, dmin = 2, dmax = 8, defence = 10, speed = 10, xp = 12, trophy = .Goat_Horn, chance = 50, first = 13, verb = "butts", line = "His Lordship's demon, the town says. A goat with opinions."},
	.Peacock = {name = "hundred-eyed beast", a = "the hundred-eyed beast", gfx = .Peacock, color = 10, health = 10, hit = 55, dmin = 1, dmax = 4, defence = 10, speed = 20, xp = 8, light = true, rare = true, trophy = .Peacock_Feather, chance = 50, first = 13, verb = "pecks", line = "A hundred eyes, the town says. Painted on."},
	.Champion = {name = "champion", a = "His Lordship's champion", gfx = .Champion, color = COLOR_YELLOW, health = 60, hit = CHAMPION_HIT, dmin = 3, dmax = 11, defence = 25, speed = 10, xp = 60, first = 99, verb = "swings at", line = "His Lordship's champion. Undefeated, nineteen years."},
	.Champion_Seated = {name = "champion", a = "His Lordship's champion", gfx = .Champion, color = COLOR_YELLOW, health = 60, defence = 25, speed = 10, peaceful = true, first = 99, line = "He has sat down. He looks lighter."},
	.Guard = {name = "hired guard", a = "a hired guard", gfx = .Guard, color = 9, health = 20, hit = 60, dmin = 2, dmax = 7, defence = 15, speed = 10, xp = 10, trophy = .Contract, chance = 50, first = 99, verb = "jabs", line = "Hired by the herald. Paid by the hour, in advance."},
	.Lord  = {name = "old man", a = "His Lordship", gfx = .Lord, color = COLOR_WHITE, health = 1, speed = 10, peaceful = true, first = 99, line = "A very old man in a chair, with a cup of tea."},
	.Carny  = {name = "carny", a = "a carny", gfx = .Carny, color = COLOR_YELLOW, health = 10, hit = 55, dmin = 1, dmax = 4, defence = 10, speed = 10, xp = 3, peaceful = true, first = 3, verb = "cuffs", line = "\"See the Undead Horde, upstairs! Two Jools!\""},
}

Tenant :: struct {
	kind:     Tenant_Kind,
	floor:    i8,
	x, y:     i16,
	health:   i16,
	energy:   i16,
	awake:    bool, // has seen you and is after you
	angry:    bool, // a peaceful tenant you struck
	still:    bool, // stays where it is unless angered (the carny at floor 4's door)
	screamed: bool, // the hundred-eyed beast has screamed (once only; fills a padding byte, so saves keep their shape)
	tx, ty:   i16, // where it last saw you
}

MAX_TENANTS :: 320 // id 0 is never used
TENANT_SIGHT :: 8 // how far a tenant sees a lit climber
TENANT_DARK_SIGHT :: 2 // and one in the dark
PLAYER_HIT :: 60 // chance in 100 to land a blow, before Dexterity and the tenant's defence
DEX_AIM :: 2 // chance in 100 to land a blow per point of Dexterity above 10 (was 4 until November 12, 2026)
DEX_DODGE :: 1 // and taken off a tenant's chance to hit you (was 2)
BEAR_DRAIN :: 10 // one maul in this many takes a point of Strength
GOBLIN_DAGGER :: 4 // one goblin in this many drops a dagger
ANT_GROUP :: 3
RESTOCK_TURNS :: 150 // a floor you left gets a tenant back this often (the user's choice; proposed 300)
WEAPON_WEAR :: 3 // a blow you land wears yer weapon one time in this many
ARMOUR_WEAR :: 2 // a blow that lands on you wears a piece of armour one time in this many

new_tenant :: proc(g: ^Game, kind: Tenant_Kind, floor, x, y: int) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .None {
			g.tenants[i] = Tenant{kind = kind, floor = i8(floor), x = i16(x), y = i16(y), health = i16(TENANT[kind].health)}
			return i
		}
	}
	// With every floor stocked the table runs close to full (slice 4 step 29: 308 of 319 at most over
	// 60 seeds). The champion and His Lordship must always be there, so they take the slot of an
	// ordinary tenant on another floor, which simply moves out.
	if kind == .Champion || kind == .Lord {
		for i in 1 ..< MAX_TENANTS {
			o := g.tenants[i]
			if int(o.floor) != floor && TENANT[o.kind].first < 99 && o.kind != .Carny {
				g.tenants[i] = Tenant{kind = kind, floor = i8(floor), x = i16(x), y = i16(y), health = i16(TENANT[kind].health)}
				return i
			}
		}
	}
	return 0
}

// The tenant at a cell of the current floor, or 0.
tenant_at :: proc(g: ^Game, x, y: int) -> int {
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind != .None && int(t.floor) == g.current && int(t.x) == x && int(t.y) == y {
			return i
		}
	}
	return 0
}

hostile :: proc(t: ^Tenant) -> bool {
	return t.kind != .None && (!TENANT[t.kind].peaceful || t.angry) && !disguised(t)
}

// A mimic that has not woken looks like a pack lying on the floor (slice 3 step 18).
disguised :: proc(t: ^Tenant) -> bool {
	return t.kind == .Mimic && !t.awake
}

// True when a tenant that means you harm is in sight (a mouse route stops for it).
hostile_in_view :: proc(g: ^Game) -> bool {
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if hostile(t) && int(t.floor) == g.current && g.vis[t.y][t.x] {
			return true
		}
	}
	return false
}

// Tenants for a floor, made once from the floor's seed: a handful of the kinds that live this high,
// none in the room with the stairs down (where you arrive), and one carny on floor 3.
populate_tenants :: proc(g: ^Game, index: int, r: ^Rng) {
	f := &g.floors[index]
	kinds: [len(Tenant_Kind)]Tenant_Kind
	n := 0
	for k in Tenant_Kind {
		if k != .None && k != .Carny && TENANT[k].first <= f.number {
			kinds[n] = k
			n += 1
		}
	}
	for _ in 0 ..< 4 + 2 * f.number {
		place_tenant(g, f, r, index, pick_kind(kinds[:n], r))
	}
	if f.number == 3 {
		place_tenant(g, f, r, index, .Carny)
	}
	f.stock = count_tenants(g, index)
}

// One of the kinds that live on a floor; a rare one (the bear, the bailiff) half as often.
pick_kind :: proc(kinds: []Tenant_Kind, r: ^Rng) -> Tenant_Kind {
	k := kinds[rng_int(r, len(kinds))]
	if TENANT[k].rare && rng_int(r, 2) == 0 {
		k = kinds[rng_int(r, len(kinds))]
	}
	return k
}

// Puts a tenant in a random spot of a floor's rooms (not the first room, where the stairs down
// are); giant ants come with two more beside them (not when restocking, one at a time).
place_tenant :: proc(g: ^Game, f: ^Floor, r: ^Rng, index: int, kind: Tenant_Kind, group := true) {
	for _ in 0 ..< 100 {
		room := f.rooms[1 + rng_int(r, f.room_count - 1)]
		x, y := room.x + rng_int(r, room.w), room.y + rng_int(r, room.h)
		if f.cells[y][x] != .Floor || tenant_at_floor(g, index, x, y) != 0 {
			continue
		}
		new_tenant(g, kind, index, x, y)
		if kind == .Ant && group {
			placed := 1
			for d in DIRECTIONS {
				if placed >= ANT_GROUP {
					break
				}
				if f.cells[y + d.y][x + d.x] == .Floor && tenant_at_floor(g, index, x + d.x, y + d.y) == 0 {
					new_tenant(g, kind, index, x + d.x, y + d.y)
					placed += 1
				}
			}
		}
		return
	}
}

count_tenants :: proc(g: ^Game, index: int) -> int {
	n := 0
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind != .None && int(g.tenants[i].floor) == index {
			n += 1
		}
	}
	return n
}

// A generated floor you come back to has had a tenant move in for every RESTOCK_TURNS you were
// away, up to the number it started with (DESIGN.md "killed monsters slowly restock").
restock :: proc(g: ^Game, index: int) {
	f := &g.floors[index]
	if g.no_tenants || f.stock == 0 || f.left_turn == 0 {
		return
	}
	kinds: [len(Tenant_Kind)]Tenant_Kind
	n := 0
	for k in Tenant_Kind {
		if k != .None && k != .Carny && TENANT[k].first <= f.number {
			kinds[n] = k
			n += 1
		}
	}
	for _ in 0 ..< (g.turn - f.left_turn) / RESTOCK_TURNS {
		if count_tenants(g, index) >= f.stock {
			break
		}
		place_tenant(g, f, &g.rng, index, pick_kind(kinds[:n], &g.rng), false) // one at a time, never past the stock
	}
	f.left_turn = 0
}

tenant_at_floor :: proc(g: ^Game, index, x, y: int) -> int {
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind != .None && int(t.floor) == index && int(t.x) == x && int(t.y) == y {
			return i
		}
	}
	return 0
}

// The tenants on this floor take their turns.
tenants_act :: proc(g: ^Game) {
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind == .None || int(t.floor) != g.current {
			continue
		}
		t.energy += i16(giant_on_crate(g, t) ? 10 : TENANT[t.kind].speed) // on its crate the giant acts every turn
		for t.energy >= 10 && t.kind != .None {
			t.energy -= 10
			tenant_act(g, i)
			if g.mode == .Dead {
				return
			}
		}
	}
}

tenant_sees_you :: proc(g: ^Game, t: ^Tenant) -> bool {
	d := max(abs(int(t.x) - g.x), abs(int(t.y) - g.y))
	sight := g.lit ? TENANT_SIGHT : TENANT_DARK_SIGHT
	return d <= sight && line_clear(floor_of(g), int(t.x), int(t.y), g.x, g.y)
}

tenant_act :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	if info.prop {
		return
	}
	near := abs(int(t.x) - g.x) <= 1 && abs(int(t.y) - g.y) <= 1
	if t.kind == .Mimic && !t.awake {
		if near {
			t.awake = true
			t.tx, t.ty = i16(g.x), i16(g.y)
			say(g, "The pack was a mimic. It opens wide.")
		}
		return
	}
	if t.kind == .Draught {
		if near {
			draught_shoves(g, id)
		} else if rng_int(&g.rng, 2) == 0 {
			tenant_step(g, id, DIRECTIONS[rng_int(&g.rng, 8)])
		}
		return
	}
	if !hostile(t) {
		if t.still {
			return
		}
		if rng_int(&g.rng, 3) == 0 {
			tenant_step(g, id, DIRECTIONS[rng_int(&g.rng, 8)])
		}
		return
	}
	if tenant_sees_you(g, t) {
		if t.kind == .Peacock && !t.screamed {
			t.screamed = true
			peacock_screams(g, id)
		}
		t.awake = true
		t.tx, t.ty = i16(g.x), i16(g.y)
	}
	if t.kind == .Giant && giant_act(g, id) {
		return
	}
	// A bailiff with yer Jools runs from you.
	if t.kind == .Bailiff && held_jools(g, id) > 0 {
		best, best_d := [2]int{}, dist2(int(t.x), int(t.y), g.x, g.y)
		for d in DIRECTIONS {
			nd := dist2(int(t.x) + d.x, int(t.y) + d.y, g.x, g.y)
			if nd > best_d && tenant_can_enter(g, int(t.x) + d.x, int(t.y) + d.y) {
				best, best_d = d, nd
			}
		}
		if best != {} {
			tenant_step(g, id, best)
		}
		return
	}
	if t.kind == .Champion && !t.awake {
		return // he stands guard, very straight
	}
	if !t.awake || (info.erratic && rng_int(&g.rng, 3) == 0) {
		if rng_int(&g.rng, 2) == 0 {
			tenant_step(g, id, DIRECTIONS[rng_int(&g.rng, 8)])
		}
		return
	}
	if abs(int(t.x) - g.x) <= 1 && abs(int(t.y) - g.y) <= 1 {
		tenant_attack(g, id)
		return
	}
	if t.kind == .Goat && goat_charges(g, id) {
		return
	}
	// Close in on where it last saw you, by the step that brings it nearest.
	best, best_d := [2]int{}, dist2(int(t.x), int(t.y), int(t.tx), int(t.ty))
	for d in DIRECTIONS {
		nd := dist2(int(t.x) + d.x, int(t.y) + d.y, int(t.tx), int(t.ty))
		if nd < best_d && tenant_can_enter(g, int(t.x) + d.x, int(t.y) + d.y) {
			best, best_d = d, nd
		}
	}
	if best != {} {
		tenant_step(g, id, best)
	} else if int(t.x) == int(t.tx) && int(t.y) == int(t.ty) {
		t.awake = false // lost you
	}
}

dist2 :: proc(x0, y0, x1, y1: int) -> int {
	return (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)
}

tenant_can_enter :: proc(g: ^Game, x, y: int) -> bool {
	return passable(cell_at(g, x, y)) && tenant_at(g, x, y) == 0 && !(x == g.x && y == g.y)
}

tenant_step :: proc(g: ^Game, id: int, d: [2]int) {
	t := &g.tenants[id]
	if tenant_can_enter(g, int(t.x) + d.x, int(t.y) + d.y) {
		t.x += i16(d.x)
		t.y += i16(d.y)
	}
}

tenant_attack :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	hit := t.kind == .Champion ? champion_hit(g) : info.hit
	chance := clamp(hit - 4 * armour_worn(g) - DEX_DODGE * (g.attr[.Dexterity] - ATTR_BASE), 5, 95)
	missed := rng_int(&g.rng, 100) >= chance
	if missed {
		say(g, "The ", info.name, " misses.")
	}
	if t.kind == .Champion {
		champion_learns(g) // every turn he fights, hit or miss
	}
	if missed {
		return
	}
	if t.kind == .Bailiff {
		bailiff_takes(g, id)
		return
	}
	if t.kind == .Wisp {
		if g.lit {
			g.lit = false
			say(g, "The wisp touches yer ", light_name(g), ". It goes out. Enter/OK to relight.")
		} else {
			say(g, "The wisp brushes past you.")
		}
		return
	}
	up := giant_on_crate(g, t)
	say(g, "The ", info.name, " ", info.verb, up ? " you from its crate." : " you.")
	if rng_int(&g.rng, ARMOUR_WEAR) == 0 {
		pieces: [len(Slot)]int
		n := 0
		for i in 1 ..< MAX_ITEMS {
			if g.items[i].place == .Worn && KIND[g.items[i].kind].armour > 0 {
				pieces[n] = i
				n += 1
			}
		}
		if n > 0 {
			wear_down(g, pieces[rng_int(&g.rng, n)])
		}
	}
	hurt(g, up ? rng_range(&g.rng, GIANT_DMIN, GIANT_DMAX) : rng_range(&g.rng, info.dmin, info.dmax), info.a)
	if t.kind == .Bear && g.mode != .Dead && g.attr[.Strength] > 3 && rng_int(&g.rng, BEAR_DRAIN) == 0 {
		g.attr[.Strength] -= 1
		g.drained[.Strength] += 1
		say(g, "The maul leaves you weaker. Strength -1.")
	}
}

// The bailiff takes half the Jools in yer purse (rounded up) and keeps them until it is caught.
bailiff_takes :: proc(g: ^Game, id: int) {
	purse := worn(g, .Purse)
	coins := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Jools && g.items[i].place == .Inside && int(g.items[i].parent) == purse && purse != 0 {
			coins = i
		}
	}
	if coins == 0 {
		say(g, "The bailiff finds yer purse empty and writes you up.")
		return
	}
	buf: [8]u8
	take := (int(g.items[coins].count) + 1) / 2
	if take >= int(g.items[coins].count) {
		unplace(g, coins)
		g.items[coins].place, g.items[coins].parent = .Held, i16(id)
	} else {
		g.items[coins].count -= i32(take)
		got := new_item(g, .Jools, take)
		if got == 0 {
			return
		}
		g.items[got].place, g.items[got].parent = .Held, i16(id)
	}
	say(g, "The bailiff takes ", itoa(buf[:], take), " Jools. \"His Lordship's rent.\" It runs.")
}

// Jools a tenant has carried off.
held_jools :: proc(g: ^Game, id: int) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Held && int(g.items[i].parent) == id && g.items[i].kind == .Jools {
			n += int(g.items[i].count)
		}
	}
	return n
}

// Yer blow at a tenant (stepping into it). A turn passes.
player_attack :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	if info.prop {
		topple(g, id, false)
		end_turn(g)
		return
	}
	if t.kind == .Draught {
		say(g, "Yer blow goes straight through it.")
		end_turn(g)
		return
	}
	if disguised(t) {
		say(g, "The pack was a mimic!")
	} else if !hostile(t) {
		t.angry = true
		say(g, "The ", info.name, " shouts for the law. There is none.")
	}
	t.awake = true
	t.tx, t.ty = i16(g.x), i16(g.y)
	weapon := worn(g, .Weapon)
	dmin, dmax := 1, 2 // bare hands
	if weapon != 0 && KIND[g.items[weapon].kind].dmax > 0 {
		dmin, dmax = KIND[g.items[weapon].kind].dmin, KIND[g.items[weapon].kind].dmax
	}
	chance := clamp(PLAYER_HIT + DEX_AIM * (g.attr[.Dexterity] - ATTR_BASE) - info.defence, 5, 95)
	if rng_int(&g.rng, 100) >= chance {
		say(g, "You miss the ", info.name, ".")
		play_sound(g, .Miss)
	} else {
		play_sound(g, .Hit)
		dmg := max(1, rng_range(&g.rng, dmin, dmax) + damage_bonus(g))
		t.health -= i16(dmg)
		if t.kind == .Champion && int(t.health) <= CHAMPION_YIELD {
			champion_yields(g, id)
		} else if t.health <= 0 {
			kill_tenant(g, id)
		} else {
			say(g, "You hit the ", info.name, ".")
		}
		if weapon != 0 && rng_int(&g.rng, WEAPON_WEAR) == 0 {
			wear_down(g, weapon)
		}
	}
	end_turn(g)
}

kill_tenant :: proc(g: ^Game, id: int) {
	if g.tenants[id].kind == .Champion {
		champion_yields(g, id) // he never dies
		return
	}
	t := g.tenants[id]
	info := TENANT[t.kind]
	g.tenants[id] = {}
	g.xp += info.xp
	g.kills += 1
	say(g, "You kill the ", info.name, ".")
	check_level(g)
	drop_at :: proc(g: ^Game, t: Tenant, kind: Item_Kind, count: int) {
		item := new_item(g, kind, count)
		if item != 0 {
			it := &g.items[item]
			it.place, it.floor, it.x, it.y = .Ground, t.floor, t.x, t.y
		}
	}
	// What it carried off falls where it dies.
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place == .Held && int(it.parent) == id {
			it.place, it.floor, it.x, it.y, it.parent = .Ground, t.floor, t.x, t.y, 0
		}
	}
	if t.kind == .Goblin && rng_int(&g.rng, GOBLIN_DAGGER) == 0 {
		drop_at(g, t, .Dagger, 1)
	}
	if t.kind == .Skeleton {
		boss_falls(g, t)
	} else if t.kind == .Sergeant {
		sergeant_falls(g, t)
	} else if t.kind == .Giant {
		giant_falls(g, t)
	} else if t.kind == .Carny || t.kind == .Hermit || t.kind == .Cartographer {
		drop_at(g, t, .Jools, rng_range(&g.rng, 5, 20))
	} else if info.trophy != .None && rng_int(&g.rng, 100) < info.chance {
		drop_at(g, t, info.trophy, 1)
	}
}

// Use wears a weapon or a piece of armour; at nothing left it breaks. Warnings at half and a fifth.
wear_down :: proc(g: ^Game, id: int) {
	it := &g.items[id]
	full := KIND[it.kind].durability
	if full == 0 {
		return
	}
	it.dur -= 1
	name_buf: [32]u8
	n := copy(name_buf[:], item_name(g, id))
	name := string(name_buf[:n])
	switch {
	case it.dur <= 0:
		free_item(g, id)
		say(g, "Yer ", name, " breaks!")
	case int(it.dur) * 5 == full:
		say(g, "Yer ", name, " is about to break.")
	case int(it.dur) * 2 == full:
		say(g, "Yer ", name, " is wearing thin.")
	}
}

// Gusts carry light tenants a cell downwind when there is room.
blow_tenants :: proc(g: ^Game) -> (moved: int) {
	d := wind_blow(floor_of(g))
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind != .None && int(t.floor) == g.current && TENANT[t.kind].light {
			before := [2]i16{t.x, t.y}
			for _ in 0 ..< gust_push(floor_of(g).number) {
				tenant_step(g, i, d)
			}
			if before != {t.x, t.y} {
				moved += 1
			}
		}
		if t.kind != .None && int(t.floor) == g.current && TENANT[t.kind].prop && rng_int(&g.rng, TOPPLE_CHANCE) == 0 {
			topple(g, i, true)
		}
		if giant_on_crate(g, t) && int(t.floor) == g.current && rng_int(&g.rng, CRATE_TIP) == 0 {
			tip_crate(g, i, d, true)
		}
	}
	return
}

draw_tenants :: proc(f: ^Frame, g: ^Game) {
	ox, oy := view_origin(g)
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind == .None || int(t.floor) != g.current {
			continue
		}
		sensed := !g.vis[t.y][t.x]
		if sensed && g.sense_turns <= 0 {
			continue
		}
		vx, vy := int(t.x) - ox, int(t.y) - oy
		if vx < 0 || vy < 0 || vx >= VIEW_W || vy >= VIEW_H {
			continue
		}
		sx, sy := MAP_X + vx * TILE, MAP_Y + vy * TILE
		fill_rect(f, sx, sy, TILE, TILE, COLOR_BLACK)
		if disguised(t) && !sensed { // Sense Tenants shows it for what it is
			draw_gfx(f, KIND[.Pack].gfx, sx, sy, KIND[.Pack].color)
			continue
		}
		if giant_on_crate(g, t) {
			// The top of the crate in the lower half of the cell, and the giant standing on it, half a
			// cell taller than everyone else.
			draw_gfx_rows(f, KIND[.Crate].gfx, sx, sy + GIANT_LIFT, sensed ? COLOR_MID : KIND[.Crate].color, 0, TILE - GIANT_LIFT)
			draw_gfx_rows(f, TENANT[t.kind].gfx, sx, sy - GIANT_LIFT, sensed ? COLOR_MID : TENANT[t.kind].color, 0, TILE)
			continue
		}
		draw_gfx(f, TENANT[t.kind].gfx, sx, sy, sensed ? COLOR_MID : TENANT[t.kind].color)
	}
}

inspect_tenant :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	if disguised(t) {
		say(g, "A pack. Somebody left it here.")
		return
	}
	if t.kind == .Lord {
		say(g, g.lord_met ? "His Lordship. " : "", info.line)
		return
	}
	hurt := int(t.health) * 2 < info.health
	line := info.line
	if t.kind == .Giant && !g.giant_up {
		line = TENANT[.Ogre].line
	}
	say(g, "A ", info.name, hurt ? " (hurt). " : ". ", line)
}

// A draught next to you pushes you a cell away from it; into a wall or a tenant it slams you, as a
// gust does (slice 3 step 18).
draught_shoves :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	d := [2]int{clamp(g.x - int(t.x), -1, 1), clamp(g.y - int(t.y), -1, 1)}
	nx, ny := g.x + d.x, g.y + d.y
	stop_travel(g)
	if !passable(cell_at(g, nx, ny)) {
		say(g, "A draught slams you into the wall.")
		play_sound(g, .Slam)
		hurt(g, 1, "a draught")
		return
	}
	if other := tenant_at(g, nx, ny); other != 0 {
		say(g, "A draught slams you into ", TENANT[g.tenants[other].kind].a, ".")
		hurt(g, 1, "a draught")
		return
	}
	g.x, g.y = nx, ny
	say(g, "A draught shoves you ", COMPASS[direction_index(d)], ".")
	refresh_view(g)
}

// Any spell that reaches a draught seals it (slice 3 step 18).
seal_draught :: proc(g: ^Game, id: int) {
	g.tenants[id] = {}
	g.xp += TENANT[.Draught].xp
	say(g, "The draught is sealed.")
	check_level(g)
}

PEACOCK_CALL :: 10 // the hundred-eyed beast's scream wakes hostile tenants this many cells round it
GOAT_CHARGE :: 3 // the demon charges from this far, in a straight line
SLAM_MIN :: 1 // a butt into a wall or a tenant hurts this much more
SLAM_MAX :: 3

// The hundred-eyed beast sees you for the first time and screams: every hostile tenant on the floor within
// PEACOCK_CALL cells wakes and knows where you are (slice 4 step 25).
peacock_screams :: proc(g: ^Game, id: int) {
	p := g.tenants[id]
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if i == id || t.kind == .None || int(t.floor) != g.current || !hostile(t) || TENANT[t.kind].prop || disguised(t) {
			continue
		}
		if max(abs(int(t.x) - int(p.x)), abs(int(t.y) - int(p.y))) <= PEACOCK_CALL {
			t.awake = true
			t.tx, t.ty = i16(g.x), i16(g.y)
		}
	}
	stop_travel(g)
	say(g, "The hundred-eyed beast screams. Everything near heard that.")
}

// The demon, 2 or 3 cells off in a straight line with nothing between, rushes up and butts you
// a cell back (into a wall or a tenant, a slam). False when it has no line to charge along.
goat_charges :: proc(g: ^Game, id: int) -> bool {
	t := &g.tenants[id]
	dx, dy := g.x - int(t.x), g.y - int(t.y)
	far := max(abs(dx), abs(dy))
	if far < 2 || far > GOAT_CHARGE || !(dx == 0 || dy == 0 || abs(dx) == abs(dy)) {
		return false
	}
	d := [2]int{clamp(dx, -1, 1), clamp(dy, -1, 1)}
	for k in 1 ..< far {
		if !tenant_can_enter(g, int(t.x) + k * d.x, int(t.y) + k * d.y) {
			return false
		}
	}
	t.x, t.y = i16(g.x - d.x), i16(g.y - d.y)
	info := TENANT[t.kind]
	chance := clamp(info.hit - 4 * armour_worn(g) - DEX_DODGE * (g.attr[.Dexterity] - ATTR_BASE), 5, 95)
	if g.vis[t.y][t.x] {
		say(g, "The demon charges.")
	}
	if rng_int(&g.rng, 100) >= chance {
		say(g, "The demon misses.")
		return true
	}
	stop_travel(g)
	hurt(g, rng_range(&g.rng, info.dmin, info.dmax), info.a)
	if g.mode == .Dead {
		return true
	}
	nx, ny := g.x + d.x, g.y + d.y
	blocked := ""
	if !passable(cell_at(g, nx, ny)) {
		blocked = "the wall"
	} else if other := tenant_at(g, nx, ny); other != 0 {
		blocked = TENANT[g.tenants[other].kind].a
	}
	if blocked != "" {
		say(g, "The demon butts you into ", blocked, ".")
		hurt(g, rng_range(&g.rng, SLAM_MIN, SLAM_MAX), info.a)
		return true
	}
	g.x, g.y = nx, ny
	say(g, "The demon butts you ", COMPASS[direction_index(d)], ".")
	refresh_view(g)
	return true
}
