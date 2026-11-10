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

// Magic screens for checking by eye (-define:DUMP_MAGIC=<prefix>): <prefix>-learn.ppm,
// <prefix>-cast.ppm, <prefix>-bolt.ppm (a bolt bent by the wind) and <prefix>-ball.ppm.
DUMP_MAGIC :: #config(DUMP_MAGIC, "")

@(test)
test_dump_magic :: proc(t: ^testing.T) {
	when DUMP_MAGIC != "" {
		g := open_room()
		defer free(g)
		fr := new(Frame)
		defer free(fr)
		shot :: proc(g: ^Game, fr: ^Frame, name: string) {
			draw_game(fr, g)
			resolve(fr)
			write_ppm(name, fr)
		}
		g.known = {}
		g.learns = 1
		g.level = 3
		open_learn_if_owed(g)
		g.menu_row = 6
		shot(g, fr, DUMP_MAGIC + "-learn.ppm")
		g.known = ~bit_set[Spell]{}
		g.mode = .Play
		g.mana = 5
		g.ward_turns, g.sense_turns, g.anchor_spell = 12, 7, true
		open_cast(g)
		g.menu_row = 1 // Gust Ball, short by 1
		shot(g, fr, DUMP_MAGIC + "-cast.ppm")
		g.mode = .Play
		g.mana = 50
		new_tenant(g, .Kobold, g.current, 22, 13)
		cast_spell(g, .Magic_Bolt, {0, -1})
		shot(g, fr, DUMP_MAGIC + "-bolt.ppm")
		new_tenant(g, .Rat, g.current, 25, 21)
		cast_spell(g, .Gust_Ball, {1, 0})
		g.mode = .Aim
		shot(g, fr, DUMP_MAGIC + "-ball.ppm")
	}
}

// Step 6 by eye (-define:DUMP_SUPPLIES=<prefix>): <prefix>-inv.ppm (unknown things, the Use row, a
// cursed ring worn), <prefix>-map.ppm (potions and jewellery on the ground) and <prefix>-ident.ppm.
DUMP_SUPPLIES :: #config(DUMP_SUPPLIES, "")

@(test)
test_dump_supplies :: proc(t: ^testing.T) {
	when DUMP_SUPPLIES != "" {
		g := open_room()
		defer free(g)
		fr := new(Frame)
		defer free(fr)
		shot :: proc(g: ^Game, fr: ^Frame, name: string) {
			draw_game(fr, g)
			resolve(fr)
			write_ppm(name, fr)
		}
		for k in ([?]Item_Kind{.Potion_Healing, .Potion_Blight, .Scroll_Decree, .Cheese, .Jerky, .Spellbook}) {
			give(g, k)
		}
		g.ident += {.Potion_Healing}
		wear(g, give(g, .Ring_Draught), .Ring_Left)
		wear(g, give(g, .Amulet_Vigour), .Amulet)
		g.hunger = 905
		open_inventory(g)
		g.inv.pane, g.inv.cursor[0] = 0, USE_ROW
		g.inv.held = worn(g, .Pack) + 4
		shot(g, fr, DUMP_SUPPLIES + "-inv.ppm")
		g.inv.held = 0
		start_identify(g)
		shot(g, fr, DUMP_SUPPLIES + "-ident.ppm")
		close_inventory(g)
		ks := [?]Item_Kind{.Potion_Healing, .Potion_Mana, .Potion_Blight, .Potion_Sight, .Scroll_Return, .Ring_Guard, .Amulet_Hop, .Cheese, .Jerky, .Spellbook}
		for k, i in ks {
			id := new_item(g, k)
			g.items[id].place, g.items[id].floor = .Ground, i8(g.current)
			g.items[id].x, g.items[id].y = i16(17 + i % 5 * 2), i16(17 + i / 5 * 2)
		}
		refresh_view(g)
		shot(g, fr, DUMP_SUPPLIES + "-map.ppm")
	}
}

// The town by eye (-define:DUMP_TOWN=<prefix>): <prefix>-street.ppm (from the gate),
// <prefix>-low.ppm (the lower street), <prefix>-smith.ppm and <prefix>-bank.ppm.
DUMP_TOWN :: #config(DUMP_TOWN, "")

@(test)
test_dump_town :: proc(t: ^testing.T) {
	when DUMP_TOWN != "" {
		g := town_game()
		defer free(g)
		fr := new(Frame)
		defer free(fr)
		shot :: proc(g: ^Game, fr: ^Frame, name: string) {
			draw_game(fr, g)
			resolve(fr)
			write_ppm(name, fr)
		}
		shot(g, fr, DUMP_TOWN + "-street.ppm")
		teleport(g, door_of(.Bank) + {6, 1})
		shot(g, fr, DUMP_TOWN + "-low.ppm")
		dagger := worn(g, .Weapon)
		for _ in 0 ..< 7 {
			wear_down(g, dagger)
		}
		give(g, .Club)
		go_in(g, .Smith)
		shot(g, fr, DUMP_TOWN + "-smith.ppm")
		command(g, .Cancel)
		g.bank = 120
		go_in(g, .Bank)
		shot(g, fr, DUMP_TOWN + "-bank.ppm")
	}
}

// Floor 4 by eye (-define:DUMP_BOSS=<prefix>): <prefix>-door.ppm (arriving, the carny at the
// door), <prefix>-hall.ppm (the Horde, one toppled) and <prefix>-notice.ppm.
DUMP_BOSS :: #config(DUMP_BOSS, "")

@(test)
test_dump_boss :: proc(t: ^testing.T) {
	when DUMP_BOSS != "" {
		g := boss_game()
		defer free(g)
		fr := new(Frame)
		defer free(fr)
		shot :: proc(g: ^Game, fr: ^Frame, name: string) {
			draw_game(fr, g)
			resolve(fr)
			write_ppm(name, fr)
		}
		command(g, .North)
		shot(g, fr, DUMP_BOSS + "-door.ppm")
		c := g.tenants[g.ticket]
		teleport(g, {int(c.x), int(c.y) + 1})
		command(g, .North)
		choose(g, .Admit)
		command(g, .North)
		command(g, .North)
		topple(g, find_kind(g, .Bones), true)
		shot(g, fr, DUMP_BOSS + "-hall.ppm")
		g.mode = .Notice
		shot(g, fr, DUMP_BOSS + "-notice.ppm")
	}
}
