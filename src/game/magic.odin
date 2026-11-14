package game

// Magic (slice 1 step 5; DESIGN.md "Character: no classes, four attributes, a spell per level",
// "Ranged: spells only, and the wind bends them", "Aiming: eight directions, no preview"). Mana
// comes from Intelligence and grows with levels; each level, the first included, you choose a
// spell. Aimed spells fly one of eight ways and the floor's wind bends them: they go farther with
// the wind and less far into it, and every few cells they drift a cell downwind. The path a spell
// took stays drawn until yer next action, so the wind can be learned; there is no preview.

Spell :: enum u8 {
	Magic_Bolt,
	Gust_Ball,
	Ward,
	Mend,
	Hop,
	Return,
	Sense_Tenants,
	Identify,
	Kindle,
	Anchor,
}

Spell_Info :: struct {
	name:  string,
	cost:  int,
	aimed: bool,
	ready: bool, // false until the step that gives it something to do
	use:   string, // one short line for the choosing screen (23 characters at most)
}

SPELL := [Spell]Spell_Info {
	.Magic_Bolt    = {"Magic Bolt", 3, true, true, "a bolt; wind bends it"},
	.Gust_Ball     = {"Gust Ball", 6, true, true, "blast where wind takes"},
	.Ward          = {"Ward", 4, false, true, "armour +3, 40 turns"},
	.Mend          = {"Mend", 4, false, true, "heal a little"},
	.Hop           = {"Hop", 3, false, true, "jump to a nearby spot"},
	.Return        = {"Return", 8, false, true, "back to the town gate"},
	.Sense_Tenants = {"Sense Tenants", 4, false, true, "show tenants, 30 turns"},
	.Identify      = {"Identify", 5, false, true, "name one thing carried"},
	.Kindle        = {"Kindle", 1, false, true, "light torch, no turn"},
	.Anchor        = {"Anchor", 2, false, true, "hold fast, one gust"},
}

// Tuning (PLAN.md step 5; to review).
BOLT_RANGE :: 7 // cells, plus how much the wind is behind it (-2 to +2)
BOLT_DRIFT :: 3 // a magic bolt drifts a cell downwind every this many cells
BALL_RANGE :: 5
BALL_DRIFT :: 2 // a gust ball is lighter: it drifts every second cell
WARD_TURNS :: 40
WARD_ARMOUR :: 3
SENSE_TURNS :: 30
HOP_MIN :: 2
HOP_MAX :: 6
LEVEL_HEALTH :: 2 // more health per level after the first
LEVEL_MANA :: 2
MAX_FX :: 32

// XP needed for each level (level 1 needs none); past the table, 30 more per level.
LEVEL_XP := [?]int{0, 0, 10, 25, 45, 70, 100}

xp_for_level :: proc(level: int) -> int {
	if level < len(LEVEL_XP) {
		return LEVEL_XP[level]
	}
	return LEVEL_XP[len(LEVEL_XP) - 1] + 30 * (level - len(LEVEL_XP) + 1)
}

max_mana :: proc(g: ^Game) -> int {
	return g.attr[.Intelligence] + LEVEL_MANA * (g.level - 1)
}

// Turns between each point of mana coming back.
mana_period :: proc(g: ^Game) -> int {
	return max(4, 25 - g.attr[.Intelligence])
}

// Added to spell damage and healing.
spell_bonus :: proc(g: ^Game) -> int {
	return (g.attr[.Intelligence] - ATTR_BASE) / 3
}

// Called when XP is gained: each level reached adds health and mana and owes a spell choice.
check_level :: proc(g: ^Game) {
	buf: [8]u8
	for g.xp >= xp_for_level(g.level + 1) {
		g.level += 1
		g.health += LEVEL_HEALTH
		g.mana += LEVEL_MANA
		g.learns += 1
		say(g, "You reach level ", itoa(buf[:], g.level), ".")
	}
}

// Spells that can still be chosen.
learnable :: proc(g: ^Game, out: ^[len(Spell)]Spell) -> int {
	n := 0
	for s in Spell {
		if SPELL[s].ready && s not_in g.known {
			out[n] = s
			n += 1
		}
	}
	return n
}

// After an action: a spell choice that is owed opens the choosing screen.
open_learn_if_owed :: proc(g: ^Game) {
	if g.mode != .Play || g.learns <= 0 {
		return
	}
	list: [len(Spell)]Spell
	if learnable(g, &list) == 0 {
		g.learns = 0
		return
	}
	stop_travel(g)
	g.mode = .Learn
	g.menu_row = 0
}

learn :: proc(g: ^Game, s: Spell) {
	g.known += {s}
	g.learns -= 1
	say(g, "You learn ", SPELL[s].name, ". C or Cast to use it.")
	g.mode = .Play
	open_learn_if_owed(g)
}

