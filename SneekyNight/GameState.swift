import SwiftUI
import Observation

enum Gender: String, CaseIterable {
    case boy, girl
}

/// How the player's character looks. Each number picks from `LookOptions`.
struct Look: Equatable {
    var gender: Gender
    var skin = 0
    var shirt = 0
    var pattern = 0
    /// 0 = no cap.
    var cap = 0
    /// Hair style, from `LookOptions.hairStyles`. 0 is the classic cut.
    var hair = 0
    /// One accessory found in a box, if you're wearing one.
    var accessory: Accessory?
    /// Boosting accessories being worn. These stack.
    var boosts: Set<Boost> = []
    /// Boosts that still work but aren't drawn on the character (when it all looks too messy).
    var hiddenBoosts: Set<Boost> = []
    var shownBoosts: Set<Boost> { boosts.subtracting(hiddenBoosts) }

    static func starter(_ gender: Gender) -> Look {
        Look(gender: gender, shirt: gender == .boy ? 0 : 1)
    }
}

enum LookOptions {
    static let skins: [Color] = [
        Color(red: 0.99, green: 0.86, blue: 0.74), Color(red: 0.96, green: 0.78, blue: 0.62),
        Color(red: 0.87, green: 0.66, blue: 0.48), Color(red: 0.74, green: 0.53, blue: 0.36),
        Color(red: 0.57, green: 0.38, blue: 0.25), Color(red: 0.40, green: 0.26, blue: 0.17),
    ]
    static let shirts: [Color] = [
        Color(red: 0.26, green: 0.52, blue: 0.92), Color(red: 0.78, green: 0.42, blue: 0.86),
        Color(red: 0.90, green: 0.28, blue: 0.30), Color(red: 0.25, green: 0.70, blue: 0.40),
        Color(red: 0.98, green: 0.58, blue: 0.18), Color(red: 0.98, green: 0.82, blue: 0.20),
        Color(red: 0.98, green: 0.52, blue: 0.70), Color(red: 0.15, green: 0.70, blue: 0.72),
    ]
    /// Picture printed on the T-shirt; nil = plain.
    static let patterns: [String?] = ["star.fill", "heart.fill", "bolt.fill", "moon.fill", "pawprint.fill", nil]
    /// Cap colours; index 0 = no cap.
    static let caps: [Color?] = [nil, .red, Color(red: 0.2, green: 0.4, blue: 0.9), .green, Color(white: 0.15), .orange, .purple]
    static let hairStyles = ["Classic", "Spiky", "Curly", "Long", "Ponytail", "Buzz cut", "Bob", "Mohawk"]
    /// Extra colours unlocked in the secret room of Side Level 1.
    static let extraShirts: [Color] = [
        Color(white: 0.15), .white, Color(red: 0.55, green: 0.95, blue: 0.45), Color(red: 0.45, green: 0.30, blue: 0.85),
        Color(red: 0.60, green: 0.38, blue: 0.20), Color(red: 0.55, green: 0.85, blue: 1.0),
    ]
    static let extraCaps: [Color?] = [.white, .pink, .cyan, Palette.gold]
    static let allShirts = shirts + extraShirts
    static let allCaps = caps + extraCaps
}

/// Things to wear that turn up in boxes: the first 10, plus 50 more in different shapes and colours.
/// Wear one at a time from Customize Character.
struct Accessory: Hashable, Identifiable {
    enum Family: String {
        case glasses, crown, bowTie, scarf, cape, headband, catEars, headphones, halo, partyHat
        case beanie, topHat, hairBow, flower
    }

    let id: String
    let family: Family
    let name: String
    let color: Color

    static func == (a: Accessory, b: Accessory) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var symbol: String {
        switch family {
        case .glasses: "sunglasses.fill"
        case .crown: "crown.fill"
        case .bowTie: "gift.fill"
        case .scarf: "wind"
        case .cape: "bolt.shield.fill"
        case .headband: "figure.martial.arts"
        case .catEars: "cat.fill"
        case .headphones: "headphones"
        case .halo: "sparkles"
        case .partyHat: "party.popper.fill"
        case .beanie: "snowflake"
        case .topHat: "hat.widebrim.fill"
        case .hairBow: "bandage.fill"
        case .flower: "leaf.fill"
        }
    }

    private static let shades: [(String, Color)] = [
        ("Red", .red), ("Blue", Color(red: 0.2, green: 0.45, blue: 0.95)), ("Green", Color(red: 0.2, green: 0.7, blue: 0.35)),
        ("Purple", .purple), ("Pink", Color(red: 1, green: 0.5, blue: 0.7)), ("Yellow", Color(red: 1, green: 0.82, blue: 0.2)),
        ("Black", Color(white: 0.15)), ("Gold", Palette.gold), ("Orange", .orange), ("Teal", .teal),
    ]

    private static func variants(_ family: Family, _ label: String, _ picks: [Int]) -> [Accessory] {
        picks.map { i in
            Accessory(id: "\(family.rawValue)-\(shades[i].0.lowercased())", family: family, name: "\(shades[i].0) \(label)", color: shades[i].1)
        }
    }

