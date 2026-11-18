import SwiftUI
import Observation

/// Level 3 rules, in the order you're meant to solve them:
/// 1. Go down the stairs without stepping on a loose plank (jump them — crouching doesn't help).
/// 2. Take food from the fridge and throw it out of the window: a dog with a key comes to the front
///    door. Bring him a second snack and he swaps it for his key (it locks the exit from outside).
/// 3. Three door keys are locked in boxes around the house. Find 3 metal scraps, craft a key from
///    each at the garage workbench, and open the boxes.
/// 4. With all 3 door keys, flip the garage light switch 3 times. Dad comes down to check: hide in
///    a closet until he's in the garage.
/// 5. Upstairs, take a toy from your brother's room and throw it in the hallway. Mom comes out to
///    look at it; while she's busy, take her phone (passcode 12345) and read Notes: the code is 0090.
/// 6. Dad is now in the basement. Dodge him (closets are safe), type 0090 at the exit door.
/// 7. Outside, lock the door with the dog's key before Dad gets out, then walk to the garden.
/// A ladder in the garage lets you climb out of the upstairs window onto the roof (star balls).
/// Each big step adds 45 seconds to the clock.
@MainActor
@Observable
final class DownstairsModel {
    enum Room: Hashable { case stairs, downstairs, garage, basement, yard, hallway, brotherRoom, momRoom, roof }
    enum Phase { case sneaking, warning, searching, over }
    enum DadPlace { case upstairs, comingDown, walkingToGarage, inGarage, basement }
    enum MomPlace { case asleep, coming, atToy, returning }

    let engine = GameEngine()
    let buddy = SiblingBuddy()
    var room: Room = .stairs
    var phase: Phase = .sneaking
    var popup: Popup?
    var banner: String?
    var hidingIn: String?
    var playerOpacity = 1.0

    // Quest progress
    var hasFood = false
    var dogWaiting = false
    var hasDogKey = false
    var scraps = 0
    var smallKeys = 0
    var doorKeys = 0
    var garageLight = false
    var hasLadder = false
    var hasToy = false
    var hasPhoneCode = false
    var codeAccepted = false
    var exitOpen = false
    var doorLocked = false
    var stars = 0
    var showPhone = false
    /// The drawing pad is open (paper from your brother's room).
    var drawing = false
    var showKeypad = false

    // Grown-ups
    var dad: DadPlace = .upstairs
    var dadX: CGFloat = 1300
    var dadChecking = false
    var mom: MomPlace = .asleep
    var momX: CGFloat = 2200
    /// True once Mom has stepped out of her door to look at the toy.
    var momOut = false
    /// Mom standing in the room you're in (woken by noise, a bump, or the clock).
    /// Mom or Dad coming after you.
    let chase = Chase()
    var toyX: CGFloat?

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var giveToy: (String) -> Void = { _ in }
    @ObservationIgnored var rewardToy: () -> Void = {}
    @ObservationIgnored var newBoost: () -> Boost? = { nil }
    @ObservationIgnored private var boostTime = 60.0
    let belt = ItemBelt()
    var dadStunned = false
    /// Seconds Dad won't catch you: laughing at your taunt, or tangled in vines.
    @ObservationIgnored private var dadPause = 0.0
    @ObservationIgnored private var dadLaughed = false
    /// The golden stick deleted Mom. She can't catch anyone now.
    @ObservationIgnored private var momDeleted = false

    @ObservationIgnored private var saved: [Room: [Thing]] = [:]
    @ObservationIgnored private var scrapSpots: Set<String> = []
    @ObservationIgnored private var checkpoints: Set<String> = []
    @ObservationIgnored private var run = 0
    @ObservationIgnored var playerName = ""
    @ObservationIgnored private var lightFlips = 0
    @ObservationIgnored private var lureTime = 0.0
    @ObservationIgnored private var dadDirection: CGFloat = -1
    @ObservationIgnored private var dadCheckStage = 0
    @ObservationIgnored private var dadCheckTime = 12.0
    @ObservationIgnored private var momTime = 0.0
    @ObservationIgnored private var lockTime = 0.0
    @ObservationIgnored private var starTime = 3.0
    @ObservationIgnored private var sawStreet = false
    @ObservationIgnored private var sawGarden = false
    @ObservationIgnored private var starCount = 0

    static let floor = HallwayModel.floor
    /// On Easy both codes are just three numbers.
    static var passcode: String { Difficulty.current == .easy ? "123" : "12345" }
    static var exitCode: String { Difficulty.current == .easy ? "090" : "0090" }
    static let searchSpots = ["couch", "bookshelf", "kitchenDrawer", "bin", "toolbox", "trunk"]
    static let lockboxSpots = ["lockbox1", "lockbox2", "lockbox3", "lockbox4", "lockbox5"]
    static let widths: [Room: CGFloat] = [.stairs: 1800, .downstairs: 3000, .garage: 1500, .basement: 1900, .yard: 1600,
                                          .hallway: HallwayModel.hallWidth, .brotherRoom: HallwayModel.roomWidth,
                                          .momRoom: HallwayModel.momRoomWidth, .roof: DownstairsModel.roofWidth]

