import SwiftUI
import Observation

/// Side Level 2 rules: a cave that never ends. Mine orbs from the glowing rocks (they grow back),
/// and spend them at the Orb Shop on upgrades that work in every level (speed goes up to ×5.7),
/// on accessories, and on demo-only exclusives. Sliding spikes hurt. The quest board gives one
/// quest; finishing it finishes the side level, and you can keep mining afterwards.
@MainActor
@Observable
final class DungeonModel {
    let engine = GameEngine()
    var popup: Popup?
    var banner: String?
    var shopOpen = false
    var questOpen = false
    /// Orbs still inside each rock.
    var left: [String: Int] = [:]
    var spikes: [Walker] = []
    let belt = ItemBelt()

    @ObservationIgnored weak var game: GameState?
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored private var regrow: [String: Double] = [:]
    @ObservationIgnored private var bannerTime = 0.0

    static let floor: ClosedRange<CGFloat> = 545...690
    static let width: CGFloat = 3900
    static let rockCount = 12
    static let questOrbs = 40
    static let questUpgrades = 3
    static let accessoryPrice = 15
    static let exclusivePrice = 40

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onKO = { [weak self] in self?.knockedOut() }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        // Practice mode: the Guide leads you to a rock with orbs left, or to the shop.
        engine.guideGoal = { [weak self] in
            guard let self, let next = questParts.first(where: { !$0.met }) else { return nil }
            if next.text.hasPrefix("Mine") {
                return engine.nearestSpot { $0.kind == "rock" && (self.left[$0.id] ?? 0) > 0 }
            }
            return engine.spot("shop")
        }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func reset() {
        var things: [Thing] = [
            HallwayModel.onWall("exit", "exit", x: 110, prompt: "Leave the dungeon"),
            HallwayModel.onWall("shop", "shop", x: 430, prompt: "Open the Orb Shop", reach: 110),
            HallwayModel.onWall("quest", "quest", x: 730, prompt: "Read the quest board", reach: 80),
        ]
        left = [:]
        regrow = [:]
        for i in 0..<Self.rockCount {
            let id = "rock\(i)"
            things.append(Thing(id: id, kind: "rock", pos: CGPoint(x: 980 + CGFloat(i) * 235, y: [580, 665, 610][i % 3]),
                                footprint: CGSize(width: 100, height: 34), solid: true,
                                prompt: "Mine an orb", reach: CGSize(width: 120, height: 70)))
            left[id] = 3
        }
        spikes = (0..<5).map { i in
            let start = 1150 + CGFloat(i) * 520
            return Walker(id: i, kind: .stranger, pos: CGPoint(x: start, y: [640, 590, 675, 620, 600][i]),
                          range: start...(start + 420), speed: (i % 2 == 0 ? 1 : -1) * (150 + CGFloat(i) * 20))
        }
        engine.load(SceneLayout(width: Self.width, floor: Self.floor, things: things, spawn: CGPoint(x: 240, y: 620)))
        engine.usesHP = true
        engine.showsClock = false
        engine.timerOn = false
        engine.resetNoise()
        engine.noiseMuted = true
        engine.bubble = nil
        belt.reset()
        popup = nil
        banner = nil
        shopOpen = false
        questOpen = false
        engine.running = true
        engine.say("Glowing rocks! I bet there are orbs inside.", seconds: 3)
    }

    // MARK: Quest

    var questParts: [(text: String, met: Bool)] {
        guard let game else { return [] }
        let bought = game.upgrades.values.reduce(0, +)
        let exclusive = !game.accessories.isDisjoint(with: Accessory.exclusives)
        return [("Mine \(Self.questOrbs) orbs (\(min(game.orbsMined, Self.questOrbs))/\(Self.questOrbs))", game.orbsMined >= Self.questOrbs),
                ("Buy \(Self.questUpgrades) upgrades (\(min(bought, Self.questUpgrades))/\(Self.questUpgrades))", bought >= Self.questUpgrades),
                ("Buy a demo exclusive", exclusive)]
    }

