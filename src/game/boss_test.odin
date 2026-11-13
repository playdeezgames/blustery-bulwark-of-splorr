#+build !js
package game

import "core:testing"

// Floor 4 with its tenants, the player on its stairs down, no gust coming.
boss_game :: proc() -> ^Game {
	g := new_game()
	g.no_tenants = false
	enter_floor(g, BOSS_INDEX, .Stairs_Down)
	g.gust_in = 1000
	return g
}

count_kind :: proc(g: ^Game, k: Tenant_Kind) -> int {
	n := 0
	for &t in g.tenants {
		if t.kind == k && int(t.floor) == BOSS_INDEX {
			n += 1
		}
	}
	return n
}

find_kind :: proc(g: ^Game, k: Tenant_Kind) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == k && int(g.tenants[i].floor) == BOSS_INDEX {
			return i
		}
	}
	return 0
}

@(test)
test_floor_four_holds_the_horde :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	f := floor_of(g)
	testing.expect_value(t, f.number, 4)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
	testing.expect_value(t, count_kind(g, .Skeleton), 1)
	testing.expect_value(t, count_kind(g, .Bones), 6)
	testing.expect(t, g.ticket != 0 && g.tenants[g.ticket].kind == .Carny)
	testing.expect_value(t, gust_period(f.number), 8)
	// The carny at the door stays put.
	at := [2]int{int(g.tenants[g.ticket].x), int(g.tenants[g.ticket].y)}
	for _ in 0 ..< 20 {
		command(g, .Wait)
	}
	testing.expect_value(t, [2]int{int(g.tenants[g.ticket].x), int(g.tenants[g.ticket].y)}, at)
}

@(test)
test_admission_moves_the_carny_aside :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	c := g.tenants[g.ticket]
	teleport(g, {int(c.x), int(c.y) + 1})
	before := carried_jools(g)
	command(g, .North)
	testing.expect_value(t, g.shop, Shop.Admission)
	testing.expect(t, choose(g, .Admit))
	testing.expect(t, g.admitted)
	testing.expect_value(t, carried_jools(g), before - ADMISSION)
	testing.expect_value(t, [2]int{int(g.tenants[g.ticket].x), int(g.tenants[g.ticket].y)}, boss_alcove())
	testing.expect_value(t, g.mode, Mode.Play)
	command(g, .North) // the doorway is clear
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{int(c.x), int(c.y)})
}

@(test)
test_shoving_past_the_door_carny_angers_it :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	c := g.tenants[g.ticket]
	teleport(g, {int(c.x), int(c.y) + 1})
	command(g, .North)
	testing.expect(t, choose(g, .Shove))
	testing.expect(t, g.tenants[g.ticket].kind == .None || hostile(&g.tenants[g.ticket]))
}

@(test)
test_the_bones_are_only_propped_up :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	id := find_kind(g, .Bones)
	b := g.tenants[id]
	testing.expect(t, !hostile(&g.tenants[id]))
	teleport(g, {int(b.x) + 1, int(b.y)})
	command(g, .West)
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.None)
	testing.expect_value(t, g.xp, 0)
	testing.expect_value(t, g.kills, 0)
	testing.expect_value(t, g.items[ground_item_at(g, int(b.x), int(b.y))].kind, Item_Kind.Old_Bones)
	// Gusts knock the rest over in time.
	for _ in 0 ..< 60 {
		gust(g)
	}
	testing.expect_value(t, count_kind(g, .Bones), 0)
}

@(test)
test_the_skeleton_drops_the_key_to_floor_five :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	id := find_kind(g, .Skeleton)
	s := g.tenants[id]
	g.tenants[id].health = 1
	g.attr[.Dexterity] = 100
	teleport(g, {int(s.x) + 1, int(s.y)})
	for _ in 0 ..< 50 {
		if g.tenants[id].kind == .None {
			break
		}
		g.health = max_health(g)
		command(g, .West)
	}
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.None)
	testing.expect(t, g.boss_dead)
	// The key and a skull lie where it fell.
	teleport(g, {int(s.x), int(s.y)})
	kinds: [2]Item_Kind
	n := 0
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place == .Ground && int(it.floor) == BOSS_INDEX && int(it.x) == int(s.x) && int(it.y) == int(s.y) && n < 2 {
			kinds[n] = it.kind
			n += 1
		}
	}
	testing.expect_value(t, n, 2)
	if g.mode == .Learn {
		command(g, .Confirm) // the level the kill gave: a spell first
	}
	// The key lies on top: you see it, and one Enter takes it.
	testing.expect_value(t, g.items[ground_item_at(g, g.x, g.y)].kind, Item_Kind.Key)
	command(g, .Confirm)
	testing.expect(t, has_key(g))
	testing.expect_value(t, g.mode, Mode.Play) // the end-of-slice notice moved to the key to floor 9
	// The door opens on floor 5 (slice 2), and its stairs down lead back to the door.
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 5)
	testing.expect_value(t, floor_of(g).w, 64)
	command(g, .Confirm) // on floor 5's stairs down
	testing.expect_value(t, floor_of(g).number, 4)
	testing.expect_value(t, [2]int{g.x, g.y}, floor_of(g).up)
	// Back in town the herald claims it.
	cast_spell(g, .Return, {0, 0})
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has destroyed the Undead Horde, as foretold.")
}

@(test)
test_the_windchute_opens_once_floor_four_is_reached :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	teleport(g, g.town.up)
	command(g, .Confirm) // before: straight up the stairs
	testing.expect_value(t, g.current, 0)
	g.deepest = 4
	enter_town(g, .Gate)
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect_value(t, g.shop, Shop.Gate)
	testing.expect(t, choose(g, .Chute))
	testing.expect_value(t, g.current, BOSS_INDEX)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
}

// A key lost in a fall above floor 4 must not lock you out: the door stays open once opened.
@(test)
test_the_door_to_floor_five_stays_open :: proc(t: ^testing.T) {
	g := boss_game()
	defer free(g)
	id := new_item(g, .Key)
	testing.expect(t, stow(g, id))
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 5)
	free_item(g, id) // lost
	enter_floor(g, BOSS_INDEX, .Stairs_Up)
	command(g, .Confirm)
	testing.expect_value(t, floor_of(g).number, 5)
}
