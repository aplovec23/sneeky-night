// Level 8 rules, "Somewhere":
// 1. Uncle drives you on: 50 seconds in his car before the level itself starts.
// 2. Grandma's garden: tidy it (sweep the leaf piles by walking over them, pull the weeds) and
//    find all 20 lanterns, some lying about and some hidden in pots, sheds and bushes. A blue key
//    is hidden somewhere too: it opens the gate to Grandma's porch. Rakes on the lawn cost time.
// 3. Knock, and it takes Grandma 5 seconds to find her slippers. She asks a few questions, then
//    wants her chores done before she'll tell you where Grandpa lives (like Auntie in Level 6).
// 4. You step outside... and Uncle, who doesn't know you're still out here, drives off. Chase the
//    car down the road, past cones, puddles and strangers, until Uncle checks his mirror and sees
//    you. Fall too far behind and he's gone. (A snack dog lies on the way: too full for snacks.)
// (A port of Level8Grandma.swift.)

SN.Level8 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.run = 0;
    const e = this.engine;
    e.onInteract = i => this.interact(i);
    e.onTimeUp = () => this.tooSlow();
    e.onTooLoud = () => e.resetNoise();
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTick = dt => this.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    e.onKO = () => this.end('Ouch!', 'You ran out of health chasing the car.');
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  title() {
    return { ride: 'Level 8 · Somewhere', garden: "Level 8 · Grandma's Garden", house: "Level 8 · Grandma's House", road: 'Level 8 · The Road' }[this.area];
  }
  award(b) { this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return !['garden', 'chores', 'road', 'ride'].includes(this.phase); }
  get gardenClean() { return this.leavesSwept >= this.leafCount && this.weedsPulled >= this.weedCount; }
  get choresDone() { return this.chores.filter(c => c.done >= c.needed).length; }
  label(c) { return c.needed > 1 ? `${c.title} (${c.done}/${c.needed})` : c.title; }

  get inventory() {
    const items = [];
    if (this.lanterns > 0) items.push({ id: 'lanterns', icon: '🏮', color: '#ff9500' });
    if (this.hasBlueKey && !this.gateOpen) items.push({ id: 'blueKey', icon: '🔑', color: '#4d8cff' });
    return items;
  }

  cornerHint() {
    const L = SN.Level8;
    switch (this.phase) {
      case 'ride': return `🚗 Grandma's house in ${Math.ceil(this.rideLeft)} s`;
      case 'garden': case 'knocking':
        return `🏮 ${this.lanterns}/${L.lanternCount}  ·  🍂 ${this.leavesSwept}/${this.leafCount}  ·  🌿 ${this.weedsPulled}/${this.weedCount}${this.hasBlueKey ? '  ·  🔑 ✓' : ''}`;
      case 'questions': return 'Grandma has a few questions...';
      case 'chores': { const next = this.chores.find(c => c.done < c.needed); return `Grandma's chores ${this.choresDone}/${this.chores.length}${next ? '  ·  next: ' + this.label(next) : ''}`; }
      case 'road': return "Catch up with Uncle's car! Stay close until he checks his mirror.";
    }
    return null;
  }

  reset() {
    this.run++;
    const e = this.engine, L = SN.Level8, d = SN.difficulty;
    this.leafCount = d.pick(6, 10, 16);
    this.weedCount = d.pick(4, 6, 9);
    const c = (id, title, needed) => ({ id, title, needed, done: 0 });
    this.chores = [c('teacups', 'Wash the teacups', 3), c('clock', 'Wind the old clock', 2), c('fish', 'Feed the goldfish', 1),
                   c('frames', 'Dust the photos', 3), c('crumbs', 'Sweep up the crumbs', d.pick(3, 4, 6)), c('needles', 'Find the knitting needles', 1)];
    const ids = SN.shuffle(L.spots.map(s => s[0]));
    this.keySpot = ids[0];
    this.lanternSpots = new Set(ids.slice(1));
    this.needlesIn = SN.pick(['drawer1', 'drawer2', 'box1']);
    this.savedHouse = L.houseThings(this.chores[4].needed);
    e.usesHP = false; e.hp = e.maxHP;
    e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.runHeld = false; e.speedBonus = 0;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.belt.reset();
    Object.assign(this, {
      popup: null, banner: null, bannerTime: 0, lanterns: 0, leavesSwept: 0, weedsPulled: 0, hasBlueKey: false, gateOpen: false,
      doorOpen: false, grandma: { x: L.doorX, y: 590 }, grandmaHere: false, grandmaSays: null, sayTime: 0, question: 0,
      knockTime: 0, rakeCooldown: 0, bumpCooldown: 0, carX: 1000, carMoving: false, carDelay: 0, mirrorTime: 14, walkers: [],
      playerOpacity: 1,
    });
    this.startRide();
  }

  show(p) {
    this.engine.running = false;
    const close = () => { this.popup = null; this.engine.running = ['garden', 'chores', 'road'].includes(this.phase); };
    this.popup = Object.assign({}, p, {
      action: () => { close(); p.action && p.action(); },
      secondAction: () => { close(); p.secondAction && p.secondAction(); },
    });
  }
  note(text, seconds = 2.6) { this.banner = text; this.bannerTime = seconds; }
  speak(text, seconds) { this.grandmaSays = text; this.sayTime = seconds; }

  // ---------- The ride ----------
  /// 50 seconds in Uncle's car, watching the road go by, before Grandma's garden.
  startRide() {
    const e = this.engine, L = SN.Level8;
    this.phase = 'ride'; this.area = 'ride';
    e.load({ width: L.roadWidth, floor: [545, 690], things: [], spawn: { x: 600, y: 620 } });
    e.hidden = true; e.timerOn = false; e.showsClock = false;
    this.rideLeft = 50; this.carX = 600; this.rideLine = -1;
    e.running = true;
  }

  tickRide(dt) {
    const e = this.engine, L = SN.Level8;
    this.rideLeft = Math.max(0, this.rideLeft - dt);
    this.carX = SN.lerp(600, L.roadWidth - 700, 1 - this.rideLeft / 50);
    e.player.x = this.carX;
    const line = Math.min(L.rideLines.length - 1, Math.floor((50 - this.rideLeft) / 10));
    if (line !== this.rideLine) { this.rideLine = line; this.note(`Uncle: "${L.rideLines[line]}"`, 6); }
    if (this.rideLeft <= 0) this.arrive();
  }

  arrive() {
    const e = this.engine, L = SN.Level8;
    SN.sound.play('door');
    this.phase = 'garden'; this.area = 'garden';
    e.load({ width: L.gardenWidth, floor: [545, 690], things: L.gardenThings(this.leafCount, this.weedCount, this.lanternSpots.size), spawn: { x: 200, y: 620 } });
    e.hidden = false; e.showsClock = true;
    e.timeLeft = SN.levelTime(8); e.timerOn = true;
    this.banner = null;
    e.running = true;
    e.say("Grandma's garden! It's a mess... and there are lanterns everywhere. 20 of them!", 4);
  }

  // ---------- The garden ----------
  static gardenThings(leaves, weeds, hidden) {
    const W = SN.Level2.onWall, L = SN.Level8, [lo, hi] = [545, 690];
    const things = L.spots.map(([id, kind, x, name]) => W(id, kind, x, `Look in ${name}`, 80));
    things.push(W('gate', 'gate', L.gateX, 'Open the gate', 100));
    // Until the gate is open, a fence closes off the porch.
    things.push(SN.thing({ id: 'fence', kind: 'fence', x: L.gateX + 40, y: 617, fw: 24, fh: 160, solid: true }));
    things.push(W('door', 'grandmaDoor', L.doorX, 'Knock on the door', 100));
    const rng = SN.Level4.seededRandom(88);
    // The lanterns lying about (the rest are hidden).
    const loose = L.lanternCount - hidden;
    for (let i = 0; i < loose; i++) {
      const x = 380 + (i + rng() * 0.7) * (L.gateX - 520) / Math.max(loose, 1);
      things.push(SN.thing({ id: 'lantern' + i, kind: 'lantern', x, y: lo + 22 + rng() * (hi - lo - 34), fw: 30, fh: 18 }));
    }
    for (let i = 0; i < leaves; i++) {
      const x = 440 + (i + rng() * 0.6) * (L.gateX - 600) / Math.max(leaves, 1);
      things.push(SN.thing({ id: 'leaves' + i, kind: 'leaves', x, y: lo + 18 + rng() * (hi - lo - 30), fw: 60, fh: 22, flat: true }));
    }
    for (let i = 0; i < weeds; i++) {
      const x = 600 + (i + rng() * 0.5) * (L.gateX - 800) / Math.max(weeds, 1);
      things.push(SN.thing({ id: 'weed' + i, kind: 'weed', x, y: lo + 30 + rng() * (hi - lo - 50), fw: 34, fh: 16, prompt: 'Pull the weed', reachW: 70, reachH: 50 }));
    }
    // Rakes left lying on the lawn: step on one and BONK. Jump over them.
    [1150, 2050, 2900].forEach((x, n) => things.push(SN.thing({ id: 'rake' + n, kind: 'rake', x, y: [600, 660, 630][n], fw: 90, fh: 18, flat: true })));
    return things;
  }

  static houseThings(crumbs) {
    const W = SN.Level2.onWall, L = SN.Level8;
    const things = [
      W('frontDoor', 'houseDoor', 120, null, 80), W('sink', 'sink', 560, 'Wash the teacups', 90),
      W('clock', 'grandfatherClock', 900, 'Wind the old clock', 70), W('drawer1', 'drawer', 1180, 'Look in the drawer'),
      W('fish', 'fishbowl', 1440, 'Feed the goldfish', 70), W('frames', 'photoShelf', 1760, 'Dust the photos', 90),
      W('drawer2', 'drawer', 2060, 'Look in the drawer'), SN.Level2.box('box1', 1600, 650),
    ];
    for (let i = 0; i < crumbs; i++) {
      things.push(SN.thing({ id: 'crumbs' + i, kind: 'dust', x: 420 + i * (L.houseWidth - 700) / Math.max(crumbs, 1), y: [600, 670, 630][i % 3], fw: 50, fh: 20, flat: true }));
    }
    return things;
  }

  static roadThings() {
    const L = SN.Level8, rng = SN.Level4.seededRandom(808), things = [];
    // Cones to dodge, puddles to wade through, and a very full snack dog.
    for (let x = 1200, n = 0; x < L.roadWidth - 900; n++) {
      const y = 545 + 20 + rng() * (690 - 545 - 30);
      if (n % 3 === 2) things.push(SN.thing({ id: 'puddle' + n, kind: 'puddle', x, y, fw: 110, fh: 34, flat: true }));
      else things.push(SN.thing({ id: 'cone' + n, kind: 'cone', x, y, fw: 40, fh: 20 }));
      x += 330 + rng() * 260;
    }
    things.push(SN.thing({ id: 'fullDog', kind: 'fullDog', x: 4300, y: 590, fw: 70, fh: 22, prompt: 'Give the dog a snack', reachW: 90, reachH: 60 }));
    return things;
  }

  static strangers() {
    const lanes = [600, 655, 580, 670, 620, 595];
    return lanes.map((y, i) => {
      const start = 2000 + i * 1100;
      return { x: start + 200, y, range: [start, start + 600], speed: (i % 2 === 0 ? 1 : -1) * (90 + (i % 3) * 25), style: i, facingRight: i % 2 === 0 };
    });
  }

  // ---------- Every frame ----------
  tick(dt) {
    if (this.bannerTime > 0) { this.bannerTime -= dt; if (this.bannerTime <= 0) this.banner = null; }
    if (this.sayTime > 0) { this.sayTime -= dt; if (this.sayTime <= 0) this.grandmaSays = null; }
    this.rakeCooldown = Math.max(0, this.rakeCooldown - dt);
    this.bumpCooldown = Math.max(0, this.bumpCooldown - dt);
    const e = this.engine, p = e.player, L = SN.Level8;
    switch (this.phase) {
      case 'ride': return this.tickRide(dt);
      case 'garden': {
        // Walking over leaves sweeps them; walking past a loose lantern picks it up.
        const leaf = e.z < 20 && e.things.find(t => t.kind === 'leaves' && !t.hidden && Math.abs(t.x - p.x) < 44 && Math.abs(t.y - p.y) < 30);
        if (leaf) {
          leaf.hidden = true; this.leavesSwept++;
          SN.sound.play('rustle', 0.5);
          if (this.leavesSwept === this.leafCount) { SN.sound.play('star'); this.note('Checkpoint! Every leaf pile is swept.'); }
          this.checkGarden();
        }
        const lantern = e.things.find(t => t.kind === 'lantern' && !t.hidden && Math.abs(t.x - p.x) < 50 && Math.abs(t.y - p.y) < 40);
        if (lantern) { lantern.hidden = true; this.gotLantern(); }
        if (e.z < 12 && this.rakeCooldown <= 0 && !e.safe && e.things.some(t => t.kind === 'rake' && !t.hidden && SN.covers(t, p.x, p.y))) {
          this.rakeCooldown = 2.5;
          const lost = Math.round(10 * SN.difficulty.damageScale);
          e.timeLeft = Math.max(1, e.timeLeft - lost);
          SN.sound.play('bonk');
          this.note(`BONK! You stepped on a rake.  −${lost} seconds`, 2.4);
        }
        return;
      }
      case 'knocking':
        this.knockTime -= dt;
        if (this.knockTime <= 0) this.grandmaOpens();
        return;
      case 'chores': {
        const crumbs = e.z < 20 && e.things.find(t => t.kind === 'dust' && !t.hidden && Math.abs(t.x - p.x) < 40 && Math.abs(t.y - p.y) < 30);
        if (crumbs) { crumbs.hidden = true; SN.sound.play('rustle', 0.5); this.progress('crumbs'); }
        return;
      }
      case 'road': return this.tickRoad(dt);
    }
  }

  gotLantern() {
    const L = SN.Level8;
    this.lanterns++;
    SN.sound.play('chime', 0.6);
    this.engine.say(this.lanterns === L.lanternCount ? "That's all 20 lanterns!" : `A lantern! ${this.lanterns} of ${L.lanternCount}.`, 1.4);
    if (this.lanterns % 5 === 0 && this.lanterns < L.lanternCount) this.engine.timeLeft += 15;
    this.checkGarden();
  }

  checkGarden() {
    if (this.gardenClean && this.lanterns >= SN.Level8.lanternCount) {
      this.note(`Checkpoint! The garden is tidy and you have every lantern.${this.gateOpen ? " Knock on Grandma's door!" : ' Now the gate: it needs a blue key.'}`, 3.5);
      SN.sound.play('powerup');
    }
  }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i];
    switch (th.kind) {
      case 'pots': case 'barrow': case 'birdhouse': case 'shed': case 'bush': case 'compost': return this.search(th);
      case 'weed':
        th.hidden = true; this.weedsPulled++;
        SN.sound.play('rustle');
        e.say(this.weedsPulled === this.weedCount ? 'Every weed is pulled!' : `Pulled! ${this.weedsPulled} of ${this.weedCount}.`, 1.3);
        return this.checkGarden();
      case 'gate': return this.useGate(th);
      case 'grandmaDoor': return this.knock();
      case 'houseDoor': return e.say('Grandma: "Chores first, dear!"');
      case 'sink': return this.work(th, 'teacups', 'water');
      case 'grandfatherClock': return this.work(th, 'clock', 'tick');
      case 'fishbowl': return this.work(th, 'fish', 'drawer');
      case 'photoShelf': return this.work(th, 'frames', 'rustle');
      case 'drawer': case 'box': return this.searchHouse(th);
      case 'fullDog':
        SN.sound.play('woof', 0.4);
        return e.say("He just yawns. He's too full for snacks. He only wants a nap.", 2.4);
    }
  }

  search(th) {
    const e = this.engine;
    th.open = true; th.prompt = null;
    SN.sound.play('rustle');
    if (th.id === this.keySpot) {
      SN.sound.play('key');
      this.show({ title: 'A blue key!', message: 'It has a little tag: "GATE". It must open the gate to Grandma\'s porch.', symbol: '🔑', color: '#4d8cff', button: 'Take Key',
        action: () => { this.hasBlueKey = true; this.award('patienceIsKey'); } });
    } else if (this.lanternSpots.delete(th.id)) {
      this.gotLantern();
    } else {
      const loot = this.game.rollLoot();
      if (loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); }
      else e.say(SN.pick(['Just a snail.', 'Garden gloves. No lantern.', 'Leaves and more leaves.']));
    }
  }

  useGate(th) {
    const e = this.engine;
    if (this.gateOpen) return;
    if (!this.hasBlueKey) { SN.sound.play('buzz'); e.say('Locked, with a blue padlock. The key must be somewhere in the garden.'); return; }
    this.gateOpen = true;
    th.prompt = null;
    e.things = e.things.filter(t => t.id !== 'fence');
    SN.sound.play('unlock');
    e.say("The blue key fits! Grandma's porch is through here.", 2.5);
    this.checkGarden();
  }

  knock() {
    const e = this.engine, L = SN.Level8;
    if (this.phase !== 'garden') return;
    if (!this.gardenClean || this.lanterns < L.lanternCount) {
      const left = [];
      if (this.lanterns < L.lanternCount) left.push(`${L.lanternCount - this.lanterns} lanterns`);
      if (this.leavesSwept < this.leafCount) left.push(`${this.leafCount - this.leavesSwept} leaf piles`);
      if (this.weedsPulled < this.weedCount) left.push(`${this.weedCount - this.weedsPulled} weeds`);
      e.say(`Grandma would hate to see her garden like this. Still to do: ${left.join(', ')}.`, 3.5);
      return;
    }
    // It takes her a moment to find her slippers.
    this.phase = 'knocking';
    this.knockTime = 5;
    e.timerOn = false;
    SN.sound.play('door', 0.5);
    this.note('Knock knock... "Coming, coming! Where are my slippers?"', 5);
  }

  grandmaOpens() {
    this.phase = 'questions';
    this.doorOpen = true; this.grandmaHere = true;
    SN.sound.play('door');
    this.engine.running = false;
    this.question = 0;
  }

  /// An answer was picked. After the last question, inside for chores.
  answer(n) {
    const L = SN.Level8, q = L.questions[this.question];
    this.speak(q[1][n][1], 3.2);
    SN.sound.play('click');
    if (this.question + 1 < L.questions.length) this.question++;
    else this.goInside();
  }

  goInside() {
    const e = this.engine, L = SN.Level8;
    this.phase = 'chores'; this.area = 'house';
    SN.sound.play('door', 0.6);
    e.load({ width: L.houseWidth, floor: [545, 690], things: this.savedHouse, spawn: { x: 260, y: 610 } });
    e.timerOn = true;
    e.timeLeft += 60;
    this.grandma = { x: 360, y: 590 };
    e.running = true;
    this.note('Checkpoint! Grandma\'s chores. +60 seconds', 3);
  }

  chore(id) { return this.chores.find(c => c.id === id); }

  work(th, id, sound) {
    const c = this.chore(id);
    if (!c || c.done >= c.needed) { this.engine.say("That's done already."); return; }
    SN.sound.play(sound, 0.7);
    this.progress(id);
    if (c.done >= c.needed) { th.open = true; th.prompt = null; }
  }

  searchHouse(th) {
    const e = this.engine, c = this.chore('needles');
    th.open = true;
    SN.sound.play('drawer');
    if (th.id === this.needlesIn && c.done < c.needed) {
      this.progress('needles');
      e.say("Grandma's knitting needles! And half a scarf.", 2);
    } else e.say(SN.pick(['Buttons and string.', 'Old photos of Grandpa!', 'A tin of toffees. Better not.']));
  }

  progress(id) {
    const c = this.chore(id);
    if (!c || c.done >= c.needed) return;
    c.done++;
    if (c.done < c.needed) return;
    SN.sound.play('powerup');
    this.note(`Checkpoint! ${c.title}: done. ${this.choresDone}/${this.chores.length}`, 2.2);
    this.speak(SN.pick(['Lovely.', 'Just like your Grandpa.', 'Oh, you ARE helpful.', "That's the way, dear."]), 2.4);
    if (this.choresDone === this.chores.length) this.allChoresDone();
  }

  allChoresDone() {
    this.engine.timerOn = false;
    this.show({ title: 'Where Grandpa is',
      message: 'Grandma: "He lives in the little blue house by the river, right where the lanterns float. He\'s been waiting all year for someone to come."',
      symbol: '🏡', color: '#32ade6', button: 'Thank you, Grandma!', action: () => this.startRoad() });
  }

  // ---------- The road ----------
  startRoad() {
    const e = this.engine, L = SN.Level8;
    this.phase = 'road'; this.area = 'road';
    this.grandmaHere = false;
    e.load({ width: L.roadWidth, floor: [545, 690], things: L.roadThings(), spawn: { x: 260, y: 620 } });
    e.usesHP = true; e.hp = e.maxHP;
    e.timerOn = false; e.showsClock = false;
    this.walkers = L.strangers();
    this.carX = 760; this.carMoving = true; this.carDelay = 2; this.mirrorTime = 14;
    SN.sound.play('door');
    this.note("Uncle didn't see you come out... he's driving away! RUN!", 4);
    e.running = true;
  }

  tickRoad(dt) {
    const e = this.engine, p = e.player, L = SN.Level8, d = SN.difficulty;
    // Uncle drives a little slower than you walk (after his engine splutters into life).
    this.carDelay = Math.max(0, this.carDelay - dt);
    if (this.carMoving && this.carDelay <= 0) this.carX += 205 * Math.sqrt(d.hazardSpeed) * dt;
    // Cones: bump one and stumble (and it hurts a bit).
    if (e.z < 14 && this.bumpCooldown <= 0) {
      const cone = e.things.find(t => t.kind === 'cone' && !t.hidden && SN.covers(t, p.x, p.y, -4, -4));
      if (cone) {
        this.bumpCooldown = 1.2;
        if (e.damage(10)) { p.x = Math.max(40, p.x - (p.x >= cone.x ? -40 : 40)); e.say('Oof! A cone!', 1.2); SN.sound.play('chair'); }
      }
    }
    // The strangers from Level 5 are back.
    for (const w of this.walkers) {
      w.x += w.speed * dt * d.hazardSpeed;
      if (w.x >= w.range[1] || w.x <= w.range[0]) { w.x = SN.clamp(w.x, w.range[0], w.range[1]); w.speed = -w.speed; }
      w.facingRight = w.speed > 0;
      const dx = p.x - w.x, dy = p.y - w.y;
      if (Math.abs(dx) < 42 && Math.abs(dy) < 28 && e.z < 40 && e.damage(20)) {
        p.x = SN.clamp(p.x + (dx >= 0 ? 80 : -80), 40, e.width - 40);
        e.say('Ouch! Keep away from the strangers!', 1.6);
      }
    }
    if (!this.carMoving || !e.running) return;
    const gap = this.carX - p.x;
    if (gap > 2200 || this.carX > L.roadWidth - 200) { this.carMoving = false; this.end("He's gone!", "Uncle's car disappeared round the corner. He never even looked back!"); return; }
    // Every 14 seconds Uncle glances in his mirror. Close enough and he sees you.
    this.mirrorTime -= dt;
    if (this.mirrorTime <= 2.5 && this.mirrorTime + dt > 2.5) this.note('Uncle is about to check his mirror... get close!', 2.5);
    if (this.mirrorTime <= 0) {
      this.mirrorTime = 14;
      if (gap < 650) this.uncleStops();
      else { SN.sound.play('buzz', 0.5); this.note("Uncle checked his mirror... too far back! He didn't see you.", 2.5); }
    }
  }

  uncleStops() {
    this.carMoving = false;
    this.phase = 'over';
    this.engine.running = false;
    this.game.complete(8);
    SN.sound.play('beep'); SN.sound.play('win');
    this.show({ title: 'Level Complete!', message: 'Uncle slams on the brakes. "KIDDO?! I thought you were inside! ...Well, hop in. Let\'s find this blue house by the river."',
      symbol: '🚗', color: SN.colors.gold, button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  tooSlow() {
    if (this.phase !== 'garden' && this.phase !== 'chores') return;
    this.award('amNotPm');
    this.end('Too slow!', this.phase === 'garden' ? "Grandma's lights went out. She's gone to bed!" : 'Grandma: "It\'s far too late, dear. We\'ll finish in the morning."');
  }

  end(title, message) {
    this.phase = 'over';
    this.banner = null;
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title, message, symbol: '⚠️', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  hint() {
    const e = this.engine, L = SN.Level8;
    switch (this.phase) {
      case 'ride': return e.say(`Sit back: ${Math.ceil(this.rideLeft)} seconds to Grandma's house.`, 2.5);
      case 'garden':
        if (!this.hasBlueKey) return e.say('A blue key is hidden somewhere: pots, the shed, the bushes...', 3.5);
        if (this.lanterns < L.lanternCount) return e.say(`${L.lanternCount - this.lanterns} lanterns to go. Some lie on the lawn, others hide in the garden things.`, 4);
        if (!this.gardenClean) return e.say('Sweep the leaf piles (walk over them) and pull the weeds (E).', 3.5);
        return e.say(this.gateOpen ? "Knock on Grandma's door!" : 'Open the gate with the blue key.', 3);
      case 'chores': { const next = this.chores.find(c => c.done < c.needed); if (next) e.say(`Next: ${this.label(next)}. Press E at it (crumbs: walk over them).`, 3.5); return; }
      case 'road': return e.say('Stay close to the car! When Uncle checks his mirror, he has to see you.', 3.5);
    }
  }

  get shadeAmount() { return 0.12; }

  // ---------- Grandma's questions ----------
  overlayKey() { return this.phase === 'questions' ? 'q' + this.question : null; }
  overlay() {
    const L = SN.Level8, q = L.questions[this.question];
    if (!q) return null;
    const el = SN.el(`<div class="overlay"><div class="popup" style="max-width:640px;background:#291f4d;border:3px solid rgba(175,82,222,.7)">
      <h2 style="font-size:24px">👵 ${SN.esc(q[0])}</h2>
      ${q[1].map((a, n) => `<p><button class="big press" style="background:#7359b3;width:100%" data-n="${n}">${SN.esc(a[0])}</button></p>`).join('')}
      <p style="opacity:.6;font-size:15px">Question ${this.question + 1} of ${L.questions.length}</p></div></div>`);
    el.querySelectorAll('[data-n]').forEach(b => b.addEventListener('click', () => { SN.sound.tap(); this.answer(+b.dataset.n); }));
    return el;
  }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, L = SN.Level8, D = SN.draw;
    if (this.area === 'garden') { SN.Level7.scene(ctx, L.gardenWidth); L.houseFront(ctx, L.doorX); }
    else if (this.area === 'house') SN.Level6.wall(ctx, L.houseWidth, true);
    else L.road(ctx, e.width);
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'bush': ctx.save(); if (th.open) ctx.globalAlpha = 0.85; P.bush(ctx, x, y, false, false, 1.5); ctx.restore(); break;
        case 'pots': P.flowerPots(ctx, x, y); break;
        case 'shed': SN.Level7.shed(ctx, x, y, th.open); break;
        case 'barrow': P.wheelbarrow(ctx, x, y); break;
        case 'compost': P.compost(ctx, x, y); break;
        case 'birdhouse': P.birdhouse(ctx, x, y); break;
        case 'gate': P.gardenGate(ctx, x, y); if (!this.gateOpen) D.text(ctx, '🔒', x, y - 90, 30, '#4d8cff'); break;
        case 'grandmaDoor': P.door(ctx, x, y, SN.rgb(0.30, 0.40, 0.70), this.doorOpen, 'GRANDMA', '#fff'); break;
        case 'houseDoor': P.door(ctx, x, y, SN.rgb(0.30, 0.40, 0.70), false); break;
        case 'sink': SN.Level6.sink(ctx, x, y, th.open, t); break;
        case 'drawer': P.dresser(ctx, x, y, th.open); break;
        case 'grandfatherClock': L.clock(ctx, x, y, th.open, t); break;
        case 'fishbowl': L.fishbowl(ctx, x, y, th.open); break;
        case 'photoShelf': L.photoShelf(ctx, x, y, th.open); break;
      }
    }
    if (this.area === 'road') L.car(ctx, this.carX, 690, null, this.carX * 1.4);
    if (this.grandmaHere || this.area === 'house') {
      const g = this.grandma;
      L.grandma(ctx, g.x, g.y, t);
      if (this.grandmaSays) SN.people.speech(ctx, Math.max(g.x, runner.cam.x + 190), g.y - 280, 'Grandma: ' + this.grandmaSays, '#af52de', true);
    }
    const extra = this.walkers.map(w => ({ y: w.y, draw: () => SN.people.person(ctx, w.x, w.y, 'stranger', w.style, { walking: true, facingRight: w.facingRight, t }) }));
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'lantern': L.lantern(ctx, x, y, Math.round(x) + th.id.length, t); break;
        case 'leaves': L.leaves(ctx, x, y, Math.round(x)); break;
        case 'weed': L.weed(ctx, x, y); break;
        case 'rake': L.rake(ctx, x, y + 6); break;
        case 'fence': D.rrect(ctx, x, y - 80, 20, 170, 4, SN.rgb(0.78, 0.72, 0.62)); break;
        case 'dust': D.ellipse(ctx, x, y, 54, 18, 'rgba(191,170,140,.75)'); D.circle(ctx, x - 10, y - 6, 16, 'rgba(204,180,150,.8)'); D.circle(ctx, x + 10, y - 5, 12, 'rgba(190,165,130,.8)'); break;
        case 'box': P.box(ctx, x, y + th.fh / 2, th.open); break;
        case 'cone': L.cone(ctx, x, y + 6); break;
        case 'puddle': P.puddle(ctx, x, y, th.fw, th.fh, t); break;
        case 'fullDog': P.dog(ctx, x, y + 6, true, t); D.text(ctx, 'z z', x + 30, y - 70, 18, 'rgba(255,255,255,.8)'); break;
      }
    }, extra);
    if (this.phase === 'ride') L.car(ctx, this.carX, 690, this.game.look, this.carX * 1.4);
  }

  // ---------- Art ----------
  /// Uncle's car, with Uncle at the wheel (and you in the back during the ride).
  static car(ctx, x, y, kidLook, wheelTurn) { SN.Level7.car(ctx, x, y, kidLook, true, wheelTurn); }

  /// Grandma: Mom's shape in a lavender dressing gown, white hair in a bun, and round glasses.
  static grandma(ctx, x, y, t) {
    SN.people.mom(ctx, x, y, { facingRight: false, robe: SN.rgb(0.62, 0.52, 0.80), hair: SN.white(0.92), noCurlers: true, bun: true, calm: true, glasses: true, t });
  }

  /// The front of Grandma's house at the end of the garden: blue walls, a porch light.
  static houseFront(ctx, doorX) {
    const D = SN.draw;
    D.rect(ctx, doorX, 75 + 235, 760, 470, SN.rgb(0.42, 0.50, 0.72));
    D.tri(ctx, doorX, -40 + 60, 820, 120, SN.rgb(0.32, 0.22, 0.28));
    [-230, 230].forEach(dx => { D.rrect(ctx, doorX + dx, 250, 110, 100, 6, 'rgba(255,214,10,.75)'); D.rect(ctx, doorX + dx, 250, 4, 100, SN.white(0.3)); });
    const g = ctx.createRadialGradient(doorX + 90, 250, 2, doorX + 90, 250, 80);
    g.addColorStop(0, 'rgba(255,214,10,.5)'); g.addColorStop(1, 'rgba(255,214,10,0)');
    ctx.fillStyle = g; ctx.fillRect(doorX + 10, 170, 160, 160);
  }

  /// A night road out in the country: hills, trees, the odd lamp post, and the road itself.
  static road(ctx, width) {
    const D = SN.draw;
    const g = ctx.createLinearGradient(0, 0, 0, 520); g.addColorStop(0, SN.palette.skyTop()); g.addColorStop(1, SN.palette.skyBottom());
    ctx.fillStyle = g; ctx.fillRect(0, 0, width, 520);
    for (let i = 0; i < 40; i++) D.circle(ctx, (i * 233) % width, (i * 61) % 260, 2 + i % 3, `rgba(255,255,255,${0.7 * SN.palette.starlight()})`);
    for (let i = 0; i <= Math.floor(width / 700); i++) D.ellipse(ctx, i * 700 + 200, 470, 900, 300, SN.rgb(0.14, 0.22, 0.24));
    for (let i = 0; i < Math.floor(width / 260); i++) {
      const x = i * 260 + 80;
      if (i % 4 === 0) {
        D.rect(ctx, x, 420, 8, 220, SN.white(0.2));
        ctx.save(); ctx.shadowColor = '#ffd60a'; ctx.shadowBlur = 14; D.circle(ctx, x, 310, 18, '#ffd60a'); ctx.restore();
      } else {
        D.rect(ctx, x, 470, 14, 80, SN.rgb(0.25, 0.16, 0.10));
        D.circle(ctx, x, 410, 110, SN.rgb(0.10, 0.28, 0.18));
      }
    }
    ctx.fillStyle = SN.rgb(0.20, 0.20, 0.25); ctx.fillRect(0, 510, width, 190);
    for (let i = 0; i < Math.floor(width / 240); i++) D.rect(ctx, i * 240 + 45, 621, 90, 6, 'rgba(255,255,255,.5)');
  }

  /// A folded paper lantern, glowing.
  static lantern(ctx, x, y, seed, t) {
    const D = SN.draw, color = ['#ff9500', '#ff3b30', '#ff2d55', '#ffcc00', '#32ade6', '#34c759'][Math.abs(seed) % 6];
    const cy = y - 14 + Math.sin((t || 0) * 2 + seed) * 2;
    const g = ctx.createRadialGradient(x, cy, 2, x, cy, 36); g.addColorStop(0, SN.alpha(color, 0.55)); g.addColorStop(1, SN.alpha(color, 0));
    ctx.fillStyle = g; ctx.fillRect(x - 36, cy - 36, 72, 72);
    D.rrect(ctx, x, cy, 30, 34, 12, color);
    for (let i = -1; i <= 1; i++) D.rect(ctx, x, cy + i * 9, 30, 2, 'rgba(0,0,0,.15)');
    D.capsule(ctx, x, cy - 18, 18, 5, SN.white(0.25)); D.capsule(ctx, x, cy + 18, 18, 5, SN.white(0.25));
  }

  static leaves(ctx, x, y, seed) {
    const colors = ['#ff9500', '#a2845e', '#ff3b30', '#ffcc00'];
    for (let i = 0; i < 6; i++) {
      SN.draw.rotated(ctx, x + (i % 3) * 14 - 14, y + Math.floor(i / 3) * 7 - 4, (i * 47 + seed) % 180, () => SN.draw.ellipse(ctx, 0, 0, 22, 11, SN.alpha(colors[(i + seed) % 4], 0.9)));
    }
  }

  static weed(ctx, x, y) {
    for (let i = 0; i < 5; i++) SN.draw.rotated(ctx, x, y, (i - 2) * 24, () => SN.draw.capsule(ctx, 0, -15, 6, 30, SN.rgb(0.25, 0.55, 0.20)));
    SN.draw.circle(ctx, x + 9, y - 26, 8, '#ffcc00');
  }

  /// A garden rake lying on the lawn, tines up. Step on it and BONK.
  static rake(ctx, x, y) {
    SN.draw.capsule(ctx, x, y, 90, 6, SN.rgb(0.55, 0.38, 0.22));
    for (let i = 0; i < 6; i++) SN.draw.rect(ctx, x + 32 + i * 6 - 15, y - 5, 3, 12, SN.white(0.55));
  }

  static cone(ctx, x, y) {
    const D = SN.draw;
    D.tri(ctx, x, y - 6 - 23, 34, 46, '#ff9500');
    D.rect(ctx, x, y - 25, 20, 6, '#fff');
    D.rrect(ctx, x, y - 4, 44, 8, 3, SN.rgb(0.85, 0.4, 0.1));
  }

  static clock(ctx, x, y, wound, t) {
    const D = SN.draw, top = y - 300;
    D.rrect(ctx, x, top + 145, 90, 290, 10, SN.rgb(0.40, 0.24, 0.14));
    D.circle(ctx, x, top + 46, 64, SN.rgb(1, 0.96, 0.85));
    D.rotated(ctx, x, top + 46, 0, () => D.rect(ctx, 0, -10, 3, 22, '#000'));
    D.rotated(ctx, x, top + 46, wound ? 90 : 40, () => D.rect(ctx, 0, -8, 3, 16, '#000'));
    D.rrect(ctx, x, top + 180, 56, 160, 6, 'rgba(0,0,0,.35)');
    const swing = Math.sin((t || 0) * (wound ? 3 : 0.6)) * 18;
    D.rotated(ctx, x, top + 106, swing, () => { D.capsule(ctx, 0, 55, 4, 110, SN.colors.gold); D.circle(ctx, 0, 108, 18, SN.colors.gold); });
  }

  static fishbowl(ctx, x, y, fed) {
    const D = SN.draw;
    D.rrect(ctx, x, y - 50, 110, 100, 4, SN.rgb(0.45, 0.30, 0.20));
    D.circle(ctx, x, y - 140, 80, 'rgba(50,173,230,.35)', 'rgba(255,255,255,.6)', 3);
    D.text(ctx, '🐟', x + (fed ? 6 : -8), y - 134, 24, '#ff9500');
    if (fed) D.circle(ctx, x - 10, y - 156, 5, SN.rgb(0.6, 0.4, 0.2));
  }

  static photoShelf(ctx, x, y, dusted) {
    const D = SN.draw, shelfY = y - 132;
    for (let i = 0; i < 4; i++) {
      ctx.save(); ctx.translate(x - 96 + i * 64, shelfY - 24); ctx.scale(0.5, 0.5); SN.props.picture(ctx, 0, 0, i + 6); ctx.restore();
    }
    if (!dusted) D.rect(ctx, x, shelfY - 24, 250, 50, 'rgba(178,178,178,.45)');
    D.rect(ctx, x, shelfY + 6, 250, 12, SN.rgb(0.45, 0.30, 0.20));
  }
};

