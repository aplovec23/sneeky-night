import SwiftUI
import Observation

/// Level 7 rules: Auntie's backyard. It costs 10 orbs to get in, and you need 32 badges.
/// First pick up the hose by the tap and wash all the mud off the yard (walk close to each
/// muddy patch, like watering the plants in Level 4). Then the kittens get out: find every one,
/// some wandering about and some hiding in the bushes, pots, shed and so on. Auntie thanks you
/// with her old Water Hose (a boost only she gives) and walks you to Uncle's car, with a short scene.
/// Nobody chases you: the clock, the sleeping cats and the noise are the trouble here.
@MainActor
@Observable
final class BackyardModel {
    enum Phase { case wash, kittens, scene, over }

    let engine = GameEngine()
    var phase: Phase = .wash
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var hasHose = false
    var washed = 0
    var mudCount = 0
    var found = 0
    var kittenCount = 0
    /// Spraying right now (for the water drawn in front of you).
    var spraying = false
    var auntie = CGPoint(x: 470, y: 590)
    var auntieWalking = false
    var auntieRight = true
    var auntieSays: String?
    /// The end scene: where Uncle's car is, and whether you're in it.
    var carX: CGFloat = 5200
    var inCar = false
    var playerOpacity = 1.0
    let belt = ItemBelt()

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    /// Gives you the Water Hose (it's on straight away).
    @ObservationIgnored var giveHose: () -> Void = {}
    @ObservationIgnored private var kittenSpots: Set<String> = []
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var sayTime = 0.0
    @ObservationIgnored private var sprayTime = 0.0
    @ObservationIgnored private var splashSound = 0.0
    @ObservationIgnored private var run = 0

    static let floorBand: ClosedRange<CGFloat> = 545...690
    static let width: CGFloat = 4400
    static let gateX: CGFloat = 4230
    /// Places a kitten might hide. Some of them hold one.
    static let hidingSpots: [(id: String, kind: String, x: CGFloat, name: String)] = [
        ("bush1", "bush", 760, "the bush"), ("pots", "pots", 1120, "the flower pots"), ("shed", "shed", 1520, "the shed"),
        ("barrow", "barrow", 1980, "the wheelbarrow"), ("bush2", "bush", 2380, "the big bush"), ("doghouse", "doghouse", 2760, "the old doghouse"),
        ("compost", "compost", 3150, "the compost bin"), ("bush3", "bush", 3480, "the hedge"), ("birdhouse", "birdhouse", 3860, "the birdhouse post"),
    ]

    /// Auntie's face: cross when you step on a cat or make a racket, worried while the kittens are loose.
    var auntieMood: Mood {
        if banner?.hasPrefix("Auntie") == true { return .cross }
        if auntieSays?.hasPrefix("Oh no") == true { return .worried }
        return .happy
    }

