import SwiftUI
import Observation

/// Level 1 rules: find the small key under the table, open the lockbox under the bed,
/// then use the big key from the lockbox on the door — before the clock runs out.
@MainActor
@Observable
final class BedroomModel {
    let engine = GameEngine()
    var inventory: [InventoryItem] = []
    var foundSmallKey = false
    var lockboxOpen = false
    var doorOpen = false
    var lampOn = false
    var showGlint = false
    var popup: Popup?
    var playerOpacity = 1.0
    var banner: String?
    let chase = Chase()

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    let belt = ItemBelt()

    static let smallKey = InventoryItem(id: "smallKey", symbol: "key.fill", color: Palette.silver)
    static let doorKey = InventoryItem(id: "doorKey", symbol: "key.fill", color: Palette.gold)

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onTimeUp = { [weak self] in self?.momWakes(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momWakes(tooLoud: true) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.chase.taunted() }
        engine.onTick = { [weak self] dt in
            self?.belt.tick(dt)
            self?.chase.tick(dt)
        }
        belt.stun = { [weak self] seconds, momOnly in self?.chase.stun(seconds, momOnly: momOnly) ?? false }
        // Mom comes in through the bedroom door.
        chase.engine = engine
        chase.entrance = { _ in (CGPoint(x: 905, y: 575), 2.5) }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.onCaught = { [weak self] _, _ in self?.sentToBed() }
        chase.onGaveUp = { [weak self] _ in self?.momGaveUp() }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        // Practice mode: the Guide leads you to the table, then the lockbox, then the door.
        engine.guideGoal = { [weak self] in
            guard let self else { return nil }
            return engine.spot(has(Self.doorKey) ? "door" : has(Self.smallKey) ? "bed" : "table")
        }
        reset()
    }

    /// Try Again or the restart button (counts toward the Retry badge).
    func retry() {
        onRetry()
        reset()
    }

    func reset() {
        belt.reset()
        engine.load(SceneLayout(width: 1000, floor: 560...680, things: Self.things(), spawn: CGPoint(x: 470, y: 620)))
        engine.timeLeft = Levels.all[0].seconds
        engine.timerOn = true
        engine.resetNoise()
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        inventory = []
        foundSmallKey = false
        lockboxOpen = false
        doorOpen = false
        lampOn = false
        showGlint = false
        popup = nil
        playerOpacity = 1
        banner = nil
        chase.reset()
        engine.running = true
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    private static func things() -> [Thing] {
        [
            Thing(id: "bed", kind: "spot", pos: CGPoint(x: 250, y: 560), heavy: true,
                  prompt: "Check the lockbox", reach: CGSize(width: 150, height: 160)),
            Thing(id: "table", kind: "spot", pos: CGPoint(x: 630, y: 560), heavy: true,
                  prompt: "Look under the table", reach: CGSize(width: 100, height: 160)),
            Thing(id: "lamp", kind: "spot", pos: CGPoint(x: 735, y: 560),
                  prompt: "Switch the lamp", reach: CGSize(width: 30, height: 160)),
            Thing(id: "toybox", kind: "toybox", pos: CGPoint(x: 800, y: 590), footprint: CGSize(width: 96, height: 30),
                  solid: true, movable: true, prompt: "Look in the toy box", reach: CGSize(width: 100, height: 70)),
            Thing(id: "door", kind: "spot", pos: CGPoint(x: 905, y: 560),
                  prompt: "Open the door", reach: CGSize(width: 80, height: 160)),
        ]
    }

    private func interact(_ i: Int) {
        switch engine.things[i].id {
        case "table": searchTable()
        case "bed": useLockbox()
        case "lamp":
            lampOn.toggle()
            Sound.click.play()
        case "toybox": engine.say("Just toys in here. No key.")
        case "door": useDoor()
        default: break
        }
    }

    private func has(_ item: InventoryItem) -> Bool { inventory.contains(item) }

    private func searchTable() {
        guard !foundSmallKey else {
            engine.say("Nothing else under the table.")
            return
        }
        engine.running = false
        engine.crouching = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            foundSmallKey = true
            Sound.key.play()
            show(Popup(title: "You found a key!", message: "A small silver key was hiding under the table.",
                       symbol: "key.fill", color: Palette.silver, button: "Take Key") { [weak self] in
                self?.inventory.append(Self.smallKey)
                self?.award(.patienceIsKey)
            })
        }
    }

