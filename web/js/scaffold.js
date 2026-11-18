// Everything around a level's room: the scaled, scrolling stage on the canvas, the top bar with
// the clock and noise meter, the backpack, the joystick and buttons, speech bubbles, pop-ups
// and the pause menu. (A port of LevelScaffold.swift.)
//
// A level is an object with: engine, belt, chase (optional), title(), inventory, popup, banner,
// cornerHint(), drawWorld(ctx, floor), retry(), hint(), and optionally overlay() for extra panels.

SN.LevelRunner = class {
  constructor(game, level, { onHome }) {
    this.game = game;
    this.level = level;
    this.engine = level.engine;
    this.onHome = onHome;
    this.canvas = document.getElementById('stage');
    // Opaque: the room always covers it, so the browser never blends it with the page behind.
    this.ctx = this.canvas.getContext('2d', { alpha: false });
    // How many canvas pixels per screen point. Starts sharp and drops a step at a time if the
    // device can't keep up (see tune); remembered for the rest of the visit.
    this.renderScale = Math.min(SN.LevelRunner.renderScale ?? 2, SN.LevelRunner.sharpest());
    this.tuning = { gaps: [], total: 0, warm: false, before: null, prev: null };
    this.ui = document.getElementById('ui');
    this.pauseOpen = false;
    this.alive = true;
    this.last = SN.now();
    this.shown = {};
    this.buildHud();
    const e = this.engine;
    e.onPause = () => this.setPause(!this.pauseOpen);
    e.onMenuKey = k => { if (k === 'menu') this.home(); if (k === 'restart') this.level.retry(); if (k === 'hint') this.level.hint(); };
    this.resize = () => this.layout();
    window.addEventListener('resize', this.resize);
    // The stage is the screen above the controls; their height changes when item buttons appear.
    const controls = this.v('controls');
    if (controls && window.ResizeObserver) { this.watch = new ResizeObserver(() => this.measureStage()); this.watch.observe(controls); }
    this.layout();
    e.running = true;
    requestAnimationFrame(() => this.frame());
  }

  home() { this.stop(); this.onHome(); }

  stop() {
    this.alive = false;
    this.engine.running = false;
    window.removeEventListener('resize', this.resize);
    if (this.watch) this.watch.disconnect();
    this.hud.remove();
  }

  // ---------- HUD (HTML on top of the canvas) ----------
  buildHud() {
    const s = SN.settings;
    const touch = s.showTouch();
    const k = s.keyLabels;
    const lab = name => k ? `<span class="key">${SN.label(name)}</span>` : '';
    this.touch = touch;
    this.hud = SN.el(`
      <div class="hud">
        <div class="topbar">
          <button class="round press" data-a="pause">⏸${lab('pause')}</button>
          <button class="round press" data-a="home">🏠${lab('menu')}</button>
          <button class="round press" data-a="restart">↻${lab('restart')}</button>
          <div class="spacer"></div>
          <div class="title-pill" data-v="title"></div>
          <div class="mid">
            <div class="pill timer" data-v="timer"></div>
            <div class="pill" data-v="hp" style="display:none"></div>
            <div class="pill" data-v="noise" style="opacity:0">🔊 <span class="meter" style="display:inline-block;vertical-align:middle"><i></i></span></div>
          </div>
          <div class="spacer"></div>
          <button class="round press" data-a="hint">💡${lab('hint')}</button>
        </div>
        <div class="backpack" data-v="pack"></div>
        <div class="pill corner-hint" data-v="corner" style="display:none"></div>
        <div data-v="banner"></div>
        ${touch ? this.controlsHtml(lab) : `<div class="pill" style="position:absolute;right:16px;bottom:12px;font-size:14px;opacity:.75">W A S D move · E use · Space jump · C crouch · R carry · T taunt · P pause</div>`}
        <div data-v="overlay"></div>
        <div data-v="popup"></div>
        <div data-v="pause"></div>
      </div>`);
    this.ui.appendChild(this.hud);
    // The HUD's parts, looked up once.
    const parts = {};
    this.v = name => name in parts ? parts[name] : (parts[name] = this.hud.querySelector(`[data-v="${name}"]`));
    this.hud.querySelectorAll('[data-a]').forEach(b => b.addEventListener('click', () => {
      SN.sound.tap();
      const a = b.dataset.a;
      if (a === 'pause') this.setPause(true);
      if (a === 'home') this.home();
      if (a === 'restart') this.level.retry();
      if (a === 'hint') this.level.hint();
    }));
    if (touch) this.wireControls();
  }

  controlsHtml(lab) {
    const swap = SN.settings.swapSides;
    const stick = `<div class="joystick" data-v="stick">${SN.settings.keyLabels ? '<span class="dir" style="left:50%;top:6px;transform:translateX(-50%)">W</span><span class="dir" style="left:8px;top:50%;transform:translateY(-50%)">A</span><span class="dir" style="left:50%;bottom:6px;transform:translateX(-50%)">S</span><span class="dir" style="right:8px;top:50%;transform:translateY(-50%)">D</span>' : ''}<div class="knob"></div></div>`;
    const btn = (a, icon, cls, color) => `<div class="action ${cls}" data-b="${a}" style="background:${color}">${icon}${lab(a)}</div>`;
    const buttons = `
      <div class="buttons">
        <div class="btn-grid" data-v="small">
          ${btn('taunt', '😜', 'small', '#ff2d55')}${btn('crouch', '⤓', 'small', '#59595e')}${btn('carry', '📦', 'small', '#30b0c7')}
          ${btn('run', '🏃', 'small', '#59595e')}${btn('dash', '💨', 'small', '#32ade6')}
        </div>
        ${btn('jump', '⬆', 'mid', '#007aff')}
        <div style="position:relative">${btn('use', '✋', 'large', '#8e8e93')}<div class="prompt" data-v="prompt" style="display:none"></div></div>
      </div>`;
    const items = `<div class="btn-grid" data-v="items" style="grid-template-columns:repeat(3,auto)"></div>`;
    return `<div class="controls${window.innerHeight < 520 ? ' floating' : ''}" data-v="controls">${swap ? buttons + items + stick : stick + items + buttons}</div>`;
  }

  wireControls() {
    const e = this.engine;
    const stick = this.v('stick'), knob = stick.querySelector('.knob');
    let id = null;
    const move = ev => {
      const r = stick.getBoundingClientRect();
      const radius = r.width * 0.36;
      let dx = ev.clientX - (r.left + r.width / 2), dy = ev.clientY - (r.top + r.height / 2);
      const len = Math.hypot(dx, dy);
      if (len > radius) { dx *= radius / len; dy *= radius / len; }
      knob.style.transform = `translate(${dx}px,${dy}px)`;
      e.stick = { x: dx / radius, y: dy / radius };
    };
    stick.addEventListener('pointerdown', ev => { id = ev.pointerId; stick.setPointerCapture(id); move(ev); });
    stick.addEventListener('pointermove', ev => { if (ev.pointerId === id) move(ev); });
    const end = ev => { if (ev.pointerId !== id) return; id = null; knob.style.transform = ''; e.stick = { x: 0, y: 0 }; };
    stick.addEventListener('pointerup', end); stick.addEventListener('pointercancel', end);
    this.wireButtons(this.hud);
  }

  wireButtons(root) {
    const e = this.engine;
    root.querySelectorAll('[data-b]').forEach(b => {
      if (b.dataset.wired) return;
      b.dataset.wired = '1';
      // Buttons act the instant your finger touches them, so jumps never wait.
      b.addEventListener('pointerdown', ev => {
        ev.preventDefault();
        b.classList.add('down');
        const a = b.dataset.b;
        if (a === 'use') { if (this.level.popup) this.confirmPopup(); else e.interact(); }
        if (a === 'jump') e.jump();
        if (a === 'crouch') e.toggleCrouch();
        if (a === 'carry') e.moveObject();
        if (a === 'taunt') e.taunt();
        if (a === 'dash') e.dash();
        if (a === 'run') e.runHeld = !e.runHeld;
        if (SN.items.includes(a) && this.level.belt) this.level.belt.use(a);
      });
      const up = () => b.classList.remove('down');
      b.addEventListener('pointerup', up); b.addEventListener('pointerleave', up); b.addEventListener('pointercancel', up);
    });
  }

  // ---------- Pop-ups and pause ----------
  confirmPopup() {
    const btn = this.v('popup').querySelector('[data-p="main"]');
    if (btn) btn.click();
  }

  showPopup(p) {
    const host = this.v('popup');
    host.innerHTML = '';
    if (!p) return;
    const el = SN.el(`
      <div class="overlay"><div class="popup">
        <div class="sym" style="color:${p.color || '#fff'}">${p.symbol || '⭐'}</div>
        <h2>${SN.esc(p.title)}</h2>
        <p>${SN.esc(p.message || '')}</p>
        <div class="row">
          ${p.secondButton ? `<button class="big gray press" data-p="second">${SN.esc(p.secondButton)}</button>` : ''}
          <button class="big press" data-p="main">${SN.esc(p.button)}</button>
        </div>
      </div></div>`);
    let used = false;
    // Each button only ever works once, however fast it's tapped (no duplicate keys).
    const once = fn => () => { if (used) return; used = true; SN.sound.tap(); fn(); };
    el.querySelector('[data-p="main"]').addEventListener('click', once(() => p.action()));
    const second = el.querySelector('[data-p="second"]');
    if (second) second.addEventListener('click', once(() => p.secondAction()));
    host.appendChild(el);
  }

  setPause(on) {
    this.pauseOpen = on;
    this.engine.paused = on;
    this.engine.stick = { x: 0, y: 0 };
    const host = this.v('pause');
    host.innerHTML = '';
    if (!on) return;
    const s = SN.settings;
    const el = SN.el(`
      <div class="overlay"><div class="popup" style="text-align:left;max-width:640px">
        <h2 style="text-align:center">⏸ Paused</h2><p style="text-align:center;margin:-4px 0 12px;opacity:.8">${SN.esc(this.level.title())}</p>
        <label class="set" ${s.practiceLocked ? 'style="opacity:.5"' : ''}><input type="checkbox" data-s="practice" ${s.practiceOn() ? 'checked' : ''} ${s.practiceLocked ? 'disabled' : ''}> ${s.practiceLocked ? 'Practice mode: locked on No Mercy until you win this level' : "Practice mode: Mom and Dad can't catch you"}</label>
        <label class="set">🔊 Master <input type="range" min="0" max="1" step="0.05" data-s="master" value="${s.master}"></label>
        <label class="set">🎵 Music <input type="range" min="0" max="1" step="0.05" data-s="music" value="${s.music}"></label>
        <label class="set">🔔 Effects <input type="range" min="0" max="1" step="0.05" data-s="effects" value="${s.effects}"></label>
        <div class="row" style="justify-content:center;margin-top:14px">
          <button class="big gray press" data-q="home">🏠 Menu</button>
          <button class="big press" style="--c:#594db3" data-q="restart">↻ Restart</button>
          <button class="big press" data-q="resume">▶ Resume</button>
        </div>
      </div></div>`);
    el.querySelectorAll('[data-s]').forEach(inp => inp.addEventListener('input', () => {
      s[inp.dataset.s] = inp.type === 'checkbox' ? inp.checked : parseFloat(inp.value);
      s.save();
    }));
    el.querySelectorAll('[data-q]').forEach(b => b.addEventListener('click', () => {
      SN.sound.tap();
      const q = b.dataset.q;
      this.setPause(false);
      if (q === 'home') this.home();
      if (q === 'restart') this.level.retry();
    }));
    host.appendChild(el);
  }

  // ---------- Layout and drawing ----------
  layout() {
    const s = this.renderScale;
    this.canvas.width = Math.round(window.innerWidth * s);
    this.canvas.height = Math.round(window.innerHeight * s);
    this.dpr = s;
    this.measureStage();
  }

  measureStage() {
    const controls = this.v('controls');
    const floating = !controls || controls.classList.contains('floating');
    this.stageH = floating ? window.innerHeight : window.innerHeight - controls.getBoundingClientRect().height;
  }

  /// The sharpest the canvas is drawn: the screen's own pixels, but never more than 2 per point
  /// (on phones with 3, a third more pixels to fill would look the same).
  static sharpest() { return Math.min(Math.max(window.devicePixelRatio || 1, 1), 2); }

  /// Keeps the game smooth on slower devices. Every second or so, looks at how long frames take;
  /// if they're slow (under about 50 a second), draws the canvas a step less sharp (fewer pixels to
  /// fill, which is what costs the most). If a step doesn't make frames faster (the browser is
  /// holding them back, as in Low Power Mode), it goes back and stops trying.
  tune(gap) {
    const T = this.tuning;
    if (SN.LevelRunner.tuned || this.pauseOpen || this.level.popup || gap > 0.25) return;
    T.gaps.push(gap); T.total += gap;
    if (T.total < 1.2 || T.gaps.length < 20) return;
    // The average frame, leaving out the slowest few (a hiccup isn't a slow device).
    const sorted = T.gaps.sort((a, b) => a - b).slice(0, Math.ceil(T.gaps.length * 0.95));
    const avg = sorted.reduce((a, b) => a + b, 0) / sorted.length;
    T.gaps = []; T.total = 0;
    if (!T.warm) { T.warm = true; return; }   // the first second of a level is setting up
    if (T.before !== null) {
      const helped = avg < T.before * 0.93;
      T.before = null;
      if (!helped) { this.setRenderScale(T.prev); SN.LevelRunner.tuned = true; return; }
    }
    if (avg > 0.02 && this.renderScale > 1) {
      T.before = avg; T.prev = this.renderScale;
      this.setRenderScale(Math.max(1, this.renderScale - 0.25));
    }
  }

  setRenderScale(s) {
    this.renderScale = s;
    SN.LevelRunner.renderScale = s;
    this.layout();
  }

  frame() {
    if (!this.alive) return;
    const now = SN.now();
    const gap = now - this.last;
    const dt = Math.min(gap, 1 / 20);
    this.last = now;
    this.tune(gap);
    this.engine.step(dt);
    if (this.level.belt) this.level.belt.tick(this.engine.running ? dt : 0);
    this.draw(now);
    this.updateHud();
    requestAnimationFrame(() => this.frame());
  }

  draw(t) {
    const ctx = this.ctx, e = this.engine;
    const W = window.innerWidth;
    const stageH = this.stageH;
    const cropTop = 80, roomH = 700 - cropTop;
    // Fit the room's height; show more of the room's width when the screen is wide.
    const scale = Math.min(stageH / roomH, W / 760);
    const viewW = W / scale;
    this.viewWidth = viewW;
    const cam = e.width > viewW ? SN.clamp(e.player.x - viewW / 2, 0, e.width - viewW) : -(viewW - e.width) / 2;
    const camY = e.height > 700 ? SN.clamp(e.player.y - 430, -80, e.height - 700) : 0;
    const offY = Math.max(0, (stageH - roomH * scale) / 2);
    this.cam = { x: cam, y: camY, scale, offY };

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.setTransform(this.dpr * scale, 0, 0, this.dpr * scale, 0, this.dpr * offY);
    ctx.translate(-cam, -cropTop - camY);
    ctx.save();
    ctx.beginPath(); ctx.rect(0, cropTop + camY, e.width, roomH); ctx.clip();
    this.level.drawWorld(ctx, t, this);
    // The sky's colour over the room (darker at night).
    const [r, g, b, amount] = SN.palette.shade();
    const strength = (this.level.shadeAmount ?? 0.22) * amount;
    // Only over the part of the room on screen, and not at all when there's nothing to see.
    if (strength > 0.004) {
      ctx.fillStyle = SN.rgb(r, g, b, strength);
      ctx.fillRect(Math.max(0, cam), cropTop + camY, Math.min(e.width, viewW + 2), roomH);
    }
    if (e.bubble) SN.people.speech(ctx, SN.clamp(e.player.x, cam + 170, cam + viewW - 170), Math.max(e.player.y - e.z - 205, camY + cropTop + 150), e.bubble, SN.colors.gold, false);
    ctx.restore();
  }

  /// Draws floor things, you and anyone else in back-to-front order (lower on the screen is in front).
  /// `extra` is a list of { y, draw(ctx) } for characters the level adds.
  drawFloor(ctx, t, drawThing, extra = []) {
    const e = this.engine;
    const left = this.cam.x - 260, right = this.cam.x + this.viewWidth + 260;
    const list = e.things.filter(th => SN.onFloor(th) && !th.hidden && th.x > left && th.x < right)
      .map(th => ({ y: th.flat ? -1 : th.y + th.sortOffset, draw: () => drawThing(th) }));
    const py = e.coverY !== null ? e.coverY - 1 : e.player.y;
    list.push({ y: py, draw: () => this.drawPlayer(ctx, t) });
    list.push(...extra);
    list.sort((a, b) => a.y - b.y);
    list.forEach(i => i.draw());
  }

  drawPlayer(ctx, t) {
    const e = this.engine, game = this.game;
    if (e.hidden) return;
    const range = e.floor[1] - e.floor[0];
    const depth = e.height > 700 ? 1 : 0.86 + (e.player.y - e.floor[0]) / Math.max(range, 1) * 0.2;
    const x = e.player.x, y = e.player.y;
    ctx.save();
    ctx.globalAlpha = (this.level.playerOpacity ?? 1) * (e.coverY !== null ? 0.55 : 1);
    SN.draw.ellipse(ctx, x, y + 6, 70 * depth * (1 - Math.min(e.z, 150) / 400), 16, 'rgba(0,0,0,.3)');
    if (e.flying) { SN.draw.ellipse(ctx, x, y - e.z + 10, 110, 34, '#fff'); SN.draw.circle(ctx, x - 26, y - e.z - 2, 46, '#fff'); SN.draw.circle(ctx, x + 8, y - e.z - 8, 56, '#fff'); }
    if (e.hurt) ctx.filter = 'sepia(1) saturate(4) hue-rotate(-40deg)';
    SN.people.character(ctx, x, y - e.z, game.look, {
      facingRight: e.facingRight, walking: e.walking && e.z === 0, crouching: e.crouching || e.ducking, taunting: e.taunting, scale: depth, t,
    });
    ctx.filter = 'none';
    if (SN.settings.nameTag && game.playerName) {
      ctx.font = '800 17px ui-rounded, system-ui'; const w = ctx.measureText(game.playerName).width + 20;
      const ty = y - e.z - (e.crouching || e.ducking ? 140 : 172) * depth;
      SN.draw.rrect(ctx, x, ty, w, 24, 12, 'rgba(0,0,0,.4)');
      SN.draw.text(ctx, game.playerName, x, ty + 1, 17, '#fff');
    }
    ctx.restore();
  }

  /// World position → screen position (for HTML things placed over the room).
  toScreen(x, y) {
    const c = this.cam;
    return { x: (x - c.x) * c.scale, y: (y - 80 - c.y) * c.scale + c.offY };
  }

  setText(name, text) {
    if (this.shown[name] === text) return;
    this.shown[name] = text;
    this.v(name).innerHTML = text;
  }

  /// Sets a style on a HUD element only when it changes (most frames nothing does, and every
  /// write makes the browser check the page again).
  put(el, prop, value) {
    const was = el._shown || (el._shown = {});
    if (was[prop] === value) return;
    was[prop] = value;
    el.style[prop] = value;
  }

  updateHud() {
    const e = this.engine, L = this.level;
    this.setText('title', SN.esc(L.title()));
    const whole = Math.ceil(e.timeLeft);
    const timer = this.v('timer');
    this.put(timer, 'display', e.showsClock ? '' : 'none');
    this.setText('timer', `⏱ ${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`);
    if ((timer._low ?? null) !== whole <= 10) { timer._low = whole <= 10; timer.classList.toggle('low', timer._low); }
    const hp = this.v('hp');
    this.put(hp, 'display', e.usesHP ? '' : 'none');
    if (e.usesHP) this.setText('hp', `❤️ ${Math.ceil(e.hp)}`);
    const noise = this.v('noise');
    this.put(noise, 'opacity', e.noise > 1 ? '1' : '0');
    const bar = this.bar || (this.bar = noise.querySelector('i'));
    this.put(bar, 'width', Math.round(e.noise) + '%');
    this.put(bar, 'background', e.noise > 70 ? '#ff3b30' : e.noise > 40 ? '#ff9500' : '#34c759');
    // Backpack
    const inv = L.inventory || [];
    const packKey = inv.map(i => i.id).join(',');
    if (this.shown.pack !== packKey) {
      this.shown.pack = packKey;
      const slots = Math.max(3, inv.length);
      let html = '🎒';
      for (let i = 0; i < slots; i++) {
        const it = inv[i];
        html += `<div class="slot" ${it ? `data-item="${it.id}" style="color:${it.color || '#fff'}"` : ''}>${it ? it.icon : ''}</div>`;
      }
      this.v('pack').innerHTML = html;
      this.v('pack').querySelectorAll('[data-item]').forEach(s => s.addEventListener('click', () => L.inventoryTap && L.inventoryTap(s.dataset.item)));
    }
    const corner = L.cornerHint ? L.cornerHint() : null;
    const ch = this.v('corner');
    this.put(ch, 'display', corner ? '' : 'none');
    if (corner) this.setText('corner', SN.esc(corner));
    // Banner
    const banner = L.banner || '';
    if (this.shown.banner !== banner) {
      this.shown.banner = banner;
      this.v('banner').innerHTML = banner ? `<div class="banner ${banner.startsWith('Checkpoint') ? 'good' : ''}">${SN.esc(banner)}</div>` : '';
    }
    // Pop-up
    if (this.shown.popup !== L.popup) { this.shown.popup = L.popup; this.showPopup(L.popup); }
    // Extra panels (keypad, talking...)
    const ov = L.overlayKey ? L.overlayKey() : null;
    if (this.shown.overlay !== ov) {
      this.shown.overlay = ov;
      const host = this.v('overlay');
      host.innerHTML = '';
      if (ov && L.overlay) { const el = L.overlay(); if (el) { host.appendChild(el); this.wireButtons(el); } }
    }
    if (!this.touch) return;
    // Buttons: E lights up when there's something to do; run and dash only once learned.
    const prompt = e.currentPrompt;
    const p = this.v('prompt');
    this.put(p, 'display', prompt ? '' : 'none');
    if (prompt) this.setText('prompt', `${SN.keys.use[1]} · ${SN.esc(prompt)}`);
    const b = this.buttons || (this.buttons = Object.fromEntries(['use', 'run', 'dash', 'crouch'].map(n => [n, this.hud.querySelector(`[data-b="${n}"]`)])));
    this.put(b.use, 'background', prompt || L.popup ? SN.colors.button : '#8e8e93');
    this.put(b.run, 'display', e.canRun ? '' : 'none');
    this.put(b.run, 'background', e.runHeld ? '#34c759' : '#59595e');
    this.put(b.dash, 'display', e.canDash ? '' : 'none');
    this.put(b.crouch, 'background', e.ducking ? '#af52de' : '#59595e');
    const belt = L.belt;
    const owned = belt ? belt.owned.join(',') : '';
    if (this.shown.items !== owned) {
      this.shown.items = owned;
      const lab = n => SN.settings.keyLabels ? `<span class="key">${SN.label(n)}</span>` : '';
      this.v('items').innerHTML = (belt ? belt.owned : []).map(n => `<div class="action small" data-b="${n}" style="background:${SN.itemInfo[n].color}">${SN.itemInfo[n].icon}${lab(n)}</div>`).join('');
      this.wireButtons(this.v('items'));
    }
  }
};

/// Shared pop-up wrapper for levels: shows it, pauses the game, and resumes when a button is pressed.
SN.levelShow = function (level, popup) {
  level.engine.running = false;
  const close = () => { level.popup = null; level.engine.crouching = false; level.engine.running = level.over !== true; };
  level.popup = Object.assign({}, popup, {
    action: () => { close(); popup.action && popup.action(); },
    secondAction: () => { close(); popup.secondAction && popup.secondAction(); },
  });
};
