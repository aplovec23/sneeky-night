// Level 4 rules. Part 1 is a big hedge maze seen from above: water all 100 plants (walking close
// waters them) and shoo the pests that land every 25 seconds. Spiky vines block some paths — jump
// them. A radar station shows what's left. Dad checks the garden every 2 minutes: hide in a bush.
// One special bush gives you vines when shaken (a permanent item). When everything is watered and
// pest-free, go through the gate — but only while the dogs are away.
// Part 2, beyond the gate: find 3 keys and type the code ("Plants") to open the street gate.
// Every 10 plants adds 20 seconds to the clock. (A port of Level4Garden.swift.)

SN.hazards.vines = ['ouch', 'OUCH! The spiky vines got you, and you yelped!'];

SN.Level4 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.chase = new SN.Chase();
    this.run = 0;
    const e = this.engine, c = this.chase, G = SN.Level4;
    e.onInteract = i => this.interact(i);
    e.onHazard = i => this.bumped(i);
    e.onTimeUp = () => this.momWakes(false);
    e.onTooLoud = () => this.momWakes(true);
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTaunt = () => this.taunted();
    e.onTick = dt => this.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    this.belt.stun = (s, momOnly) => c.stun(s, momOnly);
    c.engine = e;
    c.entrance = () => this.area === 'maze' ? { x: G.center(0, 0).x - 60, y: G.center(0, 0).y, delay: 3 } : { x: 110, y: 600, delay: 4 };
    c.setBanner = b => this.banner = b;
    c.award = b => this.award(b);
    c.onCaught = (who, msg) => this.caught(who, msg);
    c.onGaveUp = who => this.gaveUp(who);
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    /// Wearing Auntie's Water Hose (from Level 7): every plant you water also waters the four nearest thirsty ones.
    this.hasHose = game.look.boosts.includes('waterHose');
    this.reset();
  }

  /// On Easy the gate code is three numbers and there are only two keys to find.
  static get code() { return SN.difficulty.current === 0 ? '357' : 'Plants'; }
  static get codeHint() { return SN.difficulty.current === 0 ? 'The code is three numbers: 3, 5, 7' : 'The code hint is a green object that can grow'; }
  static get keysNeeded() { return SN.difficulty.current === 0 ? 2 : 3; }

  title() { return this.area === 'maze' ? 'Level 4 · Garden Maze' : 'Level 4 · Beyond the Gate'; }
  award(b) { if (b === 'oopsies') this.game.noteCaught(); else this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return this.phase === 'over'; }
  get allDone() { return this.watered >= SN.Level4.plantCount && this.pests === 0; }
  get inventory() { return Array.from({ length: this.keys }, (_, i) => ({ id: 'key' + i, icon: '🔑', color: SN.colors.gold })); }
  /// The little status line in the corner of the screen.
  cornerHint() { return this.area === 'maze' ? `🌱 Plants watered ${this.watered}/${SN.Level4.plantCount}   ·   🐞 Pests ${this.pests}` : SN.Level4.codeHint; }

  reset() {
    this.run++;
    const e = this.engine, G = SN.Level4;
    this.belt.reset();
    this.area = 'maze';
    this.keySpots = SN.shuffle(G.searchSpots).slice(0, G.keysNeeded);
    // Each run gets fresh copies of the maze's things (watering marks them).
    const things = G.built().things.map(t => Object.assign({}, t));
    e.load({ width: G.mazeW, height: G.mazeH, floor: [G.origin.y, G.origin.y + G.rows * G.cell.h], things, spawn: G.center(0, 0) });
    e.timeLeft = SN.levelTime(4); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.speedBonus = 0; e.runHeld = false; e.tauntOnly = false;
    this.chase.reset();
    this.chase.waypoint = (from, to) => G.nextStep(from, to);
    e.crouching = false; e.facingRight = true; e.bubble = null;
    Object.assign(this, {
      phase: 'sneaking', popup: null, banner: null, hidingIn: null, playerOpacity: 1,
      watered: 0, pests: 0, pestTime: 25, pestCount: 0, dogsHere: true, dogTime: 10, barkTime: 0, waterSound: 0,
      keys: 0, codeAccepted: false, gateOpen: false, showRadar: false, showKeypad: false,
      dadTime: 120, dadStage: 0, dadPause: 0, dadLaughed: false,
    });
    e.running = true;
    e.say("So many thirsty plants! Walking close waters them. The radar shows what's left.", 5);
  }

  // ---------- Building the maze ----------
  static center(c, r) { const G = SN.Level4; return { x: G.origin.x + (c + 0.5) * G.cell.w, y: G.origin.y + (r + 0.5) * G.cell.h }; }

  static cellOf(p) {
    const G = SN.Level4;
    return { c: SN.clamp(Math.floor((p.x - G.origin.x) / G.cell.w), 0, G.columns - 1), r: SN.clamp(Math.floor((p.y - G.origin.y) / G.cell.h), 0, G.rows - 1) };
  }

  /// Path-finding for whoever is chasing you: the next spot to walk to on the way from A to B
  /// without going through a hedge.
  static nextStep(a, b) {
    const G = SN.Level4, open = G.built().open, cols = G.columns;
    const start = G.cellOf(a), goal = G.cellOf(b);
    if (start.c === goal.c && start.r === goal.r) return b;
    // Search outward from the goal; the first neighbour that reaches `start` is the way to go.
    const cameFrom = new Map([[goal.c + goal.r * cols, -1]]);
    const queue = [goal];
    for (let head = 0; head < queue.length; head++) {
      const { c, r } = queue[head];
      if (c === start.c && r === start.r) break;
      const around = [];
      if (c + 1 < cols && open.has(`v ${c} ${r}`)) around.push({ c: c + 1, r });
      if (c > 0 && open.has(`v ${c - 1} ${r}`)) around.push({ c: c - 1, r });
      if (r + 1 < G.rows && open.has(`h ${c} ${r}`)) around.push({ c, r: r + 1 });
      if (r > 0 && open.has(`h ${c} ${r - 1}`)) around.push({ c, r: r - 1 });
      for (const n of around) if (!cameFrom.has(n.c + n.r * cols)) { cameFrom.set(n.c + n.r * cols, c + r * cols); queue.push(n); }
    }
    const next = cameFrom.get(start.c + start.r * cols);
    if (next === undefined || next < 0) return b;
    // Line up with the middle of the path first, so corners aren't cut through the hedges.
    const here = G.center(start.c, start.r);
    const sideways = Math.floor(next / cols) === start.r ? Math.abs(a.y - here.y) : Math.abs(a.x - here.x);
    return sideways > 30 ? here : G.center(next % cols, Math.floor(next / cols));
  }

  /// The same maze every time (so you can learn it), and the same one as on the iPad: a winding path with a few shortcuts.
  static built() {
    if (SN.Level4._built) return SN.Level4._built;
    const G = SN.Level4, cols = G.columns, rows = G.rows, cw = G.cell.w, ch = G.cell.h, o = G.origin;
    const rng = SN.Level4.seededRandom(4);
    // "v c r" = the slot between (c,r) and (c+1,r); "h c r" = between (c,r) and (c,r+1).
    const open = new Set();
    const visited = Array.from({ length: cols }, () => Array(rows).fill(false));
    const stack = [[0, 0]];
    visited[0][0] = true;
    while (stack.length) {
      const [c, r] = stack[stack.length - 1];
      const options = [];
      if (c + 1 < cols && !visited[c + 1][r]) options.push([c + 1, r, `v ${c} ${r}`]);
      if (c > 0 && !visited[c - 1][r]) options.push([c - 1, r, `v ${c - 1} ${r}`]);
      if (r + 1 < rows && !visited[c][r + 1]) options.push([c, r + 1, `h ${c} ${r}`]);
      if (r > 0 && !visited[c][r - 1]) options.push([c, r - 1, `h ${c} ${r - 1}`]);
      if (!options.length) { stack.pop(); continue; }
      const pick = options[Math.min(options.length - 1, Math.floor(rng() * options.length))];
      open.add(pick[2]); visited[pick[0]][pick[1]] = true; stack.push([pick[0], pick[1]]);
    }

    const things = [], passages = [], thick = 34;
    for (let c = 0; c < cols; c++) for (let r = 0; r < rows; r++) {
      if (c + 1 < cols) {
        const key = `v ${c} ${r}`, x = o.x + (c + 1) * cw, y = o.y + (r + 0.5) * ch;
        if (!open.has(key) && rng() < 0.16) open.add(key);
        if (open.has(key)) passages.push([key, x, y, true]);
        else things.push(SN.thing({ id: key, kind: 'hedge', x, y, fw: thick, fh: ch + thick, solid: true, sortOffset: (ch + thick) / 2 }));
      }
      if (r + 1 < rows) {
        const key = `h ${c} ${r}`, x = o.x + (c + 0.5) * cw, y = o.y + (r + 1) * ch;
        if (!open.has(key) && rng() < 0.16) open.add(key);
        if (open.has(key)) passages.push([key, x, y, false]);
        else things.push(SN.thing({ id: key, kind: 'hedge', x, y, fw: cw + thick, fh: thick, solid: true, sortOffset: thick / 2 }));
      }
    }
    // Spiky vines stretch right across some paths, so the only way past is to jump.
    passages.forEach(([key, x, y, upright], n) => {
      if (n % 6 !== 3 || key === 'v 0 0' || key === 'h 0 0') return;
      things.push(SN.thing({ id: 'vine ' + key, kind: 'spikyVine', x, y, fw: upright ? 30 : cw - thick + 14, fh: upright ? ch - thick + 14 : 26,
        hazard: 'vines', crouchSafe: false, flat: true }));
    });
    // 100 plants: one in every cell, and a second one in a quarter of them.
    let plants = 0;
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const p = G.center(c, r);
      plants++;
      things.push(SN.thing({ id: 'plant' + plants, kind: 'plant', x: p.x - 48, y: p.y - 18, fw: 30, fh: 16 }));
    }
    for (let n = 0; plants < G.plantCount; n++) {
      const p = G.center((n * 3) % cols, (n * 5) % rows);
      plants++;
      things.push(SN.thing({ id: 'plant' + plants, kind: 'plant', x: p.x + 48, y: p.y + 26, fw: 30, fh: 16 }));
    }
    [[2, 1], [6, 0], [8, 3], [4, 5], [1, 6], [7, 6], [3, 3], [9, 5], [5, 7]].forEach(([c, r], i) => {
      const p = G.center(c, r);
      things.push(SN.thing({ id: 'bush' + i, kind: 'bush', x: p.x + 50, y: p.y - 30, fw: 70, fh: 30, prompt: 'Hide in the bush', reachW: 70, reachH: 60 }));
    });
    const shaky = G.center(5, 2);
    things.push(SN.thing({ id: 'shakyBush', kind: 'shakyBush', x: shaky.x + 50, y: shaky.y - 30, fw: 70, fh: 30, prompt: 'Shake the strange bush', reachW: 70, reachH: 60 }));
    const radar = G.center(4, 3);
    things.push(SN.thing({ id: 'radar', kind: 'radar', x: radar.x - 50, y: radar.y + 34, fw: 50, fh: 24, prompt: 'Check the radar', reachW: 70, reachH: 70 }));
    const gate = G.center(cols - 1, rows - 1);
    things.push(SN.thing({ id: 'gate', kind: 'mazeGate', x: gate.x + 62, y: gate.y + 20, fw: 60, fh: 40, prompt: 'Go through the gate', reachW: 90, reachH: 90 }));
    SN.Level4._built = { things, open };
    return SN.Level4._built;
  }

  /// The iPad version's SeededRandom (a 64-bit LCG), so the maze comes out exactly the same.
  static seededRandom(seed) {
    const A = 6364136223846793005n, C = 1442695040888963407n, M = (1n << 64n) - 1n;
    let state = (BigInt(seed) * A + C) & M;
    return () => { state = (state * A + C) & M; return Number((state >> 33n) % 10000n) / 10000; };
  }

  static beyondThings() {
    const W = SN.Level2.onWall;
    const vine = (id, x) => SN.thing({ id, kind: 'spikyVine', x, y: 617, fw: 40, fh: 150, hazard: 'vines', crouchSafe: false, flat: true });
    return [
      W('backGate', 'backGate', 110, 'Look back at the maze'), W('bushA', 'bushWall', 300, 'Hide in the bush'),
      W('flowerPots', 'flowerPots', 480, 'Search the flower pots'), vine('vineA', 610),
      W('wheelbarrow', 'wheelbarrow', 740, 'Search the wheelbarrow', 80), W('birdhouse', 'birdhouse', 970, 'Search the birdhouse'),
      SN.Level2.obstacle('cans', 'cans', 1100, 650, 60, 26), W('well', 'well', 1230, 'Search the well', 80),
      W('compost', 'compost', 1490, 'Search the compost bin'), vine('vineB', 1620),
      W('scarecrow', 'scarecrow', 1750, 'Search the scarecrow'), W('bushB', 'bushWall', 1970, 'Hide in the bush'),
      W('streetGate', 'streetGate', 2250, 'Unlock the gate', 90),
    ];
  }

  show(p) { SN.levelShow(this, p); }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i];
    switch (th.kind) {
      case 'bush': case 'bushWall': return this.toggleHiding(th);
      case 'shakyBush': return this.shakeBush(i);
      case 'radar': SN.sound.play('beep'); e.running = false; this.showRadar = true; return;
      case 'pest':
        e.things.splice(i, 1);
        this.pests--;
        SN.sound.play('bug');
        e.say(SN.pick(['Shoo, bug!', 'Bye bye, beetle!', 'Off you go!']), 1.2);
        return this.checkDone();
      case 'mazeGate': return this.useMazeGate();
      case 'backGate': return e.say('No going back now. The street gate is at the other end!');
      case 'flowerPots': case 'wheelbarrow': case 'birdhouse': case 'well': case 'compost': case 'scarecrow': return this.search(i);
      case 'streetGate': return this.useStreetGate();
    }
  }

  toggleHiding(bush) {
    const e = this.engine;
    SN.sound.play('rustle');
    if (e.hidden) { e.hidden = false; this.hidingIn = null; return; }
    e.ducking = false;
    e.player = { x: bush.x, y: bush.y + (this.area === 'maze' ? 4 : 8) };
    e.hidden = true; this.hidingIn = bush.id;
  }

  shakeBush(i) {
    const e = this.engine, th = e.things[i];
    SN.sound.play('rustle');
    if (this.game.hasVines || th.open) { e.say('Just leaves now.'); return; }
    th.open = true;
    SN.sound.play('powerup');
    this.show({ title: 'You found VINES!', message: 'Yours to keep forever. Press V to tangle up Mom or Dad for 10 seconds (once every 35 seconds).',
      symbol: '🌿', color: '#34c759', button: 'Take',
      action: () => { this.game.hasVines = true; this.game.save(); if (!this.belt.owned.includes('vines')) this.belt.owned.push('vines'); } });
  }

  useMazeGate() {
    const e = this.engine, G = SN.Level4;
    if (!this.allDone) {
      const left = G.plantCount - this.watered;
      e.say(left > 0 ? `The gate won't open yet. ${left} plants still need water!` : `Almost! ${this.pests} pests still need shooing.`);
    } else if (this.dogsHere) {
      SN.sound.play('woof');
      e.say("Dogs are guarding the gate! I'll wait until they wander off.");
    } else {
      SN.sound.play('door');
      this.area = 'beyond'; this.hidingIn = null;
      this.chase.waypoint = null;
      this.chase.playerChangedRoom({ x: 110, y: 600 });
      e.load({ width: G.beyondWidth, floor: [545, 690], things: G.beyondThings(), spawn: { x: 210, y: 610 } });
      e.timeLeft += 60;
      this.banner = null;
      e.say(`Made it! Now: ${G.keysNeeded} keys and a code for the street gate.`, 4);
    }
  }

  search(i) {
    const e = this.engine, th = e.things[i], G = SN.Level4;
    if (th.open) { e.say('Nothing else here.'); return; }
    th.open = true;
    SN.sound.play('rustle');
    if (this.keySpots.includes(th.id)) {
      SN.sound.play('key');
      this.show({ title: 'You found a key!', message: `Key ${this.keys + 1} of ${G.keysNeeded} for the street gate.`, symbol: '🔑', color: SN.colors.gold, button: 'Take Key',
        action: () => { this.keys++; this.award('patienceIsKey'); } });
      return;
    }
    const loot = this.game.rollLoot();
    if (loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); }
    else e.say(SN.pick(['Just dirt and worms.', 'A snail. Hello, snail.', 'Nothing but old leaves.']));
  }

  useStreetGate() {
    if (this.gateOpen) return;
    if (!this.codeAccepted) { SN.sound.play('beep'); this.engine.running = false; this.showKeypad = true; }
    else this.tryKeys();
  }

  submitCode(entry) {
    if (entry.trim().toLowerCase() !== SN.Level4.code.toLowerCase()) { SN.sound.play('buzz'); return false; }
    SN.sound.play('unlock');
    this.codeAccepted = true;
    this.closeKeypad();
    this.tryKeys();
    return true;
  }

  closeKeypad() { this.showKeypad = false; this.engine.running = this.phase === 'sneaking'; }
  closeRadar() { this.showRadar = false; this.engine.running = this.phase === 'sneaking'; }

  tryKeys() {
    const e = this.engine, G = SN.Level4;
    if (this.keys < G.keysNeeded) { e.say(`The code worked! But the gate has ${G.keysNeeded} locks. I have ${this.keys} of ${G.keysNeeded} keys.`); return; }
    this.gateOpen = true; this.phase = 'over';
    e.running = false; e.timerOn = false;
    this.game.complete(4);
    SN.sound.play('unlock');
    SN.later(this, 0.5, () => SN.sound.play('door'));
    SN.later(this, 1.1, () => {
      const start = { x: e.player.x, y: e.player.y }, t0 = SN.now(), run = this.run;
      const walk = () => {
        if (this.run !== run) return;
        const p = SN.clamp((SN.now() - t0) / 0.7, 0, 1);
        e.walking = p < 1; e.player.x = SN.lerp(start.x, 2290, p); e.player.y = SN.lerp(start.y, 560, p); this.playerOpacity = 1 - p;
        if (p < 1) { requestAnimationFrame(walk); return; }
        SN.sound.play('win');
        this.show({ title: 'Level Complete!', message: "Every plant watered, every pest gone, and you're out on the street!",
          symbol: '⭐', color: SN.colors.gold, button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
      };
      requestAnimationFrame(walk);
    });
  }

  checkDone() {
    if (!this.allDone || this.area !== 'maze') return;
    SN.sound.play('star');
    this.banner = 'Checkpoint! All done. Head for the garden gate!';
    SN.later(this, 3, () => { if ((this.banner || '').startsWith('Checkpoint')) this.banner = null; });
  }

  // ---------- Every frame ----------
  tick(dt) {
    const e = this.engine;
    this.chase.tick(dt);
    if (this.dadPause > 0) {
      this.dadPause -= dt;
      if (this.dadPause <= 0 && (this.banner || '').includes('funny')) this.banner = null;
    }
    if (this.phase !== 'sneaking') return;
    if (this.area === 'maze') {
      this.waterPlants(dt);
      this.tickPests(dt);
      this.dogTime -= dt;
      if (this.dogTime <= 0) { this.dogsHere = !this.dogsHere; this.dogTime = this.dogsHere ? 10 : 9; }
      // The dogs grumble if you stand too close to them: a tiny bit of noise each time.
      this.barkTime -= dt;
      const gate = e.thing('gate');
      if (this.dogsHere && this.barkTime <= 0 && gate && Math.hypot(gate.x - e.player.x, gate.y - e.player.y) < 230 && !e.hidden) {
        this.barkTime = 1.6;
        SN.sound.play('woof', 0.35);
        e.addNoise(7);
      }
    }
    if (!this.chase.active) this.tickDad(dt);
  }

  waterPlants(dt) {
    const e = this.engine, G = SN.Level4, p = e.player;
    this.waterSound -= dt;
    for (const th of e.things) {
      if (th.kind !== 'plant' || th.open || Math.abs(th.x - p.x) >= 75 || Math.abs(th.y - p.y) >= 62) continue;
      const before = this.watered;
      let group = [th];
      if (this.hasHose) {
        // The hose reaches further: five plants at once instead of one.
        const d = q => Math.hypot(q.x - th.x, q.y - th.y);
        group = group.concat(e.things.filter(q => q !== th && q.kind === 'plant' && !q.open).sort((a, b) => d(a) - d(b)).slice(0, 4));
      }
      for (const q of group) { q.open = true; this.watered++; }
      if (this.waterSound <= 0) { SN.sound.play('water', 0.6); this.waterSound = 0.3; }
      // +20 seconds for every ten plants (the hose can pass several tens at once).
      const tens = Math.floor(Math.min(this.watered, G.plantCount - 1) / 10) - Math.floor(before / 10);
      if (tens > 0) { e.timeLeft += 20 * tens; e.say(`${this.watered} plants watered! +${20 * tens} seconds`, 1.6); }
      this.checkDone();
    }
  }

  tickPests(dt) {
    const e = this.engine, G = SN.Level4;
    // No new pests once every plant is watered, or while Dad is on his way or checking.
    if (this.watered >= G.plantCount || this.dadStage !== 0 || this.chase.active) return;
    this.pestTime -= dt;
    if (this.pestTime > 0) return;
    this.pestTime = 25;
    const plants = e.things.filter(t => t.kind === 'plant');
    if (this.pests >= 6 || !plants.length) return;
    const plant = SN.pick(plants);
    this.pestCount++; this.pests++;
    e.things.push(SN.thing({ id: 'pest' + this.pestCount, kind: 'pest', x: plant.x + 6, y: plant.y + 3, fw: 26, fh: 14, prompt: 'Shoo the pest', reachW: 70, reachH: 60 }));
    SN.sound.play('bug', 0.5);
    if (!this.banner) {
      const text = 'A pest landed on a plant! The radar shows where.';
      this.banner = text;
      SN.later(this, 2.5, () => { if (this.banner === text) this.banner = null; });
    }
  }

  /// Dad walks out to check the garden every 2 minutes. You hear him 10 seconds before.
  /// If you're in a bush when he arrives he sees nothing and goes back in; otherwise he comes after you.
  tickDad(dt) {
    const e = this.engine;
    if (this.dadStage === 0) {
      this.dadTime -= dt;
      if (this.dadTime <= 10) { this.dadStage = 1; SN.sound.play('dad'); }
      return;
    }
    const before = Math.ceil(this.dadTime);
    this.dadTime -= dt;
    const now = Math.ceil(Math.max(this.dadTime, 0));
    if (this.dadPause <= 0) this.banner = `Dad is coming to check the garden! Hide in a bush! ${now}`;
    if (now !== before && now % 3 === 0) SN.sound.play('dad', 0.7);
    if (this.dadTime > 0 || this.dadPause > 0) return;
    this.banner = null; this.dadLaughed = false; this.dadStage = 0; this.dadTime = 120;
    if (e.hidden) { this.award('shh'); e.say('Phew... Dad looked around and went back inside.'); }
    else this.chase.alarm('dad', 'Dad came out and spotted you! RUN!');
  }

  taunted() {
    this.chase.taunted();
    // Taunting while he's on his way: he laughs, and you get extra seconds to hide.
    if (this.dadStage === 1 && !this.dadLaughed && !this.chase.active) {
      this.dadLaughed = true; this.dadPause = SN.difficulty.dadLaugh;
      this.award('funnySon');
      this.banner = `Dad: "Ha! That's funny, son. You've got ${this.dadPause >= 60 ? 'a whole minute' : '10 seconds'}..."`;
    }
  }

  // ---------- Getting caught ----------
  /// Spiky vines (or a clatter of cans) make you yelp, and Dad comes to see what happened.
  bumped(i) {
    const e = this.engine, hazard = e.things[i].hazard;
    e.ignoreHazards(2.5);
    e.running = true;
    if (this.chase.active) return;
    this.chase.alarm('dad', `${SN.hazards[hazard][1]} Dad heard it. He's coming!`);
  }

  /// Out of time or too loud: Mom comes out into the garden to find you.
  momWakes(tooLoud) {
    if (this.phase !== 'sneaking') return;
    const e = this.engine;
    if (this.chase.active) { e.resetNoise(); return; }
    if (!tooLoud) this.award('amNotPm');
    this.showRadar = false; this.showKeypad = false;
    e.running = true;
    this.chase.alarm('mom', tooLoud ? 'Too loud! Mom is coming out to find you!' : "Time's up! Mom is coming out to find you!");
  }

  /// A minute went by without catching you.
  gaveUp(who) {
    const e = this.engine;
    this.award('shh'); e.resetNoise(); e.timerOn = true;
    if (who === 'mom') { e.timeLeft = 120; e.say('Mom gave up and went back to bed. 2 minutes until she wakes up again!', 4); }
    else { this.dadStage = 0; this.dadTime = 120; e.say('Dad gave up and went back inside. Phew!', 3); }
  }

  caught(who, message) {
    this.award('oopsies');
    if (who === 'dad') this.award('hiDad');
    this.showKeypad = false; this.showRadar = false;
    this.phase = 'over'; this.banner = null;
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title: 'Caught!', message, symbol: '⚠️', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  hint() {
    const e = this.engine, G = SN.Level4;
    if (this.area === 'maze') {
      if (this.allDone) e.say(this.dogsHere ? "Everything's done! Wait by the gate until the dogs leave." : 'The dogs are gone. Go through the gate, quick!', 4);
      else if (this.watered < G.plantCount) e.say('Walk close to the droopy plants to water them. The radar station shows which ones are left.', 4.5);
      else e.say('Only pests left! The radar shows them in red. Press E next to one.', 4);
    } else if (this.keys < G.keysNeeded) e.say(`Search everything out here: pots, the well, the scarecrow... ${G.keysNeeded} of them hide keys.`, 4);
    else e.say(SN.difficulty.current === 0 ? 'The code is 3, 5, 7!' : "The code is a green thing that grows... and I've just watered 100 of them!", 4.5);
  }

  get shadeAmount() { return this.area === 'maze' ? 0.16 : 0.12; }

  // ---------- Panels over the garden ----------
  overlayKey() {
    if (this.showKeypad) return 'keypad';
    if (this.showRadar) return 'radar';
    return null;
  }

  overlay() {
    if (this.showKeypad) return SN.keypad(SN.Level4.codeHint + '.', s => this.submitCode(s), () => this.closeKeypad());
    if (this.showRadar) return this.radarPanel();
    return null;
  }

  /// The radar screen: the whole maze from above, with what's still left to do.
  radarPanel() {
    const G = SN.Level4, e = this.engine, scale = 0.3;
    const el = SN.el(`<div class="overlay"><div class="popup radar">
      <div class="radar-title">RADAR</div>
      <canvas width="${G.mazeW * scale}" height="${G.mazeH * scale}"></canvas>
      <div class="legend"></div>
      <div class="dad"></div>
      <button class="big press">✕ Close</button></div></div>`);
    const cv = el.querySelector('canvas'), ctx = cv.getContext('2d'), D = SN.draw;
    ctx.fillStyle = SN.rgb(0.02, 0.10, 0.05); ctx.fillRect(0, 0, cv.width, cv.height);
    for (const t of e.things) {
      const x = t.x * scale, y = t.y * scale;
      switch (t.kind) {
        case 'hedge': ctx.fillStyle = 'rgba(52,199,89,.45)'; ctx.fillRect(x - t.fw * scale / 2, y - t.fh * scale / 2, t.fw * scale, t.fh * scale); break;
        case 'plant': if (!t.open) D.circle(ctx, x, y, 8, '#ffcc00'); break;
        case 'pest': D.circle(ctx, x, y, 12, '#ff3b30'); break;
        case 'bush': case 'shakyBush': D.circle(ctx, x, y, 10, SN.rgb(0.3, 0.9, 0.5)); break;
        case 'spikyVine': D.circle(ctx, x, y, 8, '#af52de'); break;
        case 'mazeGate': D.circle(ctx, x, y, 14, '#fff'); break;
      }
    }
    D.circle(ctx, e.player.x * scale, e.player.y * scale, 14, '#32ade6');
    const legend = [['#32ade6', 'You'], ['#ffcc00', `Thirsty plant (${G.plantCount - this.watered})`], ['#ff3b30', `Pest (${this.pests})`],
                    [SN.rgb(0.3, 0.9, 0.5), 'Bush'], ['#af52de', 'Spiky vine'], ['#fff', 'Gate']];
    el.querySelector('.legend').innerHTML = legend.map(([c, s]) => `<span><i style="background:${c}"></i>${SN.esc(s)}</span>`).join('');
    const dad = el.querySelector('.dad');
    dad.textContent = this.dadTime <= 10 ? 'DAD IS COMING!' : `Dad's next check: about ${Math.floor(this.dadTime)} seconds`;
    dad.style.color = this.dadTime <= 30 ? '#ff3b30' : '#34c759';
    el.querySelector('button').addEventListener('click', () => { SN.sound.tap(); this.closeRadar(); });
    return el;
  }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, G = SN.Level4;
    const extra = this.chase.active && this.chase.visible ? [{ y: this.chase.y, draw: () => this.chase.draw(ctx) }] : [];
    if (this.area === 'maze') {
      P.mazeGround(ctx, G.mazeW, G.mazeH);
      runner.drawFloor(ctx, t, th => {
        switch (th.kind) {
          case 'hedge': return P.hedge(ctx, th.x, th.y, th.fw, th.fh);
          case 'plant': return P.plant(ctx, th.x, th.y, th.open);
          case 'pest': return P.pest(ctx, th.x, th.y, t);
          case 'spikyVine': return P.spikyVine(ctx, th.x, th.y, th.fw, th.fh);
          case 'bush': return P.bush(ctx, th.x, th.y, this.hidingIn === th.id, false);
          case 'shakyBush': return P.bush(ctx, th.x, th.y, false, !th.open);
          case 'radar': return P.radarStation(ctx, th.x, th.y, t);
          case 'mazeGate': return P.mazeGate(ctx, th.x, th.y, this.allDone, this.dogsHere, t);
        }
      }, extra);
      return;
    }
    P.beyondScene(ctx, G.beyondWidth);
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'backGate': P.gardenGate(ctx, x, y); break;
        case 'bushWall': P.bush(ctx, x, y, this.hidingIn === th.id, false, 1.5); break;
        case 'flowerPots': P.flowerPots(ctx, x, y); break;
        case 'wheelbarrow': P.wheelbarrow(ctx, x, y); break;
        case 'birdhouse': P.birdhouse(ctx, x, y); break;
        case 'well': P.well(ctx, x, y); break;
        case 'compost': P.compost(ctx, x, y); break;
        case 'scarecrow': P.scarecrow(ctx, x, y); break;
        case 'streetGate': P.streetGate(ctx, x, y, this.gateOpen, this.codeAccepted); break;
      }
    }
    runner.drawFloor(ctx, t, th => {
      if (th.kind === 'spikyVine') P.spikyVine(ctx, th.x, th.y, th.fw, th.fh);
      else P.paintCans(ctx, th.x, th.y + 10);
    }, extra);
  }
};

SN.Level4.plantCount = 100;
SN.Level4.columns = 10;
SN.Level4.rows = 8;
SN.Level4.cell = { w: 220, h: 170 };
SN.Level4.origin = { x: 60, y: 150 };
SN.Level4.mazeW = 2320;
SN.Level4.mazeH = 1600;
SN.Level4.beyondWidth = 2400;
SN.Level4.searchSpots = ['flowerPots', 'wheelbarrow', 'birdhouse', 'well', 'compost', 'scarecrow'];