    var inventory: [InventoryItem] {
        var items: [InventoryItem] = []
        if hasFood { items.append(InventoryItem(id: "food", symbol: "fork.knife", color: .orange)) }
        if hasDogKey { items.append(InventoryItem(id: "dogKey", symbol: "key.fill", color: .cyan)) }
        for i in 0..<scraps { items.append(InventoryItem(id: "scrap\(i)", symbol: "gearshape.fill", color: Palette.silver)) }
        for i in 0..<smallKeys { items.append(InventoryItem(id: "small\(i)", symbol: "key.fill", color: Palette.silver)) }
        for i in 0..<doorKeys { items.append(InventoryItem(id: "door\(i)", symbol: "key.fill", color: Palette.gold)) }
        if hasToy { items.append(InventoryItem(id: "toy", symbol: "teddybear.fill", color: .pink)) }
        if hasLadder { items.append(InventoryItem(id: "ladder", symbol: "arrow.up.to.line", color: .brown)) }
        if hasPhoneCode { items.append(InventoryItem(id: "code", symbol: "note.text", color: .yellow)) }
        return items
    }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onDefaultInteract = { [weak self] in self?.defaultAction() }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onPuddle = { [weak self] in self?.splashed() }
        engine.onTimeUp = { [weak self] in self?.momWakesUp(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momWakesUp(tooLoud: true) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.taunted() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.stunGrownUp(seconds, momOnly: momOnly) ?? false }
        belt.goldenStick = { [weak self] in self?.stickDeletes() }
        chase.engine = engine
        chase.entrance = { [weak self] who in self?.entrance(for: who) ?? (.zero, 2) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.brotherFollowing = { [weak self] in self?.buddy.state == .following }
        chase.brotherPos = { [weak self] in
            guard let self, buddy.state == .following || (buddy.state == .awake && room == .brotherRoom) else { return nil }
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
        belt.reset()
        dadStunned = false
        dadPause = 0
        dadLaughed = false
        momDeleted = false
        scrapSpots = Set(Self.searchSpots.shuffled().prefix(3))
        let boxes = Set(Self.lockboxSpots.shuffled().prefix(3))
        saved = [
            .stairs: Self.stairsThings() + HallwayModel.puddles([(680, 600)]),
            .downstairs: Self.downstairsThings().filter { !$0.id.hasPrefix("lockbox") || boxes.contains($0.id) }
                + HallwayModel.puddles([(1320, 650), (2060, 600)]),
            .garage: Self.garageThings().filter { !$0.id.hasPrefix("lockbox") || boxes.contains($0.id) },
            .basement: Self.basementThings().filter { !$0.id.hasPrefix("lockbox") || boxes.contains($0.id) },
            .yard: Self.yardThings(),
            .hallway: Self.hallwayThings(),
            .brotherRoom: Self.brotherRoomThings(),
            .momRoom: Self.momRoomThings(),
            .roof: Self.roofThings(),
        ]
        room = .stairs
        engine.load(SceneLayout(width: Self.widths[.stairs]!, floor: Self.floor, things: saved[.stairs]!, spawn: CGPoint(x: 220, y: 615)))
        engine.timeLeft = Levels.time(3)
        engine.timerOn = true
        engine.resetNoise()
        engine.noiseFactor = 1
        engine.speedBoost = false
        engine.jumpBoost = false
        engine.shields = 0
        engine.speedBonus = 0
        engine.runHeld = false
        engine.tauntOnly = false
        chase.reset()
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        buddy.reset()
        phase = .sneaking
        popup = nil
        banner = nil
        hidingIn = nil
        playerOpacity = 1
        hasFood = false
        dogWaiting = false
        hasDogKey = false
        scraps = 0
        smallKeys = 0
        doorKeys = 0
        garageLight = false
        hasLadder = false
        hasToy = false
        hasPhoneCode = false
        codeAccepted = false
        exitOpen = false
        doorLocked = false
        stars = 0
        showPhone = false
        showKeypad = false
        dad = .upstairs
        dadChecking = false
        mom = .asleep
        momOut = false
        toyX = nil
        checkpoints = []
        lightFlips = 0
        boostTime = 60
        dadCheckStage = 0
        dadCheckTime = 12
        starCount = 0
        engine.running = true
        engine.say("The stairs are creaky. I'd better jump over the loose planks!", seconds: 4)
    }

    // MARK: Rooms

    private static func wall(_ id: String, _ kind: String, x: CGFloat, prompt: String?, reach: CGFloat = 70) -> Thing {
        HallwayModel.onWall(id, kind, x: x, prompt: prompt, reach: reach)
    }

    private static func plank(_ n: Int, x: CGFloat, y: CGFloat, depth: CGFloat) -> Thing {
        var t = Thing(id: "plank\(n)", kind: "plank", pos: CGPoint(x: x, y: y), footprint: CGSize(width: 84, height: depth), hazard: .plank)
        t.crouchSafe = false
        t.flat = true
        return t
    }

    static func stairsThings() -> [Thing] {
        [
            wall("toHallway", "stairsUp", x: 110, prompt: "Go upstairs"),
            plank(1, x: 400, y: 580, depth: 58),
            plank(2, x: 570, y: 662, depth: 50),
            plank(3, x: 770, y: 617, depth: 145),
            plank(4, x: 960, y: 572, depth: 46),
            plank(5, x: 1100, y: 664, depth: 46),
            plank(6, x: 1290, y: 617, depth: 145),
            plank(7, x: 1480, y: 598, depth: 90),
            wall("toDownstairs", "stairsDown", x: 1690, prompt: "Go downstairs"),
        ]
    }

    static func downstairsThings() -> [Thing] {
        [
            wall("toStairs", "stairsUp", x: 110, prompt: "Go upstairs"),
            wall("closetA", "closet", x: 330, prompt: "Hide in the closet"),
            wall("couch", "couch", x: 590, prompt: "Search the couch", reach: 90),
            HallwayModel.obstacle("table1", .table, x: 760, y: 645, size: CGSize(width: 110, height: 36)),
            wall("dWindow", "dWindow", x: 900, prompt: "Look out of the window"),
            wall("bookshelf", "bookshelf", x: 1100, prompt: "Search the bookshelf"),
            HallwayModel.obstacle("lamp1", .lamp, x: 1250, y: 580, size: CGSize(width: 40, height: 26)),
            wall("frontDoor", "frontDoor", x: 1410, prompt: "Check the front door"),
            wall("lockbox1", "lockbox", x: 1580, prompt: "Open the lockbox", reach: 55),
            wall("fridge", "fridge", x: 1770, prompt: "Grab some food"),
            HallwayModel.obstacle("chair1", .chair, x: 1890, y: 655, size: CGSize(width: 64, height: 30)),
            wall("kitchenDrawer", "kitchenCounter", x: 1980, prompt: "Search the kitchen drawer", reach: 80),
            wall("lockbox2", "lockbox", x: 2150, prompt: "Open the lockbox", reach: 55),
            wall("closetB", "closet", x: 2320, prompt: "Hide in the closet"),
            wall("toGarage", "garageDoor", x: 2530, prompt: "Go into the garage"),
            wall("toBasement", "basementDoor", x: 2790, prompt: "Go down to the basement"),
        ]
    }

    static func garageThings() -> [Thing] {
        [
            wall("toHouse", "houseDoor", x: 110, prompt: "Back into the house"),
            wall("switch", "lightSwitch", x: 270, prompt: "Flip the light switch", reach: 50),
            wall("bin", "bin", x: 410, prompt: "Search the recycling bin", reach: 55),
            HallwayModel.obstacle("cans", .cans, x: 540, y: 660, size: CGSize(width: 60, height: 26)),
            Thing(id: "car", kind: "car", pos: CGPoint(x: 760, y: floor.lowerBound), heavy: true, reach: CGSize(width: 180, height: 160)),
            wall("lockbox3", "lockbox", x: 1000, prompt: "Open the lockbox", reach: 50),
            wall("workbench", "workbench", x: 1130, prompt: "Use the workbench", reach: 65),
            wall("toolbox", "toolbox", x: 1280, prompt: "Search the toolbox", reach: 55),
            wall("ladder", "ladder", x: 1410, prompt: "Grab the ladder", reach: 55),
        ]
    }

    static func basementThings() -> [Thing] {
        [
            wall("toHouseUp", "stairsUp", x: 110, prompt: "Back upstairs"),
            wall("trunk", "trunk", x: 330, prompt: "Search the old trunk"),
            wall("lockbox4", "lockbox", x: 540, prompt: "Open the lockbox", reach: 55),
            wall("closetC", "closet", x: 760, prompt: "Hide in the closet"),
            Thing(id: "washer", kind: "washer", pos: CGPoint(x: 960, y: floor.lowerBound), heavy: true, reach: CGSize(width: 70, height: 160)),
            HallwayModel.obstacle("bucket", .cans, x: 1010, y: 660, size: CGSize(width: 50, height: 26)),
            wall("lockbox5", "lockbox", x: 1160, prompt: "Open the lockbox", reach: 55),
            wall("closetD", "closet", x: 1400, prompt: "Hide in the closet"),
            wall("exitDoor", "exitDoor", x: 1750, prompt: "Unlock the door", reach: 90),
        ]
    }

    static func yardThings() -> [Thing] {
        [
            wall("yardDoor", "yardDoor", x: 170, prompt: "Lock the door", reach: 90),
            wall("gate", "gardenGate", x: 1450, prompt: "Go into the garden", reach: 90),
        ]
    }

    /// The Level 2 hallway again; its far door now leads to the stairs.
    static func hallwayThings() -> [Thing] {
        HallwayModel.hallThings().map { thing in
            var t = thing
            switch t.id {
            case "exitDoor": t = wall("toStairs", "stairsDown", x: 3270, prompt: "Go downstairs")
            case "window": t.prompt = "Look out of the window"
            default: break
            }
            return t
        }
    }

    static func brotherRoomThings() -> [Thing] {
        HallwayModel.siblingRoomThings()
    }

    static func momRoomThings() -> [Thing] {
        HallwayModel.momRoomThings().map { thing in
            var t = thing
            if t.id == "momNightstand" { t.prompt = "Grab Mom's phone" }
            return t
        }
    }

    /// The roof runs the whole length of the house. The window is 830 along; past each end
    /// (`roofEdge` from either side) you look down on the street or the garden.
    static let roofWidth: CGFloat = 3400
    static let roofEdge: CGFloat = 560

    static func roofThings() -> [Thing] {
        [
            wall("roofWindow", "roofWindow", x: 830, prompt: "Climb back inside", reach: 90),
            wall("owl", "owl", x: 1505, prompt: "Look at the chimney", reach: 60),
        ]
    }

    private func go(to newRoom: Room, at spawn: CGPoint) {
        Sound.door.play(volume: 0.5)
        saved[room] = engine.things
        engine.load(SceneLayout(width: Self.widths[newRoom]!, floor: Self.floor, things: saved[newRoom] ?? [], spawn: spawn))
        engine.noiseFactor = newRoom == .roof ? 0 : (newRoom == .momRoom && mom == .asleep ? 2 : 1)
        hidingIn = nil
        dadChecking = false
        dadCheckStage = 0
        dadCheckTime = Double.random(in: 9...15)
        if banner?.contains("Footsteps") == true { banner = nil }
        room = newRoom
        chase.playerChangedRoom(entry: spawn)
        if buddy.state == .following { buddy.jump(to: engine.player) }
        refreshPrompts()
        // The clock stops while you're up on the roof.
        if phase == .sneaking && !chase.active { engine.timerOn = newRoom != .roof && newRoom != .yard }

        switch newRoom {
        case .downstairs:
            checkpoint("downstairs")
        case .basement:
            if dad == .basement {
                dadX = max(dadX, 1000)
                engine.say("Dad is down here! Closets are safe — he won't check them.", seconds: 4)
            }
        case .yard:
            engine.timerOn = false
            lockTime = 10
            checkpoint("outside")
        case .roof:
            award(.fly)
            engine.say("The roof! Nobody can hear me up here.", seconds: 3)
        case .momRoom:
            if mom == .asleep { engine.say("Shhh! Mom's asleep.") }
        default: break
        }
    }

    /// Prompts that depend on what you're carrying or what has happened.
    private func refreshPrompts() {
        engine.defaultPrompt = hasToy && room == .hallway ? "Throw the toy"
            : buddy.state == .following ? "Talk to your brother" : nil
        func set(_ id: String, _ prompt: String?) {
            if let i = engine.index(of: id) { engine.things[i].prompt = prompt }
        }
        switch room {
        case .downstairs:
            set("dWindow", hasFood && !dogWaiting ? "Throw food out of the window" : "Look out of the window")
            set("frontDoor", dogWaiting && !hasDogKey ? (hasFood ? "Give the dog a snack" : "Check on the dog") : "Check the front door")
        case .hallway:
            set("window", hasLadder ? "Climb out onto the roof" : "Look out of the window")
        case .yard:
            set("yardDoor", doorLocked ? nil : "Lock the door")
        case .garage:
            set("ladder", hasLadder ? nil : "Grab the ladder")
        default: break
        }
    }

    private func checkpoint(_ id: String) {
        guard !checkpoints.contains(id) else { return }
        checkpoints.insert(id)
        engine.timeLeft += 45
        Sound.star.play()
        let text = "Checkpoint! +45 seconds"
        banner = text
        let thisRun = run
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if run == thisRun && banner == text { banner = nil }
        }
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "closet": toggleHiding(in: thing)
        case "stairsUp", "stairsDown", "garageDoor", "basementDoor", "houseDoor", "roofWindow", "siblingDoor", "momDoor", "hallDoor":
            useDoor(thing)
        case "couch", "bookshelf", "kitchenCounter", "bin", "toolbox", "trunk": search(i)
        case "fridge": useFridge()
        case "dWindow": useDownstairsWindow()
        case "frontDoor": useFrontDoor()
        case "lockbox": openLockbox(i)
        case "lightSwitch": flipSwitch()
        case "workbench": craft()
        case "ladder":
            hasLadder = true
            engine.things[i].hidden = true
            Sound.box.play()
            engine.say("Got the ladder! I could use it at the upstairs hallway window...", seconds: 4)
            refreshPrompts()
        case "owl":
            award(.owl)
            Sound.window.play(volume: 0.4)
            engine.say("An owl! It winked at me. Hoo hoo!")
        case "exitDoor": useExitDoor()
        case "yardDoor": lockYardDoor()
        case "gardenGate": useGate()
        case "window": useHallwayWindow()
        case "box": searchBox(i)
        case "dresser", "nightstand": engine.say("Empty. I already took everything from here.")
        case "bedroomDoor": engine.say("Back to bed? No way!")
        case "toyChest": grabToy()
        case "paper": startDrawing()
        case "sibBed": talkToBrother()
        case "momNightstand": usePhone()
        case "vanity": engine.say("Just Mom's earrings. Better not touch those.")
        case "momBed":
            if hasToy && mom == .asleep {
                hasToy = false
                giveToy("mom")
                refreshPrompts()
                engine.say("I tucked the toy in next to Mom. She smiled in her sleep!")
            } else {
                engine.say(mom == .asleep ? "Mom is snoring. Shhh..." : "Mom's bed is empty!")
            }
        case "dadDesk":
            if hasToy {
                hasToy = false
                giveToy("dad")
                refreshPrompts()
                engine.say("I left the toy on Dad's desk. He'll find it in the morning!")
            } else {
                engine.say("Dad's desk. A cold cup of cocoa and yesterday's newspaper.")
            }
        default: break
        }
    }

