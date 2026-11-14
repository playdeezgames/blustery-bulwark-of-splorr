package game

// The wind and the light (slice 1 steps 2 and 3; DESIGN.md "Gusts are telegraphed by turn", "Gusts
// push the player unless their load anchors them", "Light burns down, and gusts snuff it"). Each
// floor has a prevailing wind; a gust comes every few turns, with a warning two turns before,
// pushes the player a tile downwind unless their load anchors them, carries light things on the
// ground along, and may blow out the torch. The torch in the light slot burns down one turn at a
// time; without light the player sees only the cells next to them.

COMPASS := [8]string{"N", "S", "W", "E", "NW", "NE", "SW", "SE"} // same order as DIRECTIONS

// Turns between gusts, by floor number (1 to 8; floors 5 to 8 from slice 2). Higher is windier.
GUST_PERIOD := [8]int{12, 11, 10, 8, 9, 8, 8, 8}
GUST_WARNING :: 2 // turns of warning before a gust

// Chance in 100 that a gust blows out a lit torch, by floor number.
SNUFF_CHANCE := [8]int{25, 35, 45, 60, 50, 55, 60, 65}

// Cells a gust pushes you (and light things and tenants), by floor number: 2 from floor 5.
gust_push :: proc(number: int) -> int {
	return number >= 5 ? 2 : 1
}

TORCH_TURNS :: 300 // a fresh torch
OIL_TURNS :: 600 // a lantern's flask of oil
LANTERN_SNUFF :: 3 // a gust snuffs a lit lantern a third as often as a torch
DARK_SIGHT :: 1

gust_period :: proc(number: int) -> int {
	return GUST_PERIOD[clamp(number, 1, len(GUST_PERIOD)) - 1]
}

snuff_chance :: proc(number: int) -> int {
	return SNUFF_CHANCE[clamp(number, 1, len(SNUFF_CHANCE)) - 1]
}

// The direction a floor's wind blows toward (it blows *from* COMPASS[wind_from]).
wind_blow :: proc(f: ^Floor) -> [2]int {
	return -DIRECTIONS[f.wind_from]
}

sight_radius :: proc(g: ^Game) -> int {
	return g.lit ? SIGHT : DARK_SIGHT
}

refresh_view :: proc(g: ^Game) {
	if in_town(g) { // daylight: the whole street is in view
		for y in 0 ..< FLOOR_H {
			for x in 0 ..< FLOOR_W {
				g.vis[y][x] = true
				g.town.seen[y][x] = true
			}
		}
		return
	}
	compute_fov(floor_of(g), g.x, g.y, sight_radius(g), &g.vis)
}

gust_warning :: proc(g: ^Game) -> bool {
	return g.gust_in > 0 && g.gust_in <= GUST_WARNING
}

// Everything that happens when a turn passes, after the player's action.
end_turn :: proc(g: ^Game) {
	if g.mode == .Dead {
		return
	}
	g.turn += 1
	f := floor_of(g)
	if g.lit && !in_town(g) { // daylight in town: the torch is not used up
		id := worn(g, .Light)
		if id == 0 || !is_light(g.items[id].kind) {
			g.lit = false
		} else {
			g.items[id].fuel -= 1
			if g.items[id].fuel <= 0 && g.items[id].kind == .Lantern {
				g.items[id].fuel = 0
				g.lit = false
				if oil_flasks(g) > 0 {
					say(g, "Yer lantern runs dry. Enter/OK to fill it.")
				} else {
					say(g, "Yer lantern runs dry, and you have no oil.")
				}
			} else if g.items[id].fuel <= 0 {
				free_item(g, id)
				g.lit = false
				if spare_torches(g) > 0 {
					say(g, "Yer torch burns out. Enter/OK to light another.")
				} else {
					say(g, "Yer torch burns out. That was the last.")
				}
			}
		}
	}
	tenants_act(g)
	if g.mode == .Dead {
		return
	}
	magic_turn(g)
	supplies_turn(g)
	if g.mode == .Dead {
		return
	}
	if g.turn % heal_period(g) == 0 && g.health < max_health(g) {
		g.health += 1
	}
	if in_town(g) { // no gusts reach the street
		refresh_view(g)
		return
	}
	g.gust_in -= 1
	if g.gust_in == GUST_WARNING {
		say(g, "The wind picks up from the ", COMPASS[f.wind_from], ".")
	}
	if g.gust_in <= 0 {
		gust(g)
		g.gust_in = gust_period(f.number)
	}
	refresh_view(g)
}

