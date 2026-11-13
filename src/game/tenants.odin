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
	tx, ty:   i16, // where it last saw you
}

MAX_TENANTS :: 320 // id 0 is never used
TENANT_SIGHT :: 8 // how far a tenant sees a lit climber
TENANT_DARK_SIGHT :: 2 // and one in the dark
PLAYER_HIT :: 60 // chance in 100 to land a blow, before Dexterity and the tenant's defence
DEX_AIM :: 2 // chance in 100 to land a blow per point of Dexterity above 10 (was 4 until November 12, 2026)
DEX_DODGE :: 1 // and taken off a tenant's chance to hit you (was 2)
WEAPON_WEAR :: 3 // a blow you land wears yer weapon one time in this many
ARMOUR_WEAR :: 2 // a blow that lands on you wears a piece of armour one time in this many

new_tenant :: proc(g: ^Game, kind: Tenant_Kind, floor, x, y: int) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .None {
			g.tenants[i] = Tenant{kind = kind, floor = i8(floor), x = i16(x), y = i16(y), health = i16(TENANT[kind].health)}
			return i
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
	return t.kind != .None && (!TENANT[t.kind].peaceful || t.angry)
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
	place :: proc(g: ^Game, f: ^Floor, r: ^Rng, index: int, kind: Tenant_Kind) {
		for _ in 0 ..< 100 {
			room := f.rooms[1 + rng_int(r, f.room_count - 1)]
			x, y := room.x + rng_int(r, room.w), room.y + rng_int(r, room.h)
			if f.cells[y][x] != .Floor || tenant_at_floor(g, index, x, y) != 0 {
				continue
			}
			new_tenant(g, kind, index, x, y)
			return
		}
	}
	for _ in 0 ..< 4 + 2 * f.number {
		place(g, f, r, index, kinds[rng_int(r, n)])
	}
	if f.number == 3 {
		place(g, f, r, index, .Carny)
	}
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
		t.energy += i16(TENANT[t.kind].speed)
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
		t.awake = true
		t.tx, t.ty = i16(g.x), i16(g.y)
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
	chance := clamp(info.hit - 4 * armour_worn(g) - DEX_DODGE * (g.attr[.Dexterity] - ATTR_BASE), 5, 95)
	if rng_int(&g.rng, 100) >= chance {
		say(g, "The ", info.name, " misses.")
		return
	}
	say(g, "The ", info.name, " ", info.verb, " you.")
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
	hurt(g, rng_range(&g.rng, info.dmin, info.dmax), info.a)
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
	if !hostile(t) {
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
	} else {
		dmg := max(1, rng_range(&g.rng, dmin, dmax) + damage_bonus(g))
		t.health -= i16(dmg)
		if t.health <= 0 {
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
	if t.kind == .Skeleton {
		boss_falls(g, t)
	} else if t.kind == .Carny {
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
blow_tenants :: proc(g: ^Game) {
	d := wind_blow(floor_of(g))
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind != .None && int(t.floor) == g.current && TENANT[t.kind].light {
			for _ in 0 ..< gust_push(floor_of(g).number) {
				tenant_step(g, i, d)
			}
		}
		if t.kind != .None && int(t.floor) == g.current && TENANT[t.kind].prop && rng_int(&g.rng, TOPPLE_CHANCE) == 0 {
			topple(g, i, true)
		}
	}
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
		draw_gfx(f, TENANT[t.kind].gfx, sx, sy, sensed ? COLOR_MID : TENANT[t.kind].color)
	}
}

inspect_tenant :: proc(g: ^Game, id: int) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	hurt := int(t.health) * 2 < info.health
	say(g, "A ", info.name, hurt ? " (hurt). " : ". ", info.line)
}
