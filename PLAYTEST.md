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

Add `-define:BOT_DEBUG=true` to print where and why a climb wedges (round 4).

## Decided with the user (November 12, 2026)

1. **Dexterity:** halved: 2 % to land a blow and 1 % off being hit per point above 10 (was 4 % and 2 %).
2. **Blight:** left as it is (3 to 6 damage, it can kill): the identification lesson stands.
3. **Anchoring:** starts at 75 % of the load limit (was 60 %); being anchored still slows you.
4. **Light:** left as it is; torches are sold in town.
5. **Money:** Jools weigh 50 g each (was 10 g). The purse (6 kg) then holds 120; more goes in the pack.
6. **The skeleton:** back to health 20 and damage 1 to 5 (from the step 9 easing to 14 and 1 to 4).
7. **Interface:** a line said again straight away shows once with a count ("A wall. (x4)") instead of filling the log. The herald stays where it is, the log stays four lines, and clicks on unexplored ground stay as they are.

Not yet built; once built, the bot is to run again to check the effect.

## Round 2: after the changes (November 12, 2026)

All five changes are built: Dexterity halved (`DEX_AIM` 2, `DEX_DODGE` 1), anchoring at 75 %, Jools 50 g each, the skeleton back to 20 health and 1 to 5 damage, and a repeated one-line message shown once with a count ("A wall. (x4)"). The save version went up to 2, so a climber saved before this starts over. 97 native tests pass. The same bot ran 100 climbs per build again, first as before (it picks things up to 90 % of its limit), then stopping at 74 %, just under the new anchoring line.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| **Bot loads to 90 %** | | | | |
| Got the key | 99 % | 100 % | 100 % | 90 % |
| Climbs with a death (round 1) | 37 % (32 %) | 9 % (5 %) | 10 % (0 %) | 20 % (10 %) |
| Deaths on floor 4 (round 1) | 9 (0) | 0 (0) | 3 (0) | 8 (0) |
| Main killers | kobold 18, bad potion 10, the Horde 6, spider 5 | kobold 4, spider 2 | kobold 4, the Horde 3, bad potion 2 | kobold 7, the Horde 7, bad potion 4 |
| Turn the key was taken | 2256 | 1410 | 2262 | 2843 |
| Turns anchored | 1871 | 704 | 1927 | 3553 |
| Jools at the end (round 1) | 77 (157) | 140 (161) | 85 (156) | 53 (143) |
| Ran out of torches | 89 % | 5 % | 95 % | 99 % |
| **Bot stops at 74 %** | | | | |
| Got the key | 92 % | 99 % | 99 % | 82 % |
| Climbs with a death | 62 % | 21 % | 29 % | 70 % |
| Turn the key was taken | 1488 | 1146 | 1303 | 1630 |
| Turns anchored | 1007 | 26 | 265 | 1521 |
| Turns starving | 776 | 0 | 102 | 1737 |
| Ran out of torches | 51 % | 10 % | 33 % | 78 % |

What it shows:

- **Dexterity is no longer the one right answer.** Nimble (Dx 16) now dies about as often as the Fighter (10 % and 9 %). Strength and Constitution matter again.
- **The skeleton is a boss again.** It killed 18 times in these 400 climbs (none before), mostly the Even and Caster builds. Kobolds stay the deadliest tenant, and Blight still kills.
- **Raising anchoring to 75 % barely helps a player who picks everything up.** The bot still loads to 90 % and is anchored most of the climb. Heavy Jools add to the load: the bot leaves more coin behind (77 at the end, down from 157).
- **There is little room under the line.** The starting kit is now 10.1 kg (its 25 Jools weigh 1.25 kg), and the line at Strength 10 is 15 kg. A player who stays under it moves faster (about 1500 turns instead of 2250) and runs out of light less often. But this bot then left food and potions behind and starved and died far more. That is partly the bot (it does not choose what to leave), but it shows how tight the load is at Strength 10 and below.
- **Light still runs out for most players who carry a lot**, as before (left as it is, by decision).

