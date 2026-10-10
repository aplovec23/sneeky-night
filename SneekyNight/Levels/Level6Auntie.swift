import SwiftUI
import Observation

/// One of Auntie's chores.
struct Chore: Identifiable {
    let id: String
    let title: String
    /// How many presses, places or things it takes.
    var needed: Int
    var done = 0
    var finished: Bool { done >= needed }
    var label: String { needed > 1 ? "\(title) (\(min(done, needed))/\(needed))" : title }
}

/// Level 6 rules: Auntie knows where Grandpa is, but first she wants her 10 chores done.
/// The house has a downstairs and an upstairs. Each chore is done by pressing E at the right
/// thing (some need several presses or several places), sweeping is done by walking over the
/// dust, and the rubbish bag has to be carried to the bin. Her cats sleep on the floor:
/// stepping on one costs time. When every chore is ticked, Auntie walks to the back door;
/// follow her out to the backyard to win. There's nobody to catch you here, only the clock.
@MainActor
@Observable
final class AuntieModel {
    enum Floor { case down, up }
    enum Phase { case chores, following, over }

    let engine = GameEngine()
    var floor: Floor = .down
    var phase: Phase = .chores
    var chores: [Chore] = []
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var auntie = CGPoint(x: 700, y: 590)
    var auntieWalking = false
    var auntieRight = true
    var auntieSays: String?
    var doorOpen = false
    let belt = ItemBelt()

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored private var saved: [Floor: [Thing]] = [:]
    @ObservationIgnored private var glassesIn = ""
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var sayTime = 0.0

    static let floorBand: ClosedRange<CGFloat> = 545...690
    static let downWidth: CGFloat = 3600
    static let upWidth: CGFloat = 2400
    static let choreCount = 10
    static let backDoor: CGFloat = 3440

    /// How much of the counted chores there is: less on Easy, more on Hard and above.
    private static func amount(_ easy: Int, _ mild: Int, _ hard: Int) -> Int { Difficulty.current.pick(easy: easy, mild: mild, hard: hard) }

    var choresDone: Int { chores.filter(\.finished).count }
    var nextChore: Chore? { chores.first { !$0.finished } }

    /// The list along the bottom of the screen.
    var cornerText: String {
        if phase != .chores { return "All \(Self.choreCount) chores done! Follow Auntie to the back door." }
        return "Chores \(choresDone)/\(Self.choreCount)   ·   next: \(nextChore?.label ?? "")"
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
        chores = [
            Chore(id: "dishes", title: "Wash the dishes", needed: 3),
            Chore(id: "cats", title: "Fill the cat bowls", needed: Self.amount(1, 2, 3)),
            Chore(id: "plants", title: "Water the plants", needed: Self.amount(2, 4, 7)),
            Chore(id: "sweep", title: "Sweep up the dust", needed: Self.amount(3, 5, 9)),
            Chore(id: "trash", title: "Take out the rubbish", needed: 1),
            Chore(id: "table", title: "Set the table", needed: 3),
            Chore(id: "shelf", title: "Dust the bookshelf", needed: 3),
            Chore(id: "bed", title: "Make the bed", needed: 2),
            Chore(id: "socks", title: "Pick up the socks", needed: Self.amount(2, 4, 7)),
            Chore(id: "glasses", title: "Find Auntie's glasses", needed: 1),
        ]
        let down = Self.downThings(), up = Self.upThings()
        saved = [.up: up]
        glassesIn = (down + up).filter { $0.kind == "drawer" || $0.kind == "box" }.map(\.id).randomElement() ?? ""
        floor = .down
        engine.load(SceneLayout(width: Self.downWidth, floor: Self.floorBand, things: down, spawn: CGPoint(x: 240, y: 620)))
        engine.usesHP = false
        engine.timeLeft = Levels.time(6)
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
        phase = .chores
        inventory = []
        popup = nil
        banner = nil
        bannerTime = 0
        doorOpen = false
        auntie = CGPoint(x: 700, y: 590)
        auntieWalking = false
        engine.running = true
        speak("Ten chores, dear. Then I'll show you something.", 4)
    }

    // MARK: The house

    private typealias H = HallwayModel

