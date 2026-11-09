# Blustery Bulwark of SPLORR!! — Plan

Drafted November 9, 2026. `DESIGN.md` is the specification; this file is how it gets built, one playable slice at a time. Everything under "Proposed" is Claude's suggestion until the user decides it; numbers are starting values to tune by playing.

## Slice 1: the town and the first stretch

**Goal:** a complete loop you can play and die in: the town, three generated floors, and the first boss floor ("the undead horde"), with the wind, light, hunger, the faithful inventory and death at the town checkpoint all working. When the skeleton falls, the herald proclaims it, and the slice ends with the key to floor 5 in yer pack and a notice that the rest is still being built.

**In the slice**
- The town (one screen, hand-built): the bulwark gate, the tavern (mentor), the herald's square, a general store, a smith (sell, buy, repair), the sage (identify), the temple (heal, remove curse), the junk shop, the bank. Every shopkeeper's line in the town's believe-and-profit voice.
- Floors 1 to 3: generated, persistent per character, stairs up and down, each with a prevailing wind direction.
- Floor 4: hand-built boss floor, "the undead horde" (one skeleton and propped-up bones that fall over in a gust).
- The return-to-town scroll; the boss-floor shortcut from town to floor 4 once it is reached.
- Character creation: name, four attributes by point-buy (decided November 9, 2026), starting kit.
- Levels 1 to about 4, a spell choice at each.
- Saves in localStorage: seed plus changes, as in Wonting.
- All four inputs on every screen; landscape; the release layout and footer from the first commit.

**Not in the slice:** floors 5 and up, bosses 2 to 4, the champion and the lord, the endgame, LootLocker scores, sound beyond a handful of effects, the title art and cover (placeholder only).

## Proposed content for slice 1

**Monsters (decided November 9, 2026):** rats, bats, spiders, beetles, a green slime, kobolds, and **carnies** (the user's addition). The skeleton boss. Each tenant has a short line on inspect ("Pays rent on the second Tuesday").
- *Carnies are sideshow barkers* (decided November 9, 2026): they run the boss floors as attractions ("See the Undead Horde! Two Jools!"), sell rigged games and charms on the floors, and fight if you skip paying. The bluster economy, inside the bulwark. The Urizen figure sheet (cols 104 to 200) should have a fitting person; check when picking tiles.

**Spells offered at level-up (decided November 9, 2026: these ten, to rename or rebalance after playing; eight directions, bent by wind):**
- Attack: Magic Bolt (single tile, wind bends it), Gust Ball (lands where the wind takes it, small blast). *(Names are ours, not Castle of the Winds'.)*
- Defence: Ward (armour up for a while).
- Healing: Mend (small heal).
- Movement: Hop (short random teleport), Return (to town; also a scroll).
- Divination: Sense Tenants (show monsters on the floor), Identify.
- Miscellaneous: Kindle (relight yer torch without a turn's fumbling), Anchor (count as heavily loaded until the next gust has passed).

**Items:** dagger, short sword, club, mace; leather cap, padded and leather armour, buckler, boots, cloak; a ring and an amulet (one cursed of each); torches, a lantern and oil, tinderbox; bread, cheese, jerky; small and medium packs, a sack, a belt with four slots, a purse; healing and unknown potions; scrolls (return, identify, unknown); one spellbook. Jools (weight per coin to tune), trophies (rat tails, bat wings, spider legs, one skull).

**Starting numbers (tune by play):**
- Hunger: 0 to 1000, +1 a turn; past 800 "peckish", at 1000 lose 1 health every 10 turns. Bread −400.
- Light: a torch burns 300 turns; a gust has a chance to snuff it (more on higher floors); the lantern resists gusts but burns oil. Dark means a sight radius of 1.
- Gusts: every 12 turns on floor 1, down to every 8 by floor 4, with a 2-turn warning (streaks on screen, a sound). Push 1 tile; carried weight over 60% of yer limit anchors you.
- Jools: 10 coins weigh 1 unit (so 500 Jools are a real burden), banked Jools are safe.

## Build order (each step ends playable in the browser and tested natively)

0. **Done November 9, 2026.** A placeholder walled room (40 by 28) the view scrolls over; eight-way movement, wait, confirm and cancel from keys and gamepad; click and right-click report the cell; side panel and log laid out; 6 native tests; checked in the browser (keys, scrolling, click, right-click; the gamepad path is untested without a pad). LootLocker feedback is wired but the LootLocker game is not set up. **Scaffold:** `src/` rules package and platform layer, `tools/test.sh`, `build.sh`, `serve.sh`, `pages.sh`, `ship.sh` plus `shippit.sh`, `index.html` with footer (back links, AI disclosure, feedback link to be wired), Urizen and DINOBYTE with licence records, a placeholder `assets/cover.png`, `ITCH_DESCRIPTION.md` draft. Framebuffer drawn to a canvas, crisp scaling, landscape layout of map, side panel and log.
1. **A floor to walk:** generator for floors 1 to 3, scrolling view centred on the player, fog of war, stairs, automap, movement on all four inputs (touch d-pad).
2. **Wind and light:** prevailing direction, telegraphed gusts, pushing items and the player, anchoring by weight, torch burn-down and snuffing, darkness.
3. **Inventory:** weight and bulk, nested containers, belt, purse, paper doll, pick-up-then-place on all four inputs, picking up and dropping on the floor.
4. **Monsters and combat:** tenants with simple chase and wander, hidden rolls, gear durability, trophies, death drops yer pack and wakes you in town.
5. **Magic:** mana, level-up spell choice, eight-direction aiming, wind-bent bolts, the slice's spells.
6. **Hunger and identification:** food, unknown potions and scrolls, curses, the cursed ring and amulet.
7. **The town:** shops, smith repairs, sage, temple, junk shop, bank, mentor, herald proclamations after each return.
8. **Floor 4 and the end of the slice:** the hand-built boss floor, the skeleton fight, the key, the shortcut, the herald's proclamation, the end-of-slice notice.
9. **Saves and polish:** seed-plus-changes saves, a first balance pass, screenshots, then Pages when the user says so.

## Decided for slice 1 (November 9, 2026)

- Character creation: point-buy.
- Monsters: the list above, carnies included, as sideshow barkers.
- Spells: the ten above.
- **GitHub Pages as soon as it is walkable:** enable Pages after build step 1 and update it as steps land (each push and enabling Pages still need the user's go-ahead).

## Open for slice 1

- The point-buy pool and base values, the starting kit, and the shop price list: settle while building steps 3 and 7.
