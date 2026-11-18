import SwiftUI
import Observation

/// Side Level 2, the Shop (it replaced the dungeon). Ion runs it from behind the counter: three
/// boosting items (Nokia, Phone, Sneaky Cape) for 1000 moonlights each, two skills (Double Jump,
/// Slide) for 1569, stat upgrades, accessories, and, once Uncle has taught you in Level 9, item
/// upgrades. Look at the three display cases and talk to Ion to finish the side level.
/// It also opens straight from the main menu (the Shop button).
@MainActor
@Observable
final class ShopModel {
    let engine = GameEngine()
    let belt = ItemBelt()
    var popup: Popup?
    var banner: String?
    var shopOpen = false
    /// The display cases looked at so far (and whether Ion has been talked to).
    var seen: Set<String> = []
    /// What Ion is saying in the room.
    var ionSays: String?

    @ObservationIgnored weak var game: GameState?
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored private var sayTime = 0.0
    @ObservationIgnored private var chatter = 9.0

    static let floor: ClosedRange<CGFloat> = 545...690
    static let width: CGFloat = 2200
    static let ionX: CGFloat = 1180
    static let cases: [(id: String, boost: Boost, x: CGFloat)] = [("nokiaCase", .nokia, 520), ("phoneCase", .phone, 760), ("capeCase", .sneakyCape, 1620)]
    static let tour: Set<String> = ["nokiaCase", "phoneCase", "capeCase", "ion"]

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        // Practice mode: the Guide walks you round the cases, then to Ion.
        engine.guideGoal = { [weak self] in
            guard let self else { return nil }
            if let next = Self.cases.first(where: { !self.seen.contains($0.id) }) { return engine.spot(next.id) }
            return seen.contains("ion") ? nil : engine.spot("counter")
        }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func reset() {
        var things: [Thing] = [
            HallwayModel.onWall("exit", "exit", x: 110, prompt: "Leave the shop"),
            HallwayModel.onWall("counter", "counter", x: Self.ionX, prompt: "Talk to Ion", reach: 170),
            HallwayModel.onWall("skills", "skillBoard", x: 1900, prompt: "Read the skills board", reach: 90),
        ]
        for c in Self.cases {
            things.append(HallwayModel.onWall(c.id, "case", x: c.x, prompt: "Look at the \(c.boost.name)", reach: 90))
        }
        engine.load(SceneLayout(width: Self.width, floor: Self.floor, things: things, spawn: CGPoint(x: 250, y: 620)))
        engine.usesHP = false
        engine.showsClock = false
        engine.timerOn = false
        engine.resetNoise()
        engine.noiseMuted = true
        engine.bubble = nil
        belt.reset()
        popup = nil
        banner = nil
        shopOpen = false
        seen = []
        speak("Welcome in! Have a look around. Moonlights only, no IOUs.", 4)
        engine.running = true
    }

    private func tick(_ dt: Double) {
        belt.tick(dt)
        if sayTime > 0 {
            sayTime -= dt
            if sayTime <= 0 { ionSays = nil }
        }
        // Ion chats now and then when you're near the counter.
        chatter -= dt
        if chatter <= 0 {
            chatter = .random(in: 10...16)
            if abs(engine.player.x - Self.ionX) < 600 && ionSays == nil {
                speak(Self.idleLines.randomElement()!, 3.5)
            }
        }
    }

    static let idleLines = [
        "That cape? Nobody hears it. Nobody hears me selling it, either.",
        "The Nokia has survived four floods and my little sister.",
        "Double jump is just a jump that changed its mind.",
        "I see you looking. I'm always looking back.",
        "Moonlights come from winning levels. Win more, buy more. Simple!",
        "Slide under the lasers, not into them. Trust me.",
    ]