    static let all: [Accessory] = [
        // The original 10
        Accessory(id: "sunglasses", family: .glasses, name: "Sunglasses", color: .black),
        Accessory(id: "crown", family: .crown, name: "Crown", color: Palette.gold),
        Accessory(id: "bowTie", family: .bowTie, name: "Bow Tie", color: .red),
        Accessory(id: "scarf", family: .scarf, name: "Scarf", color: .orange),
        Accessory(id: "cape", family: .cape, name: "Hero Cape", color: .red),
        Accessory(id: "headband", family: .headband, name: "Ninja Headband", color: .red),
        Accessory(id: "catEars", family: .catEars, name: "Cat Ears", color: Color(white: 0.25)),
        Accessory(id: "headphones", family: .headphones, name: "Headphones", color: .cyan),
        Accessory(id: "halo", family: .halo, name: "Halo", color: .yellow),
        Accessory(id: "partyHat", family: .partyHat, name: "Party Hat", color: .pink),
    ]
    // 50 more: 10 kinds × 5 colours
    + variants(.glasses, "Glasses", [0, 1, 2, 4, 7])
    + variants(.bowTie, "Bow Tie", [1, 2, 3, 5, 6])
    + variants(.scarf, "Scarf", [0, 1, 2, 3, 4])
    + variants(.cape, "Cape", [1, 2, 3, 6, 7])
    + variants(.headband, "Headband", [1, 2, 6, 4, 5])
    + variants(.partyHat, "Party Hat", [0, 1, 2, 8, 9])
    + variants(.beanie, "Beanie", [0, 1, 2, 3, 8])
    + variants(.topHat, "Top Hat", [6, 0, 1, 3, 7])
    + variants(.hairBow, "Hair Bow", [0, 4, 1, 5, 9])
    + variants(.flower, "Flower", [4, 5, 0, 3, 8])

    /// Only sold in the dungeon's orb shop, and only in the demo. They don't count toward "every accessory".
    static let exclusives: [Accessory] = [
        Accessory(id: "demo-crown", family: .crown, name: "Demo Crystal Crown", color: .cyan),
        Accessory(id: "demo-halo", family: .halo, name: "Demo Orb Halo", color: Color(red: 0.75, green: 0.45, blue: 1)),
        Accessory(id: "demo-cape", family: .cape, name: "Demo Miner's Cape", color: .teal),
        Accessory(id: "demo-ears", family: .catEars, name: "Demo Ghost Ears", color: .white),
        Accessory(id: "demo-headphones", family: .headphones, name: "Demo Golden Headphones", color: Palette.gold),
        Accessory(id: "demo-tophat", family: .topHat, name: "Demo Dungeon Top Hat", color: Color(red: 0.35, green: 0.2, blue: 0.6)),
    ]

    static func find(_ id: String) -> Accessory? { (all + exclusives).first { $0.id == id } }
}

/// Rare accessories with powers. You can wear all of them at once and their boosts stack.
enum SideReward {
    case boost(Boost), colors, nothing
}

enum Boost: String, CaseIterable, Identifiable {
    case coolCap, leaf, lightningBall, windCrown, goldenCrown, arrow, cloud
    /// The Guide's own hat. It never turns up in the game: it's only given to devices listed in `GuidesHat.devices`.
    case guidesHat

    var id: String { rawValue }

    /// Every boost you can actually find (boxes, rats, the roof, the secret room). The Guide's Hat isn't one.
    static let findable: [Boost] = allCases.filter { $0 != .guidesHat }
    var name: String {
        switch self {
        case .coolCap: "Cool Cap with a Can"
        case .leaf: "Leaf"
        case .lightningBall: "Lightning Ball"
        case .windCrown: "Wind Crown"
        case .goldenCrown: "Golden Crown"
        case .arrow: "Arrow"
        case .cloud: "Cloud"
        case .guidesHat: "The Guide's Hat"
        }
    }
    var about: String {
        switch self {
        case .coolCap: "Speed ×1.5"
        case .leaf: "Jump ×1.3 higher"
        case .lightningBall: "Press F: speed, dash and jump ×3.5 for 25 seconds, and you're quieter. 1 minute cooldown."
        case .windCrown: "Speed ×1.2 and dash ×2.5"
        case .goldenCrown: "Everything ×1.2, and you're quieter"
        case .arrow: "Dash ×1.9 and walking speed ×1.2"
        case .cloud: "Press X: fly for 10 seconds, over obstacles and hedges. 30 second cooldown."
        case .guidesHat: "Press H: switch it on or off. While it's on, everything is ×10.5 and you walk through things."
        }
    }
    var symbol: String {
        switch self {
        case .coolCap: "cup.and.saucer.fill"
        case .leaf: "leaf.fill"
        case .lightningBall: "bolt.circle.fill"
        case .windCrown: "wind"
        case .goldenCrown: "crown.fill"
        case .arrow: "arrow.right"
        case .cloud: "cloud.fill"
        case .guidesHat: "hat.widebrim.fill"
        }
    }
    var color: Color {
        switch self {
        case .coolCap: .red
        case .leaf: .green
        case .lightningBall: .yellow
        case .windCrown: .cyan
        case .goldenCrown: Palette.gold
        case .arrow: .orange
        case .cloud: Color(red: 0.8, green: 0.92, blue: 1)
        case .guidesHat: GuidesHat.color
        }
    }

