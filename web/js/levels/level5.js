// Level 5 rules: the first level with a health bar. Strangers on the street hurt you if you
// touch them (jump over them, or hide in a bus stop). Feed all 15 dogs: snacks come from the
// fridge at home, 5 at a time, and Mom is in the kitchen cooking an early breakfast — sneak past
// while her back is turned, or crouch under a table. Rats take a snack and leave an accessory.
// Then get past the hotel guards and the workers in the lobby (the first floor), take the elevator
// and find Uncle's room: a different floor and door every try, and no hints (except from the
// Guide in practice mode). Open his door with the dog's blue key from Level 3, and ask him for a
// ride. (A port of Level5Street.swift.)

SN.Level5 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.chase = new SN.Chase();
    this.run = 0;
    const e = this.engine, c = this.chase;
    e.onInteract = i => this.interact(i);
    e.onHazard = i => this.bumped(i);
    e.onTimeUp = () => this.momAlarm(false);
    e.onTooLoud = () => this.momAlarm(true);
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTaunt = () => c.taunted();
    e.onTick = dt => this.tick(dt);
    e.onKO = () => this.end('Ouch!', 'You ran out of health. The street is tough at night!');
    e.onItemKey = item => this.belt.use(item);
    this.belt.stun = (s, momOnly) => c.stun(s, momOnly);
    c.engine = e;
    c.entrance = () => this.entrance();
    c.setBanner = b => this.banner = b;
    c.award = b => this.award(b);
    c.onCaught = (who, msg) => { this.award('oopsies'); this.end('Caught!', msg); };
    c.onGaveUp = () => this.gaveUp();
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  /// The elevator's buttons: floors 2 to 11 (Hard and above: 2 to 21). Floor 1 is the lobby.
  static get floors() { const top = SN.difficulty.current >= 2 ? 21 : 11; return Array.from({ length: top - 1 }, (_, i) => i + 2); }
  /// Dogs to feed: 8 on Easy, 15 on Mild, 50 on Hard and above.
  static get dogCount() { return SN.difficulty.pick(8, 15, 50); }
  /// With 50 dogs to feed you can carry more at once.
  static get snackLoad() { return SN.difficulty.current >= 2 ? 10 : 5; }

  title() {
    const S = SN.Level5;
    return { street: `Level 5 · The Street  ·  dogs ${this.fed}/${S.dogCount}`, kitchen: "Level 5 · Mom's Kitchen", lobby: 'Level 5 · Hotel Lobby (Floor 1)',
             upstairs: `Level 5 · Hotel · Floor ${this.currentFloor}`, office: `Level 5 · Uncle's Room ${this.uncleRoom}` }[this.area];
  }
  award(b) { if (b === 'oopsies') this.game.noteCaught(); else this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return this.phase === 'over'; }
  /// Uncle's room number, e.g. 703.
  get uncleRoom() { return this.uncleFloor * 100 + this.uncleDoorIndex + 1; }

  get inventory() {
    const items = [];
    if (!this.doorOpen) items.push({ id: 'blueKey', icon: '🔑', color: SN.rgb(0.3, 0.55, 1) });
    for (let n = 0; n < this.snacks; n++) items.push({ id: 'snack' + n, icon: '🦴', color: '#ff9500' });
    return items;
  }

  reset() {
    this.run++;
    const e = this.engine, S = SN.Level5;
    this.saved = { kitchen: S.kitchenThings(), lobby: S.lobbyThings(), office: S.officeThings() };
    this.streetWalkers = S.strangersAndGuards();
    this.lobbyWalkers = S.workers();
    this.walkers = this.streetWalkers;
    this.area = 'street';
    e.load({ width: S.streetWidth, floor: [545, 690], things: S.streetThings(), spawn: { x: 260, y: 620 } });
    e.usesHP = true; e.hp = e.maxHP; e.hurt = false; e._hurtTime = 0;
    e.timeLeft = SN.levelTime(5); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.runHeld = false; e.tauntOnly = false; e.speedBonus = 0;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.chase.reset(); this.belt.reset();
    Object.assign(this, {
      phase: 'sneaking', popup: null, banner: null, bannerTime: 0, hidingIn: null,
      doorOpen: false, elevatorOpen: false, currentFloor: 1,
      // A new hiding place for Uncle every try.
      uncleFloor: SN.pick(S.floors), uncleDoorIndex: SN.randInt(0, S.roomDoors.length),
      snacks: 0, fed: 0, momX: S.stove, cooking: 'atStove', cookTime: 4.5, ratIn: 14, nextID: 100, checkedBy: new Set(),
    });
    e.running = true;
    e.say(`${S.dogCount} hungry dogs out here... the snacks are in our fridge.`, 3.5);
  }

  // ---------- Places ----------
  static streetThings() {
    const W = SN.Level2.onWall, O = SN.Level2.obstacle;
    const things = [
      W('houseDoor', 'houseDoor', 150, 'Sneak back into the kitchen', 90),
      W('stop1', 'busStop', 1150, 'Hide in the bus stop', 90), W('stop2', 'busStop', 2500, 'Hide in the bus stop', 90),
      W('stop3', 'busStop', 3700, 'Hide in the bus stop', 90), W('stop4', 'busStop', 4750, 'Hide in the bus stop', 90),
      O('cans1', 'cans', 900, 672, 60, 24), O('cans2', 'cans', 2140, 566, 60, 24), O('cans3', 'cans', 3300, 668, 60, 24),
      W('hotelDoor', 'hotelDoor', 5290, 'Sneak into the hotel', 90),
    ];
    // The dogs share the same stretch of street, so with 50 they stand close together.
    const count = SN.Level5.dogCount, gap = Math.min(245, 3430 / Math.max(count - 1, 1));
    for (let i = 0; i < count; i++) {
      things.push(SN.thing({ id: 'dog' + (i + 1), kind: 'dog', x: 520 + i * gap, y: [585, 660, 610, 680, 570][i % 5], fw: 70, fh: 22, prompt: 'Feed the dog', reachW: 80, reachH: 60 }));
    }
    return things;
  }

  static walker(o) { return Object.assign({ style: 0, wait: 0, facingRight: true, leaving: false, life: 0 }, o); }

  static strangersAndGuards() {
    const list = [], lanes = [600, 650, 575, 675, 625, 590, 660, 610];
    for (let i = 0; i < 8; i++) {
      const start = 600 + i * 470;
      list.push(SN.Level5.walker({ id: i, kind: 'stranger', x: start + 150, y: lanes[i], range: [start, start + 560], speed: (i % 2 === 0 ? 1 : -1) * (95 + (i % 3) * 25), style: i }));
    }
    // Two guards walk up and down in front of the hotel with flashlights.
    list.push(SN.Level5.walker({ id: 20, kind: 'guardian', x: 4550, y: 610, range: [4400, 4900], speed: 120 }));
    list.push(SN.Level5.walker({ id: 21, kind: 'guardian', x: 5150, y: 650, range: [4850, 5220], speed: -105 }));
    return list;
  }

  static kitchenThings() {
    const W = SN.Level2.onWall, O = SN.Level2.obstacle;
    return [
      W('streetDoor', 'streetDoor', 110, 'Back to the street'), O('table1', 'table', 340, 630, 110, 36), O('table2', 'table', 1190, 630, 110, 36),
      O('chair1', 'chair', 800, 670, 64, 30), W('fridge', 'fridge', 1390, 'Grab snacks from the fridge', 80),
    ];
  }

  static lobbyThings() {
    const W = SN.Level2.onWall, B = SN.Level2.box;
    return [
      W('lobbyDoor', 'lobbyDoor', 110, 'Back to the street'), W('plant1', 'plant', 520, 'Hide behind the plant', 80),
      W('plant2', 'plant', 1500, 'Hide behind the plant', 80), W('plant3', 'plant', 1980, 'Hide behind the plant', 80),
      B('case1', 800, 660), B('case2', 1700, 600), W('elevator', 'elevator', 2250, 'Take the elevator', 100),
    ];
  }

  /// An upstairs corridor: the elevator, four room doors and a plant to hide behind.
  corridorThings(floor) {
    const W = SN.Level2.onWall;
    const things = [W('elevator', 'elevator', 160, 'Take the elevator', 100), W('plant1', 'plant', 1060, 'Hide behind the plant', 80)];
    SN.Level5.roomDoors.forEach((x, i) => {
      const number = floor * 100 + i + 1;
      if (floor === this.uncleFloor && i === this.uncleDoorIndex) things.push(W('uncleDoor', 'uncleDoor', x, this.doorOpen ? `Go into room ${number}` : `Knock on room ${number}`, 90));
      else things.push(W('room' + number, 'roomDoor', x, `Knock on room ${number}`, 90));
    });
    return things;
  }

  /// One worker walks each upstairs corridor, pushing a trolley of towels.
  static corridorWorker(floor) { return [SN.Level5.walker({ id: 40 + floor, kind: 'worker', x: 1400, y: 640, range: [700, 1850], speed: floor % 2 === 0 ? 95 : -95, style: floor })]; }

  static workers() {
    const w = SN.Level5.walker;
    return [
      w({ id: 30, kind: 'worker', x: 700, y: 610, range: [330, 1250], speed: 110, style: 0 }),
      w({ id: 31, kind: 'worker', x: 1500, y: 660, range: [900, 1900], speed: -95, style: 1 }),
      w({ id: 32, kind: 'worker', x: 2000, y: 600, range: [1600, 2180], speed: 100, style: 2 }),
    ];
  }

  static officeThings() {
    const W = SN.Level2.onWall;
    return [W('lobbyBack', 'lobbyBack', 110, 'Back to the corridor'), W('uncle', 'uncle', 720, 'Talk to Uncle', 150)];
  }

  go(area) {
    const e = this.engine, S = SN.Level5;
    SN.sound.play('door', 0.6);
    this.saved[this.area] = e.things;
    if (this.area === 'street') this.streetWalkers = this.walkers.filter(w => w.kind !== 'rat');
    if (this.area === 'lobby') this.lobbyWalkers = this.walkers;
    const from = this.area;
    let width, spawn = { x: 190, y: 610 };
    if (area === 'street') { width = S.streetWidth; spawn = { x: from === 'kitchen' ? 230 : 5200, y: 610 }; this.walkers = this.streetWalkers; }
    else if (area === 'kitchen') { width = S.kitchenWidth; this.walkers = []; }
    else if (area === 'lobby') { width = S.lobbyWidth; if (from === 'upstairs') spawn = { x: 2150, y: 610 }; this.walkers = this.lobbyWalkers; this.currentFloor = 1; }
    else if (area === 'upstairs') {
      width = S.corridorWidth;
      spawn = from === 'office' ? { x: S.roomDoors[this.uncleDoorIndex] + 60, y: 610 } : { x: 260, y: 610 };
      this.walkers = S.corridorWorker(this.currentFloor);
      this.saved.upstairs = this.corridorThings(this.currentFloor);
    } else { width = S.officeWidth; this.walkers = []; }
    e.load({ width, floor: [545, 690], things: this.saved[area] || S.streetThings(), spawn });
    e.facingRight = !(area === 'street' && from !== 'kitchen') && !(area === 'lobby' && from === 'upstairs');
    e.noiseFactor = area === 'kitchen' ? 2 : 1;
    this.hidingIn = null;
    this.area = area;
    this.chase.playerChangedRoom(spawn);
    if (area === 'kitchen') e.say("Mom's cooking! I'll sneak past when her back is turned.", 3.2);
    else if (area === 'lobby' && from === 'street') e.say("The lobby! The workers mustn't see me. There's an elevator at the far end...", 3.2);
    else if (area === 'upstairs' && from !== 'office') e.say(`Floor ${this.currentFloor}. Which room is Uncle's?`, 2.4);
  }

  entrance() {
    const e = this.engine;
    switch (this.area) {
      // Mom comes up the street from the house.
      case 'street': return { x: Math.max(160, e.player.x - 720), y: 600, delay: 3 };
      case 'kitchen': return { x: this.momX, y: 585, delay: 0.6 };
      case 'upstairs': return { x: 160, y: 600, delay: 4 };
      default: return { x: 150, y: 600, delay: 4 };
    }
  }

  show(p) { SN.levelShow(this, p); }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i], S = SN.Level5;
    switch (th.kind) {
      case 'busStop': case 'plant': return this.toggleHiding(th);
      case 'houseDoor': return this.go('kitchen');
      case 'streetDoor': case 'lobbyDoor': return this.go('street');
      case 'lobbyBack': return this.go('upstairs');
      case 'elevator': SN.sound.play('click'); e.running = false; e.walking = false; this.elevatorOpen = true; return;
      case 'roomDoor':
        SN.sound.play('door', 0.4);
        e.addNoise(12);
        return e.say(`"${SN.pick(S.wrongRoom)}" ...Not Uncle's room.`, 2.4);
      case 'fridge': return this.openFridge();
      case 'dog': return this.feed(i);
      case 'box': return e.say("A guest's suitcase. Better leave it.");
      case 'hotelDoor':
        if (this.fed < S.dogCount) { SN.sound.play('buzz'); return e.say(`Not yet! ${S.dogCount - this.fed} dogs are still hungry.`); }
        return this.go('lobby');
      case 'uncleDoor':
        if (!this.doorOpen) {
          this.doorOpen = true;
          SN.sound.play('unlock');
          th.prompt = `Go into room ${this.uncleRoom}`;
          return e.say("Uncle's voice: \"Who's there?\" It's his room! And the dog's blue key fits!", 3);
        }
        return this.go('office');
      case 'uncle': return this.talkToUncle();
    }
  }

  /// A button in the elevator was pressed: 1 is the lobby, 2 and up the floors upstairs.
  ride(floor) {
    this.elevatorOpen = false;
    this.engine.running = this.phase === 'sneaking';
    if (floor === this.currentFloor) return;
    SN.sound.play('powerup', 0.5);
    if (floor === 1) this.go('lobby');
    else { this.currentFloor = floor; this.go('upstairs'); }
  }

  closeElevator() { this.elevatorOpen = false; this.engine.running = this.phase === 'sneaking'; }

  toggleHiding(spot) {
    const e = this.engine;
    SN.sound.play('closet');
    if (e.hidden) { e.hidden = false; this.hidingIn = null; return; }
    e.carrying = null; e.ducking = false;
    e.player = { x: spot.x, y: 553 };
    e.hidden = true; this.hidingIn = spot.id;
  }

  openFridge() {
    const e = this.engine, S = SN.Level5;
    if (this.snacks >= S.snackLoad) { e.say(`My pockets are full. ${S.snackLoad} snacks is all I can carry.`); return; }
    if (this.fed + this.snacks >= S.dogCount) { e.say('I have enough snacks for every dog now.'); return; }
    this.snacks = Math.min(S.snackLoad, S.dogCount - this.fed);
    SN.sound.play('drawer');
    e.say(`${this.snacks} snacks. Back out to the dogs!`);
  }

  feed(i) {
    const e = this.engine, th = e.things[i], S = SN.Level5;
    if (this.snacks <= 0) { e.say("No snacks left! They're in the fridge at home."); return; }
    this.snacks--; this.fed++;
    th.open = true; th.prompt = null;
    SN.sound.play('woof');
    if (this.fed === S.dogCount) {
      SN.sound.play('powerup');
      e.timeLeft += 30;
      this.banner = 'Checkpoint! Every dog is fed. +30 seconds. Now to Uncle\'s hotel!';
      this.bannerTime = 4;
    } else e.say(`Good dog! ${this.fed} of ${S.dogCount} fed.`, 1.6);
  }

  talkToUncle() {
    this.phase = 'over';
    this.engine.timerOn = false;
    this.chase.reset();
    SN.sound.play('magic');
    this.show({ title: 'Uncle', message: '"Well, look who it is! Does your mother know you\'re out? ...No, don\'t tell me."', symbol: '👨', color: '#ff9500',
      button: 'Can I hop in your car to the next city?', action: () => {
        this.game.complete(5);
        SN.sound.play('win');
        this.show({ title: 'Level Complete!', message: 'Uncle: "The next city? At this hour? ...Oh, all right. Hop in, kiddo. Seatbelt on!"', symbol: '🚗', color: SN.colors.gold,
          button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
      } });
  }

  // ---------- Every frame ----------
  tick(dt) {
    this.chase.tick(dt);
    if (this.bannerTime > 0) { this.bannerTime -= dt; if (this.bannerTime <= 0) this.banner = null; }
    if (this.phase !== 'sneaking') return;
    if (this.area === 'street') { this.walk(dt); this.tickRats(dt); }
    else if (this.area === 'lobby' || this.area === 'upstairs') this.walk(dt);
    else if (this.area === 'kitchen') this.tickMom(dt);
  }

  /// Everyone walks their beat; strangers hurt on contact, guards and workers send you back if they see you.
  walk(dt) {
    const e = this.engine, p = e.player, mode = SN.difficulty.current;
    for (const w of this.walkers) {
      if (w.kind === 'rat') continue;
      if (w.wait > 0) w.wait -= dt;
      else {
        w.x += w.speed * dt * SN.difficulty.hazardSpeed;
        // No Mercy: strangers don't just stroll past any more. Close by, they turn and come for you.
        if (mode === 4 && w.kind === 'stranger' && !e.hidden) {
          const toYou = p.x - w.x;
          if (Math.abs(toYou) < 520 && Math.abs(toYou) > 20 && (toYou > 0) !== (w.speed > 0)) w.speed = -w.speed;
          w.y += SN.clamp(p.y - w.y, -60 * dt, 60 * dt);
        }
        if (w.x >= w.range[1] || w.x <= w.range[0]) {
          w.x = SN.clamp(w.x, w.range[0], w.range[1]);
          w.speed = -w.speed;
          w.wait = w.kind === 'stranger' ? SN.rand(0.3, 1.2) : SN.rand(1, 2.2);
        }
        w.facingRight = w.speed > 0;
      }
      const dx = p.x - w.x, dy = p.y - w.y;
      if (w.kind === 'stranger') {
        if (Math.abs(dx) < 42 && Math.abs(dy) < 28 && e.z < 40 && e.damage(20)) {
          p.x = SN.clamp(p.x + (dx >= 0 ? 80 : -80), 40, e.width - 40);
          if (this.phase === 'sneaking') e.say('Ouch! Keep away from the strangers!', 1.8);
        }
        continue;
      }
      // Guards and workers see what's in front of them. Crouching, you can creep up much closer.
      const reach = e.ducking ? 110 : 290, ahead = dx * (w.facingRight ? 1 : -1);
      // Chaos and No Mercy: a worker walking right past your hiding place sometimes looks behind it.
      if (mode >= 3 && w.kind === 'worker' && e.hidden && Math.abs(dx) < 40) {
        if (!this.checkedBy.has(w.id)) {
          this.checkedBy.add(w.id);
          if (SN.randInt(0, 3) === 0) {
            e.hidden = false; this.hidingIn = null;
            const before = this.area;
            this.spotted('worker');
            if (this.area !== before) return;
          }
        }
        continue;
      }
      if (Math.abs(dx) > 120) this.checkedBy.delete(w.id);
      if (!(ahead > 0 && ahead < reach && Math.abs(dy) < 85 && !e.concealed && e.z < 60)) continue;
      // Being spotted can send you to another floor (and swap who's walking about): stop here if it did.
      const before = this.area;
      this.spotted(w.kind);
      if (this.area !== before) return;
    }
  }

  spotted(kind) {
    const e = this.engine;
    if (!e.damage(kind === 'guardian' ? 30 : 15) || this.phase !== 'sneaking') return;
    SN.sound.play('buzz');
    this.banner = kind === 'guardian' ? 'Guard: "Hey! No kids out here at night!"' : 'Worker: "Lost, little one? Out you go!"';
    this.bannerTime = 2.6;
    if (kind === 'guardian') e.player = { x: 4150, y: 620 };
    else if (this.area === 'upstairs') {
      // Upstairs, the worker sends you back down to the lobby.
      this.hidingIn = null; e.hidden = false;
      this.go('lobby');
      e.player = { x: 200, y: 620 };
      return;
    } else e.player = { x: 200, y: 620 };
    e.hidden = false; this.hidingIn = null;
  }

  /// While you carry snacks, a rat shows up now and then. It takes one snack and leaves a present.
  tickRats(dt) {
    const e = this.engine, p = e.player;
    if (this.snacks > 0 && !this.walkers.some(w => w.kind === 'rat')) {
      this.ratIn -= dt;
      if (this.ratIn <= 0) {
        this.ratIn = SN.rand(16, 26);
        const side = Math.random() < 0.5 ? 1 : -1;
        this.walkers.push(SN.Level5.walker({ id: ++this.nextID, kind: 'rat', x: SN.clamp(p.x + side * 560, 60, e.width - 60), y: p.y, range: [0, e.width], speed: 0 }));
        SN.sound.play('squeak', 0.4);
      }
    }
    const i = this.walkers.findIndex(w => w.kind === 'rat');
    if (i < 0) return;
    const rat = this.walkers[i];
    rat.life += dt;
    if (rat.leaving || rat.life > 9 || e.hidden) {
      // Scurry off the screen and vanish.
      rat.leaving = true;
      rat.x += (rat.facingRight ? 1 : -1) * 520 * dt;
      if (Math.abs(rat.x - p.x) > 760) this.walkers.splice(i, 1);
      return;
    }
    const dx = p.x - rat.x, dy = p.y - rat.y, d = Math.max(Math.hypot(dx, dy), 1);
    rat.x += dx / d * 345 * dt; rat.y += dy / d * 240 * dt;
    rat.facingRight = dx > 0;
    if (Math.abs(dx) < 36 && Math.abs(dy) < 24 && e.z < 30 && this.snacks > 0) {
      rat.leaving = true; rat.facingRight = !rat.facingRight;
      this.ratTrade();
    }
  }

  ratTrade() {
    const e = this.engine, g = this.game;
    this.snacks--;
    SN.sound.play('squeak');
    // A rat's present: 1 time in 10 a boost, otherwise an accessory you don't have.
    let gift = null;
    const boost = SN.randInt(0, 10) === 0 ? g.newBoost() : null;
    if (boost) gift = { type: 'boost', boost };
    else { const left = SN.accessories.filter(a => !g.accessories.includes(a.id)); if (left.length) gift = { type: 'accessory', item: SN.pick(left) }; }
    if (!gift) { e.timeLeft += 10; e.say('A rat took a snack! It left a shiny button... +10 seconds.', 2.6); return; }
    const p = SN.lootPopup(gift, () => g.take(gift));
    const name = gift.type === 'boost' ? `a RARE BOOST: ${gift.boost.name}` : `the ${gift.item.name}`;
    this.show(Object.assign(p, { title: 'Rat trade!', message: `A rat ran off with one of your snacks... but it left you ${name}!`, button: 'Fair deal' }));
  }

  /// Mom cooks at the stove, walks to the sink, washes up, and walks back. She only sees
  /// what's in front of her while she walks; cooking, her back is turned.
  tickMom(dt) {
    if (this.chase.active) return;
    const e = this.engine, S = SN.Level5, p = e.player;
    if (this.cooking === 'atStove' || this.cooking === 'atSink') {
      this.cookTime -= dt;
      if (this.cookTime <= 0) this.cooking = this.cooking === 'atStove' ? 'toSink' : 'toStove';
    } else if (this.cooking === 'toSink') {
      this.momX = Math.min(S.sink, this.momX + 150 * dt);
      if (this.momX >= S.sink) { this.cooking = 'atSink'; this.cookTime = 4.5; }
    } else {
      this.momX = Math.max(S.stove, this.momX - 150 * dt);
      if (this.momX <= S.stove) { this.cooking = 'atStove'; this.cookTime = 4.5; }
    }
    if (e.concealed || e.safe) return;
    const dx = p.x - this.momX;
    const looking = this.cooking === 'toSink' ? 1 : this.cooking === 'toStove' ? -1 : 0;
    const seen = looking !== 0 && dx * looking > 0 && dx * looking < 400;
    // Walking right into her counts too.
    if (seen || (Math.abs(dx) < 60 && p.y < 600)) this.chase.alarm('mom', 'Mom turned around and saw you! RUN!', { x: this.momX, y: 585 });
  }

  // ---------- Trouble ----------
  bumped(i) {
    const e = this.engine, hazard = e.things[i].hazard;
    e.ignoreHazards(2.5);
    e.running = true;
    if (this.chase.active) return;
    if (this.area === 'kitchen') this.chase.alarm('mom', `${SN.hazards[hazard][1]} Mom heard it!`, { x: this.momX, y: 585 });
    else this.chase.alarm('mom', `${SN.hazards[hazard][1]} Mom heard that all the way from the kitchen!`);
  }

  momAlarm(tooLoud) {
    if (this.phase !== 'sneaking') return;
    const e = this.engine;
    if (this.chase.active) { e.resetNoise(); return; }
    if (!tooLoud) this.award('amNotPm');
    this.elevatorOpen = false; e.running = true;
    const text = tooLoud ? 'Too loud! Mom is coming to find you!' : "Time's up! Breakfast is ready, and Mom is looking for you!";
    this.chase.alarm('mom', text, this.area === 'kitchen' ? { x: this.momX, y: 585 } : undefined);
  }

  gaveUp() {
    const e = this.engine;
    this.award('shh'); e.resetNoise();
    e.timerOn = true; e.timeLeft = 120;
    this.momX = SN.Level5.stove; this.cooking = 'atStove'; this.cookTime = 4.5;
    e.say('Mom gave up and went back to her cooking. 2 more minutes!', 4);
  }

  end(title, message) {
    this.phase = 'over'; this.banner = null; this.elevatorOpen = false;
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title, message, symbol: '⚠️', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  hint() {
    const e = this.engine, S = SN.Level5, practice = SN.settings.practice;
    switch (this.area) {
      case 'kitchen': return e.say(this.snacks > 0 ? "I've got snacks. Back out the door while Mom's back is turned!"
                                                   : 'The fridge is on the far side. Go when Mom is cooking, and crouch under a table when she walks.');
      case 'lobby': return e.say(practice ? `Take the elevator to floor ${this.uncleFloor}. Uncle is in room ${this.uncleRoom}.`
                                          : 'Hide behind the plants when a worker looks my way. The elevator is at the far end.');
      // No hints about Uncle's room... except from the Guide in practice mode.
      case 'upstairs':
        if (practice) return e.say(this.currentFloor === this.uncleFloor ? `The Guide says: this is the floor! Room ${this.uncleRoom}.` : `The Guide says: wrong floor. Uncle is on floor ${this.uncleFloor}.`);
        return e.say("Uncle's room could be on any floor. I'll have to knock on doors... quietly.");
      case 'office': return e.say('Talk to Uncle!');
    }
    if (this.fed === S.dogCount) e.say('All fed! The hotel is at the far end. Crouch to sneak past the guards, or wait in the bus stop.');
    else if (this.snacks === 0) e.say('I need snacks from the fridge at home (the door at the start of the street).');
    else e.say(`Feed the dogs! ${this.fed} of ${S.dogCount} so far. Jump over strangers and rats.`);
  }

  get shadeAmount() { return this.area === 'street' ? 0.16 : 0.12; }

  // ---------- The elevator's buttons ----------
  overlayKey() { return this.elevatorOpen ? 'elevator' + this.currentFloor : null; }

  overlay() {
    if (!this.elevatorOpen) return null;
    const floors = [1].concat(SN.Level5.floors), many = floors.length > 11;
    const el = SN.el(`<div class="overlay"><div class="popup elevator ${many ? 'many' : ''}">
      <div class="row" style="justify-content:space-between"><b>🛗 Elevator</b><button class="round press" data-x>✕</button></div>
      <p>Which floor? You're on ${this.currentFloor === 1 ? 'the lobby' : 'floor ' + this.currentFloor}.</p>
      <div class="floors">${floors.map(f => `<button class="press ${f === this.currentFloor ? 'here' : ''}" data-f="${f}">${f === 1 ? 'L' : f}</button>`).join('')}</div></div></div>`);
    el.querySelectorAll('[data-f]').forEach(b => b.addEventListener('click', () => { SN.sound.tap(); this.ride(+b.dataset.f); }));
    el.querySelector('[data-x]').addEventListener('click', () => { SN.sound.tap(); this.closeElevator(); });
    el.addEventListener('click', ev => { if (ev.target === el) this.closeElevator(); });
    return el;
  }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, S = SN.Level5, D = SN.draw;
    const w = { street: S.streetWidth, kitchen: S.kitchenWidth, lobby: S.lobbyWidth, upstairs: S.corridorWidth, office: S.officeWidth }[this.area];
    if (this.area === 'street') P.streetScene(ctx, w);
    else if (this.area === 'kitchen') P.kitchenWall(ctx, w);
    else if (this.area === 'lobby') P.lobbyWall(ctx, w);
    else if (this.area === 'upstairs') P.corridorWall(ctx, w, this.currentFloor);
    else P.officeWall(ctx, w);
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'houseDoor': P.door(ctx, x, y, SN.rgb(0.45, 0.32, 0.55), this.chase.momOut && this.area === 'street', 'HOME'); break;
        case 'streetDoor': case 'lobbyDoor': case 'lobbyBack': P.door(ctx, x, y, SN.rgb(0.35, 0.30, 0.25), false); break;
        case 'hotelDoor': P.door(ctx, x, y, SN.rgb(0.65, 0.50, 0.20), false, 'HOTEL'); break;
        case 'uncleDoor': P.door(ctx, x, y, SN.rgb(0.45, 0.22, 0.20), this.doorOpen, String(this.uncleRoom), SN.colors.gold); break;
        case 'roomDoor': P.door(ctx, x, y, SN.rgb(0.45, 0.22, 0.20), false, th.id.slice(4), SN.colors.gold); break;
        case 'elevator': P.elevatorDoor(ctx, x, y, this.currentFloor); break;
        case 'busStop': P.busStop(ctx, x, y, this.hidingIn === th.id); break;
        case 'plant': P.lobbyPlant(ctx, x, y, this.hidingIn === th.id); break;
        case 'fridge': P.fridge(ctx, x, y); break;
        case 'uncle': SN.people.person(ctx, x, y, 'uncle', 0, { facingRight: false, t }); break;
      }
    }
    if (this.area === 'kitchen' && !this.chase.active) {
      const back = this.cooking === 'atStove' || this.cooking === 'atSink', walking = !back;
      ctx.save(); if (back) ctx.filter = 'brightness(.85)';
      SN.people.mom(ctx, this.momX, 585, { walking, facingRight: this.cooking === 'toSink', calm: true, t });
      ctx.restore();
      if (back) { D.text(ctx, '♪', this.momX + 44, 585 - 270, 26, 'rgba(255,255,255,.8)'); D.text(ctx, '🔥', this.momX - 36, 585 - 120, 18, '#ff9500'); }
      else D.text(ctx, '👁', this.momX + (this.cooking === 'toSink' ? 40 : -40), 585 - 270, 22, '#ffcc00');
    }
    const view = runner.viewWidth || 1200;
    const extra = this.walkers.filter(wk => Math.abs(wk.x - e.player.x) < view).map(wk => ({ y: wk.y, draw: () => {
      if (wk.kind === 'rat') SN.people.rat(ctx, wk.x, wk.y, wk.facingRight);
      else SN.people.person(ctx, wk.x, wk.y, wk.kind, wk.style, { walking: wk.wait <= 0, facingRight: wk.facingRight, t });
    } }));
    if (this.chase.active && this.chase.visible) extra.push({ y: this.chase.y, draw: () => this.chase.draw(ctx) });
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'dog':
          P.dog(ctx, x, y, th.open, t);
          if (th.open) D.heart(ctx, x, y - 148, 24, '#ff2d55'); else D.text(ctx, '🍴', x, y - 148, 18, '#fff');
          break;
        case 'cans': P.paintCans(ctx, x, y + 10); break;
        case 'table': P.sideTable(ctx, x, y + 14); break;
        case 'chair': P.chair(ctx, x, y + 8); break;
        case 'box': P.box(ctx, x, y + th.fh / 2, false); break;
      }
    }, extra);
  }
};

SN.Level5.streetWidth = 5600;
SN.Level5.kitchenWidth = 1500;
SN.Level5.lobbyWidth = 2400;
SN.Level5.corridorWidth = 2000;
SN.Level5.officeWidth = 1000;
SN.Level5.roomDoors = [520, 880, 1240, 1600];
SN.Level5.stove = 620;
SN.Level5.sink = 980;
/// Answers through the doors of the rooms that aren't Uncle's.
SN.Level5.wrongRoom = [
  'Zzz... go away...', "Room service? We didn't order anything!", "Shh! The baby's asleep!",
  "Who's there? ...Nobody? Okay.", 'Not tonight, thank you!', '*loud snoring*',
];
