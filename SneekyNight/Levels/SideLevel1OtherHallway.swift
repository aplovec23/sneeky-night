import SwiftUI
import Observation

/// Side Level 1 rules: the other hallway runs behind your room. Five keys are hidden in the boxes
/// (each box can be searched once, and boosts turn up a bit more often here). With all
/// five keys the door at the far end opens onto a secret room with a treasure chest: a boost you
/// don't have yet, or extra colours for Customize Character.
/// Out of time, too noisy or a bump: Mom comes through your room to find you.
@MainActor
@Observable
final class OtherHallwayModel {
    enum Room { case hallway, secretRoom }
    enum Phase { case sneaking, over }

    let engine = GameEngine()
    var room: Room = .hallway
    var phase: Phase = .sneaking
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var doorOpen = false
    var chestOpen = false
    var hidingIn: String?
    let chase = Chase()
    let belt = ItemBelt()

    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    /// Hands out the secret room's prize and marks the side level as won.
    @ObservationIgnored var claimReward: () -> SideReward = { .nothing }
    @ObservationIgnored private var keyBoxes: Set<String> = []

    static let floor: ClosedRange<CGFloat> = 545...690
    static let hallWidth: CGFloat = 3200
    static let roomWidth: CGFloat = 1000
    static let keyCount = 5
    static let seconds = 220.0

    var keys: Int { inventory.count }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onTimeUp = { [weak self] in self?.momWakesUp(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momWakesUp(tooLoud: true) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.chase.taunted() }
        engine.onTick = { [weak self] dt in
            self?.chase.tick(dt)
            self?.belt.tick(dt)
        }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.chase.stun(seconds, momOnly: momOnly) ?? false }
        chase.engine = engine
        chase.entrance = { _ in (CGPoint(x: 150, y: 600), 4) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.onCaught = { [weak self] who, message in self?.caught(message) }
        chase.onGaveUp = { [weak self] _ in self?.gaveUp() }
        // Practice mode: the Guide leads you to the next place to go.
        engine.guideGoal = { [weak self] in self?.guideGoal() }
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
        let things = Self.hallThings()
        keyBoxes = Set(things.filter { $0.kind == "box" }.map(\.id).shuffled().prefix(Self.keyCount))
        room = .hallway
        engine.load(SceneLayout(width: Self.hallWidth, floor: Self.floor, things: things, spawn: CGPoint(x: 220, y: 610)))
        engine.timeLeft = (Self.seconds * Difficulty.current.timeScale).rounded()
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
        inventory = []
        popup = nil
        banner = nil
        doorOpen = false
        chestOpen = false
        hidingIn = nil
        engine.running = true
        engine.say("The other hallway! 5 keys are hidden in the boxes.", seconds: 3.5)
    }

    static func hallThings() -> [Thing] {
        typealias H = HallwayModel
        return [
            H.onWall("bedroomDoor", "bedroomDoor", x: 110, prompt: "Go back to bed"),
            H.box("box1", x: 380, y: 590),
            H.onWall("closet1", "closet", x: 560, prompt: "Hide in the closet"),
            H.obstacle("lamp1", .lamp, x: 720, y: 660, size: CGSize(width: 40, height: 26)),
            H.box("box2", x: 860, y: 640),
            H.obstacle("table1", .table, x: 1040, y: 585, size: CGSize(width: 110, height: 36)),
            H.box("box3", x: 1200, y: 670),
            H.obstacle("chair1", .chair, x: 1340, y: 610, size: CGSize(width: 64, height: 30)),
            H.onWall("closet2", "closet", x: 1500, prompt: "Hide in the closet"),
            H.box("box4", x: 1660, y: 580),
            H.obstacle("lamp2", .lamp, x: 1800, y: 600, size: CGSize(width: 40, height: 26)),
            H.obstacle("chair2", .chair, x: 1880, y: 672, size: CGSize(width: 64, height: 30)),
            H.box("box5", x: 2040, y: 630),
            H.obstacle("table2", .table, x: 2220, y: 660, size: CGSize(width: 110, height: 36)),
            H.box("box6", x: 2360, y: 575),
            H.onWall("closet3", "closet", x: 2520, prompt: "Hide in the closet"),
            H.obstacle("chair3", .chair, x: 2660, y: 590, size: CGSize(width: 64, height: 30)),
            H.box("box7", x: 2760, y: 665),
            H.box("box8", x: 2920, y: 600),
            H.onWall("secretDoor", "secretDoor", x: 3070, prompt: "Unlock the door", reach: 90),
        ]
    }