    /// Where it came from and how it was made or found.
    var origin: String {
        switch self {
        case .coolCap: "Dad won it at a school fair before you were born, then lost it in a box. The can on top is glued there. Nobody admits to gluing it."
        case .leaf: "It fell from the oldest tree in the garden on a night with no wind at all, and it has never dried out."
        case .lightningBall: "A marble that was left on the roof during a thunderstorm. It has hummed ever since."
        case .windCrown: "Folded from a kite that got away. Whoever wears it always has the wind at their back."
        case .goldenCrown: "Grandpa made it from festival lantern foil, one year when the two of you got there early."
        case .arrow: "From an old toy archery set. The bow is long gone; the arrow still wants to fly forward."
        case .cloud: "A scrap of morning fog that got caught in the garden hedge and never left."
        case .guidesHat: "The Guide's own hat. Nobody knows who made it, and he only lends it to people he chooses himself."
        }
    }

    /// The ones that make you faster (for "the world revolving").
    static let speedBoosts: Set<Boost> = [.coolCap, .windCrown, .goldenCrown, .arrow]
}

/// The Guide's Hat can't be found, bought or won: the chance is exactly 0. A device only gets it
/// when its ID is added to `devices` below (ask for it to be given to a specific device).
/// The device ID is shown at the bottom of the Settings screen.
enum GuidesHat {
    /// Device IDs (Settings → Device ID) that own the hat. Empty: nobody has it.
    static let devices: Set<String> = [
        "26016453-DFAD-4642-AA44-45078B473DDC",   // the iPad Air ("iPad (8)"), given 2026-10-07
    ]

    /// Everything is multiplied by this while the hat is switched on.
    static let power = 10.5
    static let color = Color(red: 0.45, green: 0.25, blue: 0.75)

    /// This device's ID (the same for every save file on it).
    static var deviceID: String { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
    static var grantedHere: Bool { devices.contains(deviceID) }
}

/// Things the dungeon's orb shop can upgrade. Each has 10 steps.
enum Stat: String, CaseIterable, Identifiable {
    case speed, jump, dash, quiet, health

    var id: String { rawValue }
    static let maxLevel = 10

    var name: String {
        switch self {
        case .speed: "Speed"
        case .jump: "Jump"
        case .dash: "Dash"
        case .quiet: "Quiet steps"
        case .health: "Health"
        }
    }
    var symbol: String {
        switch self {
        case .speed: "hare.fill"
        case .jump: "arrow.up.circle.fill"
        case .dash: "wind"
        case .quiet: "speaker.slash.fill"
        case .health: "heart.fill"
        }
    }
    /// The multiplier (or extra HP for health) at a level. Speed tops out at ×5.7.
    func value(at level: Int) -> Double {
        let l = Double(min(max(level, 0), Self.maxLevel))
        switch self {
        case .speed: return 1 + 0.47 * l
        case .jump: return 1 + 0.10 * l
        case .dash: return 1 + 0.20 * l
        case .quiet: return 1 + 0.20 * l
        case .health: return 20 * l
        }
    }
    func label(at level: Int) -> String {
        self == .health ? "+\(Int(value(at: level))) HP" : String(format: "×%.1f", value(at: level))
    }
    /// Orbs for the next step.
    func cost(from level: Int) -> Int { 8 + level * 6 }
}

enum Badge: String, CaseIterable, Identifiable {
    case oopsies, amNotPm, patienceIsKey, hiDad, curiosity, trolledMom, boredom, deadlySqueak, luckyGuess, ninja
    case fly, passcode, owl
    case funnySon, oldHouse, fireMusic, goAwayMom, goldenStick, southPark, tooHard, friendlyRoute, crashout
    case level1, level2, level3, level4, power, aprilFool, pumpkins, jolly, joinedDemo, shh, coolCap
    case multiplayer, trolledAgain, retry, numberOne
    case justInCase, unstoppable
    case worldRevolving

    var id: String { rawValue }

    /// Not possible until a later update. These show up named "soon".
    var isSoon: Bool { self == .aprilFool || self == .jolly }

