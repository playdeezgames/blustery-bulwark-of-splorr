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
