import SwiftUI
import Observation

/// Level 9 rules, "Raid":
/// 1. Driving on from Grandma's, Uncle suddenly stops the car: a gang of robbers jumps out of the
///    dark, and they've already pulled bits off his car.
/// 2. Hit the robbers with your bat (B; Uncle lends you his if you haven't got one). Three bonks
///    and a robber runs off, dropping whatever car part they were carrying. They talk the whole
///    time, and bumping into one hurts (there's a health bar).
/// 3. Pick up the car parts (on the road and dropped by robbers) and fit them at the car (E).
///    When every robber is gone and the car is fixed, Uncle thanks you and teaches you to upgrade
///    your boosting and defensive items (the Upgrade Items skill, used in the Shop).
/// 4. With practice mode on, the Guide fights the robbers alongside you.
@MainActor
@Observable
final class RaidModel {
    enum Phase { case fighting, over }

    struct Robber: Identifiable {
        let id: Int
        var pos: CGPoint
        var hits = 0
        /// The car part in their sack, if any (dropped when they're beaten).
        var part: String?
        var stunned = 0.0
        var fleeing = false
        var facingRight = true
        var facing: Facing = .south
        var walking = false
        var says: String?
        var sayTime = 0.0
        var bumpTime = 0.0
    }

    let engine = GameEngine()
    let belt = ItemBelt()
    var phase: Phase = .fighting
    var popup: Popup?
    var banner: String?
    var robbers: [Robber] = []
    /// Parts you're carrying, and parts already fitted to the car.
    var carrying: [String] = []
    var fitted: Set<String> = []
    var uncleSays: String?
    var playerOpacity = 1.0

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var teach: () -> Bool = { false }
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var uncleTime = 0.0
    @ObservationIgnored private var chatter = 4.0
    @ObservationIgnored private var guideSwing = 0.0
    @ObservationIgnored private var robberCount = 5

    static let floor: ClosedRange<CGFloat> = 545...690
    static let width: CGFloat = 3200
    static let carX: CGFloat = 1500
    static let uncleSpot = CGPoint(x: 1260, y: 600)
    static let parts = ["Tyre", "Battery", "Spark plug", "Headlight", "Fan belt"]
    static let partSymbols = ["Tyre": "circle.circle.fill", "Battery": "battery.100.bolt", "Spark plug": "bolt.fill",
                              "Headlight": "headlight.high.beam.fill", "Fan belt": "circle.dotted"]

    /// How many parts the car needs on this mode.
    var partsNeeded: [String] { Array(Self.parts.prefix(Difficulty.current.pick(easy: 3, mild: 4, hard: 5))) }
    var carFixed: Bool { fitted.count >= partsNeeded.count }
    var robbersLeft: Int { robbers.filter { !$0.fleeing }.count }

    var cornerText: String {
        phase == .over ? "" : "Robbers left \(robbersLeft)/\(robberCount)  ·  car parts fitted \(fitted.count)/\(partsNeeded.count)"
            + (carrying.isEmpty ? "" : "  ·  carrying \(carrying.count)")
    }

    var inventory: [InventoryItem] {
        carrying.map { InventoryItem(id: $0, symbol: Self.partSymbols[$0] ?? "gearshape.fill", color: .orange) }
    }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onTimeUp = { [weak self] in self?.end("They got away!", "The sun's coming up and the robbers drove off with half of Uncle's car.") }
        engine.onTooLoud = { [weak self] in self?.engine.resetNoise() }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        // The bat (or any stun item) bonks the nearest robber.
        belt.stun = { [weak self] seconds, _ in self?.bonk(stun: seconds) ?? false }
        belt.goldenStick = { [weak self] in
            guard let self else { return }
            for i in robbers.indices where !robbers[i].fleeing { beaten(i) }
        }
        // Practice mode: the Guide heads for the nearest robber and helps.
        engine.guideGoal = { [weak self] in
            guard let self else { return nil }
            if let r = nearestRobber(to: engine.guidePos ?? engine.player) { return robbers[r].pos }
            if let part = engine.nearestSpot(where: { $0.kind == "part" }) { return part }
            return carrying.isEmpty ? nil : CGPoint(x: Self.carX, y: 620)
        }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func retry() {
        onRetry()
        reset()
    }