    func speak(_ text: String, _ seconds: Double) {
        ionSays = text
        sayTime = seconds
    }

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "exit": onExit()
        case "counter":
            see("ion")
            openShop()
        case "skillBoard":
            speak("Double Jump and Slide: \(Skill.price) moonlights each. Talk to me at the counter!", 3.5)
        case "case":
            guard let c = Self.cases.first(where: { $0.id == thing.id }) else { return }
            see(c.id)
            let owned = game?.boosts.contains(c.boost) == true
            show(Popup(title: c.boost.name, message: c.boost.about + (owned ? "\n\nYou already own this one." : "\n\n\(GameState.shopItemPrice) moonlights at the counter."),
                       symbol: c.boost.symbol, color: c.boost.color == Color(white: 0.85) ? .white : c.boost.color, button: "OK", action: {}))
        default: break
        }
    }

    /// The tour: every display case looked at and Ion talked to.
    private func see(_ id: String) {
        guard let game else { return }
        let before = seen.isSuperset(of: Self.tour)
        seen.insert(id)
        if !before && seen.isSuperset(of: Self.tour) && !game.completedSide.contains(2) {
            game.finishSide(2)
            banner = "Side Level 2 done! You've seen everything in Ion's shop.  +\(GameState.sideReward) moonlights"
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3.5))
                self?.banner = nil
            }
        }
    }

    func openShop() {
        engine.running = false
        shopOpen = true
    }

    func closeShop() {
        shopOpen = false
        engine.running = popup == nil
        if let game { belt.configure(game: game, engine: engine) }
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        wrapped.action = { [weak self] in
            self?.popup = nil
            self?.engine.running = true
            newPopup.action()
        }
        wrapped.secondAction = { [weak self] in
            self?.popup = nil
            self?.engine.running = true
            newPopup.secondAction()
        }
        withAnimation { popup = wrapped }
    }

    func hint() {
        if let next = Self.cases.first(where: { !seen.contains($0.id) }) {
            engine.say("Have a look at the \(next.boost.name) in its case.")
        } else if !seen.contains("ion") {
            engine.say("Go and talk to Ion at the counter.")
        } else {
            engine.say("Moonlights come from winning levels and side levels. Ion takes them at the counter.")
        }
    }
}

struct ShopLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    @State private var model = ShopModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Side Level 2 · The Shop", inventory: [], popup: model.popup,
                      banner: model.banner, belt: model.belt, cornerHint: "Moonlights: \(game.moonlights)",
                      guideTips: GuideTips.shop, onHome: onExit, onRestart: model.reset, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            if model.shopOpen {
                ShopPanel(onClose: model.closeShop)
            }
        }
        .onAppear {
            model.game = game
            model.onExit = onExit
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            ShopWall(width: ShopModel.width)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            // Ion behind his counter: he looks at you wherever you go.
            let head = CGPoint(x: ShopModel.ionX, y: 330)
            let toYou = CGVector(dx: engine.player.x - head.x, dy: engine.player.y - 140 - head.y)
            IonView(gaze: IonView.gaze(toward: toYou), talking: model.ionSays != nil)
                .anchored(at: CGPoint(x: ShopModel.ionX, y: 520))
            ShopCounter().anchored(at: CGPoint(x: ShopModel.ionX, y: 560))
            if let text = model.ionSays {
                SpeechBubble(text: "Ion: \(text)", tint: .teal, small: true)
                    .position(x: ShopModel.ionX, y: 200)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { _ in EmptyView() }
            Palette.shade.opacity(0.1 * Palette.shadeAmount)
        }
        .frame(width: ShopModel.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "exit": DoorView(color: Color(red: 0.30, green: 0.45, blue: 0.40)) { DoorSign(text: "EXIT", color: .green) }
        case "case":
            if let c = ShopModel.cases.first(where: { $0.id == thing.id }) {
                DisplayCase(boost: c.boost, sold: game.boosts.contains(c.boost))
            }
        case "skillBoard": SkillBoard()
        default: EmptyView()
        }
    }
}

// MARK: - Ion

/// Ion, who runs the Shop: a teenager in a green apron with a mop of teal hair and big eyes that
/// follow you (and your finger or pointer, in the shop window). `gaze` is where he's looking,
/// each part from −1 to 1.
struct IonView: View {
    var gaze = CGVector.zero
    var talking = false

    private let skin = Color(red: 0.93, green: 0.76, blue: 0.60)
    private let hair = Color(red: 0.12, green: 0.45, blue: 0.48)

