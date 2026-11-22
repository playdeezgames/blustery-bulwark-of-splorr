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

### Decided with the user (November 12, 2026)

- **The Key on top.** The skeleton now drops the Skull first and the Key last, so you see the Key where it fell, and one Enter takes it. Tested.
- **A Big pack in the general store.** It holds 20 kg and 40,000 bulk (the Pack holds 12 kg and 25,000), weighs 1.5 kg and costs 100 Jools. The store moves everything from yer pack into it and keeps the old one, and stops offering it once you wear one. Tested. The numbers are Claude's, for review. Saves still load: the new kind is added at the end, so saved kinds keep their numbers and the Game's size is unchanged.

The bot rerun is the same as round 4. The bot never comes back to town with money (it shops only at the start and after a death, which costs it what it carries), so it never buys the Big pack. A player who uses Return, or walks down, can. That is round 1's "money has little use" again.

Found on the way and fixed: the general store's line ("...He breathes a great deal.") needed three lines, and the shop screen had room for two, so the joke lost its last words. The rows now start 8 px lower. There is still room for 13 rows, and every other shop's line fits in two.

## Wind study: does the wind earn its place? (November 15, 2026)

Asked by the user while reviewing step 14: "i dont know that the mechanic of wind blowing is really impactful to game play as assumed. we need some deep testing for it usefulness as a game mechanic and whether to keep it."

### How it was tested

- **The wind can now be switched off part by part**, for testing only (`g.wind_off`, a set of Gusts, Push, Snuff, Blow). Gusts off means no gust at all. The other three switch off one effect each: pushing you, snuffing yer light, and blowing things and tenants around. Play is unchanged. A test checks each switch.
- **The game now counts what the wind does** (`g.wind_seen`): gusts, pushes and cells pushed, slams into walls, gusts yer load held, lights snuffed, things and tenants moved, and pushes that took you into or out of an awake hostile's reach. The bot prints these per climb.
- **The bot climbed floors 1 to 7 fifty times per build in five variants:** the full wind, then each of the four switches. That's 1000 climbs, carrying up to 90 % of the load limit as in earlier rounds.
- **Bolts were studied on their own** (`-define:WIND_AIM=true`, `test_wind_aim_study`). On an open floor, for every wind and every cell within 7, the study checks which cells a bolt can reach in a calm and which with the wind.

### What the wind does in a climb (full wind, per climb)

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Gusts | 788 | 586 | 711 | 838 |
| Gusts yer load held | 688 (87 %) | 491 (84 %) | 651 (92 %) | 756 (90 %) |
| Pushes (cells) | 52 (70) | 50 (54) | 32 (36) | 45 (66) |
| Slams into a wall | 51 | 44 | 28 | 41 |
| Lights snuffed | 107 | 122 | 97 | 96 |
| Things blown | 263 | 140 | 157 | 247 |
| Tenants blown | 911 | 657 | 820 | 1019 |
| Pushed into a hostile's reach (out of it), all 50 climbs | 1 (3) | 1 (1) | 0 (1) | 0 (3) |

### What changes when a part is switched off

Deaths a climb and the turn floor 7's stairs were reached, each build at 50 climbs:

| | Even | Fighter | Nimble | Caster | All four |
|---|---|---|---|---|---|
| **Full wind** | 3.14, 6934 | 0.38, 5122 | 0.88, 6265 | 3.42, 7448 | 1.96, 6442 |
| No gusts at all | 2.72, 6737 | 0.38, 4907 | 0.60, 6101 | 3.38, 7543 | 1.77, 6322 |
| No push | 3.80, 6971 | 0.28, 5034 | 1.04, 6491 | 3.68, 7674 | 2.20, 6543 |
| No snuff | 3.66, 6745 | 0.42, 4993 | 0.90, 6251 | 3.38, 7654 | 2.09, 6411 |
| No blowing | 2.92, 6670 | 0.52, 5181 | 0.92, 6378 | 3.06, 7404 | 1.86, 6408 |

Every build reached floor 7's stairs in every variant, except for one Caster wedge in two variants. The wind killed 7 times in the 200 full-wind climbs, out of 391 deaths.

### Bolts

- **Aimed at a target on one of the eight lines a calm bolt would hit**, a windy bolt still hits 54 % of the time. Aiming another way never hits that target. By distance: 1 to 3 cells always hit; 4 and 5 cells 25 %; 6 cells 18 %; 7 cells 12 %.
- **Over every cell within 7**, averaged over the eight winds, a calm bolt can reach 56 cells and a windy one 58. Only 30 cells are reachable both ways. 28 are reachable only with the wind (off the lines, by aiming upwind and letting it drift), and 25 only in a calm (far cells on the lines).

