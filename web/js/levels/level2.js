// Level 2 rules: sneak down the long hallway without bumping chairs, tables or lamps (crouch to
// touch them safely, or jump over). Drawers hold Zoom Slippers and Spring Socks. The front door
// needs a code (on a paper hidden in a box) and two keys: one on the window ledge, and one from
// your brother's room — or Mom's spare from her jewelry box. Dad checks Mom's room now and then.
// Checking boxes over and over finds skill papers. (A port of Level2Hallway.swift.)

SN.Level2 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.chase = new SN.Chase();
    this.buddy = new SN.Brother();
    this.run = 0;
    const e = this.engine, c = this.chase;
    e.onInteract = i => this.interact(i);
    e.onHazard = i => this.bumped(i);
    e.onTimeUp = () => this.momWakes(false);
    e.onTooLoud = () => this.momWakes(true);
    e.onShieldUsed = () => this.inventory = this.inventory.filter(i => i.id !== 'silentSlippers');
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTaunt = () => this.taunted();
    e.onTick = dt => this.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    e.onDefaultInteract = () => this.talkToBrother();
    this.belt.stun = (s, momOnly) => {
      if (c.stun(s, momOnly)) return true;
      if (!momOnly && this.dad.visible) { this.dad.pause = s; this.dad.stunned = true; return true; }
      return false;
    };
    c.engine = e;
    c.entrance = who => this.entrance(who);
    c.setBanner = b => this.banner = b;
    c.award = b => this.award(b);
    c.brotherFollowing = () => this.buddy.state === 'following';
    c.brotherPos = () => (this.buddy.state === 'following' || (this.buddy.state === 'awake' && this.room === 'sibling')) ? { x: this.buddy.x, y: this.buddy.y } : null;
    c.onCaught = (who, msg) => this.caught(who, msg);
    c.onGaveUp = who => this.gaveUp(who);
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  static get codes() { return SN.difficulty.current === 0 ? ['472', '915', '638'] : ['1DLP', '9PO8', '42FOJ']; }

  title() { return { hallway: 'Level 2 · Hallway', sibling: "Level 2 · Brother's Room", mom: "Level 2 · Mom's Room" }[this.room]; }
  award(b) { if (b === 'oopsies') this.game.noteCaught(); else this.game.award(b); }
  has(id) { return this.inventory.some(i => i.id === id); }
  retry() { this.game.noteRetry(); this.reset(); }

  reset() {
    this.run++;
    this.code = SN.pick(SN.Level2.codes);
    this.paperBox = SN.pick(['box1', 'box2', 'box3', 'box4']);
    this.paperFound = false; this.boxChecks = 0; this.windowViews = 0;
    this.saved = { sibling: SN.Level2.siblingRoom(), mom: SN.Level2.momRoom() };
    this.room = 'hallway';
    const e = this.engine;
    e.load({ width: 3400, floor: [545, 690], things: SN.Level2.hallway(), spawn: { x: 220, y: 610 } });
    e.timeLeft = SN.levelTime(2); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.runHeld = false; e.speedBonus = 0;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.chase.reset(); this.buddy.reset(); this.belt.reset();
    this.toyInHand = false;
    this.dad = { visible: false, stunned: false, pause: 0, laughed: false, phase: 'idle', timer: 0 };
    this.phase = 'sneaking'; this.over = false;
    this.inventory = []; this.popup = null; this.banner = null;
    this.windowOpen = false; this.windowView = null; this.codeAccepted = false; this.doorOpen = false;
    this.showKeypad = false; this.drawing = false; this.hidingIn = null; this.playerOpacity = 1;
    e.running = true;
  }

  // ---------- Rooms ----------
  static onWall(id, kind, x, prompt, reach = 70) { return SN.thing({ id, kind, x, y: 545, prompt, reachW: reach, reachH: 160 }); }
  static box(id, x, y) { return SN.thing({ id, kind: 'box', x, y, fw: 72, fh: 30, solid: true, movable: true, prompt: 'Search the box', reachW: 100, reachH: 60 }); }
  static obstacle(id, hazard, x, y, w, h) { return SN.thing({ id, kind: id.replace(/\d/g, ''), x, y, fw: w, fh: h, hazard }); }

  static hallway() {
    const W = SN.Level2.onWall, B = SN.Level2.box, O = SN.Level2.obstacle;
    return [
      W('bedroomDoor', 'bedroomDoor', 110, 'Go back to bed'), W('closet1', 'closet', 320, 'Hide in the closet'),
      W('dresser1', 'dresser', 540, 'Open the drawer'), O('chair1', 'chair', 700, 640, 64, 30), B('box1', 870, 600),
      W('window', 'window', 1010, 'Open the window'), O('lamp1', 'lamp', 1150, 575, 40, 26), W('dresser2', 'dresser', 1330, 'Open the drawer'),
      B('box2', 1330, 565), W('siblingDoor', 'siblingDoor', 1540, "Sneak into your brother's room"), O('table1', 'table', 1700, 630, 110, 36),
      B('box3', 1870, 665), W('closet2', 'closet', 2010, 'Hide in the closet'), W('momDoor', 'momDoor', 2200, "Sneak into Mom's room"),
      O('chair2', 'chair', 2350, 590, 64, 30), O('lamp2', 'lamp', 2420, 668, 40, 26), W('dresser3', 'dresser', 2580, 'Open the drawer'),
      B('box4', 2740, 600), W('closet3', 'closet', 2900, 'Hide in the closet'), O('table2', 'table', 3040, 640, 110, 36),
      O('chair3', 'chair', 3100, 572, 64, 30), W('exitDoor', 'exitDoor', 3270, 'Unlock the door', 90),
    ];
  }

  static siblingRoom() {
    const W = SN.Level2.onWall, O = SN.Level2.obstacle;
    const car = O('car', 'toy', 700, 640, 60, 26); car.patrol = [420, 1100]; car.speed = 240;
    const ball = O('ball', 'toy', 950, 588, 40, 26); ball.patrol = [450, 1150]; ball.speed = -190;
    const robot = O('robot', 'toy', 600, 676, 44, 24); robot.patrol = [380, 1000]; robot.speed = 150;
    return [
      W('hallDoor', 'hallDoor', 110, 'Back to the hallway'), W('sibCloset', 'closet', 310, 'Hide in the closet'),
      W('toyChest', 'toyChest', 640, 'Grab a toy', 60), W('paper', 'paper', 800, 'Grab paper and draw', 55),
      O('blocks', 'toy', 520, 605, 54, 26), O('duck', 'toy', 780, 682, 40, 20), car, ball, robot,
      SN.thing({ id: 'sibBed', kind: 'sibBed', x: 1180, y: 545, heavy: true, prompt: 'Look at your brother', reachW: 140, reachH: 160 }),
      W('nightstand', 'nightstand', 1390, 'Open the drawer'),
    ];
  }

  static momRoom() {
    const W = SN.Level2.onWall, O = SN.Level2.obstacle;
    return [
      W('hallDoor', 'hallDoor', 110, 'Back to the hallway'), W('wardrobe', 'closet', 320, 'Hide in the wardrobe'),
      W('dadDesk', 'dadDesk', 500, "Look at Dad's desk", 55), O('shoes', 'shoes', 520, 668, 54, 20),
      W('vanity', 'vanity', 690, 'Open the jewelry box'), O('table3', 'table', 880, 625, 110, 36),
      SN.thing({ id: 'momBed', kind: 'momBed', x: 1180, y: 545, heavy: true, prompt: 'Look under the bed', reachW: 150, reachH: 160 }),
      O('basket', 'basket', 1310, 662, 60, 28), W('momNightstand', 'momNightstand', 1450, 'Check the alarm clock'),
    ];
  }

  go(room) {
    SN.sound.play('door', 0.6);
    this.saved[this.room] = this.engine.things;
    const from = this.room;
    const width = room === 'hallway' ? 3400 : room === 'sibling' ? 1500 : 1600;
    const spawn = room === 'hallway' ? { x: from === 'mom' ? 2200 : 1540, y: 580 } : { x: 190, y: 600 };
    const things = room === 'hallway' ? this.saved.hallway : this.saved[room];
    this.engine.load({ width, floor: [545, 690], things, spawn });
    const e = this.engine;
    e.facingRight = room !== 'hallway';
    e.noiseFactor = room === 'mom' ? 2 : 1;
    this.hidingIn = null;
    this.dad.visible = false; this.dad.phase = 'idle';
    if (this.banner && this.banner.includes('Dad')) this.banner = null;
    this.room = room;
    this.chase.playerChangedRoom(spawn);
    if (this.buddy.state === 'following') this.buddy.jumpTo(e.player);
    e.defaultPrompt = this.buddy.state === 'following' ? 'Talk to your brother' : null;
    if (room === 'sibling') e.say("Shhh... don't step on the toys!");
    if (room === 'mom' && !this.chase.active) {
      e.say("Shhh! Mom's asleep. And Dad might come check...");
      this.dad.phase = 'waiting'; this.dad.timer = SN.rand(9, 15);
    }
  }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i];
    switch (th.kind) {
      case 'closet': this.toggleHiding(th); break;
      case 'dresser': case 'nightstand': this.openDrawer(i); break;
      case 'box': this.searchBox(i); break;
      case 'window': this.useWindow(); break;
      case 'siblingDoor': this.go('sibling'); break;
      case 'momDoor': this.go('mom'); break;
      case 'hallDoor': this.go('hallway'); break;
      case 'bedroomDoor': e.say("Back to bed? No way! I'm sneaking out!"); break;
      case 'exitDoor': this.useExitDoor(); break;
      case 'sibBed': this.talkToBrother(); break;
      case 'paper': SN.sound.play('paper'); this.drawing = true; e.paused = true; break;
      case 'toyChest':
        if (this.toyInHand) e.say('One toy at a time.');
        else { this.toyInHand = true; this.inventory.push({ id: 'toy', icon: '🧸', color: '#ff2d55' }); SN.sound.play('squeak', 0.3); e.say('Got a toy. I could give it to someone...'); }
        break;
      case 'dadDesk':
        if (this.toyInHand) { this.useToy(); this.game.give('dad'); e.say("I left the toy on Dad's desk. He'll find it in the morning!"); }
        else e.say("Dad's desk. A cold cup of cocoa and yesterday's newspaper.");
        break;
      case 'vanity': this.openJewelryBox(i); break;
      case 'momBed': this.lookUnderBed(i); break;
      case 'momNightstand': this.useAlarmClock(i); break;
    }
  }

  show(p) { SN.levelShow(this, p); }

  useToy() { this.toyInHand = false; this.inventory = this.inventory.filter(i => i.id !== 'toy'); }

  toggleHiding(closet) {
    const e = this.engine;
    SN.sound.play('closet');
    if (e.hidden) { e.hidden = false; this.hidingIn = null; }
    else { e.carrying = null; e.ducking = false; e.player = { x: closet.x, y: 553 }; e.hidden = true; this.hidingIn = closet.id; }
  }

  openDrawer(i) {
    const e = this.engine, th = e.things[i];
    if (th.open) { e.say('This drawer is empty now.'); return; }
    if (th.id === 'dresser2') {
      const b = e.thing('box2');
      if (b && Math.abs(b.x - th.x) < 70 && b.y < 600) { e.say('A box is in the way! Press R to move it.'); return; }
    }
    th.open = true;
    SN.sound.play('drawer');
    if (th.id === 'dresser2') {
      SN.sound.play('powerup');
      this.show({ title: 'Zoom Slippers!', message: 'Super quiet, super fast. You can run faster now!', symbol: '🥿', color: '#00c7be', button: 'Put On',
        action: () => { this.inventory.push({ id: 'slippers', icon: '🥿', color: '#00c7be' }); e.speedBoost = true; } });
    } else if (th.id === 'dresser3') {
      SN.sound.play('powerup');
      this.show({ title: 'Spring Socks!', message: 'Boing! You can jump higher and farther now!', symbol: '🧦', color: '#ff2d55', button: 'Put On',
        action: () => { this.inventory.push({ id: 'socks', icon: '🧦', color: '#ff2d55' }); e.jumpBoost = true; } });
    } else if (th.id === 'nightstand') {
      SN.sound.play('key');
      this.show({ title: 'You found a key!', message: "It was in the drawer next to your brother's bed.", symbol: '🔑', color: SN.colors.gold, button: 'Take Key',
        action: () => { this.inventory.push({ id: 'siblingKey', icon: '🔑', color: SN.colors.gold }); this.award('patienceIsKey'); } });
    } else e.say('Just socks in here.');
  }

  /// Every box can be checked again and again; every 4th check turns up a skill paper.
  searchBox(i) {
    const e = this.engine, th = e.things[i];
    this.boxChecks++;
    th.open = true;
    SN.sound.play('box');
    if (th.id === this.paperBox && !this.paperFound) {
      this.paperFound = true;
      SN.sound.play('paper');
      this.show({ title: 'You found a paper!', message: `It has a secret code on it:\n${this.code}`, symbol: '📄', color: '#fff', button: 'Take Paper',
        action: () => this.inventory.push({ id: 'paper', icon: '📄', color: '#fff' }) });
      return;
    }
    const nextSkill = ['dash', 'run'].find(s => !this.game.skills.includes(s));
    if (this.boxChecks % 4 === 0 && nextSkill) {
      SN.sound.play('magic');
      const how = nextSkill === 'dash' ? 'Press Q (or the wind button) to zoom forward!' : 'Hold Shift (or turn on the running button) to run fast. Running is noisy, so be careful!';
      this.show({ title: 'Skill paper!', message: `You learned ${nextSkill.toUpperCase()}!\n${how}`, symbol: nextSkill === 'dash' ? '💨' : '🏃', color: '#32ade6', button: 'Cool!',
        action: () => { this.game.learn(nextSkill); if (nextSkill === 'dash') e.canDash = true; else e.canRun = true; } });
      return;
    }
    const loot = this.game.rollLoot();
    if (loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); return; }
    if (this.boxChecks % 4 === 2 && nextSkill) e.say('Hmm... something rustles at the bottom. Keep checking the boxes!');
    else e.say(SN.pick(['Just old clothes.', 'Only some books in here.', 'Lots of tangled wires.', 'A rubber chicken? Weird.']));
  }

  useWindow() {
    const e = this.engine, w = e.thing('window');
    if (!this.windowOpen) { this.windowOpen = true; SN.sound.play('window'); e.say('The window is open! Something shiny is on the ledge...'); }
    else if (!this.has('windowKey')) {
      SN.sound.play('key');
      this.show({ title: 'You found a key!', message: 'It was sitting on the window ledge outside.', symbol: '🔑', color: SN.colors.silver, button: 'Take Key',
        action: () => { this.inventory.push({ id: 'windowKey', icon: '🗝', color: SN.colors.silver }); this.award('patienceIsKey'); if (w) w.prompt = 'Look outside'; } });
    } else {
      // Just for fun: peek outside. Something different every time.
      SN.sound.play('window', 0.5);
      e.running = false;
      this.windowView = this.windowViews % SN.Level2.windowScenes.length;
      this.windowViews++;
      if (this.windowViews >= 3) this.award('curiosity');
    }
    if (w) w.prompt = !this.windowOpen ? 'Open the window' : this.has('windowKey') ? 'Look outside' : 'Grab the shiny thing';
  }

  closeWindowView() {
    this.windowView = null;
    const e = this.engine;
    e.running = this.phase === 'sneaking';
    // 1 time in 10, something lands on the ledge while you're looking.
    if (SN.randInt(0, 10) !== 0) return;
    SN.sound.play('magic');
    const k = SN.randInt(0, 3);
    if (k === 0) this.show({ title: 'A surprise!', message: 'Silent Slippers were sitting on the ledge! One free bump.', symbol: '👣', color: '#af52de', button: 'Take',
      action: () => { this.inventory.push({ id: 'silentSlippers', icon: '👣', color: '#af52de' }); e.shields++; } });
    else if (k === 1) this.show({ title: 'A surprise!', message: 'A lucky clock rolled onto the ledge. +20 seconds!', symbol: '⏰', color: '#ff9500', button: 'Take', action: () => e.timeLeft += 20 });
    else this.show({ title: 'A surprise!', message: 'A glowing star ball! You feel a little faster.', symbol: '🌟', color: '#ffcc00', button: 'Take', action: () => e.speedBonus += 0.1 });
  }

  openJewelryBox(i) {
    const th = this.engine.things[i];
    if (th.open) { this.engine.say("Just Mom's earrings left. Better not touch those."); return; }
    th.open = true;
    SN.sound.play('key');
    this.show({ title: "Mom's spare key!", message: "It opens the front door too. Now you don't need your brother's key!", symbol: '🔑', color: '#ff2d55', button: 'Take Key',
      action: () => { this.inventory.push({ id: 'spareKey', icon: '🔑', color: '#ff2d55' }); this.award('patienceIsKey'); } });
  }

  lookUnderBed(i) {
    const e = this.engine, th = e.things[i];
    if (this.toyInHand) { this.useToy(); this.game.give('mom'); e.say('I tucked the toy in next to Mom. She smiled in her sleep!'); return; }
    if (!e.ducking) { e.say('I have to crouch down to look under the bed. Press C!'); return; }
    if (th.open) { e.say('Just dust bunnies under here now.'); return; }
    th.open = true;
    SN.sound.play('powerup');
    this.show({ title: 'Silent Slippers!', message: 'Fluffy and quiet. You can bump into one thing without making a sound!', symbol: '👣', color: '#af52de', button: 'Put On',
      action: () => { this.inventory.push({ id: 'silentSlippers', icon: '👣', color: '#af52de' }); e.shields++; } });
  }

  useAlarmClock(i) {
    const e = this.engine, th = e.things[i];
    if (th.open) { e.say('I already turned the clock back.'); return; }
    th.open = true;
    SN.sound.play('beep'); SN.sound.play('powerup');
    e.timeLeft += 30;
    this.show({ title: '+30 seconds!', message: "You turned Mom's alarm clock back. More time to sneak!", symbol: '⏰', color: '#ff9500', button: 'Nice!', action: () => {} });
  }

  inventoryTap(id) {
    if (id !== 'paper') return;
    SN.sound.play('paper');
    this.show({ title: this.code, message: 'The code for the front door.', symbol: '📄', color: '#fff', button: 'OK', action: () => {} });
  }

  // ---------- Front door ----------
  useExitDoor() {
    if (this.doorOpen) return;
    if (!this.codeAccepted) { SN.sound.play('beep'); this.engine.running = false; this.showKeypad = true; }
    else this.tryKeys();
  }

  submitCode(entry) {
    const norm = s => s.toUpperCase().replace(/0/g, 'O').replace(/\s/g, '');
    if (norm(entry) !== norm(this.code)) { SN.sound.play('buzz'); return false; }
    SN.sound.play('unlock');
    if (!this.has('paper')) this.award('luckyGuess');
    this.codeAccepted = true; this.showKeypad = false; this.engine.running = true;
    this.tryKeys();
    return true;
  }

  closeKeypad() { this.showKeypad = false; this.engine.running = true; }

  tryKeys() {
    const e = this.engine;
    const keys = (this.has('windowKey') ? 1 : 0) + (this.has('siblingKey') || this.has('spareKey') ? 1 : 0);
    if (keys < 2) { e.say(`The code worked! But there are 2 locks. I have ${keys} of 2 keys.`); return; }
    e.running = false; e.timerOn = false; this.phase = 'over'; this.over = true;
    this.inventory = this.inventory.filter(i => !['windowKey', 'siblingKey', 'spareKey'].includes(i.id));
    this.game.complete(2);
    SN.sound.play('unlock');
    SN.later(this, 0.4, () => SN.sound.play('unlock'));
    SN.later(this, 0.8, () => { this.doorOpen = true; SN.sound.play('door'); });
    SN.later(this, 1.6, () => {
      const start = { x: e.player.x, y: e.player.y }, t0 = SN.now();
      const walk = () => {
        const p = SN.clamp((SN.now() - t0) / 0.7, 0, 1);
        e.walking = p < 1; e.player.x = SN.lerp(start.x, 3270, p); e.player.y = SN.lerp(start.y, 555, p); this.playerOpacity = 1 - p;
        if (p < 1) { requestAnimationFrame(walk); return; }
        SN.sound.play('win');
        const withBrother = this.buddy.state === 'following';
        if (withBrother) { this.game.hasToy = true; this.game.save(); }
        this.show({ title: 'Level Complete!', message: withBrother ? 'You and your brother made it! He gave you his toy: press G to stun Mom with it.' : 'You sneaked all the way down the hallway!',
          symbol: '⭐', color: SN.colors.gold, button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
      };
      requestAnimationFrame(walk);
    });
  }

  // ---------- Every frame: Dad and your brother ----------
  tick(dt) {
    const e = this.engine;
    this.buddy.update(e.player, e.facingRight, dt);
    this.chase.tick(dt);
    const d = this.dad;
    if (d.pause > 0) { d.pause -= dt; if (d.pause <= 0) { d.stunned = false; if (this.banner && this.banner.includes('funny')) this.banner = null; } }
    // While you're in Mom's room, Dad comes to check every 9–15 seconds.
    if (this.room !== 'mom' || this.chase.active || this.phase !== 'sneaking') return;
    d.timer -= dt;
    if (d.phase === 'waiting' && d.timer <= 0) {
      SN.sound.play('dad'); this.banner = 'Footsteps... Dad is coming! Hide!';
      d.phase = 'warning'; d.timer = 3;
    } else if (d.phase === 'warning' && d.timer <= 0) {
      this.banner = null; SN.sound.play('door', 0.5);
      d.visible = true; d.phase = 'looking'; d.timer = 2.6;
    } else if (d.phase === 'looking') {
      if (d.pause > 0) { d.timer += dt; return; }
      if (!e.concealed) {
        // He's seen you! He comes after you from the doorway.
        d.visible = false; d.stunned = false; d.phase = 'idle';
        this.chase.alarm('dad', 'Dad spotted you! RUN!', { x: 150, y: 600 });
      } else if (d.timer <= 0) {
        d.visible = false; d.laughed = false; d.phase = 'waiting'; d.timer = SN.rand(9, 15);
        this.award('shh');
        e.say("Phew... Dad didn't see me.");
      }
    }
  }

  taunted() {
    this.chase.taunted();
    const d = this.dad;
    if (this.room === 'mom' && !d.laughed && (d.visible || (this.banner && this.banner.includes('Dad')))) {
      d.laughed = true; d.pause = SN.difficulty.dadLaugh;
      this.award('funnySon');
      this.banner = `Dad: "Ha! That's funny, son. You've got ${d.pause >= 60 ? 'a whole minute' : '10 seconds'}..."`;
    }
    if ((this.room === 'sibling' || this.buddy.state === 'following') && this.buddy.taunted()) {
      this.award('crashout');
      this.engine.say('Brother: "STOP IT! You\'re SO annoying!!"', 3);
    }
    if (this.room === 'sibling' && this.buddy.state === 'asleep' && this.phase === 'sneaking') {
      this.buddy.wake();
      SN.sound.play('squeak', 0.5);
      this.engine.say('Oops... I woke up my brother!');
      const bed = this.engine.thing('sibBed');
      if (bed) bed.prompt = 'Talk to your brother';
    }
  }

  talkToBrother() {
    const e = this.engine;
    if (this.buddy.state === 'asleep') { e.say("He's fast asleep. Only something really silly would wake him up..."); return; }
    if (this.room !== 'sibling' && this.buddy.state !== 'following') return;
    e.running = false;
    this.buddy.startTalking();
  }

  closeTalk() {
    const e = this.engine;
    this.buddy.talking = false;
    e.running = this.phase === 'sneaking';
    e.defaultPrompt = this.buddy.state === 'following' ? 'Talk to your brother' : null;
    const bed = e.thing('sibBed');
    if (this.buddy.state === 'asleep' && bed) bed.prompt = 'Look at your brother';
  }

  get brotherTip() {
    if (!this.has('windowKey')) return 'I saw something shiny outside the hallway window!';
    if (!this.has('siblingKey') && !this.has('spareKey')) return "There's a key in my drawer. And Mom hides a spare one in her jewelry box.";
    if (!this.has('paper') && !this.codeAccepted) return 'Mom wrote the door code on a paper. I think it fell into one of the boxes.';
    return 'You have everything! Go to the front door at the end of the hallway.';
  }

  // ---------- Getting caught ----------
  /// Bumping something makes a noise, and Mom gets up to see what it was.
  bumped(i) {
    const e = this.engine, hazard = e.things[i].hazard;
    if (hazard === 'toy') this.award('deadlySqueak');
    e.ignoreHazards(2.5);
    e.running = true;
    if (this.chase.active) return;
    this.chase.alarm('mom', `${SN.hazards[hazard][1]} Mom heard it. She's coming!`);
  }

  momWakes(tooLoud) {
    if (this.phase !== 'sneaking') return;
    if (this.chase.active) { this.engine.resetNoise(); return; }
    if (!tooLoud) this.award('amNotPm');
    this.chase.alarm('mom', tooLoud ? "Too loud! Mom woke up. She's coming to find you!" : "Time's up! Mom woke up. She's coming to find you!");
  }

  entrance(who) {
    if (this.room === 'hallway') return { x: 2200, y: 575, delay: 2.5 };
    if (this.room === 'sibling') return { x: 150, y: 600, delay: 5 };
    return who === 'mom' ? { x: 1180, y: 610, delay: 1.5 } : { x: 150, y: 600, delay: 2.5 };
  }

  gaveUp(who) {
    const e = this.engine;
    this.award('shh'); e.resetNoise(); e.timerOn = true;
    if (who === 'mom') { e.timeLeft = 120; e.say('Mom gave up and went back to bed. 2 minutes until she wakes up again!', 4); }
    else { e.say('Dad gave up and went back to his cocoa. Phew!', 3); if (this.room === 'mom') { this.dad.phase = 'waiting'; this.dad.timer = SN.rand(9, 15); } }
  }

  caught(who, message) {
    this.award('oopsies');
    if (who === 'dad') this.award('hiDad');
    this.phase = 'over'; this.over = true; this.banner = null;
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title: 'Caught!', message, symbol: '⚠️', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  hint() {
    const e = this.engine;
    if (!this.has('windowKey')) e.say(this.windowOpen ? 'Grab the shiny thing on the window ledge!' : 'Try opening the window. I saw something shiny!');
    else if (!this.has('siblingKey') && !this.has('spareKey')) e.say("I need one more key. There's one by my brother's bed... or maybe Mom has a spare?");
    else if (!this.has('paper') && !this.codeAccepted) e.say('The door code is on a paper. Search the boxes!');
    else e.say('Go to the front door at the end of the hallway!');
  }

  get shadeAmount() { return this.room === 'mom' ? 0.28 : this.room === 'sibling' ? 0.2 : 0.22; }

  // ---------- Panels over the room ----------
  overlayKey() {
    if (this.showKeypad) return 'keypad';
    if (this.windowView !== null) return 'window' + this.windowView;
    if (this.buddy.talking) return 'talk' + this.buddy.version;
    if (this.drawing) return 'draw';
    return null;
  }

  overlay() {
    if (this.showKeypad) return SN.keypad('Find the paper with the code if you don\'t know it.', s => this.submitCode(s), () => this.closeKeypad());
    if (this.windowView !== null) {
      const [scene, text] = SN.Level2.windowScenes[this.windowView];
      const el = SN.el(`<div class="overlay"><div class="popup"><div class="sym">${scene}</div><h2>${SN.esc(text)}</h2><button class="big press">Close the window</button></div></div>`);
      el.querySelector('button').addEventListener('click', () => { SN.sound.tap(); this.closeWindowView(); });
      return el;
    }
    if (this.buddy.talking) return SN.talkPanel(this.buddy, this.brotherTip, this.toyInHand ? () => { this.useToy(); this.game.give('brother'); } : null, () => this.closeTalk());
    if (this.drawing) return SN.drawingPad(() => { this.drawing = false; this.engine.paused = false; this.engine.say("Not bad! I'll show Grandpa.", 2.2); });
    return null;
  }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine;
    if (this.room === 'hallway') P.hallwayWall(ctx, 3400);
    else if (this.room === 'sibling') P.siblingRoomWall(ctx, 1500);
    else P.momRoomWall(ctx, 1600);
    for (const th of e.things) {
      if (SN.onFloor(th) || th.hidden) continue;
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'closet': P.closet(ctx, x, y, this.hidingIn === th.id); break;
        case 'dresser': P.dresser(ctx, x, y, th.open); break;
        case 'nightstand': P.nightstand(ctx, x, y, th.open); break;
        case 'window': P.window(ctx, x, y, this.windowOpen, this.has('windowKey')); break;
        case 'bedroomDoor': P.door(ctx, x, y, SN.rgb(0.45, 0.32, 0.55), false, 'My Room'); break;
        case 'siblingDoor': P.door(ctx, x, y, SN.rgb(0.35, 0.55, 0.75), false, 'KEEP OUT ★', '#ff9500'); break;
        case 'hallDoor': P.door(ctx, x, y, this.room === 'mom' ? SN.rgb(0.55, 0.3, 0.3) : SN.rgb(0.35, 0.55, 0.75), this.dad.visible); break;
        case 'momDoor': P.door(ctx, x, y, SN.rgb(0.55, 0.3, 0.3), this.chase.momOut && this.room === 'hallway', 'MOM ♥', '#ff2d55'); break;
        case 'exitDoor': P.exitDoor(ctx, x, y, this.doorOpen, this.codeAccepted); break;
        case 'sibBed': P.siblingBed(ctx, x, y, this.buddy.state !== 'asleep'); break;
        case 'vanity': P.vanity(ctx, x, y, th.open); break;
        case 'momBed': P.momBed(ctx, x, y, this.chase.momOut); break;
        case 'momNightstand': P.alarmNightstand(ctx, x, y, th.open); break;
        case 'toyChest': P.toyChest(ctx, x, y); break;
        case 'paper': P.paperStack(ctx, x, y); break;
        case 'dadDesk': P.dadDesk(ctx, x, y); break;
      }
    }
    const extra = this.chase.active && this.chase.visible ? [{ y: this.chase.y, draw: () => this.chase.draw(ctx) }] : [];
    const b = this.buddy;
    if (!e.hidden && (b.state === 'following' || (b.state === 'awake' && this.room === 'sibling'))) {
      extra.push({ y: b.y, draw: () => {
        SN.people.character(ctx, b.x, b.y, SN.people.brotherLook, { facingRight: b.facingRight, walking: b.walking, scale: 0.78, t });
        SN.draw.rrect(ctx, b.x, b.y - 145, 70, 20, 10, 'rgba(0,0,0,.4)'); SN.draw.text(ctx, 'Brother', b.x, b.y - 144, 14, '#fff');
      } });
    }
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'box': P.box(ctx, x, y + th.fh / 2, th.open); break;
        case 'chair': P.chair(ctx, x, y + 8); break;
        case 'lamp': P.floorLamp(ctx, x, y + 6); break;
        case 'table': P.sideTable(ctx, x, y + 14); break;
        case 'blocks': P.blocks(ctx, x, y + 8); break;
        case 'duck': P.duck(ctx, x, y + 6); break;
        case 'car': P.toyCar(ctx, x, y + 8, th.speed > 0); break;
        case 'ball': P.toyBall(ctx, x, y + 8, t); break;
        case 'robot': P.toyRobot(ctx, x, y + 8); break;
        case 'shoes': P.shoes(ctx, x, y + 6); break;
        case 'basket': P.basket(ctx, x, y + 10); break;
      }
    }, extra);
    if (this.dad.visible) SN.people.dad(ctx, 150, 600, { stunned: this.dad.stunned, laughing: this.dad.pause > 0 && !this.dad.stunned, t });
  }
};

