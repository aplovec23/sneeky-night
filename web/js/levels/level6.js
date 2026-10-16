// Level 6 rules: Auntie knows where Grandpa is, but first she wants her 10 chores done.
// The house has a downstairs and an upstairs. Each chore is done by pressing E at the right
// thing (some need several presses or several places), sweeping is done by walking over the
// dust, and the rubbish bag has to be carried to the bin. Her cats sleep on the floor:
// stepping on one costs time. When every chore is ticked, Auntie walks to the back door;
// follow her out to the backyard to win. There's nobody to catch you here, only the clock.
// (A port of Level6Auntie.swift.)

SN.hazards.cat = ['squeak', "You stepped on a cat's tail. MEOWWW!"];

SN.Level6 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.run = 0;
    const e = this.engine;
    e.onInteract = i => this.interact(i);
    e.onHazard = () => this.steppedOn();
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

  /// How much of the counted chores there is: less on Easy, more on Hard and above.
  static amount(easy, mild, hard) { return SN.difficulty.pick(easy, mild, hard); }

  title() { return this.floor === 'down' ? "Level 6 · Auntie's House" : 'Level 6 · Upstairs'; }
  award(b) { this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return this.phase === 'over'; }
  get choresDone() { return this.chores.filter(c => c.done >= c.needed).length; }
  get nextChore() { return this.chores.find(c => c.done < c.needed); }
  label(c) { return c.needed > 1 ? `${c.title} (${Math.min(c.done, c.needed)}/${c.needed})` : c.title; }
  /// The list in the corner of the screen.
  cornerHint() {
    if (this.phase !== 'chores') return `All ${SN.Level6.choreCount} chores done! Follow Auntie to the back door.`;
    return `🧹 Chores ${this.choresDone}/${SN.Level6.choreCount}   ·   next: ${this.nextChore ? this.label(this.nextChore) : ''}`;
  }
  get inventory() { return this.hasGlasses ? [{ id: 'glasses', icon: '👓', color: '#32ade6' }] : []; }

  reset() {
    this.run++;
    const A = SN.Level6, a = A.amount, e = this.engine;
    const c = (id, title, needed) => ({ id, title, needed, done: 0 });
    this.chores = [
      c('dishes', 'Wash the dishes', 3), c('cats', 'Fill the cat bowls', a(1, 2, 3)), c('plants', 'Water the plants', a(2, 4, 7)),
      c('sweep', 'Sweep up the dust', a(3, 5, 9)), c('trash', 'Take out the rubbish', 1), c('table', 'Set the table', 3),
      c('shelf', 'Dust the bookshelf', 3), c('bed', 'Make the bed', 2), c('socks', 'Pick up the socks', a(2, 4, 7)),
      c('glasses', "Find Auntie's glasses", 1),
    ];
    const down = A.downThings(), up = A.upThings();
    this.saved = { up };
    this.glassesIn = SN.pick(down.concat(up).filter(t => t.kind === 'drawer' || t.kind === 'box').map(t => t.id));
    this.floor = 'down';
    e.load({ width: A.downWidth, floor: [545, 690], things: down, spawn: { x: 240, y: 620 } });
    e.usesHP = false;
    e.timeLeft = SN.levelTime(6); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.runHeld = false; e.speedBonus = 0;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.belt.reset();
    Object.assign(this, {
      phase: 'chores', hasGlasses: false, popup: null, banner: null, bannerTime: 0, doorOpen: false,
      auntie: { x: 700, y: 590 }, auntieWalking: false, auntieRight: true, auntieSays: null, sayTime: 0,
    });
    e.running = true;
    this.speak("Ten chores, dear. Then I'll show you something.", 4);
  }

  // ---------- The house ----------
  static spot(id, kind, x, y, w, h, prompt) { return SN.thing({ id, kind, x, y, fw: w, fh: h, prompt, reachW: 70, reachH: 50, flat: true }); }

  static cat(id, x, y, wanders) {
    // On Hard and above the cats don't stay asleep: they pad up and down.
    return SN.thing({ id, kind: 'cat', x, y, fw: 62, fh: 24, hazard: 'cat', patrol: wanders ? [x - 220, x + 220] : null, speed: wanders ? 90 : 0 });
  }

  static downThings() {
    const W = SN.Level2.onWall, A = SN.Level6, mode = SN.difficulty.current;
    const things = [
      W('frontDoor', 'frontDoor', 110, 'Look outside'), W('bin', 'bin', 330, 'Put rubbish in the bin', 60),
      W('shelf', 'shelf', 560, 'Dust the bookshelf', 70), W('drawer1', 'drawer', 900, 'Look in the drawer'),
      W('stairs', 'stairsUp', 1250, 'Go upstairs', 80), W('table', 'dinner', 1620, 'Set the table', 110),
      W('bowls', 'bowls', 1960, 'Fill a cat bowl', 70), W('sink', 'sink', 2330, 'Wash the dishes', 90),
      W('drawer2', 'drawer', 2680, 'Look in the drawer'), W('backDoor', 'backDoor', A.backDoor, "It's locked", 90),
      SN.thing({ id: 'bag', kind: 'bag', x: 2880, y: 640, fw: 54, fh: 26, solid: true, movable: true }),
      SN.Level2.box('box1', 3120, 600),
      A.cat('cat1', 760, 650, mode >= 2), A.cat('cat2', 2100, 600, false),
    ];
    if (mode >= 2) things.push(A.cat('cat3', 3000, 670, mode >= 3));
    return things.concat(A.extras(true));
  }

  static upThings() {
    const W = SN.Level2.onWall, A = SN.Level6, mode = SN.difficulty.current;
    const things = [
      W('stairs', 'stairsDown', 130, 'Go downstairs', 80), W('drawer3', 'drawer', 480, 'Look in the drawer'),
      W('bed', 'bed', 980, 'Make the bed', 140), W('drawer4', 'drawer', 1420, 'Look in the drawer'),
      SN.Level2.box('box2', 1700, 640), W('study', 'study', 2230, 'Try the door', 80),
      A.cat('cat4', 1200, 660, mode >= 3),
    ];
    if (mode !== 0) things.push(A.cat('cat5', 1950, 600, false));
    return things.concat(A.extras(false));
  }

  /// Plants to water, dust to sweep and socks to pick up, shared out between the two floors.
  static extras(down) {
    const A = SN.Level6, W = SN.Level2.onWall, things = [], width = down ? A.downWidth : A.upWidth, p = down ? 'd' : 'u';
    const share = total => down ? Math.floor((total + 1) / 2) : Math.floor(total / 2);
    // Spots along the wall that are clear of the furniture.
    const pots = down ? [1080, 2130, 2900, 440] : [720, 1900, 1200, 300];
    const plants = share(A.amount(2, 4, 7));
    for (let i = 0; i < Math.min(plants, pots.length); i++) things.push(W(p + 'plant' + i, 'houseplant', pots[i], 'Water the plant', 55));
    const dust = share(A.amount(3, 5, 9));
    for (let i = 0; i < dust; i++) things.push(A.spot(p + 'dust' + i, 'dust', 460 + i * (width - 800) / Math.max(dust, 1), [600, 670, 630][i % 3], 50, 20, null));
    const socks = share(A.amount(2, 4, 7));
    for (let i = 0; i < socks; i++) things.push(A.spot(p + 'sock' + i, 'sock', 620 + i * (width - 1000) / Math.max(socks, 1), [680, 585, 650][i % 3], 36, 16, 'Pick up the sock'));
    return things;
  }

  go(floor) {
    const e = this.engine, A = SN.Level6, down = floor === 'down';
    SN.sound.play('door', 0.5);
    this.saved[this.floor] = e.things;
    e.load({ width: down ? A.downWidth : A.upWidth, floor: [545, 690], things: this.saved[floor] || [], spawn: { x: down ? 1250 : 240, y: 600 } });
    this.floor = floor;
  }

  show(p) { SN.levelShow(this, p); }

  // ---------- Chores ----------
  tick(dt) {
    const e = this.engine;
    if (this.bannerTime > 0) { this.bannerTime -= dt; if (this.bannerTime <= 0) this.banner = null; }
    if (this.sayTime > 0) { this.sayTime -= dt; if (this.sayTime <= 0) this.auntieSays = null; }
    if (this.phase === 'over') return;
    // Sweeping: just walk over the dust.
    const dust = e.things.find(t => t.kind === 'dust' && !t.hidden && Math.abs(t.x - e.player.x) < 40 && Math.abs(t.y - e.player.y) < 30);
    if (dust && e.z < 20) { dust.hidden = true; SN.sound.play('rustle', 0.5); this.progress('sweep'); }
    if (this.phase === 'following') this.lead(dt);
  }

  interact(i) {
    const e = this.engine, th = e.things[i], A = SN.Level6;
    switch (th.kind) {
      case 'stairsUp': return this.go('up');
      case 'stairsDown': return this.go('down');
      case 'frontDoor': return e.say("Uncle's car has gone. No going back now!");
      case 'study': return e.say("Locked. I can hear paper rustling inside... Grandpa's letters?", 3.2);
      case 'sink': return this.work(th, 'dishes', 'water');
      case 'dinner': return this.work(th, 'table', 'drawer');
      case 'shelf': return this.work(th, 'shelf', 'rustle');
      case 'bed': return this.work(th, 'bed', 'closet');
      case 'bowls': return this.work(th, 'cats', 'box');
      case 'houseplant': th.open = true; th.prompt = null; SN.sound.play('water', 0.6); return this.progress('plants');
      case 'sock': th.hidden = true; SN.sound.play('paper', 0.5); return this.progress('socks');
      case 'bin':
        if (e.carrying === 'bag') {
          e.carrying = null;
          const bag = e.thing('bag'); if (bag) bag.hidden = true;
          SN.sound.play('box');
          return this.progress('trash');
        }
        if (this.chore('trash').done >= 1) return e.say('The rubbish is already out.');
        return e.say('The rubbish bag is by the kitchen. Pick it up with the box button (R) and bring it here.', 3.5);
      case 'drawer': case 'box': return this.search(th);
      case 'backDoor':
        if (this.phase === 'following' && Math.abs(this.auntie.x - A.backDoor) < 260) return this.win();
        if (this.phase === 'following') return e.say('I should wait for Auntie.');
        return e.say(`Locked. Auntie has the key. ${A.choreCount - this.choresDone} chores to go.`);
    }
  }

  chore(id) { return this.chores.find(c => c.id === id); }

  /// A chore done by pressing E a few times at one thing.
  work(th, id, sound) {
    const c = this.chore(id);
    if (c.done >= c.needed) { this.engine.say("That's done already."); return; }
    SN.sound.play(sound, 0.7);
    this.progress(id);
    if (c.done >= c.needed) th.open = true;
  }

  search(th) {
    const e = this.engine;
    th.open = true;
    SN.sound.play('drawer');
    if (th.id === this.glassesIn && this.chore('glasses').done < 1) {
      this.hasGlasses = true;
      this.progress('glasses');
      e.say("Auntie's glasses! In here the whole time.", 2.2);
      return;
    }
    const loot = this.game.rollLoot();
    if (loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); }
    else e.say(SN.pick(['Buttons. So many buttons.', 'Cat toys.', 'Old postcards from Grandpa!', 'Knitting wool.']));
  }

  progress(id) {
    const c = this.chore(id), A = SN.Level6;
    if (!c || c.done >= c.needed) return;
    c.done++;
    if (c.done < c.needed) return;
    SN.sound.play('powerup');
    this.banner = `Checkpoint! ${c.title}: done. ${this.choresDone}/${A.choreCount}`;
    this.bannerTime = 2.2;
    this.speak(SN.pick(['Good.', 'Very nice, dear.', 'Your Grandpa would be proud.', 'Hm. Not bad at all.', "That's the way."]), 2.4);
    if (this.choresDone === A.choreCount) this.allDone();
  }

  allDone() {
    const A = SN.Level6;
    this.phase = 'following';
    this.engine.timerOn = false;
    const door = (this.floor === 'down' ? this.engine.things : this.saved.down || []).find(t => t.id === 'backDoor');
    if (door) door.prompt = 'Go out to the backyard';
    this.banner = `Checkpoint! All ${A.choreCount} chores done. Follow Auntie!`;
    this.bannerTime = 4;
    this.speak("All ten! Come along. There's something in the backyard you should see.", 5);
  }

  /// Auntie walks to the back door, never faster than you, and waits if you fall behind.
  lead(dt) {
    if (this.floor !== 'down') { this.auntieWalking = false; return; }
    const e = this.engine, a = this.auntie, target = SN.Level6.backDoor - 110;
    const dx = target - a.x, tooFarAhead = a.x - e.player.x > 420;
    if (Math.abs(dx) > 6 && !tooFarAhead) {
      a.x += Math.sign(dx) * Math.min(Math.abs(dx), Math.min(200, Math.max(110, e.pace)) * dt);
      this.auntieRight = dx > 0; this.auntieWalking = true;
    } else {
      this.auntieWalking = false;
      if (Math.abs(dx) <= 6 && !this.doorOpen) { this.doorOpen = true; SN.sound.play('unlock'); this.speak('Here we are. After you, dear.', 4); }
      else if (tooFarAhead && !this.auntieSays) this.speak('Keep up, dear!', 2);
    }
  }

  speak(text, seconds) { this.auntieSays = text; this.sayTime = seconds; }

  // ---------- Trouble ----------
  steppedOn() {
    const e = this.engine;
    e.ignoreHazards(2.5);
    e.running = true;
    if (this.phase !== 'chores' || e.safe) return;
    const lost = Math.round(15 * SN.difficulty.damageScale);
    e.timeLeft = Math.max(1, e.timeLeft - lost);
    this.banner = `MEOW! Auntie: "Mind my cats!"  −${lost} seconds`;
    this.bannerTime = 2.6;
  }

  tooLoud() {
    const e = this.engine;
    e.resetNoise();
    if (this.phase !== 'chores' || e.safe) return;
    e.timeLeft = Math.max(1, e.timeLeft - 20);
    this.banner = 'Auntie: "Shh! You\'ll wake the whole street!"  −20 seconds';
    this.bannerTime = 2.6;
  }

  tooSlow() {
    if (this.phase !== 'chores') return;
    this.award('amNotPm');
    this.phase = 'over';
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title: 'Too slow!', message: `Auntie: "Look at the time! Off to bed with you. We'll try again tomorrow."\nYou did ${this.choresDone} of ${SN.Level6.choreCount} chores.`,
      symbol: '⏰', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  win() {
    this.phase = 'over';
    this.engine.running = false;
    this.game.complete(6);
    SN.sound.play('door'); SN.sound.play('win');
    this.show({ title: 'Level Complete!', message: 'Auntie opens the door to her backyard. Something out there is glowing...', symbol: '⭐', color: SN.colors.gold,
      button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  hint() {
    const e = this.engine;
    if (this.phase !== 'chores') { e.say(this.floor === 'up' ? 'Auntie is downstairs. Take the stairs!' : 'Follow Auntie to the back door at the far right, then press E.'); return; }
    const next = this.nextChore;
    if (!next) return;
    const whereTo = {
      dishes: 'The sink is in the kitchen, downstairs on the right. Press E three times.',
      cats: 'The cat bowls are downstairs, next to the table. Press E once for each bowl.',
      plants: 'Press E at every plant pot. Some are upstairs.',
      sweep: 'Just walk over every little pile of dust. Some are upstairs.',
      trash: 'Pick up the rubbish bag near the kitchen with R, carry it to the bin by the front door, and press E at the bin.',
      table: 'The dinner table is downstairs in the middle. Press E three times.',
      shelf: 'The bookshelf is downstairs near the front door. Press E three times.',
      bed: 'The bed is upstairs. Press E twice.',
      socks: 'Press E at each sock on the floor. Some are upstairs.',
      glasses: "Auntie's glasses are in a drawer or a box somewhere. Press E at each one.",
    };
    e.say(`Next: ${this.label(next)}. ${whereTo[next.id] || ''}`, 4.5);
  }

  get shadeAmount() { return 0.14; }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, D = SN.draw, L6 = SN.Level6;
    L6.wall(ctx, e.width, this.floor === 'up');
    const tick = (x, y, done) => { if (done) { D.circle(ctx, x, y, 40, '#fff'); D.text(ctx, '✓', x, y + 1, 30, '#34c759', 900); } };
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'frontDoor': P.door(ctx, x, y, SN.rgb(0.95, 0.78, 0.2), false); break;
        case 'backDoor': P.door(ctx, x, y, SN.rgb(0.25, 0.50, 0.40), this.doorOpen, 'BACKYARD', '#34c759'); break;
        case 'study': P.door(ctx, x, y, SN.rgb(0.35, 0.25, 0.45), false, 'STUDY', '#af52de'); break;
        case 'stairsUp': P.stairsDoor(ctx, x, y, true); break;
        case 'stairsDown': P.stairsDoor(ctx, x, y, false); break;
        case 'bin': P.bin(ctx, x, y); break;
        case 'shelf': P.bookshelf(ctx, x, y); tick(x, y - 270, th.open); break;
        case 'drawer': P.dresser(ctx, x, y, th.open); break;
        case 'dinner': L6.dinnerTable(ctx, x, y, th.open); break;
        case 'bowls': L6.catBowls(ctx, x, y, th.open); break;
        case 'sink': L6.sink(ctx, x, y, th.open, t); break;
        case 'bed': P.momBed(ctx, x, y, true); tick(x, y - 210, th.open); break;
        case 'houseplant': L6.housePlant(ctx, x, y, th.open); break;
      }
    }
    if (this.floor === 'down') {
      const a = this.auntie;
      SN.people.mom(ctx, a.x, a.y, { walking: this.auntieWalking, facingRight: this.auntieRight, robe: SN.rgb(0.20, 0.55, 0.55), noCurlers: true, bun: true, calm: true, t });
      if (this.auntieSays) SN.people.speech(ctx, a.x, a.y - 280, 'Auntie: ' + this.auntieSays, '#30b0c7', true);
    }
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'cat': L6.drawCat(ctx, x, y, th.patrol !== null, th.speed > 0, t); break;
        case 'dust': D.ellipse(ctx, x, y, 54, 18, 'rgba(191,191,191,.75)'); D.circle(ctx, x - 10, y - 6, 18, 'rgba(217,217,217,.8)'); D.circle(ctx, x + 10, y - 5, 14, 'rgba(204,204,204,.8)'); break;
        case 'sock': L6.sock(ctx, x, y, th.id.length + Math.round(x)); break;
        case 'bag': L6.bag(ctx, x, y + 14); break;
        case 'box': P.box(ctx, x, y + th.fh / 2, th.open); break;
      }
    }, []);
  }

  // ---------- Art ----------
  static wall(ctx, width, upstairs) {
    const D = SN.draw;
    const g = ctx.createLinearGradient(0, 0, 0, 545);
    if (upstairs) { g.addColorStop(0, SN.rgb(0.30, 0.28, 0.42)); g.addColorStop(1, SN.rgb(0.40, 0.34, 0.48)); }
    else { g.addColorStop(0, SN.rgb(0.36, 0.30, 0.24)); g.addColorStop(1, SN.rgb(0.46, 0.38, 0.28)); }
    ctx.fillStyle = g; ctx.fillRect(0, 0, width, 545);
    for (let i = 0; i < width / 150; i++) D.paw(ctx, i * 150 + 70, i % 2 === 0 ? 170 : 300, 22, 'rgba(255,255,255,.06)');
    ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.fillRect(0, 531, width, 14);
    ctx.fillStyle = upstairs ? SN.rgb(0.45, 0.36, 0.30) : SN.rgb(0.55, 0.42, 0.28); ctx.fillRect(0, 545, width, 155);
    ctx.fillStyle = 'rgba(0,0,0,.08)'; for (let i = 0; i < width / 110; i++) ctx.fillRect(i * 110, 545, 2, 155);
    for (let i = 0; i < Math.floor(width / 900); i++) {
      const wx = i * 900 + 760;
      const s = ctx.createLinearGradient(0, 185, 0, 315); s.addColorStop(0, SN.palette.skyTop()); s.addColorStop(1, SN.palette.skyBottom());
      ctx.fillStyle = s; ctx.beginPath(); ctx.roundRect(wx - 75, 185, 150, 130, 8); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.8)'; ctx.lineWidth = 8; ctx.stroke();
      SN.props.picture(ctx, i * 900 + 1150, 240, i * 3 + 1);
    }
    D.ellipse(ctx, width * 0.45, 630, 620, 110, 'rgba(140,64,77,.7)');
    D.ellipse(ctx, width * 0.45, 630, 560, 86, null, SN.alpha(SN.colors.gold, 0.5), 4);
  }

  static drawCat(ctx, x, y, awake, facingRight, t) {
    const D = SN.draw, fur = SN.rgb(0.95, 0.65, 0.28), ear = SN.rgb(0.85, 0.52, 0.20);
    ctx.save(); ctx.translate(x, y - 15); if (awake && !facingRight) ctx.scale(-1, 1);
    D.rotated(ctx, -36, awake ? -8 : 6, awake ? -40 : 10, () => D.capsule(ctx, 0, 0, 40, 9, SN.rgb(0.90, 0.60, 0.25)));
    D.ellipse(ctx, 0, 0, 66, awake ? 30 : 34, fur);
    const hy = awake ? -14 : -4;
    D.circle(ctx, 28, hy, 30, fur);
    D.tri(ctx, 20, hy - 16, 11, 12, ear); D.tri(ctx, 36, hy - 16, 11, 12, ear);
    if (awake) { D.circle(ctx, 24, -15, 4, '#000'); D.circle(ctx, 34, -15, 4, '#000'); }
    else {
      D.capsule(ctx, 24, -4, 7, 2, 'rgba(0,0,0,.7)'); D.capsule(ctx, 34, -4, 7, 2, 'rgba(0,0,0,.7)');
      D.text(ctx, 'z', 48, -26 - 4 * Math.abs(Math.sin((t || SN.now()) * 1.5)), 16, 'rgba(255,255,255,.8)', 900);
    }
    ctx.restore();
  }

  static sock(ctx, x, y, seed) {
    const D = SN.draw, c = ['#ff3b30', '#007aff', '#34c759', '#af52de', '#ff9500'][Math.abs(seed) % 5];
    D.capsule(ctx, x - 6, y - 26, 14, 26, c); D.capsule(ctx, x + 2, y - 14, 26, 13, c); D.rect(ctx, x - 6, y - 36, 14, 5, '#fff');
  }

  static bag(ctx, x, y) {
    const D = SN.draw;
    D.rrect(ctx, x, y - 31, 60, 62, 22, SN.white(0.16));
    D.tri(ctx, x, y - 69, 30, 22, SN.white(0.16)); D.capsule(ctx, x, y - 69, 26, 5, '#ffcc00');
  }

  static housePlant(ctx, x, y, watered) {
    const D = SN.draw;
    for (let i = 0; i < 5; i++) D.rotated(ctx, x, y - 50, (i - 2) * (watered ? 22 : 34), () => D.ellipse(ctx, 0, -40, 24, 80, watered ? SN.rgb(0.20, 0.62, 0.30) : SN.rgb(0.50, 0.52, 0.25)));
    D.rrect(ctx, x, y - 25, 56, 50, 8, SN.rgb(0.70, 0.42, 0.26));
    if (watered) D.text(ctx, '💧', x, y - 140, 18, '#32ade6');
  }

  static catBowls(ctx, x, y, full) {
    const D = SN.draw;
    [-34, 34].forEach(dx => {
      ctx.beginPath(); ctx.moveTo(x + dx - 27, y - 22); ctx.lineTo(x + dx + 27, y - 22); ctx.lineTo(x + dx + 19, y); ctx.lineTo(x + dx - 19, y); ctx.closePath();
      ctx.fillStyle = SN.rgb(0.85, 0.30, 0.35); ctx.fill();
      if (full) D.ellipse(ctx, x + dx, y - 22, 40, 10, SN.rgb(0.55, 0.35, 0.20));
    });
  }

  static dinnerTable(ctx, x, y, set) {
    const D = SN.draw;
    D.rect(ctx, x - 90, y - 45, 12, 90, SN.rgb(0.42, 0.28, 0.18)); D.rect(ctx, x + 90, y - 45, 12, 90, SN.rgb(0.42, 0.28, 0.18));
    D.rrect(ctx, x, y - 98, 230, 16, 6, SN.rgb(0.55, 0.38, 0.24));
    if (set) for (let i = -1; i <= 1; i++) { D.ellipse(ctx, x + i * 66, y - 111, 40, 10, '#fff'); D.rrect(ctx, x + i * 66 + 24, y - 119, 12, 18, 3, 'rgba(50,173,230,.7)'); }
  }

  static sink(ctx, x, y, clean, t) {
    const D = SN.draw;
    D.rect(ctx, x, y - 52, 220, 104, SN.rgb(0.40, 0.28, 0.20));
    D.rect(ctx, x, y - 111, 236, 14, SN.rgb(0.85, 0.83, 0.78));
    D.rrect(ctx, x, y - 118, 110, 12, 8, SN.white(0.72)); D.capsule(ctx, x, y - 140, 8, 44, SN.white(0.6));
    if (clean) D.text(ctx, '✨', x + 60, y - 150, 30, '#32ade6');
    else for (let i = 0; i < 4; i++) D.ellipse(ctx, x + 62 + (i % 2) * 5, y - 128 - i * 8, 46, 9, SN.white(0.9));
  }
};

SN.Level6.downWidth = 3600;
SN.Level6.upWidth = 2400;
SN.Level6.choreCount = 10;
SN.Level6.backDoor = 3440;