### The wind against a light load

The variants above carry up to 90 % of the load limit, so the bot is anchored most of the time. To see the wind where it is strongest, the bot also climbed 50 times per build stopping at 74 %, just under the anchoring line, with the full wind and with no gusts:

| Bot stops at 74 % | Even | Fighter | Nimble | Caster | All four |
|---|---|---|---|---|---|
| Deaths a climb, full wind (no gusts) | 5.94 (4.12) | 2.48 (0.92) | 2.68 (1.48) | 5.66 (4.46) | 4.19 (2.75) |
| Turn floor 7's stairs were reached | 4964 (3944) | 5421 (3091) | 4463 (3405) | 4601 (4136) | 4862 (3644) |
| Gusts yer load held | 40 of 556 | 45 of 617 | 59 of 503 | 37 of 510 | 7 % |
| Pushes (cells) | 256 (404) | 215 (338) | 215 (336) | 264 (416) | |
| Slams into a wall | 303 | 394 | 266 | 255 | |
| Pushed into a hostile's reach (out of it), all 50 climbs | 4 (15) | 3 (11) | 3 (12) | 3 (16) | |
| Turns in the dark | 2976 (1996) | 3291 (1033) | 2604 (1591) | 2765 (2354) | |

The wind killed 101 times in these 200 climbs, 12 % of all deaths. In the heavy climbs it was 2 %.

### What it shows

- **The wind is a strong force for a light climber and almost nothing for a heavy one.** Under the anchoring line, gusts push about every second time, the climber slams into a wall about every 16 turns, deaths go up by half (4.19 a climb against 2.75 with no gusts) and climbs take a third longer. Over the line, the load holds about 87 % of gusts, and no switch moves deaths or turns beyond the noise (1.77 to 2.20 deaths a climb, turns within 2 %; switching the push off even gave *more* deaths).
- **So the wind's real job is the load trade-off, and it does that job.** Being heavy is the bulwark: slower and anchored, but the wind can't touch you. Being light is faster, but the wind batters you. Without gusts a light climber is both faster (3644 turns against 6322) and only a little more deadly (2.75 against 1.77). With gusts the light climber is still faster (4862 against 6442) but dies more than twice as often (4.19 against 1.96). The light climber also leaves food and potions behind (rounds 2 and 3), which adds to its deaths with or without wind.
- **But the trade-off is lopsided now.** A player who picks things up crosses the line early (the bot is anchored from floor 1) and never meets the wind again except as messages. Anyone who plays like the 90 % bot, which is most players who loot, would rightly feel the wind does nothing. That matches the user's sense of it.
- **Snuffing hardly matters, because the light runs out anyway.** Every build runs out of torches by floor 7 in every variant. Snuffs add a few hundred turns of dark.
- **Blowing is busy but harmless.** Hundreds of tenants and things shift each climb, and it changes nothing measurable. A push into a hostile's reach is rare (about 3 in 50 light climbs, 1 in 50 heavy). Pushes out of reach are four times as common, which helps a wind-blind bot as often as it hurts.
- **Bolts are where the wind matters for everyone.** It doesn't weaken bolts overall. It reshapes where they reach: far targets on the line become unreliable, and off-line cells open up for a player who knows the drift. There's no preview (by design), so that skill comes from learning the drift.
- **Limits.** The bot is wind-blind: it never waits out a gust, casts Anchor or Calm, aims with the wind, keeps away from walls, or uses a gust to escape. A wind-aware light climber would take fewer slams than these numbers show. A heavy one would gain little either way, because the wind barely reaches them.

To run the study again, add `-define:NO_GUSTS=true`, `NO_PUSH`, `NO_SNUFF` or `NO_BLOW` to the build in "Running it again", and `-define:BOT_LOAD=74` for the light climber. The bolt study runs with `-define:WIND_AIM=true -define:ODIN_TEST_NAMES=game.test_wind_aim_study`.

Nothing in the game's rules was changed by the study itself.

### Decided with the user: make the wind reach heavy climbers (November 15, 2026)

