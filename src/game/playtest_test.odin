#+build !js
package game

// An autoplay bot for slice 1 playtests (-define:PLAYTEST=true). It plays the way a careful
// melee-only climber would: explores each floor toward the nearest unexplored edge, fights what is
// next to it, picks things up while the load allows, wears better gear, eats when hungry, rests
// when hurt, relights its torch, climbs when a floor is explored, pays the carny on floor 4 and
// fights the skeleton. After a fall it shops in town (food, torches, the temple) and climbs again.
// It casts only Mend (if it knows it) and drinks potions when low. It prints totals and the story
// of a few runs. Without the define it does nothing.

import "core:fmt"
import "core:testing"

_ :: fmt

PLAYTEST :: #config(PLAYTEST, false)
PLAYTEST_RUNS :: #config(PLAYTEST_RUNS, 200)
PLAYTEST_TURNS :: 12000 // give up after this many turns
BOT_DEBUG :: #config(BOT_DEBUG, false)
BOT_LOAD :: #config(BOT_LOAD, 90) // the bot stops picking things up at this share of its load limit

Bot_Stats :: struct {
	won:             bool, // reached the top of what is built (floor 7's stairs up, slice 2 step 10)
	turn_won:        int,
	key_turn:        int, // when the key to floor 5 was picked up (0: never)
	turns:           int,
	deaths:          int,
	death_by:        [16][40]u8, // copies: the game is gone when they are counted
	death_by_n:      [16]int,
	death_floor:     [16]int,
	deepest:         int,
	level:           int,
	kills:           int,
	starving_turns:  int,
	hungry_turns:    int,
	dark_turns:      int,
	anchored_turns:  int,
	overloaded:      int,
	slams:           int,
	ran_out_torch:   bool,
	jools_end:       int,
	jools_max:       int,
	food_eaten:      int,
	potions_drunk:   int,
	bought:          int,
	spent:           int,
	floor_turns:     [FLOOR_COUNT]int,
	stuck:           bool,
	broke:           int, // gear broken
	trophies_end:    int,
	weight_max:      int,
}

@(private = "file")
Plan :: struct {
	dir: [2]int,
	ok:  bool,
}

Goal :: enum u8 {
	Key,
	Hostile,
	Ticket,
	Item,
	Frontier,
	Stairs_Up,
}

// What the bot knows about the floor this turn, built once per decision.
Bot_View :: struct {
	tenant: [FLOOR_H][FLOOR_W]i16, // tenant id on each cell
	goal:   [FLOOR_H][FLOOR_W]bit_set[Goal],
	prev:   [FLOOR_H][FLOOR_W][2]i16,
	done:   [FLOOR_H][FLOOR_W]bool,
	queue:  [FLOOR_W * FLOOR_H][2]int,
}

@(private = "file")
bot_view: Bot_View // the bot runs on one thread

@(private = "file")
look_around :: proc(g: ^Game) {
	v := &bot_view
	f := floor_of(g)
	v.tenant = {}
	v.goal = {}
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if t.kind == .None || int(t.floor) != g.current {
			continue
		}
		v.tenant[t.y][t.x] = i16(i)
		if hostile(t) {
			v.goal[t.y][t.x] += {.Hostile}
		}
		if i == g.ticket && !g.admitted {
			v.goal[t.y][t.x] += {.Ticket}
		}
	}
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place != .Ground || int(it.floor) != g.current {
			continue
		}
		if it.kind == .Key {
			v.goal[it.y][it.x] += {.Key}
		}
		c := f.cells[it.y][it.x]
		if c != .Stairs_Up && c != .Stairs_Down && worth_taking(g, i) {
			v.goal[it.y][it.x] += {.Item}
		}
	}
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if !f.seen[y][x] || !passable(f.cells[y][x]) {
				continue
			}
			if f.cells[y][x] == .Stairs_Up {
				v.goal[y][x] += {.Stairs_Up}
			}
			for d in DIRECTIONS {
				nx, ny := x + d.x, y + d.y
				if nx >= 0 && ny >= 0 && nx < FLOOR_W && ny < FLOOR_H && !f.seen[ny][nx] {
					v.goal[y][x] += {.Frontier}
					break
				}
			}
		}
	}
}