    private func checkQuest() {
        guard let game, !game.completedSide.contains(2), !questParts.isEmpty, questParts.allSatisfy(\.met) else { return }
        game.completedSide.insert(2)
        game.orbs += 25
        shopOpen = false
        questOpen = false
        Sound.win.play()
        show(Popup(title: "Quest complete!", message: "Side Level 2 is finished, and the quest paid 25 bonus orbs. The dungeon never ends, so mine as long as you like!",
                   symbol: "checkmark.seal.fill", color: .green, button: "Keep mining", action: {},
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "exit": onExit()
        case "shop":
            engine.running = false
            shopOpen = true
        case "quest":
            engine.running = false
            questOpen = true
        case "rock": mine(i)
        default: break
        }
    }

    private func mine(_ i: Int) {
        let id = engine.things[i].id
        guard let game, let orbsLeft = left[id], orbsLeft > 0 else { return }
        // One hit in eight knocks out a big orb worth 3.
        let found = (Int.random(in: 0..<8) == 0 ? 3 : 1) * Difficulty.current.orbScale
        left[id] = orbsLeft - 1
        game.orbs += found
        game.orbsMined += found
        Sound.craft.play(volume: 0.7)
        Sound.star.play(volume: 0.6)
        engine.say(found >= 3 * Difficulty.current.orbScale ? "A BIG orb! +\(found)" : "+\(found) orb\(found == 1 ? "" : "s")", seconds: 0.9)
        if orbsLeft - 1 == 0 {
            engine.things[i].prompt = nil
            regrow[id] = 20
        }
        checkQuest()
    }

    private func tick(_ dt: Double) {
        belt.tick(dt)
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        // Mined-out rocks grow new orbs after 20 seconds.
        for (id, time) in regrow {
            if time - dt <= 0 {
                regrow[id] = nil
                left[id] = 3
                if let i = engine.index(of: id) { engine.things[i].prompt = "Mine an orb" }
            } else {
                regrow[id] = time - dt
            }
        }
        let player = engine.player
        for i in spikes.indices {
            spikes[i].pos.x += spikes[i].speed * CGFloat(dt) * Difficulty.current.hazardSpeed
            if spikes[i].pos.x >= spikes[i].range.upperBound || spikes[i].pos.x <= spikes[i].range.lowerBound {
                spikes[i].pos.x = min(max(spikes[i].pos.x, spikes[i].range.lowerBound), spikes[i].range.upperBound)
                spikes[i].speed = -spikes[i].speed
            }
            if abs(player.x - spikes[i].pos.x) < 46, abs(player.y - spikes[i].pos.y) < 20, engine.z < 14, engine.damage(15) {
                engine.say("Ouch! Spikes!", seconds: 1.2)
            }
        }
    }

    /// Out of health: you wake up at the entrance and drop a few orbs.
    private func knockedOut() {
        guard let game else { return }
        let lost = min(5, game.orbs)
        game.orbs -= lost
        engine.player = CGPoint(x: 240, y: 620)
        engine.hp = engine.maxHP
        engine.running = true
        banner = lost > 0 ? "Knocked out! You dropped \(lost) orbs." : "Knocked out! Back to the entrance."
        bannerTime = 3
        Sound.caught.play()
    }

    // MARK: Shop

    func buy(_ stat: Stat) {
        guard let game else { return }
        if game.buyUpgrade(stat) {
            Sound.powerup.play()
            belt.configure(game: game, engine: engine)
            checkQuest()
        } else {
            Sound.buzz.play()
        }
    }

    /// A random accessory you don't have. Returns its name, or nil if you couldn't buy one.
    func buyAccessory() -> String? {
        guard let game, game.orbs >= Self.accessoryPrice,
              let item = Accessory.all.filter({ !game.accessories.contains($0) }).randomElement() else {
            Sound.buzz.play()
            return nil
        }
        game.orbs -= Self.accessoryPrice
        game.take(.accessory(item))
        Sound.magic.play()
        return item.name
    }

    func buy(exclusive item: Accessory) {
        guard let game, game.orbs >= Self.exclusivePrice, !game.accessories.contains(item) else {
            Sound.buzz.play()
            return
        }
        game.orbs -= Self.exclusivePrice
        game.accessories.insert(item)
        Sound.magic.play()
        checkQuest()
    }

    func closeOverlays() {
        shopOpen = false
        questOpen = false
        engine.running = popup == nil
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
        engine.running = true
    }

    func hint() {
        if game?.completedSide.contains(2) == true {
            engine.say("The quest is done. I can keep mining and shopping for as long as I like.")
        } else if let next = questParts.first(where: { !$0.met }) {
            engine.say("Quest: \(next.text)")
        }
    }
}

struct DungeonLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    @State private var model = DungeonModel()
    @State private var lastBought = ""