**Built:** a heavy load (75 % of the limit or more) no longer always holds you. It holds against 60 gusts in 100 on floor 1, falling by 5 a floor to 25 on floor 8 (`LOAD_HOLD`). A gust it doesn't hold still drags against the load: it moves you one cell less, but at least one ("A gust drags you and yer load E."). A slam into a wall still costs a point. The Anchor spell still holds fully, and a light climber is pushed as before. The numbers are Claude's, for review. A test checks holds, drags and the light push. 128 tests. Saves are unchanged.

The same bots ran again, 50 climbs per build:

| | Even | Fighter | Nimble | Caster | All four |
|---|---|---|---|---|---|
| **Heavy (90 %)**: deaths a climb, new rule (old rule, no gusts) | 4.92 (3.14, 2.72) | 0.76 (0.38, 0.38) | 1.68 (0.88, 0.60) | 4.86 (3.42, 3.38) | 3.06 (1.96, 1.77) |
| Turn floor 7's stairs were reached | 7146 (6934, 6737) | 5555 (5122, 4907) | 6814 (6265, 6101) | 8018 (7448, 7543) | 6883 (6442, 6322) |
| Gusts the load held | 253 of 810 | 184 of 637 | 257 of 776 | 309 of 904 | 32 % (was 87 %) |
| Pushes (cells), slams | 317 (347), 247 | 248 (254), 207 | 292 (301), 229 | 342 (368), 259 | |
| **Light (74 %)**: deaths a climb, new rule (old rule) | 6.06 (5.94) | 2.64 (2.48) | 2.80 (2.68) | 5.44 (5.66) | 4.24 (4.19) |
| Turn floor 7's stairs were reached | 5113 (4964) | 5433 (5421) | 4478 (4463) | 4587 (4601) | 4903 (4862) |

The wind killed 36 times in the 200 heavy climbs (7 before) and 104 in the light ones (101 before).

What it shows:

- **The wind now reaches heavy climbers.** Their deaths rise from 1.96 to 3.06 a climb, and climbs take 7 % longer. Before, switching gusts off moved heavy deaths by 0.2; now the wind accounts for 1.3.
- **The trade-off is still there.** Light climbs are unchanged, and light is still faster (4903 turns against 6883) and deadlier (4.24 against 3.06).
- **It's a real difficulty rise, mostly from walls.** A heavy climber slams into a wall about every 30 turns, for a point each. That's chip damage, and with tenants it turns into deaths: the wind itself is named in only 36 of about 600 heavy deaths. The wind-blind bot walks corridors through gust warnings; a player who steps off a wall during the two-turn warning takes far fewer slams. If it is too harsh, the gentlest fixes are to let a drag that meets a wall cost nothing, or to raise `LOAD_HOLD`.
- **Not changed:** snuffing (the light runs out anyway) and blowing things and tenants about.

Kept as built (the user, November 15, 2026).

## Round 5: slice 2, floors 1 to 8 (November 16, 2026)

Slice 2 step 16. The bot now climbs the whole of slice 2: a climb is done when it takes the key to floor 9 from the sergeant. As the plan asked, it now also **goes back to town** to shop:

- **Spells:** it learns Mend first and Return second.
- **When it goes back:** it casts Return when its bags are nearly full and it carries 40 Jools' worth of trophies, or when its light or food is about to run out and it has 20 Jools' worth of coin and trophies. It waits at least 600 turns between trips.
- **In town:**
  - It sells its trophies.
  - It buys food (up to three), torches (two spares) and the Big pack, as before.
  - Once the Horde is gone, it buys a lantern and keeps three flasks of oil.
  - Once healing potions are named, it keeps two.
- **Back up:** it rides the windchute to the highest stop.
- **Floor 8:** it pays the carny, or shoves past when short of coin. It hunts the sergeant even when it can't see it.

Bot faults found and fixed on the way (the game is unchanged):

- With a dry lantern and no oil, it pressed Enter for ever. It now puts the lantern away and lights a torch.
- It walked to floor 8's stairs without fighting the sergeant, because it only chases tenants it can see.
- A cave bear drained one Strength so low that it couldn't move and found nothing it would drop. It now drops its heaviest armour as a last resort.