    var name: String {
        if isSoon { return "soon" }
        switch self {
        case .oopsies: return "Oopsies!"
        case .amNotPm: return "is it PM? Nope AM"
        case .patienceIsKey: return "patience is key"
        case .hiDad: return "hi dad!"
        case .curiosity: return "curiosity"
        case .trolledMom: return "Get trolled mom!"
        case .boredom: return "boredom"
        case .deadlySqueak: return "deadly squeak"
        case .luckyGuess: return "lucky guess"
        case .ninja: return "im now a ninja"
        case .fly: return "i believe i can fly!!"
        case .passcode: return "Mom whats the passcode again?"
        case .owl: return "did you see that"
        case .funnySon: return "Thats funny son"
        case .oldHouse: return "How old is this house?"
        case .fireMusic: return "Fire Music!"
        case .goAwayMom: return "Go away mom!"
        case .goldenStick: return "????"
        case .southPark: return "South park"
        case .tooHard: return "This game is too hard!"
        case .friendlyRoute: return "Friendly Route"
        case .crashout: return "Crashout"
        case .level1: return "Level 1"
        case .level2: return "Level 2"
        case .level3: return "Level 3"
        case .level4: return "Level 4"
        case .power: return "I FEEL DA POWERRRR!!!"
        case .aprilFool: return "Ur a fool"
        case .pumpkins: return "Scary pumpkins"
        case .jolly: return "A jolly day"
        case .joinedDemo: return "Joined Demo!!!!!?!?"
        case .shh: return "Shh Mom/Dad is here!"
        case .coolCap: return "check out my cool cap!"
        case .multiplayer: return "multiplayer"
        case .trolledAgain: return "Trolled again!"
        case .retry: return "Retry"
        case .numberOne: return "number 1# player!"
        case .justInCase: return "Just in case"
        case .unstoppable: return "Im unstoppable!"
        case .worldRevolving: return "the world revolving"
        }
    }

    var how: String {
        if isSoon { return "Coming in a later update." }
        switch self {
        case .oopsies: return "Get caught."
        case .amNotPm: return "Let the time run out."
        case .patienceIsKey: return "Find a key."
        case .hiDad: return "Get caught by Dad instead of Mom."
        case .curiosity: return "Look out of the hallway window 3 times."
        case .trolledMom: return "When time runs out and Mom comes looking, taunt right in front of her."
        case .boredom: return "Stay on the menu for 10 minutes."
        case .deadlySqueak: return "Get caught by stepping on a toy."
        case .luckyGuess: return "Guess the door code without the paper."
        case .ninja: return "Learn a new skill."
        case .fly: return "Go up to the rooftop with a ladder."
        case .passcode: return "Get the passcode on Mom's phone wrong 5 times."
        case .owl: return "Find the owl on the rooftop."
        case .funnySon: return "Taunt in front of Dad."
        case .oldHouse: return "Step on a loose plank."
        case .fireMusic: return "Open the Music app on Mom's phone."
        case .goAwayMom: return "Let Mom find you while your brother is following you."
        case .goldenStick: return "Find the VERY rare golden stick on the rooftop."
        case .southPark: return "Name yourself a cuss word."
        case .tooHard: return "Get caught 10 times."
        case .friendlyRoute: return "Give Mom, your brother and Dad a toy."
        case .crashout: return "Taunt your brother 5 times."
        case .level1: return "Complete Level 1."
        case .level2: return "Complete Level 2."
        case .level3: return "Complete Level 3."
        case .level4: return "Complete Level 4."
        case .power: return "Collect 10 star balls on the rooftop."
        case .aprilFool: return "Coming in a later update."
        case .pumpkins: return "Play the game on Halloween."
        case .jolly: return "Coming in a later update."
        case .joinedDemo: return "Play the demo (until Level 10 is done)."
        case .shh: return "Hide from Mom or Dad."
        case .coolCap: return "Get an accessory from a box."
        case .multiplayer: return "Play a level in multiplayer mode."
        case .trolledAgain: return "Taunt Mom while she's stunned."
        case .retry: return "Retry 20 times."
        case .numberOne: return "Finish every level, every accessory and every badge."
        case .justInCase: return "Make 10 save files."
        case .unstoppable: return "Own every boosting accessory and every permanent item."
        case .worldRevolving: return "Sprint with star ball power while wearing every speed-boosting accessory."
        }
    }

    var symbol: String {
        switch self {
        case .oopsies: "exclamationmark.triangle.fill"
        case .amNotPm: "clock.fill"
        case .patienceIsKey: "key.fill"
        case .hiDad: "eyeglasses"
        case .curiosity: "binoculars.fill"
        case .trolledMom: "face.smiling.inverse"
        case .boredom: "zzz"
        case .deadlySqueak: "teddybear.fill"
        case .luckyGuess: "dice.fill"
        case .ninja: "figure.martial.arts"
        case .fly: "paperplane.fill"
        case .passcode: "lock.iphone"
        case .owl: "bird.fill"
        case .funnySon: "mustache.fill"
        case .oldHouse: "house.fill"
        case .fireMusic: "music.note"
        case .goAwayMom: "hand.raised.fill"
        case .goldenStick: "questionmark"
        case .southPark: "text.bubble.fill"
        case .tooHard: "flame.fill"
        case .friendlyRoute: "heart.fill"
        case .crashout: "bolt.fill"
        case .level1: "1.circle.fill"
        case .level2: "2.circle.fill"
        case .level3: "3.circle.fill"
        case .level4: "4.circle.fill"
        case .power: "star.circle.fill"
        case .aprilFool, .jolly: "hourglass"
        case .multiplayer: "person.2.fill"
        case .pumpkins: "moon.haze.fill"
        case .joinedDemo: "gamecontroller.fill"
        case .shh: "eye.slash.fill"
        case .coolCap: "gift.fill"
        case .trolledAgain: "sparkles"
        case .retry: "arrow.counterclockwise"
        case .numberOne: "trophy.fill"
        case .justInCase: "folder.fill"
        case .unstoppable: "bolt.shield.fill"
        case .worldRevolving: "globe.americas.fill"
        }
    }