    /// Turns "that way, this far" into a gaze: close things get a little look, far things a full one.
    static func gaze(toward v: CGVector) -> CGVector {
        let length = max(hypot(v.dx, v.dy), 1)
        let strength = min(1, length / 220)
        return CGVector(dx: v.dx / length * strength, dy: v.dy / length * strength)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            figure(t: t)
        }
        .frame(width: 140, height: 250)
    }

    private func figure(t: Double) -> some View {
        let blink = t.truncatingRemainder(dividingBy: 4.2) < 0.15
        let mouthOpen = talking && sin(t * 14) > 0
        return ZStack {
            // Body: hoodie and apron
            RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.95, green: 0.55, blue: 0.25)).frame(width: 84, height: 120).offset(y: 50)
            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.20, green: 0.55, blue: 0.35)).frame(width: 60, height: 92).offset(y: 62)
            Text("ION").font(.game(15, .heavy)).foregroundStyle(.white).padding(.horizontal, 6)
                .background(Color.black.opacity(0.25), in: Capsule()).offset(y: 40)
            // Arms resting on the counter
            Capsule().fill(Color(red: 0.95, green: 0.55, blue: 0.25)).frame(width: 20, height: 64).rotationEffect(.degrees(20)).offset(x: -46, y: 52)
            Capsule().fill(Color(red: 0.95, green: 0.55, blue: 0.25)).frame(width: 20, height: 64).rotationEffect(.degrees(-20)).offset(x: 46, y: 52)
            // Head
            Circle().fill(skin).frame(width: 74).offset(y: -44)
            Ellipse().fill(skin).frame(width: 12, height: 18).offset(x: -37, y: -40)
            Ellipse().fill(skin).frame(width: 12, height: 18).offset(x: 37, y: -40)
            // Messy hair, with a few spikes sticking up
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 80, height: 60).offset(y: -58)
            ForEach(0..<5, id: \.self) { i in
                Triangle().fill(hair).frame(width: 20, height: 22)
                    .rotationEffect(.degrees(Double(i - 2) * 22))
                    .offset(x: CGFloat(i - 2) * 14, y: -94 + abs(CGFloat(i - 2)) * 4)
            }
            Capsule().fill(hair).frame(width: 36, height: 12).rotationEffect(.degrees(-14)).offset(x: 10, y: -64)
            // Big friendly eyes that follow you: a large warm iris with two shines (never a small
            // pupil staring out of a lot of white), and no dark outline.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Group {
                    if blink {
                        Capsule().fill(Color(red: 0.25, green: 0.15, blue: 0.10)).frame(width: 16, height: 2.5)
                    } else {
                        ZStack {
                            Ellipse().fill(Color(white: 0.98))
                            ZStack {
                                Circle().fill(Color(red: 0.42, green: 0.25, blue: 0.13))
                                Circle().fill(Color(red: 0.12, green: 0.07, blue: 0.05)).frame(width: 8)
                                Circle().fill(.white).frame(width: 5.5).offset(x: 2.6, y: -3)
                                Circle().fill(.white.opacity(0.85)).frame(width: 2.5).offset(x: -2.8, y: 3)
                            }
                            .frame(width: 15, height: 15)
                            .offset(x: gaze.dx * 3.5, y: gaze.dy * 3.5)
                        }
                        .frame(width: 19, height: 21)
                        .clipShape(Ellipse())
                        .overlay(Ellipse().stroke(Color(red: 0.55, green: 0.35, blue: 0.25).opacity(0.3), lineWidth: 1))
                    }
                }
                .offset(x: side * 15, y: -40)
            }
            // Eyebrows: gentle when he listens, lifted when he talks (never a frown).
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(hair).brightness(-0.1).frame(width: 15, height: 3.5)
                    .rotationEffect(.degrees(side * (talking ? 0 : 4)))
                    .offset(x: side * 15, y: talking ? -59 : -55)
            }
            // Rosy cheeks
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse().fill(Color.pink.opacity(0.28)).frame(width: 11, height: 7).offset(x: side * 24, y: -28)
            }
            // Freckles and a grin
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color(red: 0.6, green: 0.35, blue: 0.2).opacity(0.5)).frame(width: 3)
                    .offset(x: -26 + CGFloat(i) * 4, y: -24 + CGFloat(i % 2) * 3)
                Circle().fill(Color(red: 0.6, green: 0.35, blue: 0.2).opacity(0.5)).frame(width: 3)
                    .offset(x: 18 + CGFloat(i) * 4, y: -24 + CGFloat(i % 2) * 3)
            }
            if mouthOpen {
                Ellipse().fill(Color(red: 0.4, green: 0.1, blue: 0.12)).frame(width: 16, height: 11).offset(y: -18)
            } else {
                Circle().trim(from: 0.05, to: 0.45).stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 22).offset(y: -27)
            }
        }
    }
}

