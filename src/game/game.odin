package game

// The rules, independent of the platform. Slice 1 step 1 (PLAN.md): three generated floors that
// persist for the character, stairs, fog of war, an automap, and walking by keys, gamepad, touch
// d-pad and mouse. Wind, light, inventory and the rest arrive in later steps.

// Commands the page sends for keys, gamepad buttons and the touch d-pad (keep in step with
// web/index.html). Directions are the eight compass moves.
Command :: enum i32 {
	North,
	South,
	West,
	East,
	North_West,
	North_East,
	South_West,
	South_East,
	Wait,
	Confirm,
	Cancel,
	Map,
	Inventory,
	Cast,
}

DIRECTION := [Command][2]int {
	.North      = {0, -1},
	.South      = {0, 1},
	.West       = {-1, 0},
	.East       = {1, 0},
	.North_West = {-1, -1},
	.North_East = {1, -1},
	.South_West = {-1, 1},
	.South_East = {1, 1},
	.Wait       = {0, 0},
	.Confirm    = {0, 0},
	.Cancel     = {0, 0},
	.Map        = {0, 0},
	.Inventory  = {0, 0},
	.Cast       = {0, 0},
}

FLOOR_COUNT :: 16 // the whole bulwark (decided November 13, 2026); room for every floor in the save
BUILT_FLOORS :: 7 // floors that exist so far (slice 2 step 10): floor 8 is still being built

Mode :: enum u8 {
	Play,
	Automap,
	Inventory,
	Create, // character creation, before the climb
	Dead, // fallen; the next Confirm or click wakes you
	Learn, // choosing a spell (at level 1 and each level after)
	Cast, // the list of known spells
	Aim, // a direction for an aimed spell
	Shop, // inside a town shop (or at a carny's stall)
	Notice, // the end of slice 1, once
}

LOG_CAP :: 64 // characters per remembered message

Message :: struct {
	text: [LOG_CAP]u8,
	n:    int,
}

TRAVEL_FRAMES :: 4 // frames between steps when walking a mouse route

Spells :: bit_set[Spell; u64]
Kinds :: bit_set[Item_Kind; u128]

Game :: struct {
	seed:        u64,
	floors:      [FLOOR_COUNT]Floor,
	current:     int, // index into floors (floor number - 1)
	x, y:        int,
	turn:        int,
	mode:        Mode,
	vis:         Visible,
	log:         [LOG_LINES]Message, // oldest first
	last_said:   Message, // the last message, whole, to fold an immediate repeat into a count
	last_count:  int, // how many times in a row it was said
	last_lines:  int, // log lines it took
	path:        [MAX_PATH][2]int,
	path_len:    int,
	path_i:      int,
	travel_wait: int,
	rng:         Rng, // gusts and other chances during play (floors use their own seeds)
	gust_in:     int, // turns until the next gust
	lit:         bool, // the torch in the light slot is burning
	items:       [MAX_ITEMS]Item,
	inv:         Inventory_View,
	attr:        [Attr]int,
	health:      int,
	xp:          int,
	create_row:  int,
	tenants:     [MAX_TENANTS]Tenant,
	deaths:      int,
	killed_by:   [40]u8, // what brought you down last (a copy: saves hold no pointers)
	killed_n:    int,
	no_tenants:  bool, // tests set this to check other rules without tenants about
	level:       int,
	mana:        int,
	known:       Spells, // fixed size, so new spells keep saves loading
	learns:      int, // spell choices owed
	menu_row:    int, // the learn and cast lists
	aim_spell:   Spell,
	ward_turns:  int,
	sense_turns: int,
	anchor_spell: bool, // Anchor holds you until the next gust
	fx:          [MAX_FX][2]int, // the cells the last spell crossed
	fx_len:      int,
	fx_blast:    bool,
	fx_at:       [2]int,
	hunger:      int, // rises a point a turn; food takes it down (supplies.odin)
	ident:       Kinds, // kinds known by name (fixed size: up to MAX_KINDS kinds)
	look:        [MAX_KINDS]u8, // which look each potion, scroll, ring and amulet kind wears, by int(kind)
	town:        Floor, // the town (town.odin); g.current is TOWN while there
	shop:        Shop,
	shop_scroll: int,
	shop_tenant: int, // the carny whose stall is open
	bank:        int,
	trained:     bool, // with the mentor, this visit
	talk:        int, // turns the mentor's and herald's lines
	deepest:     int, // highest floor number reached
	kills:       int,
	told:        Told, // what the herald has already proclaimed
	proclamation: [96]u8,
	proclamation_n: int,
	ticket:      int, // the carny at floor 4's door
	admitted:    bool, // paid to see the Horde
	boss_dead:   bool,
	slice_done:  bool, // the end-of-slice notice has been shown
	unlocked:    bit_set[0 ..< FLOOR_COUNT], // boss floors (by index) whose door up has been opened: it stays open
	// New fields go here, at the end: a save from before them loads with them zero (save.odin).
	drained:     [Attr]i8, // attribute points a cave bear took (the temple gives them back)
}

