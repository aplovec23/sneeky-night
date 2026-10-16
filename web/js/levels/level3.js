// Level 3 rules, in the order you're meant to solve them:
// 1. Go down the stairs without stepping on a loose plank (jump them — crouching doesn't help).
// 2. Take food from the fridge and throw it out of the window: a dog with a key comes to the front
//    door. Bring him a second snack and he swaps it for his key (it locks the exit from outside).
// 3. Three door keys are locked in boxes around the house. Find 3 metal scraps, craft a key from
//    each at the garage workbench, and open the boxes.
// 4. With all 3 door keys, flip the garage light switch 3 times. Dad comes down to check: hide in
//    a closet until he's in the garage.
// 5. Upstairs, take a toy from your brother's room and throw it in the hallway. Mom comes out to
//    look at it; while she's busy, take her phone (passcode 12345) and read Notes: the code is 0090.
// 6. Dad is now in the basement. Dodge him (closets are safe), type 0090 at the exit door.
// 7. Outside, lock the door with the dog's key before Dad gets out, then walk to the garden.
// A ladder in the garage lets you climb out of the upstairs window onto the roof (star balls).
// Each big step adds 45 seconds to the clock. (A port of Level3Downstairs.swift.)

SN.Level3 = class {
  constructor(game, { onExit, onNext }) {
    this.game = game; this.onExit = onExit; this.onNext = onNext;
    this.engine = new SN.Engine();
    this.belt = new SN.ItemBelt();
    this.chase = new SN.Chase();
    this.buddy = new SN.Brother();
    this.run = 0;
    const e = this.engine, c = this.chase;
    e.onInteract = i => this.interact(i);
    e.onDefaultInteract = () => this.defaultAction();
    e.onHazard = i => this.bumped(i);
    e.onTimeUp = () => this.momWakes(false);
    e.onTooLoud = () => this.momWakes(true);
    e.onConfirm = () => this.popup && this.popup.action();
    e.onTaunt = () => this.taunted();
    e.onTick = dt => this.tick(dt);
    e.onItemKey = item => this.belt.use(item);
    this.belt.stun = (s, momOnly) => this.stunGrownUp(s, momOnly);
    c.engine = e;
    c.entrance = who => this.entrance(who);
    c.setBanner = b => this.banner = b;
    c.award = b => this.award(b);
    c.brotherFollowing = () => this.buddy.state === 'following';
    c.brotherPos = () => (this.buddy.state === 'following' || (this.buddy.state === 'awake' && this.room === 'brother')) ? { x: this.buddy.x, y: this.buddy.y } : null;
    c.onCaught = (who, msg) => this.caught(who, msg);
    c.onGaveUp = who => this.gaveUp(who);
    this.belt.configure(game, e);
    e.canDash = game.skills.includes('dash');
    e.canRun = game.skills.includes('run');
    this.reset();
  }

  /// On Easy both codes are just three numbers.
  static get passcode() { return SN.difficulty.current === 0 ? '123' : '12345'; }
  static get exitCode() { return SN.difficulty.current === 0 ? '090' : '0090'; }

  title() {
    return { stairs: 'Level 3 · Stairs', downstairs: 'Level 3 · Downstairs', garage: 'Level 3 · Garage', basement: 'Level 3 · Basement',
             yard: 'Level 3 · Back Yard', hallway: 'Level 3 · Hallway', brother: "Level 3 · Brother's Room", mom: "Level 3 · Mom's Room",
             roof: 'Sub level · The Roof' }[this.room];
  }
  award(b) { if (b === 'oopsies') this.game.noteCaught(); else this.game.award(b); }
  retry() { this.game.noteRetry(); this.reset(); }
  get over() { return this.phase === 'over'; }

  get inventory() {
    const items = [];
    if (this.hasFood) items.push({ id: 'food', icon: '🌭', color: '#ff9500' });
    if (this.hasDogKey) items.push({ id: 'dogKey', icon: '🔑', color: '#32ade6' });
    for (let i = 0; i < this.scraps; i++) items.push({ id: 'scrap' + i, icon: '⚙️', color: SN.colors.silver });
    for (let i = 0; i < this.smallKeys; i++) items.push({ id: 'small' + i, icon: '🗝', color: SN.colors.silver });
    for (let i = 0; i < this.doorKeys; i++) items.push({ id: 'door' + i, icon: '🔑', color: SN.colors.gold });
    if (this.hasToy) items.push({ id: 'toy', icon: '🧸', color: '#ff2d55' });
    if (this.hasLadder) items.push({ id: 'ladder', icon: '🪜', color: '#a2845e' });
    if (this.hasPhoneCode) items.push({ id: 'code', icon: '📝', color: '#ffcc00' });
    return items;
  }

  reset() {
    this.run++;
    const e = this.engine, L = SN.Level3;
    this.belt.reset();
    this.dadStunned = false; this.dadPause = 0; this.dadLaughed = false; this.momDeleted = false;
    this.scrapSpots = SN.shuffle(L.searchSpots).slice(0, 3);
    const boxes = SN.shuffle(L.lockboxSpots).slice(0, 3);
    const keep = list => list.filter(t => !t.id.startsWith('lockbox') || boxes.includes(t.id));
    this.saved = {
      stairs: L.stairsThings(), downstairs: keep(L.downstairsThings()), garage: keep(L.garageThings()), basement: keep(L.basementThings()),
      yard: L.yardThings(), hallway: L.hallwayThings(), brother: SN.Level2.siblingRoom(), mom: L.momRoomThings(), roof: L.roofThings(),
    };
    this.room = 'stairs';
    e.load({ width: L.widths.stairs, floor: [545, 690], things: this.saved.stairs, spawn: { x: 220, y: 615 } });
    e.timeLeft = SN.levelTime(3); e.timerOn = true; e.resetNoise(); e.noiseFactor = 1;
    e.speedBoost = false; e.jumpBoost = false; e.shields = 0; e.speedBonus = 0; e.runHeld = false; e.tauntOnly = false;
    e.crouching = false; e.facingRight = true; e.bubble = null;
    this.chase.reset(); this.buddy.reset();
    this.phase = 'sneaking'; this.popup = null; this.banner = null; this.hidingIn = null; this.playerOpacity = 1;
    Object.assign(this, {
      hasFood: false, dogWaiting: false, hasDogKey: false, scraps: 0, smallKeys: 0, doorKeys: 0, garageLight: false, hasLadder: false,
      hasToy: false, hasPhoneCode: false, codeAccepted: false, exitOpen: false, doorLocked: false, stars: 0,
      showPhone: false, showKeypad: false, drawing: false,
      dad: 'upstairs', dadX: 1300, dadChecking: false, dadDirection: -1, dadCheckStage: 0, dadCheckTime: 12,
      mom: 'asleep', momX: 2200, momOut: false, momTime: 0, toyX: null,
      checkpoints: new Set(), lightFlips: 0, lureTime: 0, lockTime: 0, starTime: 3, boostTime: 60, starCount: 0,
      sawStreet: false, sawGarden: false,
    });
    e.running = true;
    e.say("The stairs are creaky. I'd better jump over the loose planks!", 4);
  }

  // ---------- Rooms ----------
  static wall(id, kind, x, prompt, reach = 70) { return SN.Level2.onWall(id, kind, x, prompt, reach); }
  static plank(n, x, y, depth) { return SN.thing({ id: 'plank' + n, kind: 'plank', x, y, fw: 84, fh: depth, hazard: 'plank', crouchSafe: false, flat: true }); }

  static stairsThings() {
    const W = SN.Level3.wall, P = SN.Level3.plank;
    return [
      W('toHallway', 'stairsUp', 110, 'Go upstairs'),
      P(1, 400, 580, 58), P(2, 570, 662, 50), P(3, 770, 617, 145), P(4, 960, 572, 46), P(5, 1100, 664, 46), P(6, 1290, 617, 145), P(7, 1480, 598, 90),
      W('toDownstairs', 'stairsDown', 1690, 'Go downstairs'),
    ];
  }
  static downstairsThings() {
    const W = SN.Level3.wall, O = SN.Level2.obstacle;
    return [
      W('toStairs', 'stairsUp', 110, 'Go upstairs'), W('closetA', 'closet', 330, 'Hide in the closet'),
      W('couch', 'couch', 590, 'Search the couch', 90), O('table1', 'table', 760, 645, 110, 36),
      W('dWindow', 'dWindow', 900, 'Look out of the window'), W('bookshelf', 'bookshelf', 1100, 'Search the bookshelf'),
      O('lamp1', 'lamp', 1250, 580, 40, 26), W('frontDoor', 'frontDoor', 1410, 'Check the front door'),
      W('lockbox1', 'lockbox', 1580, 'Open the lockbox', 55), W('fridge', 'fridge', 1770, 'Grab some food'),
      O('chair1', 'chair', 1890, 655, 64, 30), W('kitchenDrawer', 'kitchenCounter', 1980, 'Search the kitchen drawer', 80),
      W('lockbox2', 'lockbox', 2150, 'Open the lockbox', 55), W('closetB', 'closet', 2320, 'Hide in the closet'),
      W('toGarage', 'garageDoor', 2530, 'Go into the garage'), W('toBasement', 'basementDoor', 2790, 'Go down to the basement'),
    ];
  }
  static garageThings() {
    const W = SN.Level3.wall, O = SN.Level2.obstacle;
    return [
      W('toHouse', 'houseDoor', 110, 'Back into the house'), W('switch', 'lightSwitch', 270, 'Flip the light switch', 50),
      W('bin', 'bin', 410, 'Search the recycling bin', 55), O('cans', 'cans', 540, 660, 60, 26),
      SN.thing({ id: 'car', kind: 'car', x: 760, y: 545, heavy: true, reachW: 180, reachH: 160 }),
      W('lockbox3', 'lockbox', 1000, 'Open the lockbox', 50), W('workbench', 'workbench', 1130, 'Use the workbench', 65),
      W('toolbox', 'toolbox', 1280, 'Search the toolbox', 55), W('ladder', 'ladder', 1410, 'Grab the ladder', 55),
    ];
  }
  static basementThings() {
    const W = SN.Level3.wall, O = SN.Level2.obstacle;
    return [
      W('toHouseUp', 'stairsUp', 110, 'Back upstairs'), W('trunk', 'trunk', 330, 'Search the old trunk'),
      W('lockbox4', 'lockbox', 540, 'Open the lockbox', 55), W('closetC', 'closet', 760, 'Hide in the closet'),
      SN.thing({ id: 'washer', kind: 'washer', x: 960, y: 545, heavy: true, reachW: 70, reachH: 160 }),
      Object.assign(O('bucket', 'cans', 1010, 660, 50, 26), { kind: 'cans' }),
      W('lockbox5', 'lockbox', 1160, 'Open the lockbox', 55), W('closetD', 'closet', 1400, 'Hide in the closet'),
      W('exitDoor', 'exitDoor', 1750, 'Unlock the door', 90),
    ];
  }
  static yardThings() {
    const W = SN.Level3.wall;
    return [W('yardDoor', 'yardDoor', 170, 'Lock the door', 90), W('gate', 'gardenGate', 1450, 'Go into the garden', 90)];
  }
  /// The Level 2 hallway again; its far door now leads to the stairs.
  static hallwayThings() {
    return SN.Level2.hallway().map(t => {
      if (t.id === 'exitDoor') return SN.Level3.wall('toStairs', 'stairsDown', 3270, 'Go downstairs');
      if (t.id === 'window') t.prompt = 'Look out of the window';
      return t;
    });
  }
  static momRoomThings() {
    return SN.Level2.momRoom().map(t => { if (t.id === 'momNightstand') t.prompt = "Grab Mom's phone"; return t; });
  }
  static roofThings() {
    const W = SN.Level3.wall;
    return [W('roofWindow', 'roofWindow', 830, 'Climb back inside', 90), W('owl', 'owl', 1505, 'Look at the chimney', 60)];
  }

  go(room, spawn) {
    SN.sound.play('door', 0.5);
    const e = this.engine;
    this.saved[this.room] = e.things;
    e.load({ width: SN.Level3.widths[room], floor: [545, 690], things: this.saved[room] || [], spawn });
    e.noiseFactor = room === 'roof' ? 0 : (room === 'mom' && this.mom === 'asleep' ? 2 : 1);
    this.hidingIn = null;
    this.dadChecking = false; this.dadCheckStage = 0; this.dadCheckTime = SN.rand(9, 15);
    if (this.banner && this.banner.includes('Footsteps')) this.banner = null;
    this.room = room;
    this.chase.playerChangedRoom(spawn);
    if (this.buddy.state === 'following') this.buddy.jumpTo(e.player);
    this.refreshPrompts();
    // The clock stops while you're up on the roof.
    if (this.phase === 'sneaking' && !this.chase.active) e.timerOn = room !== 'roof' && room !== 'yard';
    if (room === 'downstairs') this.checkpoint('downstairs');
    else if (room === 'basement' && this.dad === 'basement') {
      this.dadX = Math.max(this.dadX, 1000);
      e.say("Dad is down here! Closets are safe — he won't check them.", 4);
    } else if (room === 'yard') { e.timerOn = false; this.lockTime = 10; this.checkpoint('outside'); }
    else if (room === 'roof') { this.award('fly'); e.say('The roof! Nobody can hear me up here.', 3); }
    else if (room === 'mom' && this.mom === 'asleep') e.say("Shhh! Mom's asleep.");
  }

  /// Prompts that depend on what you're carrying or what has happened.
  refreshPrompts() {
    const e = this.engine;
    e.defaultPrompt = this.hasToy && this.room === 'hallway' ? 'Throw the toy' : this.buddy.state === 'following' ? 'Talk to your brother' : null;
    const set = (id, p) => { const t = e.thing(id); if (t) t.prompt = p; };
    if (this.room === 'downstairs') {
      set('dWindow', this.hasFood && !this.dogWaiting ? 'Throw food out of the window' : 'Look out of the window');
      set('frontDoor', this.dogWaiting && !this.hasDogKey ? (this.hasFood ? 'Give the dog a snack' : 'Check on the dog') : 'Check the front door');
    } else if (this.room === 'hallway') set('window', this.hasLadder ? 'Climb out onto the roof' : 'Look out of the window');
    else if (this.room === 'yard') set('yardDoor', this.doorLocked ? null : 'Lock the door');
    else if (this.room === 'garage') set('ladder', this.hasLadder ? null : 'Grab the ladder');
  }

  checkpoint(id) {
    if (this.checkpoints.has(id)) return;
    this.checkpoints.add(id);
    this.engine.timeLeft += 45;
    SN.sound.play('star');
    const text = 'Checkpoint! +45 seconds';
    this.banner = text;
    SN.later(this, 2, () => { if (this.banner === text) this.banner = null; });
  }

  show(p) { SN.levelShow(this, p); }

  // ---------- Pressing E ----------
  interact(i) {
    const e = this.engine, th = e.things[i];
    switch (th.kind) {
      case 'closet': return this.toggleHiding(th);
      case 'stairsUp': case 'stairsDown': case 'garageDoor': case 'basementDoor': case 'houseDoor': case 'roofWindow':
      case 'siblingDoor': case 'momDoor': case 'hallDoor': return this.useDoor(th);
      case 'couch': case 'bookshelf': case 'kitchenCounter': case 'bin': case 'toolbox': case 'trunk': return this.search(i);
      case 'fridge': return this.useFridge();
      case 'dWindow': return this.useDownstairsWindow();
      case 'frontDoor': return this.useFrontDoor();
      case 'lockbox': return this.openLockbox(i);
      case 'lightSwitch': return this.flipSwitch();
      case 'workbench': return this.craft();
      case 'ladder':
        this.hasLadder = true; th.hidden = true;
        SN.sound.play('box');
        e.say('Got the ladder! I could use it at the upstairs hallway window...', 4);
        return this.refreshPrompts();
      case 'owl': this.award('owl'); SN.sound.play('window', 0.4); return e.say('An owl! It winked at me. Hoo hoo!');
      case 'exitDoor': return this.useExitDoor();
      case 'yardDoor': return this.lockYardDoor();
      case 'gardenGate': return this.useGate();
      case 'window': return this.useHallwayWindow();
      case 'box': return this.searchBox(i);
      case 'dresser': case 'nightstand': return e.say('Empty. I already took everything from here.');
      case 'bedroomDoor': return e.say('Back to bed? No way!');
      case 'toyChest': return this.grabToy();
      case 'paper': SN.sound.play('paper'); this.drawing = true; e.paused = true; return;
      case 'sibBed': return this.talkToBrother();
      case 'momNightstand': return this.usePhone();
      case 'vanity': return e.say("Just Mom's earrings. Better not touch those.");
      case 'momBed':
        if (this.hasToy && this.mom === 'asleep') { this.hasToy = false; this.game.give('mom'); this.refreshPrompts(); e.say('I tucked the toy in next to Mom. She smiled in her sleep!'); }
        else e.say(this.mom === 'asleep' ? 'Mom is snoring. Shhh...' : "Mom's bed is empty!");
        return;
      case 'dadDesk':
        if (this.hasToy) { this.hasToy = false; this.game.give('dad'); this.refreshPrompts(); e.say("I left the toy on Dad's desk. He'll find it in the morning!"); }
        else e.say("Dad's desk. A cold cup of cocoa and yesterday's newspaper.");
    }
  }

  useDoor(th) {
    const e = this.engine;
    switch (th.id) {
      case 'toHallway': return this.go('hallway', { x: 3200, y: 600 });
      case 'toDownstairs': return this.go('downstairs', { x: 210, y: 610 });
      case 'toStairs': return this.go('stairs', this.room === 'hallway' ? { x: 220, y: 615 } : { x: 1600, y: 678 });
      case 'toGarage':
        if (this.dad === 'inGarage' || this.dad === 'walkingToGarage') return e.say('Dad is in there. No way!');
        return this.go('garage', { x: 200, y: 610 });
      case 'toBasement': return this.go('basement', { x: 200, y: 610 });
      case 'toHouse': return this.go('downstairs', { x: 2530, y: 590 });
      case 'toHouseUp': return this.go('downstairs', { x: 2790, y: 590 });
      case 'siblingDoor': return this.go('brother', { x: 190, y: 600 });
      case 'momDoor': return this.go('mom', { x: 190, y: 600 });
      case 'hallDoor': return this.go('hallway', { x: this.room === 'mom' ? 2200 : 1540, y: 580 });
      case 'roofWindow': return this.go('hallway', { x: 1010, y: 580 });
    }
  }

  toggleHiding(closet) {
    const e = this.engine;
    SN.sound.play('closet');
    if (e.hidden) { e.hidden = false; this.hidingIn = null; }
    else { e.carrying = null; e.ducking = false; e.player = { x: closet.x, y: 553 }; e.hidden = true; this.hidingIn = closet.id; }
  }

  search(i) {
    const e = this.engine, th = e.things[i];
    if (th.open) { e.say('Nothing else in here.'); return; }
    th.open = true;
    SN.sound.play('drawer');
    if (this.scrapSpots.includes(th.id)) {
      SN.sound.play('key');
      this.show({ title: 'Metal scrap!', message: `Scrap ${this.scraps + 1} of 3. The workbench in the garage can turn it into a key.`,
        symbol: '⚙️', color: SN.colors.silver, button: 'Take', action: () => this.scraps++ });
    } else {
      const loot = this.game.rollLoot();
      if (loot) this.found(loot);
      else e.say(SN.pick(['Just dust and crumbs.', 'A lost sock. No scrap here.', 'Old magazines. Nothing useful.']));
    }
  }

  found(loot) { SN.sound.play('magic'); this.show(SN.lootPopup(loot, () => this.game.take(loot))); }

  searchBox(i) {
    const th = this.engine.things[i];
    th.open = true;
    SN.sound.play('box');
    const loot = this.game.rollLoot();
    if (loot) this.found(loot);
    else this.engine.say(SN.pick(['Just old clothes.', 'Only some books in here.', 'A rubber chicken? Weird.']));
  }

  useFridge() {
    if (this.hasFood) { this.engine.say("I'm already holding a snack."); return; }
    this.hasFood = true;
    SN.sound.play('drawer');
    this.engine.say('Got a sausage. Smells yummy!');
    this.refreshPrompts();
  }

  useDownstairsWindow() {
    const e = this.engine;
    if (this.dogWaiting) e.say(this.hasDogKey ? 'The street is quiet now.' : 'The dog is waiting at the front door.');
    else if (this.hasFood) {
      this.hasFood = false; this.dogWaiting = true;
      SN.sound.play('window');
      SN.later(this, 0.9, () => SN.sound.play('woof'));
      e.say("I threw the food outside... A dog came running! He has a KEY on his collar. He's at the front door now.", 5);
      this.refreshPrompts();
    } else e.say('Dark and quiet outside. Maybe some food would bring someone over...');
  }

  useFrontDoor() {
    const e = this.engine;
    if (!this.dogWaiting) e.say('The front door. It has a pet flap at the bottom.');
    else if (this.hasDogKey) { SN.sound.play('woof', 0.5); e.say("Good dog! He's wagging his tail."); }
    else if (this.hasFood) {
      this.hasFood = false;
      SN.sound.play('woof'); SN.sound.play('key');
      this.show({ title: 'The dog gave you a key!', message: 'He swapped it for the snack through the pet flap. It locks the basement door from the outside.',
        symbol: '🔑', color: '#32ade6', button: 'Take Key',
        action: () => { this.hasDogKey = true; this.award('patienceIsKey'); this.checkpoint('dogKey'); this.refreshPrompts(); } });
    } else { SN.sound.play('woof', 0.6); e.say('Woof! The dog wants another snack before he gives up the key.'); }
  }

  openLockbox(i) {
    const e = this.engine, th = e.things[i];
    if (th.open) { e.say('This lockbox is empty now.'); return; }
    if (this.smallKeys > 0) {
      this.smallKeys--; th.open = true;
      SN.sound.play('unlock'); SN.sound.play('key');
      this.show({ title: `Door key ${this.doorKeys + 1} of 3!`,
        message: this.doorKeys === 2 ? "That's all three! Now Dad needs to be lured downstairs... the garage light switch might do it." : 'The crafted key opened the lockbox.',
        symbol: '🔑', color: SN.colors.gold, button: 'Take Key',
        action: () => { this.doorKeys++; this.award('patienceIsKey'); this.checkpoint('doorKey' + this.doorKeys); } });
    } else {
      e.say(this.scraps > 0 ? 'Locked. I can craft a key from my metal scrap at the garage workbench.' : 'Locked tight. I need metal scrap to craft a key for it.');
    }
  }

  craft() {
    const e = this.engine;
    if (this.scraps <= 0) { e.say('A workbench. With some metal scrap I could make a key here.'); return; }
    e.running = false; e.crouching = true;
    SN.sound.play('craft');
    SN.later(this, 1.2, () => {
      SN.sound.play('key');
      this.show({ title: 'You crafted a key!', message: 'It should fit one of the lockboxes around the house.', symbol: '🔨', color: SN.colors.silver,
        button: 'Take Key', action: () => { this.scraps--; this.smallKeys++; } });
    });
  }

  flipSwitch() {
    const e = this.engine;
    this.garageLight = !this.garageLight;
    SN.sound.play('lightSwitch');
    if (this.dad !== 'upstairs') return;
    if (this.doorKeys < 3) { e.say('Better not play with the lights yet. I should find all 3 door keys first.'); return; }
    this.lightFlips++;
    if (this.lightFlips >= 3) { this.dad = 'comingDown'; this.lureTime = 8; SN.sound.play('dad'); }
    else e.say(`Flick! ${3 - this.lightFlips} more and Dad will notice...`);
  }

  useHallwayWindow() {
    if (this.hasLadder) { SN.sound.play('window'); this.go('roof', { x: 930, y: 610 }); }
    else this.engine.say('Just the quiet street. If only I had a ladder to climb out...');
  }

  grabToy() {
    if (this.hasToy) { this.engine.say('One toy is enough.'); return; }
    this.hasToy = true;
    SN.sound.play('squeak', 0.3);
    this.engine.say('Got a squeaky toy. If I throw it in the hallway, Mom will come to look...', 4);
  }

  defaultAction() { if (this.hasToy && this.room === 'hallway') this.throwToy(); else this.talkToBrother(); }

  throwToy() {
    if (this.mom !== 'asleep') return;
    const e = this.engine;
    this.hasToy = false;
    this.toyX = SN.clamp(e.player.x + (e.facingRight ? 380 : -380), 250, 3150);
    SN.sound.play('squeak');
    this.mom = 'coming'; this.momX = 2200; this.momTime = 3;
    this.banner = 'Mom heard the toy! Hide before she comes out!';
    this.refreshPrompts();
  }

  usePhone() {
    if (this.mom === 'asleep' && !this.chase.momOut) { this.engine.say("Mom's phone is right by her hand. I have to get her out of the room first!"); return; }
    SN.sound.play('beep');
    this.engine.running = false;
    this.showPhone = true;
  }

  phoneNoteRead() {
    if (this.hasPhoneCode) return;
    this.hasPhoneCode = true;
    this.checkpoint('code');
    this.dad = 'basement'; this.dadX = 1400; this.dadDirection = -1;
  }

  closePhone() {
    this.showPhone = false;
    this.engine.running = this.phase === 'sneaking';
    if (this.hasPhoneCode) this.engine.say(`${SN.Level3.exitCode}! Dad finished in the garage — he's in the basement now.`, 4);
  }

  inventoryTap(id) {
    if (id !== 'code') return;
    this.show({ title: SN.Level3.exitCode, message: 'The basement door code from Mom\'s phone.', symbol: '📝', color: '#ffcc00', button: 'OK', action: () => {} });
  }

  // ---------- Grown-ups and your brother ----------
  /// Whether Dad is standing in this room right now.
  get dadHere() {
    return (this.room === 'mom' && (this.dadChecking || (this.banner || '').includes('Footsteps')))
      || (this.room === 'downstairs' && this.dad === 'walkingToGarage')
      || (this.room === 'basement' && this.dad === 'basement' && Math.abs(this.engine.player.x - this.dadX) < 800);
  }

  /// Vines (anyone) or the reward toy (Mom only): stops whoever is in the room from catching you.
  stunGrownUp(seconds, momOnly) {
    if (this.chase.stun(seconds, momOnly)) return true;
    if (!momOnly && this.dadHere) { this.dadPause = seconds; this.dadStunned = true; return true; }
    return false;
  }

  taunted() {
    this.chase.taunted();
    // Dad thinks it's funny... once per visit.
    if (this.dadHere && !this.dadLaughed) {
      this.dadLaughed = true; this.dadPause = SN.difficulty.dadLaugh;
      this.award('funnySon');
      this.banner = `Dad: "Ha! That's funny, son. You've got ${this.dadPause >= 60 ? 'a whole minute' : '10 seconds'}..."`;
    }
    if ((this.room === 'brother' || this.buddy.state === 'following') && this.buddy.taunted()) {
      this.award('crashout');
      this.engine.say('Brother: "STOP IT! You\'re SO annoying!!"', 3);
    }
    if (this.room === 'brother' && this.buddy.state === 'asleep' && this.phase === 'sneaking') {
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
    if (this.room !== 'brother' && this.buddy.state !== 'following') return;
    e.running = false;
    this.buddy.startTalking();
  }

  closeTalk() {
    this.buddy.talking = false;
    this.engine.running = this.phase === 'sneaking';
    this.refreshPrompts();
    const bed = this.engine.thing('sibBed');
    if (bed) bed.prompt = this.buddy.state === 'asleep' ? 'Look at your brother' : 'Talk to your brother';
  }

  // ---------- The way out ----------
  useExitDoor() {
    if (this.exitOpen) return;
    if (!this.codeAccepted) { SN.sound.play('beep'); this.engine.frozen = true; this.showKeypad = true; }
    else this.tryExit();
  }

  submitCode(entry) {
    if (entry.trim() !== SN.Level3.exitCode) { SN.sound.play('buzz'); return false; }
    SN.sound.play('unlock');
    this.codeAccepted = true;
    this.closeKeypad();
    this.tryExit();
    return true;
  }

  closeKeypad() { this.showKeypad = false; this.engine.frozen = false; }

  tryExit() {
    const e = this.engine;
    if (this.doorKeys < 3) { e.say(`The code worked! But there are 3 locks. I have ${this.doorKeys} of 3 door keys.`); return; }
    this.exitOpen = true;
    SN.sound.play('unlock'); SN.sound.play('door');
    this.go('yard', { x: 260, y: 610 });
    e.facingRight = true;
  }

  lockYardDoor() {
    const e = this.engine;
    if (this.doorLocked) return;
    if (!this.hasDogKey) { e.say("I can't lock it! I needed the key from the dog!"); return; }
    this.doorLocked = true; this.banner = null;
    SN.sound.play('unlock'); SN.sound.play('woof', 0.5);
    e.say("Locked! Dad can't follow me now. To the garden!");
    this.refreshPrompts();
  }

  useGate() {
    const e = this.engine;
    if (!this.doorLocked) { e.say('I have to lock the door first, or Dad will come after me!'); return; }
    this.phase = 'over';
    e.running = false; e.timerOn = false;
    this.game.complete(3);
    const start = { x: e.player.x, y: e.player.y }, t0 = SN.now(), run = this.run;
    const walk = () => {
      if (this.run !== run) return;
      const p = SN.clamp((SN.now() - t0) / 0.7, 0, 1);
      e.walking = p < 1; e.player.x = SN.lerp(start.x, 1500, p); e.player.y = SN.lerp(start.y, 565, p); this.playerOpacity = 1 - p;
      if (p < 1) { requestAnimationFrame(walk); return; }
      SN.sound.play('win');
      const withBrother = this.buddy.state === 'following';
      if (withBrother) { this.game.hasToy = true; this.game.save(); }
      this.show({ title: 'Level Complete!', message: withBrother ? 'You and your brother made it out! He gave you his toy: press G to stun Mom with it.' : 'You made it out of the house and into the garden!',
        symbol: '⭐', color: SN.colors.gold, button: 'Next', action: () => this.onNext(), secondButton: 'Menu', secondAction: () => this.onExit() });
    };
    requestAnimationFrame(walk);
  }

  // ---------- Every frame: Dad, Mom, the roof ----------
  tick(dt) {
    const e = this.engine;
    this.buddy.update(e.player, e.facingRight, dt);
    this.chase.tick(dt);
    if (this.dadPause > 0) {
      this.dadPause -= dt;
      if (this.dadPause <= 0) { this.dadStunned = false; this.dadLaughed = false; if ((this.banner || '').includes('funny')) this.banner = null; }
    }
    if (this.phase !== 'sneaking') return;
    // While someone is chasing you, the usual comings and goings are on hold.
    if (!this.chase.active) { this.tickDadCheck(dt); this.tickDad(dt); this.tickMom(dt); }
    this.tickYard(dt);
    this.tickRoof(dt);
  }

  /// Until he's lured away, Dad checks Mom's room now and then, like in Level 2.
  tickDadCheck(dt) {
    if (this.dad !== 'upstairs' || this.room !== 'mom') return;
    const e = this.engine;
    this.dadCheckTime -= dt;
    if (this.dadCheckStage === 0) {
      if (this.dadCheckTime <= 0) { this.dadCheckStage = 1; this.dadCheckTime = 3; SN.sound.play('dad'); this.banner = 'Footsteps... Dad is coming! Hide!'; }
    } else if (this.dadCheckStage === 1) {
      if (this.dadCheckTime <= 0) { this.dadCheckStage = 2; this.dadCheckTime = 2.6; this.banner = null; this.dadChecking = true; SN.sound.play('door', 0.5); }
    } else if (this.dadPause > 0) {
      this.dadCheckTime += dt;
    } else if (!e.concealed) {
      this.dadCheckStage = 0; this.dadCheckTime = SN.rand(9, 15); this.dadChecking = false;
      this.chase.alarm('dad', 'Dad spotted you! RUN!', { x: 150, y: 600 });
    } else if (this.dadCheckTime <= 0) {
      this.dadCheckStage = 0; this.dadCheckTime = SN.rand(9, 15); this.dadChecking = false;
      this.award('shh');
      e.say("Phew... Dad didn't see me.");
    }
  }

  tickDad(dt) {
    const e = this.engine;
    if (this.dad === 'comingDown') {
      const before = Math.ceil(this.lureTime);
      this.lureTime -= dt;
      const now = Math.ceil(Math.max(this.lureTime, 0));
      this.banner = `Dad saw the garage light! He's coming down! Hide in a closet! ${now}`;
      if (now !== before && now % 2 === 0) SN.sound.play('dad', 0.7);
      if (this.lureTime > 0) return;
      this.banner = null;
      if (this.room === 'garage' || this.room === 'stairs' || (this.room === 'downstairs' && !e.concealed)) {
        this.chase.alarm('dad', 'Dad came downstairs and spotted you! RUN!', { x: 110, y: 605 });
      } else if (this.room === 'downstairs') { this.dad = 'walkingToGarage'; this.dadX = 1300; }
      else this.dadInGarage();
    } else if (this.dad === 'walkingToGarage') {
      if (this.dadPause <= 0 || this.room !== 'downstairs') this.dadX += 300 * dt;
      if (this.room === 'downstairs' && this.dadPause <= 0 && !e.concealed && Math.abs(e.player.x - this.dadX) < 420) {
        this.chase.alarm('dad', 'Dad saw you on his way to the garage! RUN!', { x: this.dadX, y: 605 });
      } else if (this.dadX >= 2530) this.dadInGarage();
    } else if (this.dad === 'basement') {
      if (this.room !== 'basement' || this.dadPause > 0) return;
      this.dadX += this.dadDirection * 150 * dt;
      if (this.dadX < 260) { this.dadX = 260; this.dadDirection = 1; }
      if (this.dadX > 1480) { this.dadX = 1480; this.dadDirection = -1; }
      if (!e.concealed && Math.abs(e.player.x - this.dadX) < 300) {
        this.chase.alarm('dad', 'Dad spotted you in the basement! RUN!', { x: this.dadX, y: 605 });
      }
    }
  }

  dadInGarage() {
    this.dad = 'inGarage'; this.garageLight = true;
    if (this.engine.concealed) this.award('shh');
    this.checkpoint('dadLured');
    this.engine.say("Dad went into the garage. Now's my chance to sneak upstairs!", 4);
  }

  /// Mom walks out to the thrown toy, studies it for a while, then goes back to bed.
  tickMom(dt) {
    if (this.mom === 'asleep') return;
    const e = this.engine;
    if (this.mom === 'coming') {
      if (this.momTime > 0) {
        this.momTime -= dt;
        if (this.momTime <= 0) { SN.sound.play('door'); this.banner = null; this.momOut = true; }
        return;
      }
      if (this.toyX === null) return;
      this.momX += (this.toyX > this.momX ? 1 : -1) * 190 * dt;
      if (Math.abs(this.toyX - this.momX) < 60) { this.mom = 'atToy'; this.momTime = 22; }
    } else if (this.mom === 'atToy') {
      this.momTime -= dt;
      if (this.momTime <= 0) this.mom = 'returning';
    } else if (this.mom === 'returning') {
      this.momX += (this.momX < 2200 ? 1 : -1) * 190 * dt;
      if (Math.abs(this.momX - 2200) < 12) {
        this.mom = 'asleep'; this.momOut = false; this.toyX = null;
        SN.sound.play('door', 0.5);
        if (this.room === 'mom') {
          if (e.concealed) e.say("Mom's back in bed. Phew!");
          else this.chase.alarm('mom', 'Mom came back and saw you in her room! RUN!', { x: 150, y: 600 });
        }
        return;
      }
    }
    if (this.momOut && this.room === 'hallway' && !e.concealed && Math.abs(e.player.x - this.momX) < 360) {
      // She drops the toy and comes after you from where she's standing.
      this.mom = 'asleep'; this.momOut = false; this.toyX = null;
      this.chase.alarm('mom', 'Mom spotted you! RUN!', { x: this.momX, y: 605 });
    }
  }

  tickYard(dt) {
    if (this.room !== 'yard' || this.doorLocked) return;
    this.lockTime -= dt;
    this.banner = `Lock the door before Dad gets out! ${Math.ceil(Math.max(this.lockTime, 0))}`;
    if (this.lockTime <= 0) { this.banner = null; this.dadX = 220; this.caught('dad', 'Dad heard the door and came out after you!'); }
  }

  /// Star balls appear on the roof now and then; each one makes you 6% faster for the rest of the level.
  tickRoof(dt) {
    if (this.room !== 'roof') return;
    const e = this.engine, L = SN.Level3, p = e.player;
    if (!this.sawStreet && p.x < L.roofEdge - 120) { this.sawStreet = true; e.say('Whoa! I can see the whole street from up here.', 3); }
    if (!this.sawGarden && p.x > L.widths.roof - L.roofEdge + 120) { this.sawGarden = true; e.say("There's the garden maze! It looks tiny from the roof.", 3); }
    const spot = () => ({ x: SN.rand(640, 2760), y: SN.rand(570, 680) });
    const ball = (id, kind) => SN.thing(Object.assign({ id, kind, fw: 36, fh: 30 }, spot()));
    const touching = kind => e.things.findIndex(t => t.kind === kind && Math.abs(t.x - p.x) < 42 && Math.abs(t.y - p.y) < 36);
    // Boosting accessories are much easier to find up here: about one a minute.
    this.boostTime -= dt;
    if (this.boostTime <= 0) {
      this.boostTime = SN.rand(50, 70);
      if (this.game.newBoost() && !e.things.some(t => t.kind === 'boostBall')) { e.things.push(ball('boostBall', 'boostBall')); e.say('Something glowing just landed on the roof!', 2.5); }
    }
    let i = touching('boostBall');
    if (i >= 0) { e.things.splice(i, 1); const boost = this.game.newBoost(); if (boost) this.found({ type: 'boost', boost }); }
    i = touching('goldenStick');
    if (i >= 0) { e.things.splice(i, 1); this.useGoldenStick(); }
    this.starTime -= dt;
    if (this.starTime <= 0) {
      // The golden stick: a 0.000000000001 chance each time a star would appear.
      if (Math.random() < 0.000000000001) e.things.push(ball('goldenStick', 'goldenStick'));
      this.starTime = SN.rand(4, 7);
      if (e.things.filter(t => t.kind === 'starBall').length < 3) { this.starCount++; e.things.push(ball('star' + this.starCount, 'starBall')); }
    }
    i = touching('starBall');
    if (i >= 0) {
      e.things.splice(i, 1);
      this.stars++;
      if (this.stars >= 10) this.award('power');
      e.speedBonus = Math.min(0.6, this.stars * 0.06);
      SN.sound.play('star');
      e.say(e.speedBonus >= 0.6 ? "Star ball! I'm at top speed!" : `Star ball! I feel faster! (${this.stars})`, 1.6);
    }
  }

  /// The golden stick deletes things: every obstacle in the house, and even Mom.
  useGoldenStick() {
    this.award('goldenStick');
    SN.sound.play('magic');
    this.momDeleted = true;
    if (this.chase.momOut) this.chase.reset();
    this.momOut = false; this.mom = 'asleep';
    for (const k in this.saved) this.saved[k] = this.saved[k].filter(t => !t.hazard);
    this.engine.things = this.engine.things.filter(t => !t.hazard);
    this.show({ title: 'THE GOLDEN STICK', message: 'It deleted every obstacle in the house... and Mom. Nothing can stop you now.', symbol: '🪄', color: SN.colors.gold, button: 'Whoa', action: () => {} });
  }

  // ---------- Getting caught ----------
  /// Bumping something makes a noise, and Mom gets up to see what it was.
  bumped(i) {
    const e = this.engine, hazard = e.things[i].hazard;
    if (hazard === 'toy') this.award('deadlySqueak');
    if (hazard === 'plank') this.award('oldHouse');
    e.ignoreHazards(2.5);
    e.running = true;
    if (this.chase.active || this.momDeleted) return;
    this.chase.alarm('mom', `${SN.hazards[hazard][1]} Mom heard it. She's coming!`);
  }

  /// Out of time or too loud: Mom gets out of bed and comes looking for you.
  momWakes(tooLoud) {
    if (this.phase !== 'sneaking') return;
    const e = this.engine;
    if (this.chase.active || this.momDeleted) {
      e.resetNoise();
      if (e.timeLeft <= 0) { e.timeLeft = 30; e.timerOn = true; }
      return;
    }
    if (!tooLoud) this.award('amNotPm');
    this.closeKeypad();
    // If she was out looking at the toy, she drops that and comes for you.
    const start = this.momOut && this.room === 'hallway' ? { x: this.momX, y: 605 } : undefined;
    this.mom = 'asleep'; this.momOut = false;
    this.chase.alarm('mom', tooLoud ? "Too loud! Mom woke up. She's coming to find you!" : "Time's up! Mom woke up. She's coming to find you!", start);
  }

  /// Where a grown-up walks in for the room you're in, and how long it takes them to get there.
  entrance(who) {
    switch (this.room) {
      case 'hallway': return { x: 2200, y: 575, delay: 2.5 };
      case 'mom': return who === 'mom' ? { x: 1180, y: 610, delay: 1.5 } : { x: 150, y: 600, delay: 2.5 };
      case 'brother': return { x: 150, y: 600, delay: 5 };
      case 'stairs': return { x: 110, y: 610, delay: 4 };
      case 'downstairs': return { x: 110, y: 600, delay: 6 };
      case 'garage': case 'basement': return { x: 110, y: 600, delay: 7 };
      case 'yard': return { x: 170, y: 600, delay: 7 };
      default: return { x: 830, y: 600, delay: 6 };
    }
  }

  /// A minute went by without catching you.
  gaveUp(who) {
    const e = this.engine;
    this.award('shh'); e.resetNoise();
    e.timerOn = this.room !== 'roof' && this.room !== 'yard';
    if (who === 'mom') { e.timeLeft = 120; e.say('Mom gave up and went back to bed. 2 minutes until she wakes up again!', 4); return; }
    e.say('Dad gave up looking. Phew!', 3);
    // He carries on with what he was doing.
    if (this.dad === 'comingDown' || this.dad === 'walkingToGarage') this.dadInGarage();
    else if (this.dad === 'basement') { this.dadX = 1400; this.dadDirection = -1; }
  }

  caught(who, message) {
    this.award('oopsies');
    if (who === 'dad') this.award('hiDad');
    this.engine.frozen = false;
    this.showKeypad = false; this.showPhone = false;
    this.phase = 'over'; this.banner = null;
    this.engine.running = false;
    SN.sound.play('caught');
    this.show({ title: 'Caught!', message, symbol: '⚠️', color: '#ff3b30', button: 'Try Again', action: () => this.retry(), secondButton: 'Menu', secondAction: () => this.onExit() });
  }

  get tip() {
    if (!this.checkpoints.has('downstairs')) return "Go down the stairs. Jump over the loose planks — crouching won't help!";
    if (!this.hasDogKey) {
      if (this.dogWaiting) return this.hasFood ? 'Bring the snack to the dog at the front door.' : 'The dog wants another snack. Get one from the fridge!';
      return this.hasFood ? 'Throw the food out of the downstairs window.' : 'Grab some food from the fridge in the kitchen.';
    }
    if (this.doorKeys < 3) {
      if (this.smallKeys > 0) return 'Use the crafted key on a lockbox. There are 3 hidden around the house.';
      if (this.scraps > 0) return 'Craft a key at the workbench in the garage.';
      return 'Search for metal scraps: the couch, shelves, drawers, bins, the toolbox, the trunk...';
    }
    if (!this.hasPhoneCode) {
      if (this.dad === 'upstairs') return 'Flip the garage light switch 3 times so Dad comes down. Then hide in a closet in the house!';
      if (this.dad === 'comingDown' || this.dad === 'walkingToGarage') return 'Hide in a closet until Dad is in the garage!';
      if (this.mom === 'asleep') return this.hasToy ? 'Throw the toy in the upstairs hallway, then hide until Mom walks past.' : "Upstairs: grab a toy from my brother's room.";
      return "Mom is out of her room! Grab her phone from her nightstand.";
    }
    if (this.room !== 'yard' && !this.exitOpen) return `The basement door code is ${SN.Level3.exitCode}. Watch out for Dad down there — closets are safe.`;
    return this.doorLocked ? 'Walk to the garden gate!' : "Lock the door with the dog's key. Quick!";
  }

  hint() { this.engine.say(this.tip, 4.5); }

  get shadeAmount() {
    if (this.room === 'garage') return this.garageLight ? 0.08 : 0.5;
    if (this.room === 'basement') return 0.34;
    if (this.room === 'yard' || this.room === 'roof') return 0.1;
    return 0.22;
  }

  // ---------- Panels over the room ----------
  overlayKey() {
    if (this.showKeypad) return 'keypad';
    if (this.showPhone) return 'phone';
    if (this.buddy.talking) return 'talk' + this.buddy.version;
    if (this.drawing) return 'draw';
    return null;
  }

  overlay() {
    if (this.showKeypad) return SN.keypad("The basement door code. Mom keeps it on her phone.", s => this.submitCode(s), () => this.closeKeypad());
    if (this.showPhone) return SN.phonePanel(SN.Level3.passcode, SN.Level3.exitCode, {
      onNoteRead: () => this.phoneNoteRead(), onFiveFails: () => this.award('passcode'),
      onOpenApp: name => { if (name === 'Music') this.award('fireMusic'); }, onClose: () => this.closePhone(),
    });
    if (this.buddy.talking) return SN.talkPanel(this.buddy, this.tip, this.hasToy ? () => { this.hasToy = false; this.game.give('brother'); this.refreshPrompts(); } : null, () => this.closeTalk());
    if (this.drawing) return SN.drawingPad(() => { this.drawing = false; this.engine.paused = false; this.engine.say("Not bad! I'll show Grandpa.", 2.2); });
    return null;
  }

  // ---------- Drawing ----------
  drawWorld(ctx, t, runner) {
    const P = SN.props, e = this.engine, L = SN.Level3, w = L.widths[this.room];
    switch (this.room) {
      case 'stairs': P.stairsWall(ctx, w); break;
      case 'downstairs': P.downstairsWall(ctx, w); break;
      case 'garage': P.garageWall(ctx, w); break;
      case 'basement': P.basementWall(ctx, w); break;
      case 'yard': P.yardScene(ctx, w); break;
      case 'hallway': P.hallwayWall(ctx, w); break;
      case 'brother': P.siblingRoomWall(ctx, w); break;
      case 'mom': P.momRoomWall(ctx, w); break;
      case 'roof': P.roofScene(ctx, w, L.roofEdge); break;
    }
    for (const th of e.things) if (!SN.onFloor(th) && !th.hidden) this.drawWallThing(ctx, th, t);
    if (this.room === 'hallway' && this.toyX !== null) P.thrownToy(ctx, this.toyX, 625);

    const extra = this.chase.active && this.chase.visible ? [{ y: this.chase.y, draw: () => this.chase.draw(ctx) }] : [];
    const b = this.buddy;
    if (!e.hidden && (b.state === 'following' || (b.state === 'awake' && this.room === 'brother'))) {
      extra.push({ y: b.y, draw: () => {
        SN.people.character(ctx, b.x, b.y, SN.people.brotherLook, { facingRight: b.facingRight, walking: b.walking, scale: 0.78, t });
        SN.draw.rrect(ctx, b.x, b.y - 145, 70, 20, 10, 'rgba(0,0,0,.4)'); SN.draw.text(ctx, 'Brother', b.x, b.y - 144, 14, '#fff');
      } });
    }
    const dadOpts = { stunned: this.dadStunned, laughing: this.dadPause > 0 && !this.dadStunned, t };
    if (this.room === 'hallway' && this.momOut) extra.push({ y: 605, draw: () => SN.people.mom(ctx, this.momX, 605, { walking: this.mom !== 'atToy', facingRight: this.mom === 'coming' ? (this.toyX || 0) > this.momX : this.momX < 2200, t }) });
    if ((this.room === 'downstairs' && this.dad === 'walkingToGarage') || (this.room === 'basement' && this.dad === 'basement')
        || (this.room === 'yard' && this.phase === 'over' && !this.doorLocked)) {
      extra.push({ y: 605, draw: () => SN.people.dad(ctx, this.dadX, 605, Object.assign({ walking: this.dadPause <= 0 && this.phase === 'sneaking', facingRight: this.dad === 'walkingToGarage' || this.dadDirection > 0 }, dadOpts)) });
    }
    if (this.room === 'yard') extra.push({ y: 575, draw: () => P.dog(ctx, 560, 575, true, t) });
    runner.drawFloor(ctx, t, th => {
      const x = th.x, y = th.y;
      switch (th.kind) {
        case 'plank': P.plank(ctx, x, y, th.fw, th.fh); break;
        case 'starBall': P.starBall(ctx, x, y, t); break;
        case 'boostBall': P.boostBall(ctx, x, y, t); break;
        case 'goldenStick': P.goldenStick(ctx, x, y, t); break;
        case 'cans': P.paintCans(ctx, x, y + 10); break;
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
    if (this.room === 'mom' && this.dadChecking) SN.people.dad(ctx, 150, 600, dadOpts);
  }

  drawWallThing(ctx, th, t) {
    const P = SN.props, x = th.x, y = th.y;
    switch (th.kind) {
      case 'closet': return P.closet(ctx, x, y, this.hidingIn === th.id);
      case 'stairsUp': return P.stairsDoor(ctx, x, y, true);
      case 'stairsDown': return P.stairsDoor(ctx, x, y, false);
      case 'couch': return P.couch(ctx, x, y);
      case 'bookshelf': return P.bookshelf(ctx, x, y);
      case 'kitchenCounter': return P.kitchenCounter(ctx, x, y, th.open);
      case 'fridge': return P.fridge(ctx, x, y);
      case 'dWindow': return P.window(ctx, x, y, this.dogWaiting, true);
      case 'frontDoor': return P.frontDoor(ctx, x, y, this.dogWaiting, this.hasDogKey, t);
      case 'lockbox': return P.lockbox(ctx, x, y, th.open);
      case 'garageDoor': return P.door(ctx, x, y, SN.white(0.45), false, 'GARAGE');
      case 'basementDoor': return P.door(ctx, x, y, SN.rgb(0.30, 0.36, 0.30), false, 'BASEMENT ↓', '#fff');
      case 'houseDoor': return P.door(ctx, x, y, SN.white(0.45), false, 'HOUSE');
      case 'lightSwitch': return P.lightSwitch(ctx, x, y, this.garageLight);
      case 'bin': return P.bin(ctx, x, y);
      case 'car': return P.car(ctx, x, y);
      case 'workbench': return P.workbench(ctx, x, y);
      case 'toolbox': return P.toolbox(ctx, x, y, th.open);
      case 'ladder': return P.ladder(ctx, x, y);
      case 'trunk': return P.trunk(ctx, x, y, th.open);
      case 'washer': return P.washer(ctx, x, y);
      case 'exitDoor': return P.exitDoor(ctx, x, y, this.exitOpen, this.codeAccepted);
      case 'yardDoor': return P.door(ctx, x, y, SN.rgb(0.25, 0.40, 0.30), false, this.doorLocked ? 'LOCKED' : 'UNLOCKED!', this.doorLocked ? '#34c759' : '#ff3b30');
      case 'gardenGate': return P.gardenGate(ctx, x, y);
      case 'roofWindow': return P.roofWindow(ctx, x, y);
      case 'owl': return P.owl(ctx, x, y, t);
      case 'toyChest': return P.toyChest(ctx, x, y);
      case 'paper': return P.paperStack(ctx, x, y);
      case 'dadDesk': return P.dadDesk(ctx, x, y);
      case 'dresser': return P.dresser(ctx, x, y, th.open);
      case 'nightstand': return P.nightstand(ctx, x, y, th.open);
      case 'window': return P.window(ctx, x, y, this.hasLadder, true);
      case 'bedroomDoor': return P.door(ctx, x, y, SN.rgb(0.45, 0.32, 0.55), false, 'My Room');
      case 'siblingDoor': return P.door(ctx, x, y, SN.rgb(0.35, 0.55, 0.75), false, 'KEEP OUT ★', '#ff9500');
      case 'hallDoor': return P.door(ctx, x, y, this.room === 'mom' ? SN.rgb(0.55, 0.3, 0.3) : SN.rgb(0.35, 0.55, 0.75), this.dadChecking);
      case 'momDoor': return P.door(ctx, x, y, SN.rgb(0.55, 0.3, 0.3), this.mom !== 'asleep' || this.chase.momOut, 'MOM ♥', '#ff2d55');
      case 'sibBed': return P.siblingBed(ctx, x, y, this.buddy.state !== 'asleep');
      case 'vanity': return P.vanity(ctx, x, y, true);
      case 'momBed': return P.momBed(ctx, x, y, this.mom !== 'asleep' || this.chase.momOut);
      case 'momNightstand': return P.phoneNightstand(ctx, x, y);
    }
  }
};

SN.Level3.searchSpots = ['couch', 'bookshelf', 'kitchenDrawer', 'bin', 'toolbox', 'trunk'];
SN.Level3.lockboxSpots = ['lockbox1', 'lockbox2', 'lockbox3', 'lockbox4', 'lockbox5'];
SN.Level3.widths = { stairs: 1800, downstairs: 3000, garage: 1500, basement: 1900, yard: 1600, hallway: 3400, brother: 1500, mom: 1600, roof: 3400 };
/// The roof runs the whole length of the house. Past each end (`roofEdge` from either side) you look down on the street or the garden.
SN.Level3.roofEdge = 560;

/// Mom's phone: a passcode lock screen, then a home screen where Notes holds the door code.
SN.phonePanel = function (passcode, code, { onNoteRead, onFiveFails, onOpenApp, onClose }) {
  const el = SN.el(`<div class="overlay"><div class="row" style="gap:30px;align-items:center;flex-wrap:wrap;justify-content:center">
    <div class="phone"><div class="phone-screen" data-p="screen"></div></div>
    <button class="big press" data-p="close" style="background:#8e8e93">✕ Put it back</button></div></div>`);
  const screen = el.querySelector('[data-p="screen"]');
  const apps = [['Notes', '📝', '#ffcc00'], ['Photos', '🖼', '#ff2d55'], ['Clock', '⏰', '#ff9500'], ['Music', '🎵', '#ff3b30'], ['Camera', '📷', '#8e8e93'], ['Messages', '💬', '#34c759']];
  const texts = {
    Photos: '437 pictures of you as a baby. And one of Dad asleep on the couch.', Clock: 'Alarm set for 6:00 AM. Yikes.',
    Music: "Now playing: 'Relaxing Whale Sounds, Volume 9'.", Camera: 'You take a blurry selfie. Better delete that.',
    Messages: 'Grandma: "Are the kids asleep?"\nMom: "Of course! Like little angels."',
  };
  let entry = '', fails = 0, wrong = false;
  const locked = () => {
    screen.innerHTML = `<div class="lock">🔒</div><div class="msg" style="color:${wrong ? '#ff6b5e' : '#fff'}">${wrong ? 'Wrong passcode' : 'Enter Passcode'}</div>
      <div class="dots">${[...passcode].map((_, i) => `<i class="${i < entry.length ? 'on' : ''}"></i>`).join('')}</div>
      <div class="pad">${['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'].map(k => k ? `<button class="press" data-k="${k}">${k}</button>` : '<span></span>').join('')}</div>`;
    screen.querySelectorAll('[data-k]').forEach(b => b.addEventListener('click', () => {
      const k = b.dataset.k;
      if (k === '⌫') { entry = entry.slice(0, -1); return locked(); }
      SN.sound.play('beep', 0.6);
      wrong = false;
      if (entry.length >= passcode.length) return;
      entry += k;
      if (entry.length === passcode.length) {
        if (entry === passcode) { SN.sound.play('unlock'); entry = ''; return home(); }
        SN.sound.play('buzz'); wrong = true; fails++; entry = '';
        if (fails === 5) onFiveFails();
      }
      locked();
    }));
  };
  const home = () => {
    screen.innerHTML = `<div class="clock">2:04</div><div class="apps">${apps.map(([n, i, c]) => `<button class="press" data-app="${n}"><span style="background:${c}">${i}</span>${n}</button>`).join('')}</div>`;
    screen.querySelectorAll('[data-app]').forEach(b => b.addEventListener('click', () => {
      const n = b.dataset.app;
      SN.sound.play('click');
      onOpenApp(n);
      if (n === 'Notes') onNoteRead();
      app(n);
    }));
  };
  const app = name => {
    const body = name === 'Notes'
      ? `<div class="note"><b>Basement door</b><div class="code">${SN.esc(code)}</div><small>(don't tell the kids!)</small></div>`
      : `<p class="apptext">${SN.esc(texts[name])}</p>`;
    screen.innerHTML = `<div class="apphead"><button class="press" data-p="back">‹ Back</button><b>${name}</b><span></span></div>${body}`;
    screen.querySelector('[data-p="back"]').addEventListener('click', () => { SN.sound.play('click'); home(); });
  };
  el.querySelector('[data-p="close"]').addEventListener('click', () => { SN.sound.tap(); onClose(); });
  // Typing numbers on the keyboard works on the lock screen too.
  el.tabIndex = -1;
  el.addEventListener('keydown', ev => { const b = screen.querySelector(`[data-k="${ev.key === 'Backspace' ? '⌫' : ev.key}"]`); if (b) { b.click(); ev.stopPropagation(); } });
  setTimeout(() => el.focus(), 50);
  locked();
  return el;
};
