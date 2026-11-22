package game

// Sound (slice 4 step 32; PLAN.md item 10). The rules only name a sound; the page plays it. Each
// is a small jsfxr effect made by tools/make_sounds.js (seeded, so the set can be made again) into
// web/sounds/, in the order of this enum. S (or a click on the panel's hint) turns sound off and
// on; the choice is kept with the save. Sounds queue here until the page drains them each frame.

Sound :: enum u8 {
	None,
	Warning, // the wind picks up
	Gust,
	Slam, // into a wall
	Hit, // a blow you land
	Miss,
	Hurt,
	Pick_Up,
	Spell,
	Level,
	Key, // a key turning in a door
	Fanfare, // the herald
}

SOUND_QUEUE :: 8

// Queues a sound for the page, unless sound is off, it is already queued, or the queue is full. Being
// hurt by a slam plays only the slam.
play_sound :: proc(g: ^Game, s: Sound) {
	if g.sound_off || int(g.sound_n) >= SOUND_QUEUE {
		return
	}
	for q in g.sounds[:g.sound_n] {
		if q == s || (s == .Hurt && q == .Slam) {
			return
		}
	}
	g.sounds[g.sound_n] = s
	g.sound_n += 1
}

// What the page plays this frame; it calls clear_sounds afterwards.
queued_sounds :: proc(g: ^Game) -> []Sound {
	return g.sounds[:min(int(g.sound_n), SOUND_QUEUE)]
}

clear_sounds :: proc(g: ^Game) {
	g.sound_n = 0
}

toggle_sound :: proc(g: ^Game) {
	g.sound_off = !g.sound_off
	clear_sounds(g)
	say(g, g.sound_off ? "Sound off. S to turn it on." : "Sound on.")
}
