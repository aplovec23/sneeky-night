import SwiftUI
import Observation

/// Level 8 rules, "Somewhere":
/// 1. Uncle drives you on, 50 seconds in his car (`GrandmaLevelView` shows the ride first).
/// 2. Grandma's garden: tidy it (sweep the leaf piles by walking over them, pull the weeds) and
///    find all 20 lanterns, some lying about and some hidden in pots, sheds and bushes. A blue key
///    is hidden somewhere too: it opens the gate to Grandma's porch. Rakes on the lawn cost time.
/// 3. Knock, and it takes Grandma 5 seconds to find her slippers. She asks a few questions, then
///    wants her chores done before she'll tell you where Grandpa lives (like Auntie in Level 6).
/// 4. You step outside... and Uncle, who doesn't know you're still out here, drives off. Chase the
///    car down the road, past cones, puddles and strangers, until Uncle checks his mirror and sees
///    you. Fall too far behind and he's gone. (A snack dog lies on the way: too full for snacks.)
@MainActor
@Observable
final class GrandmaModel {
    enum Area { case garden, house, road }
    enum Phase { case garden, knocking, questions, chores, road, over }

    let engine = GameEngine()
    let belt = ItemBelt()
    var area: Area = .garden
    var phase: Phase = .garden
    var popup: Popup?
    var banner: String?
    var hidingIn: String?
    var lanterns = 0
    var leavesSwept = 0
    var leafCount = 10
    var weedsPulled = 0
    var weedCount = 6
    var hasBlueKey = false
    var gateOpen = false
    var doorOpen = false
    /// Grandma, where she's standing (at her door, then inside).
    var grandma = CGPoint(x: 3960, y: 590)
    var grandmaHere = false
    var grandmaSays: String?
    var question = 0
    var chores: [Chore] = []
    var carX: CGFloat = 1000
    var carMoving = false
    var walkers: [Walker] = []
    var playerOpacity = 1.0

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var keySpot = ""
    @ObservationIgnored private var lanternSpots: Set<String> = []
    @ObservationIgnored private var needlesIn = ""
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var sayTime = 0.0
    @ObservationIgnored private var knockTime = 0.0
    @ObservationIgnored private var rakeCooldown = 0.0
    @ObservationIgnored private var bumpCooldown = 0.0
    @ObservationIgnored private var mirrorTime = 14.0
    /// Uncle's engine takes a moment to start: a head start for you.
    @ObservationIgnored private var carDelay = 0.0
    @ObservationIgnored private var saved: [Area: [Thing]] = [:]

    static let floorBand: ClosedRange<CGFloat> = 545...690
    static let gardenWidth: CGFloat = 4300
    static let houseWidth: CGFloat = 2400
    static let roadWidth: CGFloat = 9400
    static let lanternCount = 20
    static let gateX: CGFloat = 3400
    static let doorX: CGFloat = 3960
    /// Hiding places in the garden: id, kind, x, and what to call it.
    static let spots: [(id: String, kind: String, x: CGFloat, name: String)] = [
        ("pots", "pots", 520, "the flower pots"), ("barrow", "barrow", 900, "the wheelbarrow"), ("birdhouse", "birdhouse", 1360, "the birdhouse"),
        ("shed", "shed", 1800, "the shed"), ("bush1", "bush", 2250, "the rose bush"), ("compost", "compost", 2700, "the compost bin"),
        ("bush2", "bush", 3080, "the hedge"),
    ]

    var gardenClean: Bool { leavesSwept >= leafCount && weedsPulled >= weedCount }
    var choresDone: Int { chores.filter(\.finished).count }

    var inventory: [InventoryItem] {
        var items: [InventoryItem] = []
        if lanterns > 0 { items.append(InventoryItem(id: "lanterns", symbol: "lamp.table.fill", color: .orange)) }
        if hasBlueKey && !gateOpen { items.append(InventoryItem(id: "blueKey", symbol: "key.fill", color: Color(red: 0.3, green: 0.55, blue: 1))) }
        return items
    }

    /// The status line in the corner.
    var cornerText: String {
        switch phase {
        case .garden, .knocking:
            return "Lanterns \(lanterns)/\(Self.lanternCount)  ·  leaves \(leavesSwept)/\(leafCount)  ·  weeds \(weedsPulled)/\(weedCount)" + (hasBlueKey ? "  ·  blue key ✓" : "")
        case .questions: return "Grandma has a few questions..."
        case .chores: return "Grandma's chores \(choresDone)/\(chores.count)  ·  next: \(chores.first { !$0.finished }?.label ?? "")"
        case .road: return "Catch up with Uncle's car! Stay close until he checks his mirror."
        case .over: return ""
        }
    }

