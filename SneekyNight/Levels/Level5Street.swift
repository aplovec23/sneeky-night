import SwiftUI
import Observation

/// Someone walking about in Level 5: a stranger, a rat, a hotel guard or a hotel worker.
struct Walker: Identifiable {
    enum Kind { case stranger, rat, guardian, worker }

    let id: Int
    var kind: Kind
    var pos: CGPoint
    /// They walk back and forth between these x positions.
    var range: ClosedRange<CGFloat>
    /// Signed: positive walks right.
    var speed: CGFloat
    var style = 0
    /// Seconds left standing still at the end of the walk.
    var wait = 0.0
    var facingRight = true
    /// A rat that got its snack (or gave up) and is running off.
    var leaving = false
    var life = 0.0
}

/// Level 5 rules: the first level with a health bar. Strangers on the street hurt you if you
/// touch them (jump over them, or hide in a bus stop). Feed all 15 dogs: snacks come from the
/// fridge at home, 5 at a time, and Mom is in the kitchen cooking an early breakfast — sneak past
/// while her back is turned, or crouch under a table. Rats take a snack and leave an accessory.
/// Then get past the hotel guards and the workers in the lobby (the first floor), take the elevator
/// and find Uncle's room: a different floor and door every try, and no hints (except from the Guide
/// in practice mode). Open his door with the dog's blue key from Level 3, and ask him for a ride.
@MainActor
@Observable
final class StreetModel {
    enum Area { case street, kitchen, lobby, upstairs, office }
    enum Phase { case sneaking, over }
    enum Cooking { case atStove, toSink, atSink, toStove }

    let engine = GameEngine()
    var area: Area = .street
    var phase: Phase = .sneaking
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var hidingIn: String?
    var doorOpen = false
    /// The elevator's floor buttons are on screen.
    var elevatorOpen = false
    /// The floor you're on (1 is the lobby).
    var currentFloor = 1
    /// Where Uncle's room is this time: a random floor (2–11) and one of the corridor's doors.
    var uncleFloor = 2
    /// Workers who have already walked past your hiding place this time (Chaos and above: they may look).
    @ObservationIgnored private var checkedBy: Set<Int> = []
    var uncleDoorIndex = 0
    var snacks = 0
    var fed = 0
    var walkers: [Walker] = []
    /// Mom in the kitchen.
    var momX: CGFloat = 620
    var cooking: Cooking = .atStove
    let chase = Chase()
    let belt = ItemBelt()

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    /// What a rat leaves behind (nil when you already own everything).
    @ObservationIgnored var ratGift: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored private var saved: [Area: [Thing]] = [:]
    @ObservationIgnored private var streetWalkers: [Walker] = []
    @ObservationIgnored private var lobbyWalkers: [Walker] = []
    /// Answers through the doors of the rooms that aren't Uncle's.
    private static let wrongRoom = [
        "Zzz... go away...", "Room service? We didn't order anything!", "Shh! The baby's asleep!",
        "Who's there? ...Nobody? Okay.", "Not tonight, thank you!", "*loud snoring*",
    ]
    @ObservationIgnored private var cookTime = 4.5
    @ObservationIgnored private var ratIn = 14.0
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var nextID = 100

    static let floor: ClosedRange<CGFloat> = 545...690
    static let streetWidth: CGFloat = 5600
    static let kitchenWidth: CGFloat = 1500
    static let lobbyWidth: CGFloat = 2400
    static let corridorWidth: CGFloat = 2000
    static let officeWidth: CGFloat = 1000
    /// The elevator's 10 buttons: floors 2 to 11. Floor 1 is the lobby.
    /// Hard and above: 20 floors (2 to 21).
    static var floors: [Int] { Array(2...(Difficulty.current.atLeastHard ? 21 : 11)) }
    static let roomDoors: [CGFloat] = [520, 880, 1240, 1600]
    /// Uncle's room number, e.g. 703.
    var uncleRoom: Int { uncleFloor * 100 + uncleDoorIndex + 1 }
    /// Dogs to feed: 8 on Easy, 15 on Mild, 50 on Hard and above.
    static var dogCount: Int { Difficulty.current.pick(easy: 8, mild: 15, hard: 50) }
    /// With 50 dogs to feed you can carry more at once.
    static var snackLoad: Int { Difficulty.current.atLeastHard ? 10 : 5 }
    static let stove: CGFloat = 620
    static let sink: CGFloat = 980

