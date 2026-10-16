// Sound effects and music: the same .wav files as the iPad version (sounds/), played with <audio>
// so they also work when the game is opened straight from a folder.
SN.sound = (function () {
  const pools = {};
  let music = null;
  let unlocked = false;

  function pool(name) {
    if (!pools[name]) {
      // A few copies of each so quick repeats (footsteps, clicks) can overlap.
      pools[name] = [0, 1, 2].map(() => { const a = new Audio('sounds/' + name + '.wav'); a.preload = 'auto'; return a; });
    }
    return pools[name];
  }

  function play(name, volume = 1) {
    if (!unlocked) return;
    const s = SN.settings;
    const list = pool(name);
    const a = list.find(x => x.paused || x.ended) || list[0];
    try {
      a.volume = SN.clamp(volume * s.master * s.effects, 0, 1);
      a.currentTime = 0;
      const p = a.play();
      if (p && p.catch) p.catch(() => {});
    } catch (e) { /* the browser said no; carry on silently */ }
  }

  function updateMusic() {
    if (music) music.volume = SN.clamp(SN.settings.master * SN.settings.music * 0.6, 0, 1);
  }

  function startMusic() {
    if (music || !unlocked) return;
    music = new Audio('sounds/music.wav');
    music.loop = true;
    updateMusic();
    const p = music.play();
    if (p && p.catch) p.catch(() => { music = null; });
  }

  // Browsers only allow sound after the first tap or key press.
  function unlock() {
    if (unlocked) return;
    unlocked = true;
    startMusic();
  }
  ['pointerdown', 'keydown', 'touchstart'].forEach(ev => window.addEventListener(ev, unlock, { once: false, passive: true }));

  return { play, updateMusic, startMusic, tap: () => play('click', 0.7) };
})();
