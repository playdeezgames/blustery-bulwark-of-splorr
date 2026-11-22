#+build !js
package game

import "core:strings"
import "core:testing"

// Slice 4 step 31: the Steady and Lamp rings, for the second ring slot.

// Puts a ring of kind `k` on hand `s`.
put_ring_on :: proc(g: ^Game, k: Item_Kind, s: Slot) -> int {
	id := new_item(g, k)
	put_in(g, id, worn(g, .Pack))
	wear(g, id, s)
	return id
}

@(test)
test_a_steady_ring_takes_a_cell_off_every_push :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = false
	f := floor_of(g)
	push :: proc(g: ^Game, f: ^Floor, number: int) -> int {
		f.number = number
		teleport(g, {20, 20})
		gust(g)
		return g.x - 20
	}
	put_ring_on(g, .Ring_Steady, .Ring_Left)
	testing.expect_value(t, push(g, f, 13), 2) // 3 less one
	testing.expect_value(t, push(g, f, 5), 1) // 2 less one
	testing.expect_value(t, push(g, f, 1), 1) // never none
	// Two Steady rings, or one with the wind cloak, take two cells off; still never none.
	put_ring_on(g, .Ring_Steady, .Ring_Right)
	testing.expect_value(t, push(g, f, 13), 1)
	free_item(g, worn(g, .Ring_Right))
	wear_wind_cloak(g)
	testing.expect_value(t, push(g, f, 13), 1)
	testing.expect_value(t, push(g, f, 5), 1)
}

@(test)
test_a_lamp_ring_halves_the_snuffing :: proc(t: ^testing.T) {
	count :: proc(rings: int, lantern: bool) -> int {
		g := open_room()
		defer free(g)
		floor_of(g).number = 13 // 80 % with a torch
		if lantern {
			free_item(g, worn(g, .Light))
			wear(g, new_item(g, .Lantern), .Light)
		}
		hands := [2]Slot{.Ring_Left, .Ring_Right}
		for i in 0 ..< rings {
			put_ring_on(g, .Ring_Lamp, hands[i])
		}
		snuffed := 0
		for _ in 0 ..< 1000 {
			g.lit = true
			g.items[worn(g, .Light)].fuel = 500
			teleport(g, {20, 20})
			gust(g)
			if !g.lit {
				snuffed += 1
			}
		}
		return snuffed
	}
	torch, one, two, lantern := count(0, false), count(1, false), count(2, false), count(1, true)
	testing.expectf(t, torch > 720 && torch < 880, "torch %v", torch) // 80 %
	testing.expectf(t, one > 330 && one < 470, "one ring %v", one) // 40 %
	testing.expectf(t, two > 140 && two < 260, "two rings %v", two) // 20 %
	testing.expectf(t, lantern > 80 && lantern < 190, "lantern and ring %v", lantern) // 26 / 2 = 13 %
}

@(test)
test_a_ring_picked_up_goes_on_the_free_hand :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	// Fill everything that could hold a ring so stow has to wear it.
	for s in ([?]Slot{.Purse, .Belt, .Pack}) {
		if c := worn(g, s); c != 0 {
			for i in 1 ..< MAX_ITEMS {
				if g.items[i].place == .Inside && int(g.items[i].parent) == c {
					free_item(g, i)
				}
			}
			free_item(g, c)
		}
	}
	left := new_item(g, .Ring_Guard)
	testing.expect(t, stow(g, left))
	testing.expect_value(t, worn(g, .Ring_Left), left)
	right := new_item(g, .Ring_Steady)
	testing.expect(t, stow(g, right))
	testing.expect_value(t, worn(g, .Ring_Right), right)
	third := new_item(g, .Ring_Lamp)
	testing.expect(t, !stow(g, third))
}

@(test)
test_four_ring_looks_each_their_own :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 40 {
		g := new_game(seed)
		seen: [4]bool
		for k in ([?]Item_Kind{.Ring_Guard, .Ring_Draught, .Ring_Steady, .Ring_Lamp}) {
			i := int(g.look[int(k)])
			testing.expectf(t, i < 4 && !seen[i], "seed %v: %v has look %v twice", seed, k, i)
			seen[i] = true
		}
		free(g)
	}
	g := new_game()
	defer free(g)
	testing.expect(t, strings.has_suffix(look_name(g, .Ring_Steady), " ring"))
}

@(test)
test_an_older_save_gives_the_new_rings_the_spare_looks :: proc(t: ^testing.T) {
	g := new_game(7)
	defer free(g)
	// As a save from before step 31 would load: only the first two rings shuffled.
	g.look[int(Item_Kind.Ring_Guard)], g.look[int(Item_Kind.Ring_Draught)] = 1, 0
	g.look[int(Item_Kind.Ring_Steady)], g.look[int(Item_Kind.Ring_Lamp)] = 0, 0
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	n := save_game(g, buf)
	h := new(Game)
	defer free(h)
	testing.expect(t, load_game(h, buf[:n]))
	testing.expect_value(t, h.look[int(Item_Kind.Ring_Guard)], 1)
	testing.expect_value(t, h.look[int(Item_Kind.Ring_Draught)], 0)
	testing.expect_value(t, h.look[int(Item_Kind.Ring_Steady)], 2)
	testing.expect_value(t, h.look[int(Item_Kind.Ring_Lamp)], 3)
}

@(test)
test_the_new_rings_lie_about_from_floor_nine :: proc(t: ^testing.T) {
	found_high := 0
	for seed in u64(1) ..< 6 {
		g := new_game(seed)
		g.no_tenants = true
		for i in 1 ..< FLOOR_COUNT {
			enter_floor(g, i, .Stairs_Down)
		}
		for i in 1 ..< MAX_ITEMS {
			it := &g.items[i]
			if it.place == .Ground && (it.kind == .Ring_Steady || it.kind == .Ring_Lamp) {
				number := g.floors[int(it.floor)].number
				testing.expectf(t, number >= RING_FLOOR, "seed %v: a %v on floor %v", seed, it.kind, number)
				found_high += 1
			}
		}
		free(g)
	}
	testing.expect(t, found_high >= 20)
}

@(test)
test_the_general_store_sells_the_rings_after_the_giant :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	receive_jools(g, 400)
	go_in(g, .General)
	testing.expect(t, !choose(g, .Buy, int(Item_Kind.Ring_Steady)))
	leave_shop(g)
	g.giant_dead = true
	go_in(g, .General)
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Ring_Steady)))
	testing.expectf(t, strings.has_prefix(message(&g.last_said), "You buy a Steady ring."), "said %v", message(&g.last_said))
	testing.expect(t, choose(g, .Buy, int(Item_Kind.Ring_Lamp)))
	testing.expect(t, has_kind(g, .Ring_Steady) && has_kind(g, .Ring_Lamp))
	testing.expect(t, .Ring_Steady in g.ident && .Ring_Lamp in g.ident)
	testing.expect_value(t, VALUE[.Ring_Steady], 120)
	testing.expect_value(t, VALUE[.Ring_Lamp], 90)
}