Told :: struct {
	deepest, level, kills, deaths: int,
	boss: bool,
}

floor_of :: proc(g: ^Game) -> ^Floor {
	if g.current == TOWN {
		return &g.town
	}
	return &g.floors[g.current]
}

init_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.seed = seed
	g.rng = Rng{seed ~ 0x5EED_B1A5_7E2F_0001}
	for &v in g.attr {
		v = ATTR_BASE
	}
	g.level = 1
	g.health = max_health(g)
	g.mana = max_mana(g)
	shuffle_looks(g)
	give_starting_kit(g)
	enter_town(g, .Start)
	g.mode = .Create
	say(g, "A gale flattened yer farm.")
	say(g, "The herald says the lord did it.")
	say(g, "The wind howls round the bulwark.")
}

// Moves to floor index `i`, standing on its stairs of kind `arrive`. A floor is generated the first
// time it is entered and kept after that.
enter_floor :: proc(g: ^Game, i: int, arrive: Cell) {
	if g.current >= 0 && g.current != i {
		g.floors[g.current].left_turn = max(g.turn, 1) // restocking counts from here
	}
	g.current = i
	f := floor_of(g)
	if !f.made && i == BOSS_INDEX {
		build_boss_floor(g)
	} else if !f.made {
		generate_floor(f, floor_seed(g.seed, i + 1), i + 1)
		populate_floor(g, i)
		make_camp(g, i)
		if !g.no_tenants {
			r := Rng{floor_seed(g.seed, f.number) ~ 0x7E4A_47_5EED}
			populate_tenants(g, i, &r)
		}
	}
	if i != BOSS_INDEX {
		restock(g, i)
	}
	at := arrive == .Stairs_Up ? f.up : f.down
	g.x, g.y = at.x, at.y
	g.deepest = max(g.deepest, f.number)
	g.gust_in = gust_period(f.number)
	stop_travel(g)
	refresh_view(g)
}

LOG_WIDTH :: (VIEW_W * TILE - LOG_X) / GLYPH_W // characters on a log line

