#+build !js
package game

import "core:testing"

// A new item of a kind, put in the pack.
give :: proc(g: ^Game, k: Item_Kind) -> int {
	id := new_item(g, k)
	put_in(g, id, worn(g, .Pack))
	return id
}

// Turns pass without gusts or a dying torch getting in the way.
pass_turns :: proc(g: ^Game, n: int) {
	for _ in 0 ..< n {
		g.gust_in = 1000
		if id := worn(g, .Light); id != 0 {
			g.items[id].fuel = TORCH_TURNS
		}
		command(g, .Wait)
	}
}

@(test)
test_hunger_rises_and_starving_hurts :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	pass_turns(g, HUNGER_PECKISH)
	testing.expect_value(t, g.hunger, HUNGER_PECKISH)
	word, _ := hunger_word(g)
	testing.expect_value(t, word, "Peckish")
	g.hunger = HUNGER_STARVING
	before := g.health
	pass_turns(g, STARVE_PERIOD * 3)
	testing.expect(t, g.health <= before - 2, "starving costs health")
	testing.expect(t, g.health < before)
}

@(test)
test_eating_from_the_use_row :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.hunger = 700
	command(g, .Inventory)
	command(g, .East) // into the pack
	command(g, .South)
	command(g, .Confirm) // hold the first bread
	bread := g.inv.held
	testing.expect_value(t, g.items[bread].kind, Item_Kind.Bread)
	command(g, .West)
	for g.inv.cursor[0] < USE_ROW {
		command(g, .South)
	}
	command(g, .Confirm)
	testing.expect_value(t, g.items[bread].kind, Item_Kind.None)
	testing.expect_value(t, g.hunger, 700 - KIND[.Bread].food + 1)
	testing.expect_value(t, g.inv.held, 0)
	testing.expect_value(t, g.turn, 1)
	// The Use row with nothing held only explains itself.
	command(g, .Confirm)
	testing.expect_value(t, g.turn, 1)
}

@(test)
test_unknown_until_drunk :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	id := give(g, .Potion_Healing)
	look := look_name(g, .Potion_Healing)
	testing.expect_value(t, item_name(g, id), look)
	g.health = 2
	testing.expect(t, use_item(g, id))
	testing.expect(t, g.health >= 10)
	testing.expect(t, .Potion_Healing in g.ident)
	testing.expect_value(t, item_name(g, give(g, .Potion_Healing)), "Healing potion")
}

@(test)
test_looks_are_shuffled_per_character :: proc(t: ^testing.T) {
	differ := false
	first := new_game(1)
	defer free(first)
	for seed in u64(2) ..= 20 {
		g := new_game(seed)
		if g.look != first.look {
			differ = true
		}
		// Within a group every kind has its own look.
		seen: [4]bool
		for k in ([?]Item_Kind{.Potion_Healing, .Potion_Mana, .Potion_Blight, .Potion_Sight}) {
			testing.expect(t, !seen[g.look[int(k)]])
			seen[g.look[int(k)]] = true
		}
		free(g)
	}
	testing.expect(t, differ)
}

@(test)
test_identify_scroll_names_a_chosen_thing :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	scroll := give(g, .Scroll_Identify)
	ring := give(g, .Ring_Guard)
	open_inventory(g)
	g.inv.held = scroll
	act(g, 0, USE_ROW)
	testing.expect(t, g.inv.identify)
	testing.expect_value(t, g.mode, Mode.Inventory)
	testing.expect(t, .Scroll_Identify in g.ident)
	// The ring is in the open pack; choosing it names it.
	list: [MAX_ITEMS]int
	n := view_items(g, g.inv.view, &list)
	row := 0
	for i in 0 ..< n {
		if list[i] == ring {
			row = i + 1
		}
	}
	act(g, 1, row)
	testing.expect(t, !g.inv.identify)
	testing.expect(t, .Ring_Guard in g.ident)
	testing.expect_value(t, g.inv.held, 0)
}

@(test)
test_identify_spell_opens_the_inventory :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.known = {.Identify}
	cast_spell(g, .Identify, {0, 0})
	testing.expect_value(t, g.mode, Mode.Inventory)
	testing.expect(t, g.inv.identify)
	command(g, .Cancel)
	testing.expect(t, !g.inv.identify)
}