/// Ion's big portrait in the shop window. His eyes follow your pointer or finger anywhere in the
/// window (`target`, in the "shopPanel" coordinate space), and look back at you when you stop.
private struct IonPortrait: View {
    let target: CGPoint?
    let talking: Bool

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("shopPanel"))
            let eyes = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.33)
            let gaze = target.map { IonView.gaze(toward: CGVector(dx: $0.x - eyes.x, dy: $0.y - eyes.y)) } ?? .zero
            IonView(gaze: gaze, talking: talking)
                .scaleEffect(1.25, anchor: .top)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

// MARK: - The shop window

/// What Ion sells. Opens from the counter in the side level, and from the main menu.
struct ShopPanel: View {
    @Environment(GameState.self) private var game
    let onClose: () -> Void
    @State private var tab = 0
    @State private var line = "What can I get you?"
    @State private var talking = false
    @State private var pointer: CGPoint?
    @State private var lastAccessory = ""

    private static let tabs = ["Boosting items", "Skills", "Upgrades", "Accessories"]
    static let accessoryPrice = 150
    static let exclusivePrice = 400

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onClose)
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 8) {
                    IonPortrait(target: pointer, talking: talking).frame(width: 190, height: 300)
                    Text(line)
                        .font(.game(17, .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .frame(width: 200)
                        .background(Color.teal.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ion's Shop").font(.game(36, .heavy)).foregroundStyle(.white)
                        Spacer()
                        MoonlightCount(amount: game.moonlights, size: 26)
                        RoundIconButton(symbol: "xmark", action: onClose).scaleEffect(0.8)
                    }
                    HStack(spacing: 8) {
                        ForEach(Self.tabs.indices, id: \.self) { i in
                            Button {
                                SoundPlayer.shared.tap()
                                tab = i
                            } label: {
                                Text(Self.tabs[i]).font(.game(16)).foregroundStyle(tab == i ? .black : .white)
                                    .lineLimit(1).fixedSize()
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(tab == i ? AnyShapeStyle(Color.teal) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            switch tab {
                            case 0: boostingItems
                            case 1: skills
                            case 2: upgrades
                            default: accessories
                            }
                        }
                    }
                    .frame(height: 380)
                }
                .frame(width: 600)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.14, blue: 0.24), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.teal.opacity(0.7), lineWidth: 4))
            .coordinateSpace(name: "shopPanel")
            // Ion's eyes follow the pointer (trackpad or mouse) and your finger.
            .onContinuousHover(coordinateSpace: .named("shopPanel")) { phase in
                if case .active(let spot) = phase { pointer = spot } else { pointer = nil }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("shopPanel"))
                .onChanged { pointer = $0.location }
                .onEnded { _ in pointer = nil })
        }
    }

    private func say(_ text: String) {
        line = text
        talking = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            talking = false
        }
    }

    private func short(_ price: Int) -> String {
        "You need \(price - game.moonlights) more moonlights. Win some levels and come back!"
    }

    @ViewBuilder private var boostingItems: some View {
        Text("They work in every level, and they all stack with your other boosts. \(GameState.shopItemPrice) moonlights each.")
            .font(.game(15, .medium)).foregroundStyle(.white.opacity(0.75))
        ForEach(Boost.shopOnly) { boost in
            let owned = game.boosts.contains(boost)
            row(boost.name, boost.about, boost.symbol, boost.color == Color(white: 0.85) ? .white : boost.color,
                price: owned ? "OWNED" : "\(GameState.shopItemPrice)", enabled: !owned && game.moonlights >= GameState.shopItemPrice) {
                if game.buy(boost) {
                    Sound.powerup.play()
                    say("The \(boost.name)! It's already on you. Take good care of it.")
                } else {
                    Sound.buzz.play()
                    say(owned ? "You've got one already!" : short(GameState.shopItemPrice))
                }
            }
        }
    }

    @ViewBuilder private var skills: some View {
        Text("Skills work in every level, forever. \(Skill.price) moonlights each.")
            .font(.game(15, .medium)).foregroundStyle(.white.opacity(0.75))
        ForEach(Skill.forSale, id: \.self) { skill in
            let owned = game.skills.contains(skill)
            row(skill.title.capitalized, skill.how, skill.symbol, .teal,
                price: owned ? "LEARNED" : "\(Skill.price)", enabled: !owned && game.moonlights >= Skill.price) {
                if game.buy(skill) {
                    Sound.magic.play()
                    say("\(skill.title.capitalized)! Practise it on the shop floor if you like.")
                } else {
                    Sound.buzz.play()
                    say(owned ? "You already know that one." : short(Skill.price))
                }
            }
        }
    }

    @ViewBuilder private var upgrades: some View {
        Text("Your stats").font(.game(17, .heavy)).foregroundStyle(Palette.gold)
        ForEach(Stat.allCases) { stat in
            let level = game.upgrades[stat] ?? 0
            let maxed = level >= Stat.maxLevel
            let cost = stat.cost(from: level) * 10
            row("\(stat.name)  \(stat.label(at: level))", "Step \(level) of \(Stat.maxLevel)", stat.symbol, .cyan,
                price: maxed ? "MAX" : "\(cost)", enabled: !maxed && game.moonlights >= cost) {
                if !maxed && game.moonlights >= cost {
                    game.moonlights -= cost
                    game.upgrades[stat] = level + 1
                    Sound.powerup.play()
                    say("\(stat.name) up! Feel that?")
                } else {
                    Sound.buzz.play()
                    say(maxed ? "That's as good as it gets." : short(cost))
                }
            }
        }
        Text("Your items").font(.game(17, .heavy)).foregroundStyle(Palette.gold).padding(.top, 6)
        if !game.skills.contains(.tinker) {
            Text("Locked. Someone has to teach you how to upgrade your boosting and defensive items first... maybe Uncle knows (Level 9).")
                .font(.game(15, .medium)).foregroundStyle(.white.opacity(0.7))
        } else {
            let mine = UpgradeItem.allCases.filter { game.owns($0) }
            if mine.isEmpty {
                Text("You don't have any items to upgrade yet.").font(.game(15, .medium)).foregroundStyle(.white.opacity(0.7))
            }
            ForEach(mine) { item in
                let level = game.itemLevels[item] ?? 0
                let maxed = level >= UpgradeItem.maxLevel
                row("\(item.name)  Lv \(level)/\(UpgradeItem.maxLevel)", "Each level: \(item.perLevel)", item.symbol, item.color,
                    price: maxed ? "MAX" : "\(item.cost(from: level))", enabled: !maxed && game.moonlights >= item.cost(from: level)) {
                    if game.upgrade(item) {
                        Sound.craft.play()
                        say("Tightened, polished, upgraded. \(item.name) is level \(level + 1) now!")
                    } else {
                        Sound.buzz.play()
                        say(maxed ? "Level 3 is the best I can do." : short(item.cost(from: level)))
                    }
                }
            }
        }
    }

    @ViewBuilder private var accessories: some View {
        let allOwned = game.regularAccessories == Accessory.all.count
        row("Mystery accessory", "A random accessory you don't have yet.", "gift.fill", .pink,
            price: allOwned ? "ALL" : "\(Self.accessoryPrice)", enabled: !allOwned && game.moonlights >= Self.accessoryPrice) {
            guard game.moonlights >= Self.accessoryPrice,
                  let item = Accessory.all.filter({ !game.accessories.contains($0) }).randomElement() else {
                Sound.buzz.play()
                say(allOwned ? "You've got every one I sell!" : short(Self.accessoryPrice))
                return
            }
            game.moonlights -= Self.accessoryPrice
            game.take(.accessory(item))
            Sound.magic.play()
            say("Ooh, the \(item.name)! Wear it in Customize.")
        }
        Text("Demo exclusives").font(.game(17, .heavy)).foregroundStyle(Palette.gold).padding(.top, 4)
        ForEach(Accessory.exclusives) { item in
            let owned = game.accessories.contains(item)
            row(item.name, "Only in the demo.", item.symbol, item.color == .black ? .white : item.color,
                price: owned ? "OWNED" : "\(Self.exclusivePrice)", enabled: !owned && game.moonlights >= Self.exclusivePrice) {
                guard !owned, game.moonlights >= Self.exclusivePrice else {
                    Sound.buzz.play()
                    say(owned ? "That one's yours already." : short(Self.exclusivePrice))
                    return
                }
                game.moonlights -= Self.exclusivePrice
                game.accessories.insert(item)
                Sound.magic.play()
                say("A demo exclusive! Nobody else will have one.")
            }
        }
    }

    private func row(_ name: String, _ about: String, _ symbol: String, _ color: Color, price: String, enabled: Bool,
                     action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 24, weight: .bold)).frame(width: 34).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.game(18, .heavy))
                Text(about).font(.game(14, .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: action) {
                Text(price)
                    .font(.game(16, .heavy))
                    .foregroundStyle(enabled ? .black : .white.opacity(0.6))
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 12)
                    .frame(minWidth: 80, minHeight: 34)
                    .background(enabled ? AnyShapeStyle(Color.teal) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// A little moon and how many moonlights you have.
struct MoonlightCount: View {
    let amount: Int
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.stars.fill").font(.system(size: size * 0.85, weight: .bold)).foregroundStyle(Color(red: 0.75, green: 0.85, blue: 1))
                .shadow(color: .white.opacity(0.6), radius: 5)
            Text("\(amount)").font(.game(size, .heavy)).foregroundStyle(Color(red: 0.75, green: 0.85, blue: 1)).monospacedDigit()
        }
    }
}

