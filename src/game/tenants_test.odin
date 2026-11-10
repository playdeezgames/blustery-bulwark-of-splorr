#+build !js
package game

import "core:testing"

// A game past creation with its floor 1 tenants, as play has it.
new_game_with_tenants :: proc(seed: u64 = 12345) -> ^Game {
	g := new(Game)
	init_game(g, seed)
	g.mode = .Play
	return g
}

count_tenants :: proc(g: ^Game, index: int) -> (n: int, carnies: int) {
	for &t in g.tenants {
		if t.kind != .None && int(t.floor) == index {
			n += 1
			if t.kind == .Carny {
				carnies += 1
			}
		}
	}
	return
}

@(test)
test_creation_spends_points :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g, 7)
	testing.expect_value(t, g.mode, Mode.Create)
	testing.expect_value(t, points_left(g), ATTR_POINTS)
	command(g, .South) // Dexterity
	for _ in 0 ..< 20 {
		command(g, .East)
	}
	testing.expect_value(t, g.attr[.Dexterity], ATTR_BASE + ATTR_POINTS)
	testing.expect_value(t, points_left(g), 0)
	command(g, .North) // Strength: lowering it frees points
	for _ in 0 ..< 20 {
		command(g, .West)
	}
	testing.expect_value(t, g.attr[.Strength], ATTR_MIN)
	testing.expect_value(t, points_left(g), ATTR_BASE - ATTR_MIN)
	testing.expect_value(t, carry_limit(g), CARRY_PER_STRENGTH * ATTR_MIN)
	command(g, .Confirm) // moves down a row
	testing.expect_value(t, g.mode, Mode.Create)
	command(g, .North) // wraps to Begin
	command(g, .North)
	testing.expect_value(t, g.create_row, CREATE_BEGIN_ROW)
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Learn) // the first spell comes next
	testing.expect_value(t, g.health, max_health(g))
}

@(test)
test_floors_get_tenants :: proc(t: ^testing.T) {
	for seed in u64(1) ..= 30 {
		g := new_game_with_tenants(seed)
		for i in 0 ..< FLOOR_COUNT {
			enter_floor(g, i, .Stairs_Down)
			f := floor_of(g)
			n, carnies := count_tenants(g, i)
			testing.expect(t, n >= 4, "a floor has a handful of tenants")
			testing.expect_value(t, carnies, f.number == 3 ? 1 : 0)
			first := f.rooms[0]
			for &tn in g.tenants {
				if tn.kind == .None || int(tn.floor) != i {
					continue
				}
				testing.expect(t, TENANT[tn.kind].first <= f.number)
				inside := int(tn.x) >= first.x && int(tn.x) < first.x + first.w && int(tn.y) >= first.y && int(tn.y) < first.y + first.h
				testing.expect(t, !inside, "none in the arrival room")
			}
		}
		free(g)
	}
}

@(test)
test_bumping_attacks_and_kills :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	id := new_tenant(g, .Beetle, g.current, spot.x + 1, spot.y)
	for _ in 0 ..< 200 {
		if g.tenants[id].kind == .None {
			break
		}
		g.health = max_health(g)
		command(g, .East)
		testing.expect_value(t, [2]int{g.x, g.y}, spot) // fighting, not moving
	}
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.None)
	testing.expect_value(t, g.xp, TENANT[.Beetle].xp)
}

@(test)
test_tenant_chases_and_bites :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	id := new_tenant(g, .Rat, g.current, spot.x + 2, spot.y + 2)
	g.gust_in = 1000
	command(g, .Wait)
	tn := &g.tenants[id]
	testing.expect(t, tn.awake)
	testing.expect_value(t, max(abs(int(tn.x) - g.x), abs(int(tn.y) - g.y)), 1)
	for _ in 0 ..< 100 {
		command(g, .Wait)
		if g.health < max_health(g) || g.mode == .Dead {
			break
		}
		g.items[worn(g, .Light)].fuel = TORCH_TURNS
	}
	testing.expect(t, g.health < max_health(g), "the rat bit")
}