Fifty climbs per build, carrying up to 90 % of the load limit as before (and, in brackets, stopping at 74 %):

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Took the key to floor 9 | 100 % (100 %) | 100 % (100 %) | 100 % (100 %) | 100 % (100 %) |
| Turn it was taken | 7201 (5653) | 5332 (6526) | 6226 (5122) | 9050 (5245) |
| Deaths a climb | 5.84 (8.36) | 1.12 (3.44) | 1.94 (3.32) | 7.76 (7.62) |
| Of them on floors 1 to 4, 5 to 7, 8 | 0.7, 3.9, 1.3 | 0.1, 0.6, 0.4 | 0.1, 1.1, 0.7 | 0.5, 5.4, 1.3 |
| Trips to town by Return | 6.9 (5.9) | 3.9 (4.4) | 4.9 (4.5) | 10.4 (6.5) |
| Jools spent in town | 370 (303) | 313 (303) | 276 (228) | 434 (266) |
| Jools at the end | 21 (9) | 86 (53) | 26 (18) | 9 (7) |
| Lantern bought | 100 % | 100 % | 96 % | 74 % |
| Turns in the dark | 912 (1337) | 527 (1791) | 542 (1178) | 1806 (1255) |
| Turns starving | 0 (12) | 6 (34) | 29 (37) | 3 (0) |
| Turns on floor 8 | 141 (196) | 100 (279) | 112 (135) | 162 (179) |

Killers over the 200 heavy climbs: goblins 173, cave bears 123, giant ants 112, rats 96, the sergeant 84, kobolds 66, spiders 36, the wind 35, unknown potions 28, crows 21, the skeleton 11, slimes 10, the rest 11.

What it shows:

- **Every build finishes slice 2.** No climb wedges and none runs out of turns. For the weaker builds that is because a death costs little: you wake in town and keep yer things.
- **The town matters now.** The bot goes back 4 to 10 times a climb and spends nearly everything it finds (276 to 434 Jools). In round 1 money had little use; now it ends with 7 to 86 Jools. Food and light stop being the clocks they were: starving falls from hundreds of turns a climb (the wind study) to almost none, and turns in the dark from 2500 to 5400 to 500 to 1800. The light clock still runs out on some climbs. The lantern is the main buy after the Horde.
- **Floors 5 to 7 are where people die.** They hold two thirds of all deaths. Goblins, cave bears and giant ants kill more than everything else together. The Even build dies about 4 times there each climb and the Caster more than 5. The Fighter dies there less than once a climb. The gap between builds is wider than in slice 1.
- **Floor 8 is a short, sharp fight.** It takes 100 to 280 turns and costs about one death a climb for the weaker builds (0.4 for the Fighter). The sergeant itself killed 84 times in 200 climbs.
- **Light climbers have it harder up here.** They are quicker for every build but the Fighter (whose heavy climb is the fastest), but die more: Even 8.4 a climb, Fighter 3.4. The wind killed 117 of them, and 35 heavy climbers.
- **Limits.** The bot still plays blind to the wind and casts only Mend and Return. It never uses Gale, gust balls, Calm or Blink, never banks, and never waits for a better moment. It never retreats from a fight. A player who does these things will die far less, most of all on floors 5 to 8.

Open for discussion (nothing in the rules was changed):

1. **Floors 5 to 7 may be too hard for weaker builds.** For the Even and Caster builds, goblins (12 health, 2 to 6), cave bears (26 health, 3 to 8) and ants in threes add up. This could be fine (deaths cost little), or one of these could be eased.
2. **The sergeant** (health 24, 2 to 5, 60 to hit) killed more than the Horde ever did. That fits a second boss, but it's for the user to judge.
3. **Light:** even with a lantern and town trips, the light still runs out on most climbs at some point (44 % to 98 %), though only for a few hundred turns now.

### Round 5 with spells (November 16, 2026)

On finding 1 (floors 5 to 7 for weaker builds), the user asked first to "make the bot use spells".

**What the bot casts now.** It learns Mend, Return, Magic Bolt, Ward, Gale and Gust Ball, in that order of choice. It always keeps the mana Return needs. In a fight:

- **Ward** when a hostile is within 4 cells.
- **Gale** when two or more hostiles are next to it and at least two lie on one line.
- **A gust ball** at a knot of two or more hostiles, if the blast won't catch the bot.
- **A magic bolt** at a hostile it would hit. It aims with the wind's drift, worked out the way the bolt moves, which is more than the old wind-blind bot did. A Caster (Intelligence 14 or more) also bolts tenants that are next to it.

It still doesn't use Calm, Blink or the Sense spells, and doesn't time its moves to the gusts.

Fifty climbs per build. In brackets: round 5 without spells.

