// The game engine: moves the player around a room, jumping, crouching, carrying, dashing,
// bumping into noisy obstacles, the noise meter and the clock. Each level supplies the room
// and reacts through the on… hooks. (A port of GameEngine.swift.)

/// Obstacles that make a noise when you walk into them.
SN.hazards = {
  chair: ['chair', 'The chair scraped across the floor!'],
  table: ['table', 'You bumped the table. THUD!'],
  lamp: ['lamp', 'The lamp fell over. CRASH!'],
  toy: ['squeak', 'You stepped on a squeaky toy!'],
  shoes: ['table', "You tripped over Dad's big shoes. THUMP!"],
  basket: ['box', 'You knocked over the laundry basket!'],
  plank: ['creak', 'A loose plank creaked. CREEEAK!'],
  cans: ['lamp', 'You kicked the paint cans. CLANG!'],
};

/// One object in a room. `x, y` is where it stands on the floor; `fw × fh` is the floor it
/// covers (0 = it stands against the back wall).
SN.thing = function (o) {
  return Object.assign({
    kind: 'spot', x: 0, y: 0, fw: 0, fh: 0, solid: false, hazard: null, movable: false, heavy: false,
    prompt: null, reachW: 80, reachH: 160, hidden: false, open: false, patrol: null, speed: 0,
    crouchSafe: true, flat: false, sortOffset: 0,
  }, o);
};
SN.onFloor = t => t.fw > 0;
SN.covers = (t, x, y, padW = 0, padH = 0) => Math.abs(x - t.x) <= t.fw / 2 + padW && Math.abs(y - t.y) <= t.fh / 2 + padH;

