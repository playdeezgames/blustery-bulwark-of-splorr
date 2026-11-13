#+build !js
package game

import "base:runtime"
import "core:testing"

same_game :: proc(a, b: ^Game) -> bool {
	return runtime.memory_compare(a, b, size_of(Game)) == 0
}

@(test)
test_a_save_round_trips :: proc(t: ^testing.T) {
	g := new_game_with_tenants(77)
	defer free(g)
	// Play a little everywhere: two floors, the town, floor 4.
	for _ in 0 ..< 30 {
		command(g, .East)
		command(g, .South)
	}
	enter_floor(g, 1, .Stairs_Down)
	command(g, .Wait)
	enter_floor(g, BOSS_INDEX, .Stairs_Down)
	enter_town(g, .Gate)
	hurt(g, 1000, "a test")
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	n := save_game(g, buf)
	testing.expect(t, n > 0)
	testing.expect(t, n < size_of(Game) / 2, "cells are left out and zeros packed")
	h := new(Game)
	defer free(h)
	testing.expect(t, load_game(h, buf[:n]))
	testing.expect(t, same_game(g, h))
	// And the two go on alike.
	for c in ([?]Command{.Confirm, .North, .North, .West, .Wait, .Inventory, .Cancel}) {
		command(g, c)
		command(h, c)
	}
	testing.expect(t, same_game(g, h))
}

@(test)
test_a_bad_save_is_ignored :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	n := save_game(g, buf)
	h := new_game(5)
	defer free(h)
	before := h^
	// Another version, a cut-off save and a wrong size are all refused, leaving the game alone.
	buf[4] += 1
	testing.expect(t, !load_game(h, buf[:n]))
	buf[4] -= 1
	testing.expect(t, !load_game(h, buf[:n - 10]))
	testing.expect(t, !load_game(h, buf[:5]))
	testing.expect(t, runtime.memory_compare(&before, h, size_of(Game)) == 0)
	testing.expect(t, load_game(h, buf[:n]))
}

// A save written before fields were added at the end of Game loads, with those fields zero.
@(test)
test_a_save_from_before_new_end_fields_loads :: proc(t: ^testing.T) {
	g := new_game_with_tenants(78)
	defer free(g)
	command(g, .East)
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	n := save_game(g, buf)
	// Make it the save an older build wrote: Game stopped before `drained` (zero here, so the
	// packed save ends in a run of zeros that covers it; shorten that run and the stated size).
	tail := size_of(Game) - int(offset_of(Game, drained))
	testing.expect_value(t, buf[n - 3], 0)
	run := int(buf[n - 2]) | int(buf[n - 1]) << 8
	testing.expect(t, run >= tail)
	run -= tail
	buf[n - 2], buf[n - 1] = u8(run), u8(run >> 8)
	size := u32(int(offset_of(Game, drained)))
	buf[8], buf[9], buf[10], buf[11] = u8(size), u8(size >> 8), u8(size >> 16), u8(size >> 24)
	h := new(Game)
	defer free(h)
	h.drained[.Strength] = 5 // junk that loading must clear
	testing.expect(t, load_game(h, buf[:n]))
	testing.expect(t, same_game(g, h))
	// A save that claims to be longer than Game is refused.
	size = u32(size_of(Game) + 2)
	buf[8], buf[9], buf[10], buf[11] = u8(size), u8(size >> 8), u8(size >> 16), u8(size >> 24)
	testing.expect(t, !load_game(h, buf[:n]))
}
