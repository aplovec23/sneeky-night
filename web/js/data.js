// Fixed game data: how characters can look, accessories, boosts, badges and the levels.
// It mirrors the iPad version, so the two stay the same game.

SN.look = {
  skins: [[0.99, 0.86, 0.74], [0.96, 0.78, 0.62], [0.87, 0.66, 0.48], [0.74, 0.53, 0.36], [0.57, 0.38, 0.25], [0.40, 0.26, 0.17]].map(c => SN.rgb(...c)),
  shirts: [[0.26, 0.52, 0.92], [0.78, 0.42, 0.86], [0.90, 0.28, 0.30], [0.25, 0.70, 0.40], [0.98, 0.58, 0.18], [0.98, 0.82, 0.20], [0.98, 0.52, 0.70], [0.15, 0.70, 0.72],
           [0.15, 0.15, 0.15], [1, 1, 1], [0.55, 0.95, 0.45], [0.45, 0.30, 0.85], [0.60, 0.38, 0.20], [0.55, 0.85, 1.0]].map(c => SN.rgb(...c)),
  /// The first 8 shirt colours; the rest unlock in the Other Hallway's secret room.
  baseShirts: 8,
  patterns: ['star', 'heart', 'bolt', 'moon', 'paw', null],
  caps: [null, '#ff3b30', SN.rgb(0.2, 0.4, 0.9), '#34c759', SN.white(0.15), '#ff9500', '#af52de', '#ffffff', '#ff2d55', '#32ade6', SN.colors.gold],
  baseCaps: 7,
  hairStyles: ['Classic', 'Spiky', 'Curly', 'Long', 'Ponytail', 'Buzz cut', 'Bob', 'Mohawk', 'Pigtails', 'Afro', 'Bun', 'Space buns',
               'Braid', 'Bowl cut', 'Side part', 'Quiff', 'Flat top', 'Bald', 'Long wavy', 'Short fringe'],
  hairColors: [null, SN.white(0.1), SN.rgb(0.25, 0.15, 0.08), SN.rgb(0.85, 0.7, 0.3), SN.rgb(0.8, 0.35, 0.12), SN.white(0.6), SN.white(0.95),
               SN.rgb(0.25, 0.5, 0.95), SN.rgb(1, 0.5, 0.75), SN.rgb(0.3, 0.75, 0.4), SN.rgb(0.6, 0.35, 0.85)],
  pants: [[0.20, 0.25, 0.40], [0.18, 0.18, 0.18], [0.45, 0.32, 0.20], [0.55, 0.55, 0.58], [0.25, 0.38, 0.25], [0.62, 0.20, 0.24], [0.85, 0.78, 0.62]].map(c => SN.rgb(...c)),
  shoes: [[0.95, 0.95, 0.98], [0.15, 0.15, 0.15], [0.85, 0.20, 0.22], [0.20, 0.45, 0.90], [0.95, 0.75, 0.20], [0.50, 0.32, 0.20]].map(c => SN.rgb(...c)),
  eyes: [[0.08, 0.08, 0.08], [0.38, 0.22, 0.10], [0.20, 0.45, 0.85], [0.25, 0.55, 0.30], [0.55, 0.55, 0.60], [0.55, 0.30, 0.70]].map(c => SN.rgb(...c)),
  shirtStyles: ['T-shirt', 'Hoodie', 'Stripes', 'Jacket'],
  moods: ['Calm', 'Happy', 'Worried', 'Scared', 'Surprised', 'Sneaky', 'Sleepy', 'Cross'],
  starter(gender) {
    return { gender, skin: 0, shirt: gender === 'boy' ? 0 : 1, pattern: 0, cap: 0, hair: 0, hairColor: 0, pants: -1, shoes: 0, eyes: 0,
             shirtStyle: 0, freckles: false, blush: true, face: 0, accessory: null, boosts: [], hiddenBoosts: [] };
  },
};

