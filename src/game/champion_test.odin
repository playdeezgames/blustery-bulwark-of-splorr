#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 28: floor 15, His Lordship's champion, undefeated.

champion_game :: proc(seed: u64 = 1) -> ^Game {
	g := new_game(seed)
	g.no_tenants = false
	enter_floor(g, CHAMPION_INDEX, .Stairs_Down)
	g.gust_in = 1000
	return g
}

find_champion :: proc(g: ^Game) -> int {
	for i in 1 ..< MAX_TENANTS {
		if g.tenants[i].kind == .Champion || g.tenants[i].kind == .Champion_Seated {
			return i
		}
	}
	return 0
}

log_has :: proc(g: ^Game, prefix: string) -> bool {
	for i in 0 ..< LOG_LINES {
		if strings.has_prefix(message(&g.log[i]), prefix) {
			return true
		}
	}
	return false
}

@(test)
test_floor_fifteen_holds_only_the_champion :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	enter_floor(g, CHAMPION_INDEX - 1, .Stairs_Down)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	f := floor_of(g)
	testing.expect_value(t, f.number, 15)
	testing.expect_value(t, [2]int{g.x, g.y}, f.down)
	testing.expect_value(t, f.wind_from, 2)
	testing.expect_value(t, gust_period(15), 5)
	testing.expect(t, log_has(g, "A sign by the door: \"Undefeated."))
	testing.expect_value(t, count_tenants(g, CHAMPION_INDEX), 1) // no carny: nobody has ever come
	id := find_champion(g)
	testing.expect(t, id != 0 && g.tenants[id].kind == .Champion)
	testing.expect_value(t, int(g.tenants[id].health), 60)
	cabinet := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Trophy_Cabinet && int(g.items[i].floor) == CHAMPION_INDEX {
			cabinet = i
		}
	}
	testing.expect(t, cabinet != 0 && KIND[.Trophy_Cabinet].fixed)
	teleport(g, {int(g.items[cabinet].x), int(g.items[cabinet].y)})
	command(g, .Confirm)
	testing.expect_value(t, message(&g.last_said), "A trophy cabinet, dusted daily. Nothing in it.")
	// He stands guard until he sees you.
	at := [2]i16{g.tenants[id].x, g.tenants[id].y}
	g.lit = false
	teleport(g, f.down)
	for _ in 0 ..< 20 {
		tenant_act(g, id)
	}
	testing.expect_value(t, [2]i16{g.tenants[id].x, g.tenants[id].y}, at)
	// No restocking; saves rebuild the hall.
	enter_floor(g, CHAMPION_INDEX - 1, .Stairs_Up)
	g.turn += 10 * RESTOCK_TURNS
	enter_floor(g, CHAMPION_INDEX, .Stairs_Down)
	testing.expect_value(t, count_tenants(g, CHAMPION_INDEX), 1)
	before := f.cells
	f.cells = {}
	restore_cells(g)
	testing.expect(t, f.cells == before)
}

@(test)
test_the_champion_learns_as_he_fights :: proc(t: ^testing.T) {
	g := champion_game()
	defer free(g)
	id := find_champion(g)
	testing.expect_value(t, champion_hit(g), 30)
	teleport(g, {int(g.tenants[id].x) - 1, int(g.tenants[id].y)})
	g.tenants[id].awake = true
	for i in 1 ..= 9 {
		g.health = max_health(g)
		tenant_act(g, id)
		testing.expect_value(t, champion_hit(g), min(75, 30 + 5 * i))
	}
	testing.expect(t, log_has(g, "He is getting the hang of this."))
	tenant_act(g, id)
	testing.expect_value(t, champion_hit(g), 75)
	// A quick fight is a kind one: early on he lands far fewer blows.
	early, late := 0, 0
	for seed in 1 ..= 200 {
		a := champion_game(u64(seed))
		cid := find_champion(a)
		teleport(a, {int(a.tenants[cid].x) - 1, int(a.tenants[cid].y)})
		a.tenants[cid].awake = true
		hp := a.health
		tenant_attack(a, cid)
		if a.health < hp {
			early += 1
		}
		a.champion_fights = 20
		a.health = max_health(a)
		hp = a.health
		tenant_attack(a, cid)
		if a.health < hp {
			late += 1
		}
		free(a)
	}
	testing.expect(t, early * 2 < late)
}