@(test)
test_a_cursed_ring_stays_on_until_uncursed :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	ring := give(g, .Ring_Draught)
	testing.expect(t, wear(g, ring, .Ring_Right))
	open_inventory(g)
	act(g, 0, 10) // the right ring row: will not come off
	testing.expect_value(t, g.inv.held, 0)
	testing.expect(t, .Ring_Draught in g.ident)
	scroll := give(g, .Scroll_Uncurse)
	g.inv.held = scroll
	act(g, 0, USE_ROW)
	act(g, 0, 10)
	testing.expect_value(t, g.inv.held, ring)
	act(g, 0, GROUND_ROW)
	testing.expect_value(t, g.items[ring].place, Place.Ground)
}

@(test)
test_cursed_jewellery_casts_on_you :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	wear(g, give(g, .Ring_Draught), .Ring_Left)
	snuffed := false
	for _ in 0 ..< 400 {
		g.lit = true
		pass_turns(g, 1)
		if !g.lit {
			snuffed = true
			break
		}
	}
	testing.expect(t, snuffed)
	wear(g, give(g, .Amulet_Hop), .Amulet)
	start := [2]int{g.x, g.y}
	moved := false
	for _ in 0 ..< 400 {
		pass_turns(g, 1)
		if g.x != start.x || g.y != start.y {
			moved = true
			break
		}
	}
	testing.expect(t, moved)
	testing.expect(t, .Amulet_Hop in g.ident)
}

@(test)
test_vigour_heals_faster :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	before := heal_period(g)
	wear(g, give(g, .Amulet_Vigour), .Amulet)
	testing.expect_value(t, heal_period(g), before / VIGOUR_HEAL)
}

@(test)
test_guard_ring_adds_armour :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	before := armour_worn(g)
	wear(g, give(g, .Ring_Guard), .Ring_Left)
	testing.expect_value(t, armour_worn(g), before + 2)
}

@(test)
test_spellbook_teaches :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	book := give(g, .Spellbook)
	use_item(g, book)
	testing.expect_value(t, card(g.known), 1)
}

@(test)
test_blight_can_kill :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.health = 1
	use_item(g, give(g, .Potion_Blight))
	testing.expect_value(t, g.mode, Mode.Dead)
	testing.expect_value(t, killed_by(g), "a bad potion")
}

@(test)
test_floors_hold_supplies :: proc(t: ^testing.T) {
	for seed in u64(1) ..= 20 {
		g := new_game(seed)
		for i in 0 ..< SLICE1_GENERATED {
			enter_floor(g, i, .Stairs_Down)
			groups: [Group]int
			food, books := 0, 0
			for &it in g.items {
				if it.place != .Ground || int(it.floor) != i {
					continue
				}
				groups[KIND[it.kind].group] += 1
				if KIND[it.kind].food > 0 {
					food += 1
				}
				if it.kind == .Spellbook {
					books += 1
				}
			}
			testing.expect(t, food >= 2)
			testing.expect(t, groups[.Potion] >= 1)
			testing.expect(t, groups[.Scroll] + groups[.Ring] + groups[.Amulet] >= 1)
			testing.expect_value(t, books, i == 2 ? 1 : 0)
		}
		free(g)
	}
}

@(test)
test_choosing_a_held_thing_again_uses_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.hunger = 500
	command(g, .Inventory)
	command(g, .East)
	command(g, .South)
	command(g, .Confirm) // hold the bread
	bread := g.inv.held
	command(g, .Confirm) // and again: eat it
	testing.expect_value(t, g.items[bread].kind, Item_Kind.None)
	testing.expect_value(t, g.hunger, 500 - KIND[.Bread].food + 1)
	// Something that cannot be used is let go instead.
	command(g, .West)
	command(g, .Confirm) // hold the dagger (the Hand row)
	dagger := g.inv.held
	testing.expect_value(t, g.items[dagger].kind, Item_Kind.Dagger)
	command(g, .Confirm)
	testing.expect_value(t, g.inv.held, 0)
	testing.expect_value(t, g.items[dagger].place, Place.Worn)
}
