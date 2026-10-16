// The menu screens (HTML over the starry canvas): title, Customize Character, levels, badges,
// difficulty, settings and save files. (A port of MenuScreens.swift and MoreMenus.swift.)

SN.menus = (function () {
  const tile = (id, icon, title, color) => `<div class="tile press" data-go="${id}" style="--c:${color}"><span class="icon">${icon}</span>${title}</div>`;
  const back = '<button class="round press back" data-go="title">‹</button>';

  function wire(el, go) {
    el.querySelectorAll('[data-go]').forEach(b => b.addEventListener('click', () => { SN.sound.tap(); go(b.dataset.go); }));
    return el;
  }

  function title(game, go) {
    const next = game.nextLevel;
    const play = !game.hasCharacter ? 'Play' : next ? (next === 1 && !game.completedLevels.length ? 'Play' : `Continue · Level ${next}`) : 'Play Again';
    const el = SN.el(`
      <div class="screen" style="justify-content:center">
        <canvas data-hero width="260" height="300" style="position:absolute;left:4vw;bottom:2vh;width:min(26vw,260px)"></canvas>
        <h1 style="font-size:clamp(40px,9vw,88px);text-shadow:4px 5px 0 #a020f0">Sneeky Night</h1>
        <p class="lead">Solve the puzzles. Sneak out of every room.</p>
        <div class="menu-col">
          <div class="menu-btn big-play press" data-go="play" style="--c:${SN.colors.button}"><span class="icon">▶</span>${play}<span class="chev">›</span></div>
          <button class="chip-difficulty press" data-go="difficulty" style="--c:${SN.difficulty.colors[SN.difficulty.current]}">Difficulty: ${SN.difficulty.name} ›</button>
          <div class="tiles">
            ${tile('levels', '🗺', 'Levels', '#594db3')}${tile('customize', '👕', 'Customize', '#338c99')}${tile('badges', '🏅', `Badges ${game.badges.length}/${SN.badges.length}`, '#b36633')}
            ${tile('saves', '📁', 'Save Files', '#4d734d')}${tile('settings', '⚙️', 'Settings', '#666b80')}${tile('about', '📰', 'About', '#8c4d8c')}
          </div>
        </div>
        ${game.hasCharacter ? `<p class="lead" style="margin-top:12px">Playing as ${SN.esc(game.playerName)}</p>` : ''}
      </div>`);
    // The hero, bobbing gently.
    const cv = el.querySelector('[data-hero]');
    const draw = () => {
      if (!cv.isConnected) return;
      const ctx = cv.getContext('2d');
      ctx.clearRect(0, 0, 260, 300);
      const bob = Math.sin(SN.now() * 2.2) * 4;
      if (game.hasCharacter) SN.people.character(ctx, 130, 280 + bob, game.look, { scale: 1.5 });
      else { SN.people.character(ctx, 80, 280 + bob, SN.look.starter('boy'), { scale: 1.3 }); SN.people.character(ctx, 185, 280 - bob, SN.look.starter('girl'), { scale: 1.3, facingRight: false }); }
      requestAnimationFrame(draw);
    };
    requestAnimationFrame(draw);
    return wire(el, go);
  }

  function customize(game, go, { onDone }) {
    const look = JSON.parse(JSON.stringify(game.look));
    let name = game.playerName;
    const el = SN.el(`
      <div class="screen">
        ${back}
        <h1>Customize Character</h1>
        <div class="row" style="align-items:flex-start;justify-content:center;width:100%;gap:24px">
          <div style="text-align:center"><canvas data-preview width="300" height="380" style="width:240px"></canvas>
            <div><button class="big press" data-done>Let's go!</button></div></div>
          <div data-opts style="display:flex;flex-direction:column;gap:12px;max-width:640px"></div>
        </div>
      </div>`);
    const opts = el.querySelector('[data-opts]');
    const section = (label, inner) => { const s = SN.el(`<div class="card" style="width:auto"><h3>${label}</h3><div class="row"></div></div>`); s.querySelector('.row').append(...inner); opts.appendChild(s); };
    const chip = (text, on, fn) => { const b = SN.el(`<button class="chip press ${on() ? 'on' : ''}">${SN.esc(text)}</button>`); b.addEventListener('click', () => { SN.sound.tap(); fn(); render(); }); b._on = on; return b; };
    const swatch = (color, on, fn) => { const b = SN.el(`<div class="swatch press ${on() ? 'on' : ''}" style="background:${color || 'transparent'};${color ? '' : 'border-style:dashed'}">${color ? '' : '⦸'}</div>`); b.addEventListener('click', () => { SN.sound.tap(); fn(); render(); }); b._on = on; return b; };
    const nameInput = SN.el(`<input type="text" maxlength="12" placeholder="Type a name" value="${SN.esc(name)}">`);
    nameInput.addEventListener('input', () => name = nameInput.value);
    section('Name', [nameInput]);
    section('Boy or girl', [chip('Boy', () => look.gender === 'boy', () => look.gender = 'boy'), chip('Girl', () => look.gender === 'girl', () => look.gender = 'girl')]);
    section('Hair style', SN.look.hairStyles.map((h, i) => chip(h, () => look.hair === i, () => look.hair = i)));
    section('Hair colour', SN.look.hairColors.map((c, i) => swatch(c || SN.rgb(0.4, 0.24, 0.13), () => look.hairColor === i, () => look.hairColor = i)));
    section('Skin tone', SN.look.skins.map((c, i) => swatch(c, () => look.skin === i, () => look.skin = i)));
    const shirts = game.extraColors ? SN.look.shirts.length : SN.look.baseShirts;
    section('Top', SN.look.shirtStyles.map((s, i) => chip(s, () => look.shirtStyle === i, () => look.shirtStyle = i)));
    section('Top colour', SN.look.shirts.slice(0, shirts).map((c, i) => swatch(c, () => look.shirt === i, () => look.shirt = i)));
    section('Picture on the top', SN.look.patterns.map((p, i) => chip({ star: '★', heart: '♥', bolt: '⚡', moon: '☾', paw: '🐾' }[p] || 'None', () => look.pattern === i, () => look.pattern = i)));
    section('Trousers', [chip('Match top', () => look.pants === -1, () => look.pants = -1)].concat(SN.look.pants.map((c, i) => swatch(c, () => look.pants === i, () => look.pants = i))));
    section('Shoes', SN.look.shoes.map((c, i) => swatch(c, () => look.shoes === i, () => look.shoes = i)));
    section('Eyes', SN.look.eyes.map((c, i) => swatch(c, () => look.eyes === i, () => look.eyes = i)));
    section('Usual face', SN.look.moods.map((m, i) => chip(m, () => look.face === i, () => look.face = i)));
    section('Cheeks', [chip('Blush', () => look.blush !== false, () => look.blush = look.blush === false), chip('Freckles', () => !!look.freckles, () => look.freckles = !look.freckles)]);
    const caps = game.extraColors ? SN.look.caps.length : SN.look.baseCaps;
    section('Cap', SN.look.caps.slice(0, caps).map((c, i) => swatch(c, () => look.cap === i, () => look.cap = i)));
    const owned = SN.accessories.filter(a => game.accessories.includes(a.id));
    section(`Accessories (find them in boxes!) ${owned.length}/${SN.accessories.length}`,
      [chip('None', () => !look.accessory, () => look.accessory = null)].concat(owned.map(a => chip(`${SN.accessoryIcon[a.family] || ''} ${a.name}`, () => look.accessory === a.id, () => look.accessory = a.id))));
    const boosts = SN.allBoosts().filter(b => game.boosts.includes(b.id));
    if (boosts.length) section('Boosts (they stack)', boosts.map(b => chip(`${b.icon} ${b.name}: ${look.boosts.includes(b.id) ? 'ON' : 'OFF'}`, () => look.boosts.includes(b.id),
      () => look.boosts = look.boosts.includes(b.id) ? look.boosts.filter(x => x !== b.id) : look.boosts.concat([b.id]))));
    const render = () => {
      opts.querySelectorAll('.chip, .swatch').forEach(b => { if (b._on) b.classList.toggle('on', b._on()); });
      opts.querySelectorAll('.chip').forEach(b => { const m = b.textContent.match(/^(.*): (ON|OFF)$/); if (m) { const boost = SN.allBoosts().find(x => b.textContent.includes(x.name)); if (boost) b.textContent = `${boost.icon} ${boost.name}: ${look.boosts.includes(boost.id) ? 'ON' : 'OFF'}`; } });
    };
    const cv = el.querySelector('[data-preview]');
    const draw = () => {
      if (!cv.isConnected) return;
      const ctx = cv.getContext('2d');
      ctx.clearRect(0, 0, 300, 380);
      SN.draw.ellipse(ctx, 150, 360, 220, 46, 'rgba(255,255,255,.15)');
      SN.people.character(ctx, 150, 360, look, { scale: 2.1 });
      requestAnimationFrame(draw);
    };
    requestAnimationFrame(draw);
    el.querySelector('[data-done]').addEventListener('click', () => {
      SN.sound.tap();
      const trimmed = name.trim();
      if (!trimmed) { nameInput.focus(); nameInput.placeholder = 'Type a name first!'; return; }
      game.playerName = trimmed; game.look = look; game.hasCharacter = true; game.save(); game.checkName();
      onDone();
    });
    return wire(el, go);
  }

  function levels(game, go, { onPick }) {
    const el = SN.el(`<div class="screen">${back}<h1>Levels</h1>
      <p class="lead">${game.nextLevel ? 'Win each level to unlock the next one.' : SN.levels.some(l => l.ready && !game.completedLevels.includes(l.id)) ? 'Level 7 has an entry fee: tap it to see what it needs.' : 'You won every level so far! More rooms are coming to the web version soon.'}</p>
      <div class="levels"></div></div>`);
    const grid = el.querySelector('.levels');
    const G = SN.GameState;
    SN.levels.forEach(l => {
      const open = game.isUnlocked(l), done = game.completedLevels.includes(l.id);
      // Level 7 after Level 6: open the gate (badges and orbs) instead.
      const gated = l.id === 7 && l.ready && !open && game.completedLevels.includes(6);
      const b = SN.el(`<button class="level press ${open ? '' : 'locked'} ${gated ? 'gated' : ''}"><span class="num">${l.id}</span><span>${open ? l.icon : gated ? '🔓' : '🔒'}</span>
        <span>${l.ready ? l.room : 'Coming soon'}</span>${gated ? `<small class="fee">${G.level7Badges} badges · ${G.level7Price} orbs</small>` : ''}${done ? '<span class="star">★</span>' : ''}</button>`);
      if (open) b.addEventListener('click', () => { SN.sound.tap(); onPick(l.id); });
      if (gated) b.addEventListener('click', () => { SN.sound.tap(); el.appendChild(gate()); });
      grid.appendChild(b);
    });
    /// Level 7 is the first level with an entry fee: 32 badges, and 10 orbs paid once.
    const gate = () => {
      const ready = game.level7Requirements.every(r => r[1]);
      const g = SN.el(`<div class="overlay"><div class="popup" style="text-align:left;max-width:620px">
        <h2>💧 Level 7 · Auntie's Backyard</h2>
        <p>Auntie's backyard is behind a gate. To get in you need:</p>
        ${game.level7Requirements.map(([text, met]) => `<p style="margin:4px 0;font-size:20px">${met ? '✅' : '⚪️'} ${SN.esc(text)}</p>`).join('')}
        <p style="font-size:15px;opacity:.65;margin-top:10px">Orbs come from the dungeon (Side Level 2) and the cinema (Side Level 4).</p>
        <div class="row" style="justify-content:flex-start;gap:12px"><button class="big press" data-g="no" style="background:#8e8e93">Not now</button>
        ${ready ? `<button class="big press" data-g="pay">Pay ${G.level7Price} orbs</button>` : ''}</div></div></div>`);
      g.querySelector('[data-g="no"]').addEventListener('click', () => { SN.sound.tap(); g.remove(); });
      const pay = g.querySelector('[data-g="pay"]');
      if (pay) pay.addEventListener('click', () => { if (game.payForLevel7()) { SN.sound.play('unlock'); g.remove(); onPick(7); } });
      g.addEventListener('click', ev => { if (ev.target === g) g.remove(); });
      return g;
    };
    return wire(el, go);
  }

  function badges(game, go) {
    const el = SN.el(`<div class="screen">${back}<h1>Badges</h1><p class="lead">${game.badges.length} of ${SN.badges.length} earned</p><div class="badges"></div></div>`);
    const grid = el.querySelector('.badges');
    SN.badges.forEach(([id, name, how]) => {
      const got = game.has(id);
      grid.appendChild(SN.el(`<div class="badge ${got ? 'got' : ''}"><b>${got ? '🏅' : '🔒'} ${SN.esc(name)}</b><small>${SN.esc(how)}</small></div>`));
    });
    return wire(el, go);
  }

  function difficulty(game, go) {
    const el = SN.el(`<div class="screen">${back}<h1>Difficulty</h1>
      <p class="lead">Pick how hard the game is. It applies the next time a level starts.</p>
      <div class="row" style="justify-content:center;align-items:stretch" data-cards></div></div>`);
    const cards = el.querySelector('[data-cards]');
    const render = () => {
      cards.innerHTML = '';
      SN.difficulty.names.forEach((n, i) => {
        const on = SN.settings.difficulty === i;
        const c = SN.el(`<div class="card press" style="width:200px;cursor:pointer;background:linear-gradient(${SN.difficulty.colors[i]},rgba(0,0,0,.4));border:${on ? '4px solid #ffcc40' : '2px solid rgba(255,255,255,.25)'}">
          <h3 style="color:#fff">${n}</h3>${SN.difficulty.about[i].map(a => `<div style="font-size:14px;margin:4px 0">• ${a}</div>`).join('')}
          <div class="chip" style="margin-top:10px;text-align:center;${on ? 'background:#ffcc40;color:#000' : ''}">${on ? '✓ PLAYING' : 'Tap to pick'}</div></div>`);
        c.addEventListener('click', () => { SN.sound.tap(); SN.settings.difficulty = i; SN.settings.save(); render(); });
        cards.appendChild(c);
      });
    };
    render();
    return wire(el, go);
  }

  function settings(game, go) {
    const s = SN.settings;
    const el = SN.el(`<div class="screen">${back}<h1>Settings</h1>
      <div class="card"><h3>Sound</h3>
        <label class="set">🔊 Master volume <input type="range" min="0" max="1" step="0.05" data-s="master" value="${s.master}"></label>
        <label class="set">🎵 Music <input type="range" min="0" max="1" step="0.05" data-s="music" value="${s.music}"></label>
        <label class="set">🔔 Sound effects <input type="range" min="0" max="1" step="0.05" data-s="effects" value="${s.effects}"></label></div>
      <div class="card" style="margin-top:12px"><h3>The game's sky</h3><div class="row" data-group="skyMode"></div></div>
      <div class="card" style="margin-top:12px"><h3>Buttons</h3>
        <div class="row" data-group="touchControls" style="margin-bottom:8px"></div>
        <label class="set"><input type="checkbox" data-s="swapSides" ${s.swapSides ? 'checked' : ''}> Joystick on the right</label>
        <label class="set"><input type="checkbox" data-s="keyLabels" ${s.keyLabels ? 'checked' : ''}> Show key letters on buttons (E, Space, R...)</label></div>
      <div class="card" style="margin-top:12px"><h3>Other</h3>
        <label class="set"><input type="checkbox" data-s="nameTag" ${s.nameTag ? 'checked' : ''}> Show my name above my character</label>
        <label class="set"><input type="checkbox" data-s="practice" ${s.practice ? 'checked' : ''}> Practice mode (nobody can catch you)</label></div>
    </div>`);
    el.querySelectorAll('[data-s]').forEach(inp => inp.addEventListener('input', () => { s[inp.dataset.s] = inp.type === 'checkbox' ? inp.checked : parseFloat(inp.value); s.save(); }));
    const group = (name, choices) => {
      const row = el.querySelector(`[data-group="${name}"]`);
      const render = () => { row.innerHTML = ''; choices.forEach(([v, label]) => { const b = SN.el(`<button class="chip press ${s[name] === v ? 'on' : ''}">${label}</button>`); b.addEventListener('click', () => { SN.sound.tap(); s[name] = v; s.save(); render(); }); row.appendChild(b); }); };
      render();
    };
    group('skyMode', [[0, 'Night'], [1, 'Early morning'], [2, 'Real time']]);
    group('touchControls', [['auto', 'On-screen buttons: automatic'], ['on', 'Always'], ['off', 'Never (keyboard)']]);
    return wire(el, go);
  }

  function saves(game, go, { onPick, onNew }) {
    const el = SN.el(`<div class="screen">${back}<h1>Save Files</h1><p class="lead">Tap a file to play it. Make as many as you like.</p>
      <div class="badges" data-files></div><p><button class="big press" data-new>＋ New save file</button></p></div>`);
    const list = el.querySelector('[data-files]');
    SN.GameState.slots.forEach((slot, n) => {
      const sum = SN.GameState.summary(slot), on = slot === game.slot;
      const c = SN.el(`<div class="badge press ${on ? 'got' : ''}" style="cursor:pointer"><b>📁 File ${n + 1}${on ? ' · playing' : ''}</b>
        <small>${sum.name ? SN.esc(sum.name) : 'Empty'} · ${sum.levels} levels · ${sum.badges} badges</small></div>`);
      c.addEventListener('click', () => { SN.sound.tap(); onPick(slot); });
      list.appendChild(c);
    });
    el.querySelector('[data-new]').addEventListener('click', () => { SN.sound.tap(); onNew(); });
    return wire(el, go);
  }

  function about(game, go) {
    const el = SN.el(`<div class="screen">${back}<h1>About this version</h1>
      <div class="card"><h3>Sneeky Night for the web</h3>
        <p>This is the web version of Sneeky Night. It runs in any browser: on a computer, a tablet or a phone.</p>
        <p><b>Keyboard:</b> W A S D or the arrows to walk · E use · Space jump · C crouch · R carry · T taunt · Q dash · Shift run · V F G B X items · P pause · L hint · N restart · M menu</p>
        <p>It's being rebuilt level by level. So far: Levels 1 to 7 (with the Roof), Customize Character, badges, save files, difficulty and settings. Saves are kept in this browser only.</p></div></div>`);
    return wire(el, go);
  }

  return { title, customize, levels, badges, difficulty, settings, saves, about };
})();
