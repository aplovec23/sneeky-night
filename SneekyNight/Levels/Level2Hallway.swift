import SwiftUI
import Observation

/// Level 2 rules: sneak down the long hallway without bumping chairs, tables or lamps (crouch to
/// touch them safely, or jump over). Drawers hold Zoom Slippers and Spring Socks. The front door
/// needs a code (on a paper hidden in a box) and two keys: one on the window ledge, and one from
/// your brother's room — or Mom's spare from her jewelry box. Mom's room has useful things, but Dad
/// is awake and checks it now and then. Checking boxes over and over finds skill papers.
/// Out of time, or too noisy: Mom wakes up and searches — hide in a closet or under a table (50/50).
@MainActor
@Observable
final class HallwayModel {
    enum Room { case hallway, siblingRoom, momRoom }
    enum Phase { case sneaking, warning, searching, over }

    let engine = GameEngine()
    var room: Room = .hallway
    var phase: Phase = .sneaking
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var showKeypad = false
    var windowOpen = false
    /// Which funny view is showing through the window, if any.
    var windowView: Int?
    /// The drawing pad is open (paper from your brother's room).
    var drawing = false
    var codeAccepted = false
    var doorOpen = false
    /// Mom or Dad coming after you (after noise, a bump, the clock, or Dad spotting you).
    let chase = Chase()
    /// Dad standing in the doorway of Mom's room, looking in.
    var dadVisible = false
    var hidingIn: String?
    var playerOpacity = 1.0
    var code = "1DLP"

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var knownSkills: () -> Set<Skill> = { [] }
    @ObservationIgnored var learn: (Skill) -> Void = { _ in }
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var giveToy: (String) -> Void = { _ in }
    @ObservationIgnored var rewardToy: () -> Void = {}
    let belt = ItemBelt()
    /// Holding a toy from the toy chest (to give to someone).
    var toyInHand = false
    var dadStunned = false
    /// Seconds Dad won't catch you: laughing at your taunt, or tangled in vines.
    @ObservationIgnored private var dadPause = 0.0
    @ObservationIgnored private var dadLaughed = false
    let buddy = SiblingBuddy()
    @ObservationIgnored private var paperBox = "box1"
    @ObservationIgnored private var paperFound = false
    @ObservationIgnored private var boxChecks = 0
    @ObservationIgnored private var windowViews = 0
    @ObservationIgnored private var saved: [Room: [Thing]] = [:]
    /// Bumped on every restart so leftover timers from the last try do nothing.
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var dadRun = 0

    static let codes = ["1DLP", "9PO8", "42FOJ"]
    static let floor: ClosedRange<CGFloat> = 545...690
    static let hallWidth: CGFloat = 3400
    static let roomWidth: CGFloat = 1500
    static let momRoomWidth: CGFloat = 1600