// Breadth-first search over seen, passable cells (tenants block, except a goal) to the nearest
// cell marked with `want`. Returns the first step.
@(private = "file")
bfs :: proc(g: ^Game, want: Goal) -> Plan {
	v := &bot_view
	f := floor_of(g)
	v.done = {}
	head, tail := 0, 1
	v.queue[0] = {g.x, g.y}
	v.done[g.y][g.x] = true
	for head < tail {
		c := v.queue[head]
		head += 1
		if c != {g.x, g.y} && want in v.goal[c.y][c.x] {
			for {
				p := [2]int{int(v.prev[c.y][c.x].x), int(v.prev[c.y][c.x].y)}
				if p == {g.x, g.y} {
					return {c - p, true}
				}
				c = p
			}
		}
		for d in DIRECTIONS {
			n := c + d
			if n.x < 0 || n.y < 0 || n.x >= FLOOR_W || n.y >= FLOOR_H || v.done[n.y][n.x] {
				continue
			}
			if !f.seen[n.y][n.x] || !passable(f.cells[n.y][n.x]) {
				continue
			}
			// A tenant blocks the way, unless it is what we are after (never a frontier or an item
			// under a peaceful one: that only had the bot waiting beside the hermit for ever).
			if v.tenant[n.y][n.x] != 0 && !((want == .Hostile || want == .Ticket) && want in v.goal[n.y][n.x]) {
				continue
			}
			v.done[n.y][n.x] = true
			v.prev[n.y][n.x] = {i16(c.x), i16(c.y)}
			v.queue[tail] = n
			tail += 1
		}
	}
	return {}
}

@(private = "file")
worth_taking :: proc(g: ^Game, id: int) -> bool {
	it := &g.items[id]
	k := it.kind
	if k == .Old_Bones || k == .None || KIND[k].fixed {
		return false
	}
	if KIND[k].slot != .None && k != .Torch && !is_container(k) && worn(g, KIND[k].slot) != 0 && KIND[k].dmax == 0 {
		return false // a second piece of armour or jewellery: leave it
	}
	if carried_weight(g) + weight_of(g, id) > carry_limit(g) * BOT_LOAD / 100 {
		return false
	}
	// Only what there is room for (a full pack is a limit too).
	for sl in ([?]Slot{.Purse, .Belt, .Pack}) {
		if c := worn(g, sl); c != 0 {
			if ok, _ := can_put_in(g, id, c); ok {
				return true
			}
		}
	}
	return KIND[k].slot != .None && worn(g, KIND[k].slot) == 0
}

@(private = "file")
carried_of :: proc(g: ^Game, pred: proc(k: Item_Kind) -> bool) -> (id, count: int) {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind != .None && is_carried(g, i) && g.items[i].place != .Worn && pred(g.items[i].kind) {
			if id == 0 {
				id = i
			}
			count += 1
		}
	}
	return
}

@(private = "file")
is_food :: proc(k: Item_Kind) -> bool {
	return KIND[k].food > 0
}

@(private = "file")
is_potion :: proc(k: Item_Kind) -> bool {
	return KIND[k].group == .Potion
}

@(private = "file")
is_torch :: proc(k: Item_Kind) -> bool {
	return k == .Torch
}

// Wields the best weapon carried.
@(private = "file")
best_weapon :: proc(g: ^Game) {
	cur := worn(g, .Weapon)
	best, best_dmax := cur, cur != 0 ? KIND[g.items[cur].kind].dmax : 0
	for i in 1 ..< MAX_ITEMS {
		k := g.items[i].kind
		if KIND[k].dmax > best_dmax && is_carried(g, i) {
			best, best_dmax = i, KIND[k].dmax
		}
	}
	if best != cur {
		if cur != 0 {
			if !put_in(g, cur, worn(g, .Pack)) {
				drop(g, cur)
			}
		}
		wear(g, best, .Weapon)
	}
}

@(private = "file")
step_dir :: proc(d: [2]int) -> Command {
	for c in Command {
		if DIRECTION[c] == d && c <= .South_East {
			return c
		}
	}
	return .Wait
}