    static func secretThings() -> [Thing] {
        [Thing(id: "chest", kind: "chest", pos: CGPoint(x: 640, y: 610), footprint: CGSize(width: 110, height: 36), solid: true,
               prompt: "Open the treasure chest", reach: CGSize(width: 150, height: 90))]
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "closet": toggleHiding(in: thing)
        case "box": searchBox(i)
        case "bedroomDoor": engine.say("Not yet! I want to see what's behind that other door.")
        case "secretDoor": useDoor()
        case "chest": openChest()
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

    private func searchBox(_ i: Int) {
        engine.things[i].open = true
        Sound.box.play()
        if keyBoxes.remove(engine.things[i].id) != nil {
            Sound.key.play()
            let number = keys + 1
            show(Popup(title: "Key \(number) of \(Self.keyCount)!", message: number == Self.keyCount
                       ? "That's all of them! Go to the door at the end of the hallway."
                       : "It was at the bottom of the box. Keep searching!",
                       symbol: "key.fill", color: Palette.gold, button: "Take Key") { [weak self] in
                guard let self else { return }
                inventory.append(InventoryItem(id: "key\(number)", symbol: "key.fill", color: Palette.gold))
                if number == 1 { award(.patienceIsKey) }
            })
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else {
            engine.say(["Just old clothes.", "Only dusty books.", "Nothing but bubble wrap.", "A sock with a hole in it."].randomElement()!)
        }
    }

    private func useDoor() {
        guard keys >= Self.keyCount else {
            Sound.buzz.play()
            engine.say("5 locks! I have \(keys) of \(Self.keyCount) keys. They're in the boxes.")
            return
        }
        // The door locks behind you: nobody can follow you into the secret room.
        Sound.unlock.play()
        Sound.door.play()
        chase.reset()
        banner = nil
        inventory = []
        doorOpen = true
        hidingIn = nil
        room = .secretRoom
        engine.timerOn = false
        engine.resetNoise()
        engine.load(SceneLayout(width: Self.roomWidth, floor: Self.floor, things: Self.secretThings(), spawn: CGPoint(x: 190, y: 610)))
        engine.facingRight = true
        engine.say("Whoa... a secret room!", seconds: 3)
    }

    private func openChest() {
        guard !chestOpen else { return }
        chestOpen = true
        phase = .over
        Sound.unlock.play()
        Sound.win.play()
        let message: String
        let symbol: String
        let color: Color
        switch claimReward() {
        case .boost(let boost):
            message = "Inside the chest: \(boost.name)!\n\(boost.about)"
            symbol = boost.symbol
            color = boost.color
        case .colors:
            message = "Inside the chest: paint pots! New T-shirt and cap colours are waiting in Customize Character."
            symbol = "paintpalette.fill"
            color = .cyan
        case .nothing:
            message = "You already have everything from this chest. But you did it again!"
            symbol = "star.fill"
            color = Palette.gold
        }
        show(Popup(title: "Side Level Complete!", message: message, symbol: symbol, color: color,
                   button: "Menu", action: { [weak self] in self?.onExit() },
                   secondButton: "Play Again", secondAction: { [weak self] in self?.reset() }))
    }

    // MARK: Getting caught

    private func bumped(_ i: Int) {
        let hazard = engine.things[i].hazard
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard !chase.active else { return }
        chase.alarm(.mom, "\(hazard?.noise ?? "CRASH!") Mom heard it. She's coming!")
    }

    private func momWakesUp(tooLoud: Bool) {
        guard phase == .sneaking, room == .hallway else { return }
        guard !chase.active else {
            engine.resetNoise()
            return
        }
        chase.alarm(.mom, tooLoud ? "Too loud! Mom woke up. She's coming to find you!" : "Time's up! Mom woke up. She's coming to find you!")
    }

    private func gaveUp() {
        award(.shh)
        engine.resetNoise()
        engine.timerOn = true
        engine.timeLeft = 120
        engine.say("Mom gave up and went back to bed. 2 minutes until she wakes up again!", seconds: 4)
    }

    private func caught(_ message: String) {
        award(.oopsies)
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
        engine.running = phase == .sneaking
    }

    /// Practice mode: the Guide leads you to the boxes with keys, then the door, then the chest.
    private func guideGoal() -> CGPoint? {
        if room == .secretRoom { return engine.spot("chest") }
        if keys < Self.keyCount, let box = engine.things.first(where: { keyBoxes.contains($0.id) }) { return box.pos }
        return engine.spot("secretDoor")
    }

    func hint() {
        if room == .secretRoom {
            engine.say("Open the treasure chest!")
        } else if keys < Self.keyCount {
            engine.say("I have \(keys) of \(Self.keyCount) keys. Search every box. Each one only once, so check them all!")
        } else {
            engine.say("I have all 5 keys! The door is at the far end of the hallway.")
        }
    }
}

// MARK: - View

struct OtherHallwayLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    @State private var model = OtherHallwayModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: model.room == .hallway ? "Side Level 1 · The Other Hallway" : "Side Level 1 · Secret Room",
                      inventory: model.inventory, onInventoryTap: { _ in },
                      popup: model.popup, banner: model.banner,
                      belt: model.belt, chase: model.chase, guideTips: GuideTips.otherHallway,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            Group {
                if model.room == .hallway { hallway } else { secretRoom }
            }
            .allowsHitTesting(false)
        } extra: {
            EmptyView()
        }
        .onAppear {
            model.onExit = onExit
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            // Boosts are a little easier to find here.
            model.rollLoot = { game.rollLoot(boostOdds: 8) }
            model.take = { game.take($0) }
            model.onRetry = { game.noteRetry() }
            model.claimReward = { game.claimSideReward() }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var hallway: some View {
        ZStack(alignment: .topLeading) {
            HallwayWall(width: OtherHallwayModel.hallWidth)
            // A cooler, dustier look than the main hallway.
            Color(red: 0.10, green: 0.35, blue: 0.40).opacity(0.22)
            wallItems
            floorLayer
            ChaserView(chase: model.chase)
            Palette.shade.opacity((0.26) * Palette.shadeAmount)
        }
        .frame(width: OtherHallwayModel.hallWidth, height: 700, alignment: .topLeading)
    }

    private var secretRoom: some View {
        ZStack(alignment: .topLeading) {
            HallwayWall(width: OtherHallwayModel.roomWidth)
            Color(red: 0.55, green: 0.40, blue: 0.10).opacity(0.25)
            // The chest glows.
            Circle()
                .fill(RadialGradient(colors: [Palette.gold.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 260))
                .frame(width: 520, height: 520)
                .position(x: 640, y: 540)
            floorLayer
            Palette.shade.opacity((0.18) * Palette.shadeAmount)
        }
        .frame(width: OtherHallwayModel.roomWidth, height: 700, alignment: .topLeading)
    }

    private var wallItems: some View {
        ForEach(engine.things.filter { !$0.onFloor }) { thing in
            wallItem(thing).anchored(at: thing.pos)
        }
    }

    private var floorLayer: some View {
        FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: 1) { thing in
            floorItem(thing)
        }
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "closet": ClosetView(hiding: model.hidingIn == thing.id)
        case "bedroomDoor": DoorView(color: Color(red: 0.45, green: 0.32, blue: 0.55), open: model.chase.momOut) {
            DoorSign(text: "My Room", color: .yellow)
        }
        case "secretDoor": DoorView(color: Color(red: 0.20, green: 0.45, blue: 0.45), open: model.doorOpen) {
            DoorSign(text: "\(model.keys)/\(OtherHallwayModel.keyCount) KEYS", color: Palette.gold)
        }
        default: EmptyView()
        }
    }

