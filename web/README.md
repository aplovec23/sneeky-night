# Sneeky Night — web version

The same game as the iPad app, rebuilt to run in any web browser (computer, tablet or phone),
including on Windows. Plain HTML, CSS and JavaScript: no installing, no build step.

## Play it
- **Easiest:** open `index.html` in Chrome, Edge, Safari or Firefox (double-click it).
- **Or** serve the folder, e.g. `python3 -m http.server 8768 --directory web`, then open http://localhost:8768.

Saves, settings and drawings are kept in that browser (localStorage), separately from the iPad.

## Controls
Keyboard: W A S D or arrows walk · E use (Enter too) · Space jump · C crouch · R carry · T taunt ·
Q dash · Shift run · V F G B X J items · P or Esc pause · L hint · N restart · M menu.
On touch screens a joystick and buttons appear (Settings → Buttons to force them on or off).
Every key is listed once in `js/keys.js`, which also supplies the letters on the buttons.

## What's built so far (stages 1–3)
- Title, Customize Character (all hair styles, colours, tops, trousers, shoes, eyes, moods, caps,
  accessories, boosts), Levels, Badges (all 48, with Level 1 to Level 10), Difficulty (all 5 modes), Settings, Save Files.
- Level 1 (Bedroom) and Level 2 (Hallway, your brother's room with the talk menu and drawing paper,
  Mom's room with Dad's checks, door keypad, window surprises, skill papers, loot).
- Level 3 (Downstairs: the stairs' loose planks, the dog's key, metal scraps and the workbench,
  lockboxes, luring Dad with the garage light, the toy for Mom, Mom's phone, the basement and the
  back yard) and its sub level, the Roof (star balls, the owl, the street and garden look-outs).
- Level 4 (the Garden: the same hedge maze as the iPad, 100 plants, pests, spiky vines, the radar,
  Dad's garden checks, the strange bush with the vines, the dogs at the gate, and beyond the gate).
- Level 5 (the Street: health bar, strangers, rats, 15 dogs and Mom cooking in the kitchen; the hotel's
  guards, lobby workers, the elevator and Uncle's room on a different floor every try).
- Level 6 (Auntie's House: 10 chores across two floors, the sleeping cats, the rubbish bag, the glasses,
  then follow Auntie to the back door).
- Level 7 (Auntie's Backyard: entry fee of 32 badges and 10 orbs; wash the mud with the hose, find the
  kittens, Auntie gives you the Water Hose boost (J), and Uncle's car drives you off).
- Mom and Dad chasing you (with the "parents talk" and brother encounters), practice mode, pause menu,
  items (vines, toy, bat, lightning, cloud), sounds and music.

Smooth on slower devices: the canvas is drawn at the screen's own sharpness (at most 2 pixels per point),
and if frames come slower than about 50 a second it steps down a quarter at a time (`tune` in
`js/scaffold.js`); filling pixels is what costs the most. A step that doesn't help (a browser holding
frames back, as in Low Power Mode) is undone. The top bar's styles are only written when they change.

Still to port: the side levels (Other Hallway, Dungeon, Uncle's Car, Cinema, Dreams),
the Level Maker, multiplayer, Lore and creative mode.

## Files
- `js/engine.js` — movement, jumping, crouching, carrying, hazards, noise, the clock (from GameEngine.swift)
- `js/chase.js` — Mom and Dad coming to find you (Chase.swift)
- `js/scaffold.js` — the level screen: canvas, camera, top bar, buttons, pop-ups, pause
- `js/draw-people.js`, `js/draw-props.js` — characters and furniture, drawn from shapes
- `js/draw-house.js`, `js/draw-garden.js`, `js/draw-street.js` — rooms, props and people for Levels 3–5
- `js/levels/level1.js` … `level7.js` — the levels (Levels 6 and 7 keep their own art in the same file)
- `js/menus.js`, `js/main.js` — menus and moving between screens
- `js/data.js`, `js/state.js`, `js/settings.js`, `js/sound.js`, `js/keys.js` — game data, saves, settings, sound, keys
- `sounds/` — copies of the iPad version's sound files
