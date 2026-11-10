package game

// The climber (slice 1 step 4; DESIGN.md "No classes, four attributes", "Death: town checkpoint").
// Four attributes bought with points at the start, health from Constitution, slow healing, and
// death: everything inside what you wear drops in one pile where you fell (worn things stay on
// you), you wake at the foot of the bulwark, and dying again before you pick the pile up loses it.

Attr :: enum u8 {
	Strength, // damage and the load limit
	Dexterity, // landing blows and dodging them
	Intelligence, // mana
	Constitution, // health and healing
}

ATTR_NAME := [Attr]string {
	.Strength     = "Strength",
	.Dexterity    = "Dexterity",
	.Intelligence = "Intelligence",
	.Constitution = "Constitution",
}

ATTR_USE := [Attr]string {
	.Strength     = "hits, load",
	.Dexterity    = "aim, dodge",
	.Intelligence = "mana",
	.Constitution = "health",
}

ATTR_BASE :: 10 // every attribute starts here
ATTR_MIN :: 6
ATTR_MAX :: 16
ATTR_POINTS :: 6 // to spend above the base; lowering one below the base gives its points back

points_left :: proc(g: ^Game) -> int {
	n := ATTR_POINTS
	for v in g.attr {
		n -= v - ATTR_BASE
	}
	return n
}

max_health :: proc(g: ^Game) -> int {
	return 2 * g.attr[.Constitution] + LEVEL_HEALTH * (g.level - 1)
}

// Turns between each point of health coming back.
heal_period :: proc(g: ^Game) -> int {
	p := max(5, 30 - g.attr[.Constitution])
	if worn_kind(g, .Amulet_Vigour) != 0 {
		p /= VIGOUR_HEAL
	}
	return p
}

// Added to every blow you land.
damage_bonus :: proc(g: ^Game) -> int {
	return (g.attr[.Strength] - ATTR_BASE) / 3
}

// Armour worn, from every piece.
armour_worn :: proc(g: ^Game) -> int {
	a := 0
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].place == .Worn {
			a += KIND[g.items[i].kind].armour
		}
	}
	if g.ward_turns > 0 {
		a += WARD_ARMOUR
	}
	return a
}

// Character creation: Up and Down pick a row, Left and Right change an attribute, Confirm on the
// last row begins the climb.
CREATE_BEGIN_ROW :: len(Attr)

create_command :: proc(g: ^Game, c: Command) {
	#partial switch c {
	case .North, .North_West, .North_East:
		g.create_row = (g.create_row + CREATE_BEGIN_ROW) % (CREATE_BEGIN_ROW + 1)
	case .South, .South_West, .South_East:
		g.create_row = (g.create_row + 1) % (CREATE_BEGIN_ROW + 1)
	case .West:
		change_attr(g, -1)
	case .East:
		change_attr(g, 1)
	case .Confirm:
		if g.create_row == CREATE_BEGIN_ROW {
			begin_climb(g)
		} else {
			g.create_row += 1
		}
	}
}

change_attr :: proc(g: ^Game, d: int) {
	if g.create_row >= CREATE_BEGIN_ROW {
		return
	}
	a := Attr(g.create_row)
	v := g.attr[a] + d
	if v < ATTR_MIN || v > ATTR_MAX || (d > 0 && points_left(g) <= 0) {
		return
	}
	g.attr[a] = v
	g.health = max_health(g)
}

begin_climb :: proc(g: ^Game) {
	g.mode = .Play
	g.health = max_health(g)
	g.mana = max_mana(g)
	say(g, "You climb in from the town gate.")
	g.learns = 1
	open_learn_if_owed(g)
}

// Creation screen layout (in the map area).
CREATE_TOP :: 40
CREATE_ROW_H :: 14
CREATE_MINUS_X :: 100
CREATE_VALUE_X :: 112
CREATE_PLUS_X :: 130
CREATE_USE_X :: 148

create_row_y :: proc(row: int) -> int {
	return CREATE_TOP + row * CREATE_ROW_H + (row == CREATE_BEGIN_ROW ? 6 : 0)
}

// A click or tap on the creation screen: the - and + change a row, the last row begins.
create_pointer :: proc(g: ^Game, sx, sy: int) {
	for row in 0 ..= CREATE_BEGIN_ROW {
		y := create_row_y(row)
		if sy < y - 3 || sy >= y + CREATE_ROW_H - 3 || sx >= VIEW_W * TILE {
			continue
		}
		g.create_row = row
		if row == CREATE_BEGIN_ROW {
			begin_climb(g)
		} else if sx >= CREATE_MINUS_X - 4 && sx < CREATE_VALUE_X - 2 {
			change_attr(g, -1)
		} else if sx >= CREATE_PLUS_X - 4 && sx < CREATE_USE_X - 4 {
			change_attr(g, 1)
		}
		return
	}
}

