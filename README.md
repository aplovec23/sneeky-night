# Sneeky Night

A 2D puzzle game for iPad and iPhone (SwiftUI). On an iPhone the room fills the screen and the joystick and buttons float over it, small and see-through, at the bottom; menus are the iPad ones shrunk to fit. Pick a boy or girl, type a name, then sneak out of each room before the clock runs out.

## Menu
Save Files: each file is a separate player (name, look, levels, badges, accessories, items). Make as many as you like; the original save is the first file. Custom sound swaps are shared by all files.

Play / Continue goes straight to the first level you haven't won. Levels shows your progress (you can only replay levels you've won, plus the next one). Customize Character: name, boy/girl, skin tone, T-shirt colour and picture, cap.

Settings: master / music / sound-effect volume, night or early morning, joystick and button size, joystick side, key letters, button buzz, name tag. Update Log lists every update (add new ones at the top of `UpdateLogView.updates` in `SneekyNight/MoreMenus.swift`). Side Levels shows the extra rooms and what each one needs.

Also on the menu: **Multiplayer** (two players on one screen: player 2 gets a small orange joystick and hand button, or the arrow keys and Return; player 2 can search and open things, but only player 1 hides, jumps, uses items and gets chased), **Level Maker**, and **Lore** (locked until every level and side level is won and you have 30 badges; the story text and fun facts are in `LoreView` in `SneekyNight/MoreMenus.swift` — rewrite them freely).

Settings → the game's sky: Night, Early morning, or Real time. Real time follows the clock in the time zone you pick (5–7 sunrise, 7–17 day, 17–19 sunset, otherwise night).

**Pause button** (top left in every level, or Esc / P): volumes, button size, joystick side, Restart, Menu, and **Practice mode** — the Guide gives tips (tap him for the next one) and nobody can catch or hurt you.