    func reset() {
        let mode = Difficulty.current
        robberCount = mode.pick(easy: 3, mild: 5, hard: 7)
        let needed = partsNeeded
        // The robbers carry some of the parts; the rest are scattered on the road.
        let carried = Array(needed.shuffled().prefix(min(robberCount, needed.count / 2 + 1)))
        var things: [Thing] = [
            Thing(id: "car", kind: "car", pos: CGPoint(x: Self.carX, y: 575), prompt: "Fix the car", reach: CGSize(width: 260, height: 110)),
        ]
        var rng = SeededRandom(seed: 909)
        for (n, part) in needed.filter({ !carried.contains($0) }).enumerated() {
            let x = n % 2 == 0 ? 500 + rng.next() * 500 : 2100 + rng.next() * 800
            things.append(Thing(id: "part-\(part)", kind: "part", pos: CGPoint(x: x, y: 570 + rng.next() * 100),
                                footprint: CGSize(width: 40, height: 20), prompt: "Pick up the \(part.lowercased())", reach: CGSize(width: 80, height: 60)))
        }
        robbers = (0..<robberCount).map { i in
            let side: CGFloat = i % 2 == 0 ? 1 : -1
            let x = Self.carX + side * (500 + CGFloat(i / 2) * 330)
            return Robber(id: i, pos: CGPoint(x: min(max(x, 120), Self.width - 120), y: [600, 660, 580, 640, 620, 670, 590][i % 7]),
                          part: i < carried.count ? carried[i] : nil, facingRight: side < 0)
        }
        engine.load(SceneLayout(width: Self.width, floor: Self.floor, things: things, spawn: CGPoint(x: 1200, y: 640)))
        engine.usesHP = true
        engine.timeLeft = Levels.time(9)
        engine.timerOn = true
        engine.showsClock = true
        engine.resetNoise()
        engine.noiseFactor = 1
        engine.speedBoost = false
        engine.jumpBoost = false
        engine.shields = 0
        engine.runHeld = false
        engine.speedBonus = 0
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        belt.reset()
        belt.owned.insert(.bat)
        belt.batCooldown = 0.6
        phase = .fighting
        popup = nil
        banner = "SCREECH! Uncle slams on the brakes... ROBBERS!"
        bannerTime = 3.5
        carrying = []
        fitted = []
        playerOpacity = 1
        speakUncle("They've pulled my car to bits! Bonk them with the bat (B), kiddo, and bring me the parts!", 5)
        engine.running = true
    }

    // MARK: Every frame