// Shops in town after a fall (or at the start): food to three, torches to two spares, and gear mended.
@(private = "file")
shop_town :: proc(g: ^Game, s: ^Bot_Stats) {
	buy :: proc(g: ^Game, s: ^Bot_Stats, k: Item_Kind) -> bool {
		if carried_jools(g) < VALUE[k] {
			return false
		}
		before := carried_jools(g)
		if !receive_item(g, k) {
			return false
		}
		pay(g, VALUE[k])
		s.bought += 1
		s.spent += before - carried_jools(g)
		return true
	}
	for {
		_, food := carried_of(g, is_food)
		if food >= 3 || !buy(g, s, .Bread) {
			break
		}
	}
	for spare_torches(g) < 2 && buy(g, s, .Torch) {}
	// A Big pack once there is money for it and the usual shopping after.
	if g.items[worn(g, .Pack)].kind != .Big_Pack && carried_jools(g) >= VALUE[.Big_Pack] + 30 {
		before := carried_jools(g)
		if swap_pack(g) {
			pay(g, VALUE[.Big_Pack])
			s.bought += 1
			s.spent += before - carried_jools(g)
		}
	}
	if w := worn(g, .Weapon); w != 0 && repair_price(g, w) > 0 && carried_jools(g) >= repair_price(g, w) {
		s.spent += repair_price(g, w)
		pay(g, repair_price(g, w))
		g.items[w].dur = i16(KIND[g.items[w].kind].durability)
	}
	// Sell trophies at the junk shop.
	for i in 1 ..< MAX_ITEMS {
		if KIND[g.items[i].kind].trophy && sellable(g, i) {
			v := junk_price(g, i)
			free_item(g, i)
			receive_jools(g, v)
		}
	}
}

// One decision. Returns false to stop (won, stuck or out of turns).
@(private = "file")
bot_step :: proc(g: ^Game, s: ^Bot_Stats) -> bool {
	switch g.mode {
	case .Create:
		g.create_row = CREATE_BEGIN_ROW
		command(g, .Confirm)
		return true
	case .Learn:
		// Magic Bolt first (it costs nothing to learn), then Mend, then whatever is first.
		list: [len(Spell)]Spell
		n := learnable(g, &list)
		g.menu_row = 0
		for i in 0 ..< n {
			if list[i] == .Mend {
				g.menu_row = i
			}
		}
		command(g, .Confirm)
		return true
	case .Dead:
		if s.deaths < len(s.death_by) {
			s.death_by_n[s.deaths] = copy(s.death_by[s.deaths][:], killed_by(g))
			s.death_floor[s.deaths] = g.current + 1
		}
		s.deaths += 1
		command(g, .Confirm)
		shop_town(g, s)
		return true
	case .Notice:
		command(g, .Confirm)
		return true
	case .Shop:
		if g.shop == .Admission {
			if carried_jools(g) >= ADMISSION {
				choose_row(g, .Admit)
			} else {
				choose_row(g, .Shove)
			}
		} else if g.shop == .Gate {
			choose_row(g, .Chute)
		} else if g.shop == .Carny {
			choose_row(g, .Leave)
		} else {
			command(g, .Cancel)
		}
		return true
	case .Inventory, .Cast, .Aim, .Automap:
		command(g, .Cancel)
		return true
	case .Play:
	}
	if in_town(g) {
		shop_town(g, s)
		teleport(g, g.town.up)
		command(g, .Confirm)
		return true
	}
	s.floor_turns[g.current] += 1
	look_around(g)
	// Fight what is next to you.
	for d in DIRECTIONS {
		x, y := g.x + d.x, g.y + d.y
		if x >= 0 && y >= 0 && x < FLOOR_W && y < FLOOR_H && .Hostile in bot_view.goal[y][x] {
			if g.health * 3 < max_health(g) {
				drink_something(g, s)
			}
			command(g, step_dir(d))
			return true
		}
	}
	// Look after yerself.
	if g.hunger >= HUNGER_HUNGRY {
		if id, _ := carried_of(g, is_food); id != 0 {
			use_item(g, id)
			s.food_eaten += 1
			return true
		}
	}
	if !g.lit && (torch_fuel(g) > 0 || spare_torches(g) > 0) {
		command(g, .Confirm)
		if !g.lit {
			light_torch(g)
		}
		return true
	}
	if g.health * 2 < max_health(g) && !hostile_in_view(g) {
		if .Mend in g.known && g.mana >= SPELL[.Mend].cost {
			cast_spell(g, .Mend, {0, 0})
		} else {
			command(g, .Wait)
		}
		return true
	}
	// Too loaded to move: drop something.
	if overloaded(g) && drop_one(g) {
		return true
	}
	// Pick up what is underfoot: the key first, else something worth taking (not just the top of
	// the pile, which may not fit; a player would use the inventory's ground pane).
	if .Item in bot_view.goal[g.y][g.x] || .Key in bot_view.goal[g.y][g.x] {
		pick := 0
		for i in 1 ..< MAX_ITEMS {
			it := &g.items[i]
			if it.place != .Ground || int(it.floor) != g.current || int(it.x) != g.x || int(it.y) != g.y {
				continue
			}
			if it.kind == .Key {
				pick = i
				break
			}
			if pick == 0 && worth_taking(g, i) {
				pick = i
			}
		}
		if pick != 0 {
			pick_up(g, pick)
			if g.items[pick].kind == .Key && g.items[pick].place == .Ground {
				drop_one(g) // no room for the key: make some
			}
			best_weapon(g)
			return true
		}
	}
	// Go somewhere: the key, a hostile in view, things, the unexplored, then the stairs up.
	plan := bfs(g, .Key)
	if !plan.ok && hostile_in_view(g) {
		plan = bfs(g, .Hostile)
	}
	if !plan.ok {
		plan = bfs(g, .Ticket)
	}
	if !plan.ok {
		plan = bfs(g, .Item)
	}
	if !plan.ok {
		plan = bfs(g, .Frontier)
	}
	if !plan.ok {
		if cell_at(g, g.x, g.y) == .Stairs_Up {
			if g.current == BOSS_INDEX && !has_key(g) && BOSS_INDEX not_in g.unlocked {
				s.stuck = true // explored floor 4 without the key
				return false
			}
			if g.current == BUILT_FLOORS - 1 {
				s.won = true // the top of what is built
				s.turn_won = g.turn
				return false
			}
			command(g, .Confirm)
			return true
		}
		plan = bfs(g, .Stairs_Up)
	}
	if !plan.ok {
		command(g, .Wait) // nowhere to go (blocked by a tenant?)
		return true
	}
	// Never walk into a peaceful tenant (that opens a stall or knocks bones over): wait instead.
	nx, ny := g.x + plan.dir.x, g.y + plan.dir.y
	if id := tenant_at(g, nx, ny); id != 0 && !hostile(&g.tenants[id]) && !(id == g.ticket && !g.admitted) {
		command(g, .Wait)
		return true
	}
	command(g, step_dir(plan.dir))
	return true
}

