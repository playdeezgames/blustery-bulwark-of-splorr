package game

// The inventory screen (DESIGN.md "Inventory: pick up, then place"). The left pane is the paper doll
// (one row per slot) and the ground underfoot; the right pane is one open container (or the
// ground). Choose an item to hold it, then choose where it goes: a slot to wear it, the ground to
// drop it, or anywhere in the right pane to put it in that container. East opens a container, West
// goes back out. The same model serves keys, gamepad, the touch d-pad, taps and the mouse (which can
// also drag: press on an item, release on the place). Moving things costs no turn.

Inventory_View :: struct {
	pane:   int, // 0 the paper doll, 1 the open container
	cursor: [2]int, // row in each pane
	view:   int, // the open container's item id; 0 is the ground underfoot
	held:   int, // the item chosen to move, or 0
	press:  [2]int, // pane and row where a mouse button went down (for dragging)
	scroll: int, // first item row shown in the right pane
}

LEFT_SLOTS := [?]Slot {
	.Weapon,
	.Shield,
	.Light,
	.Helmet,
	.Armour,
	.Cloak,
	.Bracers,
	.Gauntlets,
	.Boots,
	.Ring_Left,
	.Ring_Right,
	.Amulet,
	.Belt,
	.Pack,
	.Purse,
}
GROUND_ROW :: len(LEFT_SLOTS) // the last left row
LEFT_ROWS :: len(LEFT_SLOTS) + 1

INV_ROW_H :: 10
INV_TOP :: 14 // y of the first row under the headers
INV_LEFT_X :: MAP_X + 2
INV_RIGHT_X :: MAP_X + 130
INV_PANE_W :: 120
INV_RIGHT_ROWS :: (VIEW_H * TILE - INV_TOP) / INV_ROW_H // item rows that fit in the right pane

open_inventory :: proc(g: ^Game) {
	g.mode = .Inventory
	g.inv = {}
	g.inv.view = ground_item_at(g, g.x, g.y) != 0 ? 0 : worn(g, .Pack)
}

close_inventory :: proc(g: ^Game) {
	g.mode = .Play
	g.inv.held = 0
}

// The items in a view, in pool order (the ground: what lies underfoot).
view_items :: proc(g: ^Game, view: int, out: ^[MAX_ITEMS]int) -> int {
	n := 0
	for i in 1 ..< MAX_ITEMS {
		it := &g.items[i]
		in_view := view == 0 ? (it.place == .Ground && int(it.floor) == g.current && int(it.x) == g.x && int(it.y) == g.y) : (it.place == .Inside && int(it.parent) == view)
		if in_view {
			out[n] = i
			n += 1
		}
	}
	return n
}

// The item on a row (0 for an empty slot, the ground row, the header or past the end).
row_item :: proc(g: ^Game, pane, row: int) -> int {
	if pane == 0 {
		if row < 0 || row >= len(LEFT_SLOTS) {
			return 0
		}
		return worn(g, LEFT_SLOTS[row])
	}
	if row < 1 {
		return 0
	}
	list: [MAX_ITEMS]int
	n := view_items(g, g.inv.view, &list)
	return row - 1 < n ? list[row - 1] : 0
}

pane_rows :: proc(g: ^Game, pane: int) -> int {
	if pane == 0 {
		return LEFT_ROWS
	}
	list: [MAX_ITEMS]int
	return 1 + view_items(g, g.inv.view, &list)
}

open_view :: proc(g: ^Game, view: int) {
	g.inv.view = view
	g.inv.pane = 1
	g.inv.cursor[1] = pane_rows(g, 1) > 1 ? 1 : 0
	g.inv.scroll = 0
}

inventory_command :: proc(g: ^Game, c: Command) {
	v := &g.inv
	switch c {
	case .North:
		v.cursor[v.pane] = max(0, v.cursor[v.pane] - 1)
	case .South:
		v.cursor[v.pane] = min(pane_rows(g, v.pane) - 1, v.cursor[v.pane] + 1)
	case .West:
		if v.pane == 1 && v.view != 0 && g.items[v.view].place == .Inside {
			inner := v.view
			open_view(g, int(g.items[v.view].parent))
			// Put the cursor back on the container just left.
			list: [MAX_ITEMS]int
			n := view_items(g, v.view, &list)
			for i in 0 ..< n {
				if list[i] == inner {
					v.cursor[1] = i + 1
				}
			}
		} else {
			v.pane = 0
		}
	case .East:
		open_row(g, v.pane, v.cursor[v.pane])
	case .Confirm:
		act(g, v.pane, v.cursor[v.pane])
	case .Cancel:
		if v.held != 0 {
			v.held = 0
			say(g, "You leave it where it was.")
		} else {
			close_inventory(g)
		}
	case .Inventory, .Map:
		close_inventory(g)
	case .Wait, .North_West, .North_East, .South_West, .South_East, .Cast:
	}
	keep_cursor_in_view(g)
}

