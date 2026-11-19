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
	// From level 5 (slice 2 step 14).
	Gale,
	Calm,
	Sense_Things,
	Blink,
	// From level 9 (slice 3 step 21).
	Uncurse,
	Find_Stairs, // Clairvoyance until the step 21 review (never pushed)
	Teleport,
	Squall,
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
	.Gale          = {"Gale", 5, true, true, "shove tenants in a line"},
	.Calm          = {"Calm", 4, false, true, "no gusts, 30 turns"},
	.Sense_Things  = {"Sense Things", 3, false, true, "show items, 30 turns"},
	.Blink         = {"Blink", 4, true, true, "jump 4; wind bends it"},
	.Uncurse       = {"Uncurse", 6, false, true, "free what you wear"},
	.Find_Stairs   = {"Find the Stairs", 2, false, true, "show the way up"},
	.Teleport      = {"Teleport", 7, false, true, "far across the floor"},
	.Squall        = {"Squall", 8, true, true, "big blast, spares you"},
}

// The level a spell can first be chosen at: slice 2's four from level 5, slice 3's from level 9.
spell_level :: proc(s: Spell) -> int {
	#partial switch s {
	case .Gale, .Calm, .Sense_Things, .Blink:
		return SLICE2_SPELL_LEVEL
	case .Uncurse, .Find_Stairs, .Teleport, .Squall:
		return SLICE3_SPELL_LEVEL
	}
	return 1
}

// Tuning (PLAN.md step 5; to review).
BOLT_RANGE :: 7 // cells, plus how much the wind is behind it (-2 to +2)
BOLT_DRIFT :: 3 // a magic bolt drifts a cell downwind every this many cells
BALL_RANGE :: 5
BALL_DRIFT :: 2 // a gust ball is lighter: it drifts every second cell
WARD_TURNS :: 40
WARD_ARMOUR :: 3
SENSE_TURNS :: 30
SLICE2_SPELL_LEVEL :: 5
SLICE3_SPELL_LEVEL :: 9
TELEPORT_MIN :: 20 // Teleport lands at least this far away (Hop goes only 2 to 6)
SQUALL_RANGE :: 4 // a squall flies like a gust ball, drifting every second cell
GALE_RANGE :: 6 // cells along the line it shoves
GALE_SHOVE :: 3 // cells a tenant is shoved, plus how much the wind is behind it (-2 to +2)
CALM_TURNS :: 30
SENSE_THINGS_TURNS :: 30
BLINK_RANGE :: 4 // cells, plus how much the wind is behind it; drifts like a bolt
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
		if SPELL[s].ready && s not_in g.known && spell_level(s) <= g.level {
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
	g.spell_scroll = 0
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
	keep_spell_row(g)
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
	g.spell_scroll = 0
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
	keep_spell_row(g)
}

// Scrolls the spell list so the chosen row shows (18 spells do not fit; slice 3 step 21).
keep_spell_row :: proc(g: ^Game) {
	if g.menu_row < g.spell_scroll {
		g.spell_scroll = g.menu_row
	} else if g.menu_row >= g.spell_scroll + SPELL_ROWS {
		g.spell_scroll = g.menu_row - SPELL_ROWS + 1
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
	case .Gale:
		cast_gale(g, d)
	case .Calm:
		g.calm_turns = CALM_TURNS
		say(g, "The air goes still round you.")
	case .Sense_Things:
		g.sense_items = SENSE_THINGS_TURNS
		say(g, "You feel what lies about on this floor.")
	case .Blink:
		blink(g, d)
	case .Uncurse:
		say(g, uncurse_worn(g) ? "A weight lifts. What you wear will come off now." : "Nothing you wear was cursed.")
	case .Find_Stairs:
		find_stairs(g)
	case .Teleport:
		teleport_far(g)
	case .Squall:
		cast_bolt(g, d, true, true)
	}
	if turn {
		end_turn(g)
	}
}

// Frees everything worn of its curse, as the scroll does. True when something was cursed.
uncurse_worn :: proc(g: ^Game) -> bool {
	lifted := false
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Worn && g.items[i].cursed {
			g.items[i].cursed = false
			lifted = true
		}
	}
	return lifted
}