learn_command :: proc(g: ^Game, c: Command) {
	list: [len(Spell)]Spell
	n := learnable(g, &list)
	#partial switch c {
	case .North, .North_West, .North_East:
		g.menu_row = (g.menu_row + n - 1) % n
	case .South, .South_West, .South_East:
		g.menu_row = (g.menu_row + 1) % n
	case .Confirm:
		learn(g, list[g.menu_row])
	}
}

// Known spells, in table order.
known_list :: proc(g: ^Game, out: ^[len(Spell)]Spell) -> int {
	n := 0
	for s in Spell {
		if s in g.known {
			out[n] = s
			n += 1
		}
	}
	return n
}

open_cast :: proc(g: ^Game) {
	list: [len(Spell)]Spell
	if known_list(g, &list) == 0 {
		say(g, "You know no spells yet.")
		return
	}
	g.mode = .Cast
	g.menu_row = 0
}

cast_command :: proc(g: ^Game, c: Command) {
	list: [len(Spell)]Spell
	n := known_list(g, &list)
	#partial switch c {
	case .North, .North_West, .North_East:
		g.menu_row = (g.menu_row + n - 1) % n
	case .South, .South_West, .South_East:
		g.menu_row = (g.menu_row + 1) % n
	case .Confirm:
		choose_spell(g, list[g.menu_row])
	case .Cancel, .Cast:
		g.mode = .Play
	}
}

// A spell picked from the list: aimed ones ask for a direction, the rest happen at once.
choose_spell :: proc(g: ^Game, s: Spell) {
	g.mode = .Play
	if s == .Kindle && g.lit {
		say(g, "Yer ", light_name(g), " already burns.")
		return
	}
	if SPELL[s].aimed {
		g.mode = .Aim
		g.aim_spell = s
		say(g, SPELL[s].name, ": which way? Esc/Back to cancel.")
		return
	}
	cast_spell(g, s, {0, 0})
}

aim_command :: proc(g: ^Game, c: Command) {
	#partial switch c {
	case .North, .South, .West, .East, .North_West, .North_East, .South_West, .South_East:
		g.mode = .Play
		cast_spell(g, g.aim_spell, DIRECTION[c])
	case .Cancel, .Cast:
		g.mode = .Play
		say(g, "You let the spell go.")
	}
}

// A click or tap while aiming: the direction toward it (yerself cancels).
aim_pointer :: proc(g: ^Game, sx, sy: int) {
	x, y, ok := screen_to_cell(g, sx, sy)
	if !ok {
		return
	}
	d := [2]int{sign(x - g.x), sign(y - g.y)}
	g.mode = .Play
	if d == {0, 0} {
		say(g, "You let the spell go.")
		return
	}
	cast_spell(g, g.aim_spell, d)
}

cast_spell :: proc(g: ^Game, s: Spell, d: [2]int) {
	info := SPELL[s]
	// Short of mana, the spell goes off anyway and each missing point costs a point of health
	// (the user's choice, November 10, 2026; Castle of the Winds risked Constitution).
	short := max(0, info.cost - g.mana)
	g.mana = max(0, g.mana - info.cost)
	if short > 0 {
		buf: [8]u8
		say(g, "Short of mana, the spell takes ", itoa(buf[:], short), " health.")
		hurt(g, short, "casting past yer mana")
		if g.mode == .Dead {
			return
		}
	}
	turn := true
	switch s {
	case .Magic_Bolt:
		cast_bolt(g, d, false)
	case .Gust_Ball:
		cast_bolt(g, d, true)
	case .Ward:
		g.ward_turns = WARD_TURNS
		say(g, "The air stiffens round you.")
	case .Mend:
		before := g.health
		g.health = min(max_health(g), g.health + rng_range(&g.rng, 4, 6) + spell_bonus(g))
		buf: [8]u8
		say(g, "You mend ", itoa(buf[:], g.health - before), " health.")
	case .Hop:
		hop(g)
	case .Return:
		say(g, "The wind sets you down at the town gate.")
		enter_town(g, .Gate)
		turn = false
	case .Sense_Tenants:
		g.sense_turns = SENSE_TURNS
		say(g, "You feel who pays rent on this floor.")
	case .Identify:
		start_identify(g)
	case .Kindle:
		turn = false
		light_torch(g, false)
	case .Anchor:
		g.anchor_spell = true
		say(g, "You feel heavy until the next gust has passed.")
	}
	if turn {
		end_turn(g)
	}
}

hop :: proc(g: ^Game) {
	f := floor_of(g)
	for _ in 0 ..< 60 {
		x := g.x + rng_range(&g.rng, -HOP_MAX, HOP_MAX)
		y := g.y + rng_range(&g.rng, -HOP_MAX, HOP_MAX)
		if max(abs(x - g.x), abs(y - g.y)) < HOP_MIN || !passable(floor_cell(f, x, y)) || tenant_at(g, x, y) != 0 {
			continue
		}
		g.x, g.y = x, y
		refresh_view(g)
		say(g, "You hop.")
		return
	}
	say(g, "The spell finds nowhere to put you.")
}