| Bot loads to 90 % | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Took the key to floor 9 | 100 % | 100 % | 100 % | 100 % |
| Turn it was taken | 6931 (7201) | 5511 (5332) | 6135 (6226) | 6680 (9050) |
| Deaths a climb | 3.10 (5.84) | 0.92 (1.12) | 1.20 (1.94) | 1.16 (7.76) |
| On floors 5 to 7 | 2.1 (3.9) | 0.4 (0.6) | 0.6 (1.1) | 0.4 (5.4) |
| On floor 8 | 0.7 (1.3) | 0.4 (0.4) | 0.6 (0.7) | 0.6 (1.3) |
| Bolts, wards, gales, gust balls a climb | 43, 31, 0.4, 2.1 | 20, 20, 0.3, 1.0 | 31, 26, 0.4, 1.3 | 103, 35, 0.3, 3.1 |

The light climber (74 %) dies 6.30, 3.56, 2.86 and 2.30 times a climb (Even, Fighter, Nimble, Caster; it was 8.36, 3.44, 3.32 and 7.62). One light Fighter climb ran out of turns; none wedged.

What it shows:

- **Spells change the picture.** The Caster goes from the deadliest build (7.8 deaths a climb) to one of the safest (1.2) and finishes sooner. Even dies about half as often. Floors 5 to 7 now cost the weaker builds 0.4 to 2.1 deaths a climb, against 3.9 to 5.4.
- **The Even build is now the outlier.** Its 10 Intelligence gives it a small mana pool for bolts, and its Strength and Dexterity are only middling. It still dies about 3 times a climb, mostly to goblins (49 of 155 deaths), ants and bears.
- **Floor 8** is the hardest single floor for every build now (0.4 to 0.7 deaths a climb, 55 of 200 to the sergeant).
- **Gale hardly comes up** (under one a climb). The bot casts it only when crowded, and is rarely crowded in a line.

### Decided with the user (November 16, 2026)

1. **Floors 5 to 7:** left as they are. With spells the weaker builds die far less there; the Even build stays the outlier, as a jack of all trades.
2. **The sergeant:** kept as it is.
3. **Light: more oil.** A flask now lasts 900 turns (was 600). Tested. Saves are unchanged; a lantern already lit keeps its oil.

Rerun of the heavy climbs (with spells) after the oil change, 50 per build. In brackets: before the change.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| Turns in the dark | 612 (835) | 671 (681) | 467 (512) | 974 (995) |
| Light ran out at some point | 54 % (62 %) | 76 % (84 %) | 36 % (50 %) | 50 % (58 %) |
| Trips to town | 5.0 (5.6) | 3.7 (3.8) | 4.2 (4.7) | 6.5 (6.6) |
| Deaths a climb | 3.26 (3.10) | 0.86 (0.92) | 1.08 (1.20) | 1.00 (1.16) |

The light lasts longer and the bot goes back to town a little less, but this is a small change. The dark that is left probably comes mostly from torches before the lantern (floors 1 to 4) and from gusts snuffing the light; the bot does not count those apart. Deaths are within the noise.

## Step 17: floors 9 to 11 (November 17, 2026)

50 climbs a build, playing to floor 11's stairs up, with the turn limit raised from 16000 to 24000. Floors 9 to 11 hold slice 2's tenants for now; the new tenants arrive in step 18.

**The first run is not counted.** Nearly every climb ended "stuck" on floor 8. The bot gave up there whenever it was not carrying the key, even after the door was open. The game was right (the door stays open); the bot's check now matches floor 4's.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| reached floor 11 | 100 % | 100 % | 100 % | 100 % |
| reached its stairs up | 66 % | 88 % | 90 % | 100 % |
| ran out of turns | 17 | 6 | 5 | 0 |
| deaths a climb | 9.74 | 4.32 | 4.42 | 2.08 |
| deaths on floors 9, 10, 11 | 64, 88, 158 | 38, 45, 87 | 34, 44, 84 | 16, 15, 22 |
| killed by the wind | 110 | 109 | 80 | 6 |
| killed by hunger | 61 | 43 | 42 | 0 |
| turns on floors 9, 10, 11 | 2967, 3217, 3522 | 2415, 2268, 2373 | 2214, 2288, 2363 | 1250, 1142, 761 |
| spent in town | 839 | 664 | 639 | 376 |

**Findings for the step 17 review:**
1. **The wind is the main killer on floors 9 to 11** for every build but the Caster: wall slams at 1 health each, with a gust every 6 or 7 turns pushing 2 cells. Round 5 found the bot is wind-blind and slams about once every 30 turns. A player who keeps away from walls on the downwind side would slam far less, so this is partly the bot. The Caster's Ward and its kills from range keep its health higher between slams.
2. **Floors 9 to 11 take about three times as long as floors 5 to 7** for the non-casters (2200 to 3500 turns each). That long stay is where hunger and the dark come back: starving 335 to 425 turns a climb, and 1600 to 2500 turns in the dark.
3. **Even is the weakest build again**, at nearly 10 deaths a climb, with a third of its climbs out of turns.