// Drops the heaviest trophy carried (or else the heaviest thing not worn). False if nothing.
@(private = "file")
drop_one :: proc(g: ^Game) -> bool {
	heaviest, trophy := 0, false
	for i in 1 ..< MAX_ITEMS {
		k := g.items[i].kind
		if k == .None || k == .Key || !is_carried(g, i) || g.items[i].place == .Worn || is_container(k) {
			continue
		}
		t := KIND[k].trophy
		if heaviest == 0 || (t && !trophy) || (t == trophy && weight_of(g, i) > weight_of(g, heaviest)) {
			heaviest, trophy = i, t
		}
	}
	if heaviest != 0 {
		drop(g, heaviest)
	}
	return heaviest != 0
}

@(private = "file")
choose_row :: proc(g: ^Game, act: Act) {
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for i in 0 ..< n {
		if rows[i].act == act {
			g.menu_row = i
			command(g, .Confirm)
			return
		}
	}
	command(g, .Cancel)
}

@(private = "file")
drink_something :: proc(g: ^Game, s: ^Bot_Stats) {
	healing := 0
	unknown := 0
	for i in 1 ..< MAX_ITEMS {
		k := g.items[i].kind
		if !is_potion(k) || !is_carried(g, i) {
			continue
		}
		if k in g.ident {
			if k == .Potion_Healing {
				healing = i
			}
		} else if unknown == 0 {
			unknown = i
		}
	}
	if healing != 0 {
		use_item(g, healing)
		s.potions_drunk += 1
	} else if unknown != 0 {
		use_item(g, unknown)
		s.potions_drunk += 1
	}
}