    private static func spot(_ id: String, _ kind: String, x: CGFloat, y: CGFloat, size: CGSize, prompt: String?) -> Thing {
        Thing(id: id, kind: kind, pos: CGPoint(x: x, y: y), footprint: size, prompt: prompt, reach: CGSize(width: 70, height: 50), flat: true)
    }

    private static func cat(_ id: String, x: CGFloat, y: CGFloat, wanders: Bool) -> Thing {
        var cat = Thing(id: id, kind: "cat", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 62, height: 24), hazard: .cat)
        // On Hard and above the cats don't stay asleep: they pad up and down.
        if wanders {
            cat.patrol = (x - 220)...(x + 220)
            cat.speed = 90
        }
        return cat
    }

    static func downThings() -> [Thing] {
        let mode = Difficulty.current
        var things: [Thing] = [
            H.onWall("frontDoor", "frontDoor", x: 110, prompt: "Look outside"),
            H.onWall("bin", "bin", x: 330, prompt: "Put rubbish in the bin", reach: 60),
            H.onWall("shelf", "shelf", x: 560, prompt: "Dust the bookshelf", reach: 70),
            H.onWall("drawer1", "drawer", x: 900, prompt: "Look in the drawer"),
            H.onWall("stairs", "stairsUp", x: 1250, prompt: "Go upstairs", reach: 80),
            H.onWall("table", "dinner", x: 1620, prompt: "Set the table", reach: 110),
            H.onWall("bowls", "bowls", x: 1960, prompt: "Fill a cat bowl", reach: 70),
            H.onWall("sink", "sink", x: 2330, prompt: "Wash the dishes", reach: 90),
            H.onWall("drawer2", "drawer", x: 2680, prompt: "Look in the drawer"),
            H.onWall("backDoor", "backDoor", x: backDoor, prompt: "It's locked", reach: 90),
            Thing(id: "bag", kind: "bag", pos: CGPoint(x: 2880, y: 640), footprint: CGSize(width: 54, height: 26), solid: true, movable: true),
            H.box("box1", x: 3120, y: 600),
            cat("cat1", x: 760, y: 650, wanders: mode.atLeastHard),
            cat("cat2", x: 2100, y: 600, wanders: false),
        ]
        if mode.atLeastHard { things.append(cat("cat3", x: 3000, y: 670, wanders: mode.atLeastChaos)) }
        return things + extras(down: true)
    }

    static func upThings() -> [Thing] {
        let mode = Difficulty.current
        var things: [Thing] = [
            H.onWall("stairs", "stairsDown", x: 130, prompt: "Go downstairs", reach: 80),
            H.onWall("drawer3", "drawer", x: 480, prompt: "Look in the drawer"),
            H.onWall("bed", "bed", x: 980, prompt: "Make the bed", reach: 140),
            H.onWall("drawer4", "drawer", x: 1420, prompt: "Look in the drawer"),
            H.box("box2", x: 1700, y: 640),
            H.onWall("study", "study", x: 2230, prompt: "Try the door", reach: 80),
            cat("cat4", x: 1200, y: 660, wanders: mode.atLeastChaos),
        ]
        if mode != .easy { things.append(cat("cat5", x: 1950, y: 600, wanders: false)) }
        return things + extras(down: false)
    }

    /// Plants to water, dust to sweep and socks to pick up, shared out between the two floors.
    private static func extras(down: Bool) -> [Thing] {
        var things: [Thing] = []
        let width = down ? downWidth : upWidth
        func share(_ total: Int) -> Int { down ? (total + 1) / 2 : total / 2 }
        let plants = share(amount(2, 4, 7))
        // Spots along the wall that are clear of the furniture.
        let pots: [CGFloat] = down ? [1080, 2130, 2900, 440] : [720, 1900, 1200, 300]
        for i in 0..<min(plants, pots.count) {
            let x = pots[i]
            things.append(H.onWall("\(down ? "d" : "u")plant\(i)", "houseplant", x: x, prompt: "Water the plant", reach: 55))
        }
        let dust = share(amount(3, 5, 9))
        for i in 0..<dust {
            let x = 460 + CGFloat(i) * (width - 800) / CGFloat(max(dust, 1))
            things.append(spot("\(down ? "d" : "u")dust\(i)", "dust", x: x, y: [600, 670, 630][i % 3], size: CGSize(width: 50, height: 20), prompt: nil))
        }
        let socks = share(amount(2, 4, 7))
        for i in 0..<socks {
            let x = 620 + CGFloat(i) * (width - 1000) / CGFloat(max(socks, 1))
            things.append(spot("\(down ? "d" : "u")sock\(i)", "sock", x: x, y: [680, 585, 650][i % 3], size: CGSize(width: 36, height: 16), prompt: "Pick up the sock"))
        }
        return things
    }

    private func go(to newFloor: Floor) {
        Sound.door.play(volume: 0.5)
        saved[floor] = engine.things
        let down = newFloor == .down
        engine.load(SceneLayout(width: down ? Self.downWidth : Self.upWidth, floor: Self.floorBand, things: saved[newFloor] ?? [],
                                spawn: CGPoint(x: down ? 1250 : 240, y: 600)))
        floor = newFloor
    }

    // MARK: Chores

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
        guard phase != .over else { return }
        // Sweeping: just walk over the dust.
        if let i = engine.things.firstIndex(where: {
            $0.kind == "dust" && !$0.hidden && abs($0.pos.x - engine.player.x) < 40 && abs($0.pos.y - engine.player.y) < 30
        }), engine.z < 20 {
            engine.things[i].hidden = true
            Sound.rustle.play(volume: 0.5)
            progress("sweep")
        }
        if phase == .following { lead(dt) }
    }

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "stairsUp": go(to: .up)
        case "stairsDown": go(to: .down)
        case "frontDoor": engine.say("Uncle's car has gone. No going back now!")
        case "study": engine.say("Locked. I can hear paper rustling inside... Grandpa's letters?", seconds: 3.2)
        case "sink": work(i, "dishes", sound: .water, left: "Wash the dishes")
        case "dinner": work(i, "table", sound: .drawer, left: "Set the table")
        case "shelf": work(i, "shelf", sound: .rustle, left: "Dust the bookshelf")
        case "bed": work(i, "bed", sound: .closet, left: "Make the bed")
        case "bowls": work(i, "cats", sound: .box, left: "Fill a cat bowl")
        case "houseplant":
            engine.things[i].open = true
            engine.things[i].prompt = nil
            Sound.water.play(volume: 0.6)
            progress("plants")
        case "sock":
            engine.things[i].hidden = true
            Sound.paper.play(volume: 0.5)
            progress("socks")
        case "bin":
            if engine.carrying == "bag" {
                engine.carrying = nil
                if let bag = engine.index(of: "bag") { engine.things[bag].hidden = true }
                Sound.box.play()
                progress("trash")
            } else if chore("trash")?.finished == true {
                engine.say("The rubbish is already out.")
            } else {
                engine.say("The rubbish bag is by the kitchen. Pick it up with the box button (R) and bring it here.", seconds: 3.5)
            }
        case "drawer", "box": search(i)
        case "backDoor":
            if phase == .following && abs(auntie.x - Self.backDoor) < 260 {
                win()
            } else if phase == .following {
                engine.say("I should wait for Auntie.")
            } else {
                engine.say("Locked. Auntie has the key. \(Self.choreCount - choresDone) chores to go.")
            }
        default: break
        }
    }

    private func chore(_ id: String) -> Chore? { chores.first { $0.id == id } }

    /// A chore done by pressing E a few times at one thing.
    private func work(_ i: Int, _ id: String, sound: Sound, left: String) {
        guard let chore = chore(id), !chore.finished else {
            engine.say("That's done already.")
            return
        }
        sound.play(volume: 0.7)
        progress(id)
        if self.chore(id)?.finished == true { engine.things[i].open = true }
    }

    private func search(_ i: Int) {
        engine.things[i].open = true
        Sound.drawer.play()
        if engine.things[i].id == glassesIn && chore("glasses")?.finished == false {
            inventory.append(InventoryItem(id: "glasses", symbol: "eyeglasses", color: .cyan))
            progress("glasses")
            engine.say("Auntie's glasses! In here the whole time.", seconds: 2.2)
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else {
            engine.say(["Buttons. So many buttons.", "Cat toys.", "Old postcards from Grandpa!", "Knitting wool."].randomElement()!)
        }
    }

    private func progress(_ id: String) {
        guard let n = chores.firstIndex(where: { $0.id == id }), !chores[n].finished else { return }
        chores[n].done += 1
        guard chores[n].finished else { return }
        Sound.powerup.play()
        banner = "Checkpoint! \(chores[n].title): done. \(choresDone)/\(Self.choreCount)"
        bannerTime = 2.2
        speak(["Good.", "Very nice, dear.", "Your Grandpa would be proud.", "Hm. Not bad at all.", "That's the way."].randomElement()!, 2.4)
        if choresDone == Self.choreCount { allDone() }
    }

    private func allDone() {
        phase = .following
        engine.timerOn = false
        if floor == .down, let door = engine.index(of: "backDoor") { engine.things[door].prompt = "Go out to the backyard" }
        if var down = saved[.down], let door = down.firstIndex(where: { $0.id == "backDoor" }) {
            down[door].prompt = "Go out to the backyard"
            saved[.down] = down
        }
        banner = "Checkpoint! All \(Self.choreCount) chores done. Follow Auntie!"
        bannerTime = 4
        speak("All ten! Come along. There's something in the backyard you should see.", 5)
    }

    /// Auntie walks to the back door, never faster than you, and waits if you fall behind.
    private func lead(_ dt: Double) {
        guard floor == .down else {
            auntieWalking = false
            return
        }
        let target = CGPoint(x: Self.backDoor - 110, y: 590)
        let dx = target.x - auntie.x
        let tooFarAhead = auntie.x - engine.player.x > 420
        if abs(dx) > 6 && !tooFarAhead {
            auntie.x += (dx > 0 ? 1 : -1) * min(abs(dx), min(200, max(110, engine.pace)) * CGFloat(dt))
            auntieRight = dx > 0
            auntieWalking = true
        } else {
            auntieWalking = false
            if abs(dx) <= 6 && !doorOpen {
                doorOpen = true
                Sound.unlock.play()
                speak("Here we are. After you, dear.", 4)
            } else if tooFarAhead && auntieSays == nil {
                speak("Keep up, dear!", 2)
            }
        }
    }

    private func speak(_ text: String, _ seconds: Double) {
        auntieSays = text
        sayTime = seconds
    }

    /// Where the Guide should lead you (and what the lightbulb points at): the next chore.
    private func goal() -> CGPoint? {
        if phase != .chores { return engine.spot("backDoor") ?? engine.spot("stairs") }
        guard let next = nextChore else { return nil }
        let kinds: [String: [String]] = ["dishes": ["sink"], "cats": ["bowls"], "plants": ["houseplant"], "sweep": ["dust"],
                                         "trash": [engine.carrying == "bag" ? "bin" : "bag"], "table": ["dinner"], "shelf": ["shelf"],
                                         "bed": ["bed"], "socks": ["sock"], "glasses": ["drawer", "box"]]
        let wanted = kinds[next.id] ?? []
        let here = engine.things.filter { wanted.contains($0.kind) && !$0.hidden && !($0.open && $0.kind != "bag") }
        if let nearest = here.min(by: { abs($0.pos.x - engine.player.x) < abs($1.pos.x - engine.player.x) }) { return nearest.pos }
        // Nothing left for it on this floor: it's on the other one.
        return engine.spot("stairs")
    }

    // MARK: Trouble

    private func steppedOn(_ i: Int) {
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard phase == .chores, !engine.safe else { return }
        let lost = (15 * Difficulty.current.damageScale).rounded()
        engine.timeLeft = max(1, engine.timeLeft - lost)
        banner = "MEOW! Auntie: \"Mind my cats!\"  −\(Int(lost)) seconds"
        bannerTime = 2.6
    }

    private func tooLoud() {
        engine.resetNoise()
        guard phase == .chores, !engine.safe else { return }
        engine.timeLeft = max(1, engine.timeLeft - 20)
        banner = "Auntie: \"Shh! You'll wake the whole street!\"  −20 seconds"
        bannerTime = 2.6
    }

    private func tooSlow() {
        guard phase == .chores else { return }
        award(.amNotPm)
        phase = .over
        engine.running = false
        Sound.caught.play()
        show(Popup(title: "Too slow!", message: "Auntie: \"Look at the time! Off to bed with you. We'll try again tomorrow.\"\nYou did \(choresDone) of \(Self.choreCount) chores.",
                   symbol: "clock.badge.exclamationmark.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func win() {
        phase = .over
        engine.running = false
        onComplete()
        Sound.door.play()
        Sound.win.play()
        show(Popup(title: "Level Complete!", message: "Auntie opens the door to her backyard. Something out there is glowing...",
                   symbol: "star.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
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
        engine.running = phase != .over
    }

    func hint() {
        if phase != .chores {
            engine.say(floor == .up ? "Auntie is downstairs. Take the stairs!" : "Follow Auntie to the back door at the far right, then press E.")
            return
        }
        guard let next = nextChore else { return }
        let whereTo: [String: String] = [
            "dishes": "The sink is in the kitchen, downstairs on the right. Press E three times.",
            "cats": "The cat bowls are downstairs, next to the table. Press E once for each bowl.",
            "plants": "Press E at every plant pot. Some are upstairs.",
            "sweep": "Just walk over every little pile of dust. Some are upstairs.",
            "trash": "Pick up the rubbish bag near the kitchen with R, carry it to the bin by the front door, and press E at the bin.",
            "table": "The dinner table is downstairs in the middle. Press E three times.",
            "shelf": "The bookshelf is downstairs near the front door. Press E three times.",
            "bed": "The bed is upstairs. Press E twice.",
            "socks": "Press E at each sock on the floor. Some are upstairs.",
            "glasses": "Auntie's glasses are in a drawer or a box somewhere. Press E at each one.",
        ]
        engine.say("Next: \(next.label). \(whereTo[next.id] ?? "")", seconds: 4.5)
    }
}

// MARK: - View

struct AuntieLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = AuntieModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: model.floor == .down ? "Level 6 · Auntie's House" : "Level 6 · Upstairs",
                      inventory: model.inventory, popup: model.popup, banner: model.banner, belt: model.belt,
                      cornerHint: model.cornerText, guideTips: GuideTips.level6,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            EmptyView()
        }
        .onAppear {
            model.onComplete = { game.complete(level: 6) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { game.award($0) }
            model.onRetry = { game.noteRetry() }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            AuntieWall(width: engine.width, upstairs: model.floor == .up)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.floor == .down {
                AuntieView(walking: model.auntieWalking)
                    .scaleEffect(x: model.auntieRight ? 1 : -1, y: 1)
                    .anchored(at: model.auntie)
                if let text = model.auntieSays {
                    SpeechBubble(text: "Auntie: \(text)", tint: .teal, small: true)
                        .position(x: model.auntie.x, y: model.auntie.y - 280)
                }
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { thing in
                floorItem(thing)
            }
            Palette.shade.opacity(0.14 * Palette.shadeAmount)
        }
        .frame(width: engine.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "frontDoor": DoorView(color: Color(red: 0.95, green: 0.78, blue: 0.2)) { EmptyView() }
        case "backDoor": DoorView(color: Color(red: 0.25, green: 0.50, blue: 0.40), open: model.doorOpen) { DoorSign(text: "BACKYARD", color: .green) }
        case "study": DoorView(color: Color(red: 0.35, green: 0.25, blue: 0.45)) { DoorSign(text: "STUDY", color: .purple) }
        case "stairsUp": StairsDoorView(up: true)
        case "stairsDown": StairsDoorView(up: false)
        case "bin": BinView()
        case "shelf": BookshelfView().overlay(alignment: .top) { doneTick(thing.open) }
        case "drawer": DresserView(open: thing.open)
        case "dinner": DinnerTableView(set: thing.open)
        case "bowls": CatBowlsView(full: thing.open)
        case "sink": KitchenSinkView(clean: thing.open)
        case "bed": MomBedView(empty: true).overlay(alignment: .top) { doneTick(thing.open) }
        case "houseplant": HousePlantView(watered: thing.open)
        default: EmptyView()
        }
    }

    @ViewBuilder private func doneTick(_ done: Bool) -> some View {
        if done {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(.green)
                .background(Circle().fill(.white).padding(4)).offset(y: -20)
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "cat": SleepingCatView(awake: thing.patrol != nil, facingRight: thing.speed > 0)
        case "dust": DustPileView()
        case "sock": SockView(seed: thing.id.count + Int(thing.pos.x))
        case "bag": RubbishBagView()
        case "box": CardboardBox(open: thing.open)
        default: EmptyView()
        }
    }
}

// MARK: - Art

/// Auntie: in her dressing gown, hair in a bun, glasses pushed up (when she can find them).
struct AuntieView: View {
    var walking = false

    var body: some View {
        MomView(stunned: false, walking: walking, robe: Color(red: 0.20, green: 0.55, blue: 0.55))
            .overlay(alignment: .top) {
                // A grey bun on top
                Circle().fill(Color(white: 0.78)).frame(width: 36).offset(x: -8, y: -14)
            }
    }
}

struct AuntieWall: View {
    let width: CGFloat
    let upstairs: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: upstairs ? [Color(red: 0.30, green: 0.28, blue: 0.42), Color(red: 0.40, green: 0.34, blue: 0.48)]
                                            : [Color(red: 0.36, green: 0.30, blue: 0.24), Color(red: 0.46, green: 0.38, blue: 0.28)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            // Wallpaper: little paw prints
            ForEach(0..<Int(width / 150), id: \.self) { i in
                Image(systemName: "pawprint.fill").font(.system(size: 20)).foregroundStyle(.white.opacity(0.06))
                    .position(x: CGFloat(i) * 150 + 70, y: i % 2 == 0 ? 170 : 300)
            }
            Rectangle().fill(.black.opacity(0.18)).frame(width: width, height: 14).offset(y: 531)
            Rectangle().fill(upstairs ? Color(red: 0.45, green: 0.36, blue: 0.30) : Color(red: 0.55, green: 0.42, blue: 0.28))
                .frame(width: width, height: 155).offset(y: 545)
            ForEach(0..<Int(width / 110), id: \.self) { i in
                Rectangle().fill(.black.opacity(0.08)).frame(width: 2, height: 155).offset(x: CGFloat(i) * 110, y: 545)
            }
            // Windows and framed cats
            ForEach(0..<Int(width / 900), id: \.self) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: 150, height: 130)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 8))
                    .position(x: CGFloat(i) * 900 + 760, y: 250)
                PictureFrame(seed: i * 3 + 1).position(x: CGFloat(i) * 900 + 1150, y: 240)
            }
            // A rug
            Ellipse().fill(Color(red: 0.55, green: 0.25, blue: 0.30).opacity(0.7)).frame(width: 620, height: 110).position(x: width * 0.45, y: 630)
            Ellipse().stroke(Palette.gold.opacity(0.5), lineWidth: 4).frame(width: 560, height: 86).position(x: width * 0.45, y: 630)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

struct SleepingCatView: View {
    let awake: Bool
    let facingRight: Bool

    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.90, green: 0.60, blue: 0.25)).frame(width: 40, height: 9).rotationEffect(.degrees(awake ? -40 : 10)).offset(x: -36, y: awake ? -8 : 6)
            Ellipse().fill(Color(red: 0.95, green: 0.65, blue: 0.28)).frame(width: 66, height: awake ? 30 : 34)
            Circle().fill(Color(red: 0.95, green: 0.65, blue: 0.28)).frame(width: 30).offset(x: 28, y: awake ? -14 : -4)
            Triangle().fill(Color(red: 0.85, green: 0.52, blue: 0.20)).frame(width: 11, height: 12).offset(x: 20, y: awake ? -30 : -20)
            Triangle().fill(Color(red: 0.85, green: 0.52, blue: 0.20)).frame(width: 11, height: 12).offset(x: 36, y: awake ? -30 : -20)
            if awake {
                Circle().fill(.black).frame(width: 4).offset(x: 24, y: -15)
                Circle().fill(.black).frame(width: 4).offset(x: 34, y: -15)
            } else {
                Capsule().fill(.black.opacity(0.7)).frame(width: 7, height: 2).offset(x: 24, y: -4)
                Capsule().fill(.black.opacity(0.7)).frame(width: 7, height: 2).offset(x: 34, y: -4)
                Text("z").font(.game(16, .heavy)).foregroundStyle(.white.opacity(0.8)).offset(x: 48, y: -26)
            }
        }
        .frame(width: 100, height: 50)
        .scaleEffect(x: awake && !facingRight ? -1 : 1, y: 1)
    }
}

