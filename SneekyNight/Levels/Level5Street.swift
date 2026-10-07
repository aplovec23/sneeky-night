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
/// Then get past the hotel guards and the workers in the lobby, open Uncle's door with the dog's
/// blue key from Level 3, and ask him for a ride.
@MainActor
@Observable
final class StreetModel {
    enum Area { case street, kitchen, lobby, office }
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
    @ObservationIgnored private var cookTime = 4.5
    @ObservationIgnored private var ratIn = 14.0
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var nextID = 100

    static let floor: ClosedRange<CGFloat> = 545...690
    static let streetWidth: CGFloat = 5600
    static let kitchenWidth: CGFloat = 1500
    static let lobbyWidth: CGFloat = 2400
    static let officeWidth: CGFloat = 1000
    static let dogCount = 15
    static let snackLoad = 5
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
        chase.engine = engine
        chase.entrance = { [weak self] _ in self?.entrance() ?? (.zero, 2) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.onCaught = { [weak self] _, message in self?.caught(message) }
        chase.onGaveUp = { [weak self] _ in self?.gaveUp() }
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
        saved = [.kitchen: Self.kitchenThings(), .lobby: Self.lobbyThings(), .office: Self.officeThings()]
        streetWalkers = Self.strangersAndGuards()
        lobbyWalkers = Self.workers()
        walkers = streetWalkers
        area = .street
        engine.load(SceneLayout(width: Self.streetWidth, floor: Self.floor, things: Self.streetThings(), spawn: CGPoint(x: 260, y: 620)))
        engine.usesHP = true
        engine.timeLeft = Levels.all[4].seconds
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
        for i in 0..<dogCount {
            let x = 520 + CGFloat(i) * 245
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
            H.onWall("uncleDoor", "uncleDoor", x: 2270, prompt: "Unlock Uncle's door", reach: 90),
        ]
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
            H.onWall("lobbyBack", "lobbyBack", x: 110, prompt: "Back to the lobby"),
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
            if from == .office { spawn = CGPoint(x: 2180, y: 610) }
            walkers = lobbyWalkers
        case .office:
            width = Self.officeWidth
            walkers = []
        }
        engine.load(SceneLayout(width: width, floor: Self.floor, things: saved[newArea] ?? Self.streetThings(), spawn: spawn))
        engine.facingRight = !(newArea == .street && from != .kitchen) && !(newArea == .lobby && from == .office)
        engine.noiseFactor = newArea == .kitchen ? 2 : 1
        hidingIn = nil
        area = newArea
        chase.playerChangedRoom(entry: spawn)
        switch newArea {
        case .kitchen: engine.say("Mom's cooking! I'll sneak past when her back is turned.", seconds: 3.2)
        case .lobby: engine.say("The workers mustn't see me. Uncle's office is at the far end.", seconds: 3.2)
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
        }
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "busStop", "plant": toggleHiding(in: thing)
        case "houseDoor": go(to: .kitchen)
        case "streetDoor", "lobbyDoor": go(to: .street)
        case "lobbyBack": go(to: .lobby)
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
                engine.things[i].prompt = "Go into Uncle's office"
                engine.say("The dog's blue key fits!")
            } else {
                go(to: .office)
            }
        case "uncle": talkToUncle()
        default: break
        }
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
        case .lobby: walk(dt)
        case .kitchen: tickMom(dt)
        case .office: break
        }
    }

    /// Everyone walks their beat; strangers hurt on contact, guards and workers send you back if they see you.
    private func walk(_ dt: Double) {
        let player = engine.player
        for i in walkers.indices where walkers[i].kind != .rat {
            if walkers[i].wait > 0 {
                walkers[i].wait -= dt
            } else {
                walkers[i].pos.x += walkers[i].speed * CGFloat(dt)
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
                guard ahead > 0, ahead < reach, abs(dy) < 85, !engine.concealed, engine.z < 60 else { continue }
                spotted(by: w.kind)
            default: break
            }
        }
    }

    private func spotted(by kind: Walker.Kind) {
        guard engine.damage(kind == .guardian ? 30 : 15), phase == .sneaking else { return }
        Sound.buzz.play()
        banner = kind == .guardian ? "Guard: \"Hey! No kids out here at night!\"" : "Worker: \"Lost, little one? Out you go!\""
        bannerTime = 2.6
        engine.player = kind == .guardian ? CGPoint(x: 4150, y: 620) : CGPoint(x: 200, y: 620)
        engine.hidden = false
        hidingIn = nil
    }

    /// While you carry snacks, a rat shows up now and then. It takes one snack and leaves a present.
    private func tickRats(_ dt: Double) {
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
        guard !chase.active else { return }
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
            engine.say(doorOpen ? "Uncle's door is open. Go in!" : "Hide behind the plants when a worker looks my way. Uncle's door is at the far end.")
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
        case .lobby: "Level 5 · Uncle's Hotel"
        case .office: "Level 5 · Uncle's Office"
        }
    }

    var body: some View {
        LevelScaffold(engine: model.engine, title: title, inventory: model.inventory,
                      popup: model.popup, banner: model.banner, belt: model.belt,
                      chase: model.chase, guideTips: GuideTips.level5,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            EmptyView()
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
        case .office: OfficeWall(width: StreetModel.officeWidth)
        }
    }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            backdrop
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.area == .kitchen && !model.chase.active {
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
        case "uncleDoor": DoorView(color: Color(red: 0.25, green: 0.40, blue: 0.75), open: model.doorOpen) { DoorSign(text: "UNCLE", color: .cyan) }
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

/// What the Guide says in practice mode, level by level.
enum GuideTips {
    static let level1 = ["Look under the table for a key.", "The lockbox is under the bed. Crouch to reach it.", "The lockbox key opens the door."]
    static let level2 = ["Open the window: there's a key on the ledge.", "The second key is by your brother's bed, or in Mom's jewelry box.",
                         "The door code is on a paper in one of the boxes.", "Closets are good hiding places."]
    static let level3 = ["Jump the loose planks on the stairs.", "Throw food out of the window to call the dog.",
                         "Find 3 metal scraps, and make keys at the garage workbench.", "Mom's phone has the basement code. Her passcode is 12345."]
    static let level4 = ["Walk close to every plant to water it.", "When Dad is coming, hide in a bush.", "Jump over the spiky vines.",
                         "Leave through the gate only while the dogs are away."]
    static let level5 = ["Strangers hurt! Jump over them or wait in a bus stop.", "Snacks are in the fridge at home: go back through the HOME door.",
                         "Mom can't see you while she cooks. Crouch under a table when she walks.", "A rat takes one snack, but leaves you a present.",
                         "Crouch to creep up behind the hotel guards.", "The blue key from the dog opens Uncle's door."]
    static let otherHallway = ["Five of the eight boxes hide a key.", "Search boxes again for accessories and boosts.", "With 5 keys, the far door opens."]
    static let dungeon = ["Press E at a glowing rock to mine an orb.", "Spend orbs at the Orb Shop.", "The quest board tells you what to do to finish.",
                          "Jump over the sliding spikes."]
}