play_one :: proc(seed: u64, attrs: [Attr]int) -> Bot_Stats {
	s: Bot_Stats
	g := new(Game)
	defer free(g)
	init_game(g, seed)
	g.attr = attrs
	g.health = max_health(g)
	g.mana = max_mana(g)
	last_hp := g.health
	idle := 0
	for g.turn < PLAYTEST_TURNS {
		before := g.turn
		prev_x, prev_y := g.x, g.y
		if !bot_step(g, &s) {
			break
		}
		_ = prev_x
		_ = prev_y
		if g.turn > before {
			if g.hunger >= HUNGER_STARVING {
				s.starving_turns += g.turn - before
			} else if g.hunger >= HUNGER_HUNGRY {
				s.hungry_turns += g.turn - before
			}
			if !g.lit && !in_town(g) {
				s.dark_turns += g.turn - before
			}
			if load_anchors(g) {
				s.anchored_turns += g.turn - before
			}
		}
		if overloaded(g) {
			s.overloaded += 1
		}
		if s.key_turn == 0 && has_key(g) {
			s.key_turn = g.turn
		}
		s.jools_max = max(s.jools_max, carried_jools(g) + g.bank)
		s.weight_max = max(s.weight_max, carried_weight(g))
		if torch_fuel(g) == 0 && spare_torches(g) == 0 && !in_town(g) {
			s.ran_out_torch = true
		}
		_ = last_hp
		last_hp = g.health
		// A bot can wedge itself; many decisions in a row with nothing changing ends the run.
		if g.turn == before && g.x == prev_x && g.y == prev_y {
			idle += 1
			if idle > 200 {
				s.stuck = true
				when BOT_DEBUG {
					f := floor_of(g)
					fmt.printfln("STUCK seed %d mode %v floor %d at %d,%d cell %v turn %d hp %d/%d lit %v fuel %d spare %d hunger %d load %d/%d", seed, g.mode, g.current + 1, g.x, g.y, f.cells[g.y][g.x], g.turn, g.health, max_health(g), g.lit, torch_fuel(g), spare_torches(g), g.hunger, carried_weight(g), carry_limit(g))
					for i in 1 ..< MAX_ITEMS {
						it := &g.items[i]
						if it.place == .Ground && int(it.floor) == g.current && abs(int(it.x) - g.x) <= 1 && abs(int(it.y) - g.y) <= 1 {
							fmt.printfln("  item %v at %d,%d", it.kind, it.x, it.y)
						}
					}
					for i in 1 ..< MAX_TENANTS {
						t := &g.tenants[i]
						if t.kind != .None && int(t.floor) == g.current && abs(int(t.x) - g.x) <= 2 && abs(int(t.y) - g.y) <= 2 {
							fmt.printfln("  tenant %v at %d,%d hostile %v", t.kind, t.x, t.y, hostile(t))
						}
					}
					for i in 0 ..< LOG_LINES {
						fmt.printfln("  log: %s", message(&g.log[i]))
					}
				}
				break
			}
		} else {
			idle = 0
		}
	}
	when BOT_DEBUG {
		if !s.won && !s.stuck {
			fmt.printfln("OUT seed %d mode %v floor %d at %d,%d turn %d hp %d/%d", seed, g.mode, g.current + 1, g.x, g.y, g.turn, g.health, max_health(g))
			for i in 1 ..< MAX_TENANTS {
				t := &g.tenants[i]
				if t.kind != .None && int(t.floor) == g.current && abs(int(t.x) - g.x) <= 2 && abs(int(t.y) - g.y) <= 2 {
					fmt.printfln("  tenant %v at %d,%d hostile %v", t.kind, t.x, t.y, hostile(t))
				}
			}
			for i in 0 ..< LOG_LINES {
				fmt.printfln("  log: %s", message(&g.log[i]))
			}
		}
	}
	s.turns = g.turn
	s.deepest = g.deepest
	s.level = g.level
	s.kills = g.kills
	s.jools_end = carried_jools(g) + g.bank
	for i in 1 ..< MAX_ITEMS {
		if KIND[g.items[i].kind].trophy && is_carried(g, i) {
			s.trophies_end += 1
		}
	}
	return s
}

cause_name :: proc(arg: [40]u8, n: int) -> string {
	b := arg
	for t in Tenant_Kind {
		if TENANT[t].a == string(b[:n]) {
			return TENANT[t].a
		}
	}
	switch string(b[:n]) {
	case "hunger":
		return "hunger"
	case "the wind":
		return "the wind"
	case "a bad potion":
		return "a bad potion"
	case "casting past yer mana":
		return "casting past yer mana"
	}
	return "something else"
}

