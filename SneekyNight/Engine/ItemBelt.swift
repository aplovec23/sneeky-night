import SwiftUI
import Observation

/// Permanent items you can use during a level, and the boosts from the accessories you're wearing.
/// Each level owns one belt; the level decides who gets stunned.
@MainActor
@Observable
final class ItemBelt {
    enum Item: Int, CaseIterable {
        case vines, lightning, toy, bat, cloud, hat, hose, stick, phone

        /// The letter on the button, from the one list of keys in `GameKey`.
        var key: String { GameKey.items[rawValue].label }
        var symbol: String { ["leaf.arrow.triangle.circlepath", "bolt.fill", "teddybear.fill", "figure.baseball", "cloud.fill", "hat.widebrim.fill", "drop.fill", "wand.and.stars", "iphone"][rawValue] }
        var color: Color { [Color.green, .yellow, .pink, .orange, Color(red: 0.45, green: 0.7, blue: 1), GuidesHat.color, Boost.waterHose.color, Palette.gold, Color(white: 0.55)][rawValue] }
    }

    var owned: Set<Item> = []
    /// Seconds before each item can be used again. They change every frame, so the buttons watch
    /// `waits` (whole seconds) instead, and only redraw once a second.
    @ObservationIgnored var cooldowns: [Item: Double] = [:] {
        didSet {
            let shown = cooldowns.compactMapValues { $0 > 0 ? Int($0.rounded(.up)) : nil }
            if shown != waits { waits = shown }
        }
    }
    var waits: [Item: Int] = [:]
    /// Seconds of lightning-ball power left (the button shows `lightningShown`).
    @ObservationIgnored var lightningLeft = 0.0 {
        didSet {
            let shown = Int(lightningLeft.rounded(.up))
            if shown != lightningShown { lightningShown = shown }
        }
    }
    var lightningShown = 0
    /// The Guide's Hat is switched on (H): everything ×10.5 and you walk through things.
    var hatOn = false
    /// The Phone is out (O): the level waits until you put it away.
    var phoneOpen = false
    /// Seconds before the bat swings again (Level 9 makes it quicker: there are robbers to bonk).
    @ObservationIgnored var batCooldown = 5.0

    /// Set by the level: stun whoever is around for this many seconds (second value: Mom only).
    /// Returns false when there's nobody to stun.
    @ObservationIgnored var stun: (Double, Bool) -> Bool = { _, _ in false }
    /// Set by a level that wants more from the golden stick than the usual (Level 3 clears every room).
    @ObservationIgnored var goldenStick: () -> Void = {}
    @ObservationIgnored private var boosts: Set<Boost> = []
    @ObservationIgnored private var upgrades: [Stat: Int] = [:]
    /// Item upgrades from the Upgrade Items skill (Level 9).
    @ObservationIgnored private var itemLevels: [UpgradeItem: Int] = [:]
    @ObservationIgnored private var maxHP = 100.0
    @ObservationIgnored private var award: (Badge) -> Void = { _ in }
    @ObservationIgnored private weak var engine: GameEngine?

    func configure(game: GameState, engine: GameEngine) {
        self.engine = engine
        boosts = game.look.boosts
        owned = []
        if game.hasVines { owned.insert(.vines) }
        if game.hasToy { owned.insert(.toy) }
        if game.hasBat { owned.insert(.bat) }
        if boosts.contains(.lightningBall) { owned.insert(.lightning) }
        if boosts.contains(.cloud) { owned.insert(.cloud) }
        if boosts.contains(.waterHose) { owned.insert(.hose) }
        if boosts.contains(.guidesHat) { owned.insert(.hat) }
        if game.hasGoldenStick { owned.insert(.stick) }
        if boosts.contains(.phone) { owned.insert(.phone) }
        hatOn = false
        phoneOpen = false
        upgrades = game.upgrades
        itemLevels = game.itemLevels
        engine.canDoubleJump = game.skills.contains(.doubleJump)
        engine.canSlide = game.skills.contains(.slide)
        maxHP = game.maxHP
        engine.maxHP = maxHP
        engine.hp = maxHP
        award = { [weak game] in game?.award($0) }
        apply()
    }

    func reset() {
        cooldowns = [:]
        engine?.grownUpsGone = false
        engine?.guideGone = false
        engine?.guideHP = 100
        lightningLeft = 0
        hatOn = false
        engine?.maxHP = maxHP
        engine?.hp = maxHP
        engine?.hurt = false
        apply()
    }

    func tick(_ dt: Double) {
        for (item, left) in cooldowns where left > 0 {
            cooldowns[item] = max(0, left - dt)
        }
        if lightningLeft > 0 {
            lightningLeft = max(0, lightningLeft - dt)
            if lightningLeft == 0 { apply() }
        }
        // "the world revolving": sprinting with star ball power and every speed boost on.
        if let engine, engine.sprinting, engine.speedBonus > 0, boosts.isSuperset(of: Boost.speedBoosts) {
            award(.worldRevolving)
        }
    }

    /// Upgraded defensive items stun for longer (+30% a level)...
    private func longer(_ seconds: Double, _ item: UpgradeItem) -> Double { seconds * (1 + 0.3 * Double(itemLevels[item] ?? 0)) }
    /// ...and are ready again sooner (−15% a level).
    private func sooner(_ seconds: Double, _ item: UpgradeItem) -> Double { seconds * (1 - 0.15 * Double(itemLevels[item] ?? 0)) }
    /// An upgraded boost: what it adds grows by half again each level.
    private func stronger(_ multiplier: CGFloat, _ item: UpgradeItem) -> CGFloat {
        1 + (multiplier - 1) * (1 + 0.5 * CGFloat(itemLevels[item] ?? 0))
    }