    var cornerText: String {
        switch phase {
        case .wash: hasHose ? "Mud washed: \(washed)/\(mudCount)" : "Pick up the hose by the tap"
        case .kittens: "Kittens found: \(found)/\(kittenCount)"
        default: "Auntie is taking you to Uncle's car"
        }
    }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.steppedOn(i) }
        engine.onTimeUp = { [weak self] in self?.tooSlow() }
        engine.onTooLoud = { [weak self] in self?.tooLoud() }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        engine.guideGoal = { [weak self] in self?.goal() }
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
        run += 1
        let mode = Difficulty.current
        mudCount = mode.pick(easy: 12, mild: 24, hard: 38)
        kittenCount = mode.pick(easy: 4, mild: 7, hard: 10)
        // Some kittens hide; the rest wander about the yard.
        let hiding = min(Self.hidingSpots.count, (kittenCount + 1) / 2)
        kittenSpots = Set(Self.hidingSpots.map(\.id).shuffled().prefix(hiding))
        engine.load(SceneLayout(width: Self.width, floor: Self.floorBand, things: Self.things(mud: mudCount), spawn: CGPoint(x: 260, y: 620)))
        engine.usesHP = false
        engine.timeLeft = Levels.time(7)
        engine.timerOn = true
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
        phase = .wash
        inventory = []
        popup = nil
        banner = nil
        bannerTime = 0
        hasHose = false
        washed = 0
        found = 0
        spraying = false
        auntie = CGPoint(x: 470, y: 590)
        auntieWalking = false
        carX = Self.width + 600
        inCar = false
        playerOpacity = 1
        engine.running = true
        speak("Look at the state of my yard! Grab the hose by the tap and wash all that mud away.", 4.5)
    }

    // MARK: The yard

    private typealias H = HallwayModel

    static func things(mud: Int) -> [Thing] {
        var things: [Thing] = [
            H.onWall("houseDoor", "houseDoor", x: 120, prompt: "Go back inside", reach: 80),
            H.onWall("tap", "tap", x: 300, prompt: "Pick up the hose", reach: 70),
            H.onWall("basket", "basket", x: 620, prompt: nil, reach: 70),
            H.onWall("gate", "gate", x: gateX, prompt: "Open the gate", reach: 100),
        ]
        for spot in hidingSpots {
            things.append(H.onWall(spot.id, spot.kind, x: spot.x, prompt: nil, reach: 80))
        }
        // Mud everywhere, spread along the yard from near to far.
        var rng = SeededRandom(seed: 77)
        for i in 0..<mud {
            let x = 420 + (CGFloat(i) + rng.next() * 0.6) * (width - 800) / CGFloat(max(mud, 1))
            let y = floorBand.lowerBound + 20 + rng.next() * (floorBand.upperBound - floorBand.lowerBound - 30)
            things.append(Thing(id: "mud\(i)", kind: "mud", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 64, height: 22), flat: true))
        }
        // Things to jump over or crouch past: garden toys and paint pots, and two sleeping cats.
        let mode = Difficulty.current
        for (n, x) in [980, 1760, 2560, 3320].enumerated() {
            things.append(H.obstacle("toy\(n)", .toy, x: CGFloat(x), y: [600, 665, 630, 580][n], size: CGSize(width: 50, height: 26)))
        }
        things.append(H.obstacle("cans1", .cans, x: 2150, y: 655, size: CGSize(width: 60, height: 24)))
        for (n, x) in [1300, 3000].enumerated() {
            var cat = Thing(id: "cat\(n)", kind: "cat", pos: CGPoint(x: CGFloat(x), y: n == 0 ? 640 : 600), footprint: CGSize(width: 62, height: 24), hazard: .cat)
            if mode.atLeastHard {
                cat.patrol = (CGFloat(x) - 240)...(CGFloat(x) + 240)
                cat.speed = 90
            }
            things.append(cat)
        }
        return things
    }

    // MARK: Every frame

    private func tick(_ dt: Double) {
        belt.tick(dt)
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        if sayTime > 0 {
            sayTime -= dt
            if sayTime <= 0 { auntieSays = nil }
        }
        if sprayTime > 0 {
            sprayTime -= dt
            if sprayTime <= 0 { spraying = false }
        }
        splashSound -= dt
        switch phase {
        case .wash: wash()
        case .kittens: followYou(dt)
        default: break
        }
    }

    /// With the hose, walking close to mud washes it away.
    private func wash() {
        guard hasHose else { return }
        let p = engine.player
        for i in engine.things.indices where engine.things[i].kind == "mud" && !engine.things[i].hidden {
            let q = engine.things[i].pos
            guard abs(q.x - p.x) < 80, abs(q.y - p.y) < 60 else { continue }
            engine.things[i].hidden = true
            washed += 1
            spraying = true
            sprayTime = 0.4
            if splashSound <= 0 {
                Sound.water.play(volume: 0.6)
                splashSound = 0.3
            }
            if washed % 8 == 0 && washed < mudCount {
                engine.timeLeft += 15
                engine.say("\(washed) patches washed! +15 seconds", seconds: 1.6)
            }
        }
        if washed >= mudCount { allWashed() }
    }

    private func allWashed() {
        phase = .kittens
        Sound.powerup.play()
        engine.timeLeft += 45
        banner = "Checkpoint! The yard is clean. +45 seconds"
        bannerTime = 3
        // The noise of the hose let the kittens out.
        speak("Oh no, the gate to the kitten pen was open! My \(kittenCount) kittens are all over the yard. Find them, dear!", 5)
        let wandering = kittenCount - kittenSpots.count
        let colors = 5
        for n in 0..<wandering {
            let x = 900 + CGFloat(n) * (Self.width - 1500) / CGFloat(max(wandering, 1)) + .random(in: -100...100)
            var kitten = Thing(id: "kitten\(n)", kind: "kitten\(n % colors)", pos: CGPoint(x: x, y: .random(in: 580...675)),
                               footprint: CGSize(width: 44, height: 18), prompt: "Pick up the kitten", reach: CGSize(width: 70, height: 50))
            kitten.patrol = max(500, x - 300)...min(Self.width - 300, x + 300)
            kitten.speed = (n % 2 == 0 ? 1 : -1) * 70 * Difficulty.current.hazardSpeed
            engine.things.append(kitten)
        }
        for spot in Self.hidingSpots {
            if let i = engine.index(of: spot.id) { engine.things[i].prompt = "Look in \(spot.name)" }
        }
    }

    /// While you look for kittens, Auntie waits by the basket.
    private func followYou(_ dt: Double) {
        let target: CGFloat = 520
        let dx = target - auntie.x
        if abs(dx) > 6 {
            auntie.x += (dx > 0 ? 1 : -1) * min(abs(dx), 160 * CGFloat(dt))
            auntieRight = dx > 0
            auntieWalking = true
        } else if auntieWalking {
            auntieWalking = false
        }
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        if thing.kind.hasPrefix("kitten") {
            engine.things[i].hidden = true
            gotKitten("Got one! Come here, little one.")
            return
        }
        switch thing.kind {
        case "houseDoor": speak("Not until my yard is sorted, dear!", 2.4)
        case "tap":
            guard !hasHose else {
                engine.say("The hose is already on. Walk close to the mud to wash it.")
                return
            }
            hasHose = true
            engine.things[i].prompt = nil
            inventory.append(InventoryItem(id: "hose", symbol: "drop.fill", color: Boost.waterHose.color))
            Sound.water.play()
            engine.say("The hose is on! Now walk close to every muddy patch.", seconds: 3)
        case "gate":
            if phase == .scene || phase == .over { return }
            engine.say(phase == .wash ? "Auntie wants her yard clean first." : "\(kittenCount - found) kittens are still missing!")
        case "bush", "pots", "shed", "barrow", "doghouse", "compost", "birdhouse": search(i)
        default: break
        }
    }

    private func search(_ i: Int) {
        let id = engine.things[i].id
        guard phase == .kittens else { return }
        engine.things[i].open = true
        engine.things[i].prompt = nil
        Sound.rustle.play()
        if kittenSpots.remove(id) != nil {
            let name = Self.hidingSpots.first { $0.id == id }?.name ?? "there"
            gotKitten("A kitten was hiding in \(name)!")
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else {
            engine.say(["Just a snail.", "A lost tennis ball. No kitten.", "Leaves and more leaves.", "A very surprised frog."].randomElement()!)
        }
    }

    private func gotKitten(_ line: String) {
        found += 1
        Sound.squeak.play(volume: 0.5)
        inventory.append(InventoryItem(id: "kitten\(found)", symbol: "cat.fill", color: [.orange, .gray, .brown, .white, .yellow][found % 5]))
        engine.say("\(line) \(found) of \(kittenCount).", seconds: 2)
        if found >= kittenCount { allFound() }
    }

    private func allFound() {
        phase = .scene
        engine.timerOn = false
        award(.kittens)
        Sound.win.play()
        speak("Every one of them! Thank you, dear.", 3)
        show(Popup(title: "Auntie's thank-you",
                   message: "Auntie: \"You washed my yard and found every kitten. Take my old hose. It's never let me down.\"\n\n\(Boost.waterHose.name): \(Boost.waterHose.about)",
                   symbol: Boost.waterHose.symbol, color: Boost.waterHose.color, button: "Thank you, Auntie!") { [weak self] in
            guard let self else { return }
            giveHose()
            playScene()
        })
    }

    // MARK: The end scene

    /// Auntie walks you to the gate, Uncle's car pulls up, you hop in and off it goes.
    private func playScene() {
        onComplete()
        engine.running = false
        engine.walking = false
        let run = self.run
        Task { @MainActor in
            @MainActor func wait(_ seconds: Double) async -> Bool {
                try? await Task.sleep(for: .seconds(seconds))
                return self.run == run
            }
            banner = nil
            speak("Come along. Your uncle is waiting out front.", 3)
            auntieWalking = true
            engine.walking = true
            engine.facingRight = true
            auntieRight = true
            withAnimation(.linear(duration: 3)) {
                engine.player = CGPoint(x: Self.gateX - 230, y: 620)
                auntie = CGPoint(x: Self.gateX - 120, y: 590)
            }
            guard await wait(3) else { return }
            auntieWalking = false
            engine.walking = false
            Sound.door.play()
            withAnimation(.easeOut(duration: 2.2)) { carX = Self.gateX + 330 }
            guard await wait(2.4) else { return }
            Sound.beep.play()
            engine.say("Uncle: \"Beep beep! Hop in, kiddo. Grandpa's town is next.\"", seconds: 3)
            guard await wait(2.6) else { return }
            speak("Off you go. Give Grandpa a big hug from me.", 3)
            withAnimation(.easeIn(duration: 0.8)) {
                engine.player = CGPoint(x: Self.gateX + 200, y: 610)
                playerOpacity = 0
            }
            guard await wait(0.9) else { return }
            inCar = true
            Sound.door.play()
            guard await wait(1) else { return }
            withAnimation(.easeIn(duration: 2.4)) { carX = Self.gateX + 1800 }
            guard await wait(2.6) else { return }
            phase = .over
            show(Popup(title: "Level Complete!", message: "Auntie waves from the gate as Uncle's old car rattles off into the morning.",
                       symbol: "car.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                       secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
        }
    }

    // MARK: Trouble

    private func steppedOn(_ i: Int) {
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard phase == .wash || phase == .kittens, !engine.safe else { return }
        let lost = (15 * Difficulty.current.damageScale).rounded()
        engine.timeLeft = max(1, engine.timeLeft - lost)
        let what = engine.things[i].hazard == .cat ? "MEOW! \"Mind my cats!\"" : "CLATTER! \"Careful, dear!\""
        banner = "Auntie: \(what)  −\(Int(lost)) seconds"
        bannerTime = 2.6
    }

    private func tooLoud() {
        engine.resetNoise()
        guard phase == .wash || phase == .kittens, !engine.safe else { return }
        engine.timeLeft = max(1, engine.timeLeft - 20)
        banner = "Auntie: \"Shh! The neighbours are still asleep!\"  −20 seconds"
        bannerTime = 2.6
    }

    private func tooSlow() {
        guard phase == .wash || phase == .kittens else { return }
        let done = phase == .kittens ? "You found \(found) of \(kittenCount) kittens." : "You washed \(washed) of \(mudCount) patches."
        award(.amNotPm)
        phase = .over
        engine.running = false
        Sound.caught.play()
        show(Popup(title: "Too slow!", message: "Auntie: \"The sun's nearly up! We'll try again.\"\n\(done)",
                   symbol: "clock.badge.exclamationmark.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func speak(_ text: String, _ seconds: Double) {
        auntieSays = text
        sayTime = seconds
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        wrapped.action = { [weak self] in
            self?.closePopup()
            newPopup.action()
        }
        wrapped.secondAction = { [weak self] in
            self?.closePopup()
            newPopup.secondAction()
        }
        withAnimation { popup = wrapped }
    }

    private func closePopup() {
        withAnimation { popup = nil }
        engine.running = phase == .wash || phase == .kittens
    }

    // MARK: Help

    /// Where the Guide leads you: the tap, then the nearest mud; then the nearest kitten.
    private func goal() -> CGPoint? {
        switch phase {
        case .wash:
            return hasHose ? engine.nearestSpot { $0.kind == "mud" } : engine.spot("tap")
        case .kittens:
            return engine.nearestSpot { $0.kind.hasPrefix("kitten") || kittenSpots.contains($0.id) }
        default:
            return nil
        }
    }

    func hint() {
        switch phase {
        case .wash:
            engine.say(hasHose ? "Walk close to each muddy patch. \(mudCount - washed) to go." : "The hose is by the tap, next to the back door. Press E there.", seconds: 3.5)
        case .kittens:
            engine.say("\(kittenCount - found) kittens to find. Some walk about: press E next to one. Others hide: look in bushes, pots, the shed...", seconds: 4.5)
        default:
            break
        }
    }
}

extension GuideTips {
    static var level7: [String] { [
        "First press E at the tap by the back door to pick up the hose.",
        "Walk close to every muddy patch to wash it. The count is at the bottom of the screen.",
        "When the yard is clean, the kittens get out. Some walk about: stand next to one and press E.",
        "The others hide. Press E at the bushes, the pots, the shed, the wheelbarrow, the doghouse...",
        "The sleeping cats and the garden toys cost time: jump over them (Space) or crouch past (C).",
    ] }
}

// MARK: - View

struct BackyardLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = BackyardModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Level 7 · Auntie's Backyard",
                      inventory: model.inventory, popup: model.popup, banner: model.banner, belt: model.belt,
                      cornerHint: model.cornerText, guideTips: GuideTips.level7,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            EmptyView()
        }
        .onAppear {
            model.onComplete = { game.complete(level: 7) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { game.award($0) }
            model.onRetry = { game.noteRetry() }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.giveHose = { game.take(.boost(.waterHose)) }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            BackyardScene(width: BackyardModel.width)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            AuntieView(walking: model.auntieWalking, expression: model.auntieMood)
                .scaleEffect(x: model.auntieRight ? 1 : -1, y: 1)
                .anchored(at: model.auntie)
            if let text = model.auntieSays {
                SpeechBubble(text: "Auntie: \(text)", tint: .teal, small: true)
                    .position(x: model.auntie.x, y: model.auntie.y - 280)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                floorItem(thing)
            }
            if model.spraying {
                HoseSpray(facingRight: engine.facingRight)
                    .position(x: engine.player.x + (engine.facingRight ? 70 : -70), y: engine.player.y - 40)
            }
            UncleCarArt(look: game.look, kidInside: model.inCar, uncleInside: true, lightsOn: true, wheelTurn: Double(model.carX) * 1.4)
                .anchored(at: CGPoint(x: model.carX, y: 690))
            Palette.shade.opacity(0.12 * Palette.shadeAmount)
        }
        .frame(width: engine.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "houseDoor": DoorView(color: Color(red: 0.25, green: 0.50, blue: 0.40)) { DoorSign(text: "AUNTIE'S", color: .green) }
        case "tap": GardenTapView(hoseTaken: model.hasHose)
        case "basket": KittenBasketView(kittens: model.found)
        case "gate": GardenGateView()
        case "bush": BushView(hiding: false, strange: false).scaleEffect(1.5, anchor: .bottom).opacity(thing.open ? 0.85 : 1)
        case "pots": FlowerPotsView()
        case "shed": GardenShedView(open: thing.open)
        case "barrow": WheelbarrowView()
        case "doghouse": DoghouseView()
        case "compost": CompostView()
        case "birdhouse": BirdhouseView()
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        if thing.kind.hasPrefix("kitten") {
            KittenView(color: Int(thing.kind.dropFirst(6)) ?? 0, facingRight: thing.speed > 0)
        } else {
            switch thing.kind {
            case "mud": MudPatchView(seed: thing.id.count + Int(thing.pos.x))
            case "cat": SleepingCatView(awake: thing.patrol != nil, facingRight: thing.speed > 0)
            case "toy": ToyBallView()
            case "cans": PaintCansView()
            default: EmptyView()
            }
        }
    }
}

// MARK: - Art

/// Auntie's backyard just before sunrise: her house at the left, a fence, a lawn, a washing line and trees.
struct BackyardScene: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 470)
            ForEach(0..<30, id: \.self) { i in
                Circle().fill(.white.opacity(0.7 * Palette.starlight)).frame(width: CGFloat(2 + i % 3))
                    .position(x: CGFloat((i * 151) % Int(width)), y: CGFloat((i * 53) % 240))
            }
            // Far trees
            ForEach(0..<Int(width / 380), id: \.self) { i in
                Circle().fill(Color(red: 0.12, green: 0.30, blue: 0.22)).frame(width: 220).position(x: CGFloat(i) * 380 + 200, y: 330)
                Rectangle().fill(Color(red: 0.30, green: 0.20, blue: 0.14)).frame(width: 26, height: 120).position(x: CGFloat(i) * 380 + 200, y: 420)
            }
            // The back of Auntie's house
            Rectangle().fill(Color(red: 0.55, green: 0.45, blue: 0.40)).frame(width: 260, height: 470)
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.28)).frame(width: 280, height: 30).offset(y: 40)
            // Fence
            HStack(spacing: 10) {
                ForEach(0..<Int((width - 270) / 44), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.78, green: 0.72, blue: 0.62)).frame(width: 34, height: 130)
                }
            }
            .offset(x: 270, y: 330)
            // A washing line with a few things pegged on it
            Path { p in
                p.move(to: CGPoint(x: 1650, y: 250))
                p.addQuadCurve(to: CGPoint(x: 2250, y: 250), control: CGPoint(x: 1950, y: 290))
            }
            .stroke(Color(white: 0.85), lineWidth: 2)
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4).fill([Color.pink, .cyan, .white, .yellow, .purple][i].opacity(0.85))
                    .frame(width: 44, height: 56).position(x: 1730 + CGFloat(i) * 110, y: 300 + (i == 2 ? 14 : 8))
            }
            // Lawn
            LinearGradient(colors: [Color(red: 0.20, green: 0.45, blue: 0.24), Color(red: 0.25, green: 0.55, blue: 0.28)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 240)
                .offset(y: 460)
            // Stepping stones
            ForEach(0..<Int(width / 260), id: \.self) { i in
                Ellipse().fill(Color(white: 0.62)).frame(width: 80, height: 24).offset(x: 160 + CGFloat(i) * 260, y: 650 + CGFloat(i % 2) * 18)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

struct MudPatchView: View {
    let seed: Int

    var body: some View {
        let brown = Color(red: 0.36, green: 0.24, blue: 0.14)
        ZStack {
            Ellipse().fill(brown.opacity(0.9)).frame(width: 66, height: 22)
            Circle().fill(brown).frame(width: 20).offset(x: CGFloat(seed % 3) * 8 - 14, y: -5)
            Circle().fill(brown.opacity(0.8)).frame(width: 14).offset(x: 18, y: 4)
            Ellipse().fill(.white.opacity(0.12)).frame(width: 18, height: 5).offset(x: -6, y: -4)
        }
        .frame(width: 70, height: 30)
    }
}

/// The water from the hose, in front of you while you wash.
struct HoseSpray: View {
    let facingRight: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<9, id: \.self) { i in
                    let k = (t * 3 + Double(i) / 9).truncatingRemainder(dividingBy: 1)
                    Circle().fill(Color(red: 0.55, green: 0.85, blue: 1).opacity(1 - k))
                        .frame(width: 8 + CGFloat(i % 3) * 3)
                        .offset(x: CGFloat(k) * 70 - 20, y: CGFloat(k * k) * 50 - 20 + CGFloat(i % 3) * 4)
                }
            }
            .scaleEffect(x: facingRight ? 1 : -1, y: 1)
        }
        .frame(width: 120, height: 90)
    }
}