// Adds a message to the log, wrapped at spaces onto as many lines as it needs (a word longer than
// a line is cut). Wrapped lines after the first are indented by one space.
say :: proc(g: ^Game, parts: ..string) {
	text: [256]u8
	n := 0
	for s in parts {
		for i in 0 ..< len(s) {
			if n < len(text) {
				text[n] = s[i]
				n += 1
			}
		}
	}
	// The same one-line message again straight away shows once, with a count: "A wall. (x4)".
	said := string(text[:n])
	if g.last_count > 0 && g.last_lines == 1 && said == message(&g.last_said) && n + 7 <= LOG_WIDTH {
		g.last_count += 1
		buf: [8]u8
		m := &g.log[LOG_LINES - 1]
		m^ = {}
		m.n = copy(m.text[:], said)
		m.n += copy(m.text[m.n:], " (x")
		m.n += copy(m.text[m.n:], itoa(buf[:], g.last_count))
		m.n += copy(m.text[m.n:], ")")
		return
	}
	g.last_said = {}
	g.last_said.n = copy(g.last_said.text[:], said)
	g.last_count = 1
	g.last_lines = 0
	start := 0
	first := true
	for start < n {
		width := first ? LOG_WIDTH : LOG_WIDTH - 1
		end := min(n, start + width)
		if end < n {
			// Break at the last space that fits, if there is one.
			for b := end; b > start; b -= 1 {
				if text[b] == ' ' {
					end = b
					break
				}
			}
		}
		push_log_line(g, string(text[start:end]), !first)
		g.last_lines += 1
		start = end
		for start < n && text[start] == ' ' {
			start += 1
		}
		first = false
	}
}

push_log_line :: proc(g: ^Game, line: string, indent: bool) {
	for i in 0 ..< LOG_LINES - 1 {
		g.log[i] = g.log[i + 1]
	}
	m := &g.log[LOG_LINES - 1]
	m^ = {}
	if indent {
		m.text[0] = ' '
		m.n = 1
	}
	for i in 0 ..< len(line) {
		if m.n < LOG_CAP {
			m.text[m.n] = line[i]
			m.n += 1
		}
	}
}

message :: proc(m: ^Message) -> string {
	return string(m.text[:m.n])
}

// Decimal text of a whole number, in a caller's buffer.
itoa :: proc(buf: []u8, v: int) -> string {
	n := v < 0 ? -v : v
	i := len(buf)
	for {
		i -= 1
		buf[i] = u8('0' + n % 10)
		n /= 10
		if n == 0 || i == 0 {
			break
		}
	}
	if v < 0 && i > 0 {
		i -= 1
		buf[i] = '-'
	}
	return string(buf[i:])
}

cell_at :: proc(g: ^Game, x, y: int) -> Cell {
	return floor_cell(floor_of(g), x, y)
}

stop_travel :: proc(g: ^Game) {
	g.path_len, g.path_i, g.travel_wait = 0, 0, 0
}

// One step of the player, then the turn passes (the wind may move them again); a load heavy
// enough to anchor you also slows you to a step every two turns. False, with the reason said, when
// a wall is in the way or the load is too heavy to move (no turn passes).
step_player :: proc(g: ^Game, d: [2]int) -> bool {
	if id := tenant_at(g, g.x + d.x, g.y + d.y); id != 0 {
		if !hostile(&g.tenants[id]) && g.tenants[id].kind == .Carny {
			g.shop_tenant = id
			open_shop(g, id == g.ticket && !g.admitted ? .Admission : .Carny)
			return false
		}
		if !hostile(&g.tenants[id]) && g.tenants[id].kind == .Hermit {
			g.shop_tenant = id
			open_shop(g, .Hermit)
			return false
		}
		player_attack(g, id)
		return false
	}
	if !passable(cell_at(g, g.x + d.x, g.y + d.y)) {
		say(g, "A wall.")
		return false
	}
	if overloaded(g) {
		say(g, "You carry too much to move.")
		return false
	}
	g.x += d.x
	g.y += d.y
	end_turn(g)
	if load_anchors(g) {
		end_turn(g)
	}
	return true
}

