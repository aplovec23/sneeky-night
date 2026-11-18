// The player and everything they've earned, kept in the browser (localStorage) between visits.
// As on the iPad, there can be any number of save files.

SN.GameState = class {
  constructor(slot) {
    this.slot = slot;
    const data = SN.GameState.read(slot);
    this.playerName = data.playerName || '';
    this.look = Object.assign(SN.look.starter('boy'), data.look || {});
    this.hasCharacter = !!data.hasCharacter;
    this.completedLevels = data.completedLevels || [];
    this.completedSide = data.completedSide || [];
    this.skills = data.skills || [];
    this.badges = data.badges || [];
    this.accessories = data.accessories || [];
    this.boosts = data.boosts || [];
    this.hasVines = !!data.hasVines;
    this.hasToy = !!data.hasToy;
    this.hasBat = !!data.hasBat;
    this.extraColors = !!data.extraColors;
    this.caughtCount = data.caughtCount || 0;
    this.retryCount = data.retryCount || 0;
    this.gifts = data.gifts || [];
    this.orbs = data.orbs || 0;
    this.paidLevels = data.paidLevels || [];
    /// Which modes each level has been won on: { level: [mode, ...] }. Older wins count as Mild.
    this.beatenOn = data.beatenOn || {};
    this.completedLevels.forEach(l => { if (!this.beatenOn[l]) this.beatenOn[l] = [1]; });
    this.onToast = () => {};
    // Levels won before their badge existed still count.
    for (const id of this.completedLevels) {
      const badge = 'level' + id;
      if (!SN.soonBadges.includes(badge) && !this.has(badge)) this.badges.push(badge);
    }
  }

  static key(slot) { return 'sn.save.' + slot; }
  static read(slot) {
    try { return JSON.parse(localStorage.getItem(SN.GameState.key(slot)) || '{}'); } catch (e) { return {}; }
  }

  save() {
    const out = {};
    ['playerName', 'look', 'hasCharacter', 'completedLevels', 'completedSide', 'skills', 'badges', 'accessories', 'boosts',
     'hasVines', 'hasToy', 'hasBat', 'extraColors', 'caughtCount', 'retryCount', 'gifts', 'orbs', 'paidLevels', 'beatenOn'].forEach(k => out[k] = this[k]);
    try { localStorage.setItem(SN.GameState.key(this.slot), JSON.stringify(out)); } catch (e) { /* storage full or private mode */ }
  }

  // ---------- Save files ----------
  static get slots() {
    try { const s = JSON.parse(localStorage.getItem('sn.slots') || '[0]'); return s.length ? s : [0]; } catch (e) { return [0]; }
  }
  static get currentSlot() { return parseInt(localStorage.getItem('sn.currentSlot') || '0', 10) || 0; }
  static set currentSlot(v) { localStorage.setItem('sn.currentSlot', String(v)); }
  static newSlot() {
    const all = SN.GameState.slots;
    const id = Math.max(...all) + 1;
    localStorage.setItem('sn.slots', JSON.stringify(all.concat([id])));
    return id;
  }
  static summary(slot) {
    const d = SN.GameState.read(slot);
    return { name: d.playerName || '', levels: (d.completedLevels || []).length, badges: (d.badges || []).length };
  }

  // ---------- Badges ----------
  has(badge) { return this.badges.includes(badge); }
  award(badge) {
    if (SN.soonBadges.includes(badge) || this.has(badge)) return;
    this.badges.push(badge);
    this.save();
    SN.sound.play('magic');
    this.onToast(badge);
  }
  awardLaunchBadges() {
    this.award('joinedDemo');
    const d = new Date();
    if (d.getMonth() === 9 && d.getDate() === 31) this.award('pumpkins');
  }
  noteCaught() {
    this.caughtCount++; this.save();
    this.award('oopsies');
    if (this.caughtCount >= 10) this.award('tooHard');
  }
  noteRetry() {
    this.retryCount++; this.save();
    if (this.retryCount >= 20) this.award('retry');
  }
  give(toyTo) {
    if (!this.gifts.includes(toyTo)) this.gifts.push(toyTo);
    this.save();
    if (['mom', 'brother', 'dad'].every(w => this.gifts.includes(w))) this.award('friendlyRoute');
  }
  checkName() {
    const n = this.playerName.toLowerCase();
    if (['damn', 'hell', 'crap', 'ass', 'butt', 'poop', 'fart', 'shit', 'fuck', 'bitch', 'piss', 'dick', 'bastard'].some(w => n.includes(w))) this.award('southPark');
  }

  // ---------- Levels and loot ----------
  /// You can only play a level once you've won the one before it. Level 7 also needs 32 badges
  /// and 10 orbs paid at the gate (once).
  isUnlocked(level) {
    if (!level.ready || !(level.id === 1 || this.completedLevels.includes(level.id - 1))) return false;
    return level.id !== 7 || (this.badges.length >= SN.GameState.level7Badges && this.paidLevels.includes(7));
  }
  /// What Level 7 needs, for the Levels screen.
  get level7Requirements() {
    const G = SN.GameState;
    return [['Win Level 6', this.completedLevels.includes(6)],
            [`Earn ${G.level7Badges} badges (${Math.min(this.badges.length, G.level7Badges)}/${G.level7Badges})`, this.badges.length >= G.level7Badges],
            [`Pay ${G.level7Price} orbs (you have ${this.orbs})`, this.paidLevels.includes(7) || this.orbs >= G.level7Price]];
  }
  /// Pays Level 7's entry. False if you can't yet (not enough orbs or badges, or Level 6 not won).
  payForLevel7() {
    const G = SN.GameState;
    if (this.paidLevels.includes(7) || !this.completedLevels.includes(6) || this.badges.length < G.level7Badges || this.orbs < G.level7Price) return false;
    this.orbs -= G.level7Price;
    this.paidLevels.push(7);
    this.save();
    return true;
  }
  get nextLevel() {
    const l = SN.levels.find(l => l.ready && !this.completedLevels.includes(l.id) && this.isUnlocked(l));
    return l ? l.id : null;
  }
  complete(level) {
    if (!this.completedLevels.includes(level)) this.completedLevels.push(level);
    const modes = this.beatenOn[level] || [];
    if (!modes.includes(SN.difficulty.current)) this.beatenOn[level] = modes.concat([SN.difficulty.current]);
    this.save();
    this.award('level' + level);
  }
  // ---------- Modes, level by level ----------
  /// The hardest mode a level has been won on (-1 = not won yet).
  bestMode(level) { return Math.max(-1, ...(this.beatenOn[level] || [])); }
  /// Easy and Mild are always open. Win a level on Mild to open Hard for it, on Hard to open Chaos,
  /// and on Chaos (with 1000 orbs and 35 badges) to open No Mercy.
  modeUnlocked(mode, level) {
    const best = this.bestMode(level), G = SN.GameState;
    if (mode <= 1) return true;
    if (mode === 2) return best >= 1;
    if (mode === 3) return best >= 2;
    return best >= 3 && this.orbs >= G.noMercyOrbs && this.badges.length >= G.noMercyBadges;
  }
  /// What a locked mode still needs, as [text, met] pairs.
  modeNeeds(mode, level) {
    const best = this.bestMode(level), G = SN.GameState;
    if (mode === 2) return [[`Win Level ${level} on Mild`, best >= 1]];
    if (mode === 3) return [[`Win Level ${level} on Hard`, best >= 2]];
    if (mode === 4) return [[`Win Level ${level} on Chaos`, best >= 3], [`Have ${G.noMercyOrbs} orbs (you have ${this.orbs})`, this.orbs >= G.noMercyOrbs],
                            [`Earn ${G.noMercyBadges} badges (${Math.min(this.badges.length, G.noMercyBadges)}/${G.noMercyBadges})`, this.badges.length >= G.noMercyBadges]];
    return [];
  }
  /// The hardest open mode up to the one wanted.
  playableMode(wanted, level) { for (let m = wanted; m > 1; m--) if (this.modeUnlocked(m, level)) return m; return Math.min(wanted, 1); }

  learn(skill) {
    if (!this.skills.includes(skill)) this.skills.push(skill);
    this.save();
    this.award('ninja');
  }
  /// What a box gives when it has nothing special: sometimes the bat, rarely a boost, often nothing.
  rollLoot(boostOdds = 15) {
    if (!this.hasBat && SN.randInt(0, 12) === 0) return { type: 'bat' };
    const odds = Math.max(2, Math.round(boostOdds / SN.difficulty.lootScale));
    const newBoosts = SN.boosts.filter(b => !this.boosts.includes(b.id));
    if (SN.randInt(0, odds) === 0 && newBoosts.length) return { type: 'boost', boost: SN.pick(newBoosts) };
    const newItems = SN.accessories.filter(a => !this.accessories.includes(a.id));
    if (SN.randInt(0, 5) === 0 && newItems.length) return { type: 'accessory', item: SN.pick(newItems) };
    return null;
  }
  /// A boost you don't have yet (the roof and the garden's radar hand these out), or null.
  newBoost() { const left = SN.boosts.filter(b => !this.boosts.includes(b.id)); return left.length ? SN.pick(left) : null; }
  take(loot) {
    if (loot.type === 'boost' && SN.specialBoosts.some(b => b.id === loot.boost.id)) {
      if (!this.boosts.includes(loot.boost.id)) { this.boosts.push(loot.boost.id); this.look.boosts.push(loot.boost.id); }
      this.save();
      return;
    }
    if (loot.type === 'accessory') { this.accessories.push(loot.item.id); this.award('coolCap'); }
    if (loot.type === 'boost') { this.boosts.push(loot.boost.id); this.look.boosts.push(loot.boost.id); }
    if (loot.type === 'bat') this.hasBat = true;
    this.save();
    if (SN.boosts.every(b => this.boosts.includes(b.id)) && this.hasVines && this.hasToy && this.hasBat) this.award('unstoppable');
  }
};

SN.GameState.level7Badges = 32;
SN.GameState.level7Price = 10;
SN.GameState.noMercyOrbs = 1000;
SN.GameState.noMercyBadges = 35;

/// The pop-up shown when a search finds something.
SN.lootPopup = function (loot, take) {
  if (loot.type === 'accessory') {
    return { title: 'New accessory!', message: `You found the ${loot.item.name}!\nPut it on in Customize Character.`,
             symbol: SN.accessoryIcon[loot.item.family] || '🎁', color: loot.item.color, button: 'Awesome!', action: take };
  }
  if (loot.type === 'boost') {
    return { title: 'RARE BOOST!', message: `${loot.boost.name}!\n${loot.boost.about}\nIt's already on. Boosts stack!`,
             symbol: loot.boost.icon, color: loot.boost.color, button: 'WOW!', action: take };
  }
  return { title: 'You found a BAT!', message: 'Yours to keep forever. Press B to bonk Mom: she sees stars for 2 seconds (ready again after 5).',
           symbol: '🏏', color: '#ff9500', button: 'Take', action: take };
};