// Opens what is on a row: a container into the right pane, or the ground. On a plain row of the
// left pane it just moves to the right pane.
open_row :: proc(g: ^Game, pane, row: int) {
	if pane == 0 && row == GROUND_ROW {
		open_view(g, 0)
		return
	}
	id := row_item(g, pane, row)
	if id != 0 && is_container(g.items[id].kind) {
		open_view(g, id)
		return
	}
	if pane == 0 {
		g.inv.pane = 1
	}
}

// Confirm on a row: hold the item there, or put the held item there.
act :: proc(g: ^Game, pane, row: int) {
	v := &g.inv
	v.pane, v.cursor[pane] = pane, row
	target := row_item(g, pane, row)
	if v.held == 0 {
		if target != 0 {
			v.held = target
			say(g, "Holding: ", item_name(g, target), ". Choose where.")
		} else if pane == 0 && row == GROUND_ROW {
			open_view(g, 0)
		}
		return
	}
	if target == v.held {
		v.held = 0
		return
	}
	name_buf: [32]u8
	n := copy(name_buf[:], item_name(g, v.held))
	name := string(name_buf[:n])
	if pane == 0 {
		if row == GROUND_ROW {
			drop(g, v.held)
			say(g, "You drop ", name, ".")
			v.held = 0
		} else if wear(g, v.held, LEFT_SLOTS[row]) {
			say(g, "You wear ", name, ".")
			v.held = 0
		}
		return
	}
	if v.view == 0 {
		drop(g, v.held)
		say(g, "You drop ", name, ".")
		v.held = 0
	} else if put_in(g, v.held, v.view) {
		say(g, "You put ", name, " in the ", KIND[g.items[v.view].kind].name, ".")
		v.held = 0
	}
	v.cursor[1] = min(v.cursor[1], pane_rows(g, 1) - 1)
}

keep_cursor_in_view :: proc(g: ^Game) {
	v := &g.inv
	item_row := v.cursor[1] - 1
	if item_row < v.scroll {
		v.scroll = max(0, item_row)
	} else if item_row >= v.scroll + INV_RIGHT_ROWS {
		v.scroll = item_row - INV_RIGHT_ROWS + 1
	}
}

// The pane and row under a screen pixel, and whether it is on a row's open marker.
inventory_hit :: proc(g: ^Game, sx, sy: int) -> (pane, row: int, marker, ok: bool) {
	if sx < MAP_X || sy < MAP_Y || sx >= MAP_X + VIEW_W * TILE || sy >= MAP_Y + VIEW_H * TILE {
		return
	}
	pane = sx >= INV_RIGHT_X - 4 ? 1 : 0
	x0 := pane == 0 ? INV_LEFT_X : INV_RIGHT_X
	marker = sx >= x0 + INV_PANE_W - 10
	if pane == 1 && sy < INV_TOP {
		return 1, 0, marker, true
	}
	if sy < INV_TOP {
		return
	}
	r := (sy - INV_TOP) / INV_ROW_H
	if pane == 0 {
		if r >= LEFT_ROWS {
			return
		}
		return 0, r, marker, true
	}
	r += 1 + g.inv.scroll
	return 1, min(r, pane_rows(g, 1) - 1), marker, true
}

// A click or tap in the inventory. A secondary click lets go of the held item.
inventory_pointer :: proc(g: ^Game, sx, sy: int, kind: Pointer) {
	if kind == .Mouse_Secondary {
		g.inv.held = 0
		return
	}
	pane, row, marker, ok := inventory_hit(g, sx, sy)
	if !ok {
		return
	}
	g.inv.press = {pane, row}
	if marker && g.inv.held == 0 {
		id := row_item(g, pane, row)
		if (id != 0 && is_container(g.items[id].kind)) || (pane == 0 && row == GROUND_ROW) {
			open_row(g, pane, row)
			return
		}
	}
	act(g, pane, row)
	keep_cursor_in_view(g)
}

// A mouse button let go: if an item is held and the pointer moved to another row, put it there.
inventory_release :: proc(g: ^Game, sx, sy: int) {
	if g.mode != .Inventory || g.inv.held == 0 {
		return
	}
	pane, row, _, ok := inventory_hit(g, sx, sy)
	if !ok || (pane == g.inv.press[0] && row == g.inv.press[1]) {
		return
	}
	act(g, pane, row)
}

// "9.1" kilograms from grams, one decimal place.
kg :: proc(buf: []u8, grams: int) -> string {
	whole: [12]u8
	w := itoa(whole[:], grams / 1000)
	n := copy(buf, w)
	if n + 2 <= len(buf) {
		buf[n] = '.'
		buf[n + 1] = u8('0' + (grams % 1000) / 100)
		n += 2
	}
	return string(buf[:n])
}