describe_arrival :: proc(g: ^Game) {
	if id := ground_item_at(g, g.x, g.y); id != 0 {
		if KIND[g.items[id].kind].fixed {
			say(g, fixed_line(g.items[id].kind))
		} else {
			say(g, "Here: ", item_name(g, id), ". Enter/OK to pick up.")
		}
		return
	}
	#partial switch cell_at(g, g.x, g.y) {
	case .Door:
		s := shop_at(g.x, g.y)
		say(g, SHOP[s].title, s == .Herald ? ". Enter/OK to listen." : ". Enter/OK to go in.")
	case .Stairs_Up:
		if in_town(g) {
			say(g, "The bulwark gate. Enter/OK to climb.")
			return
		}
		say(g, "Stairs up. Enter/OK to climb.")
	case .Stairs_Down:
		say(g, "Stairs down. Enter/OK to descend.")
	}
}

command :: proc(g: ^Game, c: Command) {
	stop_travel(g)
	g.fx_len, g.fx_blast = 0, false
	if g.mode == .Automap {
		g.mode = .Play // any command closes the map
		return
	}
	switch g.mode {
	case .Inventory:
		inventory_command(g, c)
		return
	case .Create:
		create_command(g, c)
		return
	case .Dead:
		if c == .Confirm {
			wake(g)
		}
		return
	case .Learn:
		learn_command(g, c)
		return
	case .Cast:
		cast_command(g, c)
		return
	case .Aim:
		aim_command(g, c)
		open_learn_if_owed(g)
		return
	case .Shop:
		shop_command(g, c)
		return
	case .Notice:
		if c == .Confirm || c == .Cancel {
			g.mode = .Play
		}
		return
	case .Play, .Automap:
	}
	defer open_learn_if_owed(g)
	switch c {
	case .North, .South, .West, .East, .North_West, .North_East, .South_West, .South_East:
		if step_player(g, DIRECTION[c]) {
			describe_arrival(g)
		}
	case .Wait:
		say(g, "You wait. The wind does not.")
		end_turn(g)
	case .Confirm:
		use_here(g)
	case .Cancel:
	case .Map:
		g.mode = .Automap
	case .Inventory:
		open_inventory(g)
	case .Cast:
		open_cast(g)
	}
}

// Confirm on the spot: take the stairs, or nothing.
use_here :: proc(g: ^Game) {
	buf: [8]u8
	#partial switch cell_at(g, g.x, g.y) {
	case .Door:
		open_shop(g, shop_at(g.x, g.y))
	case .Stairs_Up:
		if in_town(g) {
			gate(g)
		} else if g.current == BOSS_INDEX {
			door_to_floor_five(g)
		} else if g.current + 1 < BUILT_FLOORS {
			enter_floor(g, g.current + 1, .Stairs_Down)
			say(g, "You climb to floor ", itoa(buf[:], g.current + 1), ". The wind is stronger.")
		} else {
			say(g, "Above: scaffolding, and a sign. \"Floor 8. Coming soon, by order of His Lordship.\"")
		}
	case .Stairs_Down:
		if g.current > 0 {
			enter_floor(g, g.current - 1, .Stairs_Up)
			say(g, "You go down to floor ", itoa(buf[:], g.current + 1), ".")
		} else {
			say(g, "You go down to the town.")
			enter_town(g, .Gate)
		}
	case:
		if !get_here(g) && !light_torch(g) {
			say(g, "Nothing here to use.")
		}
	}
}

// The map cell under a screen pixel, if the pixel is on the map view.
screen_to_cell :: proc(g: ^Game, sx, sy: int) -> (x, y: int, ok: bool) {
	if sx < MAP_X || sy < MAP_Y || sx >= MAP_X + VIEW_W * TILE || sy >= MAP_Y + VIEW_H * TILE {
		return 0, 0, false
	}
	ox, oy := view_origin(g)
	return ox + (sx - MAP_X) / TILE, oy + (sy - MAP_Y) / TILE, true
}

// Top-left map cell of the view, which keeps the player in the middle.
view_origin :: proc(g: ^Game) -> (x, y: int) {
	return g.x - VIEW_W / 2, g.y - VIEW_H / 2
}

Pointer :: enum i32 {
	Mouse_Primary,
	Mouse_Secondary,
	Touch,
}