    static let windowKey = InventoryItem(id: "windowKey", symbol: "key.fill", color: Palette.silver)
    static let siblingKey = InventoryItem(id: "siblingKey", symbol: "key.fill", color: Palette.gold)
    static let spareKey = InventoryItem(id: "spareKey", symbol: "key.fill", color: .pink)
    static let paper = InventoryItem(id: "paper", symbol: "doc.text.fill", color: .white)
    static let slippers = InventoryItem(id: "slippers", symbol: "hare.fill", color: .mint)
    static let socks = InventoryItem(id: "socks", symbol: "arrow.up.circle.fill", color: .pink)
    static let silentSlippers = InventoryItem(id: "silentSlippers", symbol: "shoeprints.fill", color: .purple)
    static let toy = InventoryItem(id: "toy", symbol: "teddybear.fill", color: .pink)

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onTimeUp = { [weak self] in self?.momWakesUp(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momWakesUp(tooLoud: true) }
        engine.onShieldUsed = { [weak self] in
            guard let self, let i = inventory.firstIndex(of: Self.silentSlippers) else { return }
            inventory.remove(at: i)
        }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.taunted() }
        engine.onTick = { [weak self] dt in
            guard let self else { return }
            buddy.update(player: engine.player, playerFacingRight: engine.facingRight, dt: dt)
            chase.tick(dt)
            belt.tick(dt)
            if dadPause > 0 {
                dadPause -= dt
                if dadPause <= 0 {
                    dadStunned = false
                    if banner?.contains("funny") == true { banner = nil }
                }
            }
        }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.stunGrownUp(seconds, momOnly: momOnly) ?? false }
        engine.onDefaultInteract = { [weak self] in self?.talkToBrother() }
        chase.engine = engine
        chase.entrance = { [weak self] who in self?.entrance(for: who) ?? (.zero, 2) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.brotherFollowing = { [weak self] in self?.buddy.state == .following }
        chase.brotherPos = { [weak self] in
            guard let self, buddy.state == .following || (buddy.state == .awake && room == .siblingRoom) else { return nil }
            return buddy.pos
        }
        chase.onCaught = { [weak self] who, message in self?.caught(who, message) }
        chase.onGaveUp = { [weak self] who in self?.gaveUp(who) }
        // Practice mode: the Guide leads you to the next place to go.
        engine.guideGoal = { [weak self] in self?.guideGoal() }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    /// Try Again or the restart button (counts toward the Retry badge).
    func retry() {
        onRetry()
        reset()
    }

    func reset() {
        run += 1
        dadRun += 1
        code = Self.codes.randomElement()!
        paperBox = ["box1", "box2", "box3", "box4"].randomElement()!
        paperFound = false
        boxChecks = 0
        saved = [.siblingRoom: Self.siblingRoomThings(), .momRoom: Self.momRoomThings()]
        room = .hallway
        engine.load(SceneLayout(width: Self.hallWidth, floor: Self.floor, things: Self.hallThings(), spawn: CGPoint(x: 220, y: 610)))
        engine.timeLeft = Levels.all[1].seconds
        engine.timerOn = true
        engine.resetNoise()
        engine.noiseFactor = 1
        engine.speedBoost = false
        engine.jumpBoost = false
        engine.shields = 0
        engine.runHeld = false
        engine.tauntOnly = false
        chase.reset()
        engine.speedBonus = 0
        buddy.reset()
        belt.reset()
        toyInHand = false
        dadStunned = false
        dadPause = 0
        dadLaughed = false
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        phase = .sneaking
        inventory = []
        popup = nil
        banner = nil
        showKeypad = false
        windowOpen = false
        windowView = nil
        codeAccepted = false
        doorOpen = false
        dadVisible = false
        hidingIn = nil
        playerOpacity = 1
        engine.running = true
    }

    // MARK: Rooms

    static func onWall(_ id: String, _ kind: String, x: CGFloat, prompt: String?, reach: CGFloat = 70) -> Thing {
        Thing(id: id, kind: kind, pos: CGPoint(x: x, y: floor.lowerBound), prompt: prompt, reach: CGSize(width: reach, height: 160))
    }

    static func box(_ id: String, x: CGFloat, y: CGFloat) -> Thing {
        Thing(id: id, kind: "box", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 72, height: 30), solid: true,
              movable: true, prompt: "Search the box", reach: CGSize(width: 100, height: 60))
    }

    static func obstacle(_ id: String, _ hazard: Hazard, x: CGFloat, y: CGFloat, size: CGSize) -> Thing {
        Thing(id: id, kind: id.filter(\.isLetter), pos: CGPoint(x: x, y: y), footprint: size, hazard: hazard)
    }

    static func hallThings() -> [Thing] {
        [
            onWall("bedroomDoor", "bedroomDoor", x: 110, prompt: "Go back to bed"),
            onWall("closet1", "closet", x: 320, prompt: "Hide in the closet"),
            onWall("dresser1", "dresser", x: 540, prompt: "Open the drawer"),
            obstacle("chair1", .chair, x: 700, y: 640, size: CGSize(width: 64, height: 30)),
            box("box1", x: 870, y: 600),
            onWall("window", "window", x: 1010, prompt: "Open the window"),
            obstacle("lamp1", .lamp, x: 1150, y: 575, size: CGSize(width: 40, height: 26)),
            onWall("dresser2", "dresser", x: 1330, prompt: "Open the drawer"),
            box("box2", x: 1330, y: 565),
            onWall("siblingDoor", "siblingDoor", x: 1540, prompt: "Sneak into your brother's room"),
            obstacle("table1", .table, x: 1700, y: 630, size: CGSize(width: 110, height: 36)),
            box("box3", x: 1870, y: 665),
            onWall("closet2", "closet", x: 2010, prompt: "Hide in the closet"),
            onWall("momDoor", "momDoor", x: 2200, prompt: "Sneak into Mom's room"),
            obstacle("chair2", .chair, x: 2350, y: 590, size: CGSize(width: 64, height: 30)),
            obstacle("lamp2", .lamp, x: 2420, y: 668, size: CGSize(width: 40, height: 26)),
            onWall("dresser3", "dresser", x: 2580, prompt: "Open the drawer"),
            box("box4", x: 2740, y: 600),
            onWall("closet3", "closet", x: 2900, prompt: "Hide in the closet"),
            obstacle("table2", .table, x: 3040, y: 640, size: CGSize(width: 110, height: 36)),
            obstacle("chair3", .chair, x: 3100, y: 572, size: CGSize(width: 64, height: 30)),
            onWall("exitDoor", "exitDoor", x: 3270, prompt: "Unlock the door", reach: 90),
        ]
    }

    static func siblingRoomThings() -> [Thing] {
        var car = obstacle("car", .toy, x: 700, y: 640, size: CGSize(width: 60, height: 26))
        car.patrol = 420...1100
        car.speed = 240
        var ball = obstacle("ball", .toy, x: 950, y: 588, size: CGSize(width: 40, height: 26))
        ball.patrol = 450...1150
        ball.speed = -190
        var robot = obstacle("robot", .toy, x: 600, y: 676, size: CGSize(width: 44, height: 24))
        robot.patrol = 380...1000
        robot.speed = 150
        return [
            onWall("hallDoor", "hallDoor", x: 110, prompt: "Back to the hallway"),
            onWall("sibCloset", "closet", x: 310, prompt: "Hide in the closet"),
            onWall("toyChest", "toyChest", x: 640, prompt: "Grab a toy", reach: 60),
            onWall("paper", "paper", x: 800, prompt: "Grab paper and draw", reach: 55),
            obstacle("blocks", .toy, x: 520, y: 605, size: CGSize(width: 54, height: 26)),
            obstacle("duck", .toy, x: 780, y: 682, size: CGSize(width: 40, height: 20)),
            car, ball, robot,
            Thing(id: "sibBed", kind: "sibBed", pos: CGPoint(x: 1180, y: floor.lowerBound), heavy: true,
                  prompt: "Look at your brother", reach: CGSize(width: 140, height: 160)),
            onWall("nightstand", "nightstand", x: 1390, prompt: "Open the drawer"),
        ]
    }

    static func momRoomThings() -> [Thing] {
        [
            onWall("hallDoor", "hallDoor", x: 110, prompt: "Back to the hallway"),
            onWall("wardrobe", "closet", x: 320, prompt: "Hide in the wardrobe"),
            onWall("dadDesk", "dadDesk", x: 500, prompt: "Look at Dad's desk", reach: 55),
            obstacle("shoes", .shoes, x: 520, y: 668, size: CGSize(width: 54, height: 20)),
            onWall("vanity", "vanity", x: 690, prompt: "Open the jewelry box"),
            obstacle("table3", .table, x: 880, y: 625, size: CGSize(width: 110, height: 36)),
            Thing(id: "momBed", kind: "momBed", pos: CGPoint(x: 1180, y: floor.lowerBound), heavy: true,
                  prompt: "Look under the bed", reach: CGSize(width: 150, height: 160)),
            obstacle("basket", .basket, x: 1310, y: 662, size: CGSize(width: 60, height: 28)),
            onWall("momNightstand", "momNightstand", x: 1450, prompt: "Check the alarm clock"),
        ]
    }

    private func go(to newRoom: Room) {
        Sound.door.play(volume: 0.6)
        saved[room] = engine.things
        let from = room
        let width: CGFloat
        let spawn: CGPoint
        switch newRoom {
        case .hallway:
            width = Self.hallWidth
            spawn = CGPoint(x: from == .momRoom ? 2200 : 1540, y: 580)
        case .siblingRoom:
            width = Self.roomWidth
            spawn = CGPoint(x: 190, y: 600)
        case .momRoom:
            width = Self.momRoomWidth
            spawn = CGPoint(x: 190, y: 600)
        }
        engine.load(SceneLayout(width: width, floor: Self.floor, things: saved[newRoom] ?? [], spawn: spawn))
        engine.facingRight = newRoom != .hallway
        engine.noiseFactor = newRoom == .momRoom ? 2 : 1
        hidingIn = nil
        dadVisible = false
        if banner?.contains("Dad") == true { banner = nil }
        room = newRoom
        dadRun += 1
        // Whoever is chasing you follows through the same door a moment later.
        chase.playerChangedRoom(entry: spawn)
        if buddy.state == .following { buddy.jump(to: engine.player) }
        engine.defaultPrompt = buddy.state == .following ? "Talk to your brother" : nil
        switch newRoom {
        case .siblingRoom: engine.say("Shhh... don't step on the toys!")
        case .momRoom:
            if !chase.active {
                engine.say("Shhh! Mom's asleep. And Dad might come check...")
                startDadPatrol()
            }
        case .hallway: break
        }
    }

    // MARK: Pressing E

    private func has(_ item: InventoryItem) -> Bool { inventory.contains(item) }

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "closet": toggleHiding(in: thing)
        case "dresser", "nightstand": openDrawer(i)
        case "box": searchBox(i)
        case "window": useWindow()
        case "siblingDoor": go(to: .siblingRoom)
        case "momDoor": go(to: .momRoom)
        case "hallDoor": go(to: .hallway)
        case "bedroomDoor": engine.say("Back to bed? No way! I'm sneaking out!")
        case "exitDoor": useExitDoor()
        case "sibBed": talkToBrother()
        case "paper":
            Sound.paper.play()
            drawing = true
            engine.paused = true
        case "toyChest":
            if toyInHand {
                engine.say("One toy at a time.")
            } else {
                toyInHand = true
                inventory.append(Self.toy)
                Sound.squeak.play(volume: 0.3)
                engine.say("Got a toy. I could give it to someone...")
            }
        case "dadDesk":
            if toyInHand {
                useToy()
                giveToy("dad")
                engine.say("I left the toy on Dad's desk. He'll find it in the morning!")
            } else {
                engine.say("Dad's desk. A cold cup of cocoa and yesterday's newspaper.")
            }
        case "vanity": openJewelryBox(i)
        case "momBed": lookUnderBed(i)
        case "momNightstand": useAlarmClock(i)
        default: break
        }
    }

    // MARK: Brother

    private func useToy() {
        toyInHand = false
        inventory.removeAll { $0 == Self.toy }
    }

    func giveBrotherToy() {
        useToy()
        giveToy("brother")
    }

    /// Vines (anyone) or the reward toy (Mom only): stops whoever is in the room from catching you.
    private func stunGrownUp(_ seconds: Double, momOnly: Bool) -> Bool {
        if chase.stun(seconds, momOnly: momOnly) { return true }
        if !momOnly && dadVisible {
            dadPause = seconds
            dadStunned = true
            return true
        }
        return false
    }

    private func taunted() {
        chase.taunted()
        // Dad thinks it's funny... once. You get 10 seconds.
        if room == .momRoom && !dadLaughed && (dadVisible || banner?.contains("Dad") == true) {
            dadLaughed = true
            dadPause = 10
            award(.funnySon)
            banner = "Dad: \"Ha! That's funny, son. You've got 10 seconds...\""
        }
        if (room == .siblingRoom || buddy.state == .following) && buddy.taunted() {
            award(.crashout)
            engine.say("Brother: \"STOP IT! You're SO annoying!!\"", seconds: 3)
        }
        if room == .siblingRoom && buddy.state == .asleep && phase == .sneaking {
            buddy.wake()
            Sound.squeak.play(volume: 0.5)
            engine.say("Oops... I woke up my brother!")
            if let i = engine.index(of: "sibBed") { engine.things[i].prompt = "Talk to your brother" }
        }
    }

    private func talkToBrother() {
        guard buddy.state != .asleep else {
            engine.say("He's fast asleep. Only something really silly would wake him up...")
            return
        }
        guard room == .siblingRoom || buddy.state == .following else { return }
        engine.running = false
        buddy.startTalking()
    }

    func finishDrawing() {
        drawing = false
        engine.paused = false
        engine.say("Not bad! I'll show Grandpa.", seconds: 2.2)
    }

    func closeTalk() {
        engine.running = phase == .sneaking || phase == .warning
        engine.defaultPrompt = buddy.state == .following ? "Talk to your brother" : nil
        if buddy.state == .asleep, let i = engine.index(of: "sibBed") { engine.things[i].prompt = "Look at your brother" }
    }

    var brotherTip: String {
        if !has(Self.windowKey) { return "I saw something shiny outside the hallway window!" }
        if !has(Self.siblingKey) && !has(Self.spareKey) { return "There's a key in my drawer. And Mom hides a spare one in her jewelry box." }
        if !has(Self.paper) && !codeAccepted { return "Mom wrote the door code on a paper. I think it fell into one of the boxes." }
        return "You have everything! Go to the front door at the end of the hallway."
    }

    private func toggleHiding(in closet: Thing) {
        Sound.closet.play()
        if engine.hidden {
            engine.hidden = false
            hidingIn = nil
        } else {
            engine.carrying = nil
            engine.ducking = false
            engine.player = CGPoint(x: closet.pos.x, y: Self.floor.lowerBound + 8)
            engine.hidden = true
            hidingIn = closet.id
        }
    }

    private func openDrawer(_ i: Int) {
        let id = engine.things[i].id
        if engine.things[i].open {
            engine.say("This drawer is empty now.")
            return
        }
        if id == "dresser2", let b = engine.index(of: "box2"),
           abs(engine.things[b].pos.x - engine.things[i].pos.x) < 70, engine.things[b].pos.y < 600 {
            engine.say("A box is in the way! Press R to move it.")
            return
        }
        engine.things[i].open = true
        Sound.drawer.play()
        switch id {
        case "dresser2":
            Sound.powerup.play()
            show(Popup(title: "Zoom Slippers!", message: "Super quiet, super fast. You can run faster now!",
                       symbol: "hare.fill", color: .mint, button: "Put On") { [weak self] in
                self?.inventory.append(Self.slippers)
                self?.engine.speedBoost = true
            })
        case "dresser3":
            Sound.powerup.play()
            show(Popup(title: "Spring Socks!", message: "Boing! You can jump higher and farther now!",
                       symbol: "arrow.up.circle.fill", color: .pink, button: "Put On") { [weak self] in
                self?.inventory.append(Self.socks)
                self?.engine.jumpBoost = true
            })
        case "nightstand":
            Sound.key.play()
            show(Popup(title: "You found a key!", message: "It was in the drawer next to your brother's bed.",
                       symbol: "key.fill", color: Palette.gold, button: "Take Key") { [weak self] in
                self?.inventory.append(Self.siblingKey)
                self?.award(.patienceIsKey)
            })
        default:
            engine.say("Just socks in here.")
        }
    }

    /// Every box can be checked again and again; every 4th check turns up a skill paper.
    private func searchBox(_ i: Int) {
        boxChecks += 1
        engine.things[i].open = true
        Sound.box.play()
        if engine.things[i].id == paperBox && !paperFound {
            paperFound = true
            Sound.paper.play()
            show(Popup(title: "You found a paper!", message: "It has a secret code on it:\n\(code)",
                       symbol: "doc.text.fill", color: .white, button: "Take Paper") { [weak self] in
                self?.inventory.append(Self.paper)
            })
            return
        }
        let nextSkill = Skill.allCases.first { !knownSkills().contains($0) }
        if boxChecks % 4 == 0, let skill = nextSkill {
            Sound.magic.play()
            show(Popup(title: "Skill paper!", message: "You learned \(skill.title)!\n\(skill.how)",
                       symbol: skill == .dash ? "wind" : "figure.run", color: .cyan, button: "Cool!") { [weak self] in
                self?.learn(skill)
                if skill == .dash { self?.engine.canDash = true } else { self?.engine.canRun = true }
            })
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else if boxChecks % 4 == 2 && nextSkill != nil {
            engine.say("Hmm... something rustles at the bottom. Keep checking the boxes!")
        } else {
            engine.say(["Just old clothes.", "Only some books in here.", "Lots of tangled wires.", "A rubber chicken? Weird."].randomElement()!)
        }
    }

    private func useWindow() {
        defer {
            if let i = engine.index(of: "window") {
                engine.things[i].prompt = !windowOpen ? "Open the window" : has(Self.windowKey) ? "Look outside" : "Grab the shiny thing"
            }
        }
        if !windowOpen {
            windowOpen = true
            Sound.window.play()
            engine.say("The window is open! Something shiny is on the ledge...")
        } else if !has(Self.windowKey) {
            Sound.key.play()
            show(Popup(title: "You found a key!", message: "It was sitting on the window ledge outside.",
                       symbol: "key.fill", color: Palette.silver, button: "Take Key") { [weak self] in
                guard let self else { return }
                inventory.append(Self.windowKey)
                award(.patienceIsKey)
                if let i = engine.index(of: "window") { engine.things[i].prompt = "Look outside" }
            })
        } else {
            // Just for fun: peek outside. Something different every time.
            Sound.window.play(volume: 0.5)
            engine.running = false
            windowView = windowViews % WindowViewOverlay.sceneCount
            windowViews += 1
            if windowViews >= 3 { award(.curiosity) }
        }
    }

    func closeWindowView() {
        windowView = nil
        engine.running = phase == .sneaking || phase == .warning
        // 1 time in 10, something lands on the ledge while you're looking.
        guard Int.random(in: 0..<10) == 0 else { return }
        Sound.magic.play()
        switch Int.random(in: 0..<3) {
        case 0:
            show(Popup(title: "A surprise!", message: "Silent Slippers were sitting on the ledge! One free bump.",
                       symbol: "shoeprints.fill", color: .purple, button: "Take") { [weak self] in
                self?.inventory.append(Self.silentSlippers)
                self?.engine.shields += 1
            })
        case 1:
            show(Popup(title: "A surprise!", message: "A lucky clock rolled onto the ledge. +20 seconds!",
                       symbol: "clock.fill", color: .orange, button: "Take") { [weak self] in
                self?.engine.timeLeft += 20
            })
        default:
            show(Popup(title: "A surprise!", message: "A glowing star ball! You feel a little faster.",
                       symbol: "star.circle.fill", color: .yellow, button: "Take") { [weak self] in
                self?.engine.speedBonus += 0.1
            })
        }
    }

    private func openJewelryBox(_ i: Int) {
        guard !engine.things[i].open else {
            engine.say("Just Mom's earrings left. Better not touch those.")
            return
        }
        engine.things[i].open = true
        Sound.key.play()
        show(Popup(title: "Mom's spare key!", message: "It opens the front door too. Now you don't need your brother's key!",
                   symbol: "key.fill", color: .pink, button: "Take Key") { [weak self] in
            self?.inventory.append(Self.spareKey)
            self?.award(.patienceIsKey)
        })
    }

    private func lookUnderBed(_ i: Int) {
        if toyInHand {
            useToy()
            giveToy("mom")
            engine.say("I tucked the toy in next to Mom. She smiled in her sleep!")
            return
        }
        guard engine.ducking else {
            engine.say("I have to crouch down to look under the bed. Press C!")
            return
        }
        guard !engine.things[i].open else {
            engine.say("Just dust bunnies under here now.")
            return
        }
        engine.things[i].open = true
        Sound.powerup.play()
        show(Popup(title: "Silent Slippers!", message: "Fluffy and quiet. You can bump into one thing without making a sound!",
                   symbol: "shoeprints.fill", color: .purple, button: "Put On") { [weak self] in
            self?.inventory.append(Self.silentSlippers)
            self?.engine.shields += 1
        })
    }

    private func useAlarmClock(_ i: Int) {
        guard !engine.things[i].open else {
            engine.say("I already turned the clock back.")
            return
        }
        engine.things[i].open = true
        Sound.beep.play()
        Sound.powerup.play()
        engine.timeLeft += 30
        show(Popup(title: "+30 seconds!", message: "You turned Mom's alarm clock back. More time to sneak!",
                   symbol: "alarm.fill", color: .orange, button: "Nice!") {})
    }

    func readPaper() {
        guard has(Self.paper) else { return }
        Sound.paper.play()
        show(Popup(title: code, message: "The code for the front door.", symbol: "doc.text.fill", color: .white, button: "OK") {})
    }

    // MARK: Front door

    private func useExitDoor() {
        guard !doorOpen else { return }
        if !codeAccepted {
            Sound.beep.play()
            engine.running = false
            showKeypad = true
        } else {
            tryKeys()
        }
    }

    /// Returns true when the code was right.
    func submitCode(_ entry: String) -> Bool {
        let normalize = { (s: String) in s.uppercased().replacingOccurrences(of: "0", with: "O").filter { !$0.isWhitespace } }
        guard normalize(entry) == normalize(code) else {
            Sound.buzz.play()
            return false
        }
        Sound.unlock.play()
        if !has(Self.paper) { award(.luckyGuess) }
        codeAccepted = true
        showKeypad = false
        engine.running = true
        tryKeys()
        return true
    }

    func closeKeypad() {
        showKeypad = false
        engine.running = true
    }

    private func tryKeys() {
        let keys = (has(Self.windowKey) ? 1 : 0) + (has(Self.siblingKey) || has(Self.spareKey) ? 1 : 0)
        guard keys == 2 else {
            engine.say("The code worked! But there are 2 locks. I have \(keys) of 2 keys.")
            return
        }
        engine.running = false
        engine.timerOn = false
        phase = .over
        dadRun += 1
        inventory.removeAll { $0 == Self.windowKey || $0 == Self.siblingKey || $0 == Self.spareKey }
        onComplete()
        let thisRun = run
        Task { @MainActor in
            Sound.unlock.play()
            try? await Task.sleep(for: .seconds(0.4))
            Sound.unlock.play()
            try? await Task.sleep(for: .seconds(0.4))
            guard run == thisRun else { return }
            doorOpen = true
            Sound.door.play()
            try? await Task.sleep(for: .seconds(0.8))
            engine.walking = true
            withAnimation(.linear(duration: 0.7)) {
                engine.player = CGPoint(x: 3270, y: Self.floor.lowerBound + 10)
                playerOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.8))
            engine.walking = false
            Sound.win.play()
            let withBrother = buddy.state == .following
            if withBrother { rewardToy() }
            show(Popup(title: "Level Complete!", message: withBrother ? "You and your brother made it! He gave you his toy: press G to stun Mom with it."
                                                                      : "You sneaked all the way down the hallway!",
                       symbol: "star.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                       secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
        }
    }

    // MARK: Dad

    /// While you're in Mom's room, Dad comes to check every 9–15 seconds.
    private func startDadPatrol() {
        let thisRun = run
        let thisPatrol = dadRun
        func stillHere() -> Bool { run == thisRun && dadRun == thisPatrol && room == .momRoom }
        Task { @MainActor in
            while true {
                var wait = Double.random(in: 9...15)
                while wait > 0 {
                    try? await Task.sleep(for: .seconds(0.25))
                    guard stillHere(), !chase.active else { return }
                    if engine.running && !engine.paused && phase == .sneaking { wait -= 0.25 }
                }
                Sound.dad.play()
                banner = "Footsteps... Dad is coming! Hide!"
                var warning = 3.0
                while warning > 0 {
                    try? await Task.sleep(for: .seconds(0.25))
                    guard stillHere(), phase == .sneaking else {
                        if banner?.contains("Dad") == true { banner = nil }
                        return
                    }
                    if engine.running && !engine.paused { warning -= 0.25 }
                }
                banner = nil
                Sound.door.play(volume: 0.5)
                withAnimation(.spring(duration: 0.4)) { dadVisible = true }
                var looking = 2.6
                while looking > 0 {
                    try? await Task.sleep(for: .seconds(0.2))
                    guard stillHere() else { return }
                    // While he's laughing or tangled up he just stands there.
                    if dadPause > 0 { continue }
                    if !engine.concealed && phase == .sneaking {
                        // He's seen you! He comes after you from the doorway.
                        dadVisible = false
                        dadStunned = false
                        chase.alarm(.dad, "Dad spotted you! RUN!", from: CGPoint(x: 150, y: 600))
                        return
                    }
                    looking -= 0.2
                }
                withAnimation(.easeOut(duration: 0.3)) { dadVisible = false }
                dadLaughed = false
                award(.shh)
                engine.say("Phew... Dad didn't see me.")
            }
        }
    }

    // MARK: Getting caught

    /// Bumping something makes a noise, and Mom gets up to see what it was.
    private func bumped(_ i: Int) {
        let hazard = engine.things[i].hazard
        if hazard == .toy { award(.deadlySqueak) }
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard !chase.active else { return }
        chase.alarm(.mom, "\(hazard?.noise ?? "CRASH!") Mom heard it. She's coming!")
    }

    /// Out of time or too loud: Mom gets out of bed and comes looking for you.
    private func momWakesUp(tooLoud: Bool) {
        guard phase == .sneaking else { return }
        guard !chase.active else {
            engine.resetNoise()
            return
        }
        if !tooLoud { award(.amNotPm) }
        chase.alarm(.mom, tooLoud ? "Too loud! Mom woke up. She's coming to find you!" : "Time's up! Mom woke up. She's coming to find you!")
    }

    /// Where a grown-up walks in for the room you're in, and how long that takes them.
    private func entrance(for who: Chase.Who) -> (CGPoint, Double) {
        switch room {
        case .hallway: (CGPoint(x: 2200, y: 575), 2.5)
        case .siblingRoom: (CGPoint(x: 150, y: 600), 5)
        case .momRoom: who == .mom ? (CGPoint(x: 1180, y: 610), 1.5) : (CGPoint(x: 150, y: 600), 2.5)
        }
    }

    /// A minute went by without catching you.
    private func gaveUp(_ who: Chase.Who) {
        award(.shh)
        engine.resetNoise()
        engine.timerOn = true
        if who == .mom {
            engine.timeLeft = 120
            engine.say("Mom gave up and went back to bed. 2 minutes until she wakes up again!", seconds: 4)
        } else {
            engine.say("Dad gave up and went back to his cocoa. Phew!", seconds: 3)
            if room == .momRoom { startDadPatrol() }
        }
    }

    private func caught(_ who: Chase.Who, _ message: String) {
        award(.oopsies)
        if who == .dad { award(.hiDad) }
        phase = .over
        banner = nil
        engine.running = false
        Sound.caught.play()
        show(Popup(title: "Caught!", message: message, symbol: "exclamationmark.triangle.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        // The button's own action runs first, so it can change the phase before the game resumes.
        wrapped.action = { [weak self] in
            newPopup.action()
            self?.closePopup()
        }
        wrapped.secondAction = { [weak self] in
            newPopup.secondAction()
            self?.closePopup()
        }
        withAnimation { popup = wrapped }
    }

    private func closePopup() {
        withAnimation { popup = nil }
        engine.running = phase == .sneaking || phase == .warning
    }

    /// Practice mode: where the Guide leads you next. In another room, he leads you to its door first.
    private func guideGoal() -> CGPoint? {
        let target: (room: Room, id: String)
        if !has(Self.windowKey) {
            target = (.hallway, "window")
        } else if !has(Self.siblingKey) && !has(Self.spareKey) {
            target = (.siblingRoom, "nightstand")
        } else if !has(Self.paper) && !codeAccepted {
            target = (.hallway, paperBox)
        } else {
            target = (.hallway, "exitDoor")
        }
        if room == target.room { return engine.spot(target.id) }
        if room == .hallway { return engine.spot(target.room == .siblingRoom ? "siblingDoor" : "momDoor") }
        return engine.spot("hallDoor")
    }

    func hint() {
        if !has(Self.windowKey) {
            engine.say(windowOpen ? "Grab the shiny thing on the window ledge!" : "Try opening the window. I saw something shiny!")
        } else if !has(Self.siblingKey) && !has(Self.spareKey) {
            engine.say("I need one more key. There's one by my brother's bed... or maybe Mom has a spare?")
        } else if !has(Self.paper) && !codeAccepted {
            engine.say("The door code is on a paper. Search the boxes!")
        } else {
            engine.say("Go to the front door at the end of the hallway!")
        }
    }
}

// MARK: - View

struct HallwayLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = HallwayModel()

    private var title: String {
        switch model.room {
        case .hallway: "Level 2 · Hallway"
        case .siblingRoom: "Level 2 · Brother's Room"
        case .momRoom: "Level 2 · Mom's Room"
        }
    }

    var body: some View {
        LevelScaffold(engine: model.engine, title: title, inventory: model.inventory,
                      onInventoryTap: { item in if item == HallwayModel.paper { model.readPaper() } },
                      popup: model.popup, banner: model.banner,
                      belt: model.belt, chase: model.chase, guideTips: GuideTips.level2,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            Group {
                switch model.room {
                case .hallway: hallway
                case .siblingRoom: siblingRoom
                case .momRoom: momRoom
                }
            }
            .allowsHitTesting(false)
        } extra: {
            if model.showKeypad {
                KeypadView(onSubmit: model.submitCode, onCancel: model.closeKeypad)
            }
            if let scene = model.windowView {
                WindowViewOverlay(scene: scene, onClose: model.closeWindowView)
                    .transition(.opacity)
            }
            if model.drawing { DrawingPad(onDone: model.finishDrawing) }
            if model.buddy.talking {
                TalkOverlay(buddy: model.buddy, tip: model.brotherTip,
                            onGiveToy: giveToyAction, onClose: model.closeTalk)
            }
        }
        .onAppear {
            model.onComplete = { game.complete(level: 2) }
            model.onExit = onExit
            model.onNext = onNext
            model.knownSkills = { game.skills }
            model.learn = { game.learn($0) }
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.onRetry = { game.noteRetry() }
            model.giveToy = { game.give(toyTo: $0) }
            model.rewardToy = { game.hasToy = true }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    /// "Give him a toy" only shows in the talk menu while you're holding one.
    private var giveToyAction: (() -> Void)? {
        guard model.toyInHand else { return nil }
        return { model.giveBrotherToy() }
    }

    private var hallway: some View {
        ZStack(alignment: .topLeading) {
            HallwayWall(width: HallwayModel.hallWidth)
            wallItems
            floorLayer
            mom
            Palette.shade.opacity((0.22) * Palette.shadeAmount)
        }
        .frame(width: HallwayModel.hallWidth, height: 700, alignment: .topLeading)
    }

    private var siblingRoom: some View {
        ZStack(alignment: .topLeading) {
            SiblingRoomWall(width: HallwayModel.roomWidth)
            wallItems
            floorLayer
            mom
            Palette.shade.opacity((0.2) * Palette.shadeAmount)
        }
        .frame(width: HallwayModel.roomWidth, height: 700, alignment: .topLeading)
    }

    private var momRoom: some View {
        ZStack(alignment: .topLeading) {
            MomRoomWall(width: HallwayModel.momRoomWidth)
            wallItems
            floorLayer
            mom
            if model.dadVisible {
                DadView(stunned: model.dadStunned)
                    .anchored(at: CGPoint(x: 150, y: 600))
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
            Palette.shade.opacity((0.28) * Palette.shadeAmount)
        }
        .frame(width: HallwayModel.momRoomWidth, height: 700, alignment: .topLeading)
    }

    private var wallItems: some View {
        ForEach(engine.things.filter { !$0.onFloor }) { thing in
            wallItem(thing).anchored(at: thing.pos)
        }
    }

    private var floorLayer: some View {
        ZStack(alignment: .topLeading) {
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                floorItem(thing)
            }
            if !engine.hidden && (model.buddy.state == .following || (model.buddy.state == .awake && model.room == .siblingRoom)) {
                BuddyView(buddy: model.buddy)
            }
        }
    }

    private var mom: some View {
        ChaserView(chase: model.chase)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "closet": ClosetView(hiding: model.hidingIn == thing.id)
        case "dresser": DresserView(open: thing.open)
        case "nightstand": NightstandView(open: thing.open)
        case "window": HallWindowView(open: model.windowOpen, keyTaken: model.inventory.contains(HallwayModel.windowKey))
        case "bedroomDoor": DoorView(color: Color(red: 0.45, green: 0.32, blue: 0.55)) { DoorSign(text: "My Room", color: .yellow) }
        case "siblingDoor": DoorView(color: Color(red: 0.35, green: 0.55, blue: 0.75)) { DoorSign(text: "KEEP OUT ★", color: .orange) }
        case "hallDoor": DoorView(color: model.room == .momRoom ? Color(red: 0.55, green: 0.30, blue: 0.30)
                                                                : Color(red: 0.35, green: 0.55, blue: 0.75),
                                  open: model.dadVisible) { EmptyView() }
        case "momDoor": DoorView(color: Color(red: 0.55, green: 0.30, blue: 0.30), open: model.chase.momOut && model.room == .hallway) {
            DoorSign(text: "MOM ♥", color: .pink)
        }
        case "exitDoor": ExitDoorView(open: model.doorOpen, codeAccepted: model.codeAccepted)
        case "sibBed": SiblingBedView(empty: model.buddy.state != .asleep)
        case "vanity": VanityView(open: thing.open)
        case "momBed": MomBedView(empty: model.chase.momOut)
        case "momNightstand": AlarmNightstandView(turnedBack: thing.open)
        case "toyChest": ToyChestView()
        case "paper": PaperStackView()
        case "dadDesk": DadDeskView()
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "box": CardboardBox(open: thing.open)
        case "chair": ChairView()
        case "lamp": FloorLampView()
        case "table": SideTableView()
        case "blocks": BlocksView()
        case "duck": DuckView()
        case "car": ToyCarView(facingRight: thing.speed > 0)
        case "ball": ToyBallView()
        case "robot": ToyRobotView()
        case "shoes": ShoesView()
        case "basket": LaundryBasketView()
        default: EmptyView()
        }
    }
}

// MARK: - Code keypad

struct KeypadView: View {
    var hint = "Find the paper with the code if you don't know it."
    let onSubmit: (String) -> Bool
    let onCancel: () -> Void
    @State private var entry = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Palette.gold)
                Text("Enter the door code")
                    .font(.game(36, .heavy))
                    .foregroundStyle(.white)
                Text(wrong ? "Wrong code! Try again." : hint)
                    .font(.game(20, .medium))
                    .foregroundStyle(wrong ? .red : .white.opacity(0.8))
                HStack(spacing: 16) {
                    TextField("CODE", text: $entry)
                        .focused($focused)
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .padding(.vertical, 10)
                        .frame(width: 260)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .offset(x: wrong ? -8 : 0)
                        .onChange(of: entry) { _, new in
                            if new.count > 6 { entry = String(new.prefix(6)) }
                            if wrong { wrong = false }
                        }
                    BigButton(title: "Enter", action: submit)
                }
                Button("Cancel") {
                    SoundPlayer.shared.tap()
                    onCancel()
                }
                .font(.game(22, .semibold))
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(36)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 36))
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
            .padding(.bottom, focused ? 240 : 0)
            .animation(.spring(duration: 0.3), value: focused)
        }
        .onAppear { focused = true }
    }

    private func submit() {
        if !onSubmit(entry) {
            withAnimation(.spring(duration: 0.15, bounce: 0.8)) { wrong = true }
            entry = ""
            focused = true
        }
    }
}