// A magic bolt or a gust ball, thrown one of eight ways. It flies cell by cell, drifting a cell
// downwind every few cells (unless the wind is along its line), and stops at a wall, a tenant or
// the end of its range. A bolt hurts the tenant it meets; a ball bursts over the three by three
// cells where it stops, yerself included.
cast_bolt :: proc(g: ^Game, d: [2]int, ball: bool) {
	f := floor_of(g)
	w := wind_blow(f)
	along := w == d || w == -d
	reach := (ball ? BALL_RANGE : BOLT_RANGE) + d.x * w.x + d.y * w.y
	drift := ball ? BALL_DRIFT : BOLT_DRIFT
	name := ball ? "gust ball" : "bolt"
	g.fx_len, g.fx_blast = 0, false
	pos := [2]int{g.x, g.y}
	hit := 0
	wall := false
	move :: proc(g: ^Game, f: ^Floor, pos: ^[2]int, by: [2]int) -> (hit: int, wall: bool) {
		next := pos^ + by
		if !passable(floor_cell(f, next.x, next.y)) {
			return 0, true
		}
		pos^ = next
		if g.fx_len < MAX_FX {
			g.fx[g.fx_len] = next
			g.fx_len += 1
		}
		return tenant_at(g, next.x, next.y), false
	}
	for step in 1 ..= max(1, reach) {
		hit, wall = move(g, f, &pos, d)
		if hit != 0 || wall {
			break
		}
		if !along && step % drift == 0 {
			hit, wall = move(g, f, &pos, w)
			if hit != 0 || wall {
				break
			}
		}
	}
	if !ball {
		if hit != 0 {
			spell_hit(g, hit, rng_range(&g.rng, 2, 6) + spell_bonus(g), name)
		} else if wall {
			say(g, "The bolt fizzles against the wall.")
		} else {
			say(g, "The bolt blows away.")
		}
		return
	}
	g.fx_blast, g.fx_at = true, pos
	say(g, "The gust ball bursts.")
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			x, y := pos.x + dx, pos.y + dy
			if id := tenant_at(g, x, y); id != 0 {
				spell_hit(g, id, rng_range(&g.rng, 2, 5) + spell_bonus(g), name)
			}
			if x == g.x && y == g.y && g.mode != .Dead {
				say(g, "Yer own gust ball catches you.")
				hurt(g, rng_range(&g.rng, 2, 5), "yer own gust ball")
			}
		}
	}
}

spell_hit :: proc(g: ^Game, id: int, dmg: int, what: string) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	if info.prop {
		topple(g, id, false)
		return
	}
	if !hostile(t) {
		t.angry = true
		say(g, "The ", info.name, " shouts for the law. There is none.")
	}
	t.awake = true
	t.tx, t.ty = i16(g.x), i16(g.y)
	t.health -= i16(max(1, dmg))
	if t.health <= 0 {
		kill_tenant(g, id)
	} else {
		say(g, "The ", what, " hits the ", info.name, ".")
	}
}

// Timed spells run down once a turn (end_turn).
magic_turn :: proc(g: ^Game) {
	if g.ward_turns > 0 {
		g.ward_turns -= 1
		if g.ward_turns == 0 {
			say(g, "Yer ward fades.")
		}
	}
	if g.sense_turns > 0 {
		g.sense_turns -= 1
	}
	if g.turn % mana_period(g) == 0 && g.mana < max_mana(g) {
		g.mana += 1
	}
}

// Screens: choosing a spell at a level, and casting one. Rows in the map area.
MENU_TOP :: 30
MENU_ROW_H :: 14
MENU_COST_X :: 96
MENU_USE_X :: 112

menu_pointer :: proc(g: ^Game, sx, sy: int, n: int) -> int {
	if sx >= VIEW_W * TILE {
		return -1
	}
	for row in 0 ..< n {
		y := MENU_TOP + row * MENU_ROW_H
		if sy >= y - 3 && sy < y + MENU_ROW_H - 3 {
			return row
		}
	}
	return -1
}

learn_pointer :: proc(g: ^Game, sx, sy: int) {
	list: [len(Spell)]Spell
	n := learnable(g, &list)
	if row := menu_pointer(g, sx, sy, n); row >= 0 {
		learn(g, list[row])
	}
}

cast_pointer :: proc(g: ^Game, sx, sy: int) {
	list: [len(Spell)]Spell
	n := known_list(g, &list)
	if row := menu_pointer(g, sx, sy, n); row >= 0 {
		choose_spell(g, list[row])
	} else {
		g.mode = .Play
	}
}