    var color: Color {
        let palette: [Color] = [.red, .indigo, Palette.gold, .blue, .teal, .pink, .gray, .orange, .green, .purple, .cyan, .mint, .brown]
        guard !isSoon else { return .gray }
        return palette[(Badge.allCases.firstIndex(of: self) ?? 0) % palette.count]
    }
}

/// Moves learned from skill papers. Once learned they work in every level.
enum Skill: String, CaseIterable {
    case dash, run

    var title: String { self == .dash ? "DASH" : "RUN" }
    var how: String {
        switch self {
        case .dash: "Press Q (or the wind button) to zoom forward!"
        case .run: "Hold Shift (or turn on the running button) to run fast. Running is noisy, so be careful!"
        }
    }
}

/// Something found while searching: a rare boost (1 in 15) or an ordinary accessory (1 in 5).
enum Loot {
    case accessory(Accessory)
    case boost(Boost)
    /// The bat: a permanent item that stuns Mom for 2 seconds.
    case bat
}

/// The player's character and everything they've earned, saved on the iPad between launches.
@Observable
final class GameState {
    var playerName: String { didSet { save() } }
    var look: Look { didSet { save() } }
    var hasCharacter: Bool { didSet { save() } }
    var completedLevels: Set<Int> { didSet { save() } }
    var skills: Set<Skill> { didSet { save() } }
    var badges: Set<Badge> { didSet { save() } }
    var accessories: Set<Accessory> { didSet { save() } }
    var boosts: Set<Boost> { didSet { save() } }
    /// Permanent items: vines stun a grown-up for 10 seconds; the toy stuns Mom for a minute.
    var hasVines: Bool { didSet { save(); if hasVines { checkUnstoppableSoon() } } }
    var hasToy: Bool { didSet { save(); if hasToy { checkUnstoppableSoon() } } }
    var hasBat: Bool { didSet { save() } }
    /// More T-shirt and cap colours, from Side Level 1's secret room.
    var extraColors: Bool { didSet { save() } }
    var completedSide: Set<Int> { didSet { save() } }
    /// Dungeon money, and how many orbs you've ever mined (for the dungeon quest).
    var orbs: Int { didSet { save() } }
    var orbsMined: Int { didSet { save() } }
    /// Orb-shop upgrades: how many steps of each stat you've bought.
    var upgrades: [Stat: Int] { didSet { save() } }
    /// Creative mode switched on (only works once it's unlocked).
    var creativeOn: Bool { didSet { save() } }
    /// Two players on this iPad. Not saved: it's off again next launch.
    var multiplayer = false
    var caughtCount: Int { didSet { save() } }
    var retryCount: Int { didSet { save() } }
    /// Who has been given a toy: "mom", "brother", "dad".
    var gifts: Set<String> { didSet { save() } }
    /// The badge to announce on screen right now.
    var badgeToast: Badge?

    var gender: Gender { look.gender }

    private let defaults = UserDefaults.standard

    /// Which save file this is. File 0 is the original save.
    let slot: Int
    private let prefix: String