@(test)
test_carny_is_peaceful_until_struck :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	id := new_tenant(g, .Carny, g.current, spot.x + 1, spot.y)
	testing.expect(t, !hostile(&g.tenants[id]))
	testing.expect(t, !hostile_in_view(g))
	g.attr[.Dexterity] = 100 // never miss
	g.items[worn(g, .Weapon)] = {} // bare hands, so it lives
	command(g, .East)
	if g.tenants[id].kind != .None {
		testing.expect(t, hostile(&g.tenants[id]))
	}
}

@(test)
test_weapon_wears_out_and_breaks :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	dagger := worn(g, .Weapon)
	full := KIND[.Dagger].durability
	for _ in 0 ..< full - 1 {
		wear_down(g, dagger)
	}
	testing.expect_value(t, int(g.items[dagger].dur), 1)
	wear_down(g, dagger)
	testing.expect_value(t, worn(g, .Weapon), 0)
	testing.expect_value(t, message(&g.log[LOG_LINES - 1]), "Yer Dagger breaks!")
}

@(test)
test_death_drops_the_pack_and_wakes_below :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	enter_floor(g, 1, .Stairs_Down)
	spot := open_spot(g)
	teleport(g, spot)
	pack := worn(g, .Pack)
	bread := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].kind == .Bread && g.items[i].place == .Inside && int(g.items[i].parent) == pack {
			bread = i
			break
		}
	}
	testing.expect(t, bread != 0)
	hurt(g, 1000, "a test")
	testing.expect_value(t, g.mode, Mode.Dead)
	// Worn things stay on; what was inside them lies here.
	testing.expect_value(t, worn(g, .Pack), pack)
	testing.expect_value(t, worn(g, .Weapon) != 0, true)
	testing.expect_value(t, g.items[bread].place, Place.Ground)
	testing.expect(t, g.items[bread].pile)
	testing.expect_value(t, contents_count(g, pack), 0)
	testing.expect_value(t, carried_jools(g), 0)
	command(g, .Wait) // only Confirm wakes
	testing.expect_value(t, g.mode, Mode.Dead)
	command(g, .Confirm)
	testing.expect_value(t, g.mode, Mode.Play)
	testing.expect_value(t, g.current, 0)
	testing.expect_value(t, cell_at(g, g.x, g.y), Cell.Stairs_Down)
	testing.expect_value(t, g.health, max_health(g))
	// Dying again before fetching it loses the pile.
	hurt(g, 1000, "a test")
	testing.expect_value(t, g.items[bread].kind, Item_Kind.None)
}

@(test)
test_picking_up_saves_it_from_the_pile :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	hurt(g, 1000, "a test")
	command(g, .Confirm)
	teleport(g, spot)
	id := ground_item_at(g, g.x, g.y)
	testing.expect(t, id != 0 && g.items[id].pile)
	command(g, .Confirm) // pick it up
	testing.expect(t, is_carried(g, id))
	testing.expect(t, !g.items[id].pile)
	hurt(g, 1000, "a test")
	testing.expect_value(t, g.items[id].place, Place.Ground) // dropped in the new pile, not lost
	testing.expect(t, g.items[id].pile)
}

@(test)
test_gust_carries_light_tenants :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	f := floor_of(g)
	d := wind_blow(f)
	spot := open_spot(g)
	// Stand off to the side, with a rat and a beetle in the open.
	teleport(g, spot + {d.y * 2, d.x * 2})
	rat := new_tenant(g, .Rat, g.current, spot.x, spot.y)
	beetle := new_tenant(g, .Beetle, g.current, spot.x - d.x, spot.y - d.y)
	blow_tenants(g)
	testing.expect_value(t, [2]int{int(g.tenants[rat].x), int(g.tenants[rat].y)}, spot + d)
	testing.expect_value(t, [2]int{int(g.tenants[beetle].x), int(g.tenants[beetle].y)}, spot - d)
}

@(test)
test_mouse_route_goes_one_step_with_a_tenant_in_view :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	spot := open_spot(g)
	teleport(g, spot)
	new_tenant(g, .Rat, g.current, spot.x - 2, spot.y - 2)
	refresh_view(g)
	sx := MAP_X + (VIEW_W / 2 + 2) * TILE + 2
	sy := MAP_Y + (VIEW_H / 2) * TILE + 2
	pointer(g, sx, sy, .Mouse_Primary)
	testing.expect_value(t, g.path_len, 1)
}