/// Things to wear from boxes: the first 10, then 10 kinds in 5 colours each.
SN.accessories = (function () {
  const shades = [['Red', '#ff3b30'], ['Blue', SN.rgb(0.2, 0.45, 0.95)], ['Green', SN.rgb(0.2, 0.7, 0.35)], ['Purple', '#af52de'],
                  ['Pink', SN.rgb(1, 0.5, 0.7)], ['Yellow', SN.rgb(1, 0.82, 0.2)], ['Black', SN.white(0.15)], ['Gold', SN.colors.gold],
                  ['Orange', '#ff9500'], ['Teal', '#30b0c7']];
  const list = [
    { id: 'sunglasses', family: 'glasses', name: 'Sunglasses', color: '#000000' },
    { id: 'crown', family: 'crown', name: 'Crown', color: SN.colors.gold },
    { id: 'bowTie', family: 'bowTie', name: 'Bow Tie', color: '#ff3b30' },
    { id: 'scarf', family: 'scarf', name: 'Scarf', color: '#ff9500' },
    { id: 'cape', family: 'cape', name: 'Hero Cape', color: '#ff3b30' },
    { id: 'headband', family: 'headband', name: 'Ninja Headband', color: '#ff3b30' },
    { id: 'catEars', family: 'catEars', name: 'Cat Ears', color: SN.white(0.25) },
    { id: 'headphones', family: 'headphones', name: 'Headphones', color: '#32ade6' },
    { id: 'halo', family: 'halo', name: 'Halo', color: '#ffcc00' },
    { id: 'partyHat', family: 'partyHat', name: 'Party Hat', color: '#ff2d55' },
  ];
  const variants = (family, label, picks) => picks.forEach(i =>
    list.push({ id: `${family}-${shades[i][0].toLowerCase()}`, family, name: `${shades[i][0]} ${label}`, color: shades[i][1] }));
  variants('glasses', 'Glasses', [0, 1, 2, 4, 7]); variants('bowTie', 'Bow Tie', [1, 2, 3, 5, 6]);
  variants('scarf', 'Scarf', [0, 1, 2, 3, 4]); variants('cape', 'Cape', [1, 2, 3, 6, 7]);
  variants('headband', 'Headband', [1, 2, 6, 4, 5]); variants('partyHat', 'Party Hat', [0, 1, 2, 8, 9]);
  variants('beanie', 'Beanie', [0, 1, 2, 3, 8]); variants('topHat', 'Top Hat', [6, 0, 1, 3, 7]);
  variants('hairBow', 'Hair Bow', [0, 4, 1, 5, 9]); variants('flower', 'Flower', [4, 5, 0, 3, 8]);
  return list;
})();
SN.accessoryIcon = { glasses: '🕶', crown: '👑', bowTie: '🎀', scarf: '🧣', cape: '🦸', headband: '🥷', catEars: '🐱', headphones: '🎧',
                     halo: '😇', partyHat: '🥳', beanie: '❄️', topHat: '🎩', hairBow: '🎀', flower: '🌸' };

/// Rare accessories with powers. They all stack.
SN.boosts = [
  { id: 'coolCap', name: 'Cool Cap with a Can', about: 'Speed ×1.5', icon: '🧢', color: '#ff3b30' },
  { id: 'leaf', name: 'Leaf', about: 'Jump ×1.3 higher', icon: '🍃', color: '#34c759' },
  { id: 'lightningBall', name: 'Lightning Ball', about: "Press F: speed, dash and jump ×3.5 for 25 seconds, and you're quieter. 1 minute cooldown.", icon: '⚡', color: '#ffcc00' },
  { id: 'windCrown', name: 'Wind Crown', about: 'Speed ×1.2 and dash ×2.5', icon: '💨', color: '#32ade6' },
  { id: 'goldenCrown', name: 'Golden Crown', about: "Everything ×1.2, and you're quieter", icon: '👑', color: SN.colors.gold },
  { id: 'arrow', name: 'Arrow', about: 'Dash ×1.9 and walking speed ×1.2', icon: '➶', color: '#ff9500' },
  { id: 'cloud', name: 'Cloud', about: 'Press X: fly for 10 seconds, over obstacles. 30 second cooldown.', icon: '☁️', color: SN.rgb(0.8, 0.92, 1) },
];
/// Boosts nobody can find in a box: only a character hands them over. Auntie gives the Water Hose (Level 7).
SN.specialBoosts = [
  { id: 'waterHose', name: 'Water Hose', about: "Press J: spray whoever is chasing you so they can't see for 8 seconds (every 25). In Level 4 it waters five plants at once.", icon: '💧', color: SN.rgb(0.25, 0.70, 0.85) },
];
/// Every boost, findable or not (for the Customize screen and pop-ups).
SN.allBoosts = () => SN.boosts.concat(SN.specialBoosts);