// Marks a box of a floor as seen: every open cell in it, and the walls round them (the
// cartographer's maps, and each cell on the way Find the Stairs draws).
reveal :: proc(f: ^Floor, x0, y0, x1, y1: int) {
	for y in max(0, y0) ..= min(FLOOR_H - 1, y1) {
		for x in max(0, x0) ..= min(FLOOR_W - 1, x1) {
			if f.cells[y][x] == .Wall {
				continue
			}
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

// Find the Stairs (the step 21 review, November 19, 2026, in place of Clairvoyance, since the
// cartographer sells maps): the shortest way to the floor's stairs up, over every open cell seen or
// not, is drawn on yer map with the stairs at its end. Tenants do not block it; walls do.
find_stairs :: proc(g: ^Game) {
	f := floor_of(g)
	goal := f.up
	from: [FLOOR_H][FLOOR_W][2]i16
	reached: [FLOOR_H][FLOOR_W]bool
	queue: [FLOOR_H * FLOOR_W][2]int
	head, tail := 0, 0
	queue[tail] = {g.x, g.y}
	tail += 1
	reached[g.y][g.x] = true
	for head < tail {
		c := queue[head]
		head += 1
		if c == goal {
			break
		}
		for d in DIRECTIONS {
			n := c + d
			if n.x < 0 || n.y < 0 || n.x >= FLOOR_W || n.y >= FLOOR_H || reached[n.y][n.x] || !passable(f.cells[n.y][n.x]) {
				continue
			}
			reached[n.y][n.x] = true
			from[n.y][n.x] = {i16(c.x), i16(c.y)}
			queue[tail] = n
			tail += 1
		}
	}
	if !reached[goal.y][goal.x] {
		say(g, "The spell finds no way up from here.")
		return
	}
	for c := goal; c != {g.x, g.y}; {
		reveal(f, c.x, c.y, c.x, c.y)
		p := from[c.y][c.x]
		c = {int(p.x), int(p.y)}
	}
	say(g, "A draught runs ahead to the stairs up. Yer map shows the way.")
}

// Teleport: to a random open cell at least TELEPORT_MIN away, with nobody on it.
teleport_far :: proc(g: ^Game) {
	f := floor_of(g)
	for _ in 0 ..< 400 {
		x, y := rng_int(&g.rng, f.w), rng_int(&g.rng, f.h)
		if max(abs(x - g.x), abs(y - g.y)) < TELEPORT_MIN || !passable(floor_cell(f, x, y)) || tenant_at(g, x, y) != 0 {
			continue
		}
		g.x, g.y = x, y
		stop_travel(g)
		refresh_view(g)
		say(g, "The wind drops you somewhere else entirely.")
		return
	}
	say(g, "The spell finds nowhere far enough to put you.")
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
// cells where it stops, yerself included. A squall is a bigger gust ball: it flies SQUALL_RANGE,
// bursts harder, and spares you.
cast_bolt :: proc(g: ^Game, d: [2]int, ball: bool, squall := false) {
	f := floor_of(g)
	w := wind_blow(f)
	along := w == d || w == -d
	reach := (squall ? SQUALL_RANGE : ball ? BALL_RANGE : BOLT_RANGE) + d.x * w.x + d.y * w.y
	drift := ball ? BALL_DRIFT : BOLT_DRIFT
	name := squall ? "squall" : ball ? "gust ball" : "bolt"
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
	say(g, squall ? "The squall bursts." : "The gust ball bursts.")
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			x, y := pos.x + dx, pos.y + dy
			if id := tenant_at(g, x, y); id != 0 {
				spell_hit(g, id, (squall ? rng_range(&g.rng, 3, 8) : rng_range(&g.rng, 2, 5)) + spell_bonus(g), name)
			}
			if x == g.x && y == g.y && g.mode != .Dead && !squall {
				say(g, "Yer own gust ball catches you.")
				hurt(g, rng_range(&g.rng, 2, 5), "yer own gust ball")
			}
		}
	}
}

// Gale: a blast along one of eight lines. Every tenant within GALE_RANGE on it is shoved away from
// you GALE_SHOVE cells, more with the wind behind the blast and less against it; one stopped by a
// wall or another tenant is slammed (1 to 3). Propped-up bones fall over. The line does not bend.
cast_gale :: proc(g: ^Game, d: [2]int) {
	f := floor_of(g)
	w := wind_blow(f)
	shove := max(1, GALE_SHOVE + d.x * w.x + d.y * w.y)
	g.fx_len, g.fx_blast = 0, false
	// Who stands on the line, farthest first (so the far ones move out of the near ones' way).
	ids: [GALE_RANGE]int
	n := 0
	for step in 1 ..= GALE_RANGE {
		c := [2]int{g.x, g.y} + step * d
		if !passable(floor_cell(f, c.x, c.y)) {
			break
		}
		if g.fx_len < MAX_FX {
			g.fx[g.fx_len] = c
			g.fx_len += 1
		}
		if id := tenant_at(g, c.x, c.y); id != 0 {
			ids[n] = id
			n += 1
		}
	}
	say(g, "A gale tears out of yer hands.")
	for i := n - 1; i >= 0; i -= 1 {
		id := ids[i]
		t := &g.tenants[id]
		if TENANT[t.kind].prop {
			topple(g, id, false)
			continue
		}
		if t.kind == .Draught {
			seal_draught(g, id)
			continue
		}
		if giant_on_crate(g, t) {
			t.awake = true
			t.tx, t.ty = i16(g.x), i16(g.y)
			tip_crate(g, id, d, false)
			continue
		}
		if disguised(t) {
			say(g, "The pack was a mimic!")
		} else if !hostile(t) {
			t.angry = true
			say(g, "The ", TENANT[t.kind].name, " shouts for the law. There is none.")
		}
		t.awake = true
		t.tx, t.ty = i16(g.x), i16(g.y)
		moved := 0
		for _ in 0 ..< shove {
			nx, ny := int(t.x) + d.x, int(t.y) + d.y
			if !tenant_can_enter(g, nx, ny) {
				break
			}
			t.x, t.y = i16(nx), i16(ny)
			moved += 1
		}
		if moved < shove {
			spell_hit(g, id, rng_range(&g.rng, 1, 3), "gale")
		}
	}
}

// Blink: up to BLINK_RANGE cells (with the wind's help or hindrance) along one of eight lines,
// drifting downwind like a bolt; it stops short of a wall or a tenant.
blink :: proc(g: ^Game, d: [2]int) {
	f := floor_of(g)
	w := wind_blow(f)
	along := w == d || w == -d
	reach := max(1, BLINK_RANGE + d.x * w.x + d.y * w.y)
	g.fx_len, g.fx_blast = 0, false
	pos := [2]int{g.x, g.y}
	try :: proc(g: ^Game, f: ^Floor, pos: ^[2]int, by: [2]int) -> bool {
		next := pos^ + by
		if !passable(floor_cell(f, next.x, next.y)) || tenant_at(g, next.x, next.y) != 0 {
			return false
		}
		pos^ = next
		if g.fx_len < MAX_FX {
			g.fx[g.fx_len] = next
			g.fx_len += 1
		}
		return true
	}
	for step in 1 ..= reach {
		if !try(g, f, &pos, d) {
			break
		}
		if !along && step % BOLT_DRIFT == 0 && !try(g, f, &pos, w) {
			break
		}
	}
	if pos == {g.x, g.y} {
		say(g, "The spell finds nowhere to put you.")
		return
	}
	g.x, g.y = pos.x, pos.y
	stop_travel(g)
	refresh_view(g)
	say(g, "You blink.")
}

spell_hit :: proc(g: ^Game, id: int, dmg: int, what: string) {
	t := &g.tenants[id]
	info := TENANT[t.kind]
	if info.prop {
		topple(g, id, false)
		return
	}
	if t.kind == .Draught {
		seal_draught(g, id)
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
	if giant_on_crate(g, t) && (what == "gust ball" || what == "squall") {
		tip_crate(g, id, {clamp(int(t.x) - g.x, -1, 1), clamp(int(t.y) - g.y, -1, 1)}, false)
	}
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
	if g.sense_items > 0 {
		g.sense_items -= 1
	}
	if g.calm_turns > 0 {
		g.calm_turns -= 1
		if g.calm_turns == 0 {
			say(g, "The calm round you lifts.")
		}
	}
	if g.turn % mana_period(g) == 0 && g.mana < max_mana(g) {
		g.mana += 1
	}
}

// Screens: choosing a spell at a level, and casting one. Rows in the map area.
MENU_TOP :: 30
MENU_ROW_H :: 10 // 14 px until slice 2 step 14
SPELL_ROWS :: 13 // rows shown; a longer list scrolls, with "more" marks above and below (slice 3 step 21)
MORE_X :: 210
MENU_COST_X :: 96
MENU_USE_X :: 112

menu_pointer :: proc(g: ^Game, sx, sy: int, n: int) -> int {
	if sx >= VIEW_W * TILE {
		return -1
	}
	for row in 0 ..< min(n - g.spell_scroll, SPELL_ROWS) {
		y := MENU_TOP + row * MENU_ROW_H
		if sy >= y - 3 && sy < y + MENU_ROW_H - 3 {
			return row + g.spell_scroll
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
	first := clamp(g.spell_scroll, 0, max(0, len(list) - SPELL_ROWS))
	// Marks for rows above and below the screen: in the header line, and in the row under the last.
	if first > 0 {
		print(f, "^ more", MORE_X, MENU_TOP - 12, COLOR_YELLOW)
	}
	if first + SPELL_ROWS < len(list) {
		print(f, "v more", MORE_X, MENU_TOP + SPELL_ROWS * MENU_ROW_H, COLOR_YELLOW)
	}
	for row in 0 ..< min(len(list) - first, SPELL_ROWS) {
		i := first + row
		s := list[i]
		y := MENU_TOP + row * MENU_ROW_H
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
