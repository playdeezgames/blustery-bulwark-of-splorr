# Blustery Bulwark of SPLORR!! — Playtest round 1 (slice 1)

November 11, 2026. Findings for the user to discuss; **nothing in the game was changed because of them.** The numbers come from 400 climbs by an autoplay bot, plus a short session by hand in the browser on the live Pages build.

## How it was tested

- **The bot** (`src/game/playtest_test.odin`, run with `-define:PLAYTEST=true`; see the end of this file) plays like a careful climber who only fights in melee:
  - It explores each floor toward the nearest unexplored edge and picks up anything worthwhile while its load stays under 90 % of the limit.
  - It wields the best weapon it finds, eats when Hungry and rests when below half health.
  - It relights its torch, climbs once a floor is explored, pays the carny on floor 4 and fights the skeleton.
  - When below a third of its health in a fight, it drinks a known healing potion, or gambles on an unknown one.
  - After a fall it buys bread and torches in town, mends its weapon and sells trophies.
  - It learns Mend as its second spell and casts nothing else. It never goes back to town on purpose, never banks, and never uses the carny's ring toss.
- **Four builds**, 100 climbs each, a different seed each climb:
  - **Even:** every attribute 10.
  - **Fighter:** St 14, Dx 12, In 6, Co 14.
  - **Nimble:** Dx 16, Co 12, In 8.
  - **Caster:** In 16, Co 12, St 8.
- **By hand:** creating a character, the town, the gate, floor 1, the map, picking up a potion, mouse routes and saving across a reload.

## The numbers

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Got the key | 99 % | 96 % (4 bot wedges) | 100 % | 91 % (9 ran out of turns) |
| Turn the key was taken (average) | 2100 | 1336 | 2139 | 2762 |
| Climbs with at least one death | 32 % | 5 % | 0 % | 10 % |
| Deaths, by floor (1 / 2 / 3 / 4) | 1 / 22 / 12 / 0 | 0 / 1 / 4 / 0 | none | 0 / 6 / 4 / 0 |
| What killed them | bad potion 16, spider 8, kobold 8, slime 1, beetle 1, the wind 1 | kobold 3, bad potion 2 | none | kobold 6, spider 3, bad potion 1 |
| Turns on floors 1 / 2 / 3 / 4 | 356 / 383 / 479 / 126 | 332 / 355 / 389 / 16 | 332 / 355 / 471 / 116 | 344 / 415 / 626 / 558 |
| Level at the end; kills | 4.3; 24.5 | 4.3; 24.6 | 4.3; 24.6 | 4.3; 24.4 |
| Jools at the end; spent | 157; 5 | 161; 5 | 156; 5 | 143; 5 |
| Heaviest load (limit) | 18.1 kg (20) | 20.7 kg (28) | 18.2 kg (20) | 14.6 kg (16) |
| Turns slowed by an anchoring load | 1961 | 671 | 1950 | 3558 |
| Turns in the dark; climbs that ran out of torches | 591; 79 % | 92; 3 % | 552; 76 % | 2087; 98 % |
| Turns Hungry; Starving | 7; 81 | 3; 0 | 8; 0 | 20; 752 |

Combat duels from step 9 (melee only, starting kit) still hold. Rats, beetles, slimes and spiders cost 1 to 4 health. A kobold or a carny costs about 8 of 20. The eased skeleton costs about 9 to 10, and a level-1 climber wins 91 % of the time.

## Findings, most important first

1. **Dexterity is worth far more than anything else.** Nimble (Dx 16) never died in 100 climbs; Even (all 10s) died in 32 of them.
   - Each point of Dexterity adds 4 % to land a blow and takes 2 % off being hit. At 16 that is +24 % and −12 %.
   - Strength adds damage only every 3 points (+2 at 16). Its real value is the carry limit (see 3).
   - Constitution adds 2 health a point.
   - Point-buy therefore has one right answer for fighting. A player who spends evenly is several times likelier to die.
2. **Unknown potions are the biggest killer of a careful player.** "A bad potion" killed 16 of the Even build's 35 deaths, more than any tenant.
   - One unknown potion in four is Blight (3 to 6 damage).
   - The natural moment to gamble on one is when you are nearly dead. Blight then finishes you.
   - That may be the intended identification lesson ("all of it", hard but fair), or too punishing for the first floors.
