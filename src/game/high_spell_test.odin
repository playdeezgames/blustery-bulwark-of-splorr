#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 27: Heal, Shelter and Tempest, from level 13.

@(test)
test_the_slice_four_spells_come_at_level_thirteen :: proc(t: ^testing.T) {
	for s in ([?]Spell{.Heal, .Shelter, .Tempest}) {
		testing.expect_value(t, spell_level(s), 13)
	}
	testing.expect_value(t, [3]int{SPELL[.Heal].cost, SPELL[.Shelter].cost, SPELL[.Tempest].cost}, [3]int{8, 6, 10})
	testing.expect(t, SPELL[.Tempest].aimed && !SPELL[.Heal].aimed && !SPELL[.Shelter].aimed)
	testing.expect_value(t, size_of(bit_set[Spell]), 4) // 21 spells still fit; saves keep their shape
	g := new_game()
	defer free(g)
	g.known = {}
	out: [len(Spell)]Spell
	g.level = 12
	n := learnable(g, &out)
	for s in out[:n] {
		testing.expect(t, s != .Heal && s != .Shelter && s != .Tempest)
	}
	g.level = 13
	testing.expect_value(t, learnable(g, &out), n + 3)
}

@(test)
test_heal_restores_half_yer_health :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.level = 13
	g.attr[.Intelligence] = ATTR_BASE
	g.mana = 99
	g.health = 1
	cast_spell(g, .Heal, {})
	testing.expect_value(t, g.health, 1 + max_health(g) / 2)
	testing.expect(t, strings.has_prefix(message(&g.last_said), "You heal "))
	cast_spell(g, .Heal, {})
	cast_spell(g, .Heal, {})
	testing.expect_value(t, g.health, max_health(g)) // never past full
}

@(test)
test_shelter_stops_every_push_for_forty_turns :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.mana = 99
	floor_of(g).number = 13
	cast_spell(g, .Shelter, {})
	testing.expect_value(t, g.shelter_turns, SHELTER_TURNS - 1) // the cast took a turn
	g.lit = true
	snuffed := false
	for _ in 0 ..< 30 {
		teleport(g, {20, 20})
		gust(g)
		testing.expect_value(t, [2]int{g.x, g.y}, [2]int{20, 20})
		if !g.lit {
			snuffed = true
			g.lit = true
		}
	}
	testing.expect(t, snuffed) // the light still goes out
	testing.expect_value(t, int(g.wind_seen.held), 30)
	g.anchor_spell = true
	gust(g)
	testing.expect(t, g.anchor_spell) // an Anchor waits for the shelter to end
	g.anchor_spell = false
	for g.shelter_turns > 0 {
		magic_turn(g)
	}
	testing.expect(t, strings.has_prefix(message(&g.last_said), "Yer shelter gives way."))
	g.lit = false
	teleport(g, {20, 20})
	gust(g)
	testing.expect_value(t, g.x, 23)
}

@(test)
test_a_tempest_hurts_and_shoves_every_tenant_on_its_line :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.mana = 99
	g.attr[.Intelligence] = ATTR_BASE
	a := new_tenant(g, .Lizard, g.current, 22, 20)
	b := new_tenant(g, .Lizard, g.current, 25, 20)
	far := new_tenant(g, .Lizard, g.current, 28, 20) // 8 cells off: beyond the line
	cast_gale(g, {1, 0}, true) // without the turn after, so nobody steps back
	want := [2]int{24, 27}
	for id, i in ([?]int{a, b}) {
		tn := g.tenants[id]
		testing.expect_value(t, int(tn.x), want[i]) // shoved 2
		lost := TENANT[.Lizard].health - int(tn.health)
		testing.expect(t, lost >= TEMPEST_DMIN && lost <= TEMPEST_DMAX)
	}
	testing.expect_value(t, int(g.tenants[far].health), TENANT[.Lizard].health)
	said := false
	for i in 0 ..< LOG_LINES {
		if strings.has_prefix(message(&g.log[i]), "A tempest tears out of yer hands.") {
			said = true
		}
	}
	testing.expect(t, said)
	// Against the wind it still shoves 2 (a gale would shove only 1).
	g.tenants[a] = {}
	g.tenants[b] = {}
	g.tenants[far] = {}
	c := new_tenant(g, .Lizard, g.current, 18, 20)
	cast_gale(g, {-1, 0}, true)
	testing.expect_value(t, int(g.tenants[c].x), 16)
	// Into a wall: the slam adds 1 to 3.
	g.tenants[c] = {}
	teleport(g, {FLOOR_W - 4, 20})
	w := new_tenant(g, .Lizard, g.current, FLOOR_W - 2, 20)
	cast_gale(g, {1, 0}, true)
	testing.expect_value(t, int(g.tenants[w].x), FLOOR_W - 2)
	testing.expect(t, TENANT[.Lizard].health - int(g.tenants[w].health) >= TEMPEST_DMIN + 1)
}

// Every spell's name ends before its cost (the step 27 review found "Find the Stairs" running into it).
@(test)
test_every_spell_name_fits_before_its_cost :: proc(t: ^testing.T) {
	for s in Spell {
		testing.expectf(t, 12 + len(SPELL[s].name) * GLYPH_W < MENU_COST_X, "%v is too long", SPELL[s].name)
	}
}
