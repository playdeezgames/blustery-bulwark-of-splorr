package game

// The wind and the light (slice 1 step 2; DESIGN.md "Gusts are telegraphed by turn", "Light burns
// down, and gusts snuff it"). Each floor has a prevailing wind; a gust comes every few turns, with a
// warning two turns before, pushes the player a tile downwind (until step 3 nothing anchors them),
// and may blow out the torch. A torch burns down one turn at a time; without light the player sees
// only the cells next to them.

COMPASS := [8]string{"N", "S", "W", "E", "NW", "NE", "SW", "SE"} // same order as DIRECTIONS

// Turns between gusts, by floor number (1 to 4; floor 4 arrives in step 8). Higher is windier.
GUST_PERIOD := [4]int{12, 11, 10, 8}
GUST_WARNING :: 2 // turns of warning before a gust

// Chance in 100 that a gust blows out a lit torch, by floor number.
SNUFF_CHANCE := [4]int{25, 35, 45, 60}

TORCH_TURNS :: 300 // a fresh torch
START_SPARE_TORCHES :: 2 // until the inventory (step 3) holds real torches
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
	compute_fov(floor_of(g), g.x, g.y, sight_radius(g), &g.vis)
}

gust_warning :: proc(g: ^Game) -> bool {
	return g.gust_in > 0 && g.gust_in <= GUST_WARNING
}

// Everything that happens when a turn passes, after the player's action.
end_turn :: proc(g: ^Game) {
	g.turn += 1
	f := floor_of(g)
	if g.lit {
		g.torch -= 1
		if g.torch <= 0 {
			g.torch = 0
			g.lit = false
			if g.spare_torches > 0 {
				say(g, "Yer torch burns out. Confirm to light another.")
			} else {
				say(g, "Yer torch burns out. That was the last.")
			}
		}
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
	if passable(floor_cell(f, g.x + d.x, g.y + d.y)) {
		g.x += d.x
		g.y += d.y
		say(g, "A gust shoves you ", COMPASS[direction_index(d)], ".")
	} else {
		// "Costs a little" (DESIGN.md): health arrives in step 4; for now it is only said.
		say(g, "A gust slams you into the wall.")
	}
	if g.lit && rng_int(&g.rng, 100) < snuff_chance(f.number) {
		g.lit = false
		say(g, "The gust blows out yer torch. Confirm to relight.")
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

// Confirm with no stairs underfoot: relight a blown-out torch, or light a spare. A turn passes.
// Returns false when there is nothing to light.
light_torch :: proc(g: ^Game) -> bool {
	if g.lit {
		return false
	}
	if g.torch > 0 {
		g.lit = true
		say(g, "You relight yer torch.")
	} else if g.spare_torches > 0 {
		g.spare_torches -= 1
		g.torch = TORCH_TURNS
		g.lit = true
		say(g, "You light a fresh torch.")
	} else {
		say(g, "You have no torch to light.")
		return true
	}
	end_turn(g)
	return true
}