SN.Level2.windowScenes = [
  ['🐈', 'A cat is dancing on the fence!'], ['🛸', 'Was that... a UFO?!'], ['🦉', 'An owl winked at you. Hoo hoo!'],
  ['🧸', 'The neighbor is sleepwalking with his teddy bear!'], ['🌠', 'A shooting star! Make a wish!'],
];

// ---------- Your brother: taunt in his room to wake him; talk to him; he can follow you. ----------
SN.Brother = class {
  constructor() { this.reset(); }
  reset() { this.state = 'asleep'; this.x = 1050; this.y = 610; this.facingRight = false; this.walking = false; this.talking = false; this.line = ''; this.taunts = 0; this.version = 0; }
  taunted() { if (this.state === 'asleep') return false; this.taunts++; return this.taunts === 5; }
  wake() { if (this.state !== 'asleep') return; this.state = 'awake'; this.x = 1010; this.y = 610; this.facingRight = false; }
  jumpTo(p) { this.x = Math.max(60, p.x - 70); this.y = p.y; }
  update(p, right, dt) {
    if (this.state !== 'following') { this.walking = false; return; }
    const tx = p.x + (right ? -85 : 85), ty = p.y;
    const dx = tx - this.x, dy = ty - this.y, d = Math.hypot(dx, dy);
    if (d > 14) { const s = Math.min(d, 330 * dt); this.x += dx / d * s; this.y += dy / d * s; if (Math.abs(dx) > 4) this.facingRight = dx > 0; this.walking = true; }
    else this.walking = false;
  }
  startTalking() { this.line = this.state === 'following' ? "What's up? I'm right behind you!" : 'Huh?! What are you doing in my room?'; this.talking = true; this.version++; }
};