    static let blueKey = InventoryItem(id: "blueKey", symbol: "key.fill", color: Color(red: 0.3, green: 0.55, blue: 1))

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onTimeUp = { [weak self] in self?.momAlarm(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momAlarm(tooLoud: true) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.chase.taunted() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onKO = { [weak self] in self?.knockedOut() }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.chase.stun(seconds, momOnly: momOnly) ?? false }
        // The golden stick: every stranger, guard, worker and rat is gone too, on every floor.
        belt.goldenStick = { [weak self] in
            guard let self else { return }
            walkers = []
            streetWalkers = []
            lobbyWalkers = []
        }
        chase.engine = engine
        chase.entrance = { [weak self] _ in self?.entrance() ?? (.zero, 2) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.onCaught = { [weak self] _, message in self?.caught(message) }
        chase.onGaveUp = { [weak self] _ in self?.gaveUp() }
        // Practice mode: the Guide leads the way, all the way to Uncle's room.
        engine.guideGoal = { [weak self] in self?.guideGoal() }
        reset()
    }

    private func guideGoal() -> CGPoint? {
        switch area {
        case .street:
            if fed == Self.dogCount { return engine.spot("hotelDoor") }
            if snacks == 0 { return engine.spot("houseDoor") }
            return engine.nearestSpot { $0.kind == "dog" && !$0.open }
        case .kitchen:
            return snacks == 0 && fed < Self.dogCount ? engine.spot("fridge") : engine.spot("streetDoor")
        case .lobby: return engine.spot("elevator")
        case .upstairs: return currentFloor == uncleFloor ? engine.spot("uncleDoor") : engine.spot("elevator")
        case .office: return engine.spot("uncle")
        }
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
        saved = [.kitchen: Self.kitchenThings(), .lobby: Self.lobbyThings(), .office: Self.officeThings()]
        streetWalkers = Self.strangersAndGuards()
        lobbyWalkers = Self.workers()
        walkers = streetWalkers
        area = .street
        engine.load(SceneLayout(width: Self.streetWidth, floor: Self.floor, things: Self.streetThings(), spawn: CGPoint(x: 260, y: 620)))
        engine.usesHP = true
        engine.timeLeft = Levels.time(5)
        engine.timerOn = true
        engine.resetNoise()
        engine.noiseFactor = 1
        engine.speedBoost = false
        engine.jumpBoost = false
        engine.shields = 0
        engine.runHeld = false
        engine.tauntOnly = false
        engine.speedBonus = 0
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        chase.reset()
        belt.reset()
        phase = .sneaking
        inventory = [Self.blueKey]
        popup = nil
        banner = nil
        bannerTime = 0
        hidingIn = nil
        doorOpen = false
        elevatorOpen = false
        currentFloor = 1
        // A new hiding place for Uncle every try.
        uncleFloor = Self.floors.randomElement()!
        uncleDoorIndex = Int.random(in: 0..<Self.roomDoors.count)
        snacks = 0
        fed = 0
        momX = Self.stove
        cooking = .atStove
        cookTime = 4.5
        ratIn = 14
        engine.running = true
        engine.say("15 hungry dogs out here... the snacks are in our fridge.", seconds: 3.5)
    }

    // MARK: Places

    private typealias H = HallwayModel

    static func streetThings() -> [Thing] {
        var things: [Thing] = [
            H.onWall("houseDoor", "houseDoor", x: 150, prompt: "Sneak back into the kitchen", reach: 90),
            H.onWall("stop1", "busStop", x: 1150, prompt: "Hide in the bus stop", reach: 90),
            H.onWall("stop2", "busStop", x: 2500, prompt: "Hide in the bus stop", reach: 90),
            H.onWall("stop3", "busStop", x: 3700, prompt: "Hide in the bus stop", reach: 90),
            H.onWall("stop4", "busStop", x: 4750, prompt: "Hide in the bus stop", reach: 90),
            H.obstacle("cans1", .cans, x: 900, y: 672, size: CGSize(width: 60, height: 24)),
            H.obstacle("cans2", .cans, x: 2140, y: 566, size: CGSize(width: 60, height: 24)),
            H.obstacle("cans3", .cans, x: 3300, y: 668, size: CGSize(width: 60, height: 24)),
            H.onWall("hotelDoor", "hotelDoor", x: 5290, prompt: "Sneak into the hotel", reach: 90),
        ]
        // Fifteen dogs spread along the street, near and far from the wall.
        let count = dogCount
        // They share the same stretch of street, so with 50 they stand close together.
        let gap = min(245, 3430 / CGFloat(max(count - 1, 1)))
        for i in 0..<count {
            let x = 520 + CGFloat(i) * gap
            let y: CGFloat = [585, 660, 610, 680, 570][i % 5]
            things.append(Thing(id: "dog\(i + 1)", kind: "dog", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 70, height: 22),
                                prompt: "Feed the dog", reach: CGSize(width: 80, height: 60)))
        }
        return things
    }

    static func strangersAndGuards() -> [Walker] {
        var list: [Walker] = []
        let lanes: [CGFloat] = [600, 650, 575, 675, 625, 590, 660, 610]
        for i in 0..<8 {
            let start = 600 + CGFloat(i) * 470
            list.append(Walker(id: i, kind: .stranger, pos: CGPoint(x: start + 150, y: lanes[i]), range: start...(start + 560),
                               speed: (i % 2 == 0 ? 1 : -1) * (95 + CGFloat(i % 3) * 25), style: i))
        }
        // Two guards walk up and down in front of the hotel with flashlights.
        list.append(Walker(id: 20, kind: .guardian, pos: CGPoint(x: 4550, y: 610), range: 4400...4900, speed: 120))
        list.append(Walker(id: 21, kind: .guardian, pos: CGPoint(x: 5150, y: 650), range: 4850...5220, speed: -105))
        return list
    }

    static func kitchenThings() -> [Thing] {
        [
            H.onWall("streetDoor", "streetDoor", x: 110, prompt: "Back to the street"),
            H.obstacle("table1", .table, x: 340, y: 630, size: CGSize(width: 110, height: 36)),
            H.obstacle("table2", .table, x: 1190, y: 630, size: CGSize(width: 110, height: 36)),
            H.obstacle("chair1", .chair, x: 800, y: 670, size: CGSize(width: 64, height: 30)),
            H.onWall("fridge", "fridge", x: 1390, prompt: "Grab snacks from the fridge", reach: 80),
        ]
    }

    static func lobbyThings() -> [Thing] {
        [
            H.onWall("lobbyDoor", "lobbyDoor", x: 110, prompt: "Back to the street"),
            H.onWall("plant1", "plant", x: 520, prompt: "Hide behind the plant", reach: 80),
            H.onWall("plant2", "plant", x: 1500, prompt: "Hide behind the plant", reach: 80),
            H.onWall("plant3", "plant", x: 1980, prompt: "Hide behind the plant", reach: 80),
            H.box("case1", x: 800, y: 660),
            H.box("case2", x: 1700, y: 600),
            H.onWall("elevator", "elevator", x: 2250, prompt: "Take the elevator", reach: 100),
        ]
    }

