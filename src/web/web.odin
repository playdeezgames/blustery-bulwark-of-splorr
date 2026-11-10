#+build js
package main

// Thin browser layer. odin.js drives `step` from its own requestAnimationFrame loop; the page copies
// the frame when platform_frame_ready says it changed, and forwards input as small integers.

import "base:runtime"
import "tggd:game"

state: struct {
	rules:  game.Game,
	screen: game.Frame,
	dirty:  bool,
	ready:  bool,
	save:   [game.SAVE_CAP]u8, // the packed save, for the page to put in localStorage
	load:   [game.SAVE_CAP]u8, // where the page writes a save it read back
}

main :: proc() {
	game.init_game(&state.rules, 1)
	state.dirty = true
}

// A new character from a seed the page makes (two 32-bit halves; wasm ints are 32 bits).
@(export)
platform_start :: proc "c" (seed_hi, seed_lo: i32) {
	context = runtime.default_context()
	game.init_game(&state.rules, u64(u32(seed_hi)) << 32 | u64(u32(seed_lo)))
	state.dirty = true
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = c
	if game.tick(&state.rules) {
		state.dirty = true
	}
	if state.dirty {
		state.dirty = false
		game.draw_game(&state.screen, &state.rules)
		game.resolve(&state.screen)
		state.ready = true
	}
	return true
}

// A game.Command from a key, a gamepad button or the touch d-pad.
@(export)
platform_command :: proc "c" (command: i32) {
	context = runtime.default_context()
	if command < 0 || command > i32(max(game.Command)) {
		return
	}
	game.command(&state.rules, game.Command(command))
	state.dirty = true
}

// A click or tap at framebuffer pixel (x, y); kind is a game.Pointer (0 mouse, 1 right mouse, 2 touch).
@(export)
platform_pointer :: proc "c" (x, y, kind: i32) {
	context = runtime.default_context()
	if kind < 0 || kind > i32(max(game.Pointer)) {
		return
	}
	game.pointer(&state.rules, int(x), int(y), game.Pointer(kind))
	state.dirty = true
}

// A mouse button let go at framebuffer pixel (x, y) (dragging in the inventory).
@(export)
platform_pointer_up :: proc "c" (x, y: i32) {
	context = runtime.default_context()
	game.inventory_release(&state.rules, int(x), int(y))
	state.dirty = true
}

// Packs the game into the save buffer; returns its length for the page to store.
@(export)
platform_save :: proc "c" () -> i32 {
	context = runtime.default_context()
	return i32(game.save_game(&state.rules, state.save[:]))
}

@(export)
platform_save_ptr :: proc "c" () -> rawptr {
	return &state.save
}

@(export)
platform_save_cap :: proc "c" () -> i32 {
	return game.SAVE_CAP
}

@(export)
platform_load_ptr :: proc "c" () -> rawptr {
	return &state.load
}

// Restores the save the page wrote into the load buffer (`n` bytes). 1 when it was one this build
// can read; 0 leaves the game as it was.
@(export)
platform_load :: proc "c" (n: i32) -> i32 {
	context = runtime.default_context()
	if n <= 0 || int(n) > len(state.load) {
		return 0
	}
	if !game.load_game(&state.rules, state.load[:n]) {
		return 0
	}
	state.dirty = true
	return 1
}

// 1 when the frame holds pixels the page has not copied yet (and marks them taken).
@(export)
platform_frame_ready :: proc "c" () -> i32 {
	if !state.ready {
		return 0
	}
	state.ready = false
	return 1
}

@(export)
platform_frame_ptr :: proc "c" () -> rawptr {
	return &state.screen.rgba
}

@(export)
platform_screen_w :: proc "c" () -> i32 {
	return game.SCREEN_W
}

@(export)
platform_screen_h :: proc "c" () -> i32 {
	return game.SCREEN_H
}