    private func useDoor(_ thing: Thing) {
        switch thing.id {
        case "toHallway": go(to: .hallway, at: CGPoint(x: 3200, y: 600))
        case "toDownstairs": go(to: .downstairs, at: CGPoint(x: 210, y: 610))
        case "toStairs":
            go(to: .stairs, at: room == .hallway ? CGPoint(x: 220, y: 615) : CGPoint(x: 1600, y: 678))
        case "toGarage":
            if dad == .inGarage || dad == .walkingToGarage {
                engine.say("Dad is in there. No way!")
            } else {
                go(to: .garage, at: CGPoint(x: 200, y: 610))
            }
        case "toBasement": go(to: .basement, at: CGPoint(x: 200, y: 610))
        case "toHouse": go(to: .downstairs, at: CGPoint(x: 2530, y: 590))
        case "toHouseUp": go(to: .downstairs, at: CGPoint(x: 2790, y: 590))
        case "siblingDoor": go(to: .brotherRoom, at: CGPoint(x: 190, y: 600))
        case "momDoor": go(to: .momRoom, at: CGPoint(x: 190, y: 600))
        case "hallDoor": go(to: .hallway, at: CGPoint(x: room == .momRoom ? 2200 : 1540, y: 580))
        case "roofWindow": go(to: .hallway, at: CGPoint(x: 1010, y: 580))
        default: break
        }
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

    private func search(_ i: Int) {
        guard !engine.things[i].open else {
            engine.say("Nothing else in here.")
            return
        }
        engine.things[i].open = true
        Sound.drawer.play()
        if scrapSpots.contains(engine.things[i].id) {
            Sound.key.play()
            show(Popup(title: "Metal scrap!", message: "Scrap \(scraps + 1) of 3. The workbench in the garage can turn it into a key.",
                       symbol: "gearshape.fill", color: Palette.silver, button: "Take") { [weak self] in
                self?.scraps += 1
            })
        } else if let loot = rollLoot() {
            found(loot)
        } else {
            engine.say(["Just dust and crumbs.", "A lost sock. No scrap here.", "Old magazines. Nothing useful."].randomElement()!)
        }
    }

    private func found(_ loot: Loot) {
        Sound.magic.play()
        show(.loot(loot) { [weak self] in self?.take(loot) })
    }

    private func searchBox(_ i: Int) {
        engine.things[i].open = true
        Sound.box.play()
        if let loot = rollLoot() {
            found(loot)
        } else {
            engine.say(["Just old clothes.", "Only some books in here.", "A rubber chicken? Weird."].randomElement()!)
        }
    }

    private func useFridge() {
        guard !hasFood else {
            engine.say("I'm already holding a snack.")
            return
        }
        hasFood = true
        Sound.drawer.play()
        engine.say("Got a sausage. Smells yummy!")
        refreshPrompts()
    }

    private func useDownstairsWindow() {
        if dogWaiting {
            engine.say(hasDogKey ? "The street is quiet now." : "The dog is waiting at the front door.")
        } else if hasFood {
            hasFood = false
            dogWaiting = true
            Sound.window.play()
            let thisRun = run
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                guard run == thisRun else { return }
                Sound.woof.play()
            }
            engine.say("I threw the food outside... A dog came running! He has a KEY on his collar. He's at the front door now.", seconds: 5)
            refreshPrompts()
        } else {
            engine.say("Dark and quiet outside. Maybe some food would bring someone over...")
        }
    }