    var title: String {
        switch area {
        case .garden: "Level 8 · Grandma's Garden"
        case .house: "Level 8 · Grandma's House"
        case .road: "Level 8 · The Road"
        }
    }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onTimeUp = { [weak self] in self?.tooSlow() }
        engine.onTooLoud = { [weak self] in self?.engine.resetNoise() }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.goldenStick = { [weak self] in
            guard let self else { return }
            walkers = []
            engine.things.removeAll { $0.kind == "rake" || $0.kind == "cone" }
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
        leafCount = mode.pick(easy: 6, mild: 10, hard: 16)
        weedCount = mode.pick(easy: 4, mild: 6, hard: 9)
        chores = [
            Chore(id: "teacups", title: "Wash the teacups", needed: 3),
            Chore(id: "clock", title: "Wind the old clock", needed: 2),
            Chore(id: "fish", title: "Feed the goldfish", needed: 1),
            Chore(id: "frames", title: "Dust the photos", needed: 3),
            Chore(id: "crumbs", title: "Sweep up the crumbs", needed: mode.pick(easy: 3, mild: 4, hard: 6)),
            Chore(id: "needles", title: "Find the knitting needles", needed: 1),
        ]
        let ids = Self.spots.map(\.id).shuffled()
        keySpot = ids[0]
        lanternSpots = Set(ids.dropFirst())
        needlesIn = ["drawer1", "drawer2", "box1"].randomElement()!
        saved = [.house: Self.houseThings(crumbs: chores[4].needed)]
        area = .garden
        engine.load(SceneLayout(width: Self.gardenWidth, floor: Self.floorBand,
                                things: Self.gardenThings(leaves: leafCount, weeds: weedCount, hidden: lanternSpots.count),
                                spawn: CGPoint(x: 200, y: 620)))
        engine.usesHP = false
        engine.timeLeft = Levels.time(8)
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
        phase = .garden
        popup = nil
        banner = nil
        bannerTime = 0
        hidingIn = nil
        lanterns = 0
        leavesSwept = 0
        weedsPulled = 0
        hasBlueKey = false
        gateOpen = false
        doorOpen = false
        grandma = CGPoint(x: Self.doorX, y: 590)
        grandmaHere = false
        grandmaSays = nil
        question = 0
        carX = 1000
        carMoving = false
        walkers = []
        mirrorTime = 14
        playerOpacity = 1
        engine.running = true
        engine.say("Grandma's garden! It's a mess... and there are lanterns everywhere. 20 of them!", seconds: 4)
    }

    // MARK: The garden

    private typealias H = HallwayModel