draw_inventory :: proc(f: ^Frame, g: ^Game) {
	v := &g.inv
	b1, b2: [16]u8
	// Left header: the load.
	load := carried_weight(g)
	load_color: u8 = overloaded(g) ? COLOR_RED : load_anchors(g) ? COLOR_ORANGE : COLOR_CYAN
	x := print(f, "Worn ", INV_LEFT_X, 2, COLOR_CYAN)
	x += print(f, kg(b1[:], load), INV_LEFT_X + x, 2, load_color)
	x += print(f, "/", INV_LEFT_X + x, 2, COLOR_MID)
	x += print(f, kg(b2[:], carry_limit(g)), INV_LEFT_X + x, 2, COLOR_MID)
	print(f, "kg", INV_LEFT_X + x, 2, COLOR_MID)
	for s, i in LEFT_SLOTS {
		draw_inv_row(f, g, 0, i, SLOT_LABEL[s], worn(g, s))
	}
	draw_inv_row(f, g, 0, GROUND_ROW, "Floor", 0)
	fill_rect(f, INV_RIGHT_X - 5, 0, 1, VIEW_H * TILE, COLOR_DARK)
	// Right header: the open container and its limits.
	y := 2
	if v.pane == 1 && v.cursor[1] == 0 {
		fill_rect(f, INV_RIGHT_X - 2, y - 1, INV_PANE_W + 2, INV_ROW_H, COLOR_DARK)
	}
	if v.view == 0 {
		print(f, "Underfoot", INV_RIGHT_X, y, COLOR_CYAN)
	} else {
		k := KIND[g.items[v.view].kind]
		x = print(f, k.name, INV_RIGHT_X, y, COLOR_CYAN)
		if k.belt_slots > 0 {
			x += print(f, " ", INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, itoa(b1[:], contents_count(g, v.view)), INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, "/", INV_RIGHT_X + x, y, COLOR_MID)
			print(f, itoa(b2[:], k.belt_slots), INV_RIGHT_X + x, y, COLOR_MID)
		} else {
			x += print(f, " ", INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, kg(b1[:], contents_weight(g, v.view)), INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, "/", INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, kg(b2[:], k.cap_weight), INV_RIGHT_X + x, y, COLOR_MID)
			x += print(f, " ", INV_RIGHT_X + x, y, COLOR_MID)
			// Bulk as a share of the room, in tenths, so it fits.
			x += print(f, itoa(b1[:], contents_bulk(g, v.view) * 100 / k.cap_bulk), INV_RIGHT_X + x, y, COLOR_MID)
			print(f, "%", INV_RIGHT_X + x, y, COLOR_MID)
		}
	}
	list: [MAX_ITEMS]int
	n := view_items(g, v.view, &list)
	if n == 0 {
		print(f, "(nothing)", INV_RIGHT_X, INV_TOP, COLOR_DARK)
	}
	for i in v.scroll ..< min(n, v.scroll + INV_RIGHT_ROWS) {
		draw_inv_row(f, g, 1, i + 1, "", list[i])
	}
	if v.scroll > 0 {
		print(f, "^", INV_RIGHT_X + INV_PANE_W - 6, INV_TOP - 9, COLOR_MID)
	}
	if v.scroll + INV_RIGHT_ROWS < n {
		print(f, "v", INV_RIGHT_X + INV_PANE_W - 6, INV_TOP + INV_RIGHT_ROWS * INV_ROW_H - 2, COLOR_MID)
	}
}

draw_inv_row :: proc(f: ^Frame, g: ^Game, pane, row: int, label: string, id: int) {
	v := &g.inv
	x0 := pane == 0 ? INV_LEFT_X : INV_RIGHT_X
	y := pane == 0 ? INV_TOP + row * INV_ROW_H : INV_TOP + (row - 1 - v.scroll) * INV_ROW_H
	if v.pane == pane && v.cursor[pane] == row {
		fill_rect(f, x0 - 2, y - 1, INV_PANE_W + 2, INV_ROW_H, COLOR_DARK)
	}
	x := x0
	if label != "" {
		x += print(f, label, x, y, COLOR_MID) + GLYPH_W
	}
	if id == 0 {
		if pane == 0 && row == GROUND_ROW {
			list: [MAX_ITEMS]int
			n := view_items(g, 0, &list)
			if n > 0 {
				b: [12]u8
				w := print(f, itoa(b[:], n), x, y, COLOR_LIGHT)
				print(f, n == 1 ? " thing" : " things", x + w, y, COLOR_LIGHT)
			} else {
				print(f, "-", x, y, COLOR_DARK)
			}
			print(f, ">", x0 + INV_PANE_W - 8, y, COLOR_MID)
		} else {
			print(f, "-", x, y, COLOR_DARK)
		}
		return
	}
	color: u8 = id == v.held ? COLOR_YELLOW : COLOR_WHITE
	if id == worn(g, .Light) && g.lit {
		color = id == v.held ? COLOR_YELLOW : COLOR_ORANGE
	}
	if full := KIND[g.items[id].kind].durability; full > 0 && id != v.held {
		dur := int(g.items[id].dur)
		if dur * 5 <= full {
			color = COLOR_RED
		} else if dur * 2 <= full {
			color = COLOR_ORANGE
		}
	}
	name := item_name(g, id)
	room := (x0 + INV_PANE_W - (is_container(g.items[id].kind) ? 10 : 0) - x) / GLYPH_W
	print(f, name[:min(len(name), room)], x, y, color)
	if is_container(g.items[id].kind) {
		print(f, ">", x0 + INV_PANE_W - 8, y, COLOR_MID)
	}
}