3. **Anchoring slows almost everyone, almost all the time, and switches the wind off.** A load over 60 % of the limit anchors you: gusts cannot push you, and you take two turns a step.
   - The bot carried up to 90 % and was anchored for 1961 of the Even build's ~2100 turns. The Fighter (limit 28 kg) only for 671.
   - The bot hoards more than many players would. Even so, the starting kit is 9.1 kg, so at Strength 10 picking up about 3 kg anchors you.
   - Two effects follow:
     - The push, the game's signature mechanic, mostly disappears for a player carrying loot.
     - Turns double, which drains torches and food (see 4).
   - At Strength 8 the starting kit alone is 57 % of the limit. The Caster was anchored 3558 turns, went 752 turns starving and spent 2087 in the dark.
4. **Torches run out for most players; food mostly does not.** 79 % of Even climbs ran out of torches and spent about 600 turns in the dark.
   - Supply: you start with three torches (900 turns) and each floor adds one.
   - Use: a climb is about 2100 turns, or about 1350 when you are not slowed.
   - Bread is ample: about 3 eaten a climb, hardly any hungry turns, except for the slow Caster.
   - Whether the dark should be this common is a design call. It ties to finding 3, since slowness burns light.
5. **Money has almost nothing to do.** Climbers end the slice with about 150 Jools and spend 5 (the bot shops only after a fall, and a careful player rarely falls).
   - Jools weigh 10 g each, so 150 is 1.5 kg: not yet the "heavy Jools, the bank matters" pressure the design describes.
   - Prices are low against what the floors give (3 to 5 piles a floor, of up to 10, 20 or 30 Jools on floors 1, 2 and 3, plus trophies).
   - The town economy will likely matter only once players return to town on purpose, or prices go up.
6. **The skeleton is no longer a threat.** No build died on floor 4 in 400 climbs.
   - Climbers reach it at level 4 or so, after about 24 kills.
   - Floor 4 took 16 to 126 turns (558 for the slow Caster).
   - The admission carny and the toppling bones play out as intended.
   - The real danger of the slice sits on floors 2 and 3: kobolds and spiders. You chose the easing in step 9; this is a data point for that choice.
7. **Levels and pacing look right for the slice.** Everyone ends at level 4 (the plan said "levels 1 to about 4"). The floors take 330 to 480 turns each. The whole slice is about 1300 to 2100 turns.
8. **Kobolds are the most dangerous tenant**: 17 of the 50 deaths, and the most dangerous tenant for every build that died. They reach floor 2 with health 8, damage 1 to 5 and to-hit 55. Spiders are next, at 11 deaths.

### Things noticed by hand (interface)

9. **The herald stands in the middle of the street, in line with the gate.** Walking straight between the gate and the shops crosses the herald's spot, and each crossing adds "The herald. Enter/OK to listen." to the log.
10. **Bumping a wall repeats "A wall."** Four bumps fill the whole four-line log and push out the lines that matter. A repeated line could show once, with a count.
11. **The log is short for fights.** In a crowd, the tenants' lines push the player's own out, as noted in step 4.
12. **A click on unexplored ground says "You know no way there."** That is correct, but a mouse player may expect to walk toward it. Routes only cross cells already seen.

### Not covered

- Spells in combat: the bot casts only Mend.
- Gamepad and touch on real devices.
- Returning to town on purpose, the bank, the sage and temple prices in practice, and the carny's ring toss.
- Identification by Identify scrolls versus the sage.
- The bot can wedge itself (4 Fighter climbs) or run out of turns (9 slow Caster climbs). Those are bot limits, not game bugs, as far as can be told.

## Questions for the discussion

1. Should Dexterity be reined in (smaller per-point bonuses), or should Strength and Constitution give more?
2. Is a lethal Blight potion at low health the right lesson, or should Blight be milder (say 1 to 3), or never kill?
3. Should anchoring start higher (say 75 %), or not slow you, or should the starting kit be lighter?
4. Is running out of light this often wanted? Options: more torches on the floors, or a longer burn.
5. Should money matter more: dearer town prices, heavier Jools, fewer Jools on the floors?
6. Should the skeleton come back up a little, given that no build died there?
7. Which interface items (9 to 12) to fix?

## Running it again

```
odin build src/game -build-mode:test -collection:tggd=src -o:speed -define:PLAYTEST=true -define:PLAYTEST_RUNS=100 -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.test_playtest -define:ODIN_TEST_TRACK_MEMORY=false -out:/tmp/pt && /tmp/pt
```

Build the binary and run it. Through `odin test`, the memory tracking makes it far slower. 400 climbs take about four minutes.