    @ViewBuilder private func floorItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "box": CardboardBox(open: thing.open)
        case "chair": ChairView()
        case "lamp": FloorLampView()
        case "table": SideTableView()
        case "chest": TreasureChestView(open: model.chestOpen)
        default: EmptyView()
        }
    }
}

/// The secret room's prize chest, drawn from shapes.
struct TreasureChestView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.50, green: 0.30, blue: 0.14))
                .frame(width: 130, height: 62)
            Rectangle().fill(Palette.gold).frame(width: 130, height: 8).offset(y: -22)
            HStack(spacing: 86) {
                Rectangle().fill(Palette.gold).frame(width: 10, height: 62)
                Rectangle().fill(Palette.gold).frame(width: 10, height: 62)
            }
            if open {
                Ellipse().fill(Palette.gold).frame(width: 110, height: 26).offset(y: -52)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -74)
            }
            // Lid: closed on top, or tipped back when open.
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .fill(Color(red: 0.60, green: 0.37, blue: 0.18))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30).stroke(Palette.gold, lineWidth: 5))
                .frame(width: 134, height: 44)
                .rotationEffect(.degrees(open ? -70 : 0), anchor: .bottomLeading)
                .offset(y: -60)
            if !open {
                RoundedRectangle(cornerRadius: 4).fill(Palette.gold).frame(width: 22, height: 26).offset(y: -44)
            }
        }
        .frame(width: 140, height: 130, alignment: .bottom)
    }
}