draw_spell_rows :: proc(f: ^Frame, g: ^Game, list: []Spell, casting: bool) {
	buf: [8]u8
	for s, i in list {
		y := MENU_TOP + i * MENU_ROW_H
		if g.menu_row == i {
			fill_rect(f, 2, y - 3, VIEW_W * TILE - 4, MENU_ROW_H, COLOR_DARK)
			print(f, ">", 4, y, COLOR_YELLOW)
		}
		// Short of mana, the cost shows orange: the rest comes out of health.
		afford := !casting || g.mana >= SPELL[s].cost
		print(f, SPELL[s].name, 12, y, COLOR_LIGHT)
		print(f, itoa(buf[:], SPELL[s].cost), MENU_COST_X, y, afford ? COLOR_CYAN : COLOR_ORANGE)
		print(f, SPELL[s].use, MENU_USE_X, y, COLOR_MID)
	}
}

draw_learn :: proc(f: ^Frame, g: ^Game) {
	list: [len(Spell)]Spell
	n := learnable(g, &list)
	buf: [8]u8
	if g.level <= 1 {
		print(f, "Choose yer first spell", 12, 6, COLOR_CYAN)
	} else {
		w := print(f, "Level ", 12, 6, COLOR_CYAN)
		w += print(f, itoa(buf[:], g.level), 12 + w, 6, COLOR_CYAN)
		print(f, ": choose a spell", 12 + w, 6, COLOR_CYAN)
	}
	print(f, "mana", MENU_COST_X - 6, 18, COLOR_DARK)
	draw_spell_rows(f, g, list[:n], false)
	print(f, "Up/Down: pick   Enter/OK or click: learn", 6, VIEW_H * TILE - 10, COLOR_DARK)
}

draw_cast :: proc(f: ^Frame, g: ^Game) {
	list: [len(Spell)]Spell
	n := known_list(g, &list)
	buf: [8]u8
	w := print(f, "Cast which spell?  Mana ", 12, 6, COLOR_CYAN)
	w += print(f, itoa(buf[:], g.mana), 12 + w, 6, COLOR_CYAN)
	w += print(f, "/", 12 + w, 6, COLOR_DARK)
	print(f, itoa(buf[:], max_mana(g)), 12 + w, 6, COLOR_DARK)
	print(f, "mana", MENU_COST_X - 6, 18, COLOR_DARK)
	draw_spell_rows(f, g, list[:n], true)
	if short := SPELL[list[g.menu_row]].cost - g.mana; short > 0 {
		w = print(f, "Short of mana: it will cost ", 6, VIEW_H * TILE - 10, COLOR_ORANGE)
		w += print(f, itoa(buf[:], short), 6 + w, VIEW_H * TILE - 10, COLOR_ORANGE)
		print(f, " health", 6 + w, VIEW_H * TILE - 10, COLOR_ORANGE)
	} else {
		print(f, "Enter/OK or click: cast   Esc/Back: close", 6, VIEW_H * TILE - 10, COLOR_DARK)
	}
}

// The path the last spell took (until yer next action), and the cells around you while aiming.
draw_magic :: proc(f: ^Frame, g: ^Game) {
	ox, oy := view_origin(g)
	on_view :: proc(x, y, ox, oy: int) -> (sx, sy: int, ok: bool) {
		vx, vy := x - ox, y - oy
		if vx < 0 || vy < 0 || vx >= VIEW_W || vy >= VIEW_H {
			return 0, 0, false
		}
		return MAP_X + vx * TILE, MAP_Y + vy * TILE, true
	}
	for i in 0 ..< g.fx_len {
		if sx, sy, ok := on_view(g.fx[i].x, g.fx[i].y, ox, oy); ok {
			fill_rect(f, sx + 4, sy + 4, 4, 4, COLOR_CYAN)
		}
	}
	if g.fx_blast {
		for dy in -1 ..= 1 {
			for dx in -1 ..= 1 {
				if sx, sy, ok := on_view(g.fx_at.x + dx, g.fx_at.y + dy, ox, oy); ok {
					outline(f, sx, sy, TILE, TILE, COLOR_ORANGE)
				}
			}
		}
	}
	if g.mode == .Aim {
		for d in DIRECTIONS {
			if sx, sy, ok := on_view(g.x + d.x, g.y + d.y, ox, oy); ok {
				outline(f, sx, sy, TILE, TILE, COLOR_YELLOW)
			}
		}
	}
}

outline :: proc(f: ^Frame, x, y, w, h: int, c: u8) {
	fill_rect(f, x, y, w, 1, c)
	fill_rect(f, x, y + h - 1, w, 1, c)
	fill_rect(f, x, y, 1, h, c)
	fill_rect(f, x + w - 1, y, 1, h, c)
}