    static func gardenThings(leaves: Int, weeds: Int, hidden: Int) -> [Thing] {
        var things: [Thing] = []
        for spot in spots {
            things.append(H.onWall(spot.id, spot.kind, x: spot.x, prompt: "Look in \(spot.name)", reach: 80))
        }
        things.append(H.onWall("gate", "gate", x: gateX, prompt: "Open the gate", reach: 100))
        // Until the gate is open, a fence closes off the porch.
        things.append(Thing(id: "fence", kind: "fence", pos: CGPoint(x: gateX + 40, y: 617), footprint: CGSize(width: 24, height: 160), solid: true))
        things.append(H.onWall("door", "grandmaDoor", x: doorX, prompt: "Knock on the door", reach: 100))
        var rng = SeededRandom(seed: 88)
        // The lanterns lying about (the rest are hidden).
        let loose = lanternCount - hidden
        for i in 0..<loose {
            let x = 380 + (CGFloat(i) + rng.next() * 0.7) * (gateX - 520) / CGFloat(max(loose, 1))
            let y = floorBand.lowerBound + 22 + rng.next() * (floorBand.upperBound - floorBand.lowerBound - 34)
            things.append(Thing(id: "lantern\(i)", kind: "lantern", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 30, height: 18)))
        }
        for i in 0..<leaves {
            let x = 440 + (CGFloat(i) + rng.next() * 0.6) * (gateX - 600) / CGFloat(max(leaves, 1))
            let y = floorBand.lowerBound + 18 + rng.next() * (floorBand.upperBound - floorBand.lowerBound - 30)
            things.append(Thing(id: "leaves\(i)", kind: "leaves", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 60, height: 22), flat: true))
        }
        for i in 0..<weeds {
            let x = 600 + (CGFloat(i) + rng.next() * 0.5) * (gateX - 800) / CGFloat(max(weeds, 1))
            let y = floorBand.lowerBound + 30 + rng.next() * (floorBand.upperBound - floorBand.lowerBound - 50)
            things.append(Thing(id: "weed\(i)", kind: "weed", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 34, height: 16),
                                prompt: "Pull the weed", reach: CGSize(width: 70, height: 50)))
        }
        // Rakes left lying on the lawn: step on one and BONK. Jump over them.
        for (n, x) in [1150, 2050, 2900].enumerated() {
            things.append(Thing(id: "rake\(n)", kind: "rake", pos: CGPoint(x: CGFloat(x), y: [600, 660, 630][n]), footprint: CGSize(width: 90, height: 18), flat: true))
        }
        return things
    }

    static func houseThings(crumbs: Int) -> [Thing] {
        var things: [Thing] = [
            H.onWall("frontDoor", "houseDoor", x: 120, prompt: nil, reach: 80),
            H.onWall("sink", "sink", x: 560, prompt: "Wash the teacups", reach: 90),
            H.onWall("clock", "grandfatherClock", x: 900, prompt: "Wind the old clock", reach: 70),
            H.onWall("drawer1", "drawer", x: 1180, prompt: "Look in the drawer"),
            H.onWall("fish", "fishbowl", x: 1440, prompt: "Feed the goldfish", reach: 70),
            H.onWall("frames", "photoShelf", x: 1760, prompt: "Dust the photos", reach: 90),
            H.onWall("drawer2", "drawer", x: 2060, prompt: "Look in the drawer"),
            H.box("box1", x: 1600, y: 650),
        ]
        for i in 0..<crumbs {
            let x = 420 + CGFloat(i) * (houseWidth - 700) / CGFloat(max(crumbs, 1))
            things.append(Thing(id: "crumbs\(i)", kind: "dust", pos: CGPoint(x: x, y: [600, 670, 630][i % 3]), footprint: CGSize(width: 50, height: 20), flat: true))
        }
        return things
    }

    static func roadThings() -> [Thing] {
        var things: [Thing] = []
        var rng = SeededRandom(seed: 808)
        // Cones and bins to dodge, puddles to wade through, and a very full snack dog.
        var x: CGFloat = 1200
        var n = 0
        while x < roadWidth - 900 {
            let y = floorBand.lowerBound + 20 + rng.next() * (floorBand.upperBound - floorBand.lowerBound - 30)
            if n % 3 == 2 {
                things.append(Thing(id: "puddle\(n)", kind: "puddle", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 110, height: 34), flat: true))
            } else {
                things.append(Thing(id: "cone\(n)", kind: "cone", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 40, height: 20)))
            }
            x += 330 + rng.next() * 260
            n += 1
        }
        things.append(Thing(id: "fullDog", kind: "fullDog", pos: CGPoint(x: 4300, y: 590), footprint: CGSize(width: 70, height: 22),
                            prompt: "Give the dog a snack", reach: CGSize(width: 90, height: 60)))
        return things
    }

    static func strangers() -> [Walker] {
        let lanes: [CGFloat] = [600, 655, 580, 670, 620, 595]
        return (0..<6).map { i in
            let start = 2000 + CGFloat(i) * 1100
            return Walker(id: i, kind: .stranger, pos: CGPoint(x: start + 200, y: lanes[i]), range: start...(start + 600),
                          speed: (i % 2 == 0 ? 1 : -1) * (90 + CGFloat(i % 3) * 25), style: i)
        }
    }

    // MARK: Every frame

    private func tick(_ dt: Double) {
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        if sayTime > 0 {
            sayTime -= dt
            if sayTime <= 0 { grandmaSays = nil }
        }
        rakeCooldown = max(0, rakeCooldown - dt)
        bumpCooldown = max(0, bumpCooldown - dt)
        let p = engine.player
        switch phase {
        case .garden:
            // Walking over leaves sweeps them; walking past a loose lantern picks it up.
            if engine.z < 20, let i = engine.things.firstIndex(where: { $0.kind == "leaves" && !$0.hidden && abs($0.pos.x - p.x) < 44 && abs($0.pos.y - p.y) < 30 }) {
                engine.things[i].hidden = true
                leavesSwept += 1
                Sound.rustle.play(volume: 0.5)
                if leavesSwept == leafCount { note("Checkpoint! Every leaf pile is swept.") }
                checkGarden()
            }
            if let i = engine.things.firstIndex(where: { $0.kind == "lantern" && !$0.hidden && abs($0.pos.x - p.x) < 50 && abs($0.pos.y - p.y) < 40 }) {
                engine.things[i].hidden = true
                gotLantern()
            }
            if engine.z < 12, rakeCooldown <= 0, !engine.safe,
               engine.things.contains(where: { $0.kind == "rake" && !$0.hidden && $0.covers(p) }) {
                rakeCooldown = 2.5
                let lost = (10 * Difficulty.current.damageScale).rounded()
                engine.timeLeft = max(1, engine.timeLeft - lost)
                Sound.bonk.play()
                banner = "BONK! You stepped on a rake.  −\(Int(lost)) seconds"
                bannerTime = 2.4
            }
        case .knocking:
            knockTime -= dt
            if knockTime <= 0 { grandmaOpens() }
        case .chores:
            if engine.z < 20, let i = engine.things.firstIndex(where: { $0.kind == "dust" && !$0.hidden && abs($0.pos.x - p.x) < 40 && abs($0.pos.y - p.y) < 30 }) {
                engine.things[i].hidden = true
                Sound.rustle.play(volume: 0.5)
                progress("crumbs")
            }
        case .road: tickRoad(dt)
        default: break
        }
    }

    private func note(_ text: String) {
        Sound.star.play()
        banner = text
        bannerTime = 2.6
    }

    private func gotLantern() {
        lanterns += 1
        Sound.chime.play(volume: 0.6)
        engine.say(lanterns == Self.lanternCount ? "That's all 20 lanterns!" : "A lantern! \(lanterns) of \(Self.lanternCount).", seconds: 1.4)
        if lanterns % 5 == 0 && lanterns < Self.lanternCount { engine.timeLeft += 15 }
        checkGarden()
    }

    private func checkGarden() {
        if gardenClean && lanterns >= Self.lanternCount {
            banner = "Checkpoint! The garden is tidy and you have every lantern.\(gateOpen ? " Knock on Grandma's door!" : " Now the gate: it needs a blue key.")"
            bannerTime = 3.5
            Sound.powerup.play()
        }
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "pots", "barrow", "birdhouse", "shed", "bush", "compost": search(i)
        case "weed":
            engine.things[i].hidden = true
            weedsPulled += 1
            Sound.rustle.play()
            engine.say(weedsPulled == weedCount ? "Every weed is pulled!" : "Pulled! \(weedsPulled) of \(weedCount).", seconds: 1.3)
            checkGarden()
        case "gate": useGate(i)
        case "grandmaDoor": knock()
        case "houseDoor": engine.say("Grandma: \"Chores first, dear!\"")
        case "sink": work(i, "teacups", sound: .water)
        case "grandfatherClock": work(i, "clock", sound: .tick)
        case "fishbowl": work(i, "fish", sound: .drawer)
        case "photoShelf": work(i, "frames", sound: .rustle)
        case "drawer", "box": searchHouse(i)
        case "fullDog":
            Sound.woof.play(volume: 0.4)
            engine.say("He just yawns. He's too full for snacks. He only wants a nap.", seconds: 2.4)
        default: break
        }
    }

    private func search(_ i: Int) {
        let id = engine.things[i].id
        engine.things[i].open = true
        engine.things[i].prompt = nil
        Sound.rustle.play()
        if id == keySpot {
            Sound.key.play()
            show(Popup(title: "A blue key!", message: "It has a little tag: \"GATE\". It must open the gate to Grandma's porch.",
                       symbol: "key.fill", color: Color(red: 0.3, green: 0.55, blue: 1), button: "Take Key") { [weak self] in
                self?.hasBlueKey = true
                self?.award(.patienceIsKey)
            })
        } else if lanternSpots.remove(id) != nil {
            gotLantern()
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else {
            engine.say(["Just a snail.", "Garden gloves. No lantern.", "Leaves and more leaves."].randomElement()!)
        }
    }

    private func useGate(_ i: Int) {
        guard !gateOpen else { return }
        guard hasBlueKey else {
            Sound.buzz.play()
            engine.say("Locked, with a blue padlock. The key must be somewhere in the garden.")
            return
        }
        gateOpen = true
        engine.things[i].prompt = nil
        engine.things.removeAll { $0.id == "fence" }
        Sound.unlock.play()
        engine.say("The blue key fits! Grandma's porch is through here.", seconds: 2.5)
        checkGarden()
    }

    private func knock() {
        guard phase == .garden else { return }
        guard gardenClean && lanterns >= Self.lanternCount else {
            var left: [String] = []
            if lanterns < Self.lanternCount { left.append("\(Self.lanternCount - lanterns) lanterns") }
            if leavesSwept < leafCount { left.append("\(leafCount - leavesSwept) leaf piles") }
            if weedsPulled < weedCount { left.append("\(weedCount - weedsPulled) weeds") }
            engine.say("Grandma would hate to see her garden like this. Still to do: \(left.joined(separator: ", ")).", seconds: 3.5)
            return
        }
        // It takes her a moment to find her slippers.
        phase = .knocking
        knockTime = 5
        engine.timerOn = false
        Sound.door.play(volume: 0.5)
        banner = "Knock knock... \"Coming, coming! Where are my slippers?\""
        bannerTime = 5
    }

    private func grandmaOpens() {
        phase = .questions
        doorOpen = true
        grandmaHere = true
        Sound.door.play()
        engine.running = false
        question = 0
    }

    /// Grandma's questions on the doorstep: (question, answers, what she says back to each answer).
    static let questions: [(ask: String, answers: [(String, String)])] = [
        ("Goodness! And who might you be, out here at this hour?", [
            ("Your grandchild!", "So you are! Look how you've grown."),
            ("A very sneaky visitor.", "Sneaky, hmm? You get that from your Grandpa."),
        ]),
        ("How on earth did you get all the way out here?", [
            ("Uncle drove me.", "Of course he did. That car is older than I am."),
            ("I sneaked out of bed!", "Shh! Don't tell me that. I didn't hear it."),
        ]),
        ("Did you tidy my garden? And all my lanterns, are they safe?", [
            ("Every leaf, and all 20 lanterns.", "Twenty! Grandpa made every single one of those."),
            ("Mostly. The rakes bit me.", "Those rakes bite everyone. Even the postman."),
        ]),
        ("And I suppose you want to know where your Grandpa is?", [
            ("Yes please!", "Then you can help me first. Chores, dear! Come in, come in."),
            ("I promised to bring him a lantern.", "What a lovely promise. But chores first, dear. Come in."),
        ]),
    ]

    /// An answer was picked. After the last question, inside for chores.
    func answer(_ n: Int) {
        let q = Self.questions[question]
        speak(q.answers[n].1, 3.2)
        Sound.click.play()
        if question + 1 < Self.questions.count {
            question += 1
        } else {
            goInside()
        }
    }

    private func goInside() {
        phase = .chores
        Sound.door.play(volume: 0.6)
        saved[.garden] = engine.things
        area = .house
        engine.load(SceneLayout(width: Self.houseWidth, floor: Self.floorBand, things: saved[.house] ?? [], spawn: CGPoint(x: 260, y: 610)))
        engine.timerOn = true
        engine.timeLeft += 60
        grandma = CGPoint(x: 360, y: 590)
        engine.running = true
        banner = "Checkpoint! Grandma's chores. +60 seconds"
        bannerTime = 3
    }

    private func chore(_ id: String) -> Chore? { chores.first { $0.id == id } }

    private func work(_ i: Int, _ id: String, sound: Sound) {
        guard let c = chore(id), !c.finished else {
            engine.say("That's done already.")
            return
        }
        sound.play(volume: 0.7)
        progress(id)
        if chore(id)?.finished == true { engine.things[i].open = true; engine.things[i].prompt = nil }
    }

    private func searchHouse(_ i: Int) {
        let id = engine.things[i].id
        engine.things[i].open = true
        Sound.drawer.play()
        if id == needlesIn && chore("needles")?.finished == false {
            progress("needles")
            engine.say("Grandma's knitting needles! And half a scarf.", seconds: 2)
        } else {
            engine.say(["Buttons and string.", "Old photos of Grandpa!", "A tin of toffees. Better not."].randomElement()!)
        }
    }

    private func progress(_ id: String) {
        guard let n = chores.firstIndex(where: { $0.id == id }), !chores[n].finished else { return }
        chores[n].done += 1
        guard chores[n].finished else { return }
        Sound.powerup.play()
        banner = "Checkpoint! \(chores[n].title): done. \(choresDone)/\(chores.count)"
        bannerTime = 2.2
        speak(["Lovely.", "Just like your Grandpa.", "Oh, you ARE helpful.", "That's the way, dear."].randomElement()!, 2.4)
        if choresDone == chores.count { allChoresDone() }
    }

    private func allChoresDone() {
        engine.timerOn = false
        show(Popup(title: "Where Grandpa is",
                   message: "Grandma: \"He lives in the little blue house by the river, right where the lanterns float. He's been waiting all year for someone to come.\"",
                   symbol: "house.lodge.fill", color: .cyan, button: "Thank you, Grandma!") { [weak self] in
            self?.startRoad()
        })
    }

    // MARK: The road

    private func startRoad() {
        phase = .road
        area = .road
        grandmaHere = false
        engine.load(SceneLayout(width: Self.roadWidth, floor: Self.floorBand, things: Self.roadThings(), spawn: CGPoint(x: 260, y: 620)))
        engine.usesHP = true
        engine.hp = engine.maxHP
        engine.timerOn = false
        engine.showsClock = false
        walkers = Self.strangers()
        carX = 760
        carMoving = true
        carDelay = 2
        mirrorTime = 14
        Sound.door.play()
        banner = "Uncle didn't see you come out... he's driving away! RUN!"
        bannerTime = 4
    }

    private func tickRoad(_ dt: Double) {
        let p = engine.player
        // Uncle drives a little slower than you walk (after his engine splutters into life).
        let speed: CGFloat = 205 * Difficulty.current.hazardSpeed.squareRoot()
        carDelay = max(0, carDelay - dt)
        if carMoving && carDelay <= 0 { carX += speed * CGFloat(dt) }
        // Cones: bump one and stumble (and it hurts a bit).
        if engine.z < 14, bumpCooldown <= 0,
           let cone = engine.things.first(where: { $0.kind == "cone" && !$0.hidden && $0.covers(p, pad: CGSize(width: -4, height: -4)) }) {
            bumpCooldown = 1.2
            if engine.damage(10) {
                engine.player.x = max(40, p.x - (p.x >= cone.pos.x ? -40 : 40))
                engine.say("Oof! A cone!", seconds: 1.2)
                Sound.chair.play()
            }
        }
        // The strangers from Level 5 are back.
        for i in walkers.indices {
            walkers[i].pos.x += walkers[i].speed * CGFloat(dt) * Difficulty.current.hazardSpeed
            let range = walkers[i].range
            if walkers[i].pos.x >= range.upperBound || walkers[i].pos.x <= range.lowerBound {
                walkers[i].pos.x = min(max(walkers[i].pos.x, range.lowerBound), range.upperBound)
                walkers[i].speed = -walkers[i].speed
            }
            walkers[i].facingRight = walkers[i].speed > 0
            let dx = p.x - walkers[i].pos.x, dy = p.y - walkers[i].pos.y
            if abs(dx) < 42, abs(dy) < 28, engine.z < 40, engine.damage(20) {
                engine.player.x = min(max(p.x + (dx >= 0 ? 80 : -80), 40), engine.width - 40)
                engine.say("Ouch! Keep away from the strangers!", seconds: 1.6)
            }
        }
        guard carMoving else { return }
        let gap = carX - p.x
        if gap > 2200 || carX > Self.roadWidth - 200 {
            lost()
            return
        }
        // Every 14 seconds Uncle glances in his mirror. Close enough and he sees you.
        mirrorTime -= dt
        if mirrorTime <= 2.5 && mirrorTime + dt > 2.5 {
            banner = "Uncle is about to check his mirror... get close!"
            bannerTime = 2.5
        }
        if mirrorTime <= 0 {
            mirrorTime = 14
            if gap < 650 {
                uncleStops()
            } else {
                Sound.buzz.play(volume: 0.5)
                banner = "Uncle checked his mirror... too far back! He didn't see you."
                bannerTime = 2.5
            }
        }
    }

    private func uncleStops() {
        carMoving = false
        phase = .over
        engine.running = false
        onComplete()
        Sound.beep.play()
        Sound.win.play()
        show(Popup(title: "Level Complete!",
                   message: "Uncle slams on the brakes. \"KIDDO?! I thought you were inside! ...Well, hop in. Let's find this blue house by the river.\"",
                   symbol: "car.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func lost() {
        carMoving = false
        end(title: "He's gone!", message: "Uncle's car disappeared round the corner. He never even looked back!")
    }

    private func tooSlow() {
        guard phase == .garden || phase == .chores else { return }
        award(.amNotPm)
        end(title: "Too slow!", message: phase == .garden ? "Grandma's lights went out. She's gone to bed!" : "Grandma: \"It's far too late, dear. We'll finish in the morning.\"")
    }

    func knockedOut() {
        end(title: "Ouch!", message: "You ran out of health chasing the car.")
    }

    private func end(title: String, message: String) {
        phase = .over
        banner = nil
        engine.running = false
        Sound.caught.play()
        show(Popup(title: title, message: message, symbol: "exclamationmark.triangle.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func speak(_ text: String, _ seconds: Double) {
        grandmaSays = text
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
        engine.running = phase == .garden || phase == .chores || phase == .road
    }

    /// Where the Guide leads you (practice mode).
    private func goal() -> CGPoint? {
        switch phase {
        case .garden:
            if !hasBlueKey { return engine.spot(keySpot) }
            if let lantern = engine.nearestSpot(where: { $0.kind == "lantern" || lanternSpots.contains($0.id) }) { return lantern }
            if let leaf = engine.nearestSpot(where: { $0.kind == "leaves" }) { return leaf }
            if let weed = engine.nearestSpot(where: { $0.kind == "weed" }) { return weed }
            return gateOpen ? engine.spot("door") : engine.spot("gate")
        case .chores:
            guard let next = chores.first(where: { !$0.finished }) else { return nil }
            let where_: [String: [String]] = ["teacups": ["sink"], "clock": ["grandfatherClock"], "fish": ["fishbowl"],
                                              "frames": ["photoShelf"], "crumbs": ["dust"], "needles": ["drawer", "box"]]
            return engine.nearestSpot { (where_[next.id] ?? []).contains($0.kind) && !$0.open }
        case .road: return CGPoint(x: carX - 200, y: 620)
        default: return nil
        }
    }


    func hint() {
        switch phase {
        case .garden:
            if !hasBlueKey { engine.say("A blue key is hidden somewhere: pots, the shed, the bushes...", seconds: 3.5) }
            else if lanterns < Self.lanternCount { engine.say("\(Self.lanternCount - lanterns) lanterns to go. Some lie on the lawn, others hide in the garden things.", seconds: 4) }
            else if !gardenClean { engine.say("Sweep the leaf piles (walk over them) and pull the weeds (E).", seconds: 3.5) }
            else { engine.say(gateOpen ? "Knock on Grandma's door!" : "Open the gate with the blue key.", seconds: 3) }
        case .chores:
            if let next = chores.first(where: { !$0.finished }) { engine.say("Next: \(next.label). Press E at it (crumbs: walk over them).", seconds: 3.5) }
        case .road: engine.say("Stay close to the car! When Uncle checks his mirror, he has to see you.", seconds: 3.5)
        default: break
        }
    }
}

// MARK: - View

struct GrandmaLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = GrandmaModel()
    /// The 50-second ride in Uncle's car comes first.
    @State private var riding = true

    static let rideLines = [
        "Grandma's house is past the end of my road. Fifty seconds, give or take.",
        "Auntie phoned ahead. Grandma's expecting you... sort of.",
        "Her garden is full of lanterns. Your Grandpa made every one.",
        "Watch out for the rakes. They bite. Ask the postman.",
        "Nearly there. See the lights in the trees?",
    ]

    var body: some View {
        if riding {
            UncleCarView(onExit: onExit, rideLength: 50, startInCar: true, destination: "Grandma's house",
                         lines: Self.rideLines, rideTitle: "Level 8 · Somewhere") {
                Sound.door.play()
                riding = false
            }
        } else {
            level
        }
    }

    private var level: some View {
        LevelScaffold(engine: model.engine, title: model.title, inventory: model.inventory,
                      popup: model.popup, banner: model.banner, belt: model.belt,
                      cornerHint: model.cornerText, guideTips: GuideTips.level8,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            if model.phase == .questions && model.question < GrandmaModel.questions.count {
                questionPanel
            }
        }
        .onAppear {
            model.onComplete = { game.complete(level: 8) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { game.award($0) }
            model.onRetry = { game.noteRetry() }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.engine.onKO = { [weak model] in model?.knockedOut() }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            switch model.area {
            case .garden:
                BackyardScene(width: GrandmaModel.gardenWidth)
                GrandmaHouseFront(doorX: GrandmaModel.doorX)
            case .house: AuntieWall(width: GrandmaModel.houseWidth, upstairs: true)
            case .road: RoadScene(width: GrandmaModel.roadWidth)
            }
            ForEach(engine.things.filter { !$0.onFloor && !$0.hidden }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.area == .road {
                UncleCarArt(look: game.look, kidInside: false, uncleInside: true, lightsOn: true, wheelTurn: Double(model.carX) * 1.4)
                    .anchored(at: CGPoint(x: model.carX, y: 575))
            }
            if model.grandmaHere || model.area == .house {
                GrandmaView(walking: false, expression: model.phase == .questions ? .surprised : .happy)
                    .scaleEffect(x: -1, y: 1)
                    .anchored(at: model.grandma)
                if let text = model.grandmaSays {
                    SpeechBubble(text: "Grandma: \(text)", tint: .purple, small: true)
                        .position(x: model.grandma.x, y: model.grandma.y - 280)
                }
            }
            ForEach(model.walkers.filter { $0.pos.y <= engine.player.y }) { w in
                PersonView(outfit: .stranger(w.style), walking: true).scaleEffect(x: w.facingRight ? 1 : -1, y: 1).anchored(at: w.pos)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                floorItem(thing)
            }
            ForEach(model.walkers.filter { $0.pos.y > engine.player.y }) { w in
                PersonView(outfit: .stranger(w.style), walking: true).scaleEffect(x: w.facingRight ? 1 : -1, y: 1).anchored(at: w.pos)
            }
            Palette.shade.opacity(0.12 * Palette.shadeAmount)
        }
        .frame(width: engine.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "bush": BushView(hiding: false, strange: false).scaleEffect(1.5, anchor: .bottom).opacity(thing.open ? 0.85 : 1)
        case "pots": FlowerPotsView()
        case "shed": GardenShedView(open: thing.open)
        case "barrow": WheelbarrowView()
        case "compost": CompostView()
        case "birdhouse": BirdhouseView()
        case "gate": GardenGateView().overlay(alignment: .center) {
            if !model.gateOpen {
                Image(systemName: "lock.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Color(red: 0.3, green: 0.55, blue: 1)).offset(y: 60)
            }
        }
        case "grandmaDoor": DoorView(color: Color(red: 0.30, green: 0.40, blue: 0.70), open: model.doorOpen) { DoorSign(text: "GRANDMA", color: .white) }
        case "houseDoor": DoorView(color: Color(red: 0.30, green: 0.40, blue: 0.70)) { EmptyView() }
        case "sink": KitchenSinkView(clean: thing.open)
        case "drawer": DresserView(open: thing.open)
        case "grandfatherClock": GrandfatherClockView(wound: thing.open)
        case "fishbowl": FishbowlView(fed: thing.open)
        case "photoShelf": PhotoShelfView(dusted: thing.open)
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "lantern": PaperLanternView(seed: thing.id.count + Int(thing.pos.x))
        case "leaves": LeafPileView(seed: Int(thing.pos.x))
        case "weed": WeedView()
        case "rake": RakeView().offset(y: 6)
        case "dust": DustPileView()
        case "box": CardboardBox(open: thing.open)
        case "cone": TrafficConeView()
        case "puddle": PuddleView(size: thing.footprint).offset(y: thing.footprint.height / 2)
        case "fullDog": DogView(happy: true).overlay(alignment: .top) {
            Text("z z").font(.game(18, .heavy)).foregroundStyle(.white.opacity(0.8)).offset(x: 30, y: 6)
        }
        default: EmptyView()
        }
    }

    /// Grandma's questions on the doorstep.
    private var questionPanel: some View {
        let q = GrandmaModel.questions[model.question]
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                GrandmaView(walking: false, expression: .happy).scaleEffect(0.45).frame(width: 66, height: 120)
                Text(q.ask).font(.game(24, .heavy)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(q.answers.indices, id: \.self) { n in
                BigButton(title: q.answers[n].0, color: Color(red: 0.45, green: 0.35, blue: 0.70)) { model.answer(n) }
                    .scaleEffect(0.85)
            }
            Text("Question \(model.question + 1) of \(GrandmaModel.questions.count)").font(.game(15, .semibold)).foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
        .frame(width: 620)
        .background(Color(red: 0.16, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.purple.opacity(0.7), lineWidth: 3))
    }
}

extension GuideTips {
    static var level8: [String] { [
        "First, the garden: walk over the leaf piles to sweep them, and press E at the weeds to pull them.",
        "Find all 20 lanterns. Some lie on the lawn (just walk past them); the others hide in the pots, the shed, the bushes...",
        "A blue key is hidden in one of the garden things. It opens the gate to Grandma's porch.",
        "Jump over the rakes (Space): stepping on one costs time.",
        "Knock on Grandma's door, answer her questions, then do her chores (like Auntie's).",
        "Then run after Uncle's car! Stay close: when he checks his mirror, he has to see you. Jump over cones, dodge the strangers.",
    ] }
}

// MARK: - Art

/// Grandma: in a lavender dressing gown, white hair in a bun, and round glasses.
struct GrandmaView: View {
    var walking = false
    var expression: Mood = .happy

    var body: some View {
        MomView(stunned: false, walking: walking, expression: expression, robe: Color(red: 0.62, green: 0.52, blue: 0.80),
                hair: Color(white: 0.92), curlers: false)
            .overlay(alignment: .top) {
                Circle().fill(Color(white: 0.92)).frame(width: 34).offset(x: 6, y: 20)
            }
            .overlay {
                HStack(spacing: 4) {
                    Circle().stroke(Color(white: 0.25), lineWidth: 2.5).frame(width: 17)
                    Circle().stroke(Color(white: 0.25), lineWidth: 2.5).frame(width: 17)
                }
                .offset(y: -62)
            }
    }
}

/// The front of Grandma's house at the end of the garden: blue walls, a porch light.
struct GrandmaHouseFront: View {
    let doorX: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(red: 0.42, green: 0.50, blue: 0.72)).frame(width: 760, height: 470).offset(x: doorX - 380, y: 75)
            Triangle().fill(Color(red: 0.32, green: 0.22, blue: 0.28)).frame(width: 820, height: 120).offset(x: doorX - 410, y: -40)
            ForEach([-230.0, 230.0], id: \.self) { dx in
                RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.75)).frame(width: 110, height: 100)
                    .overlay(Rectangle().fill(Color(white: 0.3)).frame(width: 4, height: 100))
                    .offset(x: doorX + dx - 55, y: 200)
            }
            Circle().fill(RadialGradient(colors: [.yellow.opacity(0.5), .clear], center: .center, startRadius: 2, endRadius: 80))
                .frame(width: 160).offset(x: doorX - 80 + 90, y: 170)
        }
        .allowsHitTesting(false)
    }
}

/// A night road out in the country: hills, trees, the odd lamp post, and the road itself.
struct RoadScene: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom).frame(width: width, height: 520)
            ForEach(0..<Int(width / 700) + 1, id: \.self) { i in
                Ellipse().fill(Color(red: 0.14, green: 0.22, blue: 0.24)).frame(width: 900, height: 300).position(x: CGFloat(i) * 700 + 200, y: 470)
            }
            ForEach(0..<Int(width / 260), id: \.self) { i in
                if i % 4 == 0 {
                    ZStack(alignment: .top) {
                        Rectangle().fill(Color(white: 0.2)).frame(width: 8, height: 220)
                        Circle().fill(Color.yellow).frame(width: 18).shadow(color: .yellow, radius: 14)
                    }
                    .position(x: CGFloat(i) * 260 + 80, y: 420)
                } else {
                    ZStack(alignment: .bottom) {
                        Rectangle().fill(Color(red: 0.25, green: 0.16, blue: 0.10)).frame(width: 14, height: 80)
                        Circle().fill(Color(red: 0.10, green: 0.28, blue: 0.18)).frame(width: 110).offset(y: -60)
                    }
                    .position(x: CGFloat(i) * 260 + 80, y: 470)
                }
            }
            Rectangle().fill(Color(red: 0.20, green: 0.20, blue: 0.25)).frame(width: width, height: 190).offset(y: 510)
            ForEach(0..<Int(width / 240), id: \.self) { i in
                Rectangle().fill(.white.opacity(0.5)).frame(width: 90, height: 6).offset(x: CGFloat(i) * 240, y: 618)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// A folded paper lantern, glowing.
struct PaperLanternView: View {
    let seed: Int

    var body: some View {
        let color = [Color.orange, .red, .pink, .yellow, .cyan, .green][abs(seed) % 6]
        ZStack {
            Ellipse().fill(RadialGradient(colors: [color.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 34)).frame(width: 70, height: 50)
            RoundedRectangle(cornerRadius: 12).fill(color).frame(width: 30, height: 34)
            ForEach(0..<3, id: \.self) { i in
                Rectangle().fill(.black.opacity(0.15)).frame(width: 30, height: 2).offset(y: CGFloat(i - 1) * 9)
            }
            Capsule().fill(Color(white: 0.25)).frame(width: 18, height: 5).offset(y: -18)
            Capsule().fill(Color(white: 0.25)).frame(width: 18, height: 5).offset(y: 18)
        }
        .shadow(color: color, radius: 8)
        .frame(width: 70, height: 50)
        .offset(y: -14)
    }
}

struct LeafPileView: View {
    let seed: Int

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Ellipse().fill([Color.orange, .brown, .red, .yellow][(i + seed) % 4].opacity(0.9))
                    .frame(width: 22, height: 11)
                    .rotationEffect(.degrees(Double((i * 47 + seed) % 180)))
                    .offset(x: CGFloat(i % 3) * 14 - 14, y: CGFloat(i / 3) * 7 - 4)
            }
        }
        .frame(width: 64, height: 28)
    }
}

