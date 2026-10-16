// Mom or Dad coming to find you. They walk in through a door and head for you. You can outrun
// them, jump over them, hide (they might still check your hiding place) or stun them. After a
// minute without catching you they give up. Sometimes the other parent comes over and they
// talk about the noisy house for a minute. (A port of Chase.swift.)

SN.Chase = class {
  constructor() {
    this.who = 'mom'; this.active = false; this.visible = false;
    this.x = 0; this.y = 0; this.facingRight = true; this.walking = false;
    this.stunned = 0; this.laughing = 0; this.timeLeft = 0;
    this.speech = null; this.partner = null; this.partnerX = 0; this.partnerY = 0; this.partnerWalking = false; this.partnerSpeech = null;
    this.talkLeft = 0; this.brotherSpeech = null;
    this.engine = null;
    this.entrance = () => ({ x: 0, y: 600, delay: 2 });
    this.waypoint = null;
    this.onCaught = () => {}; this.onGaveUp = () => {}; this.setBanner = () => {}; this.award = () => {};
    this.brotherFollowing = () => false;
    this.brotherPos = () => null;
    this._door = { x: 0, y: 600 }; this._enter = 0; this._look = 0; this._bannerTime = 0;
    this._wasConcealed = false; this._sawHide = false; this._checked = false; this._wander = null;
    this._brotherUsed = false; this._laughed = false; this._meetIn = Infinity; this._metBrother = false;
    this._script = []; this._lineTime = 0; this._linePause = 3.6; this._speechTime = 0; this._mutterIn = 4;
  }

  get momOut() { return this.active && this.who === 'mom'; }
  get dadOut() { return this.active && this.who === 'dad'; }
  get talking() { return this.talkLeft > 0; }
  get speed() { return SN.difficulty.chaserSpeed(this.who === 'mom' ? 225 : 245, this.engine ? this.engine.pace : 290); }

  reset() {
    this.active = false; this.visible = false; this.walking = false; this.stunned = 0; this.laughing = 0;
    this._bannerTime = 0; this._brotherUsed = false; this._laughed = false;
    this.speech = null; this.partner = null; this.partnerSpeech = null; this.brotherSpeech = null;
    this.talkLeft = 0; this._script = []; this._meetIn = Infinity; this._metBrother = false;
  }

  /// Someone heard or saw you. Does nothing if a chase is already on.
  /// Pass `from` when they're already standing somewhere in this room.
  alarm(who, text, from) {
    const e = this.engine;
    if (!e || this.active) return;
    this.who = who; this.active = true; this.timeLeft = 60;
    this.stunned = 0; this.laughing = 0; this._laughed = false;
    this._wasConcealed = e.concealed; this._sawHide = false; this._checked = false; this._wander = null;
    this.speech = null; this.partner = null; this.talkLeft = 0; this._mutterIn = 4;
    // Four chases in ten, the other grown-up comes to see what's going on.
    this._meetIn = Math.random() < 0.4 ? SN.rand(9, 20) : Infinity;
    if (from) {
      this._door = { x: from.x, y: from.y }; this.x = from.x; this.y = from.y;
      this.visible = true; this._enter = 0; this._look = 0;
    } else {
      const way = this.entrance(who);
      this._door = { x: way.x, y: way.y }; this._enter = way.delay; this.visible = false;
    }
    e.timerOn = false;
    this.setBanner(text); this._bannerTime = 3.5;
    SN.sound.play(who === 'mom' ? 'mom' : 'dad');
  }

  /// You went through a door: they follow a couple of seconds later through the same one.
  playerChangedRoom(entry) {
    if (!this.active) return;
    this.visible = false; this.walking = false;
    this._door = { x: entry.x, y: entry.y }; this._enter = 2.4; this._sawHide = false; this._wander = null;
    this.partner = null; this.talkLeft = 0; this.speech = null; this.partnerSpeech = null;
  }

  /// Returns false when there's nobody here to stun.
  stun(seconds, momOnly) {
    if (!this.active || !this.visible || (momOnly && this.who === 'dad')) return false;
    this.stunned = Math.max(this.stunned, seconds); this.walking = false;
    return true;
  }

  forceMeet() { if (this.active && this.visible && !this.partner && !this.talking) this._meetIn = 0; }

  /// Taunting in front of them: badges for Mom; Dad laughs (once) and gives you some time.
  taunted() {
    const e = this.engine;
    if (!this.active || !this.visible || !e) return;
    if (this.stunned > 0) { if (this.who === 'mom') this.award('trolledAgain'); return; }
    if (e.concealed || Math.hypot(e.player.x - this.x, e.player.y - this.y) >= 560) return;
    if (this.who === 'mom') this.award('trolledMom');
    else if (!this._laughed) {
      this._laughed = true; this.laughing = SN.difficulty.dadLaugh; this.walking = false;
      this.award('funnySon');
      this.setBanner(`Dad: "Ha! That's funny, son. You've got ${this.laughing >= 60 ? 'a whole minute' : '10 seconds'}..."`);
      this._bannerTime = 4;
    }
  }

  _say(text, seconds) { this.speech = text; this._speechTime = seconds; }

  _startTalk(lines, pause) {
    this._script = lines.slice(); this._linePause = pause; this._lineTime = 0;
    this.talkLeft = lines.length * pause; this._speechTime = 0;
  }

  tick(dt) {
    const e = this.engine;
    if (!this.active || !e) return;
    if (this._bannerTime > 0) { this._bannerTime -= dt; if (this._bannerTime <= 0) this.setBanner(null); }
    if (!this.talking) this.timeLeft -= dt;
    if (this.timeLeft <= 0) {
      const who = this.who;
      this.reset(); this.setBanner(null); this.onGaveUp(who);
      return;
    }
    if (this.stunned > 0) { this.stunned -= dt; return; }
    if (this.laughing > 0) { this.laughing -= dt; return; }
    if (!this.visible) {
      this._enter -= dt;
      if (this._enter <= 0) {
        this.visible = true; this.x = this._door.x; this.y = this._door.y;
        // A moment in the doorway to look around, so you're never caught the instant they arrive.
        this._look = 1.2;
        SN.sound.play('door', 0.5);
      }
      return;
    }
    if (this._look > 0) { this._look -= dt; return; }
    if (this._speechTime > 0) { this._speechTime -= dt; if (this._speechTime <= 0) this.speech = null; }
    if (this.talking) { this._tickTalk(dt); return; }

    if (this.partner) {
      // The other grown-up is walking over. Whoever was chasing you waits for them.
      this.walking = false;
      const dx = this.x - this.partnerX, dy = this.y - this.partnerY, d = Math.hypot(dx, dy);
      if (d > 95) {
        const step = Math.min(d - 95, 230 * dt);
        this.partnerX += dx / d * step; this.partnerY += dy / d * step; this.partnerWalking = true;
      } else {
        this.partnerWalking = false;
        this.facingRight = this.partnerX > this.x;
        const mine = this.who;
        this._startTalk(SN.Chase.houseTalk.map(([w, t]) => [w === mine ? 'chaser' : 'partner', t]), 3.6);
        this.setBanner(`${mine === 'mom' ? 'Mom and Dad' : 'Dad and Mom'} are talking about the noise. You've got a minute!`);
        this._bannerTime = 4.5;
      }
      return;
    }
    this._meetIn -= dt;
    if (this._meetIn <= 0) {
      this._meetIn = Infinity;
      this.partner = this.who === 'mom' ? 'dad' : 'mom';
      this.partnerX = this._door.x; this.partnerY = this._door.y;
      this._say(this.who === 'mom' ? 'Huh? Is that you, dear?' : 'Honey? What are you doing up?', 2.5);
      SN.sound.play('door', 0.4);
      return;
    }
    const brother = this.brotherPos();
    if (!this._metBrother && brother && Math.hypot(brother.x - this.x, brother.y - this.y) < 130) {
      this._metBrother = true; this.facingRight = brother.x > this.x; this.walking = false;
      this._startTalk(this.who === 'mom'
        ? [['chaser', 'What are YOU doing up?'], ['brother', 'Um... getting a glass of water!'], ['chaser', 'Back to bed. Right now, mister.']]
        : [['chaser', "Hey, buddy. Can't sleep?"], ['brother', 'I dreamed about a giant duck.'], ['chaser', '...Okay. Off to bed, champ.']], 2.8);
      return;
    }

    const p = e.player, hiding = e.concealed;
    this._mutterIn -= dt;
    if (this._mutterIn <= 0) {
      this._mutterIn = SN.rand(5, 9);
      const lines = hiding && !this._sawHide ? ['Where did you go?', "I know you're in here...", 'Come out, come out...', 'Hmm. Nobody here?']
        : this.who === 'mom' ? ['Back to bed!', 'Stop right there!', 'I can SEE you!', "It's the middle of the night!"]
        : ['Hold it, kiddo!', 'Hey! Come back!', 'No running in the house!', "I'm too old for this..."];
      this._say(SN.pick(lines), 2.4);
    }
    if (hiding && !this._wasConcealed) {
      // Did they see you duck into your hiding place?
      this._sawHide = Math.hypot(p.x - this.x, p.y - this.y) < 380;
      this._checked = false;
    }
    if (!hiding) this._sawHide = false;
    this._wasConcealed = hiding;

    // Easy: they never look in hiding places. Chaos and No Mercy: they always know where you are.
    const mode = SN.difficulty.current;
    if (mode >= 3 && hiding) this._sawHide = true;
    let target = { x: p.x, y: p.y };
    if (hiding && !this._sawHide) {
      if (!this._wander || Math.hypot(this.x - this._wander.x, this.y - this._wander.y) < 30) {
        this._wander = Math.random() < 1 / 3 ? { x: p.x, y: p.y } : { x: SN.rand(80, Math.max(81, e.width - 80)), y: SN.rand(e.floor[0], e.floor[1]) };
      }
      target = this._wander;
    }
    const next = this.waypoint ? this.waypoint({ x: this.x, y: this.y }, target) : target;
    const dx = next.x - this.x, dy = next.y - this.y, d = Math.hypot(dx, dy);
    if (d > 4) {
      const step = Math.min(d, this.speed * dt);
      this.x += dx / d * step;
      this.y += dy / d * step * (Math.abs(dx) > Math.abs(dy) ? 1 : 0.8);
      if (Math.abs(dx) > 3) this.facingRight = dx > 0;
      this.walking = true;
    } else this.walking = false;

    const name = this.who === 'mom' ? 'Mom' : 'Dad';
    if (hiding) {
      if (mode === 0 || Math.abs(p.x - this.x) >= 46 || Math.abs(p.y - this.y) >= 110) return;
      if (this._sawHide) this._caught(`${name} saw where you hid... and found you!`);
      else if (!this._checked) {
        // Walking past your hiding place: half the time they look inside.
        this._checked = true;
        if (Math.random() < 0.5) { SN.sound.play('closet'); this._caught(`${name} looked in your hiding place... and found you!`); }
      }
    } else if (Math.abs(p.x - this.x) < 48 && Math.abs(p.y - this.y) < 42 && e.z < 50) {
      this._caught(`${name} caught you!`);
    }
  }

  _tickTalk(dt) {
    this.talkLeft -= dt; this._lineTime -= dt;
    if (this._lineTime <= 0 && this._script.length) {
      this._lineTime = this._linePause;
      const [speaker, text] = this._script.shift();
      this.speech = speaker === 'chaser' ? text : null;
      this.partnerSpeech = speaker === 'partner' ? text : null;
      this.brotherSpeech = speaker === 'brother' ? text : null;
    }
    if (this.talkLeft > 0) return;
    this.talkLeft = 0; this.speech = null; this.partnerSpeech = null; this.brotherSpeech = null;
    if (this.partner) { this.partner = null; SN.sound.play('door', 0.4); }
  }

  _caught(message) {
    const e = this.engine;
    // Practice mode: nobody can catch you.
    if (e && e.safe) {
      this.stunned = 4; this.walking = false;
      this._say('Just practice... carry on.', 3);
      e.say('Practice mode: I would have been caught right here!', 2.5);
      return;
    }
    // Once per try, a brother who's following you throws his toy at Mom.
    if (this.who === 'mom' && this.brotherFollowing() && !this._brotherUsed) {
      this._brotherUsed = true; this.stunned = 60; this.walking = false;
      this.award('goAwayMom');
      SN.sound.play('squeak'); SN.sound.play('table');
      if (e) e.say("My brother threw his toy at Mom! She's seeing stars. RUN!", 3.5);
      return;
    }
    const who = this.who;
    this.active = false; this.walking = false; this.setBanner(null);
    this.onCaught(who, message);
  }

  /// Draws whoever is chasing you (and whoever they're talking to).
  draw(ctx) {
    if (!this.active || !this.visible) return;
    const t = SN.now();
    const fig = (who, x, y, walking, right, speech) => {
      if (who === 'mom') SN.people.mom(ctx, x, y, { walking, stunned: this.stunned > 0 && who === this.who, facingRight: right, t });
      else SN.people.dad(ctx, x, y, { walking, stunned: this.stunned > 0 && who === this.who, laughing: this.laughing > 0 && who === this.who, facingRight: right, t });
      if (speech) SN.people.speech(ctx, x, y - 270, speech, who === 'mom' ? '#ff2d55' : '#007aff');
    };
    if (this.partner) fig(this.partner, this.partnerX, this.partnerY, this.partnerWalking, this.partnerX < this.x, this.partnerSpeech);
    fig(this.who, this.x, this.y, this.walking, this.facingRight, this.speech);
    const b = this.brotherPos();
    if (this.brotherSpeech && b) SN.people.speech(ctx, b.x, b.y - 190, this.brotherSpeech, '#34c759');
  }
};

/// Mom and Dad meet in the middle of the night and talk about the noisy house. About a minute.
SN.Chase.houseTalk = [
  ['mom', 'Did you hear that noise too?'], ['dad', 'I thought it was the fridge again.'],
  ['mom', 'This house is SO noisy at night.'], ['dad', "It's the old floorboards. Creak, creak, creak."],
  ['mom', 'And the pipes! Bang, bang, all night.'], ['dad', "I'll fix them on Saturday."],
  ['mom', 'You said that LAST Saturday.'], ['dad', '...Did I?'],
  ['mom', "Maybe it's the kids."], ['dad', "At this hour? They're fast asleep."],
  ['mom', "I'm sure I heard footsteps."], ['dad', 'Probably the dog next door.'],
  ['mom', 'We should get thicker carpets.'], ['dad', 'Or earplugs. Earplugs are cheaper.'],
  ['mom', 'Very funny.'], ['dad', 'Fine. One more look around, then bed.'],
];