    private func useFrontDoor() {
        if !dogWaiting {
            engine.say("The front door. It has a pet flap at the bottom.")
        } else if hasDogKey {
            Sound.woof.play(volume: 0.5)
            engine.say("Good dog! He's wagging his tail.")
        } else if hasFood {
            hasFood = false
            Sound.woof.play()
            Sound.key.play()
            show(Popup(title: "The dog gave you a key!", message: "He swapped it for the snack through the pet flap. It locks the basement door from the outside.",
                       symbol: "key.fill", color: .cyan, button: "Take Key") { [weak self] in
                self?.hasDogKey = true
                self?.award(.patienceIsKey)
                self?.checkpoint("dogKey")
                self?.refreshPrompts()
            })
        } else {
            Sound.woof.play(volume: 0.6)
            engine.say("Woof! The dog wants another snack before he gives up the key.")
        }
    }

    private func openLockbox(_ i: Int) {
        if engine.things[i].open {
            engine.say("This lockbox is empty now.")
        } else if smallKeys > 0 {
            smallKeys -= 1
            engine.things[i].open = true
            Sound.unlock.play()
            Sound.key.play()
            show(Popup(title: "Door key \(doorKeys + 1) of 3!", message: doorKeys == 2 ? "That's all three! Now Dad needs to be lured downstairs... the garage light switch might do it."
                                                                                    : "The crafted key opened the lockbox.",
                       symbol: "key.fill", color: Palette.gold, button: "Take Key") { [weak self] in
                guard let self else { return }
                doorKeys += 1
                award(.patienceIsKey)
                checkpoint("doorKey\(doorKeys)")
            })
        } else {
            engine.say(scraps > 0 ? "Locked. I can craft a key from my metal scrap at the garage workbench."
                                  : "Locked tight. I need metal scrap to craft a key for it.")
        }
    }