@(test)
test_playtest :: proc(t: ^testing.T) {
	when PLAYTEST {
		builds := [?]struct {
			name:  string,
			attrs: [Attr]int,
		} {
			{"even (10s)", {.Strength = 10, .Dexterity = 10, .Intelligence = 10, .Constitution = 10}},
			{"fighter (St14 Dx12 In6 Co14)", {.Strength = 14, .Dexterity = 12, .Intelligence = 6, .Constitution = 14}},
			{"nimble (Dx16 Co12)", {.Strength = 10, .Dexterity = 16, .Intelligence = 8, .Constitution = 12}},
			{"caster (In16 Co12, St8)", {.Strength = 8, .Dexterity = 10, .Intelligence = 16, .Constitution = 12}},
		}
		for b in builds {
			won, deaths, runs, turns_won, stuck := 0, 0, PLAYTEST_RUNS, 0, 0
			keys, key_turns := 0, 0
			starving, hungry, dark, anchored, out_torch, overload := 0, 0, 0, 0, 0, 0
			level, kills, jools, eaten, drunk, spent := 0, 0, 0, 0, 0, 0
			wmax := 0
			deepest_hist: [FLOOR_COUNT + 1]int
			floor_turns: [FLOOR_COUNT]int
			causes: map[string]int
			defer delete(causes)
			death_floors: [FLOOR_COUNT + 2]int
			first_death_runs := 0
			for r in 0 ..< runs {
				s := play_one(u64(r * 104729 + 17), b.attrs)
				if s.won {
					won += 1
					turns_won += s.turn_won
				}
				if s.key_turn > 0 {
					keys += 1
					key_turns += s.key_turn
				}
				if s.stuck {
					stuck += 1
				}
				deaths += s.deaths
				if s.deaths > 0 {
					first_death_runs += 1
				}
				for i in 0 ..< min(s.deaths, len(s.death_by)) {
					causes[cause_name(s.death_by[i], s.death_by_n[i])] += 1
					death_floors[clamp(s.death_floor[i], 0, FLOOR_COUNT + 1)] += 1
				}
				starving += s.starving_turns
				hungry += s.hungry_turns
				dark += s.dark_turns
				anchored += s.anchored_turns
				if s.ran_out_torch {
					out_torch += 1
				}
				overload += s.overloaded > 0 ? 1 : 0
				level += s.level
				kills += s.kills
				jools += s.jools_end
				eaten += s.food_eaten
				drunk += s.potions_drunk
				spent += s.spent
				wmax += s.weight_max
				deepest_hist[clamp(s.deepest, 0, FLOOR_COUNT)] += 1
				for i in 0 ..< FLOOR_COUNT {
					floor_turns[i] += s.floor_turns[i]
				}
			}
			fmt.printfln("\n== %s, %d runs ==", b.name, runs)
			fmt.printfln("got the key to floor 5: %d%% (avg turn %d)", keys * 100 / runs, keys > 0 ? key_turns / keys : 0)
			fmt.printfln("reached floor %d's stairs up: %d%% (avg turn %d); stuck %d; ran out of turns %d", BUILT_FLOORS, won * 100 / runs, won > 0 ? turns_won / won : 0, stuck, runs - won - stuck)
			fmt.printfln("deaths: %.2f a run; runs with a death %d%%; by floor (town=0) %v", f64(deaths) / f64(runs), first_death_runs * 100 / runs, death_floors[:BUILT_FLOORS + 1])
			fmt.printf("causes:")
			for k, v in causes {
				fmt.printf(" %s %d;", k, v)
			}
			fmt.println()
			fmt.printfln("deepest floor reached %v (index = floor)", deepest_hist[:BUILT_FLOORS + 1])
			fmt.printf("turns per floor (avg)")
			for i in 0 ..< BUILT_FLOORS {
				fmt.printf(" %d", floor_turns[i] / runs)
			}
			fmt.println()
			fmt.printfln("end level %.1f, kills %.1f, Jools at end %d, spent in town %d, max load %.1f kg", f64(level) / f64(runs), f64(kills) / f64(runs), jools / runs, spent / runs, f64(wmax) / f64(runs) / 1000)
			fmt.printfln("food eaten %.1f; potions drunk %.1f; turns hungry %d, starving %d; turns in the dark %d; anchored %d; ran out of torches %d%%; ever overloaded %d%%", f64(eaten) / f64(runs), f64(drunk) / f64(runs), hungry / runs, starving / runs, dark / runs, anchored / runs, out_torch * 100 / runs, overload * 100 / runs)
		}
	}
}