### The bot minds the wind (step 17 review, November 17, 2026)

On the user's word ("Teach the bot the wind"), the bot now minds the wind. On the last turn before a gust it checks whether the push would slam it into a wall or a tenant. If so it steps to a neighbouring cell where it would not; if it is already safe it waits. It does not dodge while fighting something next to it, or when it carries too much to move. A first run left 3 to 14 climbs a build stuck: an overloaded bot kept trying to step aside instead of dropping something. That was fixed before this run. `-define:BOT_WIND=false` gives the old wind-blind bot.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| reached floor 11's stairs up | 96 % (was 66) | 100 % (88) | 100 % (90) | 100 % (100) |
| deaths a climb | 6.68 (was 9.74) | 1.68 (4.32) | 2.36 (4.42) | 1.72 (2.08) |
| deaths on floors 9, 10, 11 | 53, 59, 75 | 9, 7, 23 | 17, 17, 34 | 14, 10, 9 |
| killed by the wind | 38 (was 110) | 14 (109) | 19 (80) | 3 (6) |
| killed by hunger | 15 (was 61) | 7 (43) | 12 (42) | 0 (0) |
| turns on floors 9, 10, 11 | 2113, 1776, 1800 | 1324, 1244, 1156 | 1580, 1496, 1278 | 1309, 1123, 897 |
| stepped aside, waited (a climb) | 280, 506 | 208, 385 | 236, 447 | 205, 430 |

Minding the wind cut the wind's kills by two thirds or more, and halved the time spent on floors 9 to 11. Slams still happen, about 400 to 640 a climb, all floors together: when a gust comes during a fight, when no neighbouring cell is safe, or when the bot is overloaded. The wind is now behind goblins, cave bears and giant ants as a cause of death for every build. Floors 9 to 11 still take about one and a half times as long as floors 5 to 7. Even remains the weakest build by far.

### Decided with the user (November 17, 2026)

1. The wind on floors 9 to 11: the bot learned to mind it (above); the game's numbers are kept.
2. Long floors 9 to 11: kept as they are.
3. The Even build: kept as it is.

## Step 18: the tenants from floor 9 (November 17, 2026)

50 climbs a build, to floor 11's stairs up, with the bot minding the wind. Floors 9 to 11 now hold the ogre, the wisp, the mimic and the draught alongside the older tenants. Changes are against the wind-minding round in step 17.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| reached floor 11's stairs up | 86 % (was 96) | 98 % (100) | 98 % (100) | 100 % (100) |
| deaths a climb | 7.12 (6.68) | 2.56 (1.68) | 2.88 (2.36) | 2.04 (1.72) |
| deaths on floors 9, 10, 11 | 57, 59, 78 | 17, 23, 43 | 26, 27, 38 | 19, 17, 12 |
| killed by an ogre | 44 | 8 | 21 | 16 |
| killed by a draught | 21 | 18 | 15 | 0 |
| killed by a mimic | 3 | 0 | 1 | 0 |
| killed by the wind | 34 | 25 | 21 | 1 |
| turns on floors 9, 10, 11 | 2374, 2026, 1829 | 1661, 1530, 1385 | 1679, 1678, 1417 | 1532, 1302, 935 |

**Findings for the step 18 review:**
1. **The ogre is now the leading killer on floors 9 to 11** for Even (44) and second for the others. That matches its role: meeting plain ogres is meant to set up floor 12's giant.
2. **Draughts kill 15 to 21 times a build for the non-casters.** The bot never casts at a draught because it is not hostile, and it does not step away from one, so it takes every slam. A player who knows "any spell seals it" would spend a Magic Bolt. It is the bot's blind spot, much as the wind was.
3. **Mimics and wisps barely register:** mimics killed 4 climbers in 200 climbs and wisps none. Wisps add a little time in the dark (Even 1739 to 2156 turns).

### The bot seals draughts (step 18 review, November 18, 2026)