// A click or tap at a screen pixel. A mouse click walks there (one step, or a route over seen
// cells); a right click or a tap inspects (touch moves with the d-pad; DESIGN.md).
pointer :: proc(g: ^Game, sx, sy: int, kind: Pointer) {
	stop_travel(g)
	if g.mode != .Aim {
		g.fx_len, g.fx_blast = 0, false
	}
	if g.mode == .Automap {
		g.mode = .Play
		return
	}
	switch g.mode {
	case .Inventory:
		inventory_pointer(g, sx, sy, kind)
		return
	case .Create:
		create_pointer(g, sx, sy)
		return
	case .Dead:
		wake(g)
		return
	case .Learn:
		learn_pointer(g, sx, sy)
		return
	case .Cast:
		cast_pointer(g, sx, sy)
		return
	case .Aim:
		g.fx_len, g.fx_blast = 0, false
		aim_pointer(g, sx, sy)
		open_learn_if_owed(g)
		return
	case .Shop:
		shop_pointer(g, sx, sy)
		return
	case .Notice:
		g.mode = .Play
		return
	case .Play, .Automap:
	}
	defer open_learn_if_owed(g)
	if hint, ok := panel_hint_at(sx, sy); ok {
		command(g, hint)
		return
	}
	x, y, ok := screen_to_cell(g, sx, sy)
	if !ok {
		return
	}
	f := floor_of(g)
	if kind != .Mouse_Primary {
		inspect(g, x, y)
		return
	}
	if x == g.x && y == g.y {
		use_here(g)
		return
	}
	if abs(x - g.x) <= 1 && abs(y - g.y) <= 1 {
		if step_player(g, {x - g.x, y - g.y}) {
			describe_arrival(g)
		}
		return
	}
	g.path_len = find_path(f, {g.x, g.y}, {x, y}, &g.path)
	if g.path_len == 0 {
		say(g, "You know no way there.")
	} else if hostile_in_view(g) {
		g.path_len = 1 // with a tenant after you, one step at a time
	}
}

inspect :: proc(g: ^Game, x, y: int) {
	f := floor_of(g)
	if x < 0 || y < 0 || x >= FLOOR_W || y >= FLOOR_H || !f.seen[y][x] {
		say(g, "You have not seen that.")
		return
	}
	if x == g.x && y == g.y {
		say(g, "You. Windswept.")
		return
	}
	if id := tenant_at(g, x, y); id != 0 && g.vis[y][x] {
		inspect_tenant(g, id)
		return
	}
	if id := ground_item_at(g, x, y); id != 0 && g.vis[y][x] {
		say(g, item_name(g, id), ".")
		return
	}
	switch f.cells[y][x] {
	case .Wall:
		say(g, "A wall of the bulwark.")
	case .Floor:
		say(g, "Floor.")
	case .Stairs_Up:
		say(g, "Stairs up.")
	case .Stairs_Down:
		say(g, "Stairs down.")
	case .Building:
		say(g, "A house of the town.")
	case .Door:
		s := shop_at(x, y)
		say(g, SHOP[s].title, ".")
	}
}

// Called once per frame by the platform; walks a mouse route. True when something changed.
tick :: proc(g: ^Game) -> bool {
	if g.path_i >= g.path_len {
		return false
	}
	g.travel_wait += 1
	if g.travel_wait < TRAVEL_FRAMES {
		return false
	}
	g.travel_wait = 0
	if g.path_i > 0 && hostile_in_view(g) {
		stop_travel(g)
		return true
	}
	next := g.path[g.path_i]
	g.path_i += 1
	d := next - [2]int{g.x, g.y}
	if abs(d.x) > 1 || abs(d.y) > 1 || !step_player(g, d) {
		stop_travel(g)
		return true
	}
	if g.path_i >= g.path_len {
		stop_travel(g)
		describe_arrival(g)
	}
	return true
}
