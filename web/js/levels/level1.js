// Level 1 rules: find the small key under the table, open the lockbox under the bed, then use
// the big key from the lockbox on the door — before the clock runs out. Too loud, or out of
// time, and Mom comes in to send you to bed. (A port of Level1Bedroom.swift.)

SN.Level1 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.chase = new SN.Chase();
    this.run = 0;
    const e = this.engine, c = this.chase;
    e.onInteract = i => this.interact(i);
    e.onTimeUp = () => this.momWakes(false);
    e.onTooLoud = () => this.momWakes(true);
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTaunt = () => c.taunted();
    e.onTick = dt => c.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    this.belt.stun = (s, momOnly) => c.stun(s, momOnly);
    c.engine = e;
    // Mom comes in through the bedroom door.
    c.entrance = () => ({ x: 905, y: 575, delay: 2.5 });
    c.setBanner = b => this.banner = b;
    c.award = b => this.award(b);
    c.onCaught = () => this.sentToBed();
    c.onGaveUp = () => this.momGaveUp();
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  title() { return 'Level 1 · Bedroom'; }
  award(b) { if (b === 'oopsies') this.game.noteCaught(); else this.game.award(b); }
  has(id) { return this.inventory.some(i => i.id === id); }

  retry() { this.game.noteRetry(); this.reset(); }

  reset() {
    this.run++;
    this.belt.reset();
    this.engine.load({ width: 1000, floor: [560, 680], spawn: { x: 470, y: 620 }, things: [
      SN.thing({ id: 'bed', x: 250, y: 560, heavy: true, prompt: 'Check the lockbox', reachW: 150 }),
      SN.thing({ id: 'table', x: 630, y: 560, heavy: true, prompt: 'Look under the table', reachW: 100 }),
      SN.thing({ id: 'lamp', x: 735, y: 560, prompt: 'Switch the lamp', reachW: 30 }),
      SN.thing({ id: 'toybox', kind: 'toybox', x: 800, y: 590, fw: 96, fh: 30, solid: true, movable: true, prompt: 'Look in the toy box', reachW: 100, reachH: 70 }),
      SN.thing({ id: 'door', x: 905, y: 560, prompt: 'Open the door', reachW: 80 }),
    ] });
    const e = this.engine;
    e.timeLeft = SN.levelTime(1); e.timerOn = true; e.resetNoise(); e.crouching = false; e.facingRight = true; e.bubble = null;
    this.inventory = []; this.foundSmallKey = false; this.lockboxOpen = false; this.doorOpen = false;
    this.lampOn = false; this.showGlint = false; this.popup = null; this.playerOpacity = 1; this.banner = null; this.over = false;
    this.chase.reset();
    e.running = true;
  }

  interact(i) {
    switch (this.engine.things[i].id) {
      case 'table': this.searchTable(); break;
      case 'bed': this.useLockbox(); break;
      case 'lamp': this.lampOn = !this.lampOn; SN.sound.play('click'); break;
      case 'toybox': this.engine.say('Just toys in here. No key.'); break;
      case 'door': this.useDoor(); break;
    }
  }

  show(p) { SN.levelShow(this, p); }

  searchTable() {
    const e = this.engine;
    if (this.foundSmallKey) { e.say('Nothing else under the table.'); return; }
    e.running = false; e.crouching = true;
    SN.later(this, 0.6, () => {
      this.foundSmallKey = true;
      SN.sound.play('key');
      this.show({ title: 'You found a key!', message: 'A small silver key was hiding under the table.', symbol: '🔑', color: SN.colors.silver,
        button: 'Take Key', action: () => { this.inventory.push({ id: 'smallKey', icon: '🗝', color: SN.colors.silver }); this.award('patienceIsKey'); } });
    });
  }

  useLockbox() {
    const e = this.engine;
    if (this.lockboxOpen) { e.say('The lockbox is empty now.'); return; }
    if (!this.has('smallKey')) { e.say("A lockbox under the bed! It's locked. I need a key."); return; }
    e.running = false; e.crouching = true;
    SN.later(this, 0.4, () => {
      this.inventory = this.inventory.filter(i => i.id !== 'smallKey');
      this.lockboxOpen = true;
      SN.sound.play('unlock');
      SN.later(this, 0.8, () => {
        SN.sound.play('key');
        this.show({ title: 'You found a key!', message: 'The lockbox had a big golden key inside!', symbol: '🔑', color: SN.colors.gold,
          button: 'Take Key', action: () => this.inventory.push({ id: 'doorKey', icon: '🔑', color: SN.colors.gold }) });
      });
    });
  }

  useDoor() {
    const e = this.engine;
    if (this.doorOpen) return;
    if (this.has('doorKey')) {
      e.running = false; this.over = true;
      this.inventory = this.inventory.filter(i => i.id !== 'doorKey');
      SN.sound.play('unlock');
      this.doorOpen = true;
      this.game.complete(1);
      SN.later(this, 0.3, () => SN.sound.play('door'));
      // Walk out through the door, fading away.
      const start = { x: e.player.x, y: e.player.y }, t0 = SN.now() + 0.9;
      const walk = () => {
        const p = SN.clamp((SN.now() - t0) / 0.6, 0, 1);
        if (SN.now() >= t0) { e.walking = p < 1; e.player.x = SN.lerp(start.x, 905, p); e.player.y = SN.lerp(start.y, 565, p); this.playerOpacity = 1 - p; }
        if (p < 1) requestAnimationFrame(walk);
        else {
          SN.sound.play('win');
          this.show({ title: 'Level Complete!', message: 'Shhh... you sneaked out of the bedroom!', symbol: '⭐', color: SN.colors.gold,
            button: 'Next Level', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
        }
      };
      requestAnimationFrame(walk);
    } else if (this.has('smallKey')) e.say('This little key is too small for the door.');
    else e.say('The door is locked. I need a key.');
  }

  /// Out of time, or too noisy: Mom gets up, walks in through the door and comes after you.
  momWakes(tooLoud) {
    if (this.doorOpen) return;
    if (this.chase.active) { this.engine.resetNoise(); return; }
    if (!tooLoud) this.award('amNotPm');
    this.chase.alarm('mom', tooLoud ? 'Too loud! Mom is coming to check your room!' : "Time's up! Mom is coming to check your room!");
  }

  sentToBed() {
    this.award('oopsies');
    this.engine.timerOn = false;
    this.over = true;
    SN.sound.play('caught');
    this.show({ title: 'Go to sleep!', message: 'Mom caught you: "Why are you still awake? Bed. Now!"', symbol: '🌙', color: SN.palette.moon(),
      button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  momGaveUp() {
    this.award('shh');
    const e = this.engine;
    e.timeLeft = 120; e.timerOn = true; e.resetNoise();
    e.say('Mom gave up and went back to bed. 2 minutes until she wakes up again!', 4);
  }

  hint() {
    const e = this.engine;
    if (this.has('doorKey')) e.say('I can use the big key on the door!');
    else if (this.has('smallKey')) e.say('This little key might open something under the bed...');
    else { this.showGlint = true; e.say('Things like to hide under furniture. Maybe the table?'); }
  }

  get shadeAmount() { return this.lampOn ? 0.05 : 0.25; }

  // ---------- Drawing the bedroom (1000 × 700) ----------
  drawWorld(ctx, t, runner) {
    const D = SN.draw;
    // Wall with stars and moons
    let g = ctx.createLinearGradient(0, 0, 0, 450);
    g.addColorStop(0, SN.rgb(0.16, 0.17, 0.38)); g.addColorStop(1, SN.rgb(0.24, 0.22, 0.48));
    ctx.fillStyle = g; ctx.fillRect(0, 0, 1000, 450);
    for (let i = 0; i < 40; i++) {
      const x = (i % 10) * 100 + (Math.floor(i / 10) % 2 === 0 ? 30 : 80), y = Math.floor(i / 10) * 100 + 50;
      if (i % 3 === 0) D.moon(ctx, x, y, 12, 'rgba(255,255,255,.08)', SN.rgb(0.2, 0.2, 0.43)); else D.star(ctx, x, y, 7, 'rgba(255,255,255,.08)');
    }
    D.rect(ctx, 500, 448, 1000, 16, SN.rgb(0.36, 0.24, 0.2));
    // Floor
    g = ctx.createLinearGradient(0, 456, 0, 700);
    g.addColorStop(0, SN.rgb(0.4, 0.26, 0.18)); g.addColorStop(1, SN.rgb(0.52, 0.34, 0.22));
    ctx.fillStyle = g; ctx.fillRect(0, 456, 1000, 244);
    for (let i = 1; i < 6; i++) D.rect(ctx, 500, 456 + i * (i + 2) * 6, 1000, 2, 'rgba(0,0,0,.15)');
    // Window
    D.rrect(ctx, 600, 200, 220, 200, 8, SN.rgb(0.45, 0.3, 0.22));
    g = ctx.createLinearGradient(0, 115, 0, 285); g.addColorStop(0, SN.palette.skyTop()); g.addColorStop(1, SN.rgb(0.15, 0.18, 0.45));
    ctx.fillStyle = g; ctx.fillRect(505, 115, 190, 170);
    ctx.save(); ctx.shadowColor = SN.palette.moon(); ctx.shadowBlur = 18; D.circle(ctx, 640, 165, 56, SN.palette.moon()); ctx.restore();
    for (let i = 0; i < 6; i++) D.circle(ctx, 600 + i * 29 - 80, 200 + ((i * 37) % 120) - 50, 3, '#fff');
    D.rect(ctx, 600, 200, 8, 170, SN.rgb(0.45, 0.3, 0.22)); D.rect(ctx, 600, 200, 190, 8, SN.rgb(0.45, 0.3, 0.22));
    D.capsule(ctx, 482, 200, 34, 230, SN.rgb(0.55, 0.2, 0.35)); D.capsule(ctx, 718, 200, 34, 230, SN.rgb(0.55, 0.2, 0.35));
    // Moonbeam
    ctx.save(); ctx.globalCompositeOperation = 'screen';
    g = ctx.createLinearGradient(0, 290, 0, 700); g.addColorStop(0, SN.alpha(SN.palette.moon(), 0.18)); g.addColorStop(1, SN.alpha(SN.palette.moon(), 0.02));
    ctx.beginPath(); ctx.moveTo(515, 290); ctx.lineTo(685, 290); ctx.lineTo(760, 700); ctx.lineTo(360, 700); ctx.closePath(); ctx.fillStyle = g; ctx.fill();
    ctx.restore();
    // Door: opens when you leave, or when Mom comes in.
    SN.props.door(ctx, 905, 555, SN.rgb(0.55, 0.33, 0.2), this.doorOpen || this.chase.active, null);
    // Rug
    D.ellipse(ctx, 470, 630, 340, 80, SN.rgb(0.3, 0.45, 0.62)); D.ellipse(ctx, 470, 630, 318, 58, null, SN.rgb(0.95, 0.8, 0.45), 6);
    this.drawBed(ctx);
    this.drawTable(ctx, t);
    // Mom is drawn in depth order too, so she can walk in front of or behind you.
    const extra = this.chase.active && this.chase.visible ? [{ y: this.chase.y, draw: () => this.chase.draw(ctx) }] : [];
    runner.drawFloor(ctx, t, th => { if (th.kind === 'toybox') this.drawToyBox(ctx, th.x, th.y); }, extra);
    if (this.lampOn) {
      ctx.save(); ctx.globalCompositeOperation = 'screen';
      const r = ctx.createRadialGradient(730, 385, 10, 730, 385, 420);
      r.addColorStop(0, 'rgba(255,214,10,.35)'); r.addColorStop(1, 'rgba(255,214,10,0)');
      ctx.fillStyle = r; ctx.fillRect(0, 0, 1000, 700); ctx.restore();
    }
  }

  drawBed(ctx) {
    const D = SN.draw;
    D.rect(ctx, 235, 534, 300, 52, 'rgba(0,0,0,.55)');
    // Lockbox under the bed
    D.rrect(ctx, 250, 541, 76, 40, 4, SN.rgb(0.55, 0.55, 0.62));
    if (this.lockboxOpen) D.rotated(ctx, 210, 513, -70, () => D.rrect(ctx, 40, 0, 80, 14, 4, SN.rgb(0.42, 0.42, 0.5)));
    else { D.rrect(ctx, 250, 513, 80, 14, 4, SN.rgb(0.42, 0.42, 0.5)); D.text(ctx, '🔒', 250, 534, 14, SN.colors.gold); }
    D.rrect(ctx, 71, 455, 32, 210, 10, SN.rgb(0.45, 0.28, 0.18));
    D.rrect(ctx, 394, 490, 24, 140, 8, SN.rgb(0.45, 0.28, 0.18));
    D.rect(ctx, 235, 497, 300, 26, SN.rgb(0.5, 0.32, 0.2));
    D.rrect(ctx, 235, 469, 300, 34, 10, 'rgba(255,255,255,.9)');
    D.capsule(ctx, 132, 441, 80, 34, SN.rgb(0.92, 0.92, 1));
    const g = ctx.createLinearGradient(0, 440, 0, 498); g.addColorStop(0, SN.rgb(0.36, 0.62, 0.48)); g.addColorStop(1, SN.rgb(0.24, 0.48, 0.38));
    D.rrect(ctx, 282, 469, 225, 58, 16, g);
    // Teddy
    const bear = SN.rgb(0.7, 0.48, 0.3);
    D.circle(ctx, 330, 439, 46, bear); D.circle(ctx, 330, 417, 36, bear); D.circle(ctx, 316, 401, 14, bear); D.circle(ctx, 344, 401, 14, bear);
    D.circle(ctx, 324, 415, 4, '#000'); D.circle(ctx, 336, 415, 4, '#000');
  }

  drawTable(ctx, t) {
    const D = SN.draw;
    D.ellipse(ctx, 640, 561, 220, 26, 'rgba(0,0,0,.35)');
    if (this.showGlint && !this.foundSmallKey) SN.props.sparkle(ctx, 638, 538, t);
    D.rect(ctx, 559, 503, 14, 118, SN.rgb(0.42, 0.27, 0.17)); D.rect(ctx, 723, 503, 14, 118, SN.rgb(0.42, 0.27, 0.17));
    D.rrect(ctx, 640, 438, 210, 20, 6, SN.rgb(0.55, 0.36, 0.22));
    D.rrect(ctx, 590, 422, 60, 12, 2, 'rgba(255,59,48,.8)'); D.rrect(ctx, 591, 410, 52, 12, 2, 'rgba(48,176,199,.9)');
    // Lamp
    ctx.save();
    if (this.lampOn) { ctx.shadowColor = '#ffcc00'; ctx.shadowBlur = 20; }
    ctx.beginPath(); ctx.moveTo(688, 341); ctx.lineTo(712, 341); ctx.lineTo(733, 379); ctx.lineTo(677, 379); ctx.closePath();
    ctx.fillStyle = this.lampOn ? SN.rgb(1, 0.85, 0.45) : SN.rgb(0.75, 0.65, 0.5); ctx.fill();
    ctx.restore();
    D.rect(ctx, 705, 397, 6, 36, SN.rgb(0.3, 0.3, 0.35)); D.capsule(ctx, 705, 420, 34, 10, SN.rgb(0.3, 0.3, 0.35));
  }

  drawToyBox(ctx, x, y) {
    const D = SN.draw;
    D.circle(ctx, x - 16, y - 84, 30, '#ff3b30');
    D.rotated(ctx, x + 14, y - 86, 15, () => D.rrect(ctx, 0, 0, 24, 24, 3, '#ffcc00'));
    D.rrect(ctx, x, y - 38, 96, 66, 6, SN.rgb(0.25, 0.55, 0.85));
    D.text(ctx, 'TOYS', x, y - 38, 16, '#fff', 900);
  }
};