struct DustPileView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(white: 0.75).opacity(0.75)).frame(width: 54, height: 18)
            Circle().fill(Color(white: 0.85).opacity(0.8)).frame(width: 18).offset(x: -10, y: -6)
            Circle().fill(Color(white: 0.8).opacity(0.8)).frame(width: 14).offset(x: 10, y: -5)
        }
        .frame(width: 60, height: 30)
    }
}

struct SockView: View {
    let seed: Int

    var body: some View {
        let color = [Color.red, .blue, .green, .purple, .orange][abs(seed) % 5]
        ZStack {
            Capsule().fill(color).frame(width: 14, height: 26).offset(x: -6, y: -6)
            Capsule().fill(color).frame(width: 26, height: 13).offset(x: 2, y: 6)
            Rectangle().fill(.white).frame(width: 14, height: 5).offset(x: -6, y: -16)
        }
        .frame(width: 40, height: 40)
    }
}

struct RubbishBagView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.16)).frame(width: 60, height: 62)
            Triangle().fill(Color(white: 0.16)).frame(width: 30, height: 22).offset(y: -58)
            Capsule().fill(Color.yellow).frame(width: 26, height: 5).offset(y: -58)
        }
        .frame(width: 70, height: 90, alignment: .bottom)
    }
}

struct HousePlantView: View {
    let watered: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<5, id: \.self) { i in
                Ellipse().fill(watered ? Color(red: 0.20, green: 0.62, blue: 0.30) : Color(red: 0.50, green: 0.52, blue: 0.25))
                    .frame(width: 24, height: 80)
                    .rotationEffect(.degrees(Double(i - 2) * (watered ? 22 : 34)), anchor: .bottom)
                    .offset(y: -44)
            }
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.70, green: 0.42, blue: 0.26)).frame(width: 56, height: 50)
            if watered {
                Image(systemName: "drop.fill").font(.system(size: 18)).foregroundStyle(.cyan).offset(y: -130)
            }
        }
        .frame(width: 110, height: 150, alignment: .bottom)
    }
}