struct GardenTapView: View {
    let hoseTaken: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(white: 0.55)).frame(width: 10, height: 90).offset(y: -30)
            Capsule().fill(Palette.gold).frame(width: 34, height: 12).offset(x: 10, y: -114)
            Circle().fill(.red).frame(width: 16).offset(y: -124)
            if !hoseTaken {
                ZStack {
                    Circle().stroke(Color(red: 0.20, green: 0.62, blue: 0.30), lineWidth: 7).frame(width: 64)
                    Circle().stroke(Color(red: 0.20, green: 0.62, blue: 0.30), lineWidth: 7).frame(width: 44)
                }
                .offset(x: 24, y: -10)
            }
        }
        .frame(width: 110, height: 140, alignment: .bottom)
    }
}

struct KittenBasketView: View {
    let kittens: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            Trapezoid().fill(Color(red: 0.75, green: 0.55, blue: 0.30)).frame(width: 110, height: 46).rotationEffect(.degrees(180))
            HStack(spacing: -10) {
                ForEach(0..<min(kittens, 6), id: \.self) { i in
                    KittenView(color: i, facingRight: i % 2 == 0).scaleEffect(0.55)
                        .frame(width: 30, height: 26)
                }
            }
            .offset(y: -34)
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(.black.opacity(0.12)).frame(width: 100, height: 2).offset(y: -CGFloat(i) * 10 - 6)
            }
        }
        .frame(width: 120, height: 80, alignment: .bottom)
    }
}