    private static let orbColors: [Color] = [.cyan, .purple, .green, .pink, .yellow]

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Side Level 2 · The Dungeon  ·  \(game.orbs) orbs",
                      inventory: [], popup: model.popup, banner: model.banner, belt: model.belt,
                      guideTips: GuideTips.dungeon, onHome: onExit, onRestart: model.reset, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            if model.shopOpen { shop }
            if model.questOpen { quest }
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
            DungeonWall(width: DungeonModel.width)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            ForEach(model.spikes) { spike in
                SpikeTrapView().anchored(at: spike.pos)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { thing in
                OrbRockView(left: model.left[thing.id] ?? 0,
                            color: Self.orbColors[(Int(thing.id.dropFirst(4)) ?? 0) % Self.orbColors.count])
            }
            Palette.shade.opacity(0.2 * Palette.shadeAmount)
        }
        .frame(width: DungeonModel.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "exit": DoorView(color: Color(red: 0.30, green: 0.30, blue: 0.36)) { DoorSign(text: "EXIT", color: .green) }
        case "shop": OrbShopView()
        case "quest": QuestBoardView(done: game.completedSide.contains(2))
        default: EmptyView()
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: model.closeOverlays)
            VStack(spacing: 12) {
                HStack {
                    Text(title).font(.game(36, .heavy)).foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(RadialGradient(colors: [.white, .cyan], center: .center, startRadius: 1, endRadius: 12)).frame(width: 22)
                        Text("\(game.orbs)").font(.game(26, .heavy)).foregroundStyle(.cyan).monospacedDigit()
                    }
                    RoundIconButton(symbol: "xmark", action: model.closeOverlays).scaleEffect(0.8)
                }
                content()
            }
            .padding(24)
            .frame(width: 880)
            .background(Color(red: 0.12, green: 0.10, blue: 0.24), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.cyan.opacity(0.6), lineWidth: 4))
        }
    }

    private var shop: some View {
        panel("Orb Shop") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upgrades (they work in every level)").font(.game(17, .heavy)).foregroundStyle(Palette.gold)
                    ForEach(Stat.allCases) { stat in
                        upgradeRow(stat)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessories").font(.game(17, .heavy)).foregroundStyle(Palette.gold)
                    buyRow("Mystery accessory", "gift.fill", .pink, price: DungeonModel.accessoryPrice,
                           owned: game.regularAccessories == Accessory.all.count) {
                        if let name = model.buyAccessory() { lastBought = "You got the \(name)!" }
                    }
                    if !lastBought.isEmpty {
                        Text(lastBought).font(.game(14, .semibold)).foregroundStyle(.green)
                    }
                    Text("Demo exclusives").font(.game(17, .heavy)).foregroundStyle(Palette.gold).padding(.top, 4)
                    ForEach(Accessory.exclusives) { item in
                        buyRow(item.name, item.symbol, item.color, price: DungeonModel.exclusivePrice,
                               owned: game.accessories.contains(item)) { model.buy(exclusive: item) }
                    }
                }
            }
        }
    }

    private func upgradeRow(_ stat: Stat) -> some View {
        let level = game.upgrades[stat] ?? 0
        let maxed = level >= Stat.maxLevel
        return HStack(spacing: 8) {
            Image(systemName: stat.symbol).frame(width: 26).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stat.name)  \(stat.label(at: level))").font(.game(17))
                HStack(spacing: 3) {
                    ForEach(0..<Stat.maxLevel, id: \.self) { i in
                        Capsule().fill(i < level ? Color.cyan : .white.opacity(0.18)).frame(width: 14, height: 6)
                    }
                }
            }
            Spacer()
            price(maxed ? "MAX" : "\(stat.cost(from: level))", enabled: !maxed && game.orbs >= stat.cost(from: level)) { model.buy(stat) }
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: 400)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private func buyRow(_ name: String, _ symbol: String, _ color: Color, price cost: Int, owned: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(color == .black ? .white : color)
            Text(name).font(.game(16)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            price(owned ? "OWNED" : "\(cost)", enabled: !owned && game.orbs >= cost, action: action)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: 400)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private func price(_ text: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(text)
                .font(.game(16, .heavy))
                .foregroundStyle(enabled ? .black : .white.opacity(0.6))
                .frame(width: 76, height: 34)
                .background(enabled ? AnyShapeStyle(Color.cyan) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var quest: some View {
        panel("Quest Board") {
            VStack(alignment: .leading, spacing: 12) {
                Text(game.completedSide.contains(2) ? "Quest complete! The dungeon is yours to mine forever."
                                                    : "The dungeon has no end... but finish this quest and Side Level 2 counts as done:")
                    .font(.game(20, .medium))
                    .foregroundStyle(.white.opacity(0.9))
                ForEach(model.questParts, id: \.text) { part in
                    HStack(spacing: 10) {
                        Image(systemName: part.met ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(part.met ? .green : .white.opacity(0.5))
                        Text(part.text)
                    }
                    .font(.game(24, .semibold))
                    .foregroundStyle(.white)
                }
                Text("Reward: 25 orbs.").font(.game(18, .semibold)).foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
