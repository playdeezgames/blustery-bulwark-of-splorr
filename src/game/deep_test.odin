#+build !js
package game

import "core:testing"

// Tenants from floor 9 (slice 3 step 18): the ogre, the wisp, the mimic and the draught.

// A cell of the current floor where the 4 by 3 block round it (one west, two east) is open floor.
open_block :: proc(g: ^Game) -> [2]int {
	f := floor_of(g)
	for y in 2 ..< FLOOR_H - 2 {
		x_loop: for x in 2 ..< FLOOR_W - 3 {
			for dy in -1 ..= 1 {
				for dx in -1 ..= 2 {
					if f.cells[y + dy][x + dx] != .Floor {
						continue x_loop
					}
				}
			}
			return {x, y}
		}
	}
	return {}
}

@(test)
test_floors_nine_and_up_have_the_newest_tenants :: proc(t: ^testing.T) {
	seen: [Tenant_Kind]int
	for seed in u64(1) ..= 20 {
		g := new_game_with_tenants(seed)
		for i in ([?]int{4, 5, 6, 8, 9, 10}) {
			enter_floor(g, i, .Stairs_Down)
		}
		for &tn in g.tenants {
			if tn.kind == .None {
				continue
			}
			number := g.floors[tn.floor].number
			if TENANT[tn.kind].first == 9 {
				testing.expectf(t, number >= 9, "%v on floor %v", tn.kind, number)
			}
			if number >= 9 {
				seen[tn.kind] += 1
			}
		}
		free(g)
	}
	for k in ([?]Tenant_Kind{.Ogre, .Wisp, .Mimic, .Draught}) {
		testing.expectf(t, seen[k] > 0, "no %v on floors 9 to 11 in 20 seeds", k)
	}
	// The mimic and the draught are rarer; the older tenants still live up here.
	testing.expect(t, seen[.Mimic] < seen[.Ogre])
	testing.expect(t, seen[.Draught] < seen[.Wisp])
	testing.expect(t, seen[.Goblin] > 0)
}

@(test)
test_the_ogre_is_heavy_and_slow :: proc(t: ^testing.T) {
	testing.expect(t, !TENANT[.Ogre].light)
	testing.expect_value(t, TENANT[.Ogre].speed, 5)
	testing.expect_value(t, TENANT[.Ogre].trophy, Item_Kind.Ogre_Tooth)
	testing.expect_value(t, VALUE[.Ogre_Tooth], 12)
	testing.expect_value(t, VALUE[.Wisp_Glass], 8)
	testing.expect_value(t, VALUE[.Mimic_Hinge], 10)
}

@(test)
test_a_wisp_puts_out_yer_light_and_does_no_harm :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	testing.expect(t, g.lit)
	id := new_tenant(g, .Wisp, g.current, g.x + 1, g.y)
	hp := g.health
	for _ in 0 ..< 100 {
		if !g.lit {
			break
		}
		tenant_attack(g, id)
	}
	testing.expect(t, !g.lit)
	testing.expect_value(t, g.health, hp)
	tenant_attack(g, id)
	testing.expect_value(t, g.health, hp)
	testing.expect(t, TENANT[.Wisp].light) // gusts carry it
}

@(test)
test_a_mimic_looks_like_a_pack_until_you_are_next_to_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	at := open_block(g)
	teleport(g, at)
	id := new_tenant(g, .Mimic, g.current, at.x + 2, at.y)
	m := &g.tenants[id]
	testing.expect(t, disguised(m))
	testing.expect(t, !hostile(m))
	testing.expect(t, !hostile_in_view(g))
	inspect_tenant(g, id)
	testing.expect_value(t, message(&g.last_said), "A pack. Somebody left it here.")
	tenant_act(g, id) // two cells away: it keeps still
	testing.expect(t, disguised(m))
	testing.expect_value(t, [2]int{int(m.x), int(m.y)}, [2]int{at.x + 2, at.y})
	teleport(g, {at.x + 1, at.y})
	tenant_act(g, id)
	testing.expect(t, !disguised(m))
	testing.expect(t, hostile(m))
	testing.expect_value(t, message(&g.last_said), "The pack was a mimic. It opens wide.")
}

@(test)
test_striking_a_disguised_mimic_wakes_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	id := new_tenant(g, .Mimic, g.current, g.x + 1, g.y)
	player_attack(g, id)
	testing.expect(t, !disguised(&g.tenants[id]))
	testing.expect(t, !g.tenants[id].angry) // it was never peaceful, only shut
}

@(test)
test_a_draught_shoves_you_and_slams_you_into_walls :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	g.no_tenants = false
	at := open_block(g)
	teleport(g, at)
	id := new_tenant(g, .Draught, g.current, at.x - 1, at.y)
	testing.expect(t, !hostile(&g.tenants[id]))
	hp := g.health
	tenant_act(g, id)
	testing.expect_value(t, [2]int{g.x, g.y}, [2]int{at.x + 1, at.y}) // pushed east, away from it
	testing.expect_value(t, message(&g.last_said), "A draught shoves you E.")
	testing.expect_value(t, g.health, hp)
	// Against a wall it slams you.
	f := floor_of(g)
	wall: [2]int
	find: for y in 1 ..< FLOOR_H - 1 {
		for x in 2 ..< FLOOR_W - 1 {
			if f.cells[y][x] == .Floor && f.cells[y][x - 1] == .Floor && f.cells[y][x + 1] == .Wall {
				wall = {x, y}
				break find
			}
		}
	}
	teleport(g, wall)
	g.tenants[id].x, g.tenants[id].y = i16(wall.x - 1), i16(wall.y)
	tenant_act(g, id)
	testing.expect_value(t, [2]int{g.x, g.y}, wall)
	testing.expect_value(t, g.health, hp - 1)
	testing.expect_value(t, message(&g.last_said), "A draught slams you into the wall.")
}

@(test)
test_blows_pass_through_a_draught_and_a_spell_seals_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	id := new_tenant(g, .Draught, g.current, g.x + 1, g.y)
	for _ in 0 ..< 10 {
		g.gust_in = 99 // no wind warning in the log
		player_attack(g, id)
	}
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.Draught)
	testing.expect_value(t, message(&g.last_said), "Yer blow goes straight through it.")
	xp := g.xp
	spell_hit(g, id, 1, "bolt")
	testing.expect_value(t, g.tenants[id].kind, Tenant_Kind.None)
	testing.expect_value(t, g.xp, xp + TENANT[.Draught].xp)
	testing.expect_value(t, message(&g.last_said), "The draught is sealed.")
}