struct KittenView: View {
    let color: Int
    let facingRight: Bool

    var body: some View {
        let fur = [Color(red: 0.95, green: 0.62, blue: 0.28), Color(white: 0.55), Color(red: 0.50, green: 0.34, blue: 0.22),
                   Color(white: 0.95), Color(white: 0.18)][abs(color) % 5]
        ZStack {
            Capsule().fill(fur).frame(width: 24, height: 6).rotationEffect(.degrees(-50)).offset(x: -22, y: -10)
            Ellipse().fill(fur).frame(width: 40, height: 20)
            Circle().fill(fur).frame(width: 22).offset(x: 18, y: -10)
            Triangle().fill(fur).brightness(-0.1).frame(width: 9, height: 10).offset(x: 12, y: -24)
            Triangle().fill(fur).brightness(-0.1).frame(width: 9, height: 10).offset(x: 24, y: -24)
            Circle().fill(color == 4 ? .yellow : .black).frame(width: 3.5).offset(x: 15, y: -11)
            Circle().fill(color == 4 ? .yellow : .black).frame(width: 3.5).offset(x: 23, y: -11)
            Capsule().fill(fur).brightness(-0.08).frame(width: 6, height: 10).offset(x: -10, y: 10)
            Capsule().fill(fur).brightness(-0.08).frame(width: 6, height: 10).offset(x: 10, y: 10)
        }
        .frame(width: 70, height: 46)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
    }
}

