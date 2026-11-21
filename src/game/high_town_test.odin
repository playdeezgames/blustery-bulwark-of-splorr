#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 26: the camps on floors 13 and 14, the wind cloak, and the town after the giant.

// Puts a wind cloak on you (in the cloak slot).
wear_wind_cloak :: proc(g: ^Game) -> int {
	id := new_item(g, .Wind_Cloak)
	put_in(g, id, worn(g, .Pack))
	if w := worn(g, .Cloak); w != 0 {
		free_item(g, w)
	}
	wear(g, id, .Cloak)
	return id
}

@(test)
test_the_wind_cloak_takes_a_cell_off_every_push :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = false
	id := wear_wind_cloak(g)
	testing.expect_value(t, worn(g, .Cloak), id)
	f := floor_of(g)
	for c in ([?][2]int{{1, 1}, {5, 1}, {13, 2}}) { // floor, cells pushed
		f.number = c[0]
		teleport(g, {20, 20})
		gust(g)
		testing.expectf(t, g.x - 20 == c[1], "floor %v: pushed %v", c[0], g.x - 20)
	}
	// With a heavy load that gives, on floor 13: 3, less one for the load, less one for the cloak.
	g.attr[.Strength] = 8
	sack := new_item(g, .Sack)
	put_in(g, sack, worn(g, .Pack))
	put_in(g, new_item(g, .Jools, 100), sack)
	f.number = 13
	for _ in 0 ..< 100 {
		teleport(g, {20, 20})
		gust(g)
		testing.expect(t, g.x - 20 == 0 || g.x - 20 == 1)
	}
	k := KIND[.Wind_Cloak]
	testing.expect_value(t, k.slot, Slot.Cloak)
	testing.expect_value(t, k.weight, 1500)
}

@(test)
test_floors_thirteen_and_fourteen_have_the_last_camps :: proc(t: ^testing.T) {
	testing.expect(t, is_camp_floor(13) && is_camp_floor(14) && !is_camp_floor(12) && !is_camp_floor(15))
	testing.expect_value(t, camp_gear(13), Item_Kind.Long_Sword)
	testing.expect_value(t, camp_gear(14), Item_Kind.Wind_Cloak)
	g := new_game(3)
	defer free(g)
	read_note(g, camp_note(13))
	testing.expect_value(t, NOTES[camp_note(13) - 1], "Day 230. Two floors to the champion. Everyone says he is undefeated. Nobody says by whom.")
	read_note(g, camp_note(14))
	testing.expect_value(t, NOTES[camp_note(14) - 1], "Turned back here. I could hear somebody upstairs, dusting.")
	sword := KIND[.Long_Sword]
	testing.expect_value(t, [3]int{sword.dmin, sword.dmax, sword.weight}, [3]int{3, 11, 2500})
}

@(test)
test_the_town_after_the_giant :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	receive_jools(g, 600)
	has_row :: proc(g: ^Game, act: Act, arg: int) -> bool {
		rows: [MAX_ROWS]Row
		n := shop_rows(g, &rows)
		for r in rows[:n] {
			if r.act == act && r.arg == arg {
				return true
			}
		}
		return false
	}
	go_in(g, .Smith)
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Long_Sword)))
	g.giant_dead = true
	testing.expect(t, has_row(g, .Buy, int(Item_Kind.Long_Sword)) && has_row(g, .Buy, int(Item_Kind.Plate_Armour)))
	testing.expect_value(t, [2]int{VALUE[.Long_Sword], VALUE[.Plate_Armour]}, [2]int{100, 160})
	plate := KIND[.Plate_Armour]
	testing.expect_value(t, [2]int{plate.armour, plate.weight}, [2]int{7, 22000})
	leave_shop(g)
	// The general store's anchor-weight.
	go_in(g, .General)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Anchor_Weight)))
	testing.expect_value(t, message(&g.last_said), "You buy an Anchor-weight. \"Holds you down. Also down.\"")
	testing.expect_value(t, KIND[.Anchor_Weight].weight, 8000)
	testing.expect_value(t, VALUE[.Anchor_Weight], 25)
	testing.expect(t, has_row(g, .Buy, int(Item_Kind.Anchor_Weight))) // as many as you like
	leave_shop(g)
	// The sage's wind cloak, once (the anchor-weight left behind to make room).
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Anchor_Weight {
			free_item(g, i)
		}
	}
	receive_jools(g, VALUE[.Wind_Cloak])
	go_in(g, .Sage)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Wind_Cloak)))
	testing.expectf(t, strings.has_prefix(message(&g.last_said), "You buy the Wind cloak."), "said %v", message(&g.last_said))
	testing.expect(t, g.sage_cloak && has_kind(g, .Wind_Cloak))
	testing.expect(t, !has_row(g, .Buy, int(Item_Kind.Wind_Cloak)))
	testing.expect_value(t, VALUE[.Wind_Cloak], 150)
}