    private func tick(_ dt: Double) {
        belt.tick(dt)
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        if uncleTime > 0 {
            uncleTime -= dt
            if uncleTime <= 0 { uncleSays = nil }
        }
        let p = engine.player
        let speed = 150 * Difficulty.current.hazardSpeed
        chatter -= dt
        for i in robbers.indices {
            var r = robbers[i]
            if r.sayTime > 0 {
                r.sayTime -= dt
                if r.sayTime <= 0 { r.says = nil }
            }
            r.bumpTime = max(0, r.bumpTime - dt)
            var target: CGPoint
            if r.fleeing {
                target = CGPoint(x: r.pos.x < Self.carX ? -200 : Self.width + 200, y: r.pos.y)
            } else if r.stunned > 0 {
                r.stunned -= dt
                target = r.pos
            } else {
                // Close by, they come for you; further off, they hang around the car.
                let near = hypot(p.x - r.pos.x, p.y - r.pos.y) < 650
                target = near ? p : CGPoint(x: Self.carX + (r.id % 2 == 0 ? 220 : -220), y: r.pos.y)
            }
            let dx = target.x - r.pos.x, dy = target.y - r.pos.y
            let distance = hypot(dx, dy)
            let pace = r.fleeing ? speed * 2.2 : speed
            if distance > 30 {
                let step = min(distance, pace * CGFloat(dt))
                r.pos.x += dx / distance * step
                r.pos.y = min(max(r.pos.y + dy / distance * step * 0.8, Self.floor.lowerBound), Self.floor.upperBound)
                if abs(dx) > 3 { r.facingRight = dx > 0 }
                r.facing = Facing.moving(dx: dx, dy: dy)
                r.walking = true
            } else {
                r.walking = false
                r.facing = .south
            }
            // Bumping into a robber hurts and knocks you back.
            if !r.fleeing && r.stunned <= 0 && abs(p.x - r.pos.x) < 50 && abs(p.y - r.pos.y) < 30 && engine.z < 40 && r.bumpTime <= 0 {
                if engine.damage(12) {
                    r.bumpTime = 1.5
                    engine.player.x = min(max(p.x + (p.x >= r.pos.x ? 90 : -90), 40), engine.width - 40)
                    if r.says == nil { r.says = Self.grabLines.randomElement(); r.sayTime = 2 }
                }
            }
            robbers[i] = r
        }
        robbers.removeAll { $0.fleeing && ($0.pos.x < -150 || $0.pos.x > Self.width + 150) }
        // Robbers can't keep quiet.
        if chatter <= 0 {
            chatter = .random(in: 3...6)
            if let i = robbers.indices.filter({ !robbers[$0].fleeing && robbers[$0].says == nil }).randomElement() {
                robbers[i].says = Self.chatterLines.randomElement()
                robbers[i].sayTime = 2.6
            }
        }
        // Practice mode: the Guide bonks any robber he reaches.
        guideSwing = max(0, guideSwing - dt)
        if Settings.shared.practiceOn, !engine.guideGone, let g = engine.guidePos, guideSwing <= 0,
           let r = nearestRobber(to: g), hypot(robbers[r].pos.x - g.x, robbers[r].pos.y - g.y) < 100 {
            guideSwing = 1.6
            hit(r, by: "the Guide")
            engine.guideSpeech = ["Take that!", "Hi-yah!", "Lantern bonk!", "Leave our car alone!"].randomElement()
        }
    }

    private func nearestRobber(to spot: CGPoint) -> Int? {
        robbers.indices.filter { !robbers[$0].fleeing }
            .min { hypot(robbers[$0].pos.x - spot.x, robbers[$0].pos.y - spot.y) < hypot(robbers[$1].pos.x - spot.x, robbers[$1].pos.y - spot.y) }
    }

    /// The bat: bonks the nearest robber within reach. False if nobody is close enough.
    private func bonk(stun seconds: Double) -> Bool {
        let p = engine.player
        guard let r = nearestRobber(to: p), abs(robbers[r].pos.x - p.x) < 130, abs(robbers[r].pos.y - p.y) < 70 else {
            engine.say("Too far away! Get closer, then swing.", seconds: 1.4)
            return false
        }
        engine.facingRight = robbers[r].pos.x > p.x
        hit(r, by: "you", stun: max(1.2, seconds))
        return true
    }

    private func hit(_ r: Int, by who: String, stun: Double = 1.2) {
        Sound.bonk.play()
        robbers[r].hits += 1
        robbers[r].stunned = stun
        robbers[r].pos.x += robbers[r].pos.x >= engine.player.x ? 70 : -70
        robbers[r].pos.x = min(max(robbers[r].pos.x, 40), Self.width - 40)
        if robbers[r].hits >= 3 {
            beaten(r)
        } else {
            robbers[r].says = Self.hurtLines.randomElement()
            robbers[r].sayTime = 1.8
        }
    }