struct CatBowlsView: View {
    let full: Bool

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<2, id: \.self) { _ in
                ZStack(alignment: .top) {
                    Trapezoid().fill(Color(red: 0.85, green: 0.30, blue: 0.35)).frame(width: 54, height: 22)
                    if full { Ellipse().fill(Color(red: 0.55, green: 0.35, blue: 0.20)).frame(width: 40, height: 10).offset(y: -3) }
                }
            }
        }
        .frame(width: 130, height: 30, alignment: .bottom)
    }
}

struct DinnerTableView: View {
    let set: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.42, green: 0.28, blue: 0.18)).frame(width: 12, height: 90).offset(x: -90)
            Rectangle().fill(Color(red: 0.42, green: 0.28, blue: 0.18)).frame(width: 12, height: 90).offset(x: 90)
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.38, blue: 0.24)).frame(width: 230, height: 16).offset(y: -90)
            if set {
                HStack(spacing: 26) {
                    ForEach(0..<3, id: \.self) { _ in
                        ZStack {
                            Ellipse().fill(.white).frame(width: 40, height: 10)
                            RoundedRectangle(cornerRadius: 3).fill(Color.cyan.opacity(0.7)).frame(width: 12, height: 18).offset(x: 24, y: -8)
                        }
                    }
                }
                .offset(y: -106)
            }
        }
        .frame(width: 240, height: 130, alignment: .bottom)
    }
}

struct KitchenSinkView: View {
    let clean: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.40, green: 0.28, blue: 0.20)).frame(width: 220, height: 104)
            Rectangle().fill(Color(red: 0.85, green: 0.83, blue: 0.78)).frame(width: 236, height: 14).offset(y: -104)
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.72)).frame(width: 110, height: 12).offset(y: -112)
            Capsule().fill(Color(white: 0.6)).frame(width: 8, height: 44).offset(y: -118)
            if clean {
                Image(systemName: "sparkles").font(.system(size: 30, weight: .bold)).foregroundStyle(.cyan).offset(x: 60, y: -130)
            } else {
                // A wobbly stack of dirty plates
                ForEach(0..<4, id: \.self) { i in
                    Ellipse().fill(Color(white: 0.9)).frame(width: 46, height: 9).offset(x: 62 + CGFloat(i % 2) * 5, y: -118 - CGFloat(i) * 8)
                }
            }
        }
        .frame(width: 240, height: 190, alignment: .bottom)
    }
}
