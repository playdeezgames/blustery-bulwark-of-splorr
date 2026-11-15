#+build !js
package game

// The wind study (November 15, 2026, at the user's request): what the wind does to aiming. Run
// with -define:WIND_AIM=true. In an open room with the wind from each of the eight directions, a
// tenant stands where a straight magic bolt aimed at it would hit in a calm (on one of the eight
// lines, within the bolt's calm range). For each spot it prints how often the bolt aimed straight
// at it still hits, and how often some other of the eight directions would hit it instead (the
// choice the wind is meant to create). Without the define it does nothing.

import "core:fmt"
import "core:testing"

_ :: fmt

WIND_AIM :: #config(WIND_AIM, false)

@(test)
test_wind_aim_study :: proc(t: ^testing.T) {
	when WIND_AIM {
		g := open_room()
		defer free(g)
		f := floor_of(g)
		total, straight_hits, other_hits, no_hit := 0, 0, 0, 0
		by_dist: [BOLT_RANGE + 1][2]int // [distance] = {cases, straight hits}
		// Where a bolt aimed `d` from (px, py) first meets something, with the floor's wind.
		lands :: proc(g: ^Game, d: [2]int, target: [2]int) -> bool {
			f := floor_of(g)
			w := wind_blow(f)
			along := w == d || w == -d
			reach := BOLT_RANGE + d.x * w.x + d.y * w.y
			pos := [2]int{g.x, g.y}
			for step in 1 ..= max(1, reach) {
				pos += d
				if pos == target {
					return true
				}
				if !along && step % BOLT_DRIFT == 0 {
					pos += w
					if pos == target {
						return true
					}
				}
			}
			return false
		}
		for wind in 0 ..< len(DIRECTIONS) {
			f.wind_from = wind
			for d in DIRECTIONS {
				for dist in 1 ..= BOLT_RANGE {
					target := [2]int{g.x, g.y} + dist * d
					total += 1
					by_dist[dist][0] += 1
					if lands(g, d, target) {
						straight_hits += 1
						by_dist[dist][1] += 1
						continue
					}
					found := false
					for e in DIRECTIONS {
						if e != d && lands(g, e, target) {
							found = true
						}
					}
					if found {
						other_hits += 1
					} else {
						no_hit += 1
					}
				}
			}
		}
		// Every cell within the bolt's calm range (a square), on a line or not: which can some bolt hit
		// in a calm, and which with the wind?
		calm_cells, wind_cells, both, wind_only, calm_only := 0, 0, 0, 0, 0
		for wind in 0 ..< len(DIRECTIONS) {
			for dy in -BOLT_RANGE ..= BOLT_RANGE {
				for dx in -BOLT_RANGE ..= BOLT_RANGE {
					if dx == 0 && dy == 0 {
						continue
					}
					target := [2]int{g.x + dx, g.y + dy}
					calm := (dx == 0 || dy == 0 || abs(dx) == abs(dy))
					f.wind_from = wind
					windy := false
					for e in DIRECTIONS {
						if lands(g, e, target) {
							windy = true
						}
					}
					calm_cells += calm ? 1 : 0
					wind_cells += windy ? 1 : 0
					if calm && windy {
						both += 1
					} else if windy {
						wind_only += 1
					} else if calm {
						calm_only += 1
					}
				}
			}
		}
		fmt.printfln("\nevery cell within %d (8 winds): a calm bolt reaches %d a wind, the wind reaches %d a wind", BOLT_RANGE, calm_cells / 8, wind_cells / 8)
		fmt.printfln("  reachable either way %d, only with the wind %d, only in a calm %d (a wind)", both / 8, wind_only / 8, calm_only / 8)
		fmt.printfln("\nwind and aiming: %d spots a calm bolt would hit (8 winds x 8 lines x 1..%d cells)", total, BOLT_RANGE)
		fmt.printfln("aimed straight, still hits: %d%%", straight_hits * 100 / total)
		fmt.printfln("misses straight, another direction hits: %d%%", other_hits * 100 / total)
		fmt.printfln("no direction hits: %d%%", no_hit * 100 / total)
		for dist in 1 ..= BOLT_RANGE {
			fmt.printfln("  %d cells away: straight hits %d%%", dist, by_dist[dist][1] * 100 / by_dist[dist][0])
		}
	}
}
