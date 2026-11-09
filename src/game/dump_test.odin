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
		refresh_view(g)
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

// A fight with one of every tenant about (-define:DUMP_FIGHT=<path.ppm>), and the same moment
// fallen (-define:DUMP_DEAD=<path.ppm>), for checking the pictures by eye.
DUMP_FIGHT :: #config(DUMP_FIGHT, "")
DUMP_DEAD :: #config(DUMP_DEAD, "")

@(test)
test_dump_fight :: proc(t: ^testing.T) {
	when DUMP_FIGHT != "" || DUMP_DEAD != "" {
		g := new_game(u64(DUMP_SEED))
		defer free(g)
		spot := open_spot(g)
		teleport(g, spot)
		kinds := [?]Tenant_Kind{.Rat, .Bat, .Beetle, .Spider, .Kobold, .Slime, .Carny}
		offsets := [?][2]int{{1, 0}, {-2, -1}, {2, 2}, {-1, 2}, {0, -2}, {-2, 1}, {2, -2}}
		for k, i in kinds {
			new_tenant(g, k, g.current, spot.x + offsets[i].x, spot.y + offsets[i].y)
		}
		for p in ([?]struct{k: Item_Kind, at: [2]int}{{.Rat_Tail, {-1, -1}}, {.Kobold_Ear, {1, 1}}, {.Bat_Wing, {0, 2}}}) {
			id := new_item(g, p.k)
			g.items[id].place, g.items[id].floor = .Ground, i8(g.current)
			g.items[id].x, g.items[id].y = i16(spot.x + p.at.x), i16(spot.y + p.at.y)
		}
		g.gust_in = 100
		command(g, .East)
		command(g, .East)
		fr := new(Frame)
		defer free(fr)
		when DUMP_FIGHT != "" {
			draw_game(fr, g)
			resolve(fr)
			write_ppm(DUMP_FIGHT, fr)
		}
		when DUMP_DEAD != "" {
			hurt(g, 1000, "a kobold")
			draw_game(fr, g)
			resolve(fr)
			write_ppm(DUMP_DEAD, fr)
		}
	}
}