@(test)
test_the_champion_yields_and_never_dies :: proc(t: ^testing.T) {
	g := champion_game()
	defer free(g)
	id := find_champion(g)
	teleport(g, {int(g.tenants[id].x) - 1, int(g.tenants[id].y)})
	xp, kills := g.xp, g.kills
	g.tenants[id].health = 20
	spell_hit(g, id, 50, "bolt") // far more than he has left
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.Champion_Seated)
	testing.expect(t, g.tenants[id].health >= 1)
	testing.expect(t, g.champion_yielded)
	testing.expect_value(t, g.xp, xp + 60)
	testing.expect_value(t, g.kills, kills) // he was not killed
	testing.expect(t, has_kind(g, .Key_Sixteen))
	testing.expect(t, log_has(g, "The champion sits down."))
	testing.expect(t, log_has(g, "He gives you the key to floor 16."))
	// Seated, he does not fight, and spells pass him by.
	hp := g.health
	for _ in 0 ..< 10 {
		tenant_act(g, id)
	}
	testing.expect_value(t, g.health, hp)
	spell_hit(g, id, 50, "bolt")
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.Champion_Seated)
	// Bump him: nobody has been higher, and he goes down to town.
	command(g, .East)
	testing.expect(t, log_has(g, "\"Nobody has been higher."))
	testing.expect(t, log_has(g, "He dusts where he sat and goes to town."))
	testing.expect_value(t, find_champion(g), 0)
	// A blow that would have killed him outright, too.
	b := champion_game(2)
	defer free(b)
	bid := find_champion(b)
	kill_tenant(b, bid)
	testing.expect_value(t, b.tenants[bid].kind, Tenant_Kind.Champion_Seated)
	// Leaving the floor without talking: he has gone when you come back.
	enter_floor(b, CHAMPION_INDEX - 1, .Stairs_Up)
	enter_floor(b, CHAMPION_INDEX, .Stairs_Down)
	testing.expect_value(t, find_champion(b), 0)
}

@(test)
test_the_door_to_floor_sixteen_was_never_locked :: proc(t: ^testing.T) {
	g := champion_game()
	defer free(g)
	teleport(g, floor_of(g).up)
	command(g, .Confirm)
	testing.expect(t, log_has(g, "The door opens."))
	testing.expect_value(t, message(&g.last_said), "You climb out onto the roof. The wind is strongest here.")
	testing.expect_value(t, g.current, LORD_INDEX)
	testing.expect(t, CHAMPION_INDEX in g.unlocked)
	b := champion_game()
	defer free(b)
	receive_item(b, .Key_Sixteen)
	teleport(b, floor_of(b).up)
	command(b, .Confirm)
	testing.expect(t, log_has(b, "The key turns."))
	testing.expect(t, !log_has(b, "The door opens."))
}

@(test)
test_after_the_champion_the_herald_the_chute_and_the_tavern :: proc(t: ^testing.T) {
	g := champion_game()
	defer free(g)
	g.champion_yielded = true
	g.giant_told, g.army_told = true, true
	g.told = {g.deepest, g.level, g.kills, g.deaths, g.boss_dead}
	enter_town(g, .Gate)
	testing.expect_value(t, string(g.proclamation[:g.proclamation_n]), "His Lordship has crushed the treacherous champion, as foretold.")
	testing.expect(t, g.champion_told)
	// The windchute reaches floor 15.
	teleport(g, g.town.up)
	command(g, .Confirm)
	testing.expect(t, choose(g, .Chute, CHAMPION_INDEX))
	testing.expect_value(t, g.current, CHAMPION_INDEX)
	enter_town(g, .Gate)
	go_in(g, .Tavern)
	testing.expect(t, choose(g, .Talk, 1))
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The champion: "))
	testing.expect(t, choose(g, .Talk, 0))
	testing.expect(t, strings.has_prefix(message(&g.last_said), "The mentor: "))
	// Before he yields, he is not in the tavern.
	b := town_game()
	defer free(b)
	go_in(b, .Tavern)
	testing.expect(t, !choose(b, .Talk, 1))
	testing.expect(t, !sellable_kind(.Key_Sixteen))
}

sellable_kind :: proc(k: Item_Kind) -> bool {
	g := town_game()
	defer free(g)
	receive_item(g, k)
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == k {
			return sellable(g, i)
		}
	}
	return false
}
