// Level 7 rules: Auntie's backyard. It costs 10 orbs to get in, and you need 32 badges.
// First pick up the hose by the tap and wash all the mud off the yard (walk close to each
// muddy patch, like watering the plants in Level 4). Then the kittens get out: find every one,
// some wandering about and some hiding in the bushes, pots, shed and so on. Auntie thanks you
// with her old Water Hose (a boost only she gives) and walks you to Uncle's car, with a short scene.
// Nobody chases you: the clock, the sleeping cats and the noise are the trouble here.
// (A port of Level7Backyard.swift.)

SN.Level7 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.run = 0;
    const e = this.engine;
    e.onInteract = i => this.interact(i);
    e.onHazard = i => this.steppedOn(i);
    e.onTimeUp = () => this.tooSlow();
    e.onTooLoud = () => this.tooLoud();
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTick = dt => this.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  title() { return "Level 7 · Auntie's Backyard"; }
  award(b) { this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return this.phase !== 'wash' && this.phase !== 'kittens'; }
  cornerHint() {
    if (this.phase === 'wash') return this.hasHose ? `🟤 Mud washed: ${this.washed}/${this.mudCount}` : '🚰 Pick up the hose by the tap';
    if (this.phase === 'kittens') return `🐱 Kittens found: ${this.found}/${this.kittenCount}`;
    return "Auntie is taking you to Uncle's car";
  }
  get inventory() {
    const items = this.hasHose ? [{ id: 'hose', icon: '💧', color: '#40b3d9' }] : [];
    for (let n = 1; n <= this.found; n++) items.push({ id: 'kitten' + n, icon: '🐱', color: '#ff9500' });
    return items;
  }

  reset() {
    this.run++;
    const e = this.engine, B = SN.Level7, d = SN.difficulty;
    this.mudCount = d.pick(12, 24, 38);
    this.kittenCount = d.pick(4, 7, 10);
    // Some kittens hide; the rest wander about the yard.
    const hiding = Math.min(B.hidingSpots.length, Math.floor((this.kittenCount + 1) / 2));
    this.kittenSpots = new Set(SN.shuffle(B.hidingSpots.map(s => s[0])).slice(0, hiding));
    e.load({ width: B.width, floor: [545, 690], things: B.things(this.mudCount), spawn: { x: 260, y: 620 } });
    e.usesHP = false;
    e.timeLeft = SN.levelTime(7); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.runHeld = false; e.speedBonus = 0;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.belt.reset();
    Object.assign(this, {
      phase: 'wash', popup: null, banner: null, bannerTime: 0, hasHose: false, washed: 0, found: 0,
      spraying: false, sprayTime: 0, splashSound: 0, auntie: { x: 470, y: 590 }, auntieWalking: false, auntieRight: true,
      auntieSays: null, sayTime: 0, carX: B.width + 600, inCar: false, playerOpacity: 1,
    });
    e.running = true;
    this.speak('Look at the state of my yard! Grab the hose by the tap and wash all that mud away.', 4.5);
  }

  // ---------- The yard ----------
  static things(mud) {
    const W = SN.Level2.onWall, O = SN.Level2.obstacle, B = SN.Level7;
    const things = [
      W('houseDoor', 'houseDoor', 120, 'Go back inside', 80), W('tap', 'tap', 300, 'Pick up the hose', 70),
      W('basket', 'basket', 620, null, 70), W('gate', 'gate', B.gateX, 'Open the gate', 100),
    ];
    for (const [id, kind, x] of B.hidingSpots) things.push(W(id, kind, x, null, 80));
    // Mud everywhere, spread along the yard from near to far (the same patches as on the iPad).
    const rng = SN.Level4.seededRandom(77);
    for (let i = 0; i < mud; i++) {
      const x = 420 + (i + rng() * 0.6) * (B.width - 800) / Math.max(mud, 1);
      const y = 545 + 20 + rng() * (690 - 545 - 30);
      things.push(SN.thing({ id: 'mud' + i, kind: 'mud', x, y, fw: 64, fh: 22, flat: true }));
    }
    // Things to jump over or crouch past: garden toys and paint pots, and two sleeping cats.
    [980, 1760, 2560, 3320].forEach((x, n) => things.push(Object.assign(O('toy' + n, 'toy', x, [600, 665, 630, 580][n], 50, 26), { kind: 'toy' })));
    things.push(O('cans1', 'cans', 2150, 655, 60, 24));
    const hard = SN.difficulty.current >= 2;
    [1300, 3000].forEach((x, n) => things.push(SN.thing({ id: 'cat' + n, kind: 'cat', x, y: n === 0 ? 640 : 600, fw: 62, fh: 24, hazard: 'cat',
      patrol: hard ? [x - 240, x + 240] : null, speed: hard ? 90 : 0 })));
    return things;
  }

  show(p) { SN.levelShow(this, p); }

  // ---------- Every frame ----------
  tick(dt) {
    if (this.bannerTime > 0) { this.bannerTime -= dt; if (this.bannerTime <= 0) this.banner = null; }
    if (this.sayTime > 0) { this.sayTime -= dt; if (this.sayTime <= 0) this.auntieSays = null; }
    if (this.sprayTime > 0) { this.sprayTime -= dt; if (this.sprayTime <= 0) this.spraying = false; }
    this.splashSound -= dt;
    if (this.phase === 'wash') this.wash();
    else if (this.phase === 'kittens') this.waitByBasket(dt);
  }

  /// With the hose, walking close to mud washes it away.
  wash() {
    if (!this.hasHose) return;
    const e = this.engine, p = e.player;
    for (const th of e.things) {
      if (th.kind !== 'mud' || th.hidden || Math.abs(th.x - p.x) >= 80 || Math.abs(th.y - p.y) >= 60) continue;
      th.hidden = true;
      this.washed++;
      this.spraying = true; this.sprayTime = 0.4;
      if (this.splashSound <= 0) { SN.sound.play('water', 0.6); this.splashSound = 0.3; }
      if (this.washed % 8 === 0 && this.washed < this.mudCount) { e.timeLeft += 15; e.say(`${this.washed} patches washed! +15 seconds`, 1.6); }
    }
    if (this.washed >= this.mudCount) this.allWashed();
  }

  allWashed() {
    const e = this.engine, B = SN.Level7;
    this.phase = 'kittens';
    this.spraying = false;
    SN.sound.play('powerup');
    e.timeLeft += 45;
    this.banner = 'Checkpoint! The yard is clean. +45 seconds';
    this.bannerTime = 3;
    // The noise of the hose let the kittens out.
    this.speak(`Oh no, the gate to the kitten pen was open! My ${this.kittenCount} kittens are all over the yard. Find them, dear!`, 5);
    const wandering = this.kittenCount - this.kittenSpots.size;
    for (let n = 0; n < wandering; n++) {
      const x = 900 + n * (B.width - 1500) / Math.max(wandering, 1) + SN.rand(-100, 100);
      e.things.push(SN.thing({ id: 'kitten' + n, kind: 'kitten', color: n % 5, x, y: SN.rand(580, 675), fw: 44, fh: 18, prompt: 'Pick up the kitten', reachW: 70, reachH: 50,
        patrol: [Math.max(500, x - 300), Math.min(B.width - 300, x + 300)], speed: (n % 2 === 0 ? 1 : -1) * 70 * SN.difficulty.hazardSpeed }));
    }
    for (const [id, , , name] of B.hidingSpots) { const t = e.thing(id); if (t) t.prompt = `Look in ${name}`; }
  }

  /// While you look for kittens, Auntie waits by the basket.
  waitByBasket(dt) {
    const a = this.auntie, dx = 520 - a.x;
    if (Math.abs(dx) > 6) { a.x += Math.sign(dx) * Math.min(Math.abs(dx), 160 * dt); this.auntieRight = dx > 0; this.auntieWalking = true; }
    else this.auntieWalking = false;
  }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i];
    if (th.kind === 'kitten') { th.hidden = true; this.gotKitten('Got one! Come here, little one.'); return; }
    switch (th.kind) {
      case 'houseDoor': return this.speak('Not until my yard is sorted, dear!', 2.4);
      case 'tap':
        if (this.hasHose) return e.say('The hose is already on. Walk close to the mud to wash it.');
        this.hasHose = true; th.prompt = null;
        SN.sound.play('water');
        return e.say('The hose is on! Now walk close to every muddy patch.', 3);
      case 'gate':
        if (this.phase === 'scene' || this.phase === 'over') return;
        return e.say(this.phase === 'wash' ? 'Auntie wants her yard clean first.' : `${this.kittenCount - this.found} kittens are still missing!`);
      case 'bush': case 'pots': case 'shed': case 'barrow': case 'doghouse': case 'compost': case 'birdhouse': return this.search(th);
    }
  }

  search(th) {
    const e = this.engine;
    if (this.phase !== 'kittens') return;
    th.open = true; th.prompt = null;
    SN.sound.play('rustle');
    if (this.kittenSpots.delete(th.id)) {
      const spot = SN.Level7.hidingSpots.find(s => s[0] === th.id);
      this.gotKitten(`A kitten was hiding in ${spot ? spot[3] : 'there'}!`);
      return;
    }
    const loot = this.game.rollLoot();
    if (loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); }
    else e.say(SN.pick(['Just a snail.', 'A lost tennis ball. No kitten.', 'Leaves and more leaves.', 'A very surprised frog.']));
  }

  gotKitten(line) {
    this.found++;
    SN.sound.play('squeak', 0.5);
    this.engine.say(`${line} ${this.found} of ${this.kittenCount}.`, 2);
    if (this.found >= this.kittenCount) this.allFound();
  }

  allFound() {
    const hose = SN.specialBoosts.find(b => b.id === 'waterHose');
    this.phase = 'scene';
    this.engine.timerOn = false;
    this.award('kittens');
    SN.sound.play('win');
    this.speak('Every one of them! Thank you, dear.', 3);
    this.show({ title: "Auntie's thank-you",
      message: `Auntie: "You washed my yard and found every kitten. Take my old hose. It's never let me down."\n\n${hose.name}: ${hose.about}`,
      symbol: hose.icon, color: hose.color, button: 'Thank you, Auntie!',
      action: () => { this.game.take({ type: 'boost', boost: hose }); this.playScene(); } });
  }

  // ---------- The end scene ----------
  /// Moves things smoothly over `seconds`; resolves false if the level was restarted meanwhile.
  tween(seconds, step, ease = p => p) {
    const run = this.run, t0 = SN.now();
    return new Promise(done => {
      const frame = () => {
        if (this.run !== run) { done(false); return; }
        const p = Math.min(1, (SN.now() - t0) / seconds);
        step(ease(p));
        if (p < 1) requestAnimationFrame(frame); else done(true);
      };
      requestAnimationFrame(frame);
    });
  }
  wait(seconds) { const run = this.run; return new Promise(done => setTimeout(() => done(this.run === run), seconds * 1000)); }

  /// Auntie walks you to the gate, Uncle's car pulls up, you hop in and off it goes.
  async playScene() {
    const e = this.engine, B = SN.Level7, a = this.auntie;
    this.game.complete(7);
    e.running = false; e.walking = false;
    this.banner = null;
    this.speak('Come along. Your uncle is waiting out front.', 3);
    this.auntieWalking = true; this.auntieRight = true; e.walking = true; e.facingRight = true;
    const p0 = { x: e.player.x, y: e.player.y }, a0 = { x: a.x };
    if (!await this.tween(3, p => { e.player.x = SN.lerp(p0.x, B.gateX - 230, p); e.player.y = SN.lerp(p0.y, 620, p); a.x = SN.lerp(a0.x, B.gateX - 120, p); })) return;
    this.auntieWalking = false; e.walking = false;
    SN.sound.play('door');
    const c0 = this.carX;
    if (!await this.tween(2.2, p => { this.carX = SN.lerp(c0, B.gateX + 330, p); }, p => 1 - (1 - p) * (1 - p))) return;
    if (!await this.wait(0.2)) return;
    SN.sound.play('beep');
    e.say('Uncle: "Beep beep! Hop in, kiddo. Grandpa\'s town is next."', 3);
    if (!await this.wait(2.6)) return;
    this.speak('Off you go. Give Grandpa a big hug from me.', 3);
    const p1 = { x: e.player.x, y: e.player.y };
    if (!await this.tween(0.8, p => { e.player.x = SN.lerp(p1.x, B.gateX + 200, p); e.player.y = SN.lerp(p1.y, 610, p); this.playerOpacity = 1 - p; })) return;
    this.inCar = true;
    SN.sound.play('door');
    if (!await this.wait(1)) return;
    const c1 = this.carX;
    if (!await this.tween(2.4, p => { this.carX = SN.lerp(c1, B.gateX + 1800, p); }, p => p * p)) return;
    this.phase = 'over';
    this.show({ title: 'Level Complete!', message: "Auntie waves from the gate as Uncle's old car rattles off into the morning.", symbol: '🚗', color: SN.colors.gold,
      button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  // ---------- Trouble ----------
  steppedOn(i) {
    const e = this.engine;
    e.ignoreHazards(2.5);
    e.running = true;
    if ((this.phase !== 'wash' && this.phase !== 'kittens') || e.safe) return;
    const lost = Math.round(15 * SN.difficulty.damageScale);
    e.timeLeft = Math.max(1, e.timeLeft - lost);
    const what = e.things[i].hazard === 'cat' ? 'MEOW! "Mind my cats!"' : 'CLATTER! "Careful, dear!"';
    this.banner = `Auntie: ${what}  −${lost} seconds`;
    this.bannerTime = 2.6;
  }

  tooLoud() {
    const e = this.engine;
    e.resetNoise();
    if ((this.phase !== 'wash' && this.phase !== 'kittens') || e.safe) return;
    e.timeLeft = Math.max(1, e.timeLeft - 20);
    this.banner = 'Auntie: "Shh! The neighbours are still asleep!"  −20 seconds';
    this.bannerTime = 2.6;
  }

  tooSlow() {
    if (this.phase !== 'wash' && this.phase !== 'kittens') return;
    const done = this.phase === 'kittens' ? `You found ${this.found} of ${this.kittenCount} kittens.` : `You washed ${this.washed} of ${this.mudCount} patches.`;
    this.award('amNotPm');
    this.phase = 'over';
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title: 'Too slow!', message: `Auntie: "The sun's nearly up! We'll try again."\n${done}`, symbol: '⏰', color: '#ff3b30',
      button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  speak(text, seconds) { this.auntieSays = text; this.sayTime = seconds; }

  hint() {
    const e = this.engine;
    if (this.phase === 'wash') e.say(this.hasHose ? `Walk close to each muddy patch. ${this.mudCount - this.washed} to go.` : 'The hose is by the tap, next to the back door. Press E there.', 3.5);
    else if (this.phase === 'kittens') e.say(`${this.kittenCount - this.found} kittens to find. Some walk about: press E next to one. Others hide: look in bushes, pots, the shed...`, 4.5);
  }

  get shadeAmount() { return 0.12; }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, B = SN.Level7, D = SN.draw;
    B.scene(ctx, B.width);
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'houseDoor': P.door(ctx, x, y, SN.rgb(0.25, 0.50, 0.40), false, "AUNTIE'S", '#34c759'); break;
        case 'tap': B.tap(ctx, x, y, this.hasHose); break;
        case 'basket': B.basket(ctx, x, y, this.found); break;
        case 'gate': P.gardenGate(ctx, x, y); break;
        case 'bush': ctx.save(); if (th.open) ctx.globalAlpha = 0.85; P.bush(ctx, x, y, false, false, 1.5); ctx.restore(); break;
        case 'pots': P.flowerPots(ctx, x, y); break;
        case 'shed': B.shed(ctx, x, y, th.open); break;
        case 'barrow': P.wheelbarrow(ctx, x, y); break;
        case 'doghouse': B.doghouse(ctx, x, y); break;
        case 'compost': P.compost(ctx, x, y); break;
        case 'birdhouse': P.birdhouse(ctx, x, y); break;
      }
    }
    const a = this.auntie;
    SN.people.mom(ctx, a.x, a.y, { walking: this.auntieWalking, facingRight: this.auntieRight, robe: SN.rgb(0.20, 0.55, 0.55), noCurlers: true, bun: true, calm: true, t });
    if (this.auntieSays) SN.people.speech(ctx, a.x, a.y - 280, 'Auntie: ' + this.auntieSays, '#30b0c7', true);
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'kitten': B.kitten(ctx, x, y, th.color, th.speed > 0); break;
        case 'mud': B.mud(ctx, x, y, th.id.length + Math.round(x)); break;
        case 'cat': SN.Level6.drawCat(ctx, x, y, th.patrol !== null, th.speed > 0, t); break;
        case 'toy': P.toyBall(ctx, x, y + 8, t); break;
        case 'cans': P.paintCans(ctx, x, y + 10); break;
      }
    }, []);
    if (this.spraying && !e.hidden) B.spray(ctx, e.player.x + (e.facingRight ? 70 : -70), e.player.y - 40, e.facingRight, t);
    B.car(ctx, this.carX, 690, this.inCar ? this.game.look : null, true, this.carX * 1.4);
  }

  // ---------- Art ----------
  /// Auntie's backyard just before sunrise: her house at the left, a fence, a lawn, a washing line and trees.
  static scene(ctx, width) {
    const D = SN.draw;
    const g = ctx.createLinearGradient(0, 0, 0, 470); g.addColorStop(0, SN.palette.skyTop()); g.addColorStop(1, SN.palette.skyBottom());
    ctx.fillStyle = g; ctx.fillRect(0, 0, width, 470);
    for (let i = 0; i < 30; i++) D.circle(ctx, (i * 151) % width, (i * 53) % 240, 2 + i % 3, `rgba(255,255,255,${0.7 * SN.palette.starlight()})`);
    for (let i = 0; i < Math.floor(width / 380); i++) {
      D.circle(ctx, i * 380 + 200, 330, 220, SN.rgb(0.12, 0.30, 0.22));
      D.rect(ctx, i * 380 + 200, 420, 26, 120, SN.rgb(0.30, 0.20, 0.14));
    }
    ctx.fillStyle = SN.rgb(0.55, 0.45, 0.40); ctx.fillRect(0, 0, 260, 470);
    ctx.fillStyle = SN.rgb(0.45, 0.30, 0.28); ctx.fillRect(0, 40, 280, 30);
    for (let x = 270; x + 34 < width; x += 44) D.rrect(ctx, x + 17, 395, 34, 130, 4, SN.rgb(0.78, 0.72, 0.62));
    ctx.strokeStyle = SN.white(0.85); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(1650, 250); ctx.quadraticCurveTo(1950, 290, 2250, 250); ctx.stroke();
    ['#ff2d55', '#32ade6', '#fff', '#ffcc00', '#af52de'].forEach((c, i) => D.rrect(ctx, 1730 + i * 110, 300 + (i === 2 ? 14 : 8), 44, 56, 4, SN.alpha(c, 0.85)));
    const l = ctx.createLinearGradient(0, 460, 0, 700); l.addColorStop(0, SN.rgb(0.20, 0.45, 0.24)); l.addColorStop(1, SN.rgb(0.25, 0.55, 0.28));
    ctx.fillStyle = l; ctx.fillRect(0, 460, width, 240);
    for (let i = 0; i < Math.floor(width / 260); i++) D.ellipse(ctx, 200 + i * 260, 662 + (i % 2) * 18, 80, 24, SN.white(0.62));
  }

  static mud(ctx, x, y, seed) {
    const D = SN.draw, brown = SN.rgb(0.36, 0.24, 0.14);
    D.ellipse(ctx, x, y, 66, 22, SN.alpha(brown, 0.9));
    D.circle(ctx, x + (seed % 3) * 8 - 14, y - 5, 20, brown);
    D.circle(ctx, x + 18, y + 4, 14, SN.alpha(brown, 0.8));
    D.ellipse(ctx, x - 6, y - 4, 18, 5, 'rgba(255,255,255,.12)');
  }

  /// The water from the hose, in front of you while you wash.
  static spray(ctx, x, y, facingRight, t) {
    ctx.save(); ctx.translate(x, y); if (!facingRight) ctx.scale(-1, 1);
    for (let i = 0; i < 9; i++) {
      const k = ((t * 3 + i / 9) % 1);
      SN.draw.circle(ctx, k * 70 - 20, k * k * 50 - 20 + (i % 3) * 4, 8 + (i % 3) * 3, `rgba(140,217,255,${1 - k})`);
    }
    ctx.restore();
  }

  static tap(ctx, x, y, hoseTaken) {
    const D = SN.draw;
    D.rect(ctx, x, y - 75, 10, 90, SN.white(0.55));
    D.capsule(ctx, x + 10, y - 120, 34, 12, SN.colors.gold);
    D.circle(ctx, x, y - 130, 16, '#ff3b30');
    if (!hoseTaken) { D.circle(ctx, x + 24, y - 42, 64, null, SN.rgb(0.20, 0.62, 0.30), 7); D.circle(ctx, x + 24, y - 42, 44, null, SN.rgb(0.20, 0.62, 0.30), 7); }
  }

  static basket(ctx, x, y, kittens) {
    const D = SN.draw;
    for (let i = 0; i < Math.min(kittens, 6); i++) {
      ctx.save(); ctx.translate(x - (Math.min(kittens, 6) - 1) * 10 + i * 20, y - 40); ctx.scale(0.55, 0.55);
      SN.Level7.kitten(ctx, 0, 23, i, i % 2 === 0); ctx.restore();
    }
    ctx.beginPath(); ctx.moveTo(x - 55, y - 46); ctx.lineTo(x + 55, y - 46); ctx.lineTo(x + 38, y); ctx.lineTo(x - 38, y); ctx.closePath();
    ctx.fillStyle = SN.rgb(0.75, 0.55, 0.30); ctx.fill();
    for (let i = 0; i < 4; i++) D.rect(ctx, x, y - i * 10 - 6, 90 - i * 6, 2, 'rgba(0,0,0,.12)');
  }

  static kitten(ctx, x, y, color, facingRight) {
    const D = SN.draw;
    const fur = [SN.rgb(0.95, 0.62, 0.28), SN.white(0.55), SN.rgb(0.50, 0.34, 0.22), SN.white(0.95), SN.white(0.18)][Math.abs(color) % 5];
    ctx.save(); ctx.translate(x, y - 23); if (!facingRight) ctx.scale(-1, 1);
    D.rotated(ctx, -22, -10, -50, () => D.capsule(ctx, 0, 0, 24, 6, fur));
    D.capsule(ctx, -10, 10, 6, 10, SN.shade(fur, -0.08)); D.capsule(ctx, 10, 10, 6, 10, SN.shade(fur, -0.08));
    D.ellipse(ctx, 0, 0, 40, 20, fur);
    D.circle(ctx, 18, -10, 22, fur);
    D.tri(ctx, 12, -24, 9, 10, SN.shade(fur, -0.1)); D.tri(ctx, 24, -24, 9, 10, SN.shade(fur, -0.1));
    const eye = color === 4 ? '#ffcc00' : '#000';
    D.circle(ctx, 15, -11, 3.5, eye); D.circle(ctx, 23, -11, 3.5, eye);
    ctx.restore();
  }

  static shed(ctx, x, y, open) {
    const D = SN.draw;
    D.rect(ctx, x, y - 95, 220, 190, SN.rgb(0.45, 0.32, 0.22));
    D.tri(ctx, x, y - 186 - 35 + 4, 250, 70, SN.rgb(0.32, 0.22, 0.16));
    for (let i = 0; i < 6; i++) D.rect(ctx, x - 90 + i * 36, y - 95, 2, 190, 'rgba(0,0,0,.1)');
    D.rrect(ctx, x, y - 70, 80, 140, 4, open ? SN.white(0.08) : SN.rgb(0.55, 0.40, 0.26));
    if (!open) D.circle(ctx, x + 26, y - 70, 9, SN.colors.gold);
  }

  static doghouse(ctx, x, y) {
    const D = SN.draw;
    D.rect(ctx, x, y - 45, 130, 90, SN.rgb(0.62, 0.30, 0.22));
    D.tri(ctx, x, y - 88 - 28 + 2, 150, 56, SN.rgb(0.40, 0.20, 0.16));
    D.ellipse(ctx, x, y - 27, 56, 66, SN.white(0.06));
    D.text(ctx, 'REX', x, y - 100, 14, '#fff', 900);
  }

  /// Uncle's old car: rusty orange, a mismatched door, Uncle at the wheel and you in the back.
  static car(ctx, x, y, kidLook, lightsOn, wheelTurn) {
    const D = SN.draw, body = SN.rgb(0.70, 0.48, 0.18), roof = SN.rgb(0.62, 0.42, 0.16);
    ctx.save(); ctx.translate(x - 200, y - 190);
    if (lightsOn) {
      const g = ctx.createLinearGradient(390, 0, 650, 0); g.addColorStop(0, 'rgba(255,204,0,.5)'); g.addColorStop(1, 'rgba(255,204,0,0)');
      ctx.beginPath(); ctx.moveTo(390, 120); ctx.lineTo(650, 60); ctx.lineTo(650, 180); ctx.closePath(); ctx.fillStyle = g; ctx.fill();
    }
    D.rrect(ctx, 186, 73, 250, 90, 40, roof);
    D.rrect(ctx, 186, 70, 206, 56, 18, 'rgba(140,204,242,.55)');
    if (kidLook) {
      ctx.save(); ctx.beginPath(); ctx.rect(95, 44, 70, 50); ctx.clip();
      SN.people.character(ctx, 130, 150, kidLook, { facingRight: true, scale: 0.62 }); ctx.restore();
    }
    ctx.save(); ctx.beginPath(); ctx.rect(193, 46, 70, 52); ctx.clip();
    ctx.translate(228, 46); ctx.scale(0.5, 0.5); SN.people.person(ctx, 0, 250, 'uncle', 0, {}); ctx.restore();
    D.rect(ctx, 182, 70, 8, 56, roof);
    D.rrect(ctx, 200, 122, 390, 92, 30, body);
    D.rect(ctx, 200, 106 - 22, 390, 4, 'rgba(0,0,0,.15)');
    D.circle(ctx, 384, 92, 20, lightsOn ? '#ffcc00' : SN.white(0.8));
    D.circle(ctx, 12, 90, 14, 'rgba(255,59,48,.85)');
    D.rrect(ctx, 140, 122, 86, 64, 6, SN.rgb(0.55, 0.55, 0.50));
    [74, 326].forEach(cx => {
      D.circle(ctx, cx, 152, 76, SN.white(0.1)); D.circle(ctx, cx, 152, 32, SN.white(0.6));
      D.rotated(ctx, cx, 152, wheelTurn % 360, () => D.rect(ctx, 0, 0, 28, 4, SN.white(0.3)));
    });
    ctx.restore();
  }
};

SN.Level7.width = 4400;
SN.Level7.gateX = 4230;
/// Places a kitten might hide: id, kind, x, and what to call it. Some of them hold one.
SN.Level7.hidingSpots = [
  ['bush1', 'bush', 760, 'the bush'], ['pots', 'pots', 1120, 'the flower pots'], ['shed', 'shed', 1520, 'the shed'],
  ['barrow', 'barrow', 1980, 'the wheelbarrow'], ['bush2', 'bush', 2380, 'the big bush'], ['doghouse', 'doghouse', 2760, 'the old doghouse'],
  ['compost', 'compost', 3150, 'the compost bin'], ['bush3', 'bush', 3480, 'the hedge'], ['birdhouse', 'birdhouse', 3860, 'the birdhouse post'],
];