    private func craft() {
        guard scraps > 0 else {
            engine.say("A workbench. With some metal scrap I could make a key here.")
            return
        }
        engine.running = false
        engine.crouching = true
        Sound.craft.play()
        let thisRun = run
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard run == thisRun else { return }
            Sound.key.play()
            show(Popup(title: "You crafted a key!", message: "It should fit one of the lockboxes around the house.",
                       symbol: "hammer.fill", color: Palette.silver, button: "Take Key") { [weak self] in
                self?.scraps -= 1
                self?.smallKeys += 1
            })
        }
    }

    private func flipSwitch() {
        garageLight.toggle()
        Sound.lightSwitch.play()
        guard dad == .upstairs else { return }
        guard doorKeys >= 3 else {
            engine.say("Better not play with the lights yet. I should find all 3 door keys first.")
            return
        }
        lightFlips += 1
        if lightFlips >= 3 {
            dad = .comingDown
            lureTime = 8
            Sound.dad.play()
        } else {
            engine.say("Flick! \(3 - lightFlips) more and Dad will notice...")
        }
    }

    private func useHallwayWindow() {
        if hasLadder {
            Sound.window.play()
            go(to: .roof, at: CGPoint(x: 930, y: 610))
        } else {
            engine.say("Just the quiet street. If only I had a ladder to climb out...")
        }
    }


    private func startDrawing() {
        Sound.paper.play()
        drawing = true
        engine.paused = true
    }

    func finishDrawing() {
        drawing = false
        engine.paused = false
        engine.say("Not bad! I'll show Grandpa.", seconds: 2.2)
    }

    private func grabToy() {
        guard !hasToy else {
            engine.say("One toy is enough.")
            return
        }
        hasToy = true
        Sound.squeak.play(volume: 0.3)
        engine.say("Got a squeaky toy. If I throw it in the hallway, Mom will come to look...", seconds: 4)
    }

    private func defaultAction() {
        if hasToy && room == .hallway {
            throwToy()
        } else {
            talkToBrother()
        }
    }

    private func throwToy() {
        guard mom == .asleep else { return }
        hasToy = false
        toyX = min(max(engine.player.x + (engine.facingRight ? 380 : -380), 250), 3150)
        Sound.squeak.play()
        mom = .coming
        momX = 2200
        momTime = 3
        banner = "Mom heard the toy! Hide before she comes out!"
        refreshPrompts()
    }

    private func usePhone() {
        // With Mom deleted by the golden stick, her phone is just lying there.
        guard mom != .asleep || chase.momOut || momDeleted else {
            engine.say("Mom's phone is right by her hand. I have to get her out of the room first!")
            return
        }
        Sound.beep.play()
        engine.running = false
        showPhone = true
    }

    func phoneNoteRead() {
        guard !hasPhoneCode else { return }
        hasPhoneCode = true
        checkpoint("code")
        dad = .basement
        dadX = 1400
        dadDirection = -1
    }

    func closePhone() {
        showPhone = false
        engine.running = phase == .sneaking || phase == .warning
        if hasPhoneCode { engine.say("\(Self.exitCode)! Dad finished in the garage — he's in the basement now.", seconds: 4) }
    }

    func readCode() {
        show(Popup(title: Self.exitCode, message: "The basement door code from Mom's phone.", symbol: "note.text", color: .yellow, button: "OK") {})
    }

    // MARK: Brother

    func giveBrotherToy() {
        hasToy = false
        giveToy("brother")
        refreshPrompts()
    }

    /// Where Dad is standing if he's in this room right now.
    private var dadHere: Bool {
        guard !engine.grownUpsGone else { return false }
        return (room == .momRoom && (dadChecking || banner?.contains("Footsteps") == true))
            || (room == .downstairs && dad == .walkingToGarage)
            || (room == .basement && dad == .basement && abs(engine.player.x - dadX) < 800)
    }

    /// Vines (anyone) or the reward toy (Mom only): stops whoever is in the room from catching you.
    private func stunGrownUp(_ seconds: Double, momOnly: Bool) -> Bool {
        if chase.stun(seconds, momOnly: momOnly) { return true }
        if !momOnly && dadHere {
            dadPause = seconds
            dadStunned = true
            return true
        }
        return false
    }

    private func taunted() {
        chase.taunted()
        // Dad thinks it's funny... once per visit. You get 10 seconds.
        if dadHere && !dadLaughed {
            dadLaughed = true
            dadPause = 10
            award(.funnySon)
            banner = "Dad: \"Ha! That's funny, son. You've got 10 seconds...\""
        }
        if (room == .brotherRoom || buddy.state == .following) && buddy.taunted() {
            award(.crashout)
            engine.say("Brother: \"STOP IT! You're SO annoying!!\"", seconds: 3)
        }
        if room == .brotherRoom && buddy.state == .asleep && phase == .sneaking {
            buddy.wake()
            Sound.squeak.play(volume: 0.5)
            engine.say("Oops... I woke up my brother!")
        }
    }

    private func talkToBrother() {
        guard buddy.state != .asleep else {
            engine.say("He's fast asleep. Only something really silly would wake him up...")
            return
        }
        guard room == .brotherRoom || buddy.state == .following else { return }
        engine.running = false
        buddy.startTalking()
    }

    func closeTalk() {
        engine.running = phase == .sneaking || phase == .warning
        refreshPrompts()
    }

    // MARK: Exit

    private func useExitDoor() {
        guard !exitOpen else { return }
        if !codeAccepted {
            Sound.beep.play()
            engine.frozen = true
            showKeypad = true
        } else {
            tryExit()
        }
    }

    func submitCode(_ entry: String) -> Bool {
        guard entry == Self.exitCode else {
            Sound.buzz.play()
            return false
        }
        Sound.unlock.play()
        codeAccepted = true
        closeKeypad()
        tryExit()
        return true
    }

    func closeKeypad() {
        showKeypad = false
        engine.frozen = false
    }

    private func tryExit() {
        guard doorKeys >= 3 else {
            engine.say("The code worked! But there are 3 locks. I have \(doorKeys) of 3 door keys.")
            return
        }
        exitOpen = true
        Sound.unlock.play()
        Sound.door.play()
        go(to: .yard, at: CGPoint(x: 260, y: 610))
        engine.facingRight = true
    }

    private func lockYardDoor() {
        guard !doorLocked else { return }
        guard hasDogKey else {
            engine.say("I can't lock it! I needed the key from the dog!")
            return
        }
        doorLocked = true
        banner = nil
        Sound.unlock.play()
        Sound.woof.play(volume: 0.5)
        engine.say("Locked! Dad can't follow me now. To the garden!")
        refreshPrompts()
    }

    private func useGate() {
        guard doorLocked else {
            engine.say("I have to lock the door first, or Dad will come after me!")
            return
        }
        phase = .over
        engine.running = false
        onComplete()
        let thisRun = run
        Task { @MainActor in
            engine.walking = true
            withAnimation(.linear(duration: 0.7)) {
                engine.player = CGPoint(x: 1500, y: Self.floor.lowerBound + 20)
                playerOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.8))
            guard run == thisRun else { return }
            engine.walking = false
            Sound.win.play()
            let withBrother = buddy.state == .following
            if withBrother { rewardToy() }
            show(Popup(title: "Level Complete!", message: withBrother ? "You and your brother made it out! He gave you his toy: press G to stun Mom with it."
                                                                      : "You made it out of the house and into the garden!",
                       symbol: "star.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                       secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
        }
    }

    // MARK: Every frame: Dad, Mom, the roof

    private func tick(_ dt: Double) {
        buddy.update(player: engine.player, playerFacingRight: engine.facingRight, dt: dt)
        chase.tick(dt)
        belt.tick(dt)
        if dadPause > 0 {
            dadPause -= dt
            if dadPause <= 0 {
                dadStunned = false
                dadLaughed = false
                if banner?.contains("funny") == true { banner = nil }
            }
        }
        guard phase == .sneaking else { return }
        // While someone is chasing you, the usual comings and goings are on hold.
        if !chase.active {
            tickDadCheck(dt)
            tickDad(dt)
            tickMom(dt)
        }
        tickYard(dt)
        tickRoof(dt)
    }

    /// Until he's lured away, Dad checks Mom's room now and then, like in Level 2.
    private func tickDadCheck(_ dt: Double) {
        guard dad == .upstairs, room == .momRoom, !engine.grownUpsGone else { return }
        dadCheckTime -= dt
        switch dadCheckStage {
        case 0:
            if dadCheckTime <= 0 {
                dadCheckStage = 1
                dadCheckTime = 3
                Sound.dad.play()
                banner = "Footsteps... Dad is coming! Hide!"
            }
        case 1:
            if dadCheckTime <= 0 {
                dadCheckStage = 2
                dadCheckTime = 2.6
                banner = nil
                dadChecking = true
                Sound.door.play(volume: 0.5)
            }
        default:
            if dadPause > 0 {
                dadCheckTime += dt
            } else if !engine.concealed {
                dadCheckStage = 0
                dadCheckTime = Double.random(in: 9...15)
                dadChecking = false
                chase.alarm(.dad, "Dad spotted you! RUN!", from: CGPoint(x: 150, y: 600))
            } else if dadCheckTime <= 0 {
                dadCheckStage = 0
                dadCheckTime = Double.random(in: 9...15)
                dadChecking = false
                award(.shh)
                engine.say("Phew... Dad didn't see me.")
            }
        }
    }

    private func tickDad(_ dt: Double) {
        // After the golden stick, Dad isn't around to walk anywhere: skip straight to "he's busy".
        if engine.grownUpsGone {
            if dad == .comingDown || dad == .walkingToGarage { banner = nil; dadInGarage() }
            return
        }
        switch dad {
        case .comingDown:
            let before = Int(lureTime.rounded(.up))
            lureTime -= dt
            let now = Int(max(lureTime, 0).rounded(.up))
            banner = "Dad saw the garage light! He's coming down! Hide in a closet! \(now)"
            if now != before && now % 2 == 0 { Sound.dad.play(volume: 0.7) }
            guard lureTime <= 0 else { return }
            banner = nil
            if room == .garage || room == .stairs || (room == .downstairs && !engine.concealed) {
                chase.alarm(.dad, "Dad came downstairs and spotted you! RUN!", from: CGPoint(x: 110, y: 605))
            } else if room == .downstairs {
                dad = .walkingToGarage
                dadX = 1300
            } else {
                dadInGarage()
            }
        case .walkingToGarage:
            if dadPause <= 0 || room != .downstairs { dadX += 300 * CGFloat(dt) }
            if room == .downstairs && dadPause <= 0 && !engine.concealed && abs(engine.player.x - dadX) < 420 {
                chase.alarm(.dad, "Dad saw you on his way to the garage! RUN!", from: CGPoint(x: dadX, y: 605))
            } else if dadX >= 2530 {
                dadInGarage()
            }
        case .basement:
            guard room == .basement else { return }
            guard dadPause <= 0 else { return }
            dadX += dadDirection * 150 * CGFloat(dt)
            if dadX < 260 { dadX = 260; dadDirection = 1 }
            if dadX > 1480 { dadX = 1480; dadDirection = -1 }
            if !engine.concealed && abs(engine.player.x - dadX) < 300 {
                chase.alarm(.dad, "Dad spotted you in the basement! RUN!", from: CGPoint(x: dadX, y: 605))
            }
        default: break
        }
    }

    private func dadInGarage() {
        dad = .inGarage
        garageLight = true
        if engine.concealed { award(.shh) }
        checkpoint("dadLured")
        engine.say("Dad went into the garage. Now's my chance to sneak upstairs!", seconds: 4)
    }

    private func dadCaught(_ message: String) {
        caught(.dad, message)
    }

    /// Mom walks out to the thrown toy, studies it for a while, then goes back to bed.
    private func tickMom(_ dt: Double) {
        guard mom != .asleep else { return }
        switch mom {
        case .coming:
            if momTime > 0 {
                momTime -= dt
                if momTime <= 0 {
                    Sound.door.play()
                    banner = nil
                    momOut = true
                }
                return
            }
            guard let toyX else { return }
            let direction: CGFloat = toyX > momX ? 1 : -1
            momX += direction * 190 * CGFloat(dt)
            if abs(toyX - momX) < 60 {
                mom = .atToy
                momTime = 22
            }
        case .atToy:
            momTime -= dt
            if momTime <= 0 { mom = .returning }
        case .returning:
            let direction: CGFloat = momX < 2200 ? 1 : -1
            momX += direction * 190 * CGFloat(dt)
            if abs(momX - 2200) < 12 {
                mom = .asleep
                momOut = false
                toyX = nil
                Sound.door.play(volume: 0.5)
                if room == .momRoom {
                    if engine.concealed {
                        engine.say("Mom's back in bed. Phew!")
                    } else {
                        chase.alarm(.mom, "Mom came back and saw you in her room! RUN!", from: CGPoint(x: 150, y: 600))
                    }
                }
                return
            }
        case .asleep: break
        }
        if momOut && room == .hallway && !engine.concealed && abs(engine.player.x - momX) < 360 {
            // She drops the toy and comes after you from where she's standing.
            mom = .asleep
            momOut = false
            toyX = nil
            chase.alarm(.mom, "Mom spotted you! RUN!", from: CGPoint(x: momX, y: 605))
        }
    }

    private func tickYard(_ dt: Double) {
        // Nobody to come out after you once the golden stick has been used.
        guard room == .yard, !doorLocked, !engine.grownUpsGone else {
            if engine.grownUpsGone, banner?.hasPrefix("Lock the door") == true { banner = nil }
            return
        }
        lockTime -= dt
        banner = "Lock the door before Dad gets out! \(Int(max(lockTime, 0).rounded(.up)))"
        if lockTime <= 0 {
            banner = nil
            dadX = 220
            dadCaught("Dad heard the door and came out after you!")
        }
    }

    /// Star balls appear on the roof now and then; each one makes you 6% faster for the rest of the level.
    private func tickRoof(_ dt: Double) {
        guard room == .roof else { return }
        // Walk out to either end of the roof and you can see the outside of the house from above.
        if !sawStreet && engine.player.x < Self.roofEdge - 120 {
            sawStreet = true
            engine.say("Whoa! I can see the whole street from up here.", seconds: 3)
        }
        if !sawGarden && engine.player.x > Self.roofWidth - Self.roofEdge + 120 {
            sawGarden = true
            engine.say("There's the garden maze! It looks tiny from the roof.", seconds: 3)
        }
        starTime -= dt
        let balls = engine.things.filter { $0.kind == "starBall" }
        // Boosting accessories are much easier to find up here: about one a minute.
        boostTime -= dt
        if boostTime <= 0 {
            boostTime = Double.random(in: 50...70)
            if newBoost() != nil && !engine.things.contains(where: { $0.kind == "boostBall" }) {
                engine.things.append(Thing(id: "boostBall", kind: "boostBall", pos: CGPoint(x: .random(in: 640...2760), y: .random(in: 570...680)),
                                           footprint: CGSize(width: 36, height: 30)))
                engine.say("Something glowing just landed on the roof!", seconds: 2.5)
            }
        }
        if let i = engine.things.firstIndex(where: { $0.kind == "boostBall" && abs($0.pos.x - engine.player.x) < 42 && abs($0.pos.y - engine.player.y) < 36 }) {
            engine.things.remove(at: i)
            if let boost = newBoost() { found(.boost(boost)) }
        }
        if let i = engine.things.firstIndex(where: { $0.kind == "goldenStick" && abs($0.pos.x - engine.player.x) < 42 && abs($0.pos.y - engine.player.y) < 36 }) {
            engine.things.remove(at: i)
            useGoldenStick()
        }
        if starTime <= 0 {
            // The golden stick: a 0.000000000001 chance each time a star would appear.
            if Double.random(in: 0..<1) < 0.000000000001 {
                engine.things.append(Thing(id: "goldenStick", kind: "goldenStick", pos: CGPoint(x: .random(in: 640...2760), y: .random(in: 570...680)),
                                           footprint: CGSize(width: 36, height: 30)))
            }
            starTime = Double.random(in: 4...7)
            if balls.count < 3 {
                starCount += 1
                engine.things.append(Thing(id: "star\(starCount)", kind: "starBall",
                                           pos: CGPoint(x: .random(in: 640...2760), y: .random(in: 570...680)),
                                           footprint: CGSize(width: 36, height: 30)))
            }
        }
        if let i = engine.things.firstIndex(where: { $0.kind == "starBall" && abs($0.pos.x - engine.player.x) < 42 && abs($0.pos.y - engine.player.y) < 36 }) {
            engine.things.remove(at: i)
            stars += 1
            if stars >= 10 { award(.power) }
            engine.speedBonus = min(0.6, CGFloat(stars) * 0.06)
            Sound.star.play()
            engine.say(engine.speedBonus >= 0.6 ? "Star ball! I'm at top speed!" : "Star ball! I feel faster! (\(stars))", seconds: 1.6)
        }
    }

    /// The golden stick deletes things: every obstacle in the house, and even Mom.
    private func useGoldenStick() {
        award(.goldenStick)
        Sound.magic.play()
        engine.grownUpsGone = true
        stickDeletes()
        show(Popup(title: "THE GOLDEN STICK", message: "It deleted every obstacle in the house... and Mom, and Dad. Nothing can stop you now.",
                   symbol: "wand.and.stars", color: Palette.gold, button: "Whoa") {})
    }

    /// What the golden stick deletes: every obstacle in every room of the house, and Mom.
    /// Also what pressing K does here, if you got the stick from The Room.
    private func stickDeletes() {
        momDeleted = true
        dadChecking = false
        if banner?.contains("Dad") == true || banner?.contains("Footsteps") == true || banner?.hasPrefix("Lock the door") == true { banner = nil }
        if chase.momOut { chase.reset() }
        momOut = false
        mom = .asleep
        for (key, things) in saved { saved[key] = things.filter { $0.hazard == nil } }
        engine.things.removeAll { $0.hazard != nil }
    }

    // MARK: Getting caught

    /// Bumping something makes a noise, and Mom gets up to see what it was.
    /// No Mercy: a splash in a puddle wakes Mom.
    private func splashed() {
        guard phase == .sneaking, !chase.active, !momDeleted else { return }
        chase.alarm(.mom, "SPLASH! You stepped in a puddle. Mom heard it!")
    }

    private func bumped(_ i: Int) {
        let hazard = engine.things[i].hazard
        if hazard == .toy { award(.deadlySqueak) }
        if hazard == .plank { award(.oldHouse) }
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard !chase.active, !momDeleted else { return }
        chase.alarm(.mom, "\(hazard?.noise ?? "CRASH!") Mom heard it. She's coming!")
    }

    /// Out of time or too loud: Mom gets out of bed and comes looking for you.
    private func momWakesUp(tooLoud: Bool) {
        guard phase == .sneaking else { return }
        guard !chase.active, !momDeleted else {
            engine.resetNoise()
            if engine.timeLeft <= 0 { engine.timeLeft = 30; engine.timerOn = true }
            return
        }
        if !tooLoud { award(.amNotPm) }
        if room == .roof { Voice.momCalls(playerName) }
        showKeypad = false
        engine.frozen = false
        // If she was out looking at the toy, she drops that and comes for you.
        let start: CGPoint? = momOut && room == .hallway ? CGPoint(x: momX, y: 605) : nil
        mom = .asleep
        momOut = false
        chase.alarm(.mom, tooLoud ? "Too loud! Mom woke up. She's coming to find you!" : "Time's up! Mom woke up. She's coming to find you!", from: start)
    }

    /// Where a grown-up walks in for the room you're in, and how long it takes them to get there.
    private func entrance(for who: Chase.Who) -> (CGPoint, Double) {
        switch room {
        case .hallway: (CGPoint(x: 2200, y: 575), 2.5)
        case .momRoom: who == .mom ? (CGPoint(x: 1180, y: 610), 1.5) : (CGPoint(x: 150, y: 600), 2.5)
        case .brotherRoom: (CGPoint(x: 150, y: 600), 5)
        case .stairs: (CGPoint(x: 110, y: 610), 4)
        case .downstairs: (CGPoint(x: 110, y: 600), 6)
        case .garage, .basement: (CGPoint(x: 110, y: 600), 7)
        case .yard: (CGPoint(x: 170, y: 600), 7)
        case .roof: (CGPoint(x: 830, y: 600), 6)
        }
    }

    /// A minute went by without catching you.
    private func gaveUp(_ who: Chase.Who) {
        award(.shh)
        engine.resetNoise()
        engine.timerOn = room != .roof && room != .yard
        if who == .mom {
            engine.timeLeft = 120
            engine.say("Mom gave up and went back to bed. 2 minutes until she wakes up again!", seconds: 4)
        } else {
            engine.say("Dad gave up looking. Phew!", seconds: 3)
            // He carries on with what he was doing.
            switch dad {
            case .comingDown, .walkingToGarage: dadInGarage()
            case .basement:
                dadX = 1400
                dadDirection = -1
            default: break
            }
        }
    }

    private func caught(_ who: Chase.Who, _ message: String) {
        award(.oopsies)
        if who == .dad { award(.hiDad) }
        engine.frozen = false
        showKeypad = false
        showPhone = false
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
        engine.crouching = false
        engine.running = phase == .sneaking || phase == .warning
    }


    var tip: String {
        if !checkpoints.contains("downstairs") { return "Go down the stairs. Jump over the loose planks — crouching won't help!" }
        if !hasDogKey {
            if dogWaiting { return hasFood ? "Bring the snack to the dog at the front door." : "The dog wants another snack. Get one from the fridge!" }
            return hasFood ? "Throw the food out of the downstairs window." : "Grab some food from the fridge in the kitchen."
        }
        if doorKeys < 3 {
            if smallKeys > 0 { return "Use the crafted key on a lockbox. There are 3 hidden around the house." }
            if scraps > 0 { return "Craft a key at the workbench in the garage." }
            return "Search for metal scraps: the couch, shelves, drawers, bins, the toolbox, the trunk..."
        }
        if !hasPhoneCode {
            if dad == .upstairs { return "Flip the garage light switch 3 times so Dad comes down. Then hide in a closet in the house!" }
            if dad == .comingDown || dad == .walkingToGarage { return "Hide in a closet until Dad is in the garage!" }
            if mom == .asleep { return hasToy ? "Throw the toy in the upstairs hallway, then hide until Mom walks past." : "Upstairs: grab a toy from my brother's room." }
            return "Mom is out of her room! Grab her phone from her nightstand."
        }
        if room != .yard && !exitOpen { return "The basement door code is \(Self.exitCode). Watch out for Dad down there — closets are safe." }
        return doorLocked ? "Walk to the garden gate!" : "Lock the door with the dog's key. Quick!"
    }

    func hint() { engine.say(tip, seconds: 4.5) }

    // MARK: The Guide (practice mode)

    /// The doors between rooms: from, to, and the door you use.
    private static let links: [(Room, Room, String)] = [
        (.hallway, .stairs, "toStairs"), (.stairs, .hallway, "toHallway"),
        (.stairs, .downstairs, "toDownstairs"), (.downstairs, .stairs, "toStairs"),
        (.downstairs, .garage, "toGarage"), (.garage, .downstairs, "toHouse"),
        (.downstairs, .basement, "toBasement"), (.basement, .downstairs, "toHouseUp"),
        (.hallway, .brotherRoom, "siblingDoor"), (.brotherRoom, .hallway, "hallDoor"),
        (.hallway, .momRoom, "momDoor"), (.momRoom, .hallway, "hallDoor"),
        (.basement, .yard, "exitDoor"), (.roof, .hallway, "roofWindow"),
    ]

    /// The room the next step happens in, and the thing to go to there (nil: just get to the room).
    private var guideTarget: (room: Room, id: String?) {
        if !checkpoints.contains("downstairs") { return (.downstairs, nil) }
        if !hasDogKey {
            if dogWaiting { return (.downstairs, hasFood ? "frontDoor" : "fridge") }
            return (.downstairs, hasFood ? "dWindow" : "fridge")
        }
        if doorKeys < 3 {
            if smallKeys > 0 { return firstClosed(Self.lockboxSpots) }
            if scraps > 0 { return (.garage, "workbench") }
            return firstClosed(Array(scrapSpots))
        }
        if !hasPhoneCode {
            if dad == .upstairs { return (.garage, "switch") }
            if dad == .comingDown || dad == .walkingToGarage { return (.downstairs, "closetA") }
            if mom == .asleep { return hasToy ? (.hallway, nil) : (.brotherRoom, "toyChest") }
            return (.momRoom, "momNightstand")
        }
        if room != .yard && !exitOpen { return (.basement, "exitDoor") }
        return (.yard, doorLocked ? "gate" : "yardDoor")
    }

    /// The first of these things that hasn't been opened yet, in whichever room it's in.
    private func firstClosed(_ ids: [String]) -> (room: Room, id: String?) {
        for place in [Room.downstairs, .garage, .basement] {
            let things = place == room ? engine.things : saved[place] ?? []
            if let thing = things.first(where: { ids.contains($0.id) && !$0.open && !$0.hidden }) { return (place, thing.id) }
        }
        return (.downstairs, nil)
    }

    private func guideGoal() -> CGPoint? {
        let target = guideTarget
        if target.room == room { return target.id.flatMap { engine.spot($0) } }
        // Find the way there, room by room, and lead to the first door.
        var seen: Set<Room> = [room]
        var queue: [(room: Room, door: String)] = []
        for link in Self.links where link.0 == room {
            seen.insert(link.1)
            queue.append((link.1, link.2))
        }
        var i = 0
        while i < queue.count {
            let step = queue[i]
            i += 1
            if step.room == target.room { return engine.spot(step.door) }
            for link in Self.links where link.0 == step.room && !seen.contains(link.1) {
                seen.insert(link.1)
                queue.append((link.1, step.door))
            }
        }
        return nil
    }
}

