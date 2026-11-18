// Starts the game and moves between screens: the menus, and the levels.
(function () {
  const ui = document.getElementById('ui');
  const canvas = document.getElementById('stage');
  let game = new SN.GameState(SN.GameState.currentSlot);
  let runner = null;
  let skyRunning = false;
  let playAfterCustomize = false;

  // ---------- Badge toasts ----------
  function wireToasts() {
    game.onToast = id => {
      const b = SN.badges.find(x => x[0] === id);
      if (!b) return;
      const t = SN.el(`<div class="toast">🏅 New badge: ${SN.esc(b[1])}<small>${SN.esc(b[2])}</small></div>`);
      document.body.appendChild(t);
      setTimeout(() => t.remove(), 3500);
    };
  }

  // ---------- The starry sky behind the menus ----------
  const stars = (() => { const r = SN.seeded(7); return Array.from({ length: 90 }, () => [r(), r() * 0.8, 1 + r() * 2.5, r() * 6]); })();
  function sky() {
    if (!skyRunning) return;
    const dpr = window.devicePixelRatio || 1;
    if (canvas.width !== Math.round(innerWidth * dpr)) { canvas.width = Math.round(innerWidth * dpr); canvas.height = Math.round(innerHeight * dpr); }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const W = innerWidth, H = innerHeight, t = SN.now();
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, SN.palette.skyTop()); g.addColorStop(1, SN.palette.skyBottom());
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    const light = SN.palette.starlight();
    for (const [x, y, r, ph] of stars) {
      ctx.globalAlpha = (0.45 + 0.55 * Math.abs(Math.sin(t * 0.8 + ph))) * light;
      SN.draw.circle(ctx, x * W, y * H, r * 2, '#fff');
    }
    ctx.globalAlpha = 1;
    // A shooting star every 7 seconds or so.
    const cycle = t % 7;
    if (cycle < 0.9 && light > 0.3) {
      const n = Math.floor(t / 7), sx = ((n * 0.37) % 0.6 + 0.1) * W, sy = ((n * 0.23) % 0.3 + 0.05) * H;
      const hx = sx + cycle * 380, hy = sy + cycle * 150;
      const lg = ctx.createLinearGradient(hx, hy, hx - 90, hy - 36);
      lg.addColorStop(0, `rgba(255,255,255,${0.9 * (1 - cycle)})`); lg.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.strokeStyle = lg; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(hx - 90, hy - 36); ctx.stroke();
    }
    // The moon (or sun), and the hill with the house.
    ctx.save(); ctx.shadowColor = SN.palette.moon(); ctx.shadowBlur = 40;
    SN.draw.circle(ctx, W * 0.36, Math.min(115, H * 0.16), Math.min(150, W * 0.13), SN.palette.moon()); ctx.restore();
    SN.draw.ellipse(ctx, W * 0.3, H + 70, W * 1.4, 360, SN.rgb(0.1, 0.22, 0.2));
    requestAnimationFrame(sky);
  }

  function showScreen(el) {
    if (runner) { runner.stop(); runner = null; }
    ui.innerHTML = '';
    ui.appendChild(el);
    if (!skyRunning) { skyRunning = true; requestAnimationFrame(sky); }
  }

  function go(where) {
    const M = SN.menus;
    switch (where) {
      case 'title': return showScreen(M.title(game, go));
      case 'play': return play();
      case 'levels': return showScreen(M.levels(game, go, { onPick: startLevel }));
      case 'customize': return showScreen(M.customize(game, go, { onDone: () => { if (playAfterCustomize) { playAfterCustomize = false; play(); } else go('title'); } }));
      case 'badges': return showScreen(M.badges(game, go));
      case 'difficulty': return showScreen(M.difficulty(game, go));
      case 'settings': return showScreen(M.settings(game, go));
      case 'about': return showScreen(M.about(game, go));
      case 'saves': return showScreen(M.saves(game, go, {
        onPick: slot => { switchTo(slot); go('title'); },
        onNew: () => { switchTo(SN.GameState.newSlot()); if (SN.GameState.slots.length >= 10) game.award('justInCase'); playAfterCustomize = false; go('customize'); },
      }));
    }
  }

  function switchTo(slot) {
    SN.GameState.currentSlot = slot;
    game = new SN.GameState(slot);
    wireToasts();
    game.awardLaunchBadges();
  }

  /// Play goes straight to the first level you haven't won.
  function play() {
    if (!game.hasCharacter) { playAfterCustomize = true; go('customize'); return; }
    const next = game.nextLevel;
    if (next) startLevel(next); else go('levels');
  }

  function startLevel(id) {
    const Level = SN['Level' + id];
    if (!Level) { go('levels'); return; }
    skyRunning = false;
    ui.innerHTML = '';
    const onExit = () => go('title');
    const onNext = () => { const n = SN['Level' + (id + 1)] ? id + 1 : null; if (n) startLevel(n); else go('levels'); };
    let level;
    const leave = fn => () => { if (runner) { runner.stop(); runner = null; } fn(); };
    level = new Level(game, { onExit: leave(onExit), onNext: leave(onNext) });
    runner = new SN.LevelRunner(game, level, { onHome: () => { runner = null; go('title'); } });
    // For testing from the browser console: SN.current.level is the level being played.
    SN.current = { game, level, runner };
  }
  // Also for testing: SN.startLevel(3) opens a level straight away.
  SN.startLevel = startLevel;

  wireToasts();
  game.awardLaunchBadges();
  // Stay on the menu for 10 minutes: the "boredom" badge.
  let menuSince = SN.now();
  setInterval(() => { if (runner) menuSince = SN.now(); else if (SN.now() - menuSince > 600) game.award('boredom'); }, 5000);
  go('title');
})();