    init(slot: Int = GameState.currentSlot) {
        let p = slot == 0 ? "" : "slot\(slot)."
        self.slot = slot
        prefix = p
        playerName = defaults.string(forKey: p + "playerName") ?? ""
        let gender = Gender(rawValue: defaults.string(forKey: p + "gender") ?? "") ?? .boy
        var look = Look.starter(gender)
        if defaults.object(forKey: p + "shirt") != nil {
            look.skin = defaults.integer(forKey: p + "skin")
            look.shirt = defaults.integer(forKey: p + "shirt")
            look.pattern = defaults.integer(forKey: p + "pattern")
            look.cap = defaults.integer(forKey: p + "cap")
            look.hair = defaults.integer(forKey: p + "hair")
            look.accessory = Accessory.find(defaults.string(forKey: p + "accessory") ?? "")
            look.boosts = Set((defaults.stringArray(forKey: p + "wornBoosts") ?? []).compactMap(Boost.init(rawValue:)))
            look.hiddenBoosts = Set((defaults.stringArray(forKey: p + "hiddenBoosts") ?? []).compactMap(Boost.init(rawValue:)))
        }
        self.look = look
        hasCharacter = defaults.bool(forKey: p + "hasCharacter")
        let won = Set(defaults.array(forKey: p + "completedLevels") as? [Int] ?? [])
        let learned = Set((defaults.stringArray(forKey: p + "skills") ?? []).compactMap(Skill.init(rawValue:)))
        let owned = Set((defaults.stringArray(forKey: p + "accessories") ?? []).compactMap(Accessory.find))
        completedLevels = won
        skills = learned
        accessories = owned
        boosts = Set((defaults.stringArray(forKey: p + "boosts") ?? []).compactMap(Boost.init(rawValue:)))
        hasVines = defaults.bool(forKey: p + "hasVines")
        hasToy = defaults.bool(forKey: p + "hasToy")
        hasBat = defaults.bool(forKey: p + "hasBat")
        extraColors = defaults.bool(forKey: p + "extraColors")
        completedSide = Set(defaults.array(forKey: p + "completedSide") as? [Int] ?? [])
        orbs = defaults.integer(forKey: p + "orbs")
        orbsMined = defaults.integer(forKey: p + "orbsMined")
        var bought: [Stat: Int] = [:]
        for (key, value) in defaults.dictionary(forKey: p + "upgrades") as? [String: Int] ?? [:] {
            if let stat = Stat(rawValue: key) { bought[stat] = value }
        }
        upgrades = bought
        creativeOn = defaults.bool(forKey: p + "creativeOn")
        caughtCount = defaults.integer(forKey: p + "caughtCount")
        retryCount = defaults.integer(forKey: p + "retryCount")
        gifts = Set(defaults.stringArray(forKey: p + "gifts") ?? [])
        var earned = Set((defaults.stringArray(forKey: p + "badges") ?? []).compactMap(Badge.init(rawValue:)))
        // Things done before a badge existed still count, where the save file shows them.
        if !won.isEmpty { earned.insert(.patienceIsKey) }
        if !learned.isEmpty { earned.insert(.ninja) }
        if !owned.isEmpty { earned.insert(.coolCap) }
        for (level, badge) in [(1, Badge.level1), (2, .level2), (3, .level3), (4, .level4)] where won.contains(level) {
            earned.insert(badge)
        }
        if earned.contains(.fly) || earned.contains(.owl) { earned.insert(.fly) }
        badges = earned
        // The Guide's Hat only exists on devices it was given to.
        if GuidesHat.grantedHere {
            boosts.insert(.guidesHat)
        } else {
            boosts.remove(.guidesHat)
            self.look.boosts.remove(.guidesHat)
        }
    }

    func award(_ badge: Badge) {
        guard !badge.isSoon, !badges.contains(badge) else { return }
        badges.insert(badge)
        badgeToast = badge
        Sound.magic.play()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            if badgeToast == badge { badgeToast = nil }
        }
        checkNumberOne()
    }

    /// Badges for simply opening the game: the demo badge, and Halloween on October 31.
    func awardLaunchBadges() {
        award(.joinedDemo)
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        if today.month == 10 && today.day == 31 { award(.pumpkins) }
    }

    func noteCaught() {
        caughtCount += 1
        award(.oopsies)
        if caughtCount >= 10 { award(.tooHard) }
    }

    func noteRetry() {
        retryCount += 1
        if retryCount >= 20 { award(.retry) }
    }

    func give(toyTo who: String) {
        gifts.insert(who)
        if gifts.isSuperset(of: ["mom", "brother", "dad"]) { award(.friendlyRoute) }
    }

    private static let cussWords = ["damn", "hell", "crap", "ass", "butt", "poop", "fart", "shit", "fuck", "bitch", "piss", "dick", "bastard"]

    /// The "South park" badge: your name is (or contains) a rude word.
    func checkName() {
        let name = playerName.lowercased()
        if Self.cussWords.contains(where: { name.contains($0) }) { award(.southPark) }
    }

    /// Every level, every accessory and every other badge. Not possible until all 10 levels exist.
    private func checkNumberOne() {
        let others = Badge.allCases.filter { $0 != .numberOne }
        if completedLevels.count >= 10 && regularAccessories == Accessory.all.count && badges.isSuperset(of: others) {
            award(.numberOne)
        }
    }

    /// What a box or drawer gives when it has nothing special: usually nothing,
    /// 1 time in 15 a boost you don't have, otherwise 1 time in 5 a new accessory.
    func rollLoot(boostOdds: Int = 15) -> Loot? {
        if !hasBat && Int.random(in: 0..<12) == 0 { return .bat }
        if Int.random(in: 0..<boostOdds) == 0, let boost = Boost.findable.filter({ !boosts.contains($0) }).randomElement() {
            return .boost(boost)
        }
        if Int.random(in: 0..<5) == 0, let item = Accessory.all.filter({ !accessories.contains($0) }).randomElement() {
            return .accessory(item)
        }
        return nil
    }

