# Blustery Bulwark of SPLORR!! — Design

Started November 9, 2026. This file is the specification. Sections: what is **Decided** (the user's calls, dated), the two trope inventories this design draws on, **Proposed** (Claude's suggestions, waiting on the user) and **Open** questions. Only the user moves an item to Decided.

## Decided

- **Name: Blustery Bulwark of SPLORR!!** (November 9, 2026). Picked from synonyms for "Windy Castle of SPLORR!!".
- **A more modern take on Castle of the Winds** (November 9, 2026, the user's words: "a more modern take on the game 'Castle of the Winds'"). Inspired by its genre and systems; its story, names, bosses and art are not used (see `CLAUDE.md`).
- **"Blustery" means both** (November 9, 2026, the user chose "Both" for Proposed items 1 and 2): the wind is a real mechanic (gusts on a visible pattern push loose items and light creatures, blow out yer torch, carry yer scent downwind, bend spell bolts), and "windy" as in full of hot air is the Metaphor layer (the bulwark's lord is a blowhard; the quest is built on boasts that turn out empty). Details still to settle.
- **Death: town checkpoint** (November 9, 2026): you respawn in town and what you carried stays on the floor where you died, to be fetched back. Everything carried (not worn) drops in one pile; die again before reaching it and that pile is gone for good. Banked Jools are safe.
- **Length: one town and 12 to 16 floors** (November 9, 2026), boss floors gating the way on; a few evenings to finish. **16 floors** (November 13, 2026): bosses on floors 4, 8 and 12, the champion on 15, the lord on 16. **The floors go up** (November 9, 2026): the bulwark is climbed floor by floor, gusts grow stronger and more frequent toward the top, and the blowhard lord sits at the top.
- **Brutality: hard but fair** (November 9, 2026): monsters hit hard and the first floor can kill you, but danger is readable (wind patterns, visible threats); with the checkpoint, dying is a setback, not a wall.
- **Art: the Urizen 1-bit tileset** (November 9, 2026; vurmux, CC0, 12 by 12; see the vault's `Tech/Urizen tileset.md` and the tile catalogues). **Font: DINOBYTE** (November 9, 2026; mby, CC BY 4.0, 6 by 8; credit required).
- **Stack: Odin to `js_wasm32`, web only** (November 9, 2026): canvas software framebuffer, keyboard, mouse, gamepad and touch, localStorage saves, pure rules package with native tests, Pages first.
- **Venue: a normal release** (November 9, 2026): no jam, no deadline; GitHub Pages first, itch.io later on a Coxswain-booked day once the user is happy with it.
- **Character: no classes, four attributes, a spell per level** (November 9, 2026): Strength, Dexterity, Intelligence and Constitution; everyone fights and casts; each level-up the player picks a spell.
- **Ranged: spells only, and the wind bends them** (November 9, 2026): no bows or thrown weapons; bolts and balls drift with the gust, so you aim with the wind (into it, for less range).
- **Inventory: faithful to Castle of the Winds** (November 9, 2026, the user chose this over a modernised version): weight and bulk limits, full container nesting (packs and bags in sizes, chests, belts with fixed slots, purses for coin, packs of holding that do not nest in each other) and a paper doll of worn gear. The bookkeeping is part of the fun.
- **Identification and curses: all of it** (November 9, 2026): unidentified items, a sage who identifies for a fee, an Identify spell, curses that stop removal until Remove Curse (a temple service and a spell), cursed items that cast bad spells, and a junk shop that buys anything for a pittance.
- **Combat rolls: hidden** (November 9, 2026, the user chose this over the SPLORR!! sixes-only dice): to-hit and damage are worked out behind the scenes, as in Castle of the Winds.
- **Gear wears out; a smith repairs it** (November 9, 2026): weapons and armour lose durability in use and break at zero; a town smith repairs them for coin.
- **Money: heavy Jools, a bank, trophies** (November 9, 2026): one coin, Jools, that has weight (so with the faithful inventory the bank matters); banked Jools are safe from death; monster trophies (tails, fangs, wings) sell in town.
- **Hunger: a slow clock** (November 9, 2026): food found on floors or bought in town (with weight and bulk like anything else); starving costs health slowly, not instantly.
- **Floors: mixed, and bosses hold the keys** (November 9, 2026): generated floors between hand-built set pieces (the gate, the boss floors, the lord's top floor); each boss drops the key to the next stretch.
- **Floors persist per character** (November 9, 2026): each floor is generated once and kept (layout, items on the floor, the death pile); killed monsters slowly restock.
- **Getting back to town: a return spell and boss-floor shortcuts** (November 9, 2026): a return-to-town spell or scroll, plus a shortcut (a lift or windchute) unlocked at each boss floor so the player resumes from the last boss beaten.
- **Light burns down, and gusts snuff it** (November 9, 2026): torches and lantern oil run out over time and gusts blow them out; light is a second clock beside hunger.
- **Gusts are telegraphed by turn** (November 9, 2026): each floor has a prevailing direction; a gust comes every N turns with a warning a turn or two before (streaks on screen, a sound); higher floors have a shorter N and a stronger push.
- **Gusts push the player unless their load anchors them** (November 9, 2026): a heavy enough load keeps you put but slows you; being pushed into a monster or a wall costs a little.

- **Interface: equal for all inputs** (November 9, 2026, the user chose this over mouse-first): every screen is designed for mouse, keyboard, gamepad and touch from the start, the inventory included. Slower to build, accepted. **Landscape only** (November 9, 2026): one layout; phones play turned sideways. **Map: scrolling, centred on you** (November 9, 2026): floors are bigger than the screen, about 21 by 15 Urizen tiles visible, a side panel for stats and the message log, and a full-floor automap on a key or button. **Inventory: pick up, then place** (November 9, 2026): select an item (click, tap, or cursor and button) to hold it, then select where it goes (a container, a belt slot, a paper-doll slot); the mouse can also drag. One model, the same on every input. **Touch on the map: an on-screen d-pad** (November 9, 2026): touch shows a d-pad and action buttons at the screen edges; no tap-to-path. Mouse clicks and keyboard keys as usual, gamepad stick or d-pad; bump to attack. **Aiming: eight directions, no preview** (November 9, 2026): choose the spell, then one of eight directions; the bolt flies that way and the wind bends it. No predicted path: the player learns the wind.

## Story

Worked out beat by beat with the user from November 9, 2026, starting at the beginning. Approach: take the clichés of such games and of fantasy writing and give each a twist, knowing that twisting them is itself a modern trope. So the twist is played straight: the world is a little wrong, nobody in it remarks on it, and the text never winks at the player (the vault's honest-copy rule).

**Beat 1, the opening (decided November 9, 2026, option A):** one night a gale flattens yer farm. It is only weather. Next morning the lord's herald reads a proclamation taking credit: His Lordship, as foretold, has blown down the farm of the insolent (nobody insulted him). He claims credit for gusts. You set out to climb the bulwark for revenge on a man who did not do it but says he did. It is the Castle of the Winds revenge opening bent: the vengeance is real, the villain is a boast.

**Beat 2, the town (decided November 9, 2026, all four options):**
- *The town believes him.* Everyone takes the proclamations as fact: the sage and the temple both explain that the lord commands the weather; shops sell gust insurance and charms against His Lordship's breath. Nobody is evil; nobody has checked. Only you doubt it, and nobody remarks on that.
- *The town profits from him.* The economy runs on the bluster: weathervanes, wind charms, anchor-weights, repairs after every gust (the smith mends what the wind breaks). Nobody wants the boasts exposed, and nobody says so; they keep selling you things.
- *A former climber as mentor.* An old warrior who went up years ago, came back down, and will not say what is at the top. They train you anyway, and they never die or vanish: they are simply in the tavern every time you return.
- *The herald is the quest board.* Each return to town, the herald reads a new proclamation claiming yer latest deed for the lord ("His Lordship has slain the beast of the third floor"), and the town cheers the lord. Yer progress is his propaganda.

**Beat 3, the climb (decided November 9, 2026, options A, B and C):**
- *The monsters are tenants.* The bulwark is a home; its creatures pay the lord rent and believe his proclamations like the town does. They are not his army; they attack because yer trespassing. No talk-it-out mechanic.
- *Each boss is a boast made real.* The lord proclaims the bulwark guarded by, say, a dragon; what is on that floor is the cheapest thing that technically fits (a very large lizard someone named Dragon). Still dangerous (hard but fair), just less than proclaimed. Every boss floor is another boast falling short, and the herald then announces the horde destroyed (or the dragon slain) while you carry one skull (or a lizard tail) worth a few Jools.
- *Earlier climbers.* Every floor holds traces of people who believed and climbed: camps, notes, gear (heavy, so worth taking but costly to carry). Some stopped partway and live there now; one may be the mentor's old companion. The lore layer, hinting at what is at the top without saying.
- Held for the ending: where the wind actually comes from.

**Beat 4, the boss ladder (decided November 9, 2026):** four bosses, about one every three or four floors, then the lord. Each is a proclamation and the cheapest thing that technically fits; each still fights hard. In climbing order:
1. *"The undead horde"*: one skeleton nobody got round to burying, with friends' bones propped up to look like more.
2. *"An army of a thousand"*: a thousand of something small (rats or beetles), a swarm rather than soldiers.
3. *"A giant"*: an ordinary ogre standing on a box; knock the box away (the wind can too) and the fight changes.
4. *"His Lordship's champion, undefeated"*: undefeated because he has never fought anyone; the mentor's old climbing companion, who stopped here years ago.
Not used, kept for reference: the dragon (a large lizard named Dragon), the demon (a bad-tempered goat), the hundred-eyed beast (a peacock), the storm sorcerer (a weather-wizard who manages only drizzle; held for the ending discussion).

**Beat 5, after the champion (decided November 9, 2026, all four options):**
- *Nobody has been higher.* The beaten champion admits he never went past his floor, and nobody else did either, the mentor included. The mentor would not say what is at the top because they never saw it: they stopped at the champion and came back down. A boast by omission from someone you trusted; no betrayal.
- *The champion is relieved.* Being undefeated was a burden. He goes down to town, and from then on the mentor and their old companion sit together in the tavern. Nobody comments on it.
- *The herald spins it.* The next proclamation: His Lordship has crushed the treacherous champion. Yesterday he was the lord's pride; the town cheers the same.
- *The last door was never locked.* The champion drops the key to the lord's floor, as every boss drops a key, but the door it opens was never locked. The key works anyway, and nothing remarks on it.

**Beat 6, the top floor (decided November 9, 2026, option D):** the lord is real and never said a word. He is a mild, very old man who has lived at the top for years paying no attention; the herald has been writing the proclamations in his name all along. He is a tenant like the rest, and as surprised as you are. He did not blow down yer farm, exactly as the opening implied. The wind is natural: the bulwark sits on the windiest crag in the land (the one honest thing in the game). The final fight is the top floor's wind, the strongest in the game, plus whatever the herald has hired to guard the top. Ruled out on purpose: the man behind the curtain with a bellows (the twist players will expect by now).

**Beat 7, the ending (decided November 9, 2026, option B):** the herald is sincere. You confront him back in town, and he believes every word he wrote. He has never been up either; he wrote what he thought must be true, because who else could command the wind? He is the town's belief at its source. There is no villain to punish, only a man full of hot air who meant it. The story ends there. Considered and not chosen: nobody believing you (A), you becoming the herald (C), the rebuilt farm blown down again (D).

## Castle of the Winds: the tropes

Gathered November 9, 2026 from Wikipedia and RogueBasin (StrategyWiki refused automated reads). Where sources disagree it is noted.

**Shape of the game**
- Tile-based roguelike for Windows 3.x, mouse-driven with keyboard shortcuts, 16-colour icons, no sound.
- Revenge plot: yer farm burned and yer godparents killed. Two parts: a small mine and a town's fortress ending at a giant lord, then a ruined castle of 25 levels with a ladder of boss kings ending at a fire giant. Loosely Norse.
- About 40 levels, a mix of **hand-designed and random** ones, with **towns between dungeons**.
- Save anywhere, restore after death: **no permadeath**. A hall-of-champions leaderboard ranked by time.
- Time played changes shop stock (and, per Wikipedia only, the last boss).

**Character**
- Four attributes: Strength (damage, carry weight), Dexterity (to-hit, traps), Intelligence (mana), Constitution (health; draining it kills).
- **No classes.** Everyone fights and casts.
- Level up to 30, **one spell gained per level** by choice, more from spellbooks.

**Magic**
- Spells are the **only ranged attack** (no bows).
- Schools: attack, defence, healing, movement, divination, miscellaneous (RogueBasin adds item-only spells).
- Elemental pairs (fire and cold, lightning and acid) with resistances.
- Utility spells carry much of the game: Phase Door, Teleport, Levitation, Rune of Return (to town), Detect Objects/Traps/Monsters, Clairvoyance, Identify, Remove Curse, Light.
- Casting past zero mana risks a Constitution drop that can kill.

**Stuff**
- Load limited by **weight and bulk**, not item count.
- **Containers matter**: packs and bags in sizes, chests, belts with fixed slots (utility belt, wand quiver), purses for coin only, packs of holding that do not nest.
- **Paper-doll** slots: armour, shield, helmet, bracers, gauntlets, boots, cloak, two rings, amulet, weapon.
- **Unidentified items**, curses that stop removal, cursed items that cast bad spells; items found broken or rusted.
- Coin is heavy, so a **bank** in town matters.

**Town**
- A temple (heal, restore attributes, remove curse), a sage (identify for a fee), a junk shop that buys anything for a pittance, smiths, outfitters, general and magic shops.
- A ruler who gives advice and rewards after bosses.

## SPLORR!! games: the tropes

Gathered November 9, 2026 from the vault (`Concepts/Metaphor design.md`, `Concepts/Starvation.md`, and the crawler notes: HamQuest, Key Seeker, Wonting, Fortune Hunter, Kordanor's Cabal, Clumsy Oaf, T!ts UUp!!, Pyramid of Ahraxis).

**Identity**
- A **Metaphor**, not a game: the mechanic is the message. Mundane or absurd things played straight, deadpan short text, absurdist taglines, honest copy.
- The **"yer" voice** in every player-facing line.
- Minimal retro presentation: **1-bit tiles** (Urizen, Bountiful Bits, Bit Bonanza), DINOBYTE or small pixel fonts, Anvil-made sprites and sounds.

**Rules that recur**
- **Dice that only count on a six** for attack and defence (Key Seeker, Wonting, T!ts UUp!!).
- **Gear wears out and breaks** (Key Seeker, Wonting, HamQuest, T!ts UUp!!).
- **Starvation**: a draining resource as the clock, refilled only at a place in the world (Bus Anticipator, Feretory, Kordanor's Cabal).
- **Locks and keys** gate areas, each key found in the area before (Key Seeker, HamQuest, Fortune Hunter, Chores).
- **Generated mazes** for the dungeons (spanning trees in HamQuest; Key Seeker is built from maze generators).
- **Jools** (and Crowns) as currency; monster **trophies** (tails, fangs, wings) sold in town (Wonting, Key Seeker).
- **Brutal on purpose**: weak start, lethal monsters, "losing is fun" (HamQuest, Clumsy Oaf).
- Light that burns down (HamQuest); hunger that slowly hurts (Kordanor's Cabal); bosses on each floor (Kordanor's Cabal, Wonting's tower).
- A **checkpoint** that spends earned currency on stats, with what you carry dropped where you die (Clumsy Oaf).

**How they are built and released**
- Odin to wasm, pure rules package with native tests, keyboard plus gamepad plus touch, localStorage saves (often seed plus changes), a portrait layout where it helps.
- GitHub Pages first, then itch.io at one release a day; footer back links, AI disclosure, feedback form.

## Open (the user's to answer)

The twelve original proposals were all answered on November 9, 2026 (see Decided). Still open:

- **Details to settle later:** the spell list and schools, the monster roster per floor, the boss stats, the town's shops and services, numbers for hunger, light, gusts and anchoring weight. (The floor count was settled November 13, 2026: see Decided.)