    private func useLockbox() {
        if lockboxOpen {
            engine.say("The lockbox is empty now.")
        } else if has(Self.smallKey) {
            engine.running = false
            engine.crouching = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                inventory.removeAll { $0 == Self.smallKey }
                lockboxOpen = true
                Sound.unlock.play()
                try? await Task.sleep(for: .seconds(0.8))
                Sound.key.play()
                show(Popup(title: "You found a key!", message: "The lockbox had a big golden key inside!",
                           symbol: "key.fill", color: Palette.gold, button: "Take Key") { [weak self] in
                    self?.inventory.append(Self.doorKey)
                })
            }
        } else {
            engine.say("A lockbox under the bed! It's locked. I need a key.")
        }
    }

    private func useDoor() {
        guard !doorOpen else { return }
        if has(Self.doorKey) {
            engine.running = false
            inventory.removeAll { $0 == Self.doorKey }
            Sound.unlock.play()
            doorOpen = true
            onComplete()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                Sound.door.play()
                try? await Task.sleep(for: .seconds(0.6))
                engine.walking = true
                withAnimation(.linear(duration: 0.6)) {
                    engine.player = CGPoint(x: 905, y: 565)
                    playerOpacity = 0
                }
                try? await Task.sleep(for: .seconds(0.7))
                engine.walking = false
                Sound.win.play()
                show(Popup(title: "Level Complete!", message: "Shhh... you sneaked out of the bedroom!",
                           symbol: "star.fill", color: Palette.gold, button: "Next Level", action: { [weak self] in self?.onNext() },
                           secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
            }
        } else if has(Self.smallKey) {
            engine.say("This little key is too small for the door.")
        } else {
            engine.say("The door is locked. I need a key.")
        }
    }

    /// Out of time, or too noisy: Mom gets up, walks in through the door and comes after you.
    private func momWakes(tooLoud: Bool) {
        guard !doorOpen else { return }
        guard !chase.active else {
            engine.resetNoise()
            return
        }
        if !tooLoud { award(.amNotPm) }
        chase.alarm(.mom, tooLoud ? "Too loud! Mom is coming to check your room!" : "Time's up! Mom is coming to check your room!")
    }

    /// She reached you.
    private func sentToBed() {
        award(.oopsies)
        engine.timerOn = false
        Sound.caught.play()
        show(Popup(title: "Go to sleep!", message: "Mom caught you: \"Why are you still awake? Bed. Now!\"",
                   symbol: "moon.zzz.fill", color: Palette.moon, button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    /// A whole minute without catching you: she goes back to bed, and you get 2 more minutes.
    private func momGaveUp() {
        award(.shh)
        engine.timeLeft = 120
        engine.timerOn = true
        engine.resetNoise()
        engine.say("Mom gave up and went back to bed. 2 minutes until she wakes up again!", seconds: 4)
    }

    /// Shows a pop-up; the game is paused until its button is pressed.
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
        engine.crouching = false
        engine.running = true
    }

    func hint() {
        if has(Self.doorKey) {
            engine.say("I can use the big key on the door!")
        } else if has(Self.smallKey) {
            engine.say("This little key might open something under the bed...")
        } else {
            showGlint = true
            engine.say("Things like to hide under furniture. Maybe the table?")
        }
    }
}

struct BedroomLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = BedroomModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Level 1 · Bedroom", inventory: model.inventory,
                      popup: model.popup, banner: model.banner, belt: model.belt, chase: model.chase, guideTips: GuideTips.level1,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            room
        } extra: {
            EmptyView()
        }
        .onAppear {
            model.onComplete = { game.complete(level: 1) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            model.onRetry = { game.noteRetry() }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    // MARK: - Room drawing (1000×700 stage)

    private var room: some View {
        ZStack(alignment: .topLeading) {
            wall
            floor
            window.position(x: 600, y: 200)
            moonbeam
            door
            rug.position(x: 470, y: 630)
            bed
            table
            FloorLayer(engine: model.engine, look: game.look, name: game.playerName,
                       playerOpacity: model.playerOpacity) { thing in
                if thing.kind == "toybox" { toyBox }
            }
            if model.lampOn {
                RadialGradient(colors: [Color.yellow.opacity(0.35), .clear], center: .init(x: 0.73, y: 0.55),
                               startRadius: 10, endRadius: 420)
                    .blendMode(.screen)
            }
            Palette.shade.opacity((model.lampOn ? 0.05 : 0.25) * Palette.shadeAmount)
            ChaserView(chase: model.chase)
        }
        .frame(width: 1000, height: 700)
        .allowsHitTesting(false)
    }

    private var wall: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.17, blue: 0.38), Color(red: 0.24, green: 0.22, blue: 0.48)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 1000, height: 450)
            ForEach(0..<40) { i in
                Image(systemName: i % 3 == 0 ? "moon.fill" : "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.08))
                    .position(x: CGFloat(i % 10) * 100 + (i / 10 % 2 == 0 ? 30 : 80), y: CGFloat(i / 10) * 100 + 50)
            }
            Rectangle()
                .fill(Color(red: 0.36, green: 0.24, blue: 0.20))
                .frame(width: 1000, height: 16)
                .offset(y: 440)
        }
    }

    private var floor: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.40, green: 0.26, blue: 0.18), Color(red: 0.52, green: 0.34, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 1000, height: 244)
            ForEach(1..<6) { i in
                Rectangle()
                    .fill(.black.opacity(0.15))
                    .frame(width: 1000, height: 2)
                    .offset(y: CGFloat(i) * CGFloat(i + 2) * 6)
            }
        }
        .offset(y: 456)
    }

    private var window: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.30, blue: 0.22)).frame(width: 220, height: 200)
            LinearGradient(colors: [Palette.skyTop, Color(red: 0.15, green: 0.18, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                .frame(width: 190, height: 170)
            Circle().fill(Palette.moon).frame(width: 56).shadow(color: Palette.moon, radius: 18).offset(x: 40, y: -35)
            ForEach(0..<6) { i in
                Circle().fill(.white).frame(width: 3).offset(x: CGFloat(i * 29 - 80), y: CGFloat((i * 37) % 120 - 50))
            }
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.22)).frame(width: 8, height: 170)
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.22)).frame(width: 190, height: 8)
            HStack {
                Capsule().fill(Color(red: 0.55, green: 0.20, blue: 0.35)).frame(width: 34, height: 230)
                Spacer()
                Capsule().fill(Color(red: 0.55, green: 0.20, blue: 0.35)).frame(width: 34, height: 230)
            }
            .frame(width: 270)
        }
    }

    private var moonbeam: some View {
        Path { p in
            p.move(to: CGPoint(x: 515, y: 290))
            p.addLine(to: CGPoint(x: 685, y: 290))
            p.addLine(to: CGPoint(x: 760, y: 700))
            p.addLine(to: CGPoint(x: 360, y: 700))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Palette.moon.opacity(0.18), Palette.moon.opacity(0.02)], startPoint: .top, endPoint: .bottom))
        .blendMode(.screen)
    }

    private var rug: some View {
        Ellipse()
            .fill(Color(red: 0.30, green: 0.45, blue: 0.62))
            .overlay(Ellipse().stroke(Color(red: 0.95, green: 0.80, blue: 0.45), lineWidth: 6).padding(10))
            .frame(width: 340, height: 80)
    }

    private var door: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.5), Color(red: 0.6, green: 0.4, blue: 0.2)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 104, height: 300)
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.33, blue: 0.20))
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.25), lineWidth: 4).frame(width: 66, height: 110)
                    RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.25), lineWidth: 4).frame(width: 66, height: 120)
                }
                Circle().fill(Palette.gold).frame(width: 16).offset(x: 34, y: 10)
                Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(.black.opacity(0.6)).offset(x: 34, y: 34)
            }
            .frame(width: 104, height: 300)
            .scaleEffect(x: model.doorOpen || model.chase.active ? 0.15 : 1, anchor: .leading)
            .animation(.easeInOut(duration: 0.8), value: model.doorOpen || model.chase.active)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.32, green: 0.20, blue: 0.14), lineWidth: 10))
        .position(x: 905, y: 405)
    }

    private var bed: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.black.opacity(0.55)).frame(width: 300, height: 52).offset(x: 85, y: 508)
            lockbox.offset(x: 210, y: 506)
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.45, green: 0.28, blue: 0.18)).frame(width: 32, height: 210).offset(x: 55, y: 350)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.28, blue: 0.18)).frame(width: 24, height: 140).offset(x: 382, y: 420)
            Rectangle().fill(Color(red: 0.50, green: 0.32, blue: 0.20)).frame(width: 300, height: 26).offset(x: 85, y: 484)
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.9)).frame(width: 300, height: 34).offset(x: 85, y: 452)
            Capsule().fill(Color(red: 0.92, green: 0.92, blue: 1)).frame(width: 80, height: 34).offset(x: 92, y: 424)
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.62, blue: 0.48), Color(red: 0.24, green: 0.48, blue: 0.38)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 225, height: 58)
                .offset(x: 170, y: 440)
            teddy.offset(x: 300, y: 382)
        }
        .frame(width: 1000, height: 700, alignment: .topLeading)
    }

    private var teddy: some View {
        ZStack {
            Circle().fill(Color(red: 0.70, green: 0.48, blue: 0.30)).frame(width: 46).offset(y: 22)
            Circle().fill(Color(red: 0.70, green: 0.48, blue: 0.30)).frame(width: 36)
            Circle().fill(Color(red: 0.70, green: 0.48, blue: 0.30)).frame(width: 14).offset(x: -14, y: -16)
            Circle().fill(Color(red: 0.70, green: 0.48, blue: 0.30)).frame(width: 14).offset(x: 14, y: -16)
            Circle().fill(.black).frame(width: 4).offset(x: -6, y: -2)
            Circle().fill(.black).frame(width: 4).offset(x: 6, y: -2)
            Text("z").font(.game(16)).foregroundStyle(.white.opacity(0.6)).offset(x: 24, y: -24)
        }
        .frame(width: 60, height: 70)
    }

    private var lockbox: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.55, green: 0.55, blue: 0.62))
                .frame(width: 76, height: 40)
                .offset(y: 14)
            if !model.lockboxOpen {
                Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(Palette.gold).offset(y: 26)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.42, green: 0.42, blue: 0.50))
                .frame(width: 80, height: 14)
                .rotationEffect(.degrees(model.lockboxOpen ? -70 : 0), anchor: .leading)
                .animation(.spring(duration: 0.5, bounce: 0.4), value: model.lockboxOpen)
        }
        .frame(width: 80, height: 54)
    }

    private var table: some View {
        ZStack(alignment: .topLeading) {
            Ellipse().fill(.black.opacity(0.35)).frame(width: 220, height: 26).offset(x: 530, y: 548)
            if model.showGlint && !model.foundSmallKey {
                Image(systemName: "sparkle")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
                    .offset(x: 625, y: 525)
            }
            Rectangle().fill(Color(red: 0.42, green: 0.27, blue: 0.17)).frame(width: 14, height: 118).offset(x: 552, y: 444)
            Rectangle().fill(Color(red: 0.42, green: 0.27, blue: 0.17)).frame(width: 14, height: 118).offset(x: 716, y: 444)
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.36, blue: 0.22)).frame(width: 210, height: 20).offset(x: 535, y: 428)
            RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.8)).frame(width: 60, height: 12).offset(x: 560, y: 416)
            RoundedRectangle(cornerRadius: 2).fill(Color.teal.opacity(0.9)).frame(width: 52, height: 12).offset(x: 565, y: 404)
            lamp.offset(x: 670, y: 340)
        }
        .frame(width: 1000, height: 700, alignment: .topLeading)
    }

    private var lamp: some View {
        VStack(spacing: 0) {
            Trapezoid()
                .fill(model.lampOn ? Color(red: 1, green: 0.85, blue: 0.45) : Color(red: 0.75, green: 0.65, blue: 0.5))
                .frame(width: 56, height: 38)
                .shadow(color: model.lampOn ? .yellow : .clear, radius: 20)
            Rectangle().fill(Color(red: 0.3, green: 0.3, blue: 0.35)).frame(width: 6, height: 36)
            Capsule().fill(Color(red: 0.3, green: 0.3, blue: 0.35)).frame(width: 34, height: 10)
        }
        .frame(width: 70, height: 90)
    }

    private var toyBox: some View {
        ZStack {
            Circle().fill(Color.red).frame(width: 30).offset(x: -16, y: -36)
            RoundedRectangle(cornerRadius: 3).fill(Color.yellow).frame(width: 24, height: 24).rotationEffect(.degrees(15)).offset(x: 14, y: -38)
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.25, green: 0.55, blue: 0.85)).frame(width: 96, height: 66)
            Text("TOYS").font(.game(16, .heavy)).foregroundStyle(.white)
        }
        .frame(width: 100, height: 110)
    }
}

struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
