#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 30: the ending.

herald_rows_have :: proc(g: ^Game, act: Act) -> bool {
	rows: [MAX_ROWS]Row
	n := shop_rows(g, &rows)
	for r in rows[:n] {
		if r.act == act {
			return true
		}
	}
	return false
}

@(test)
test_after_the_lord_you_tell_the_herald_and_the_game_ends :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	go_in(g, .Herald)
	testing.expect(t, !herald_rows_have(g, .Tell)) // not before you have met him
	leave_shop(g)
	g.lord_met = true
	g.turn, g.deaths, g.level, g.kills = 23456, 3, 34, 250
	go_in(g, .Herald)
	testing.expect(t, choose(g, .Tell))
	testing.expect_value(t, g.mode, Mode.End)
	testing.expect(t, g.ended)
	testing.expect_value(t, g.shop, Shop.None)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The herald: \"Then who blows the wind?"))
	// The end screen shows the climb's numbers.
	fr := new(Frame)
	defer free(fr)
	draw_game(fr, g)
	// Enter/OK plays on, in the town.
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.current, TOWN)
	// The row is gone, and the herald proclaims as ever.
	go_in(g, .Herald)
	testing.expect(t, !herald_rows_have(g, .Tell))
	testing.expect(t, herald_rows_have(g, .Ask))
	leave_shop(g)
	g.kills += 5
	enter_floor(g, 0, .Stairs_Down)
	enter_town(g, .Gate)
	testing.expect(t, strings.has_prefix(string(g.proclamation[:g.proclamation_n]), "His Lordship has "))
	// A click plays on too.
	g.mode = .End
	pointer(g, 100, 100, .Mouse_Primary)
	testing.expect_value(t, g.mode, Mode.Play)
}

// Up the whole way by the stairs: floor 15's door, the roof, the lord, down, and the herald.
@(test)
test_the_ending_from_the_roof :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	enter_floor(g, CHAMPION_INDEX, .Stairs_Down)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, g.current, LORD_INDEX)
	lord := 0
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Lord {
			lord = i
		}
	}
	teleport(g, {int(g.tenants[lord].x) - 1, int(g.tenants[lord].y)})
	command(g, .East)
	command(g, .Confirm) // the notice
	g.mana = 99
	cast_spell(g, .Return, {})
	testing.expect_value(t, g.current, TOWN)
	go_in(g, .Herald)
	testing.expect(t, choose(g, .Tell))
	testing.expect_value(t, g.mode, Mode.End)
}