draw_create :: proc(f: ^Frame, g: ^Game) {
	buf: [12]u8
	print(f, "Who climbs the bulwark?", 12, 8, COLOR_CYAN)
	w := print(f, "Points to spend: ", 12, 22, COLOR_MID)
	left := points_left(g)
	print(f, itoa(buf[:], left), 12 + w, 22, left > 0 ? COLOR_YELLOW : COLOR_MID)
	for a, i in Attr {
		y := create_row_y(i)
		if g.create_row == i {
			fill_rect(f, 2, y - 3, VIEW_W * TILE - 4, CREATE_ROW_H, COLOR_DARK)
			print(f, ">", 4, y, COLOR_YELLOW)
		}
		print(f, ATTR_NAME[a], 12, y, COLOR_LIGHT)
		print(f, "-", CREATE_MINUS_X, y, g.attr[a] > ATTR_MIN ? COLOR_WHITE : COLOR_DARK)
		print(f, itoa(buf[:], g.attr[a]), CREATE_VALUE_X, y, COLOR_WHITE)
		print(f, "+", CREATE_PLUS_X, y, g.attr[a] < ATTR_MAX && left > 0 ? COLOR_WHITE : COLOR_DARK)
		print(f, ATTR_USE[a], CREATE_USE_X, y, COLOR_MID)
	}
	y := create_row_y(CREATE_BEGIN_ROW)
	if g.create_row == CREATE_BEGIN_ROW {
		fill_rect(f, 2, y - 3, VIEW_W * TILE - 4, CREATE_ROW_H, COLOR_DARK)
		print(f, ">", 4, y, COLOR_YELLOW)
	}
	print(f, "Begin the climb", 12, y, COLOR_YELLOW)
	kb: [16]u8
	y += 22
	w = print(f, "Health ", 12, y, COLOR_MID)
	w += print(f, itoa(buf[:], max_health(g)), 12 + w, y, COLOR_LIGHT)
	w += print(f, "   Load limit ", 12 + w, y, COLOR_MID)
	w += print(f, kg(kb[:], carry_limit(g)), 12 + w, y, COLOR_LIGHT)
	print(f, " kg", 12 + w, y, COLOR_MID)
	print(f, "Up/Down: pick    Left/Right: change", 12, y + 14, COLOR_DARK)
	print(f, "Enter/OK, or click Begin, to start", 12, y + 24, COLOR_DARK)
}

hurt :: proc(g: ^Game, amount: int, by: string) {
	g.health -= amount
	if g.health <= 0 {
		die(g, by)
	}
}

// Death: the old pile (if it was never fetched) is gone; everything inside what you wear drops in
// a new pile here.
die :: proc(g: ^Game, by: string) {
	g.health = 0
	stop_travel(g)
	for i in 1 ..< MAX_ITEMS {
		if g.items[i].pile && g.items[i].place == .Ground {
			free_item(g, i)
		}
	}
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		if it.place != .Inside || g.items[it.parent].place != .Worn {
			continue
		}
		it.place, it.floor, it.x, it.y, it.pile = .Ground, i8(g.current), i16(g.x), i16(g.y), true
	}
	g.deaths += 1
	g.mode = .Dead
	g.killed_by = by
	say(g, "You fall to ", by, ".")
}

// Confirm (or a click) after death: wake at the foot of the bulwark with full health. Tenants
// forget you.
wake :: proc(g: ^Game) {
	g.mode = .Play
	g.health = max_health(g)
	g.mana = max_mana(g)
	g.ward_turns, g.sense_turns, g.anchor_spell = 0, 0, false
	g.hunger = 0 // fed while you lay there (until the town exists)
	for &t in g.tenants {
		t.awake = false
	}
	enter_floor(g, 0, .Stairs_Down)
	g.lit = torch_fuel(g) > 0
	say(g, "You wake below the bulwark (no town yet).")
	say(g, "What you carried lies where you fell.")
	open_learn_if_owed(g)
}

DEAD_Y :: 50

draw_dead :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, 20, DEAD_Y - 8, VIEW_W * TILE - 40, 64, COLOR_BLACK)
	fill_rect(f, 20, DEAD_Y - 8, VIEW_W * TILE - 40, 1, COLOR_RED)
	fill_rect(f, 20, DEAD_Y + 55, VIEW_W * TILE - 40, 1, COLOR_RED)
	print(f, "You fall.", 30, DEAD_Y, COLOR_RED)
	w := print(f, "Brought down by ", 30, DEAD_Y + 12, COLOR_LIGHT)
	print(f, g.killed_by, 30 + w, DEAD_Y + 12, COLOR_LIGHT)
	print(f, "Yer pack's contents stay here.", 30, DEAD_Y + 24, COLOR_MID)
	print(f, "Press Enter, OK or click to wake.", 30, DEAD_Y + 40, COLOR_YELLOW)
}
