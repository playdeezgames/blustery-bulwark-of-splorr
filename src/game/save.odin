package game

// Saves (slice 1 step 9; PLAN.md "Saves in localStorage: seed plus changes"). A save is the whole
// Game with every floor's cells left out (they grow back from the character's seed, and the town and
// floor 4 are built by hand), packed by running zeros together. A header carries a version and the
// size of Game, so a save from a build whose rules differ is ignored, never half-read. Loading
// touches nothing unless the whole save checks out.

import "base:runtime"

SAVE_MAGIC :: u32(0x4C42_5342) // "BSBL"
SAVE_VERSION :: u32(2) // bump whenever Game changes shape or meaning
SAVE_HEADER :: 12
SAVE_CAP :: 2 * size_of(Game) + SAVE_HEADER // a packed save is never longer than this

// The byte ranges of every floor's cells inside a Game (left out of saves).
@(private = "file")
cell_ranges :: proc(g: ^Game) -> (ranges: [FLOOR_COUNT + 1][2]int) {
	base := uintptr(g)
	for i in 0 ..< FLOOR_COUNT {
		start := int(uintptr(&g.floors[i].cells) - base)
		ranges[i] = {start, start + size_of(g.floors[i].cells)}
	}
	start := int(uintptr(&g.town.cells) - base)
	ranges[FLOOR_COUNT] = {start, start + size_of(g.town.cells)}
	return
}

@(private = "file")
put_u32 :: proc(out: []u8, at: int, v: u32) {
	out[at], out[at + 1], out[at + 2], out[at + 3] = u8(v), u8(v >> 8), u8(v >> 16), u8(v >> 24)
}

@(private = "file")
get_u32 :: proc(data: []u8, at: int) -> u32 {
	return u32(data[at]) | u32(data[at + 1]) << 8 | u32(data[at + 2]) << 16 | u32(data[at + 3]) << 24
}

// Packs the game into `out` (at least SAVE_CAP bytes). Returns the length, or 0 if `out` is short.
save_game :: proc(g: ^Game, out: []u8) -> int {
	if len(out) < SAVE_CAP {
		return 0
	}
	put_u32(out, 0, SAVE_MAGIC)
	put_u32(out, 4, SAVE_VERSION)
	put_u32(out, 8, u32(size_of(Game)))
	raw := ([^]u8)(g)[:size_of(Game)]
	skip := cell_ranges(g)
	n := SAVE_HEADER
	zeros := 0
	flush :: proc(out: []u8, n: ^int, zeros: ^int) {
		for zeros^ > 0 {
			run := min(zeros^, 0xFFFF)
			out[n^], out[n^ + 1], out[n^ + 2] = 0, u8(run), u8(run >> 8)
			n^ += 3
			zeros^ -= run
		}
	}
	for i := 0; i < len(raw); i += 1 {
		b := raw[i]
		for s in skip {
			if i >= s[0] && i < s[1] {
				b = 0
				break
			}
		}
		if b == 0 {
			zeros += 1
			continue
		}
		flush(out, &n, &zeros)
		out[n] = b
		n += 1
	}
	flush(out, &n, &zeros)
	return n
}

// Unpacks a save into `g`. False, with `g` untouched, when the save is not one this build wrote.
load_game :: proc(g: ^Game, data: []u8) -> bool {
	if len(data) < SAVE_HEADER || get_u32(data, 0) != SAVE_MAGIC || get_u32(data, 4) != SAVE_VERSION || get_u32(data, 8) != u32(size_of(Game)) {
		return false
	}
	// First count what it unpacks to; only a save of exactly the right size is used.
	total := 0
	for i := SAVE_HEADER; i < len(data); {
		if data[i] == 0 {
			if i + 2 >= len(data) {
				return false
			}
			total += int(data[i + 1]) | int(data[i + 2]) << 8
			i += 3
		} else {
			total += 1
			i += 1
		}
	}
	if total != size_of(Game) {
		return false
	}
	raw := ([^]u8)(g)[:size_of(Game)]
	n := 0
	for i := SAVE_HEADER; i < len(data); {
		if data[i] == 0 {
			run := int(data[i + 1]) | int(data[i + 2]) << 8
			runtime.memset(&raw[n], 0, run)
			n += run
			i += 3
		} else {
			raw[n] = data[i]
			n += 1
			i += 1
		}
	}
	restore_cells(g)
	return true
}

// Grows every made floor's cells back: generated floors from the seed, the town and floor 4 by hand.
restore_cells :: proc(g: ^Game) {
	tmp := new(Floor)
	defer free(tmp)
	for i in 0 ..< FLOOR_COUNT {
		f := &g.floors[i]
		if !f.made {
			continue
		}
		if i == BOSS_INDEX {
			boss_cells(f)
		} else {
			generate_floor(tmp, floor_seed(g.seed, i + 1), i + 1)
			f.cells = tmp.cells
		}
	}
	if g.town.made {
		town_cells(&g.town)
	}
}