    /// An upstairs corridor: the elevator, four room doors and a plant to hide behind.
    func corridorThings(floor: Int) -> [Thing] {
        var things = [
            H.onWall("elevator", "elevator", x: 160, prompt: "Take the elevator", reach: 100),
            H.onWall("plant1", "plant", x: 1060, prompt: "Hide behind the plant", reach: 80),
        ]
        for (i, x) in Self.roomDoors.enumerated() {
            let number = floor * 100 + i + 1
            if floor == uncleFloor && i == uncleDoorIndex {
                things.append(H.onWall("uncleDoor", "uncleDoor", x: x, prompt: doorOpen ? "Go into room \(number)" : "Knock on room \(number)", reach: 90))
            } else {
                things.append(H.onWall("room\(number)", "roomDoor", x: x, prompt: "Knock on room \(number)", reach: 90))
            }
        }
        return things
    }

    /// One worker walks each upstairs corridor, pushing a trolley of towels.
    static func corridorWorker(floor: Int) -> [Walker] {
        [Walker(id: 40 + floor, kind: .worker, pos: CGPoint(x: 1400, y: 640), range: 700...1850, speed: floor % 2 == 0 ? 95 : -95, style: floor)]
    }

    static func workers() -> [Walker] {
        [
            Walker(id: 30, kind: .worker, pos: CGPoint(x: 700, y: 610), range: 330...1250, speed: 110, style: 0),
            Walker(id: 31, kind: .worker, pos: CGPoint(x: 1500, y: 660), range: 900...1900, speed: -95, style: 1),
            Walker(id: 32, kind: .worker, pos: CGPoint(x: 2000, y: 600), range: 1600...2180, speed: 100, style: 2),
        ]
    }

    static func officeThings() -> [Thing] {
        [
            H.onWall("lobbyBack", "lobbyBack", x: 110, prompt: "Back to the corridor"),
            H.onWall("uncle", "uncle", x: 720, prompt: "Talk to Uncle", reach: 150),
        ]
    }

    private func go(to newArea: Area) {
        Sound.door.play(volume: 0.6)
        saved[area] = engine.things
        if area == .street { streetWalkers = walkers.filter { $0.kind != .rat } }
        if area == .lobby { lobbyWalkers = walkers }
        let from = area
        let width: CGFloat
        var spawn = CGPoint(x: 190, y: 610)
        switch newArea {
        case .street:
            width = Self.streetWidth
            spawn = CGPoint(x: from == .kitchen ? 230 : 5200, y: 610)
            walkers = streetWalkers
        case .kitchen:
            width = Self.kitchenWidth
            walkers = []
        case .lobby:
            width = Self.lobbyWidth
            if from == .upstairs { spawn = CGPoint(x: 2150, y: 610) }
            walkers = lobbyWalkers
            currentFloor = 1
        case .upstairs:
            width = Self.corridorWidth
            spawn = from == .office ? CGPoint(x: Self.roomDoors[uncleDoorIndex] + 60, y: 610) : CGPoint(x: 260, y: 610)
            walkers = engine.grownUpsGone ? [] : Self.corridorWorker(floor: currentFloor)
            saved[.upstairs] = corridorThings(floor: currentFloor)
        case .office:
            width = Self.officeWidth
            walkers = []
        }
        engine.load(SceneLayout(width: width, floor: Self.floor, things: saved[newArea] ?? Self.streetThings(), spawn: spawn))
        engine.facingRight = !(newArea == .street && from != .kitchen) && !(newArea == .lobby && from == .upstairs)
        engine.noiseFactor = newArea == .kitchen ? 2 : 1
        hidingIn = nil
        area = newArea
        chase.playerChangedRoom(entry: spawn)
        switch newArea {
        case .kitchen: engine.say("Mom's cooking! I'll sneak past when her back is turned.", seconds: 3.2)
        case .lobby where from == .street:
            engine.say("The lobby! The workers mustn't see me. There's an elevator at the far end...", seconds: 3.2)
        case .upstairs where from != .office:
            engine.say("Floor \(currentFloor). Which room is Uncle's?", seconds: 2.4)
        default: break
        }
    }