In practice mode the Guide also walks in the room with you ("Follow me!") and leads you to the next place to go (each level's `guideGoal`).

**Creative mode** (switch at the top of the Levels screen; needs every level, every side level and 33 badges): a wand button in each level opens the admin panel with 55 commands (`SneekyNight/Creative.swift`), and you wear the creative crown while it's on. Status commands stack (Speed ×2 pressed three times = ×8; the panel shows your current stats). Creative mode switches on immortality and the untouchable buff: when Mom or Dad try to grab you they get confused ("Why can't I touch you?!") and sometimes decide you're a ghost. In your own Level Maker levels, creative mode can be switched on in the editor even before it's unlocked.

**Difficulty** (the bar under Play; `SneekyNight/Difficulty.swift` holds every number):

| | Clock | Hazards | Other |
|---|---|---|---|
| Easy | ×1.4 | speed ×0.6 | you: speed ×1.15, slightly higher jump, noise ÷1.5; about 10 taunts to wake Mom; Dad laughs 60 s; Mom and Dad never find you hiding; 3-number codes; 8 dogs; 2 gate keys; smaller chores |
| Mild | ×1 | as before | the original game |
| Hard | ×0.85 | speed ×1.3, damage ×1.5 | 50 dogs (10 snacks a trip), 20 hotel floors, bigger chores and wandering cats; boosts ×1.5 as likely; orbs ×2 |
| Chaos | ×0.85 | speed ×1.6, damage ×2 | Mom and Dad move at your speed; they always find you hiding; a hotel worker passing your hiding place looks behind it 1 time in 3; boosts ×2; orbs ×3 |
| No Mercy | ×0.5 | speed ×1.8, damage ×2.5 | Mom and Dad are 12% faster than you; the first touch of any box, drawer or rock is a 50-50 trap (noise, and 15 damage where there's health); strangers turn toward you; every third Guide tip is wrong; boosts ×3; orbs ×4 |

## Controls
| Keyboard | On screen | Does |
|---|---|---|
| W A S D (or arrows) | Joystick (bottom left) | Walk |
| E | Hand button | Use / open / search the thing you're next to |
| Space | Arrow button | Jump (clears obstacles and toys) |
| R | Box button | Pick up / put down a small object (big ones are too heavy) |
| C | Down-arrow button | Crouch: slower, safe to touch obstacles, hide under tables |
| T | Smiley button | Taunt (fills the noise meter — too much and Mom wakes up) |
| Shift (hold) | Running button (switch) | Run — once learned. Noisy! |
| Q | Wind button | Dash — once learned |
| V / F / G / B / X | Item buttons (middle) | Vines / Lightning Ball / Brother's toy / Bat / Cloud — once you own them |
| P (or Esc) / M / N / L / Z | Top buttons | Pause / Menu / Restart / Hint / Creative wand |
| Arrow keys, Return | Player 2's joystick and hand | Player 2 walks and uses things (multiplayer) |

Every key lives in one list, `SneekyNight/Engine/GameKey.swift`: the key the game listens for and the letter drawn on the on-screen button both come from it, so they always match. Change a key there and both change.
| H | Hat button | The Guide's Hat on / off (only on a device it was given to) |

Dash goes whichever way the joystick (or keys) is pointing.

## Levels
Clock per level (seconds): 100, 150, 200, 250, 350, 400, 450, 500, 550, 600 — `Levels.seconds` in `SneekyNight/GameState.swift`.

1. **Bedroom** — key under the table opens the lockbox under the bed; the lockbox key opens the door. Out of time (or too loud) = Mom comes in and says go to sleep.
2. **Hallway** — avoid chairs, tables and lamps (crouch to touch them safely, or jump). Drawers hold Zoom Slippers (faster) and Spring Socks (higher jumps); one drawer is blocked by a box you must move with R. Front door needs the code from a paper in one of the boxes (1DLP, 9PO8 or 42FOJ) plus two keys: the window-ledge key, and either the key by your sibling's bed (jump the rolling toys) or Mom's spare key. Open the window again after taking its key to peek outside (a different silly scene each time). Every 4th box check finds a skill paper (Dash, then Run).
   - **Mom's room**: spare key (jewelry box), Silent Slippers (crouch and look under the bed — one free bump), alarm clock (+30 seconds). Noise counts double here. Dad checks the room every 9–15 seconds: hide in the wardrobe or crouch under the table.
3. **Downstairs** (200 s, +45 s at each big step) — in order: go down the stairs jumping the loose planks (crouching doesn't help); take food from the fridge and throw it out of the window so a dog with a key comes to the front door, then bring him a second snack for the key; find 3 metal scraps (random spots), craft each into a key at the garage workbench and open the 3 lockboxes (random spots) for the 3 door keys; flip the garage light switch 3 times so Dad comes down, and hide in a closet until he's in the garage; upstairs, take a toy from your brother's room, throw it in the hallway and hide while Mom walks to it, then take her phone (passcode 12345, no hints) and read Notes for the code 0090; in the basement dodge Dad (closets are safe) and type 0090 at the exit door; outside, lock the door with the dog's key within 10 seconds, then walk to the garden gate.
   - **Roof (sub level)**: grab the ladder in the garage and use the upstairs hallway window. Star balls appear there (+6% speed each, up to +60%, for the rest of the level) and taunting makes no noise.
4. **Garden** (250 s, +20 s per 10 plants, +60 s at the gate) — a top-down hedge maze (same layout every time). Walk close to all 100 plants to water them; a pest lands every 25 seconds (E to shoo it, at most 6 at once). Spiky vines stretch across some paths: jump them (touching one brings Dad). The radar station shows thirsty plants, pests, bushes and Dad's timer. Dad checks every 2 minutes with a 10-second warning: hide in a bush. One strange sparkly bush gives the permanent Vines item. The gate dogs grumble (a little noise) if you stand close while they're there. When everything is done, go through the gate while the dogs are away (they come and go about every 10 seconds). Beyond the gate: 3 keys hidden in 3 of 6 spots, and the street gate's code is "Plants" (hint in the corner of the screen).
5. **Street** (350 s, +30 s when every dog is fed) — the first level with health (100 HP, +45 for every boost you're wearing, plus dungeon upgrades). Strangers take 20 HP if you touch them: jump over them or wait in a bus stop. Feed the 15 dogs with snacks from the fridge at home (the HOME door at the start of the street), 5 at a time. Mom is cooking: she can't see you while she's at the stove or the sink, but she sees what's ahead of her when she walks between them, so crouch under a table. A rat turns up now and then while you carry snacks: it takes one and leaves an accessory (1 in 10: a boost). Then the hotel at the far end: guards outside (30 HP and sent back) and workers inside (15 HP and sent back) see what's in front of them, much less far if you crouch. The first floor is the lobby; the elevator at its far end has 10 floor buttons (2–11). Uncle's room is on a random floor and behind a random one of its 4 doors, new every try, with no hints — except in practice mode, where the Guide tells you (and leads you there). Knocking on the wrong door makes a little noise, and the worker on each floor sends you back down to the lobby. Uncle's door opens with the blue key (it's in your backpack from the start). Talk to Uncle to finish.
6. **Auntie's House** (400 s) — no one chases you; it's you against the clock. Do Auntie's 10 chores across two floors: wash the dishes, fill the cat bowls, water the plants, sweep the dust (just walk over it), take the rubbish bag to the bin (R to carry, E at the bin), set the table, dust the bookshelf, make the bed, pick up the socks, and find her glasses (in a random drawer or box). The next chore is shown at the bottom of the screen. Stepping on a sleeping cat costs 15 s (more on harder modes); filling the noise meter costs 20 s. When all ten are done Auntie walks to the back door; follow her and press E there.
7–10. Not designed yet ("Coming soon").

## Getting chased
When the clock runs out, the noise meter fills, you bump something or Dad spots you, Mom or Dad walks in through a door and comes after you (`SneekyNight/Engine/Chase.swift`). You can outrun them, jump over them, hide (if they didn't see you hide, they look inside half the time when they walk past), or stun them. After one minute without catching you they give up; when it was Mom, the clock is set to 2 minutes. In the Level 4 maze they follow the paths.

## Side levels
1. **The other hallway** — needs 3 accessories, 20 badges and Level 3 won. 5 keys are hidden in 5 of the 8 boxes; boxes can be searched again for accessories and boosts (1-in-8 here instead of 1-in-15). With all 5 keys the far door opens onto a secret room with a chest: a boost you don't have yet, or extra T-shirt and cap colours for Customize Character.

2. **The dungeon** — needs Level 5, Side Level 1 and the Friendly Route badge. No clock. Each glowing rock holds 3 orbs (1 hit in 8 gives a big orb worth 3) and grows back after 20 s. The Orb Shop sells upgrades that work in every level (10 steps each: speed up to ×5.7, jump ×2, dash ×3, quiet ×3, health +200; a step costs 8, 14, 20… orbs), a mystery accessory (15) and six demo exclusives (40 each). Spikes take 15 HP; at 0 you wake at the entrance minus 5 orbs. The quest (mine 40 orbs, buy 3 upgrades, buy one exclusive) finishes the side level and pays 25 orbs.

3. **Uncle's car** — needs every level won and 30 badges (it is not needed for the Lore or creative mode). A short scene behind the hotel, then you ride in the back seat while Uncle drives to the city where Auntie lives; tap the car to hear what he says. Stay for the full 10 minutes and you get five scenes from Level 6, "Auntie's House", and the side level counts as finished (`SneekyNight/Levels/SideLevel3UncleCar.swift`; the ride length is `rideSeconds`).

4. **The cinema** — no requirements. Ten shows, each exactly one hour (`CinemaShow.length`). Pick a show, then a free seat: front rows see a bigger screen, side seats see it at an angle. The clock only runs while the film is on screen; if you leave, your place in that show is kept. Each time a show reaches the end you get 1000 orbs (`CinemaShow.reward`), and you can watch any show again. The star appears when all ten have been watched. The screen is kept awake during a film. The shows are listed in `SneekyNight/Levels/SideLevel4Cinema.swift` and their stories are in `CinemaStories.swift`: each show has 8 parts of 8 lines, all different (640 lines, none repeated). The lines are spread evenly over the hour, so a new one appears about every 56 seconds, stays up for 24, and the picture carries on without words in between; a part lasts seven and a half minutes. On every subtitle the camera picks a shot (wide, or closer in on one of the cast), each actor walks to a new mark and then hops, crouches, taunts, looks around or turns to whoever the camera is on, and the set has its own moving things (`MovieScreen` in the same file). Sound: a lobby tune and four film tunes (adventure, funny, mystery, cosy; `CinemaShow.music` picks one) replace the game's usual music while you're in the cinema, plus effects for picking a seat, the ticket, the projector, popcorn in the audience, a chime at each new part and applause at the end. All of it is made by `tools/make_sounds.py`.

## Level Maker
Menu → Level Maker. There are no limits: as many objects (start, exit door, keys, boxes — with or without a key inside — rocks, closets, plants, pictures, dogs) and hazards (chair, table, lamp, cans, toy car, spikes, stranger) as you like, and any length or time. Add Mom, Dad and your brother, plus characters that only exist in the Level Maker: Uncle, a Friend, a friendly Ghost and the Guide (talk to them to hear their line), and Guards and Workers (they walk up and down and send you back to the start if they see you; guards also hurt). Write your own words for each. The "Creative" switch in the editor turns creative mode on for that level. Pick a thing, tap the room to place it, drag to move it, drag an empty spot to slide the room. Goal when playing: find every key, then use the exit. Mom wakes when time runs out, you're too loud or you bump a hazard; Dad patrols and chases if he sees you; talk to your brother to hear his line. Levels are saved on the device and shared by all save files (`SneekyNight/LevelMaker.swift`).

## Extras
- **Dash cancel**: press dash again during a dash to stop.
- **Level Maker instant-fail hazards**: lava (jump over it) and a laser that blinks on for 1.7 s and off for 1.3 s (walk through while it's off).
- **Talk with your brother**: "Let's talk" in his menu opens six topics, each a short back-and-forth (`TalkOverlay.topics` in `Levels/Sibling.swift`).
- **Hair styles**: 20 presets, 11 hair colours and "My own" (six sliders: top, fringe, sides, back, spikes, curls), in Customize Character (`LookOptions.hairStyles`, drawn in `CharacterView.swift`).
- **Where items came from**: every entry under Lore → Items and Accessories has an origin line (`ItemLore` in `MoreMenus.swift`, `Boost.origin` in `GameState.swift`); a boost's origin also shows when you find it.
- **The roof** is 3400 wide now; walk past either end to look down on the street or the garden.
- **Drawing**: the paper stack next to the toy chest in your brother's room opens a drawing pad (`DrawingPad.swift`). The game is paused while you draw, and the picture is kept on the device.
- **Grown-ups talk**: in 4 chases out of 10 the other parent walks in and they talk about the noisy house for about a minute (nobody chases you meanwhile). They also stop to talk to your brother if he's up, and mutter while they search.
- **Cloud** boost (X): fly for 10 s, 30 s cooldown; in the air you pass over everything, including the garden hedges.
- **The Guide's Hat** boost (H): toggles on and off, no cooldown. While on: speed, jump, dash, quietness and health ×10.5, and you walk through things. It can never be found in the game (chance 0). It's given to a specific device by adding that device's ID (shown at the bottom of Settings) to `GuidesHat.devices` in `SneekyNight/GameState.swift`.
- **Lore** categories: Story, Characters, Items, Accessories, Fun facts.
- **Bat** (B): 1-in-12 chance in any search until you own it, then yours forever. Stuns Mom 2 s, ready again after 5 s.
- **Badges** (menu → Badges, 40; "the world revolving" = sprint with star ball power while wearing every speed boost; "multiplayer" = play a level in multiplayer mode; "Just in case" = 10 save files, "Im unstoppable!" = every boost plus the vines, toy and bat): three are named "soon" because they can't be earned yet (April Fools, Christmas, multiplayer). "number 1# player!" needs all 10 levels. The golden stick ("????") has a 0.000000000001 chance each time a star ball would appear on the roof.
- **Accessories**: 60 (the first 10 plus 10 kinds × 5 colours). A search has a 1-in-5 chance to give one; wear one at a time.
- **Boosts** (1-in-15 chance, all stack, toggle in Customize; the eye button next to each one makes it invisible on your character while it keeps working): Cool Cap with a Can (speed ×1.5), Leaf (jump ×1.3), Wind Crown (speed ×1.2, dash ×2.5), Golden Crown (everything ×1.2, quieter), Lightning Ball (press F: speed/dash/jump ×3.5 for 25 s, quieter, 1 min cooldown), Arrow (dash ×1.9, walking speed ×1.2). On the roof a glowing gift with a boost you don't own lands about once a minute, and the level clock is paused while you're up there. Total speed is capped at 1100 so you can still steer.
- **Items**: Vines (V) stun Mom or Dad 10 s, every 35 s — from the strange bush in Level 4. Brother's toy (G) stuns Mom 60 s, every 50 s — the reward for finishing Level 2 or 3 with your brother following.
- **Brother**: taunt in his room to wake him; talk (E) for tips, "Follow me", or give him a toy. Following you, he stuns Mom once if she catches you.
- **Toys as gifts**: grab one from the toy chest in your brother's room; give it to him (talk menu), Mom (her bed) and Dad (his desk in Mom's room) for "Friendly Route".
- **Dad and taunting**: taunt while Dad is there (or on his way) and he laughs and gives you 10 seconds.
- **Custom Sounds** (Customize → Custom Sounds): every game sound with a play button; swap any of them for one of 20 effects.
- **Window surprises** (Level 2), **roof star balls** and **Mom calling your name** work as before.

## Files
- `SneekyNight/Engine/GameEngine.swift` — movement, jumping, carrying, obstacles, keyboard, the clock
- `SneekyNight/Engine/LevelScaffold.swift` — level screen: room, top bar, timer, backpack, joystick and buttons
- `SneekyNight/Engine/Sound.swift` — sound effects (made by `python3 tools/make_sounds.py`)
- `SneekyNight/Engine/ItemBelt.swift` — usable items and stacked boosts
- `SneekyNight/Levels/` — Level 1 (bedroom), Level 2 (hallway rules; `HallwayArt.swift`, `MomRoomArt.swift`), Level 3 (`Level3Downstairs.swift`, `DownstairsArt.swift`), Level 4 (`Level4Garden.swift`, `GardenArt.swift`), `Sibling.swift` (the brother)
- `SneekyNight/Levels/SideLevel1OtherHallway.swift`, `SideLevel2Dungeon.swift` — side levels
- `SneekyNight/Levels/Level5Street.swift`, `StreetArt.swift` — Level 5 (and the Guide's tips for every level)
- `SneekyNight/Engine/HUD.swift` — speech bubble, health bar, pause menu, the Guide, fireflies
- `SneekyNight/Creative.swift`, `LevelMaker.swift`
- `SneekyNight/Engine/Chase.swift` — Mom and Dad coming to find you
- `SneekyNight/Settings.swift`, `MoreMenus.swift` (Settings, Side Levels, Update Log)
- `SneekyNight/MenuScreens.swift`, `GameState.swift`, `CharacterView.swift`, `Popup.swift`

## Put it on your iPad
Plug in the iPad and ask Claude to install it, or open `SneekyNight.xcodeproj` in Xcode, pick the iPad at the top and press ▶ Run.
