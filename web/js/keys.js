// Every keyboard control in one place, as in the iPad version's GameKey: the key the game listens
// for and the letter drawn on the matching on-screen button both come from here.
SN.keys = {
  up: ['KeyW', 'W'], left: ['KeyA', 'A'], down: ['KeyS', 'S'], right: ['KeyD', 'D'],
  use: ['KeyE', 'E'], jump: ['Space', 'Space'], carry: ['KeyR', 'R'], crouch: ['KeyC', 'C'], taunt: ['KeyT', 'T'],
  dash: ['KeyQ', 'Q'], run: ['ShiftLeft', 'Shift'],
  vines: ['KeyV', 'V'], lightning: ['KeyF', 'F'], toy: ['KeyG', 'G'], bat: ['KeyB', 'B'], cloud: ['KeyX', 'X'], hose: ['KeyJ', 'J'],
  pause: ['KeyP', 'P'], menu: ['KeyM', 'M'], restart: ['KeyN', 'N'], hint: ['KeyL', 'L'],
};
/// Extra keys that do the same job: arrows walk too, Esc pauses, either Shift runs.
SN.keyAliases = { ArrowUp: 'up', ArrowLeft: 'left', ArrowDown: 'down', ArrowRight: 'right', Escape: 'pause', ShiftRight: 'run', Enter: 'use' };
SN.items = ['vines', 'lightning', 'toy', 'bat', 'cloud', 'hose'];
SN.label = name => SN.keys[name][1];

/// What's held down right now, and what was pressed since the last frame.
SN.input = (function () {
  const held = new Set();
  let pressed = new Set();
  const action = code => {
    for (const name in SN.keys) if (SN.keys[name][0] === code) return name;
    return SN.keyAliases[code] || null;
  };
  window.addEventListener('keydown', e => {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    const a = action(e.code);
    if (!a) return;
    if (!held.has(a)) pressed.add(a);
    held.add(a);
    if (a === 'jump' || a.startsWith('up') || a.startsWith('down')) e.preventDefault();
  });
  window.addEventListener('keyup', e => { const a = action(e.code); if (a) held.delete(a); });
  window.addEventListener('blur', () => held.clear());
  return {
    held: a => held.has(a),
    /// The actions pressed since last asked (each one reported once).
    take() { const p = pressed; pressed = new Set(); return p; },
    press(a) { pressed.add(a); },
  };
})();
