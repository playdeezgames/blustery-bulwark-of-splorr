package game

// The ending (slice 4 step 30; DESIGN.md beats 6 and 7). Once you have met His Lordship on the roof,
// the herald's stall has a new row: tell him what is at the top. He listens to all of it, and
// believes every word he wrote. Then the end screen, with the one honest thing in the game, and the
// climb's numbers. You can play on; the herald proclaims just as before.

END_Y :: 28

// Telling the herald, once: his answer, then the end screen.
tell_herald :: proc(g: ^Game) {
	say(g, "You tell the herald: an old man, a cup of tea, six guards.")
	say(g, "The herald: \"Then who blows the wind? His Lordship, surely. Who else could?\"")
	g.ended = true
	leave_shop(g)
	g.mode = .End
}

draw_end :: proc(f: ^Frame, g: ^Game) {
	buf: [12]u8
	fill_rect(f, MAP_X, MAP_Y, VIEW_W * TILE, VIEW_H * TILE, COLOR_BLACK)
	x := 18
	print(f, "The end.", x, END_Y, COLOR_YELLOW)
	print(f, "The bulwark sits on the windiest crag", x, END_Y + 18, COLOR_LIGHT)
	print(f, "in the land.", x, END_Y + 28, COLOR_LIGHT)
	print(f, "The wind is only wind.", x, END_Y + 46, COLOR_WHITE)
	rows := [4]string{"Turns", "Deaths", "Level", "Kills"}
	values := [4]int{g.turn, g.deaths, g.level, g.kills}
	for name, i in rows {
		y := END_Y + 70 + i * 10
		print(f, name, x, y, COLOR_MID)
		print(f, itoa(buf[:], values[i]), x + 60, y, COLOR_LIGHT)
	}
	print(f, "Enter/OK or click to play on.", x, END_Y + 122, COLOR_YELLOW)
}
