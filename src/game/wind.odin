package game

// The wind and the light (slice 1 steps 2 and 3; DESIGN.md "Gusts are telegraphed by turn", "Gusts
// push the player unless their load anchors them", "Light burns down, and gusts snuff it"). Each
// floor has a prevailing wind; a gust comes every few turns, with a warning two turns before,
// pushes the player a tile downwind unless their load anchors them, carries light things on the
// ground along, and may blow out the torch. The torch in the light slot burns down one turn at a
// time; without light the player sees only the cells next to them.

COMPASS := [8]string{"N", "S", "W", "E", "NW", "NE", "SW", "SE"} // same order as DIRECTIONS

// Turns between gusts, by floor number (1 to 4; floor 4 arrives in step 8). Higher is windier.
GUST_PERIOD := [4]int{12, 11, 10, 8}
GUST_WARNING :: 2 // turns of warning before a gust

// Chance in 100 that a gust blows out a lit torch, by floor number.
SNUFF_CHANCE := [4]int{25, 35, 45, 60}

TORCH_TURNS :: 300 // a fresh torch
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
		if id == 0 || g.items[id].kind != .Torch {
			g.lit = false
		} else {
			g.items[id].fuel -= 1
			if g.items[id].fuel <= 0 {
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
	} else if passable(floor_cell(f, g.x + d.x, g.y + d.y)) {
		g.x += d.x
		g.y += d.y
		say(g, "A gust shoves you ", COMPASS[direction_index(d)], ".")
	} else {
		// "Costs a little" (DESIGN.md).
		say(g, "A gust slams you into the wall.")
		hurt(g, 1, "the wind")
		if g.mode == .Dead {
			return
		}
	}
	if g.lit && rng_int(&g.rng, 100) < snuff_chance(f.number) {
		g.lit = false
		say(g, "The gust blows out yer torch. Enter/OK to relight.")
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

// Turns left in the torch in the light slot (0 when there is none).
torch_fuel :: proc(g: ^Game) -> int {
	id := worn(g, .Light)
	if id == 0 || g.items[id].kind != .Torch {
		return 0
	}
	return int(g.items[id].fuel)
}

// Confirm with nothing else to do: relight the torch in the light slot, or take a spare (the belt's
// first) into it and light that. A turn passes. Returns false when the torch is already lit.
light_torch :: proc(g: ^Game, takes_turn := true) -> bool {
	if g.lit {
		return false
	}
	id := worn(g, .Light)
	if id != 0 && g.items[id].kind == .Torch {
		g.lit = true
		say(g, "You light yer torch.")
		refresh_view(g)
		if takes_turn {
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
	if takes_turn {
		end_turn(g)
	}
	return true
}