struct WeedView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<5, id: \.self) { i in
                Capsule().fill(Color(red: 0.25, green: 0.55, blue: 0.20)).frame(width: 6, height: 30)
                    .rotationEffect(.degrees(Double(i - 2) * 24), anchor: .bottom)
            }
            Circle().fill(.yellow).frame(width: 8).offset(x: 9, y: -26)
        }
        .frame(width: 44, height: 36, alignment: .bottom)
    }
}

/// A garden rake lying on the lawn, tines up. Step on it and BONK.
struct RakeView: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.55, green: 0.38, blue: 0.22)).frame(width: 90, height: 6)
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { _ in Rectangle().fill(Color(white: 0.55)).frame(width: 3, height: 12) }
            }
            .offset(x: 40, y: -5)
        }
        .frame(width: 100, height: 22)
    }
}

struct TrafficConeView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Triangle().fill(Color.orange).frame(width: 34, height: 46).offset(y: -6)
            Rectangle().fill(.white).frame(width: 20, height: 6).offset(y: -22)
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.85, green: 0.4, blue: 0.1)).frame(width: 44, height: 8)
        }
        .frame(width: 46, height: 54, alignment: .bottom)
    }
}

struct GrandfatherClockView: View {
    let wound: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { ctx in
            let swing = sin(ctx.date.timeIntervalSinceReferenceDate * (wound ? 3 : 0.6)) * 18
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.40, green: 0.24, blue: 0.14)).frame(width: 90, height: 290)
                Circle().fill(Color(red: 1, green: 0.96, blue: 0.85)).frame(width: 64).offset(y: 14)
                Capsule().fill(.black).frame(width: 3, height: 24).offset(y: 22)
                Capsule().fill(.black).frame(width: 3, height: 18).rotationEffect(.degrees(wound ? 90 : 40), anchor: .bottom).offset(y: 28)
                RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.35)).frame(width: 56, height: 160).offset(y: 100)
                Capsule().fill(Palette.gold).frame(width: 4, height: 110).offset(y: 106).rotationEffect(.degrees(swing), anchor: .top)
            }
            .frame(width: 100, height: 300, alignment: .top)
        }
        .frame(width: 100, height: 300)
    }
}

struct FishbowlView: View {
    let fed: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.35)).frame(width: 80)
                Circle().stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 80)
                Image(systemName: "fish.fill").font(.system(size: 24)).foregroundStyle(.orange).offset(x: fed ? 6 : -8, y: 6)
                if fed { Circle().fill(Color.brown).frame(width: 5).offset(x: -10, y: -16) }
            }
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.45, green: 0.30, blue: 0.20)).frame(width: 110, height: 100)
        }
    }
}

struct PhotoShelfView: View {
    let dusted: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    PictureFrame(seed: i + 6).scaleEffect(0.5).frame(width: 56, height: 46)
                }
            }
            .overlay { if !dusted { Rectangle().fill(Color(white: 0.7).opacity(0.45)) } }
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.20)).frame(width: 250, height: 12)
            Spacer().frame(height: 120)
        }
        .frame(width: 260, height: 190)
    }
}