    /// Three bonks: they drop their part and run.
    private func beaten(_ r: Int) {
        robbers[r].fleeing = true
        robbers[r].stunned = 0
        robbers[r].says = Self.fleeLines.randomElement()
        robbers[r].sayTime = 2.5
        if let part = robbers[r].part {
            robbers[r].part = nil
            engine.things.append(Thing(id: "part-\(part)", kind: "part", pos: robbers[r].pos, footprint: CGSize(width: 40, height: 20),
                                       prompt: "Pick up the \(part.lowercased())", reach: CGSize(width: 80, height: 60)))
            banner = "The robber dropped the \(part.lowercased())!"
            bannerTime = 2.2
        }
        Sound.star.play()
        if robbersLeft == 0 {
            banner = carFixed ? nil : "Every robber has run off! Now fix Uncle's car."
            bannerTime = 3
            speakUncle(carFixed ? "That's the lot of them!" : "You did it! Quick, the parts. Bring them to the car!", 3.5)
        }
        checkWin()
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "part":
            let name = String(thing.id.dropFirst(5))
            engine.things.remove(at: i)
            carrying.append(name)
            Sound.key.play()
            engine.say("Got the \(name.lowercased())! Take it to the car.", seconds: 1.6)
        case "car": fixCar()
        default: break
        }
    }

    private func fixCar() {
        guard !carFixed else {
            engine.say("The car's fixed. Now chase off the robbers!")
            return
        }
        guard !carrying.isEmpty else {
            let missing = partsNeeded.filter { !fitted.contains($0) }
            engine.say("Still missing: \(missing.map { $0.lowercased() }.joined(separator: ", ")).", seconds: 2.5)
            return
        }
        for part in carrying { fitted.insert(part) }
        carrying = []
        Sound.craft.play()
        speakUncle(carFixed ? "That's the last one! She purrs like a kitten again." : "Lovely! Clunk, clank... in it goes.", 3)
        if carFixed {
            banner = robbersLeft > 0 ? "Checkpoint! The car is fixed. Now get rid of the robbers!" : nil
            bannerTime = 3
        }
        checkWin()
    }

    private func checkWin() {
        guard phase == .fighting, carFixed, robbersLeft == 0 else { return }
        phase = .over
        engine.running = false
        engine.timerOn = false
        onComplete()
        let fresh = teach()
        Sound.win.play()
        show(Popup(title: "Level Complete!",
                   message: "Uncle: \"Robbers, bonked. Car, fixed. Kiddo, you're a natural with a spanner... let me show you a trick.\""
                       + (fresh ? "\n\nNew skill: UPGRADE ITEMS! Upgrade your boosting and defensive items in the Shop, up to level 3."
                                : "\n\n(You already know how to upgrade your items.)"),
                   symbol: "wrench.and.screwdriver.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    func knockedOut() {
        end("Ouch!", "The robbers were too much this time. Uncle drags you back into the car.")
    }

    private func end(_ title: String, _ message: String) {
        guard phase == .fighting else { return }
        phase = .over
        banner = nil
        engine.running = false
        Sound.caught.play()
        show(Popup(title: title, message: message, symbol: "exclamationmark.triangle.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func speakUncle(_ text: String, _ seconds: Double) {
        uncleSays = text
        uncleTime = seconds
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        wrapped.action = { [weak self] in
            self?.popup = nil
            newPopup.action()
        }
        wrapped.secondAction = { [weak self] in
            self?.popup = nil
            newPopup.secondAction()
        }
        withAnimation { popup = wrapped }
    }

    func hint() {
        if robbersLeft > 0 {
            engine.say("Walk up to a robber and press B to bonk them. Three bonks and they run. Don't let them bump you!", seconds: 4)
        } else if !carrying.isEmpty {
            engine.say("Take the parts to Uncle's car and press E.", seconds: 3)
        } else {
            engine.say("Find the missing car parts on the road, then fit them at the car.", seconds: 3.5)
        }
    }

    static let chatterLines = [
        "Nice car. Shame about the tyres!", "Who's the little one?", "Grab the battery, Gary!", "Nobody move! ...Except me.",
        "Is that a BAT?", "We're not robbers, we're... collectors.", "Get the kid!", "Shiny bits, shiny bits!",
    ]
    static let hurtLines = ["OW!", "Hey, that HURT!", "Not the nose!", "Who taught this kid to swing?!", "Oof!"]
    static let fleeLines = ["I'm out of here!", "RUN!", "Mummy!", "Keep the car, keep it!", "Never again!"]
    static let grabLines = ["Gotcha!", "Out of the way, kid!", "Ha! Too slow!"]
}

struct RaidLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = RaidModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Level 9 · Raid", inventory: model.inventory,
                      popup: model.popup, banner: model.banner, belt: model.belt,
                      cornerHint: model.cornerText, guideTips: GuideTips.level9,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            EmptyView()
        }
        .onAppear {
            model.onComplete = { game.complete(level: 9) }
            model.onExit = onExit
            model.onNext = onNext
            model.onRetry = { game.noteRetry() }
            model.award = { game.award($0) }
            model.teach = {
                let fresh = !game.skills.contains(.tinker)
                game.learn(.tinker)
                return fresh
            }
            model.engine.onKO = { [weak model] in model?.knockedOut() }
            model.belt.configure(game: game, engine: model.engine)
            model.belt.owned.insert(.bat)
            model.belt.batCooldown = 0.6
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            RoadScene(width: RaidModel.width)
            // Uncle's car, bonnet up until it's fixed.
            UncleCarArt(look: game.look, kidInside: false, uncleInside: false, lightsOn: model.carFixed)
                .overlay(alignment: .topTrailing) {
                    if !model.carFixed {
                        Image(systemName: "smoke.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6)).offset(x: -30, y: -30)
                    }
                }
                .anchored(at: CGPoint(x: RaidModel.carX, y: 575))
            PersonView(outfit: .uncle, expression: model.robbersLeft > 0 ? .scared : .happy)
                .anchored(at: RaidModel.uncleSpot)
            if let text = model.uncleSays {
                SpeechBubble(text: "Uncle: \(text)", tint: .orange, small: true)
                    .position(x: RaidModel.uncleSpot.x, y: RaidModel.uncleSpot.y - 280)
            }
            ForEach(model.robbers.filter { $0.pos.y <= engine.player.y }) { robber($0) }
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                if thing.kind == "part" {
                    let name = String(thing.id.dropFirst(5))
                    Image(systemName: RaidModel.partSymbols[name] ?? "gearshape.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.orange)
                        .shadow(color: .yellow, radius: 8)
                        .padding(.bottom, 4)
                }
            }
            ForEach(model.robbers.filter { $0.pos.y > engine.player.y }) { robber($0) }
            ForEach(model.robbers.filter { $0.says != nil }) { r in
                SpeechBubble(text: r.says ?? "", tint: .gray, small: true)
                    .position(x: r.pos.x, y: r.pos.y - 270)
            }
            Palette.shade.opacity(0.12 * Palette.shadeAmount)
        }
        .frame(width: RaidModel.width, height: 700, alignment: .topLeading)
    }

    private func robber(_ r: RaidModel.Robber) -> some View {
        PersonView(outfit: .robber(r.id), walking: r.walking, expression: r.fleeing ? .scared : r.stunned > 0 ? .surprised : nil,
                   facing: r.facing.isSideways ? nil : r.facing)
            .scaleEffect(x: r.facingRight ? 1 : -1, y: 1)
            .overlay(alignment: .top) {
                if r.stunned > 0 { StunStars().offset(y: 10) }
                // Bonks left before they give up
                if !r.fleeing {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { n in
                            Circle().fill(n < 3 - r.hits ? Color.red : .white.opacity(0.25)).frame(width: 10)
                        }
                    }
                    .offset(y: -12)
                }
            }
            .anchored(at: r.pos)
    }
}

extension GuideTips {
    static var level9: [String] { [
        "Robbers! Walk right up to one and press B to bonk them with the bat. Three bonks and they run away.",
        "Don't let them bump into you: it costs health. Jump (Space) or dash (Q) out of the way.",
        "Some robbers carry a car part in their sack. Beat them and they drop it. Others are lying on the road.",
        "Press E on a part to pick it up, then E at Uncle's car to fit it.",
        "When every robber is gone and the car is fixed, the level is won, and Uncle teaches you something new.",
        "With practice mode on, I'll fight them with you. Lantern bonk!",
    ] }
}