    /// A random boost you don't own yet (the roof hands these out), or nil when you have them all.
    func newBoost() -> Boost? {
        Boost.findable.filter { !boosts.contains($0) }.randomElement()
    }

    func take(_ loot: Loot) {
        switch loot {
        case .accessory(let item):
            accessories.insert(item)
            award(.coolCap)
        case .boost(let boost):
            boosts.insert(boost)
            look.boosts.insert(boost)
        case .bat:
            hasBat = true
        }
        checkUnstoppable()
    }

    private func checkUnstoppableSoon() {
        Task { @MainActor in checkUnstoppable() }
    }

    /// "Im unstoppable!": every boost, plus the vines, the toy and the bat.
    func checkUnstoppable() {
        if boosts.isSuperset(of: Boost.findable) && hasVines && hasToy && hasBat { award(.unstoppable) }
    }

    /// Side Level 1 opens with 3 accessories, 20 badges and Level 3 won.
    var sideLevelRequirements: [(text: String, met: Bool)] {
        [("Have 3 accessories (\(min(accessories.count, 3))/3)", accessories.count >= 3),
         ("Earn 20 badges (\(min(badges.count, 20))/20)", badges.count >= 20),
         ("Win Level 3", completedLevels.contains(3))]
    }

    var sideLevelUnlocked: Bool { sideLevelRequirements.allSatisfy(\.met) }

    /// Side Level 1's treasure chest: a boost you don't have yet, or the extra colours.
    func claimSideReward() -> SideReward {
        completedSide.insert(1)
        var choices: [SideReward] = []
        if let boost = Boost.findable.filter({ !boosts.contains($0) }).randomElement() { choices.append(.boost(boost)) }
        if !extraColors { choices.append(.colors) }
        let prize = choices.randomElement() ?? .nothing
        switch prize {
        case .boost(let boost): take(.boost(boost))
        case .colors: extraColors = true
        case .nothing: break
        }
        return prize
    }

    /// Accessories from boxes (the dungeon's demo exclusives are counted separately).
    var regularAccessories: Int { accessories.subtracting(Accessory.exclusives).count }

    // MARK: Unlocks

    /// Every level that exists so far is won.
    var allLevelsWon: Bool { Levels.all.filter(\.isReady).allSatisfy { completedLevels.contains($0.id) } }
    static let sideLevelCount = 2
    var allSidesDone: Bool { (1...Self.sideLevelCount).allSatisfy { completedSide.contains($0) } }

    /// Side Level 2 (the dungeon): Level 5, the first side level, and the Friendly Route badge.
    var dungeonRequirements: [(text: String, met: Bool)] {
        [("Win Level 5", completedLevels.contains(5)),
         ("Finish Side Level 1", completedSide.contains(1)),
         ("Earn the \"Friendly Route\" badge", badges.contains(.friendlyRoute))]
    }
    var dungeonUnlocked: Bool { dungeonRequirements.allSatisfy(\.met) }

    /// Side Level 3 (Uncle's car): every level won and 30 badges. It isn't needed for the Lore or creative mode.
    var carRequirements: [(text: String, met: Bool)] {
        [("Win every level", allLevelsWon),
         ("Earn 30 badges (\(min(badges.count, 30))/30)", badges.count >= 30)]
    }
    var carUnlocked: Bool { carRequirements.allSatisfy(\.met) }

    private func endgame(badges count: Int) -> [(text: String, met: Bool)] {
        [("Win every level", allLevelsWon),
         ("Finish every side level", allSidesDone),
         ("Earn \(count) badges (\(min(badges.count, count))/\(count))", badges.count >= count)]
    }
    var loreRequirements: [(text: String, met: Bool)] { endgame(badges: 30) }
    var loreUnlocked: Bool { loreRequirements.allSatisfy(\.met) }
    var creativeRequirements: [(text: String, met: Bool)] { endgame(badges: 33) }
    var creativeUnlocked: Bool { creativeRequirements.allSatisfy(\.met) }
    /// Creative mode is unlocked and switched on.
    var creativeActive: Bool { creativeOn && creativeUnlocked }

    /// What the worn boosts and the orb-shop upgrades add to your health (Level 5 on).
    var maxHP: Double { 100 + 45 * Double(look.boosts.count) + Stat.health.value(at: upgrades[.health] ?? 0) }

    /// Buys the next step of a stat with orbs. Returns false if you can't afford it or it's maxed.
    func buyUpgrade(_ stat: Stat) -> Bool {
        let level = upgrades[stat] ?? 0
        guard level < Stat.maxLevel, orbs >= stat.cost(from: level) else { return false }
        orbs -= stat.cost(from: level)
        upgrades[stat] = level + 1
        return true
    }

    func note(saveFiles count: Int) {
        if count >= 10 { award(.justInCase) }
    }

    /// You can only play a level once you've won the one before it.
    func isUnlocked(_ level: LevelInfo) -> Bool {
        level.isReady && (level.id == 1 || completedLevels.contains(level.id - 1))
    }

