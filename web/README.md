# Sneeky Night — web version

The same game as the iPad app, rebuilt to run in any web browser (computer, tablet or phone),
including on Windows. Plain HTML, CSS and JavaScript: no installing, no build step.

## Play it
- **Easiest:** open `index.html` in Chrome, Edge, Safari or Firefox (double-click it).
- **Or** serve the folder, e.g. `python3 -m http.server 8768 --directory web`, then open http://localhost:8768.

Saves, settings and drawings are kept in that browser (localStorage), separately from the iPad.

## Controls
Keyboard: W A S D or arrows walk · E use (Enter too) · Space jump · C crouch · R carry · T taunt ·
Q dash · Shift run · V F G B X items · P or Esc pause · L hint · N restart · M menu.
On touch screens a joystick and buttons appear (Settings → Buttons to force them on or off).
Every key is listed once in `js/keys.js`, which also supplies the letters on the buttons.

## What's built so far (stage 1)
- Title, Customize Character (all hair styles, colours, tops, trousers, shoes, eyes, moods, caps,
  accessories, boosts), Levels, Badges (all 42), Difficulty (all 5 modes), Settings, Save Files.
- Level 1 (Bedroom) and Level 2 (Hallway, your brother's room with the talk menu and drawing paper,
  Mom's room with Dad's checks, door keypad, window surprises, skill papers, loot).
- Mom and Dad chasing you (with the "parents talk" and brother encounters), practice mode, pause menu,
  items (vines, toy, bat, lightning, cloud), sounds and music.

Still to port: Levels 3–7, the side levels (Other Hallway, Dungeon, Uncle's Car, Cinema, Dreams),
the Level Maker, multiplayer, Lore and creative mode.

## Files
- `js/engine.js` — movement, jumping, crouching, carrying, hazards, noise, the clock (from GameEngine.swift)
- `js/chase.js` — Mom and Dad coming to find you (Chase.swift)
- `js/scaffold.js` — the level screen: canvas, camera, top bar, buttons, pop-ups, pause
- `js/draw-people.js`, `js/draw-props.js` — characters and furniture, drawn from shapes
- `js/levels/level1.js`, `level2.js` — the levels
- `js/menus.js`, `js/main.js` — menus and moving between screens
- `js/data.js`, `js/state.js`, `js/settings.js`, `js/sound.js`, `js/keys.js` — game data, saves, settings, sound, keys
- `sounds/` — copies of the iPad version's sound files