/// Things to talk about with your brother. Each topic goes back and forth.
SN.Brother.topics = [
  ["Where I'm going", [["I'm going to find Grandpa.", "Grandpa?! But nobody will tell us where he is!"], ["Auntie knows. Uncle's going to drive me to her city.", "Whoa. That's really far. Farther than school."], ["I'll bring him a lantern from the festival.", 'Bring me one too? A green one. Please please please.']]],
  ['Your toys', [['Why are your toys ALL over the floor?', "It's not a mess. It's a trap. For burglars."], ["I'm the one who keeps stepping on them!", '...Then the trap works.'], ["Which one's your favourite?", 'The squeaky one. I only lend it to people I really like.']]],
  ['Scary stuff', [['Are you scared of the dark?', 'No! ...A little. Only the bit under the bed.'], ["There's only a lockbox under mine.", "That's exactly what a monster would want you to think."], ["I'll check under yours when I'm back.", "Okay. Deal. Don't forget."]]],
  ['A joke', [['Tell me a joke.', 'Why did the kid bring a ladder to bed?'], ["I don't know. Why?", 'To get to HIGH sleep! ...Get it? Like high school?'], ['That was terrible.', 'You laughed. I saw your face do the thing.']]],
];

/// The talk menu with your brother.
SN.talkPanel = function (buddy, tip, giveToy, onClose) {
  const el = SN.el(`<div class="overlay"><div class="popup talk" style="max-width:640px">
    <div class="line" data-t="you" style="display:none;background:#ffcc40;align-self:flex-end"></div>
    <div class="line" data-t="him"></div>
    <div data-t="opts" class="talk"></div></div></div>`);
  const you = el.querySelector('[data-t="you"]'), him = el.querySelector('[data-t="him"]'), opts = el.querySelector('[data-t="opts"]');
  const say = (y, h) => { you.style.display = y ? '' : 'none'; you.textContent = y ? 'You: ' + y : ''; him.textContent = 'Brother: ' + h; };
  const option = (text, fn) => { const b = SN.el(`<button class="big press opt" style="--c:#594db3">${SN.esc(text)}</button>`); b.addEventListener('click', () => { SN.sound.tap(); fn(); }); opts.appendChild(b); };
  const menu = () => {
    opts.innerHTML = '';
    option("Let's talk", topics);
    option('What are you doing up?', () => say(null, "I heard you being silly! Are you sneaking out? That's so cool!"));
    option('Got any tips?', () => say(null, tip));
    if (giveToy) option('Give him a toy', () => { giveToy(); giveToy = null; say(null, 'A toy? For ME? You\'re the best!'); menu(); });
    if (buddy.state === 'following') option('Wait here', () => { buddy.state = 'awake'; say(null, "Okay. I'll wait right here."); menu(); });
    else option('Follow me', () => { buddy.state = 'following'; say(null, "Yay! I'll be super quiet. Promise!"); menu(); });
    option('Go back to sleep', () => { buddy.state = 'asleep'; onClose(); });
    option('Bye', onClose);
  };
  const topics = () => {
    opts.innerHTML = '';
    say(null, 'Talk? At night? Okay! What about?');
    SN.Brother.topics.forEach(([title, talk]) => option(title, () => chat(talk, 0)));
    option("That's enough talking", () => { say(null, 'That was nice. We should talk more!'); menu(); });
  };
  const chat = (talk, i) => {
    say(talk[i][0], talk[i][1]);
    opts.innerHTML = '';
    if (i + 1 < talk.length) option('Keep talking', () => chat(talk, i + 1));
    else option('Talk about something else', topics);
    option("That's enough talking", () => { say(null, 'That was nice. We should talk more!'); menu(); });
  };
  say(null, buddy.line);
  menu();
  return el;
};