SN.Engine = class {
  constructor() {
    this.width = 1000; this.height = 700; this.floor = [560, 680]; this.things = [];
    this.player = { x: 500, y: 620 }; this.z = 0; this.vz = 0;
    this.facingRight = true; this.walking = false; this.crouching = false; this.ducking = false;
    this.taunting = false; this.sprinting = false; this.hidden = false; this.coverY = null;
    this.speedBoost = false; this.jumpBoost = false; this.carrying = null;
    this.canDash = false; this.canRun = false; this.runHeld = false; this.shields = 0;
    this.speedBonus = 0; this.speedMult = 1; this.jumpMult = 1; this.dashMult = 1; this.noiseDiv = 1;
    this.frozen = false; this.defaultPrompt = null; this.tauntOnly = false;
    this.noise = 0; this.noiseFactor = 1; this.timeLeft = 100; this.timerOn = true; this.showsClock = true;
    this.running = false; this.paused = false;
    this.bubble = null; this.bubbleId = 0; this.nearest = null;
    this.stick = { x: 0, y: 0 };
    this.usesHP = false; this.hp = 100; this.maxHP = 100; this.hurt = false;
    this.flying = false; this.flyLeft = 0;
    this.walkSpeed = 290;
    this._dashTime = 0; this._dashDir = { x: 1, y: 0 }; this._dashCooldown = 0; this._input = { x: 0, y: 0 };
    this._tauntTime = 0; this._grace = 0; this._tooLoudSent = false; this._stepClock = 0; this._lastWhole = 1e9;
    this._hurtTime = 0; this._tested = new Set(); this._inPuddle = false;
    const nop = () => {};
    Object.assign(this, { onInteract: nop, onHazard: nop, onTimeUp: nop, onConfirm: nop, onTooLoud: nop, onShieldUsed: nop,
                          onDefaultInteract: nop, onTaunt: nop, onPuddle: nop, onItemKey: nop, onTick: nop, onKO: nop, onPause: nop, onMenuKey: nop });
  }

  get concealed() { return this.hidden || this.coverY !== null; }
  /// Practice mode: nobody can catch or hurt you.
  get safe() { return SN.settings.practiceOn(); }
  /// How fast you're able to go right now (running counts).
  get pace() { return this.walkSpeed * (this.sprinting ? 1.5 : 1); }

  load(layout) {
    this.width = layout.width; this.height = layout.height || 700; this.floor = layout.floor;
    this.things = layout.things; this.player = { x: layout.spawn.x, y: layout.spawn.y };
    this.carrying = null; this.hidden = false; this.ducking = false; this.coverY = null; this.taunting = false;
    this._tauntTime = 0; this._dashTime = 0; this.frozen = false; this.defaultPrompt = null;
    this.z = 0; this.vz = 0; this.nearest = null; this.flying = false; this.flyLeft = 0; this._tested = new Set();
  }

  index(id) { return this.things.findIndex(t => t.id === id); }
  thing(id) { return this.things.find(t => t.id === id); }
  /// Where a thing stands (for the Guide and hints), or null.
  spot(id) { const t = this.thing(id); return t && !t.hidden ? { x: t.x, y: t.y } : null; }

  ignoreHazards(seconds) { this._grace = seconds; }
  resetNoise() { this.noise = 0; this._tooLoudSent = false; }

  say(text, seconds = 2.8) {
    this.bubbleId++;
    this.bubble = text;
    const id = this.bubbleId;
    setTimeout(() => { if (this.bubbleId === id) this.bubble = null; }, seconds * 1000);
  }

  fly(seconds) { this.flying = true; this.flyLeft = seconds; this.ducking = false; this.carrying = null; }

  damage(amount) {
    if (!this.usesHP || !this.running || this._hurtTime > 0 || this.safe || this.hidden) return false;
    this.hp = Math.max(0, this.hp - amount * SN.difficulty.damageScale);
    this._hurtTime = 1.3; this.hurt = true;
    SN.sound.play('ouch');
    if (this.hp <= 0) { this.running = false; this.walking = false; this.onKO(); }
    return true;
  }

  // ---------- Actions (keyboard or on-screen buttons) ----------
  interact() {
    if (!this.running || this.frozen) return;
    if (this.nearest !== null) {
      if (this.springsTrap(this.nearest)) return;
      const th = this.things[this.nearest];
      this.onInteract(this.nearest);
      // Boxes (and drawers) can only be searched once: after that there's nothing to press.
      if (th && th.open && ['box', 'drawer', 'dresser', 'nightstand'].includes(th.kind)) th.prompt = null;
    }
    else if (this.defaultPrompt && !this.hidden) this.onDefaultInteract();
  }

  /// No Mercy: the first time you touch a box or drawer, it's 50-50 whether it was a trap.
  springsTrap(i) {
    const t = this.things[i];
    if (SN.difficulty.current !== 4 || this.safe || !t || !['box', 'dresser', 'nightstand'].includes(t.kind) || this._tested.has(t.id)) return false;
    this._tested.add(t.id);
    if (Math.random() < 0.5) return false;
    SN.sound.play('buzz'); SN.sound.play('ouch');
    this.say('OW! It was a trap!', 1.8);
    this.addNoise(45);
    this.damage(15);
    return true;
  }

  jump() {
    if (!this.running || this.frozen || this.z !== 0 || this.vz !== 0 || this.hidden || this.flying) return;
    if (this.ducking) { this.ducking = false; return; }
    this.vz = (this.jumpBoost ? 820 : 640) * Math.sqrt(this.jumpMult) * SN.difficulty.playerJump;
    SN.sound.play('jump', 0.6);
  }

  toggleCrouch() {
    if (!this.running || this.frozen || this.hidden || this.z !== 0 || this.flying) return;
    this.ducking = !this.ducking;
    if (this.ducking) this.carrying = null;
    SN.sound.play('crouch', 0.6);
  }

  taunt() {
    if ((!this.running && !this.tauntOnly) || this.hidden || this._tauntTime > 0) return;
    this.taunting = true; this._tauntTime = 0.9;
    SN.sound.play('taunt', 0.8);
    this.say(SN.pick(['Nyeh nyeh!', "Can't catch me!", 'Hee hee hee!', 'Ninja mode!', 'Too sneaky for you!']), 1.4);
    this.addNoise(SN.difficulty.tauntNoise, true);
    this.onTaunt();
  }

  dash() {
    // Pressing dash again in the middle of a dash stops it right there.
    if (this._dashTime > 0) { this._dashTime = 0; return; }
    if (!this.running || this.frozen || !this.canDash || this.hidden || this._dashCooldown > 0) return;
    this.ducking = false;
    const len = Math.hypot(this._input.x, this._input.y);
    this._dashDir = len > 0.2 ? { x: this._input.x / len, y: this._input.y / len } : { x: this.facingRight ? 1 : -1, y: 0 };
    this._dashTime = Math.min(1, 0.17 * this.dashMult);
    this._dashCooldown = 1.2;
    SN.sound.play('dash');
  }

  /// `plain`: the amount is already set for the difficulty, so Easy's quiet steps don't apply again.
  addNoise(amount, plain = false) {
    this.noise = Math.min(100, this.noise + amount * this.noiseFactor / this.noiseDiv / (plain ? 1 : SN.difficulty.quiet));
  }

  moveObject() {
    if (!this.running || this.frozen || this.hidden) return;
    if (this.carrying) { this.carrying = null; SN.sound.play('box', 0.5); return; }
    const near = this.things.filter(t => (t.movable || t.heavy) && !t.hidden
      && Math.abs(t.x - this.player.x) <= Math.max(110, t.reachW) && Math.abs(t.y - this.player.y) <= t.reachH);
    near.sort((a, b) => Math.abs(a.x - this.player.x) - Math.abs(b.x - this.player.x));
    const t = near[0];
    if (!t) { this.say("There's nothing here I can move."); return; }
    if (t.heavy) { SN.sound.play('heavy'); this.say("Too heavy! I can't move that."); return; }
    this.carrying = t.id;
    SN.sound.play('box', 0.5);
  }

  // ---------- Game loop ----------
  step(dt) {
    const pressed = SN.input.take();
    if (pressed.has('pause')) this.onPause();
    if (this.paused) { this.walking = false; return; }
    for (const k of ['menu', 'restart', 'hint']) if (pressed.has(k)) this.onMenuKey(k);

    if (!this.running) {
      this.walking = false; this.sprinting = false;
      if (this.tauntOnly) {
        this._timers(dt);
        if (pressed.has('taunt')) this.taunt();
        this._itemKeys(pressed);
      } else if (pressed.has('use') || pressed.has('jump')) {
        this.onConfirm();
      }
      return;
    }

    if (this.timerOn) {
      this.timeLeft = Math.max(0, this.timeLeft - dt);
      const whole = Math.ceil(this.timeLeft);
      if (whole !== this._lastWhole) {
        this._lastWhole = whole;
        if (whole <= 10 && whole > 0) SN.sound.play('tick', 0.6);
      }
      if (this.timeLeft <= 0) { this.timerOn = false; this.walking = false; this.onTimeUp(); return; }
    }

    const run = this.canRun && (SN.input.held('run') || this.runHeld) && !this.ducking;
    this._move(run, dt);
    this._jump(dt);
    this._things(dt);
    this._timers(dt);
    if (this._hazards()) return;
    this._updateNearest();
    this._cover();
    if (this.sprinting) this.addNoise(15 * dt);
    this.noise = Math.max(0, this.noise - 9 * dt);
    if (this.noise >= 99.5 && !this._tooLoudSent) { this._tooLoudSent = true; this.onTooLoud(); }
    this.onTick(dt);

    if (pressed.has('use')) this.interact();
    if (pressed.has('jump')) this.jump();
    if (pressed.has('carry')) this.moveObject();
    if (pressed.has('crouch')) this.toggleCrouch();
    if (pressed.has('taunt')) this.taunt();
    if (pressed.has('dash')) this.dash();
    this._itemKeys(pressed);
  }

  _itemKeys(pressed) { SN.items.forEach((name, i) => { if (pressed.has(name)) this.onItemKey(name); }); }

  _timers(dt) {
    this._dashTime = Math.max(0, this._dashTime - dt);
    this._dashCooldown = Math.max(0, this._dashCooldown - dt);
    this._grace = Math.max(0, this._grace - dt);
    if (this._hurtTime > 0) { this._hurtTime -= dt; if (this._hurtTime <= 0) this.hurt = false; }
    if (this.flying) { this.flyLeft -= dt; if (this.flyLeft <= 0) { this.flying = false; this.flyLeft = 0; } }
    if (this._tauntTime > 0) { this._tauntTime -= dt; if (this._tauntTime <= 0) this.taunting = false; }
  }

  _move(run, dt) {
    let v = { x: this.stick.x, y: this.stick.y };
    if (SN.input.held('left')) v.x -= 1;
    if (SN.input.held('right')) v.x += 1;
    if (SN.input.held('up')) v.y -= 1;
    if (SN.input.held('down')) v.y += 1;
    const len = Math.hypot(v.x, v.y);
    if (len > 1) { v.x /= len; v.y /= len; }
    this._input = { x: v.x, y: v.y };
    if (this.hidden || this.crouching || this.frozen) v = { x: 0, y: 0 };

    // Boosts stack, but anything past 1100 is too fast to steer.
    let speed = Math.min(1100, (this.speedBoost ? 440 : 290) * (1 + this.speedBonus) * this.speedMult * SN.difficulty.playerSpeed);
    this.walkSpeed = speed;
    if (this.ducking) speed *= 0.5; else if (run) speed *= 1.5;
    if (this._dashTime > 0) { v = this._dashDir; speed = 1050; }
    // No Mercy water puddles: wading slows you right down, and the first splash is heard.
    const wading = this.z < 10 && !this.flying && this.things.some(t => t.kind === 'puddle' && !t.hidden && SN.covers(t, this.player.x, this.player.y));
    if (wading) {
      speed *= 0.4;
      if (!this._inPuddle) { SN.sound.play('water'); this.addNoise(25); this.onPuddle(); }
    }
    this._inPuddle = wading;

    const stuck = this._blocked(this.player.x, this.player.y);
    let px = this.player.x, py = this.player.y;
    const nx = SN.clamp(px + v.x * speed * dt, 40, this.width - 40);
    if (stuck || !this._blocked(nx, py)) px = nx;
    const ny = SN.clamp(py + v.y * speed * 0.7 * dt, this.floor[0], this.floor[1]);
    if (stuck || !this._blocked(px, ny)) py = ny;
    this.player.x = px; this.player.y = py;

    this.walking = (len > 0.15 || this._dashTime > 0) && !this.hidden && !this.crouching;
    this.sprinting = run && this.walking;
    // Turn to face left or right only when really going sideways, not when the stick wobbles a
    // little while you walk up or down.
    if (Math.abs(v.x) >= 0.3 && Math.abs(v.x) >= Math.abs(v.y) * 0.4) this.facingRight = v.x > 0;
    if (this.walking && this.z === 0) {
      this._stepClock += dt;
      if (this._stepClock > (this.sprinting ? 0.2 : 0.32)) {
        this._stepClock = 0;
        SN.sound.play('step', this.ducking ? 0.18 : this.sprinting ? 0.65 : 0.45);
      }
    }
  }

  _jump(dt) {
    if (this.flying) { this.z = Math.min(130, this.z + 420 * dt); this.vz = 0; return; }
    if (this.z <= 0 && this.vz <= 0) return;
    this.vz -= 1800 * dt;
    this.z = Math.max(0, this.z + this.vz * dt);
    if (this.z === 0) {
      this.vz = 0;
      SN.sound.play('land', 0.5);
      // Landed on top of a box: slide off to the nearer side.
      const box = this.things.find(t => t.solid && !t.hidden && t.id !== this.carrying && SN.covers(t, this.player.x, this.player.y, 6, 0));
      if (box) {
        const side = this.player.x >= box.x ? 1 : -1;
        this.player.x = SN.clamp(box.x + side * (box.fw / 2 + 20), 40, this.width - 40);
      }
    }
  }

  _things(dt) {
    if (this.carrying) {
      const t = this.thing(this.carrying);
      if (t) { t.x = SN.clamp(this.player.x + (this.facingRight ? 78 : -78), 40, this.width - 40); t.y = this.player.y + 2; }
    }
    for (const t of this.things) {
      if (!t.patrol || t.hidden) continue;
      t.x += t.speed * dt * SN.difficulty.hazardSpeed;
      if (t.x > t.patrol[1]) { t.x = t.patrol[1]; t.speed = -Math.abs(t.speed); }
      else if (t.x < t.patrol[0]) { t.x = t.patrol[0]; t.speed = Math.abs(t.speed); }
    }
  }

  /// Walking into an obstacle makes a noise. Jumping clears it; crouching makes most of them safe.
  _hazards() {
    if (this.z >= 14 || this.hidden || this._grace > 0) return false;
    const i = this.things.findIndex(t => t.hazard && !t.hidden && !(this.ducking && t.crouchSafe) && SN.covers(t, this.player.x, this.player.y, -4, -6));
    if (i < 0) return false;
    if (this.shields > 0) {
      this.shields--; this._grace = 1.2;
      SN.sound.play('crouch');
      this.say('Phew! My Silent Slippers kept it quiet.');
      this.onShieldUsed();
      return false;
    }
    this.running = false; this.walking = false;
    SN.sound.play(SN.hazards[this.things[i].hazard][0]);
    this.onHazard(i);
    return true;
  }

  _updateNearest() {
    let best = null, bestD = 1e9;
    this.things.forEach((t, i) => {
      if (!t.prompt || t.hidden || t.id === this.carrying) return;
      const dx = Math.abs(t.x - this.player.x), dy = Math.abs(t.y - this.player.y);
      if (dx <= t.reachW && dy <= t.reachH && dx < bestD) { best = i; bestD = dx; }
    });
    this.nearest = best;
  }

  /// Crouching inside a table's footprint hides you under it.
  _cover() {
    let y = null;
    if (this.ducking && !this.hidden) {
      const t = this.things.find(t => t.hazard === 'table' && !t.hidden && SN.covers(t, this.player.x, this.player.y, 6, 10));
      if (t) y = t.y;
    }
    this.coverY = y;
  }

  _blocked(x, y) {
    if (this.flying) return false;
    // In the air you clear small things like boxes.
    return this.things.some(t => t.solid && !t.hidden && t.id !== this.carrying && !(this.z > 24 && t.movable) && SN.covers(t, x, y, 6, 0));
  }

  /// What E will do right now.
  get currentPrompt() {
    if (this.nearest !== null && this.things[this.nearest]) return this.things[this.nearest].prompt;
    return this.hidden ? null : this.defaultPrompt;
  }
};