    private func entrance() -> (CGPoint, Double) {
        switch area {
        case .street:
            // Mom comes up the street from the house.
            return (CGPoint(x: max(160, engine.player.x - 720), y: 600), 3)
        case .kitchen: return (CGPoint(x: momX, y: 585), 0.6)
        case .lobby, .office: return (CGPoint(x: 150, y: 600), 4)
        case .upstairs: return (CGPoint(x: 160, y: 600), 4)
        }
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "busStop", "plant": toggleHiding(in: thing)
        case "houseDoor": go(to: .kitchen)
        case "streetDoor", "lobbyDoor": go(to: .street)
        case "lobbyBack": go(to: .upstairs)
        case "elevator":
            Sound.click.play()
            engine.running = false
            engine.walking = false
            elevatorOpen = true
        case "roomDoor":
            Sound.door.play(volume: 0.4)
            engine.addNoise(12)
            engine.say("\"\(Self.wrongRoom.randomElement()!)\" ...Not Uncle's room.", seconds: 2.4)
        case "fridge": openFridge()
        case "dog": feed(i)
        case "box": engine.say("A guest's suitcase. Better leave it.")
        case "hotelDoor":
            if fed < Self.dogCount {
                Sound.buzz.play()
                engine.say("Not yet! \(Self.dogCount - fed) dogs are still hungry.")
            } else {
                go(to: .lobby)
            }
        case "uncleDoor":
            if !doorOpen {
                doorOpen = true
                Sound.unlock.play()
                inventory.removeAll { $0 == Self.blueKey }
                engine.things[i].prompt = "Go into room \(uncleRoom)"
                engine.say("Uncle's voice: \"Who's there?\" It's his room! And the dog's blue key fits!", seconds: 3)
            } else {
                go(to: .office)
            }
        case "uncle": talkToUncle()
        default: break
        }
    }

    /// A button in the elevator was pressed: 1 is the lobby, 2–11 the floors upstairs.
    func ride(to floor: Int) {
        elevatorOpen = false
        engine.running = phase == .sneaking
        guard floor != currentFloor else { return }
        Sound.powerup.play(volume: 0.5)
        if floor == 1 {
            go(to: .lobby)
        } else {
            currentFloor = floor
            go(to: .upstairs)
        }
    }

    func closeElevator() {
        elevatorOpen = false
        engine.running = phase == .sneaking
    }

    private func toggleHiding(in spot: Thing) {
        Sound.closet.play()
        if engine.hidden {
            engine.hidden = false
            hidingIn = nil
        } else {
            engine.carrying = nil
            engine.ducking = false
            engine.player = CGPoint(x: spot.pos.x, y: Self.floor.lowerBound + 8)
            engine.hidden = true
            hidingIn = spot.id
        }
    }

    private func openFridge() {
        guard snacks < Self.snackLoad else {
            engine.say("My pockets are full. \(Self.snackLoad) snacks is all I can carry.")
            return
        }
        guard fed + snacks < Self.dogCount else {
            engine.say("I have enough snacks for every dog now.")
            return
        }
        snacks = min(Self.snackLoad, Self.dogCount - fed)
        showSnacks()
        Sound.drawer.play()
        engine.say("\(snacks) snacks. Back out to the dogs!")
    }

    private func showSnacks() {
        inventory.removeAll { $0.id.hasPrefix("snack") }
        for n in 0..<snacks {
            inventory.append(InventoryItem(id: "snack\(n)", symbol: "takeoutbag.and.cup.and.straw.fill", color: .orange))
        }
    }

    private func feed(_ i: Int) {
        guard snacks > 0 else {
            engine.say("No snacks left! They're in the fridge at home.")
            return
        }
        snacks -= 1
        fed += 1
        showSnacks()
        engine.things[i].open = true
        engine.things[i].prompt = nil
        Sound.woof.play()
        if fed == Self.dogCount {
            Sound.powerup.play()
            engine.timeLeft += 30
            banner = "Checkpoint! Every dog is fed. +30 seconds. Now to Uncle's hotel!"
            bannerTime = 4
        } else {
            engine.say("Good dog! \(fed) of \(Self.dogCount) fed.", seconds: 1.6)
        }
    }

    private func talkToUncle() {
        phase = .over
        engine.timerOn = false
        chase.reset()
        Sound.magic.play()
        show(Popup(title: "Uncle", message: "\"Well, look who it is! Does your mother know you're out? ...No, don't tell me.\"",
                   symbol: "mustache.fill", color: .orange, button: "Can I hop in your car to the next city?") { [weak self] in
            guard let self else { return }
            onComplete()
            Sound.win.play()
            show(Popup(title: "Level Complete!", message: "Uncle: \"The next city? At this hour? ...Oh, all right. Hop in, kiddo. Seatbelt on!\"",
                       symbol: "car.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                       secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
        })
    }

    // MARK: Every frame

    private func tick(_ dt: Double) {
        chase.tick(dt)
        belt.tick(dt)
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        guard phase == .sneaking else { return }
        switch area {
        case .street:
            walk(dt)
            tickRats(dt)
        case .lobby, .upstairs: walk(dt)
        case .kitchen: tickMom(dt)
        case .office: break
        }
    }

    /// Everyone walks their beat; strangers hurt on contact, guards and workers send you back if they see you.
    private func walk(_ dt: Double) {
        let player = engine.player
        let mode = Difficulty.current
        for i in walkers.indices where walkers[i].kind != .rat {
            if walkers[i].wait > 0 {
                walkers[i].wait -= dt
            } else {
                walkers[i].pos.x += walkers[i].speed * CGFloat(dt) * mode.hazardSpeed
                // No Mercy: strangers don't just stroll past any more. Close by, they turn and come for you.
                if mode == .noMercy, walkers[i].kind == .stranger, !engine.hidden {
                    let toYou = player.x - walkers[i].pos.x
                    if abs(toYou) < 520, abs(toYou) > 20, (toYou > 0) != (walkers[i].speed > 0) { walkers[i].speed = -walkers[i].speed }
                    walkers[i].pos.y += min(max(player.y - walkers[i].pos.y, -60 * CGFloat(dt)), 60 * CGFloat(dt))
                }
                let range = walkers[i].range
                if walkers[i].pos.x >= range.upperBound || walkers[i].pos.x <= range.lowerBound {
                    walkers[i].pos.x = min(max(walkers[i].pos.x, range.lowerBound), range.upperBound)
                    walkers[i].speed = -walkers[i].speed
                    walkers[i].wait = walkers[i].kind == .stranger ? .random(in: 0.3...1.2) : .random(in: 1...2.2)
                }
                walkers[i].facingRight = walkers[i].speed > 0
            }
            let w = walkers[i]
            let dx = player.x - w.pos.x, dy = player.y - w.pos.y
            switch w.kind {
            case .stranger:
                if abs(dx) < 42, abs(dy) < 28, engine.z < 40, engine.damage(20) {
                    engine.player.x = min(max(player.x + (dx >= 0 ? 80 : -80), 40), engine.width - 40)
                    if phase == .sneaking { engine.say("Ouch! Keep away from the strangers!", seconds: 1.8) }
                }
            case .guardian, .worker:
                // They see what's in front of them. Crouching, you can creep up much closer.
                let reach: CGFloat = engine.ducking ? 110 : 290
                let ahead = dx * (w.facingRight ? 1 : -1)
                // Chaos and No Mercy: a worker walking right past your hiding place sometimes looks behind it.
                if mode.atLeastChaos, w.kind == .worker, engine.hidden, abs(dx) < 40 {
                    if !checkedBy.contains(w.id) {
                        checkedBy.insert(w.id)
                        if Int.random(in: 0..<3) == 0 {
                            engine.hidden = false
                            hidingIn = nil
                            let before = area
                            spotted(by: .worker)
                            if area != before { return }
                        }
                    }
                    continue
                }
                if abs(dx) > 120 { checkedBy.remove(w.id) }
                guard ahead > 0, ahead < reach, abs(dy) < 85, !engine.concealed, engine.z < 60 else { continue }
                // Being spotted can send you to another floor (and swap who's walking about): stop here if it did.
                let before = area
                spotted(by: w.kind)
                if area != before { return }
            default: break
            }
        }
    }

    private func spotted(by kind: Walker.Kind) {
        guard engine.damage(kind == .guardian ? 30 : 15), phase == .sneaking else { return }
        Sound.buzz.play()
        banner = kind == .guardian ? "Guard: \"Hey! No kids out here at night!\"" : "Worker: \"Lost, little one? Out you go!\""
        bannerTime = 2.6
        if kind == .guardian {
            engine.player = CGPoint(x: 4150, y: 620)
        } else if area == .upstairs {
            // Upstairs, the worker sends you back down to the lobby.
            hidingIn = nil
            engine.hidden = false
            go(to: .lobby)
            engine.player = CGPoint(x: 200, y: 620)
            return
        } else {
            engine.player = CGPoint(x: 200, y: 620)
        }
        engine.hidden = false
        hidingIn = nil
    }

    /// While you carry snacks, a rat shows up now and then. It takes one snack and leaves a present.
    private func tickRats(_ dt: Double) {
        guard !engine.grownUpsGone else { return }
        let player = engine.player
        if snacks > 0, !walkers.contains(where: { $0.kind == .rat }) {
            ratIn -= dt
            if ratIn <= 0 {
                ratIn = .random(in: 16...26)
                let side: CGFloat = Bool.random() ? 1 : -1
                nextID += 1
                walkers.append(Walker(id: nextID, kind: .rat, pos: CGPoint(x: min(max(player.x + side * 560, 60), engine.width - 60), y: player.y),
                                      range: 0...engine.width, speed: 0, style: 0))
                Sound.squeak.play(volume: 0.4)
            }
        }
        guard let i = walkers.firstIndex(where: { $0.kind == .rat }) else { return }
        walkers[i].life += dt
        var rat = walkers[i]
        if rat.leaving || rat.life > 9 || engine.hidden {
            // Scurry off the screen and vanish.
            rat.leaving = true
            rat.pos.x += (rat.facingRight ? 1 : -1) * 520 * CGFloat(dt)
            if abs(rat.pos.x - player.x) > 760 {
                walkers.remove(at: i)
                return
            }
        } else {
            let dx = player.x - rat.pos.x, dy = player.y - rat.pos.y
            let distance = max(hypot(dx, dy), 1)
            rat.pos.x += dx / distance * 345 * CGFloat(dt)
            rat.pos.y += dy / distance * 240 * CGFloat(dt)
            rat.facingRight = dx > 0
            if abs(dx) < 36, abs(dy) < 24, engine.z < 30, snacks > 0 {
                rat.leaving = true
                rat.facingRight = !rat.facingRight
                walkers[i] = rat
                ratTrade()
                return
            }
        }
        walkers[i] = rat
    }

    private func ratTrade() {
        snacks -= 1
        showSnacks()
        Sound.squeak.play()
        guard let gift = ratGift() else {
            engine.timeLeft += 10
            engine.say("A rat took a snack! It left a shiny button... +10 seconds.", seconds: 2.6)
            return
        }
        let (name, symbol, color): (String, String, Color)
        switch gift {
        case .accessory(let item): (name, symbol, color) = ("the \(item.name)", item.symbol, item.color == .black ? .white : item.color)
        case .boost(let boost): (name, symbol, color) = ("a RARE BOOST: \(boost.name)", boost.symbol, boost.color)
        case .bat: (name, symbol, color) = ("a bat", "figure.baseball", .orange)
        }
        show(Popup(title: "Rat trade!", message: "A rat ran off with one of your snacks... but it left you \(name)!",
                   symbol: symbol, color: color, button: "Fair deal") { [weak self] in self?.take(gift) })
    }

    /// Mom cooks at the stove, walks to the sink, washes up, and walks back. She only sees
    /// what's in front of her while she walks; cooking, her back is turned.
    private func tickMom(_ dt: Double) {
        guard !chase.active, !engine.grownUpsGone else { return }
        let player = engine.player
        switch cooking {
        case .atStove, .atSink:
            cookTime -= dt
            if cookTime <= 0 { cooking = cooking == .atStove ? .toSink : .toStove }
        case .toSink:
            momX = min(Self.sink, momX + 150 * CGFloat(dt))
            if momX >= Self.sink { cooking = .atSink; cookTime = 4.5 }
        case .toStove:
            momX = max(Self.stove, momX - 150 * CGFloat(dt))
            if momX <= Self.stove { cooking = .atStove; cookTime = 4.5 }
        }
        guard !engine.concealed, !engine.safe else { return }
        let dx = player.x - momX
        let looking: CGFloat? = cooking == .toSink ? 1 : cooking == .toStove ? -1 : nil
        let seen = looking.map { dx * $0 > 0 && dx * $0 < 400 } ?? false
        // Walking right into her counts too.
        if seen || (abs(dx) < 60 && player.y < 600) {
            chase.alarm(.mom, "Mom turned around and saw you! RUN!", from: CGPoint(x: momX, y: 585))
        }
    }

    // MARK: Trouble

    private func bumped(_ i: Int) {
        let hazard = engine.things[i].hazard
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard !chase.active else { return }
        if area == .kitchen {
            chase.alarm(.mom, "\(hazard?.noise ?? "CRASH!") Mom heard it!", from: CGPoint(x: momX, y: 585))
        } else {
            chase.alarm(.mom, "\(hazard?.noise ?? "CLANG!") Mom heard that all the way from the kitchen!")
        }
    }

    private func momAlarm(tooLoud: Bool) {
        guard phase == .sneaking else { return }
        guard !chase.active else {
            engine.resetNoise()
            return
        }
        if !tooLoud { award(.amNotPm) }
        let text = tooLoud ? "Too loud! Mom is coming to find you!" : "Time's up! Breakfast is ready, and Mom is looking for you!"
        if area == .kitchen {
            chase.alarm(.mom, text, from: CGPoint(x: momX, y: 585))
        } else {
            chase.alarm(.mom, text)
        }
    }

    private func gaveUp() {
        award(.shh)
        engine.resetNoise()
        engine.timerOn = true
        engine.timeLeft = 120
        momX = Self.stove
        cooking = .atStove
        cookTime = 4.5
        engine.say("Mom gave up and went back to her cooking. 2 more minutes!", seconds: 4)
    }

    private func caught(_ message: String) {
        award(.oopsies)
        end(title: "Caught!", message: message)
    }

    private func knockedOut() {
        end(title: "Ouch!", message: "You ran out of health. The street is tough at night!")
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
        engine.running = phase == .sneaking
    }

    func hint() {
        switch area {
        case .kitchen:
            engine.say(snacks > 0 ? "I've got snacks. Back out the door while Mom's back is turned!"
                                  : "The fridge is on the far side. Go when Mom is cooking, and crouch under a table when she walks.")
        case .lobby:
            engine.say(Settings.shared.practiceOn ? "Take the elevator to floor \(uncleFloor). Uncle is in room \(uncleRoom)."
                                                : "Hide behind the plants when a worker looks my way. The elevator is at the far end.")
        case .upstairs:
            // No hints about Uncle's room... except from the Guide in practice mode.
            if Settings.shared.practiceOn {
                engine.say(currentFloor == uncleFloor ? "The Guide says: this is the floor! Room \(uncleRoom)." : "The Guide says: wrong floor. Uncle is on floor \(uncleFloor).")
            } else {
                engine.say("Uncle's room could be on any floor. I'll have to knock on doors... quietly.")
            }
        case .office: engine.say("Talk to Uncle!")
        case .street:
            if fed == Self.dogCount {
                engine.say("All fed! The hotel is at the far end. Crouch to sneak past the guards, or wait in the bus stop.")
            } else if snacks == 0 {
                engine.say("I need snacks from the fridge at home (the door at the start of the street).")
            } else {
                engine.say("Feed the dogs! \(fed) of \(Self.dogCount) so far. Jump over strangers and rats.")
            }
        }
    }
}

// MARK: - View

struct StreetLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = StreetModel()

    private var title: String {
        switch model.area {
        case .street: "Level 5 · The Street  ·  dogs \(model.fed)/\(StreetModel.dogCount)"
        case .kitchen: "Level 5 · Mom's Kitchen"
        case .lobby: "Level 5 · Hotel Lobby (Floor 1)"
        case .upstairs: "Level 5 · Hotel · Floor \(model.currentFloor)"
        case .office: "Level 5 · Uncle's Room \(model.uncleRoom)"
        }
    }

    var body: some View {
        LevelScaffold(engine: model.engine, title: title, inventory: model.inventory,
                      popup: model.popup, banner: model.banner, belt: model.belt,
                      chase: model.chase,
                      guideTips: GuideTips.level5 + ["Uncle's room this time: room \(model.uncleRoom), on floor \(model.uncleFloor). Take the elevator!"],
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            if model.elevatorOpen {
                ElevatorPanel(current: model.currentFloor, onPick: model.ride(to:), onClose: model.closeElevator)
            }
        }
        .onAppear {
            model.onComplete = { game.complete(level: 5) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            model.onRetry = { game.noteRetry() }
            model.take = { game.take($0) }
            // A rat's present: 1 time in 10 a boost, otherwise an accessory you don't have.
            model.ratGift = {
                if Int.random(in: 0..<10) == 0, let boost = game.newBoost() { return .boost(boost) }
                return Accessory.all.filter { !game.accessories.contains($0) }.randomElement().map { .accessory($0) }
            }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    @ViewBuilder private var backdrop: some View {
        switch model.area {
        case .street: StreetScene(width: StreetModel.streetWidth)
        case .kitchen: KitchenWall(width: StreetModel.kitchenWidth)
        case .lobby: LobbyWall(width: StreetModel.lobbyWidth)
        case .upstairs: HotelCorridorWall(width: StreetModel.corridorWidth, floor: model.currentFloor)
        case .office: OfficeWall(width: StreetModel.officeWidth)
        }
    }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.area == .kitchen && !model.chase.active && !model.engine.grownUpsGone {
                CookingMomView(backTurned: model.cooking == .atStove || model.cooking == .atSink,
                               facingRight: model.cooking == .toSink, walking: model.cooking == .toSink || model.cooking == .toStove)
                    .anchored(at: CGPoint(x: model.momX, y: 585))
            }
            // People further back than you are drawn behind you; the rest in front.
            people(behind: true)
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { thing in
                floorItem(thing)
            }
            people(behind: false)
            ChaserView(chase: model.chase)
            Palette.shade.opacity((model.area == .street ? 0.16 : 0.12) * Palette.shadeAmount)
        }
        .frame(width: engine.width, height: 700, alignment: .topLeading)
    }

    private func people(behind: Bool) -> some View {
        let seen = model.walkers.filter {
            ($0.pos.y <= engine.player.y) == behind && abs($0.pos.x - engine.player.x) < engine.viewWidth
        }
        return ForEach(seen) { walker in
            walkerView(walker)
                .scaleEffect(x: walker.facingRight ? 1 : -1, y: 1)
                .anchored(at: walker.pos)
        }
    }

    @ViewBuilder private func walkerView(_ walker: Walker) -> some View {
        switch walker.kind {
        case .stranger: PersonView(outfit: .stranger(walker.style), walking: walker.wait <= 0)
        case .guardian: PersonView(outfit: .guardian, walking: walker.wait <= 0)
        case .worker: PersonView(outfit: .worker(walker.style), walking: walker.wait <= 0)
        case .rat: RatView()
        }
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "houseDoor": DoorView(color: Color(red: 0.45, green: 0.32, blue: 0.55), open: model.chase.momOut && model.area == .street) {
            DoorSign(text: "HOME", color: .yellow)
        }
        case "streetDoor", "lobbyDoor", "lobbyBack": DoorView(color: Color(red: 0.35, green: 0.30, blue: 0.25)) { EmptyView() }
        case "hotelDoor": DoorView(color: Color(red: 0.65, green: 0.50, blue: 0.20)) { DoorSign(text: "HOTEL", color: .yellow) }
        case "uncleDoor": DoorView(color: Color(red: 0.45, green: 0.22, blue: 0.20), open: model.doorOpen) { DoorSign(text: "\(model.uncleRoom)", color: Palette.gold) }
        case "roomDoor": DoorView(color: Color(red: 0.45, green: 0.22, blue: 0.20)) { DoorSign(text: String(thing.id.dropFirst(4)), color: Palette.gold) }
        case "elevator": ElevatorDoorView(floor: model.currentFloor)
        case "busStop": BusStopView(hiding: model.hidingIn == thing.id)
        case "plant": LobbyPlantView(hiding: model.hidingIn == thing.id)
        case "fridge": FridgeView()
        case "uncle": PersonView(outfit: .uncle).scaleEffect(x: -1, y: 1)
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "dog":
            DogView(happy: thing.open)
                .overlay(alignment: .top) {
                    Image(systemName: thing.open ? "heart.fill" : "fork.knife")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(thing.open ? .pink : .white)
                        .offset(y: -30)
                }
        case "cans": PaintCansView()
        case "table": SideTableView()
        case "chair": ChairView()
        case "box": CardboardBox(open: false)
        default: EmptyView()
        }
    }
}