    /// The level "Play" starts: the first one you haven't won yet. Nil when every finished level is won.
    var nextLevel: Int? {
        Levels.all.first { $0.isReady && !completedLevels.contains($0.id) && isUnlocked($0) }?.id
    }

    func complete(level: Int) {
        completedLevels.insert(level)
        if let badge = [1: Badge.level1, 2: .level2, 3: .level3, 4: .level4][level] { award(badge) }
    }

    func learn(_ skill: Skill) {
        skills.insert(skill)
        award(.ninja)
    }

    private func save() {
        let p = prefix
        defaults.set(playerName, forKey: p + "playerName")
        defaults.set(look.gender.rawValue, forKey: p + "gender")
        defaults.set(look.skin, forKey: p + "skin")
        defaults.set(look.shirt, forKey: p + "shirt")
        defaults.set(look.pattern, forKey: p + "pattern")
        defaults.set(look.cap, forKey: p + "cap")
        defaults.set(look.hair, forKey: p + "hair")
        defaults.set(look.accessory?.id, forKey: p + "accessory")
        defaults.set(look.boosts.map(\.rawValue), forKey: p + "wornBoosts")
        defaults.set(look.hiddenBoosts.map(\.rawValue), forKey: p + "hiddenBoosts")
        defaults.set(hasCharacter, forKey: p + "hasCharacter")
        defaults.set(Array(completedLevels), forKey: p + "completedLevels")
        defaults.set(skills.map(\.rawValue), forKey: p + "skills")
        defaults.set(accessories.map(\.id), forKey: p + "accessories")
        defaults.set(boosts.map(\.rawValue), forKey: p + "boosts")
        defaults.set(badges.map(\.rawValue), forKey: p + "badges")
        defaults.set(hasVines, forKey: p + "hasVines")
        defaults.set(hasToy, forKey: p + "hasToy")
        defaults.set(hasBat, forKey: p + "hasBat")
        defaults.set(extraColors, forKey: p + "extraColors")
        defaults.set(Array(completedSide), forKey: p + "completedSide")
        defaults.set(orbs, forKey: p + "orbs")
        defaults.set(orbsMined, forKey: p + "orbsMined")
        defaults.set(Dictionary(uniqueKeysWithValues: upgrades.map { ($0.key.rawValue, $0.value) }), forKey: p + "upgrades")
        defaults.set(creativeOn, forKey: p + "creativeOn")
        defaults.set(caughtCount, forKey: p + "caughtCount")
        defaults.set(retryCount, forKey: p + "retryCount")
        defaults.set(Array(gifts), forKey: p + "gifts")
    }

    // MARK: Save files

    /// Every save file that exists, oldest first. There's no limit.
    static var slots: [Int] {
        UserDefaults.standard.array(forKey: "saveSlots") as? [Int] ?? [0]
    }

    /// The file that was being played last.
    static var currentSlot: Int {
        get { UserDefaults.standard.integer(forKey: "currentSlot") }
        set { UserDefaults.standard.set(newValue, forKey: "currentSlot") }
    }

    /// Makes a brand-new, empty save file and returns its number.
    static func newSlot() -> Int {
        let all = slots
        let id = (all.max() ?? 0) + 1
        UserDefaults.standard.set(all + [id], forKey: "saveSlots")
        return id
    }

    /// What to show for a file in the list, without loading it.
    static func summary(of slot: Int) -> (name: String, levels: Int, badges: Int) {
        let p = slot == 0 ? "" : "slot\(slot)."
        let d = UserDefaults.standard
        return (d.string(forKey: p + "playerName") ?? "", (d.array(forKey: p + "completedLevels") ?? []).count,
                (d.stringArray(forKey: p + "badges") ?? []).count)
    }
}

struct LevelInfo: Identifiable {
    let id: Int
    let room: String
    let symbol: String
    /// Seconds on the clock for this level.
    let seconds: Double
    /// Levels without a room yet show as "Coming soon".
    let isReady: Bool
}

enum Levels {
    static let seconds: [Double] = [100, 150, 200, 250, 350, 400, 450, 500, 550, 600]

    static let all: [LevelInfo] = (1...10).map { id in
        switch id {
        case 1: LevelInfo(id: 1, room: "Bedroom", symbol: "bed.double.fill", seconds: seconds[0], isReady: true)
        case 2: LevelInfo(id: 2, room: "Hallway", symbol: "door.left.hand.open", seconds: seconds[1], isReady: true)
        case 3: LevelInfo(id: 3, room: "Downstairs", symbol: "stairs", seconds: seconds[2], isReady: true)
        case 4: LevelInfo(id: 4, room: "Garden", symbol: "leaf.fill", seconds: seconds[3], isReady: true)
        case 5: LevelInfo(id: 5, room: "Street", symbol: "road.lanes", seconds: seconds[4], isReady: true)
        default: LevelInfo(id: id, room: "Coming soon", symbol: "lock.fill", seconds: seconds[id - 1], isReady: false)
        }
    }
}
