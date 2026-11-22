#+build !js
package game

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

// Slice 4 step 32: the rules name sounds for the page to play, and S turns them off and on.

has_sound :: proc(g: ^Game, s: Sound) -> bool {
	for q in queued_sounds(g) {
		if q == s {
			return true
		}
	}
	return false
}

@(test)
test_s_turns_sound_off_and_on_without_a_turn :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	testing.expect(t, !g.sound_off) // on to start, and for a save from before this step
	turn := g.turn
	command(g, .Sound)
	testing.expect(t, g.sound_off)
	testing.expect_value(t, message(&g.last_said), "Sound off. S to turn it on.")
	testing.expect_value(t, sound_hint(g), "S sound: off")
	play_sound(g, .Gust)
	testing.expect_value(t, len(queued_sounds(g)), 0)
	command(g, .Sound)
	testing.expect(t, !g.sound_off)
	testing.expect_value(t, message(&g.last_said), "Sound on.")
	testing.expect_value(t, g.turn, turn)
	// It works from other screens too, and leaves them open.
	open_inventory(g)
	command(g, .Sound)
	testing.expect(t, g.sound_off && g.mode == .Inventory)
}

@(test)
test_a_click_on_the_sound_hint_toggles_it :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	pointer(g, PANEL_X + 10, SOUND_HINT_Y + 3, .Mouse_Primary)
	testing.expect(t, g.sound_off)
	c, ok := panel_hint_at(PANEL_X + 4, PANEL_HINT_Y + 3)
	testing.expect(t, ok && c == .Map) // the row below is still the map
}

@(test)
test_the_queue_keeps_one_of_each_and_a_slam_hides_the_hurt :: proc(t: ^testing.T) {
	g := new_game()
	defer free(g)
	play_sound(g, .Slam)
	play_sound(g, .Slam)
	play_sound(g, .Hurt)
	testing.expect_value(t, len(queued_sounds(g)), 1)
	for s in Sound {
		play_sound(g, s)
	}
	testing.expect_value(t, len(queued_sounds(g)), SOUND_QUEUE)
	clear_sounds(g)
	testing.expect_value(t, len(queued_sounds(g)), 0)
}

@(test)
test_the_wind_makes_its_sounds :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = false
	g.gust_in = GUST_WARNING + 1
	end_turn(g)
	testing.expect(t, has_sound(g, .Warning))
	clear_sounds(g)
	gust(g)
	testing.expect(t, has_sound(g, .Gust) && !has_sound(g, .Slam))
	clear_sounds(g)
	teleport(g, {FLOOR_W - 2, 20}) // against the east wall, the wind blowing east
	gust(g)
	testing.expect(t, has_sound(g, .Slam) && !has_sound(g, .Hurt))
}

@(test)
test_blows_pickups_spells_and_levels_make_sounds :: proc(t: ^testing.T) {
	g := open_room()
	defer free(g)
	g.lit = false
	id := new_item(g, .Bread)
	g.items[id].place, g.items[id].floor, g.items[id].x, g.items[id].y = .Ground, i8(g.current), 20, 20
	get_here(g)
	testing.expect(t, has_sound(g, .Pick_Up))
	clear_sounds(g)
	g.xp = xp_for_level(g.level + 1)
	check_level(g)
	testing.expect(t, has_sound(g, .Level))
	clear_sounds(g)
	cast_spell(g, .Ward, {0, 0})
	testing.expect(t, has_sound(g, .Spell))
	clear_sounds(g)
	g.no_tenants = false
	rat := new_tenant(g, .Rat, g.current, 21, 20)
	hit, missed := false, false
	for _ in 0 ..< 40 {
		if g.tenants[rat].kind != .Rat || int(g.tenants[rat].floor) != g.current {
			rat = new_tenant(g, .Rat, g.current, 21, 20)
		}
		g.health = max_health(g)
		teleport(g, {20, 20})
		player_attack(g, rat)
		hit ||= has_sound(g, .Hit)
		missed ||= has_sound(g, .Miss)
		clear_sounds(g)
	}
	testing.expect(t, hit && missed)
	hurt(g, 1, "a test")
	testing.expect(t, has_sound(g, .Hurt))
}

@(test)
test_keys_and_the_herald_make_sounds :: proc(t: ^testing.T) {
	g := town_game()
	defer free(g)
	enter_floor(g, 0, .Stairs_Down)
	clear_sounds(g)
	use_here(g) // back down to town: the herald proclaims floor 1
	testing.expect(t, has_sound(g, .Fanfare))
	clear_sounds(g)
	enter_floor(g, GIANT_INDEX, .Stairs_Down)
	key := new_item(g, .Key_Thirteen)
	put_in(g, key, worn(g, .Pack))
	clear_sounds(g)
	door_to_floor_thirteen(g)
	testing.expect(t, has_sound(g, .Key))
}

// The page plays web/sounds/<name>.wav for each Sound after None, in order; the files must be there.
@(test)
test_every_sound_has_its_file :: proc(t: ^testing.T) {
	for s in Sound {
		if s == .None {
			continue
		}
		name := strings.to_lower(fmt.tprint(s), context.temp_allocator)
		path := fmt.tprintf("web/sounds/%v.wav", name)
		testing.expectf(t, os.exists(path), "missing %v", path)
	}
	page, err := os.read_entire_file("web/index.html", context.temp_allocator)
	testing.expect(t, err == nil)
	testing.expect(t, strings.contains(string(page), `const SOUND_FILES = ["warning", "gust", "slam", "hit", "miss", "hurt", "pick_up", "spell", "level", "key", "fanfare"];`))
	testing.expect_value(t, len(Sound), 12)
}
