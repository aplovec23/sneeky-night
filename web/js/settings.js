// Choices from the Settings screen. Shared by every save file, kept in the browser between visits.
SN.settings = (function () {
  const KEY = 'sn.settings';
  const defaults = {
    master: 1, music: 0.5, effects: 1,
    skyMode: 0,            // 0 night, 1 early morning, 2 real time, 3 afternoon, 4 sunset
    difficulty: 1,         // 0 easy, 1 mild, 2 hard, 3 chaos, 4 no mercy
    controlSize: 1,        // 0 small, 1 normal, 2 big
    touchControls: 'auto', // 'auto' (only on touch screens), 'on', 'off'
    swapSides: false, keyLabels: true, nameTag: true, practice: false,
  };
  let saved = {};
  try { saved = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) { saved = {}; }
  const s = Object.assign({}, defaults, saved);
  s.save = function () {
    const out = {};
    Object.keys(defaults).forEach(k => out[k] = s[k]);
    try { localStorage.setItem(KEY, JSON.stringify(out)); } catch (e) { /* private mode: settings just won't stick */ }
    if (SN.sound) SN.sound.updateMusic();
  };
  /// No Mercy: practice mode stays off until you've won the level on No Mercy (set when a level starts).
  s.practiceLocked = false;
  s.practiceOn = () => s.practice && !s.practiceLocked;
  s.controlScale = () => [0.85, 1, 1.2][SN.clamp(s.controlSize, 0, 2)];
  s.showTouch = () => s.touchControls === 'on' || (s.touchControls === 'auto' && ('ontouchstart' in window || navigator.maxTouchPoints > 0));
  /// night, dawn, day, afternoon or dusk (sunset).
  s.sky = function () {
    if (s.skyMode === 1) return 'dawn';
    if (s.skyMode === 3) return 'afternoon';
    if (s.skyMode === 4) return 'dusk';
    if (s.skyMode === 2) {
      const h = new Date().getHours();
      return h >= 5 && h < 7 ? 'dawn' : h >= 7 && h < 13 ? 'day' : h >= 13 && h < 17 ? 'afternoon' : h >= 17 && h < 19 ? 'dusk' : 'night';
    }
    return 'night';
  };
  return s;
})();

/// The sky tints the whole game: night, sunrise, day, afternoon or sunset.
SN.palette = {
  skyTop() { return { night: SN.rgb(0.05, 0.06, 0.2), dawn: SN.rgb(0.35, 0.5, 0.8), day: SN.rgb(0.25, 0.58, 0.95), afternoon: SN.rgb(0.3, 0.55, 0.9), dusk: SN.rgb(0.22, 0.18, 0.48) }[SN.settings.sky()]; },
  skyBottom() { return { night: SN.rgb(0.22, 0.13, 0.4), dawn: SN.rgb(0.98, 0.65, 0.45), day: SN.rgb(0.66, 0.86, 1), afternoon: SN.rgb(1, 0.84, 0.6), dusk: SN.rgb(0.95, 0.48, 0.36) }[SN.settings.sky()]; },
  moon() { return { night: SN.rgb(1, 0.95, 0.75), dawn: SN.rgb(1, 0.85, 0.35), day: SN.rgb(1, 0.93, 0.45), afternoon: SN.rgb(1, 0.86, 0.42), dusk: SN.rgb(1, 0.62, 0.3) }[SN.settings.sky()]; },
  /// The colour washed over every room, and how strong it is.
  shade() { return { night: [0.02, 0.02, 0.12, 1], dawn: [1, 0.75, 0.45, 0.3], day: [1, 0.97, 0.8, 0.12], afternoon: [1, 0.85, 0.55, 0.18], dusk: [0.55, 0.2, 0.25, 0.5] }[SN.settings.sky()]; },
  starlight() { return { night: 1, dawn: 0.25, day: 0, afternoon: 0, dusk: 0.45 }[SN.settings.sky()]; },
};

/// How hard the whole game is (the same five modes as on the iPad).
SN.difficulty = {
  names: ['Easy', 'Mild', 'Hard', 'Chaos', 'No Mercy'],
  colors: ['#40b366', '#5973d9', '#e68026', '#cc3340', '#730d33'],
  about: [
    ['Slower hazards, quieter steps, longer clock', "You're faster and jump a little higher", "Mom and Dad can't check hiding places", 'Codes are just 3 numbers; fewer dogs and keys', '10 taunts to wake Mom; Dad laughs for a whole minute'],
    ['The game as it has always been', 'The main difficulty'],
    ['Hazards are faster and hurt more', 'More to collect', 'A slightly shorter clock', 'Boosts and orbs turn up more often'],
    ['Everything in Hard, but worse', 'Mom and Dad move at 75% of your speed', 'Hiding never works: they always find you'],
    ['Everything in Chaos, plus:', 'A very short clock, and Mom outruns you', 'Hurts much more; water puddles in Levels 2–3', 'Boxes and drawers can be traps (50-50)', 'The Guide really gets things wrong', 'No practice mode until you win the level'],
  ],
  get current() { return SN.clamp(SN.settings.difficulty | 0, 0, 4); },
  get name() { return this.names[this.current]; },
  pick(easy, mild, hard) { const d = this.current; return d === 0 ? easy : d === 1 ? mild : hard; },
  get timeScale() { return [1.4, 1, 0.85, 0.85, 0.5][this.current]; },
  get hazardSpeed() { return [0.6, 1, 1.3, 1.6, 1.8][this.current]; },
  get damageScale() { return [1, 1, 1.5, 2, 3.5][this.current]; },
  get playerSpeed() { return this.current === 0 ? 1.15 : 1; },
  get playerJump() { return this.current === 0 ? 1.06 : 1; },
  get quiet() { return this.current === 0 ? 1.5 : 1; },
  get tauntNoise() { return this.current === 0 ? 18 : 34; },
  get dadLaugh() { return this.current === 0 ? 60 : 10; },
  get lootScale() { return [1, 1, 1.5, 2, 3][this.current]; },
  /// Chaos: always 75% of your speed. No Mercy: faster than you.
  chaserSpeed(base, yours) { const d = this.current; return d === 3 ? yours * 0.75 : d === 4 ? Math.max(base, yours * 1.12) : base; },
};