On the user's word ("Teach the bot"), the bot now bolts a draught standing next to it when it has the mana for a Magic Bolt (keeping enough for Return). That is what a player who knows "any spell seals it" would do. It sealed 2 to 3 draughts a climb. Changes are against the step 18 round above.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| reached floor 11's stairs up | 94 % (was 86) | 100 % (98) | 98 % (98) | 98 % (100) |
| deaths a climb | 5.94 (7.12) | 2.26 (2.56) | 2.76 (2.88) | 1.90 (2.04) |
| deaths on floors 9, 10, 11 | 51, 46, 55 | 18, 20, 31 | 23, 20, 42 | 18, 15, 9 |
| killed by a draught | 4 (was 21) | 7 (18) | 4 (15) | 0 (0) |
| killed by an ogre | 34 (44) | 6 (8) | 19 (21) | 13 (16) |
| killed by a mimic | 3 | 0 | 1 | 0 |
| killed by the wind | 33 | 23 | 28 | 1 |
| turns on floors 9, 10, 11 | 2064, 1786, 1406 | 1613, 1546, 1359 | 1735, 1596, 1441 | 1481, 1290, 929 |

Sealing draughts took them from 15 to 21 kills a build down to 4 to 7, and the Even build is back near its step 17 figure. The Caster's one miss ran out of turns rather than dying. The ogre stays the leading new killer.

### Decided with the user (November 18, 2026)

1. Draughts: the bot learned to seal them (above); the draught is kept as built.
2. The mimic and the wisp: kept as they are, a surprise and a nuisance rather than killers.
3. The ogre: its numbers are kept (health 30, hits 3 to 9).
4. The four tenants' lines, trophy prices (tooth 12, glass 8, hinge 10) and pictures: approved.

## Step 19: the deep camps, the cartographer and the pack of holding (November 18, 2026)

50 climbs a build, to floor 11's stairs up, with the bot minding the wind and sealing draughts. Floors 9 to 11 now hold camps with a war hammer, a pack of holding and scale mail, and floor 10's cartographer. The bot picks up gear as before: it wields the war hammer, since it hits hardest, but takes the scale mail only when it wears no armour, and it does not buy maps or wear the pack of holding yet (step 23). Changes are against the step 18 review round.

A first run left one Even climb stuck on floor 11: a cave bear had drained its Strength until its limit was 7.5 kg, and it carried 7.95 kg with nothing loose left to drop and no armour on, only the 5 kg war hammer in hand. The bot only ever dropped loose things or worn armour; it now drops the heaviest worn thing that is not a container. A bot fault; the game is unchanged.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| reached floor 11's stairs up | 100 % (was 94) | 100 % (100) | 100 % (98) | 98 % (98) |
| deaths a climb | 5.60 (5.94) | 1.92 (2.26) | 2.24 (2.76) | 1.94 (1.90) |
| deaths on floors 9, 10, 11 | 45, 48, 47 | 12, 12, 30 | 18, 17, 25 | 17, 16, 12 |
| killed by an ogre | 35 (34) | 5 (6) | 12 (19) | 11 (13) |
| killed by a draught | 5 (4) | 6 (7) | 3 (4) | 1 (0) |
| killed by the wind | 23 (33) | 21 (23) | 17 (28) | 3 (1) |
| turns on floors 9, 10, 11 | 1841, 1534, 1278 | 1509, 1354, 1289 | 1663, 1385, 1256 | 1386, 1226, 815 |

Every build but the Caster dies a little less on floors 9 to 11, most likely from the war hammer, though the change is small enough to be partly chance. The Caster's one miss ran out of turns. Nothing new kills anybody: the cartographer never moves and never fights.

### Decided with the user (November 18, 2026)

Step 19 is kept as built: the camp gear's numbers, the pack of holding's limits, the new lines and the pictures. The game is unchanged by the review.

## Step 22: floor 12, the giant (November 19, 2026)

50 climbs a build. Floor 11's stairs up now climb to floor 12, but the bot's climb still ends there (`BOT_TOP` in `playtest_test.odin`), since it does not yet know how to knock the giant off its crate (step 23). The figures are those of steps 19 and 21 to the last digit: 100, 100, 100 and 98 % reach floor 11's stairs up, with 5.60, 1.92, 2.24 and 1.94 deaths a climb. Building floor 12 draws no random numbers before you arrive, so nothing earlier moved.

## Round 6: all of slice 3 (step 23, November 19, 2026)

50 climbs a build, done when the bot takes the key to floor 13 (24,000 turns at most). On floor 12 the bot knocks the giant off its crate with a gale, a squall or a gust ball when it can, otherwise waits 3 cells off, downwind, for a gust to tip the crate; then it runs for the crate when it will get there first, and fights the giant next to it. It now also learns and casts Squall and buys or wears a pack of holding. A first try waited 5 cells upwind and spent up to 716 turns a climb waiting, the giant climbing back before the bot reached the crate.

