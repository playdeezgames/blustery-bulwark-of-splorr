#+build !js
package game

// Writes real frames for screenshots when run with -define:DUMP_PLAY=<path.ppm> (tools/make_shots.sh).
// Without the define it does nothing.

import "core:os"
import "core:testing"

DUMP_PLAY :: #config(DUMP_PLAY, "")
DUMP_SEED :: #config(DUMP_SEED, 7)

@(test)
test_dump_play :: proc(t: ^testing.T) {
	when DUMP_PLAY != "" {
		g := new_game(u64(DUMP_SEED))
		defer free(g)
		// Walk toward the stairs up for a while, so the picture shows a room and a corridor.
		// (Routes only cross seen cells, so pretend the floor is seen while planning, then forget it.)
		f := floor_of(g)
		for y in 0 ..< FLOOR_H {
			for x in 0 ..< FLOOR_W {
				f.seen[y][x] = f.cells[y][x] != .Wall
			}
		}
		n := find_path(f, {g.x, g.y}, f.up, &g.path)
		f.seen = {}
		compute_fov(f, g.x, g.y, &g.vis)
		for i in 0 ..< min(n, 3) {
			step_player(g, g.path[i] - [2]int{g.x, g.y})
		}
		say(g, "The wind howls round the bulwark.")
		fr := new(Frame)
		defer free(fr)
		draw_game(fr, g)
		resolve(fr)
		write_ppm(DUMP_PLAY, fr)
	}
}

write_ppm :: proc(path: string, f: ^Frame) {
	header := "P6\n384 216\n255\n"
	data := make([]u8, len(header) + SCREEN_W * SCREEN_H * 3)
	defer delete(data)
	copy(data, header)
	for c, i in f.rgba {
		data[len(header) + i * 3 + 0] = u8(c)
		data[len(header) + i * 3 + 1] = u8(c >> 8)
		data[len(header) + i * 3 + 2] = u8(c >> 16)
	}
	_ = os.write_entire_file(path, data)
}