/// The hotel elevator's doors, with the floor number lit up above them.
struct ElevatorDoorView: View {
    let floor: Int

    var body: some View {
        VStack(spacing: 6) {
            Text(floor == 1 ? "L" : "\(floor)")
                .font(.game(22, .heavy))
                .foregroundStyle(.orange)
                .frame(width: 54, height: 34)
                .background(.black, in: RoundedRectangle(cornerRadius: 6))
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.55)).frame(width: 150, height: 290)
                HStack(spacing: 4) {
                    LinearGradient(colors: [Color(white: 0.85), Color(white: 0.65)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [Color(white: 0.65), Color(white: 0.85)], startPoint: .leading, endPoint: .trailing)
                }
                .frame(width: 134, height: 276)
            }
            .overlay(alignment: .trailing) {
                VStack(spacing: 6) {
                    Circle().fill(.orange).frame(width: 12)
                    Circle().fill(Color(white: 0.3)).frame(width: 12)
                }
                .padding(6)
                .background(Color(white: 0.4), in: Capsule())
                .offset(x: 26)
            }
        }
    }
}

/// An upstairs corridor in Uncle's hotel: wallpaper, a long carpet and the floor number.
struct HotelCorridorWall: View {
    let width: CGFloat
    let floor: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.36), Color(red: 0.30, green: 0.32, blue: 0.44)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            ForEach(0..<Int(width / 90), id: \.self) { i in
                Rectangle().fill(.white.opacity(0.05)).frame(width: 30, height: 545).offset(x: CGFloat(i) * 90)
            }
            Rectangle().fill(Palette.gold.opacity(0.5)).frame(width: width, height: 6).offset(y: 440)
            Rectangle().fill(Color(red: 0.16, green: 0.18, blue: 0.28)).frame(width: width, height: 100).offset(y: 446)
            Rectangle().fill(Color(red: 0.45, green: 0.14, blue: 0.18)).frame(width: width, height: 155).offset(y: 545)
            Rectangle().fill(Palette.gold.opacity(0.35)).frame(width: width, height: 5).offset(y: 600)
            ForEach(0..<Int(width / 600) + 1, id: \.self) { i in
                Text("FLOOR \(floor)")
                    .font(.game(26, .heavy))
                    .foregroundStyle(Palette.gold.opacity(0.8))
                    .position(x: 340 + CGFloat(i) * 600, y: 150)
            }
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "light.cylindrical.ceiling.fill").font(.system(size: 44)).foregroundStyle(Palette.gold)
                    .position(x: 300 + CGFloat(i) * 480, y: 70)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// The elevator's buttons: L for the lobby, then floors 2 to 11. No hints about which one is Uncle's.