/// [id, name, how to earn it]. "soon" badges can't be earned yet.
SN.badges = [
  ['oopsies', 'Oopsies!', 'Get caught.'], ['amNotPm', 'is it PM? Nope AM', 'Let the time run out.'], ['patienceIsKey', 'patience is key', 'Find a key.'],
  ['hiDad', 'hi dad!', 'Get caught by Dad instead of Mom.'], ['curiosity', 'curiosity', 'Look out of the hallway window 3 times.'],
  ['trolledMom', 'Get trolled mom!', 'When time runs out and Mom comes looking, taunt right in front of her.'], ['boredom', 'boredom', 'Stay on the menu for 10 minutes.'],
  ['deadlySqueak', 'deadly squeak', 'Get caught by stepping on a toy.'], ['luckyGuess', 'lucky guess', 'Guess the door code without the paper.'],
  ['ninja', 'im now a ninja', 'Learn a new skill.'], ['fly', 'i believe i can fly!!', 'Go up to the rooftop with a ladder.'],
  ['passcode', 'Mom whats the passcode again?', "Get the passcode on Mom's phone wrong 5 times."], ['owl', 'did you see that', 'Find the owl on the rooftop.'],
  ['funnySon', 'Thats funny son', 'Taunt in front of Dad.'], ['oldHouse', 'How old is this house?', 'Step on a loose plank.'],
  ['fireMusic', 'Fire Music!', "Open the Music app on Mom's phone."], ['goAwayMom', 'Go away mom!', 'Let Mom find you while your brother is following you.'],
  ['goldenStick', '????', 'Find the VERY rare golden stick on the rooftop.'], ['southPark', 'South park', 'Name yourself a cuss word.'],
  ['tooHard', 'This game is too hard!', 'Get caught 10 times.'], ['friendlyRoute', 'Friendly Route', 'Give Mom, your brother and Dad a toy.'],
  ['crashout', 'Crashout', 'Taunt your brother 5 times.'], ['level1', 'Level 1', 'Complete Level 1.'], ['level2', 'Level 2', 'Complete Level 2.'],
  ['level3', 'Level 3', 'Complete Level 3.'], ['level4', 'Level 4', 'Complete Level 4.'], ['power', 'I FEEL DA POWERRRR!!!', 'Collect 10 star balls on the rooftop.'],
  ['aprilFool', 'soon', 'Coming in a later update.'], ['pumpkins', 'Scary pumpkins', 'Play the game on Halloween.'], ['jolly', 'soon', 'Coming in a later update.'],
  ['joinedDemo', 'Joined Demo!!!!!?!?', 'Play the demo (until Level 10 is done).'], ['shh', 'Shh Mom/Dad is here!', 'Hide from Mom or Dad.'],
  ['coolCap', 'check out my cool cap!', 'Get an accessory from a box.'], ['multiplayer', 'multiplayer', 'Play a level in multiplayer mode.'],
  ['trolledAgain', 'Trolled again!', "Taunt Mom while she's stunned."], ['retry', 'Retry', 'Retry 20 times.'],
  ['numberOne', 'number 1# player!', 'Finish every level, every accessory and every badge.'], ['justInCase', 'Just in case', 'Make 10 save files.'],
  ['unstoppable', 'Im unstoppable!', 'Own every boosting accessory and every permanent item.'],
  ['worldRevolving', 'the world revolving', 'Sprint with star ball power while wearing every speed-boosting accessory.'],
  ['kittens', 'Cat whisperer', "Find every missing kitten in Auntie's backyard."], ['dreamer', 'Sweet dreams', 'Wake up from a dream (Side Level 5).'],
];
SN.soonBadges = ['aprilFool', 'jolly'];

/// The ten levels. `ready` ones are built in this web version so far.
SN.levels = [
  { id: 1, room: 'Bedroom', icon: '🛏', seconds: 100, ready: true },
  { id: 2, room: 'Hallway', icon: '🚪', seconds: 150, ready: true },
  { id: 3, room: 'Downstairs', icon: '🪜', seconds: 200, ready: true },
  { id: 4, room: 'Garden', icon: '🌿', seconds: 250, ready: true },
  { id: 5, room: 'Street', icon: '🛣', seconds: 350, ready: true },
  { id: 6, room: "Auntie's House", icon: '🐈', seconds: 400, ready: true },
  { id: 7, room: "Auntie's Backyard", icon: '💧', seconds: 450, ready: true },
  { id: 8, room: 'Coming soon', icon: '🔒', seconds: 500, ready: false },
  { id: 9, room: 'Coming soon', icon: '🔒', seconds: 550, ready: false },
  { id: 10, room: 'Coming soon', icon: '🔒', seconds: 600, ready: false },
];
/// A level's clock on the difficulty being played.
SN.levelTime = id => Math.round(SN.levels[id - 1].seconds * SN.difficulty.timeScale);
