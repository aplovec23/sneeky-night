import SwiftUI
import Observation

/// Permanent items you can use during a level, and the boosts from the accessories you're wearing.
/// Each level owns one belt; the level decides who gets stunned.
@MainActor
@Observable
final class ItemBelt {
    enum Item: Int, CaseIterable {
        case vines, lightning, toy, bat, cloud, hat

        var key: String { ["V", "F", "G", "B", "X", "H"][rawValue] }
        var symbol: String { ["leaf.arrow.triangle.circlepath", "bolt.fill", "teddybear.fill", "figure.baseball", "cloud.fill", "hat.widebrim.fill"][rawValue] }
        var color: Color { [Color.green, .yellow, .pink, .orange, Color(red: 0.45, green: 0.7, blue: 1), GuidesHat.color][rawValue] }
    }

    var owned: Set<Item> = []
    var cooldowns: [Item: Double] = [:]
    /// Seconds of lightning-ball power left.
    var lightningLeft = 0.0
    /// The Guide's Hat is switched on (H): everything ×10.5 and you walk through things.
    var hatOn = false

    /// Set by the level: stun whoever is around for this many seconds (second value: Mom only).
    /// Returns false when there's nobody to stun.
    @ObservationIgnored var stun: (Double, Bool) -> Bool = { _, _ in false }
    @ObservationIgnored private var boosts: Set<Boost> = []
    @ObservationIgnored private var upgrades: [Stat: Int] = [:]
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
        if boosts.contains(.guidesHat) { owned.insert(.hat) }
        hatOn = false
        upgrades = game.upgrades
        maxHP = game.maxHP
        engine.maxHP = maxHP
        engine.hp = maxHP
        award = { [weak game] in game?.award($0) }
        apply()
    }

    func reset() {
        cooldowns = [:]
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

    func use(_ item: Item) {
        guard owned.contains(item), (cooldowns[item] ?? 0) <= 0, let engine else { return }
        switch item {
        case .vines:
            // Vines whip out and tangle up a grown-up: 10 seconds, usable every 35.
            if stun(10, false) {
                cooldowns[.vines] = 35
                Sound.whip.play()
            } else {
                engine.say("There's nobody here to use the vines on.")
            }
        case .toy:
            // Your brother's reward toy: stuns Mom for a minute, usable every 50 seconds.
            if stun(60, true) {
                cooldowns[.toy] = 50
                Sound.squeak.play()
            } else {
                engine.say("Mom isn't here to throw the toy at.")
            }
        case .bat:
            // A quick bonk: Mom sees stars for 2 seconds. Ready again after 5.
            if stun(2, true) {
                cooldowns[.bat] = 5
                Sound.bonk.play()
            } else {
                engine.say("Mom isn't here to bonk.")
            }
        case .cloud:
            // Ten seconds in the air, then 30 to rest.
            guard engine.running, !engine.hidden else { return }
            engine.fly(10)
            cooldowns[.cloud] = 10 + 30
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
        if boosts.contains(.coolCap) { speed *= 1.5 }
        if boosts.contains(.leaf) { jump *= 1.3 }
        if boosts.contains(.windCrown) { speed *= 1.2; dash *= 2.5 }
        if boosts.contains(.goldenCrown) { speed *= 1.2; jump *= 1.2; dash *= 1.2; quiet *= 1.5 }
        if boosts.contains(.arrow) { speed *= 1.2; dash *= 1.9 }
        if lightningLeft > 0 { speed *= 3.5; jump *= 3.5; dash *= 3.5; quiet *= 1.75 }
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