/// "+250 moonlights", shown for a moment when you earn some.
struct MoonlightToast: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill").font(.system(size: 30, weight: .bold))
            Text("+\(amount) moonlights").font(.game(28, .heavy))
        }
        .foregroundStyle(Color(red: 0.80, green: 0.88, blue: 1))
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(Color(red: 0.12, green: 0.14, blue: 0.30).opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color(red: 0.75, green: 0.85, blue: 1).opacity(0.7), lineWidth: 2))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}

/// The Shop from the main menu: the shop window on its own, over the night sky.
struct ShopMenuView: View {
    let onBack: () -> Void

    var body: some View {
        ZStack {
            NightSky()
            ShopPanel(onClose: onBack)
        }
    }
}

// MARK: - Shop art

struct ShopWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.32, green: 0.24, blue: 0.40), Color(red: 0.42, green: 0.30, blue: 0.42)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            // Fairy lights along the top
            ForEach(0..<Int(width / 60), id: \.self) { i in
                Circle().fill([Color.yellow, .pink, .cyan, .orange][i % 4]).frame(width: 10)
                    .shadow(color: [Color.yellow, .pink, .cyan, .orange][i % 4], radius: 6)
                    .position(x: CGFloat(i) * 60 + 30, y: 40 + sin(CGFloat(i)) * 8)
            }
            // Shelves full of odds and ends
            ForEach([300.0, 1500.0, 1950.0], id: \.self) { x in
                ForEach(0..<3, id: \.self) { row in
                    Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.20)).frame(width: 200, height: 10)
                        .position(x: x, y: 170 + CGFloat(row) * 90)
                    ForEach(0..<5, id: \.self) { n in
                        RoundedRectangle(cornerRadius: 4)
                            .fill([Color.teal, .orange, .purple, .yellow, .pink][(n + row + Int(x)) % 5].opacity(0.85))
                            .frame(width: 26, height: 30 + CGFloat((n * 7 + row * 3) % 20))
                            .position(x: x - 80 + CGFloat(n) * 40, y: 150 + CGFloat(row) * 90 - CGFloat((n * 7 + row * 3) % 20) / 2)
                    }
                }
            }
            // A big moon sign over the counter
            Text("ION'S SHOP")
                .font(.game(44, .heavy))
                .foregroundStyle(Color(red: 0.80, green: 0.90, blue: 1))
                .shadow(color: .cyan, radius: 10)
                .position(x: ShopModel.ionX, y: 110)
            Image(systemName: "moon.stars.fill").font(.system(size: 50)).foregroundStyle(.yellow).shadow(color: .yellow, radius: 10)
                .position(x: ShopModel.ionX + 190, y: 104)
            // Floor
            Rectangle().fill(Color(red: 0.36, green: 0.26, blue: 0.20)).frame(width: width, height: 155).offset(y: 545)
            ForEach(0..<Int(width / 120), id: \.self) { i in
                Rectangle().fill(.black.opacity(0.12)).frame(width: 3, height: 155).offset(x: CGFloat(i) * 120, y: 545)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// The long wooden counter Ion stands behind.
struct ShopCounter: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.55, green: 0.36, blue: 0.22)).frame(width: 340, height: 130)
            Rectangle().fill(Color(red: 0.65, green: 0.45, blue: 0.28)).frame(width: 360, height: 16)
            // A till and a jar of moonlights
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.3)).frame(width: 60, height: 40).offset(x: 110, y: -36)
            Capsule().fill(Color(red: 0.7, green: 0.85, blue: 1).opacity(0.6)).frame(width: 34, height: 44).offset(x: -120, y: -40)
            Image(systemName: "moon.fill").font(.system(size: 16)).foregroundStyle(.yellow).offset(x: -120, y: -32)
        }
        .frame(width: 360, height: 130)
    }
}

