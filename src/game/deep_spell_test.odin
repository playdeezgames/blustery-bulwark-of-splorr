#+build !js
package game

import "core:testing"

// Slice 3 step 21: the four spells from level 9 and the scrolling spell list.

// Opens the floor round you into one hall, with nobody in it and the next gust far off.
open_hall :: proc(g: ^Game, r: int) {
	f := floor_of(g)
	for y in max(1, g.y - r) ..= min(FLOOR_H - 2, g.y + r) {
		for x in max(1, g.x - r) ..= min(FLOOR_W - 2, g.x + r) {
			f.cells[y][x] = .Floor
		}
	}
	for &tn in g.tenants {
		if int(tn.floor) == g.current {
			tn = {}
		}
	}
	g.gust_in = 99
}

@(test)
test_the_slice_three_spells_come_at_level_nine :: proc(t: ^testing.T) {
	for s in ([?]Spell{.Uncurse, .Clairvoyance, .Teleport, .Squall}) {
		testing.expect_value(t, spell_level(s), 9)
	}
	testing.expect_value(t, [4]int{SPELL[.Uncurse].cost, SPELL[.Clairvoyance].cost, SPELL[.Teleport].cost, SPELL[.Squall].cost}, [4]int{6, 5, 7, 8})
	testing.expect(t, SPELL[.Squall].aimed && !SPELL[.Teleport].aimed)
	for s in Spell {
		testing.expect(t, len(SPELL[s].use) <= 23)
	}
}

@(test)
test_uncurse_frees_what_you_wear :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	pack := worn(g, .Pack)
	g.items[pack].cursed = true
	g.mana = 20
	cast_spell(g, .Uncurse, {0, 0})
	testing.expect(t, !g.items[pack].cursed)
	testing.expect_value(t, message(&g.last_said), "A weight lifts. What you wear will come off now.")
	cast_spell(g, .Uncurse, {0, 0})
	testing.expect_value(t, message(&g.last_said), "Nothing you wear was cursed.")
}

@(test)
test_clairvoyance_maps_twelve_cells_round_you :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, 8, .Stairs_Down)
	f := floor_of(g)
	g.mana = 20
	cast_spell(g, .Clairvoyance, {0, 0})
	px, py := g.x, g.y // Clairvoyance does not move you
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if f.cells[y][x] == .Wall {
				continue
			}
			d := max(abs(x - px), abs(y - py))
			if d <= CLAIRVOYANCE_RANGE {
				testing.expectf(t, f.seen[y][x], "%v,%v (%v away) not mapped", x, y, d)
			}
		}
	}
	// Somewhere far off stays unseen.
	far := false
	for y in 0 ..< FLOOR_H {
		for x in 0 ..< FLOOR_W {
			if f.cells[y][x] != .Wall && max(abs(x - px), abs(y - py)) > CLAIRVOYANCE_RANGE + 10 && !f.seen[y][x] {
				far = true
			}
		}
	}
	testing.expect(t, far)
}

@(test)
test_teleport_lands_far_away :: proc(t: ^testing.T) {
	for seed in u64(1) ..= 10 {
		g := new_game_with_tenants(seed)
		enter_floor(g, 8, .Stairs_Down)
		x, y := g.x, g.y
		g.mana = 20
		cast_spell(g, .Teleport, {0, 0})
		testing.expect(t, max(abs(g.x - x), abs(g.y - y)) >= TELEPORT_MIN)
		testing.expect(t, passable(cell_at(g, g.x, g.y)))
		testing.expect_value(t, message(&g.last_said), "The wind drops you somewhere else entirely.")
		free(g)
	}
}

@(test)
test_a_squall_bursts_harder_and_spares_you :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, 8, .Stairs_Down)
	open_hall(g, 8)
	d := wind_blow(floor_of(g))
	// Right next to you: the burst catches it and leaves you be.
	rat := new_tenant(g, .Rat, g.current, g.x + d.x, g.y + d.y)
	g.tenants[rat].health = 50
	g.mana, g.health = 30, max_health(g)
	cast_spell(g, .Squall, d)
	lost := 50 - int(g.tenants[rat].health)
	testing.expect(t, lost >= 3 + spell_bonus(g) && lost <= 8 + spell_bonus(g))
	testing.expect_value(t, g.health, max_health(g))
	// Out along the wind it flies 4 cells and more with the wind behind it.
	g.tenants[rat] = {}
	far := new_tenant(g, .Rat, g.current, g.x + 4 * d.x, g.y + 4 * d.y)
	g.tenants[far].health = 50
	g.gust_in = 99
	cast_spell(g, .Squall, d)
	testing.expect(t, g.tenants[far].health < 50)
	// With nobody in the way it bursts at the end of that reach.
	g.tenants[far] = {}
	g.gust_in = 99
	cast_spell(g, .Squall, d)
	testing.expect(t, g.fx_blast)
	testing.expect_value(t, g.fx_at, [2]int{g.x, g.y} + (SQUALL_RANGE + d.x * d.x + d.y * d.y) * d) // the wind behind it adds 1 a step of the line
}

@(test)
test_a_long_spell_list_scrolls :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	for s in Spell {
		g.known += {s}
	}
	g.learns = 0
	open_cast(g)
	testing.expect_value(t, g.mode, Mode.Cast)
	for _ in 0 ..< len(Spell) - 1 {
		command(g, .South)
	}
	testing.expect_value(t, g.menu_row, len(Spell) - 1)
	testing.expect_value(t, g.spell_scroll, len(Spell) - SPELL_ROWS)
	command(g, .South) // wraps to the top
	testing.expect_value(t, g.menu_row, 0)
	testing.expect_value(t, g.spell_scroll, 0)
	// A click on the first row shown picks the spell there, scrolled or not.
	command(g, .North)
	testing.expect_value(t, menu_pointer(g, 20, MENU_TOP, len(Spell)), g.spell_scroll)
}