Open for discussion: whether the load (kit weight, Jools weight, the 75 % line, Strength's carry limit) needs another look now that coin is heavy. Nothing else was changed.

## Round 3: more carry per Strength (November 12, 2026)

Decided with the user: **2.5 kg of load limit per point of Strength** (was 2 kg), so Strength 10 carries 25 kg and anchoring starts at 18.75 kg. With the 10.1 kg kit, that leaves about 8.5 kg of room before you are anchored, where there was 5. The bot now also checks that a thing fits in its containers before going for it: with the bigger limit, the Fighter's pack filled before its load did.

| Bot loads to 90 % | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Got the key (round 2) | 99 % (99 %) | 77 % (100 %), 23 bot wedges | 100 % (100 %) | 96 % (90 %) |
| Turn the key was taken (round 2) | 1657 (2256) | 1161 (1410) | 1608 (2262) | 2230 (2843) |
| Climbs with a death (round 2) | 42 % (37 %) | 18 % (9 %) | 9 % (10 %) | 22 % (20 %) |
| Turns anchored (round 2) | 1027 (1871) | 195 (704) | 1040 (1927) | 2046 (3553) |
| Ran out of torches (round 2) | 42 % (89 %) | 6 % (5 %) | 26 % (95 %) | 84 % (99 %) |
| Turns starving (round 2) | 0 (0) | 0 (0) | 0 (0) | 173 (758) |
| Jools at the end (round 2) | 109 (77) | 146 (140) | 121 (85) | 82 (53) |

What it shows:

- **Climbs are about a quarter shorter and anchoring roughly halves**, even for a bot that picks everything up. Running out of light drops from most climbs to under half (Even 42 %, Nimble 26 %); the Caster still struggles (Strength 8 carries 20 kg).
- **Deaths moved little.** Even dies in 42 % of climbs, Nimble in 9 %, the Caster in 22 %. Kobolds, Blight and the skeleton are the main killers.
- **The Fighter's 23 wedged climbs are a bot fault, not yet traced.** It stops making progress somewhere on floors 2 and 3 with a big load. Nothing points to a game bug, but it has not been ruled out.
- **The 74 % variant** (the bot stops just under the anchoring line) was run too. It is faster (1100 to 1300 turns) and rarely anchored, but it leaves food and potions behind, so it starves and dies much more (Even 70 % of climbs). As in round 2, that is mostly the bot not choosing what to leave.

Nothing else was changed.

## Round 4: the bot wedge traced (November 12, 2026)

The bot now prints its state when it wedges (`-define:BOT_DEBUG=true`). In round 3, 26 climbs wedged across the four builds (23 Fighter, 1 Even, 2 Caster). Round 3 said these were on floors 2 and 3, but most were on floor 4, on the cell where the skeleton fell. **Every one was a bot fault**, of two kinds:

- **Piles.** Enter takes only the top thing on a cell. When that thing would not fit (the Skull over the Key, more Jools than the purse holds), the bot pressed Enter for ever. A player opens the inventory's ground pane and takes what they want from under it. The bot now picks a chosen thing from the pile (the key first). For that, the game's pick-up was split into `pick_up(g, id)`, with `get_here` calling it for the top thing; play is unchanged.
- **No room, by bulk and count.** In two climbs the top of a pile was a heavy heap of Jools that took the bot past its limit, and it could not move. In three, the Key itself would not fit: the pack (12 kg) and the belt's four slots were full, though the bot carried only 27 of its 35 kg. A player drops something. The bot now drops its heaviest trophy when it cannot move, or to make room for the key.

After the fix, no climb wedges and every build takes the key in all 100 climbs. The bot also sheds trophies now, so climbs are a little quicker and less anchored than in round 3. Deaths are the same.

| Bot loads to 90 % | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Got the key (round 3) | 100 % (99 %) | 100 % (77 %) | 100 % (100 %) | 100 % (96 %) |
| Turn the key was taken (round 3) | 1594 (1657) | 1161 (1161) | 1571 (1608) | 2035 (2230) |
| Climbs with a death (round 3) | 42 % (42 %) | 18 % (18 %) | 9 % (9 %) | 22 % (22 %) |
| Turns anchored (round 3) | 970 (1027) | 191 (195) | 1002 (1040) | 1674 (2046) |
| Ran out of torches (round 3) | 37 % (42 %) | 6 % (6 %) | 24 % (26 %) | 82 % (84 %) |

Killers over the 400 climbs: kobolds 45, unknown potions 25, the skeleton 15, spiders 9, everything else 10.

Two things from this for discussion (nothing in the game was changed):

- **The Key is hidden under the Skull.** The skeleton drops the Key first and the Skull on top of it. Standing there you see a skull, and the log says "Here: Skull." The slice's goal lies underneath, and nothing says so. If yer bags are full you are told "No room to carry Skull." and you might walk off. Options: drop the Key on top, say "and more" when a pile has more than one thing, or have Enter take the first thing that fits.
- **For strong builds, the pack is the real limit, not Strength.** From round 3, Strength carries 2.5 kg a point (35 kg at 14). But the pack holds 12 kg and the belt four small things, so a Fighter fills its bags around 26 kg and never reaches its limit. Strength above about 12 then adds nothing to carrying (it still adds to damage). A bigger pack from the general store would be one way to let it count.