/// The door keypad: type the code and press Enter.
SN.keypad = function (hint, onSubmit, onCancel) {
  const el = SN.el(`<div class="overlay"><div class="popup keypad">
    <div class="sym" style="color:#ffcc40">🔐</div><h2>Enter the door code</h2><p data-k="hint">${SN.esc(hint)}</p>
    <div class="row"><input type="text" maxlength="6" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="CODE"><button class="big press" data-k="go">Enter</button></div>
    <p style="margin-top:12px"><button class="chip press" data-k="cancel">Cancel</button></p></div></div>`);
  const input = el.querySelector('input'), msg = el.querySelector('[data-k="hint"]');
  const go = () => {
    if (!onSubmit(input.value)) { msg.textContent = 'Wrong code! Try again.'; msg.style.color = '#ff6b5e'; input.value = ''; input.focus(); }
  };
  el.querySelector('[data-k="go"]').addEventListener('click', go);
  input.addEventListener('keydown', ev => { if (ev.key === 'Enter') go(); ev.stopPropagation(); });
  el.querySelector('[data-k="cancel"]').addEventListener('click', () => { SN.sound.tap(); onCancel(); });
  setTimeout(() => input.focus(), 50);
  return el;
};

/// Paper from your brother's room: draw with your finger or mouse. The picture is kept in the browser.
SN.drawingPad = function (onDone) {
  const el = SN.el(`<div class="overlay"><div class="popup" style="padding:20px;max-width:none">
    <div class="row" style="justify-content:space-between;margin-bottom:10px"><b style="font-size:26px">✏️ Draw something!</b>
      <span><button class="chip press" data-d="undo">↶ Undo</button> <button class="chip press" data-d="clear">New page</button> <button class="big press" data-d="done">✓ Done</button></span></div>
    <canvas width="720" height="430" style="background:#fffaeb;border-radius:10px;max-width:86vw;touch-action:none"></canvas>
    <div class="row" data-d="colors" style="margin-top:10px"></div></div></div>`);
  const cv = el.querySelector('canvas'), ctx = cv.getContext('2d');
  const colors = ['#000', '#ff3b30', '#ff9500', '#ffcc00', '#34c759', '#007aff', '#af52de', '#ff2d55', '#a2845e', '#fff'];
  let color = 0, strokes = [], cur = null;
  try { strokes = JSON.parse(localStorage.getItem('sn.drawing') || '[]'); } catch (e) { strokes = []; }
  const redraw = () => {
    ctx.clearRect(0, 0, cv.width, cv.height);
    for (const s of strokes.concat(cur ? [cur] : [])) {
      ctx.strokeStyle = colors[s.c]; ctx.lineWidth = s.w; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      ctx.beginPath(); s.p.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y + 0.01)); ctx.lineTo(s.p[s.p.length - 1][0] + 0.1, s.p[s.p.length - 1][1]); ctx.stroke();
    }
  };
  const pt = ev => { const r = cv.getBoundingClientRect(); return [(ev.clientX - r.left) * cv.width / r.width, (ev.clientY - r.top) * cv.height / r.height]; };
  cv.addEventListener('pointerdown', ev => { cv.setPointerCapture(ev.pointerId); cur = { c: color, w: 6, p: [pt(ev)] }; redraw(); });
  cv.addEventListener('pointermove', ev => { if (cur) { cur.p.push(pt(ev)); redraw(); } });
  const end = () => { if (cur) { strokes.push(cur); cur = null; redraw(); } };
  cv.addEventListener('pointerup', end); cv.addEventListener('pointercancel', end);
  const row = el.querySelector('[data-d="colors"]');
  colors.forEach((c, i) => {
    const b = SN.el(`<div class="swatch ${i === 0 ? 'on' : ''}" style="background:${c}"></div>`);
    b.addEventListener('click', () => { color = i; row.querySelectorAll('.swatch').forEach(s => s.classList.remove('on')); b.classList.add('on'); });
    row.appendChild(b);
  });
  el.querySelector('[data-d="undo"]').addEventListener('click', () => { strokes.pop(); redraw(); });
  el.querySelector('[data-d="clear"]').addEventListener('click', () => { strokes = []; redraw(); });
  el.querySelector('[data-d="done"]').addEventListener('click', () => {
    try { localStorage.setItem('sn.drawing', JSON.stringify(strokes)); } catch (e) { /* too big to keep */ }
    onDone();
  });
  redraw();
  return el;
};