gust :: proc(g: ^Game) {
	f := floor_of(g)
	stop_travel(g)
	d := wind_blow(f)
	blow_items(g)
	blow_tenants(g)
	if anchored(g) {
		say(g, "A gust tugs at you. ", load_anchors(g) ? "Yer load" : "Yer spell", " holds you down.")
		g.anchor_spell = false
	} else {
		// Pushed cell by cell; a wall or a tenant in the way stops you, and "costs a little"
		// (DESIGN.md).
		moved := 0
		blocked := ""
		for _ in 0 ..< gust_push(f.number) {
			nx, ny := g.x + d.x, g.y + d.y
			if !passable(floor_cell(f, nx, ny)) {
				blocked = "the wall"
				break
			}
			if id := tenant_at(g, nx, ny); id != 0 {
				blocked = TENANT[g.tenants[id].kind].a
				break
			}
			g.x, g.y = nx, ny
			moved += 1
		}
		if blocked != "" {
			say(g, moved > 0 ? "A gust shoves you along and slams you into " : "A gust slams you into ", blocked, ".")
			hurt(g, 1, "the wind")
			if g.mode == .Dead {
				return
			}
		} else {
			say(g, moved > 1 ? "A gust hurls you " : "A gust shoves you ", COMPASS[direction_index(d)], ".")
		}
	}
	chance := snuff_chance(f.number)
	if g.items[worn(g, .Light)].kind == .Lantern {
		chance /= LANTERN_SNUFF
	}
	if g.lit && rng_int(&g.rng, 100) < chance {
		g.lit = false
		say(g, "The gust blows out yer ", light_name(g), ". Enter/OK to relight.")
	}
}

direction_index :: proc(d: [2]int) -> int {
	for v, i in DIRECTIONS {
		if v == d {
			return i
		}
	}
	return 0
}

// Torches carried but not in the light slot.
spare_torches :: proc(g: ^Game) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.kind == .Torch && !(it.place == .Worn && it.slot == .Light) && is_carried(g, i) {
			n += 1
		}
	}
	return n
}

is_light :: proc(k: Item_Kind) -> bool {
	return k == .Torch || k == .Lantern
}

// "torch" or "lantern": what is in the light slot.
light_name :: proc(g: ^Game) -> string {
	return g.items[worn(g, .Light)].kind == .Lantern ? "lantern" : "torch"
}

// Turns left in the torch or lantern in the light slot (0 when there is none).
light_fuel :: proc(g: ^Game) -> int {
	id := worn(g, .Light)
	if id == 0 || !is_light(g.items[id].kind) {
		return 0
	}
	return int(g.items[id].fuel)
}

// What can relight yer light: oil flasks for a lantern in the light slot, else spare torches.
light_spares :: proc(g: ^Game) -> int {
	return g.items[worn(g, .Light)].kind == .Lantern ? oil_flasks(g) : spare_torches(g)
}

oil_flasks :: proc(g: ^Game) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Oil_Flask && is_carried(g, i) {
			n += 1
		}
	}
	return n
}

has_tinderbox :: proc(g: ^Game) -> bool {
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Tinderbox && is_carried(g, i) {
			return true
		}
	}
	return false
}

// Confirm with nothing else to do: relight the torch in the light slot, or take a spare (the belt's
// first) into it and light that. A turn passes. Returns false when the torch is already lit.
light_torch :: proc(g: ^Game, takes_turn := true) -> bool {
	if g.lit {
		return false
	}
	quick := !takes_turn || has_tinderbox(g) // a tinderbox (or Kindle) takes no turn
	id := worn(g, .Light)
	if id != 0 && g.items[id].kind == .Torch {
		g.lit = true
		say(g, "You light yer torch.")
		refresh_view(g)
		if !quick {
			end_turn(g)
		}
		return true
	}
	if id != 0 && g.items[id].kind == .Lantern {
		if g.items[id].fuel <= 0 {
			oil := 0
			for i in 1 ..< MAX_ITEMS {
				if g.items[i].kind == .Oil_Flask && is_carried(g, i) {
					oil = i
				}
			}
			if oil == 0 {
				say(g, "Yer lantern is dry, and you have no oil.")
				return true
			}
			free_item(g, oil)
			g.items[id].fuel = OIL_TURNS
			say(g, "You fill yer lantern and light it.")
		} else {
			say(g, "You light yer lantern.")
		}
		g.lit = true
		refresh_view(g)
		if !quick {
			end_turn(g)
		}
		return true
	}
	if id != 0 {
		say(g, "Yer light hand holds the ", item_name(g, id), ".")
		return true
	}
	best := 0
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.kind != .Torch || !is_carried(g, i) {
			continue
		}
		on_belt := it.place == .Inside && g.items[it.parent].kind == .Belt
		if best == 0 || on_belt {
			best = i
		}
		if on_belt {
			break
		}
	}
	if best == 0 {
		say(g, "You have no torch to light.")
		return true
	}
	unplace(g, best)
	g.items[best].place, g.items[best].slot = .Worn, .Light
	g.lit = true
	say(g, "You light a fresh torch.")
	refresh_view(g)
	if !quick {
		end_turn(g)
	}
	return true
}