struct GardenShedView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.45, green: 0.32, blue: 0.22)).frame(width: 220, height: 190)
            Triangle().fill(Color(red: 0.32, green: 0.22, blue: 0.16)).frame(width: 250, height: 70).offset(y: -186)
            ForEach(0..<6, id: \.self) { i in
                Rectangle().fill(.black.opacity(0.1)).frame(width: 2, height: 190).offset(x: -90 + CGFloat(i) * 36)
            }
            RoundedRectangle(cornerRadius: 4).fill(open ? Color(white: 0.08) : Color(red: 0.55, green: 0.40, blue: 0.26))
                .frame(width: 80, height: 140)
            if !open { Circle().fill(Palette.gold).frame(width: 9).offset(x: 26, y: -70) }
        }
        .frame(width: 260, height: 280, alignment: .bottom)
    }
}

struct DoghouseView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.62, green: 0.30, blue: 0.22)).frame(width: 130, height: 90)
            Triangle().fill(Color(red: 0.40, green: 0.20, blue: 0.16)).frame(width: 150, height: 56).offset(y: -88)
            Ellipse().fill(Color(white: 0.06)).frame(width: 56, height: 66).offset(y: 6)
            Text("REX").font(.game(14, .heavy)).foregroundStyle(.white).offset(y: -100)
        }
        .frame(width: 160, height: 160, alignment: .bottom)
    }
}