// MARK: - View

struct DownstairsLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = DownstairsModel()

    private var title: String {
        switch model.room {
        case .stairs: "Level 3 · Stairs"
        case .downstairs: "Level 3 · Downstairs"
        case .garage: "Level 3 · Garage"
        case .basement: "Level 3 · Basement"
        case .yard: "Level 3 · Back Yard"
        case .hallway: "Level 3 · Hallway"
        case .brotherRoom: "Level 3 · Brother's Room"
        case .momRoom: "Level 3 · Mom's Room"
        case .roof: "Sub level · The Roof"
        }
    }

    var body: some View {
        LevelScaffold(engine: model.engine, title: title, inventory: model.inventory,
                      onInventoryTap: { item in if item.id == "code" { model.readCode() } },
                      popup: model.popup, banner: model.banner,
                      belt: model.belt, chase: model.chase, guideTips: GuideTips.level3,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            if model.showKeypad {
                NumberPadOverlay(title: "Basement door code", digits: DownstairsModel.exitCode.count, onSubmit: model.submitCode, onCancel: model.closeKeypad)
            }
            if model.showPhone {
                PhoneOverlay(passcode: DownstairsModel.passcode, code: DownstairsModel.exitCode,
                             onNoteRead: model.phoneNoteRead, onFiveFails: { game.award(.passcode) },
                             onOpenApp: { if $0 == "Music" { game.award(.fireMusic) } }, onClose: model.closePhone)
            }
            if model.drawing { DrawingPad(onDone: model.finishDrawing) }
            if model.buddy.talking {
                TalkOverlay(buddy: model.buddy, tip: model.tip,
                            onGiveToy: giveToyAction, onClose: model.closeTalk)
            }
        }
        .onAppear {
            model.onComplete = { game.complete(level: 3) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.onRetry = { game.noteRetry() }
            model.giveToy = { game.give(toyTo: $0) }
            model.rewardToy = { game.hasToy = true }
            model.newBoost = { game.newBoost() }
            model.belt.configure(game: game, engine: model.engine)
            model.playerName = game.playerName
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    /// "Give him a toy" only shows in the talk menu while you're holding one.
    private var giveToyAction: (() -> Void)? {
        guard model.hasToy else { return nil }
        return { model.giveBrotherToy() }
    }

    private var world: some View {
        let width = DownstairsModel.widths[model.room] ?? 1000
        return ZStack(alignment: .topLeading) {
            background(width: width)
            ForEach(engine.things.filter { !$0.onFloor && !$0.hidden }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.room == .hallway, let toyX = model.toyX {
                ThrownToyView().anchored(at: CGPoint(x: toyX, y: 625))
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                floorItem(thing)
            }
            if !engine.hidden && (model.buddy.state == .following || (model.buddy.state == .awake && model.room == .brotherRoom)) {
                BuddyView(buddy: model.buddy)
            }
            grownUps
            Palette.shade.opacity((darkness) * Palette.shadeAmount)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }

    private var darkness: Double {
        switch model.room {
        case .garage: model.garageLight ? 0.08 : 0.5
        case .basement: 0.34
        case .yard, .roof: 0.1
        default: 0.22
        }
    }

    @ViewBuilder private func background(width: CGFloat) -> some View {
        switch model.room {
        case .stairs: StairsWall(width: width)
        case .downstairs: DownstairsWall(width: width)
        case .garage: GarageWall(width: width)
        case .basement: BasementWall(width: width)
        case .yard: YardScene(width: width)
        case .hallway: HallwayWall(width: width)
        case .brotherRoom: SiblingRoomWall(width: width)
        case .momRoom: MomRoomWall(width: width)
        case .roof: RoofScene(width: width)
        }
    }

    @ViewBuilder private var grownUps: some View {
        let pop = AnyTransition.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity)
        ChaserView(chase: model.chase)
        if model.room == .hallway && model.momOut && !model.engine.grownUpsGone {
            // Puzzled by the toy; half asleep walking there and back.
            MomView(walking: model.mom != .atToy, expression: model.mom == .atToy ? .surprised : .sleepy).anchored(at: CGPoint(x: model.momX, y: 605))
        }
        if model.room == .momRoom && model.dadChecking {
            DadView(stunned: model.dadStunned, expression: .sneaky).anchored(at: CGPoint(x: 150, y: 600)).transition(pop)
        }
        if !model.engine.grownUpsGone && ((model.room == .downstairs && model.dad == .walkingToGarage) || (model.room == .basement && model.dad == .basement)
            || (model.room == .yard && model.phase == .over && !model.doorLocked)) {
            // Sleepy on his way to the garage, watchful in the basement, cross when you lock him in... nearly.
            DadView(stunned: model.dadStunned, expression: model.room == .yard ? .cross : model.dad == .walkingToGarage ? .sleepy : .sneaky)
                .anchored(at: CGPoint(x: model.dadX, y: 605))
        }
        if model.room == .yard {
            DogView(happy: true).anchored(at: CGPoint(x: 560, y: 575))
        }
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "closet": ClosetView(hiding: model.hidingIn == thing.id)
        case "stairsUp": StairsDoorView(up: true)
        case "stairsDown": StairsDoorView(up: false)
        case "couch": CouchView()
        case "bookshelf": BookshelfView()
        case "kitchenCounter": KitchenCounterView(open: thing.open)
        case "fridge": FridgeView()
        case "dWindow": HallWindowView(open: model.dogWaiting, keyTaken: true)
        case "frontDoor": FrontDoorView(dogWaiting: model.dogWaiting, gaveKey: model.hasDogKey)
        case "lockbox": LockboxWallView(open: thing.open)
        case "garageDoor": DoorView(color: Color(white: 0.45)) { DoorSign(text: "GARAGE", color: .yellow) }
        case "basementDoor": DoorView(color: Color(red: 0.30, green: 0.36, blue: 0.30)) { DoorSign(text: "BASEMENT ↓", color: .white) }
        case "houseDoor": DoorView(color: Color(white: 0.45)) { DoorSign(text: "HOUSE", color: .yellow) }
        case "lightSwitch": LightSwitchView(on: model.garageLight)
        case "bin": BinView()
        case "car": CarView()
        case "workbench": WorkbenchView()
        case "toolbox": ToolboxView(open: thing.open)
        case "ladder": LadderView()
        case "trunk": TrunkView(open: thing.open)
        case "washer": WasherView()
        case "exitDoor": ExitDoorView(open: model.exitOpen, codeAccepted: model.codeAccepted)
        case "yardDoor": DoorView(color: Color(red: 0.25, green: 0.40, blue: 0.30)) {
            DoorSign(text: model.doorLocked ? "LOCKED" : "UNLOCKED!", color: model.doorLocked ? .green : .red)
        }
        case "gardenGate": GardenGateView()
        case "roofWindow": RoofWindowView()
        case "owl": OwlView()
        case "toyChest": ToyChestView()
        case "paper": PaperStackView()
        case "dadDesk": DadDeskView()
        case "dresser": DresserView(open: thing.open)
        case "nightstand": NightstandView(open: thing.open)
        case "window": HallWindowView(open: model.hasLadder, keyTaken: true)
        case "bedroomDoor": DoorView(color: Color(red: 0.45, green: 0.32, blue: 0.55)) { DoorSign(text: "My Room", color: .yellow) }
        case "siblingDoor": DoorView(color: Color(red: 0.35, green: 0.55, blue: 0.75)) { DoorSign(text: "KEEP OUT ★", color: .orange) }
        case "hallDoor": DoorView(color: model.room == .momRoom ? Color(red: 0.55, green: 0.30, blue: 0.30)
                                                                : Color(red: 0.35, green: 0.55, blue: 0.75),
                                  open: model.dadChecking) { EmptyView() }
        case "momDoor": DoorView(color: Color(red: 0.55, green: 0.30, blue: 0.30), open: model.mom != .asleep) {
            DoorSign(text: "MOM ♥", color: .pink)
        }
        case "sibBed": SiblingBedView(empty: model.buddy.state != .asleep)
        case "vanity": VanityView(open: true)
        case "momBed": MomBedView(empty: model.mom != .asleep || model.chase.momOut)
        case "momNightstand": PhoneNightstandView()
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "puddle": PuddleView(size: thing.footprint).offset(y: thing.footprint.height / 2)
        case "plank": PlankView(size: thing.footprint).offset(y: thing.footprint.height / 2)
        case "starBall": StarBallView()
        case "boostBall": BoostBallView()
        case "goldenStick": Image(systemName: "wand.and.stars").font(.system(size: 40)).foregroundStyle(Palette.gold).shadow(color: .yellow, radius: 12)
        case "cans", "bucket": PaintCansView()
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