/// A glass case with one of Ion's boosting items on a cushion.
struct DisplayCase: View {
    let boost: Boost
    let sold: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.15)).frame(width: 130, height: 120)
                RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 130, height: 120)
                Ellipse().fill(Color(red: 0.6, green: 0.15, blue: 0.25)).frame(width: 90, height: 24).offset(y: 40)
                Image(systemName: boost.symbol).font(.system(size: 50, weight: .bold))
                    .foregroundStyle(boost.color == Color(white: 0.85) ? .white : boost.color)
                    .shadow(color: .white.opacity(0.5), radius: 6)
                    .opacity(sold ? 0.35 : 1)
                if sold {
                    Text("YOURS").font(.game(18, .heavy)).foregroundStyle(.green).rotationEffect(.degrees(-14))
                }
            }
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.20)).frame(width: 140, height: 120)
                .overlay(Text("\(GameState.shopItemPrice)").font(.game(20, .heavy)).foregroundStyle(.yellow).offset(y: -30))
        }
    }
}

/// The board listing Ion's skills.
struct SkillBoard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("SKILLS").font(.game(22, .heavy)).foregroundStyle(.yellow)
            ForEach(Skill.forSale, id: \.self) { skill in
                HStack(spacing: 6) {
                    Image(systemName: skill.symbol)
                    Text(skill.title.capitalized)
                }
                .font(.game(16, .semibold))
                .foregroundStyle(.white)
            }
            Text("\(Skill.price) each").font(.game(15, .heavy)).foregroundStyle(.cyan)
        }
        .padding(14)
        .background(Color(red: 0.15, green: 0.25, blue: 0.20), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.55, green: 0.36, blue: 0.22), lineWidth: 8))
        .padding(.bottom, 170)
    }
}

extension GuideTips {
    static var shop: [String] { [
        "This is Ion's shop. Look at the three glass cases: the Nokia, the Phone and the Sneaky Cape.",
        "Then talk to Ion at the counter (press E). That finishes this side level.",
        "Everything costs moonlights. You earn them by winning levels and side levels, again and again.",
        "Boosting items are 1000 each; skills are 1569. Upgrades for your items unlock after Level 9.",
    ] }
}