struct ElevatorPanel: View {
    let current: Int
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down.square.fill").foregroundStyle(.orange)
                    Text("Elevator")
                    Spacer()
                    RoundIconButton(symbol: "xmark", action: onClose).scaleEffect(0.75)
                }
                .font(.game(34, .heavy))
                .foregroundStyle(.white)
                Text("Which floor? You're on \(current == 1 ? "the lobby" : "floor \(current)").")
                    .font(.game(18, .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                let many = StreetModel.floors.count > 10
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(many ? 64 : 78), spacing: many ? 10 : 14), count: many ? 6 : 4), spacing: many ? 10 : 14) {
                    ForEach([1] + StreetModel.floors, id: \.self) { floor in
                        Button {
                            SoundPlayer.shared.tap()
                            onPick(floor)
                        } label: {
                            Text(floor == 1 ? "L" : "\(floor)")
                                .font(.game(many ? 24 : 30, .heavy))
                                .foregroundStyle(floor == current ? .black : .white)
                                .frame(width: many ? 64 : 78, height: many ? 64 : 78)
                                .background(floor == current ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color(white: 0.3).gradient), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 3))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(28)
            .frame(width: StreetModel.floors.count > 10 ? 500 : 440)
            .background(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(.orange.opacity(0.7), lineWidth: 4))
        }
    }
}