    func use(_ item: Item) {
        guard owned.contains(item), (cooldowns[item] ?? 0) <= 0, let engine else { return }
        switch item {
        case .phone:
            // Out comes the phone; everything waits.
            phoneOpen = true
            engine.paused = true
            Sound.click.play()
        case .vines:
            // Vines whip out and tangle up a grown-up: 10 seconds, usable every 35.
            if stun(longer(10, .vines), false) {
                cooldowns[.vines] = sooner(35, .vines)
                Sound.whip.play()
            } else {
                engine.say("There's nobody here to use the vines on.")
            }
        case .toy:
            // Your brother's reward toy: stuns Mom for a minute, usable every 50 seconds.
            if stun(longer(60, .toy), true) {
                cooldowns[.toy] = sooner(50, .toy)
                Sound.squeak.play()
            } else {
                engine.say("Mom isn't here to throw the toy at.")
            }
        case .bat:
            // A quick bonk: Mom sees stars for 2 seconds. Ready again after 5.
            if stun(longer(2, .bat), true) {
                cooldowns[.bat] = sooner(batCooldown, .bat)
                Sound.bonk.play()
            } else {
                engine.say("Mom isn't here to bonk.")
            }
        case .cloud:
            // Ten seconds in the air, then 30 to rest.
            guard engine.running, !engine.hidden else { return }
            let flight = 10 * Double(stronger(1.2, .cloud)) / 1.2
            engine.fly(flight)
            cooldowns[.cloud] = flight + 30
            Sound.magic.play()
            engine.say("Up, up and away!", seconds: 1.5)
        case .hat:
            // No cooldown: the Guide's Hat switches on and off whenever you like.
            hatOn.toggle()
            let full = engine.hp >= engine.maxHP
            let part = engine.hp / max(engine.maxHP, 1)
            engine.maxHP = maxHP * (hatOn ? GuidesHat.power : 1)
            engine.hp = full ? engine.maxHP : engine.maxHP * part
            Sound.magic.play()
            engine.say(hatOn ? "The Guide's Hat! I feel ×10.5 stronger!" : "Hat power off.", seconds: 1.5)
            apply()
        case .hose:
            // A blast of water in the face: whoever is chasing you can't see for 8 seconds. Ready again after 25.
            if stun(longer(8, .hose), false) {
                cooldowns[.hose] = sooner(25, .hose)
                Sound.water.play()
                engine.say("SPLASH! Can't see me now!", seconds: 1.5)
            } else {
                engine.say("There's nobody here to spray.")
            }
        case .stick:
            // The golden stick (from The Room): every obstacle in the room vanishes, and so do Mom,
            // Dad and everyone else who could catch you, for the rest of the try. Once per try.
            // Each level also removes its own extras (strangers, guards, pests...) in `goldenStick`.
            guard engine.running else { return }
            cooldowns[.stick] = 1_000_000
            engine.things.removeAll { $0.hazard != nil }
            engine.grownUpsGone = true
            goldenStick()
            Sound.magic.play()
            engine.say("THE GOLDEN STICK! Mom, Dad, everything in my way... gone.", seconds: 2.5)
        case .lightning:
            guard engine.running else { return }
            lightningLeft = 25
            cooldowns[.lightning] = 25 + 60
            Sound.powerup.play()
            engine.say("LIGHTNING POWER!", seconds: 1.5)
            apply()
        }
    }

    /// Works out the stacked multipliers and hands them to the engine.
    private func apply() {
        var speed: CGFloat = 1, jump: CGFloat = 1, dash = 1.0, quiet = 1.0
        let up = stronger
        if boosts.contains(.coolCap) { speed *= up(1.5, .coolCap) }
        if boosts.contains(.leaf) { jump *= up(1.3, .leaf) }
        if boosts.contains(.windCrown) { speed *= up(1.2, .windCrown); dash *= Double(up(2.5, .windCrown)) }
        if boosts.contains(.goldenCrown) {
            let g = up(1.2, .goldenCrown)
            speed *= g; jump *= g; dash *= Double(g); quiet *= Double(up(1.5, .goldenCrown))
        }
        if boosts.contains(.arrow) { speed *= up(1.2, .arrow); dash *= Double(up(1.9, .arrow)) }
        // The Sneaky Cape: every stat ×1.2 (more when upgraded), and no noise at all.
        if boosts.contains(.sneakyCape) {
            let c = up(1.2, .sneakyCape)
            speed *= c; jump *= c; dash *= Double(c)
        }
        engine?.silent = boosts.contains(.sneakyCape)
        if lightningLeft > 0 {
            let l = up(3.5, .lightningBall)
            speed *= l; jump *= l; dash *= Double(l); quiet *= 1.75
        }
        // Orb-shop upgrades from the dungeon.
        speed *= CGFloat(Stat.speed.value(at: upgrades[.speed] ?? 0))
        jump *= CGFloat(Stat.jump.value(at: upgrades[.jump] ?? 0))
        dash *= Stat.dash.value(at: upgrades[.dash] ?? 0)
        quiet *= Stat.quiet.value(at: upgrades[.quiet] ?? 0)
        if hatOn {
            speed *= CGFloat(GuidesHat.power)
            jump *= CGFloat(GuidesHat.power)
            dash *= GuidesHat.power
            quiet *= GuidesHat.power
        }
        engine?.phasing = hatOn
        engine?.speedMult = speed
        engine?.jumpMult = jump
        engine?.dashMult = dash
        engine?.noiseDiv = quiet
    }
}