/// Permanent items and the boosts you're wearing. (A port of ItemBelt.swift.)
SN.ItemBelt = class {
  constructor() {
    this.owned = []; this.cooldowns = {}; this.lightningLeft = 0; this.boosts = [];
    this.stun = () => false;
  }
  configure(game, engine) {
    this.engine = engine;
    this.boosts = game.look.boosts.slice();
    this.owned = [];
    if (game.hasVines) this.owned.push('vines');
    if (game.boosts.includes('lightningBall') && this.boosts.includes('lightningBall')) this.owned.push('lightning');
    if (game.hasToy) this.owned.push('toy');
    if (game.hasBat) this.owned.push('bat');
    if (game.boosts.includes('cloud') && this.boosts.includes('cloud')) this.owned.push('cloud');
    if (game.boosts.includes('waterHose') && this.boosts.includes('waterHose')) this.owned.push('hose');
    this.apply();
  }
  reset() { this.cooldowns = {}; this.lightningLeft = 0; this.apply(); }
  tick(dt) {
    for (const k in this.cooldowns) this.cooldowns[k] = Math.max(0, this.cooldowns[k] - dt);
    if (this.lightningLeft > 0) { this.lightningLeft = Math.max(0, this.lightningLeft - dt); if (this.lightningLeft === 0) this.apply(); }
  }
  use(item) {
    const e = this.engine;
    if (!e || !this.owned.includes(item) || (this.cooldowns[item] || 0) > 0) return;
    if (item === 'vines') {
      if (this.stun(10, false)) { this.cooldowns.vines = 35; SN.sound.play('whip'); } else e.say('There\'s nobody here to use the vines on.');
    } else if (item === 'toy') {
      if (this.stun(60, true)) { this.cooldowns.toy = 50; SN.sound.play('squeak'); } else e.say("Mom isn't here to throw the toy at.");
    } else if (item === 'bat') {
      if (this.stun(2, true)) { this.cooldowns.bat = 5; SN.sound.play('bonk'); } else e.say("Mom isn't here to bonk.");
    } else if (item === 'lightning') {
      if (!e.running) return;
      this.lightningLeft = 25; this.cooldowns.lightning = 85;
      SN.sound.play('powerup'); e.say('LIGHTNING POWER!', 1.5); this.apply();
    } else if (item === 'hose') {
      // A blast of water in the face: whoever is chasing you can't see for 8 seconds. Ready again after 25.
      if (this.stun(8, false)) { this.cooldowns.hose = 25; SN.sound.play('water'); e.say("SPLASH! Can't see me now!", 1.5); }
      else e.say('There\'s nobody here to spray.');
    } else if (item === 'cloud') {
      if (!e.running || e.hidden) return;
      e.fly(10); this.cooldowns.cloud = 40;
      SN.sound.play('magic'); e.say('Up, up and away!', 1.5);
    }
  }
  apply() {
    let speed = 1, jump = 1, dash = 1, quiet = 1;
    const b = this.boosts;
    if (b.includes('coolCap')) speed *= 1.5;
    if (b.includes('leaf')) jump *= 1.3;
    if (b.includes('windCrown')) { speed *= 1.2; dash *= 2.5; }
    if (b.includes('goldenCrown')) { speed *= 1.2; jump *= 1.2; dash *= 1.2; quiet *= 1.5; }
    if (b.includes('arrow')) { speed *= 1.2; dash *= 1.9; }
    if (this.lightningLeft > 0) { speed *= 3.5; jump *= 3.5; dash *= 3.5; quiet *= 1.75; }
    if (this.engine) Object.assign(this.engine, { speedMult: speed, jumpMult: jump, dashMult: dash, noiseDiv: quiet });
  }
};
SN.itemInfo = {
  vines: { icon: '🌿', color: '#34c759' }, lightning: { icon: '⚡', color: '#ffcc00' }, toy: { icon: '🧸', color: '#ff2d55' },
  bat: { icon: '🏏', color: '#ff9500' }, cloud: { icon: '☁️', color: '#73b3ff' }, hose: { icon: '💧', color: '#40b3d9' },
};