/// What the Guide says in practice mode, level by level: full step-by-step instructions,
/// each one saying where to go and which button to press.
@MainActor
enum GuideTips {
    static var level1: [String] { [
        "Step 1: walk to the small table and press the hand button (E). A key is hiding under it.",
        "Step 2: go to the bed. Press the crouch button (C), then E, to pull out the lockbox and open it with that key.",
        "Step 3: the lockbox had the door key in it. Walk to the door and press E. Done!",
        "If you make too much noise, Mom comes in. Don't press the taunt button (T) too often.",
    ] }
    static var level2: [String] { [
        "Step 1: the window. Press E to open it, then E again to take the key from the ledge.",
        "Step 2: a second key. Either the drawer next to your brother's bed (jump over his toys with Space), or Mom's jewelry box in her room.",
        "Step 3: the door code is on a paper in one of the four boxes. Press E at each box until you find it.",
        "Step 4: walk to the front door at the far right end, press E and type the code. With 2 keys it opens.",
        "Don't walk into chairs, tables or lamps. Crouch (C) to touch them safely, or jump over them.",
        "If Mom or Dad comes, press E at a closet to hide inside.",
    ] }
    static var level3: [String] { [
        "Step 1: go down the stairs. Jump (Space) over every loose plank; crouching does NOT help here.",
        "Step 2: take food from the fridge, go to the window and throw it out. A dog comes to the front door. Bring him one more snack and he gives you a key.",
        "Step 3: find 3 metal scraps (press E at shelves, bins and boxes). Take each one to the workbench in the garage to make a key, then open the 3 lockboxes.",
        "Step 4: flick the garage light switch 3 times. Dad comes down to look. Hide in a closet until he is inside the garage.",
        "Step 5: upstairs, take a toy from your brother's room, throw it in the hallway and hide. While Mom looks at it, take her phone. Passcode: \(DownstairsModel.passcode). Notes has the basement code: \(DownstairsModel.exitCode).",
        "Step 6: go to the basement, keep away from Dad, and type \(DownstairsModel.exitCode) at the exit door.",
        "Step 7: outside, lock the door with the dog's key within 10 seconds, then walk to the garden gate.",
    ] }
    static var level4: [String] { [
        "Step 1: water all the plants. You don't press anything: just walk close to each one.",
        "The radar station (press E) shows which plants are still thirsty.",
        "When the banner says Dad is coming, find a bush and press E to hide in it until he leaves.",
        "Spiky vines across a path: jump over them with Space. Touching one brings Dad.",
        "Pests: walk up to one and press E to shoo it away.",
        "Step 2: when every plant is watered, go to the gate. Only walk through while the two dogs are away.",
        "Step 3: beyond the gate, search the spots for \(GardenModel.keysNeeded) keys, then type the code at the street gate. The hint is at the bottom of the screen.",
    ] }
    static var level5: [String] { [
        "You have a health bar here. Strangers take health if they touch you: jump over them, or press E at a bus stop to wait inside.",
        "Step 1: go through the HOME door at the start of the street to get snacks from the fridge (\(StreetModel.snackLoad) at a time).",
        "In the kitchen, Mom can't see you while she stands cooking. When she walks, crouch (C) under a table.",
        "Step 2: back on the street, press E at each dog to feed it. There are \(StreetModel.dogCount) dogs.",
        "A rat takes one snack but leaves you a present. Jump over it if you want to keep the snack.",
        "Step 3: the hotel is at the far right. Crouch to creep up behind the guards; they only see in front of them.",
        "Step 4: inside, hide behind plants when a worker looks your way. Take the elevator and find Uncle's room.",
        "Step 5: the blue key in your backpack opens Uncle's door. Go in and press E to talk to him.",
    ] }
    static var level6: [String] { [
        "Auntie wants \(AuntieModel.choreCount) chores done. The list is at the bottom of the screen; the next one is in yellow.",
        "Walk to the thing for a chore and press E. Some chores need a few presses, or more than one place.",
        "For the rubbish: stand next to the bag, press the box button (R) to pick it up, carry it to the bin, and press E at the bin.",
        "The cats are asleep on the floor. Jump over them (Space) or crouch past (C). If you step on one, you lose time.",
        "Auntie's glasses are hidden in one of the drawers or boxes. Press E at each until you find them.",
        "When every chore is ticked, Auntie walks to the back door. Follow her and press E at the door.",
    ] }
    static var otherHallway: [String] { [
        "Five of the eight boxes hide a key. Walk to each box and press E.",
        "Each box can only be searched once, and it might hold an accessory or a boost.",
        "With all 5 keys, walk to the door at the far right end and press E.",
    ] }

    /// No Mercy: the Guide gets things wrong, and he says them like he means it.
    static let mistakes = [
        "The key is under the fridge. Go and look!",
        "Go left. The door's definitely on the left.",
        "Taunt as much as you like: it makes you invisible.",
        "The code is 0000. It's always 0000.",
        "Mom is fast asleep. Walk right past her.",
        "That box is safe. Search it.",
        "Jump onto the chairs: they're quieter than the floor.",
        "Dad never checks the closets, so stand in front of one instead.",
    ]
}
