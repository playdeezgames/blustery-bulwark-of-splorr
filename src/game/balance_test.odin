#+build !js
package game

// A first balance pass (slice 1 step 9), run with -define:BALANCE=true: melee duels with the real
// combat rules, the climber at levels 1 to 4 with the starting kit, against every tenant. It prints
// how often you win, the health it costs and how long it takes. Spells, potions and the doorway are
// left out, so these are the hard cases. Without the define it does nothing.

import "core:fmt"
import "core:testing"

_ :: fmt // used only with -define:BALANCE=true

BALANCE :: #config(BALANCE, false)

@(test)
test_balance_duels :: proc(t: ^testing.T) {
	when BALANCE {
		TRIALS :: 2000
		fmt.println("tenant     lvl  win%  hp lost (of max)  turns")
		for kind in Tenant_Kind {
			if kind == .None || TENANT[kind].prop {
				continue
			}
			for level in ([?]int{1, 4, 6, 8}) {
				wins, lost, turns := 0, 0, 0
				hp := 0
				for trial in 0 ..< TRIALS {
					g := new_game(u64(trial * 7919 + level))
					teleport(g, open_spot(g))
					g.level = level
					g.health = max_health(g)
					hp = max_health(g)
					id := new_tenant(g, kind, g.current, g.x + 1, g.y)
					g.tenants[id].awake = true
					g.tenants[id].angry = true
					g.tenants[id].tx, g.tenants[id].ty = i16(g.x), i16(g.y)
					n := 0
					for n < 200 && g.mode != .Dead && g.tenants[id].kind != .None {
						g.gust_in = 1000
						g.items[worn(g, .Light)].fuel = TORCH_TURNS
						if g.tenants[id].x != i16(g.x + 1) || g.tenants[id].y != i16(g.y) {
							break // it wandered off (a bat); count as a draw
						}
						player_attack(g, id)
						n += 1
					}
					if g.tenants[id].kind == .None {
						wins += 1
					}
					lost += hp - max(0, g.health)
					turns += n
					free(g)
				}
				fmt.printfln("%-10s %3d  %4d  %5.1f (of %d)       %5.1f", TENANT[kind].name, level, wins * 100 / TRIALS, f64(lost) / TRIALS, hp, f64(turns) / TRIALS)
			}
		}
	}
}
