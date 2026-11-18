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
PLAYTEST_TURNS :: 24000 // give up after this many turns (16000 in slice 2)
TRIP_GAP :: 600 // turns between the bot's trips back to town
TRIP_MONEY :: 40 // Jools (carried, or in trophies) worth a trip
BOT_DEBUG :: #config(BOT_DEBUG, false)
// Parts of the wind switched off for the wind study (November 15, 2026).
NO_GUSTS :: #config(NO_GUSTS, false)
NO_PUSH :: #config(NO_PUSH, false)
NO_SNUFF :: #config(NO_SNUFF, false)
NO_BLOW :: #config(NO_BLOW, false)
BOT_WIND :: #config(BOT_WIND, true) // the bot minds the wind (step 17 review); false for the old wind-blind bot
BOT_LOAD :: #config(BOT_LOAD, 90) // the bot stops picking things up at this share of its load limit

Bot_Stats :: struct {
	won:             bool, // reached floor 11's stairs up, the top of slice 3 so far (step 17)
	turn_won:        int,
	key9_turn:       int, // when the key to floor 9 was picked up (0: never)
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
	wind:            Wind_Counts,
	wind_dodges:     int, // steps off a cell the coming gust would slam
	wind_waits:      int, // turns waited on a safe cell for a gust
	wind_deaths:     int,
	trips:           int, // back to town by Return to shop
	last_trip:       int,
	lanterns:        int, // bought
	army_turn:       int, // when floor 8 was reached (0: never)
	casts:           [Spell]int, // spells cast in fights
	draught_seals:   int, // draughts sealed with a bolt
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
		if (i == g.ticket && !g.admitted) || (i == g.army_ticket && !g.army_admitted) {
			v.goal[t.y][t.x] += {.Ticket}
		}
	}
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place != .Ground || int(it.floor) != g.current {
			continue
		}
		if it.kind == .Key || it.kind == .Key_Nine {
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
	// After the Horde: a lantern once, then oil; healing potions once they are named.
	if g.boss_dead {
		lantern := worn(g, .Light) != 0 && g.items[worn(g, .Light)].kind == .Lantern
		_, packed := carried_of(g, proc(k: Item_Kind) -> bool {return k == .Lantern})
		if !lantern && (packed > 0 || (carried_jools(g) >= VALUE[.Lantern] + 30 && buy(g, s, .Lantern))) {
			if packed == 0 {
				s.lanterns += 1
			}
			for i in 1 ..< MAX_ITEMS {
				if g.items[i].kind == .Lantern && is_carried(g, i) && g.items[i].place != .Worn {
					if old := worn(g, .Light); old != 0 {
						unplace(g, old)
						if !put_in(g, old, worn(g, .Pack)) {
							free_item(g, old)
						}
					}
					unplace(g, i)
					g.items[i].place, g.items[i].slot = .Worn, .Light
					g.items[i].fuel = 0
					g.lit = false
					break
				}
			}
		}
		lantern = worn(g, .Light) != 0 && g.items[worn(g, .Light)].kind == .Lantern
		if lantern {
			for oil_flasks(g) < 3 && buy(g, s, .Oil_Flask) {}
		}
		if .Potion_Healing in g.ident {
			for {
				_, n := carried_of(g, proc(k: Item_Kind) -> bool {return k == .Potion_Healing})
				if n >= 2 || !buy(g, s, .Potion_Healing) {
					break
				}
			}
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
		best := 99
		for i in 0 ..< n {
			for want, rank in ([?]Spell{.Mend, .Return, .Magic_Bolt, .Ward, .Gale, .Gust_Ball}) {
				if list[i] == want && rank < best {
					g.menu_row, best = i, rank
				}
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
		} else if g.shop == .Army_Door {
			if carried_jools(g) >= ARMY_ADMISSION {
				choose_row(g, .Admit)
			} else {
				choose_row(g, .Shove)
			}
		} else if g.shop == .Gate {
			// The highest stop the windchute offers.
			rows: [MAX_ROWS]Row
			n := shop_rows(g, &rows)
			g.menu_row = 0
			for i in 0 ..< n {
				if rows[i].act == .Chute {
					g.menu_row = i
				}
			}
			command(g, .Confirm)
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
	if bot_casts(g, s) {
		return true
	}
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
	// Mind the wind (step 17 review, November 17, 2026): on the last turn before a gust, stand
	// where the push will not slam you into a wall or a tenant. Off a safe cell, wait it out.
	if bot_minds_wind(g, s) {
		return true
	}
	// Look after yerself.
	if g.hunger >= HUNGER_HUNGRY {
		if id, _ := carried_of(g, is_food); id != 0 {
			use_item(g, id)
			s.food_eaten += 1
			return true
		}
	}
	// A dry lantern and no oil: put it away and light a torch (a player would, in the inventory).
	if lt := worn(g, .Light); lt != 0 && g.items[lt].kind == .Lantern && g.items[lt].fuel <= 0 && oil_flasks(g) == 0 && spare_torches(g) > 0 {
		unplace(g, lt)
		if !put_in(g, lt, worn(g, .Pack)) {
			free_item(g, lt) // left behind (dropped, it would be picked up and worn again)
		}
		g.lit = false
	}
	if !g.lit && (light_fuel(g) > 0 || light_spares(g) > 0) {
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
	// Back to town to shop, by Return, when the bags are full or the light or food is running out,
	// and there is money (or trophies) to spend.
	if g.current >= 1 && !hostile_in_view(g) && .Return in g.known && g.mana >= SPELL[.Return].cost && g.turn - s.last_trip >= TRIP_GAP {
		_, food := carried_of(g, is_food)
		full := carried_weight(g) * 100 >= carry_limit(g) * (BOT_LOAD - 8)
		dark := light_fuel(g) < 100 && light_spares(g) == 0
		trophies := 0
		for i in 1 ..< MAX_ITEMS {
			if KIND[g.items[i].kind].trophy && is_carried(g, i) {
				trophies += VALUE[g.items[i].kind]
			}
		}
		// Full only counts when there are trophies to sell; short of light or food, any money will do.
		if (full && trophies >= TRIP_MONEY) || ((dark || food == 0) && carried_jools(g) + trophies >= TRIP_MONEY / 2) {
			s.trips += 1
			s.last_trip = g.turn
			cast_spell(g, .Return, {0, 0})
			return true
		}
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
			if it.kind == .Key || it.kind == .Key_Nine {
				pick = i
				break
			}
			if pick == 0 && worth_taking(g, i) {
				pick = i
			}
		}
		if pick != 0 {
			pick_up(g, pick)
			if (g.items[pick].kind == .Key || g.items[pick].kind == .Key_Nine) && g.items[pick].place == .Ground {
				drop_one(g) // no room for the key: make some
			}
			best_weapon(g)
			return true
		}
	}
	// Go somewhere: the key, a hostile in view, things, the unexplored, then the stairs up.
	plan := bfs(g, .Key)
	// On floor 8 the sergeant has the key: hunt it, seen or not.
	if !plan.ok && (hostile_in_view(g) || (g.current == ARMY_INDEX && !g.army_dead)) {
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
				when BOT_DEBUG {
					fmt.printfln("NOKEY floor 4 seed %d turn %d boss_dead %v", g.seed, g.turn, g.boss_dead)
				}
				return false
			}
			if g.current == ARMY_INDEX && !has_kind(g, .Key_Nine) && ARMY_INDEX not_in g.unlocked {
				s.stuck = true // explored floor 8 without the key
				when BOT_DEBUG {
					fmt.printfln("NOKEY floor 8 seed %d turn %d army_dead %v sergeants %d", g.seed, g.turn, g.army_dead, count_of(g, .Sergeant))
					for i in 1 ..< MAX_ITEMS {
						if g.items[i].kind == .Key_Nine {
							fmt.printfln("  key place %v floor %d at %d,%d", g.items[i].place, g.items[i].floor, g.items[i].x, g.items[i].y)
						}
					}
				}
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
	if id := tenant_at(g, nx, ny); id != 0 && !hostile(&g.tenants[id]) && !(id == g.ticket && !g.admitted) && !(id == g.army_ticket && !g.army_admitted) {
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
		if k == .None || k == .Key || k == .Key_Nine || !is_carried(g, i) || g.items[i].place == .Worn || is_container(k) {
			continue
		}
		t := KIND[k].trophy
		if heaviest == 0 || (t && !trophy) || (t == trophy && weight_of(g, i) > weight_of(g, heaviest)) {
			heaviest, trophy = i, t
		}
	}
	if heaviest == 0 {
		// Nothing loose: the heaviest thing worn that is not a container, armour or weapon (a cave
		// bear can drain Strength that far, and floor 9's war hammer weighs 5 kg).
		for i in 1 ..< MAX_ITEMS {
			it := &g.items[i]
			if it.place == .Worn && is_carried(g, i) && !is_container(it.kind) && (heaviest == 0 || weight_of(g, i) > weight_of(g, heaviest)) {
				heaviest = i
			}
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
	when NO_GUSTS {
		g.wind_off += {.Gusts}
	}
	when NO_PUSH {
		g.wind_off += {.Push}
	}
	when NO_SNUFF {
		g.wind_off += {.Snuff}
	}
	when NO_BLOW {
		g.wind_off += {.Blow}
	}
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
		if s.army_turn == 0 && g.current == ARMY_INDEX {
			s.army_turn = g.turn
		}
		if s.key9_turn == 0 && has_kind(g, .Key_Nine) {
			s.key9_turn = g.turn
		}
		if g.current == BUILT_FLOORS - 1 && cell_at(g, g.x, g.y) == .Stairs_Up {
			s.won = true // the top floor built so far
			s.turn_won = g.turn
			break
		}
		s.jools_max = max(s.jools_max, carried_jools(g) + g.bank)
		s.weight_max = max(s.weight_max, carried_weight(g))
		if light_fuel(g) == 0 && light_spares(g) == 0 && !in_town(g) {
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
					fmt.printfln("STUCK seed %d mode %v floor %d at %d,%d cell %v turn %d hp %d/%d lit %v fuel %d spare %d hunger %d load %d/%d", seed, g.mode, g.current + 1, g.x, g.y, f.cells[g.y][g.x], g.turn, g.health, max_health(g), g.lit, light_fuel(g), spare_torches(g), g.hunger, carried_weight(g), carry_limit(g))
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
		if !s.won {
			fmt.printfln("OUT stuck %v seed %d mode %v floor %d at %d,%d turn %d hp %d/%d gust_in %d", s.stuck, seed, g.mode, g.current + 1, g.x, g.y, g.turn, g.health, max_health(g), g.gust_in)
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
	s.wind = g.wind_seen
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
			keys, key_turns, keys9, key9_turns := 0, 0, 0, 0
			dodges, wwaits, seals := 0, 0, 0
			armies, army_turns, trips, lanterns := 0, 0, 0, 0
			casts: [Spell]int
			wind: [10]int
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
				ws := s.wind
				for v, i in ([10]i32{ws.gusts, ws.pushed, ws.cells, ws.slams, ws.held, ws.snuffed, ws.things_moved, ws.tenants_moved, ws.into_reach, ws.out_of_reach}) {
					wind[i] += int(v)
				}
				if s.key_turn > 0 {
					keys += 1
					key_turns += s.key_turn
				}
				if s.key9_turn > 0 {
					keys9 += 1
					key9_turns += s.key9_turn
				}
				if s.stuck {
					stuck += 1
				}
				if s.army_turn > 0 {
					armies += 1
					army_turns += s.army_turn
				}
				trips += s.trips
				dodges += s.wind_dodges
				seals += s.draught_seals
				wwaits += s.wind_waits
				for sp in Spell {
					casts[sp] += s.casts[sp]
				}
				lanterns += s.lanterns
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
			fmt.printfln("reached floor 8: %d%% (avg turn %d)", armies * 100 / runs, armies > 0 ? army_turns / armies : 0)
			fmt.printfln("took the key to floor 9: %d%% (avg turn %d)", keys9 * 100 / runs, keys9 > 0 ? key9_turns / keys9 : 0)
			fmt.printfln("reached floor %d's stairs up: %d%% (avg turn %d); stuck %d; ran out of turns %d", BUILT_FLOORS, won * 100 / runs, won > 0 ? turns_won / won : 0, stuck, runs - won - stuck)
			fmt.printfln("minding the wind a climb: stepped aside %d, waited %d", dodges / runs, wwaits / runs)
			fmt.printfln("draughts sealed a climb: %.1f", f64(seals) / f64(runs))
			fmt.printfln("trips to town by Return %.1f a climb; lanterns bought %d%%", f64(trips) / f64(runs), lanterns * 100 / runs)
			fmt.printfln("fighting spells a climb: bolt %.1f, ward %.1f, gale %.1f, gust ball %.1f", f64(casts[.Magic_Bolt]) / f64(runs), f64(casts[.Ward]) / f64(runs), f64(casts[.Gale]) / f64(runs), f64(casts[.Gust_Ball]) / f64(runs))
			fmt.printfln("deaths: %.2f a run; runs with a death %d%%; by floor (town=0) %v", f64(deaths) / f64(runs), first_death_runs * 100 / runs, death_floors[:BUILT_FLOORS + 1])
			fmt.printfln("wind a climb: gusts %d; pushed %d (%d cells); slams %d; held by load %d; snuffed %d; things moved %d; tenants moved %d; pushed into a hostile's reach %d, out of it %d", wind[0] / runs, wind[1] / runs, wind[2] / runs, wind[3] / runs, wind[4] / runs, wind[5] / runs, wind[6] / runs, wind[7] / runs, wind[8] / runs, wind[9] / runs)
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

count_of :: proc(g: ^Game, k: Tenant_Kind) -> int {
	n := 0
	for &t in g.tenants {
		if t.kind == k {
			n += 1
		}
	}
	return n
}

// Where a bolt (or gust ball) aimed `d` goes, as cast_bolt moves it: the tenant it meets first, and
// the cell it ends on. The bot aims with the wind in mind (the wind study's drift).
bot_bolt :: proc(g: ^Game, d: [2]int, ball: bool) -> (hit: int, end: [2]int) {
	f := floor_of(g)
	w := wind_blow(f)
	along := w == d || w == -d
	reach := (ball ? BALL_RANGE : BOLT_RANGE) + d.x * w.x + d.y * w.y
	drift := ball ? BALL_DRIFT : BOLT_DRIFT
	pos := [2]int{g.x, g.y}
	move :: proc(g: ^Game, f: ^Floor, pos: ^[2]int, by: [2]int) -> (hit: int, wall: bool) {
		next := pos^ + by
		if !passable(floor_cell(f, next.x, next.y)) {
			return 0, true
		}
		pos^ = next
		return tenant_at(g, next.x, next.y), false
	}
	for step in 1 ..= max(1, reach) {
		h, wall := move(g, f, &pos, d)
		if h != 0 || wall {
			return h, pos
		}
		if !along && step % drift == 0 {
			h, wall = move(g, f, &pos, w)
			if h != 0 || wall {
				return h, pos
			}
		}
	}
	return 0, pos
}

// The bot's fighting spells, kept above the mana Return needs: Ward when a fight is near, Gale when
// crowded, a gust ball at a knot of tenants, a bolt at one that is not next to you (or at any, for
// a caster). True when it cast.
// Would the coming gust slam you into something, standing at (x, y)?
gust_slams :: proc(g: ^Game, x, y: int) -> bool {
	f := floor_of(g)
	d := wind_blow(f)
	cells := load_anchors(g) ? max(1, gust_push(f.number) - 1) : gust_push(f.number)
	cx, cy := x, y
	for _ in 0 ..< cells {
		cx, cy = cx + d.x, cy + d.y
		if !passable(floor_cell(f, cx, cy)) || tenant_at(g, cx, cy) != 0 {
			return true
		}
	}
	return false
}

// The last turn before a gust: step off a cell where it would slam you, or wait on a safe one.
bot_minds_wind :: proc(g: ^Game, s: ^Bot_Stats) -> bool {
	if !BOT_WIND || g.gust_in != 1 || g.calm_turns > 0 || g.anchor_spell || in_town(g) || overloaded(g) {
		return false
	}
	if !gust_slams(g, g.x, g.y) {
		s.wind_waits += 1
		command(g, .Wait)
		return true
	}
	f := floor_of(g)
	for d, i in DIRECTIONS {
		x, y := g.x + d.x, g.y + d.y
		if passable(floor_cell(f, x, y)) && tenant_at(g, x, y) == 0 && !gust_slams(g, x, y) {
			s.wind_dodges += 1
			command(g, Command(i))
			return true
		}
	}
	return false
}

bot_casts :: proc(g: ^Game, s: ^Bot_Stats) -> bool {
	reserve := .Return in g.known ? SPELL[.Return].cost : 0
	can :: proc(g: ^Game, sp: Spell, reserve: int) -> bool {
		return sp in g.known && g.mana >= SPELL[sp].cost + reserve
	}
	do_cast :: proc(g: ^Game, s: ^Bot_Stats, sp: Spell, d: [2]int) -> bool {
		s.casts[sp] += 1
		cast_spell(g, sp, d)
		return true
	}
	// A draught next to you is sealed with a bolt, as a player who knows any spell seals it (step 18
	// review): blows pass through it, so the bot would otherwise take every shove and slam.
	if can(g, .Magic_Bolt, reserve) {
		for d in DIRECTIONS {
			if id := tenant_at(g, g.x + d.x, g.y + d.y); id != 0 && g.tenants[id].kind == .Draught {
				s.draught_seals += 1
				return do_cast(g, s, .Magic_Bolt, d)
			}
		}
	}
	if !hostile_in_view(g) {
		return false
	}
	near, adjacent := 0, 0
	for i in 1 ..< MAX_TENANTS {
		t := &g.tenants[i]
		if hostile(t) && int(t.floor) == g.current && g.vis[t.y][t.x] {
			dist := max(abs(int(t.x) - g.x), abs(int(t.y) - g.y))
			if dist <= 4 {
				near += 1
			}
			if dist <= 1 {
				adjacent += 1
			}
		}
	}
	if near > 0 && g.ward_turns == 0 && can(g, .Ward, reserve) {
		return do_cast(g, s, .Ward, {0, 0})
	}
	if adjacent >= 2 && can(g, .Gale, reserve) {
		best, most := [2]int{}, 0
		for d in DIRECTIONS {
			n := 0
			for k in 1 ..= GALE_RANGE {
				if id := tenant_at(g, g.x + k * d.x, g.y + k * d.y); id != 0 && hostile(&g.tenants[id]) {
					n += 1
				}
			}
			if n > most {
				best, most = d, n
			}
		}
		if most >= 2 {
			return do_cast(g, s, .Gale, best)
		}
	}
	if can(g, .Gust_Ball, reserve) {
		for d in DIRECTIONS {
			_, end := bot_bolt(g, d, true)
			if max(abs(end.x - g.x), abs(end.y - g.y)) <= 1 {
				continue // it would catch you too
			}
			n := 0
			for dy in -1 ..= 1 {
				for dx in -1 ..= 1 {
					if id := tenant_at(g, end.x + dx, end.y + dy); id != 0 && hostile(&g.tenants[id]) {
						n += 1
					}
				}
			}
			if n >= 2 {
				return do_cast(g, s, .Gust_Ball, d)
			}
		}
	}
	if can(g, .Magic_Bolt, reserve) {
		caster := g.attr[.Intelligence] >= 14
		for d in DIRECTIONS {
			hit, end := bot_bolt(g, d, false)
			if hit != 0 && hostile(&g.tenants[hit]) && (caster || max(abs(end.x - g.x), abs(end.y - g.y)) > 1) {
				return do_cast(g, s, .Magic_Bolt, d)
			}
		}
	}
	return false
}