SN.Level8.gardenWidth = 4300;
SN.Level8.houseWidth = 2400;
SN.Level8.roadWidth = 9400;
SN.Level8.lanternCount = 20;
SN.Level8.gateX = 3400;
SN.Level8.doorX = 3960;
/// Hiding places in the garden: id, kind, x, and what to call it.
SN.Level8.spots = [
  ['pots', 'pots', 520, 'the flower pots'], ['barrow', 'barrow', 900, 'the wheelbarrow'], ['birdhouse', 'birdhouse', 1360, 'the birdhouse'],
  ['shed', 'shed', 1800, 'the shed'], ['bush1', 'bush', 2250, 'the rose bush'], ['compost', 'compost', 2700, 'the compost bin'],
  ['bush2', 'bush', 3080, 'the hedge'],
];
SN.Level8.rideLines = [
  "Grandma's house is past the end of my road. Fifty seconds, give or take.",
  "Auntie phoned ahead. Grandma's expecting you... sort of.",
  'Her garden is full of lanterns. Your Grandpa made every one.',
  'Watch out for the rakes. They bite. Ask the postman.',
  'Nearly there. See the lights in the trees?',
];
/// Grandma's questions on the doorstep: [question, [[answer, what she says back], ...]].
SN.Level8.questions = [
  ['Goodness! And who might you be, out here at this hour?', [
    ['Your grandchild!', "So you are! Look how you've grown."],
    ['A very sneaky visitor.', 'Sneaky, hmm? You get that from your Grandpa.']]],
  ['How on earth did you get all the way out here?', [
    ['Uncle drove me.', 'Of course he did. That car is older than I am.'],
    ['I sneaked out of bed!', "Shh! Don't tell me that. I didn't hear it."]]],
  ['Did you tidy my garden? And all my lanterns, are they safe?', [
    ['Every leaf, and all 20 lanterns.', 'Twenty! Grandpa made every single one of those.'],
    ['Mostly. The rakes bit me.', 'Those rakes bite everyone. Even the postman.']]],
  ['And I suppose you want to know where your Grandpa is?', [
    ['Yes please!', 'Then you can help me first. Chores, dear! Come in, come in.'],
    ['I promised to bring him a lantern.', 'What a lovely promise. But chores first, dear. Come in.']]],
];