| | Even | Fighter | Nimble | Caster |
|---|---|---|---|---|
| took the key to floor 13 | 96 % (2 out of turns) | 98 % (1) | 100 % | 98 % (1) |
| turn the key was taken (avg) | 14830 | 12472 | 13950 | 14301 |
| deaths a climb | 5.60 | 2.12 | 2.62 | 2.02 |
| deaths on floors 9, 10, 11, 12 | 50, 44, 50, 7 | 20, 13, 26, 1 | 22, 16, 33, 9 | 19, 12, 12, 3 |
| killed by the Giant | 7 | 1 | 9 | 3 |
| turns on floor 12 (avg) | 98 | 98 | 98 | 89 |
| giant knocked off by a spell, a climb | 1.1 | 0.6 | 0.8 | 1.2 |
| turns waited for a gust, a climb | 14.8 | 29.6 | 12.5 | 9.6 |
| crate carried off, a climb | 0.5 | 0.6 | 0.5 | 0.3 |
| squalls cast, a climb | 8.7 | 3.5 | 4.9 | 8.0 |
| wearing a pack of holding at the end | 38 % | 48 % | 26 % | 14 % |
| end level | 33.9 | 32.0 | 32.9 | 32.2 |

The giant is the easiest of the three boss floors for the bot so far: it arrives at level 30 or more, and about half the time it carries the crate off. Floors 9 to 11 shifted a little against step 19 (the squall and the pack of holding change the climbs). The leading killers are still goblins, ogres, giant ants and cave bears on floors 5 to 11, and the wind for every build but the Caster.

### Decided with the user (November 19, 2026)

The giant, gust insurance at 120 Jools and the bot's gaps (maps, the smith's new stock, scale mail, Uncurse, Find the Stairs, Teleport) are left as they are; the floor 12 screenshot is approved. The game is unchanged by the review.

## Step 24: floors 13 and 14 (November 20, 2026)

50 climbs a build. The bot's climb still ends when it takes the key to floor 13, so it never goes through the door; the figures are those of round 6 to the last digit (96, 98, 100 and 98 % take the key; 5.60, 2.12, 2.62 and 2.02 deaths a climb). Nothing on floors 1 to 12 changed: the wind tables only grew past floor 12, and the 3-cell push starts at floor 13. The bot meets floors 13 to 16 in step 33.

### Decided with the user (November 20, 2026)

Step 24 is kept as built: the wind table for floors 13 to 16, the 3-cell push (a heavy load drags 2) and the tenant counts. The game is unchanged by the review.

## Step 25: the tenants from floor 13 (November 20, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The three new tenants live only from floor 13, which the bot does not enter until step 33.

### Decided with the user (November 20, 2026)

Step 25 is kept as built: the numbers, the demon's charge, the scream and the pictures. The hundred-eyed beast now screams only the first time it sees you, as described (it had screamed again after losing you).

## Step 26: the last camps and the town after the giant (November 21, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The bot's climb ends with the key to floor 13, so it never shops after the giant or reaches floors 13 and 14.

### Decided with the user (November 21, 2026)

Step 26 is kept as built: the gear's numbers, the wind cloak stacking with a heavy load, the lines and the pictures. The game is unchanged by the review.

## Step 27: Heal, Shelter and Tempest (November 21, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The bot learns the three new spells once it has the older eighteen, but casts none of them until step 33.

### Decided with the user (November 21, 2026)

Step 27 is kept as built. Find the Stairs is renamed Find Stairs so it no longer runs into its cost in the spell list; the bot does not cast it, so no figure moves.

## Step 28: floor 15, the champion (November 21, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The bot does not climb past the key to floor 13 until step 33.

### Decided with the user (November 21, 2026)

Step 28 is kept as built: the champion's learning, the key handed over, the lines and the pictures. The game is unchanged by the review.

## Step 29: floor 16, the top (November 21, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The bot does not climb past the key to floor 13 until step 33.

### Decided with the user (November 22, 2026)

Step 29 is kept as built. The end-of-stretch notice for the key to floor 13 is dropped; rerun after the change, the bot round gives the same figures as round 6.

## Step 30: the ending (November 22, 2026)

50 climbs a build: the same figures as round 6 to the last digit. The bot does not climb past the key to floor 13 until step 33.

### Decided with the user (November 22, 2026)

Step 30 is kept as built. The game is unchanged by the review.
