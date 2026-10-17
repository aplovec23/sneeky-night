import SwiftUI

struct InventoryItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let color: Color
}

/// Everything around a level's room: the scaled, scrolling stage, the top bar with the timer,
/// the noise meter, the backpack, the joystick and action buttons, speech bubbles and pop-ups.
struct LevelScaffold<World: View, Extra: View>: View {
    @Environment(GameState.self) private var game
    let engine: GameEngine
    let title: String
    let inventory: [InventoryItem]
    var onInventoryTap: (InventoryItem) -> Void = { _ in }
    let popup: Popup?
    var banner: String?
    var belt: ItemBelt?
    /// Small text pinned to the bottom-left corner of the room (Level 4's code hint).
    var cornerHint: String?
    /// Whoever chases you in this level (creative mode's admin panel can summon them).
    var chase: Chase?
    /// What the Guide says in practice mode, in order.
    var guideTips: [String] = []
    /// Creative mode works here even when it isn't unlocked yet (your own Level Maker levels, when you switch it on there).
    var creativeHere = false
    let onHome: () -> Void
    let onRestart: () -> Void
    let onHint: () -> Void
    @ViewBuilder let world: () -> World
    @ViewBuilder var extra: () -> Extra

    @State private var pauseOpen = false
    @State private var adminOpen = false
    @State private var confetti = 0

    /// The top of the stage is plain wall, so it's cropped to make room for the control strip.
    private static var cropTop: CGFloat { 80 }
    private static var stageHeight: CGFloat { 700 - cropTop }
    /// Joystick and button size: 1.22× the original, times the size picked in Settings.
    private static var k: CGFloat { 1.22 * Settings.shared.controlScale }
    private static var controlsHeight: CGFloat { 170 * k }

    var body: some View {
        GeometryReader { geo in
            let phone = Device.isPhone
            // iPad: the room sits above a control strip. iPhone: the room fills the screen and
            // the controls float over it.
            let scale = phone ? geo.size.height / Self.stageHeight
                              : min(geo.size.width / 1000, (geo.size.height - Self.controlsHeight) / Self.stageHeight)
            let viewWidth = phone ? geo.size.width / scale : 1000
            let shown = min(viewWidth, engine.width)
            ZStack {
                Color.black
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        world()
                        GuideWalker(engine: engine).allowsHitTesting(false)
                        bubble
                    }
                    .frame(width: engine.width, height: engine.height, alignment: .topLeading)
                    .offset(x: -engine.camera, y: -Self.cropTop - engine.cameraY)
                    .frame(width: shown, height: Self.stageHeight, alignment: .topLeading)
                    .clipped()
                    .overlay { AmbientLayer().allowsHitTesting(false) }
                    .scaleEffect(scale)
                    .frame(width: shown * scale, height: Self.stageHeight * scale)
                    .overlay(alignment: phone ? .top : .bottomLeading) {
                        if let cornerHint {
                            Text(cornerHint)
                                .font(.game(phone ? 11 : 17, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, phone ? 3 : 6)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(.top, phone ? 46 : 10)
                                .padding([.horizontal, .bottom], 10)
                        }
                    }
                    if !phone {
                        controls
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(LinearGradient(colors: [Color(red: 0.13, green: 0.10, blue: 0.24), Color(red: 0.05, green: 0.04, blue: 0.11)],
                                                       startPoint: .top, endPoint: .bottom))
                            .overlay(alignment: .top) { Rectangle().fill(Palette.gold.opacity(0.35)).frame(height: 2) }
                    }
                }

                if phone {
                    // Everything on top of the room is drawn smaller; the controls are see-through.
                    let small: CGFloat = 0.6
                    ZStack {
                        topBar
                        VStack {
                            Spacer()
                            controls
                                .opacity(0.6)
                                .padding(.bottom, 16)
                        }
                        bannerView
                    }
                    .padding(.horizontal, 70)
                    .frame(width: geo.size.width / small, height: geo.size.height / small)
                    .scaleEffect(small)
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    topBar
                    bannerView
                }
                FitToPhone {
                    ZStack {
                        if let popup {
                            PopupView(popup: popup).id(popup.id).transition(.opacity)
                        }
                        extra()
                        if adminOpen {
                            AdminPanel(context: AdminContext(engine: engine, chase: chase, belt: belt, restart: onRestart,
                                                             confetti: { confetti += 1 }),
                                       onClose: { adminOpen = false; engine.paused = false })
                        }
                        if pauseOpen {
                            PauseOverlay(engine: engine, onResume: { setPause(false) },
                                         onRestart: { setPause(false); onRestart() },
                                         onHome: { setPause(false); onHome() })
                        }
                    }
                }
                if confetti > 0 {
                    ConfettiView().id(confetti).allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(duration: 0.3), value: banner)
            .animation(.easeOut(duration: 0.2), value: pauseOpen)
            .onAppear {
                engine.viewWidth = viewWidth
                engine.creative = game.creativeActive || creativeHere
                // Creative mode comes with immortality and the untouchable buff (the admin panel can switch them off).
                if engine.creative {
                    engine.godMode = true
                    engine.ghost = true
                }
                engine.multiplayer = game.multiplayer
                engine.placePlayer2()
                if game.multiplayer { game.award(.multiplayer) }
                engine.onPause = { setPause(!pauseOpen) }
                engine.onMenuKey = { key in
                    switch key {
                    case .menu: onHome()
                    case .restart: onRestart()
                    case .hint: onHint()
                    case .admin:
                        if engine.creative {
                            adminOpen = true
                            engine.paused = true
                        }
                    default: break
                    }
                }
            }
            .onDisappear {
                // Creative-mode changes don't follow you out of the level.
                Settings.shared.skyOverride = nil
                SoundPlayer.shared.setMusic(rate: 1)
            }
            .onChange(of: geo.size) { _, _ in engine.viewWidth = viewWidth }
        }
        .ignoresSafeArea()
    }

    private func setPause(_ on: Bool) {
        guard !adminOpen else { return }
        pauseOpen = on
        engine.paused = on
        engine.stick = .zero
        engine.stick2 = .zero
    }

    @ViewBuilder private var bannerView: some View {
        if let banner {
            Text(banner)
                .font(.game(34, .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background((banner.hasPrefix("Checkpoint") ? Color.green : Color.red).opacity(0.85), in: Capsule())
                .shadow(radius: 10)
                .offset(y: -150)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder private var bubble: some View {
        if let text = engine.bubble {
            SpeechBubble(text: text, tint: Palette.gold)
                .position(x: min(max(engine.player.x, engine.camera + 170), engine.camera + max(engine.viewWidth, 340) - 170),
                          y: max(engine.player.y - engine.z - 220, engine.cameraY + 190))
                .id(engine.bubbleID)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: engine.bubbleID)
        }
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 14) {
                RoundIconButton(symbol: "pause.fill", key: GameKey.pause.label) { setPause(true) }
                RoundIconButton(symbol: "house.fill", key: GameKey.menu.label, action: onHome)
                RoundIconButton(symbol: "arrow.counterclockwise", key: GameKey.restart.label, action: onRestart)
                Spacer()
                Text(title)
                    .font(.game(26))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.45), in: Capsule())
                VStack(spacing: 6) {
                    if engine.showsClock { TimerBadge(seconds: engine.timeLeft) }
                    if engine.usesHP { HealthBar(hp: engine.hp, max: engine.maxHP) }
                    NoiseMeter(level: engine.noise)
                }
                Spacer()
                if engine.creative {
                    RoundIconButton(symbol: "wand.and.stars", key: GameKey.admin.label) {
                        adminOpen = true
                        engine.paused = true
                    }
                }
                RoundIconButton(symbol: "lightbulb.fill", key: GameKey.hint.label, action: onHint)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    backpack
                    if Settings.shared.practice {
                        GuideCard(tips: guideTips, onHint: onHint)
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .padding(24)
    }

    private var controls: some View {
        let k = Self.k
        // Settings can swap the sides: joystick on the right, buttons on the left.
        return HStack(alignment: .center) {
            if engine.player2 != nil {
                // Two players: player 1's joystick on the far left, player 2's on the far right.
                Joystick(engine: engine, k: k)
                Spacer()
                itemButtons(k)
                Spacer()
                buttons(k)
                playerTwoControls(k)
            } else {
                if Settings.shared.swapSides { buttons(k) } else { Joystick(engine: engine, k: k) }
                Spacer()
                itemButtons(k)
                Spacer()
                if Settings.shared.swapSides { Joystick(engine: engine, k: k) } else { buttons(k) }
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.15), value: currentPrompt)
    }

    /// Player 2's own joystick and "use" button, on the right-hand side of the screen.
    private func playerTwoControls(_ k: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text("PLAYER 2")
                .font(.game(12, .heavy))
                .foregroundStyle(.orange)
            HStack(spacing: 8) {
                ActionButton(key: GameKey.use2.label, symbol: "hand.raised.fill", size: 58 * k, color: .orange, action: engine.interact2)
                Joystick(engine: engine, k: k * 0.8, second: true)
            }
        }
        .padding(.leading, 18)
    }

    @ViewBuilder private func itemButtons(_ k: CGFloat) -> some View {
        if let belt {
            let items = ItemBelt.Item.allCases.filter { belt.owned.contains($0) }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(62 * k), spacing: 8), count: items.count > 4 ? 3 : items.count > 2 ? 2 : max(items.count, 1)), spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let wait = belt.cooldowns[item] ?? 0
                    ActionButton(key: item.key, symbol: item.symbol, size: (items.count > 2 ? 56 : 62) * k,
                                 color: wait > 0 || (item == .hat && !belt.hatOn) ? Color(white: 0.3) : item.color) { belt.use(item) }
                        .overlay {
                            if item == .hat {
                                Text(belt.hatOn ? "ON" : "OFF").font(.game(16, .heavy)).foregroundStyle(belt.hatOn ? .yellow : .white.opacity(0.8))
                                    .offset(y: 22)
                            } else if item == .cloud && engine.flying {
                                Text("\(Int(engine.flyLeft.rounded(.up)))").font(.game(22, .heavy)).foregroundStyle(.white)
                            } else if item == .lightning && belt.lightningLeft > 0 {
                                Text("\(Int(belt.lightningLeft.rounded(.up)))").font(.game(22, .heavy)).foregroundStyle(.yellow)
                            } else if item == .stick && wait > 0 {
                                Text("USED").font(.game(14, .heavy)).foregroundStyle(.white.opacity(0.85)).offset(y: 22)
                            } else if wait > 0 {
                                Text("\(Int(wait.rounded(.up)))").font(.game(22, .heavy)).foregroundStyle(.white)
                            }
                        }
                }
            }
            .fixedSize()
        }
    }

    private func buttons(_ k: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ActionButton(key: GameKey.taunt.label, symbol: "face.smiling.inverse", size: 58 * k, color: .pink, action: engine.taunt)
                    ActionButton(key: GameKey.crouch.label, symbol: "arrow.down.to.line", size: 58 * k,
                                 color: engine.ducking ? .purple : Color(white: 0.35), action: engine.toggleCrouch)
                    ActionButton(key: GameKey.carry.label, symbol: engine.carrying == nil ? "shippingbox.fill" : "arrow.down.to.line",
                                 size: 58 * k, color: .teal, action: engine.moveObject)
                }
                if engine.canRun || engine.canDash {
                    HStack(spacing: 8) {
                        if engine.canRun {
                            ActionButton(key: GameKey.run.label, symbol: "figure.run", size: 58 * k,
                                         color: engine.runHeld ? .green : Color(white: 0.35)) { engine.runHeld.toggle() }
                        }
                        if engine.canDash {
                            ActionButton(key: GameKey.dash.label, symbol: "wind", size: 58 * k, color: .cyan, action: engine.dash)
                        }
                    }
                }
            }
            ActionButton(key: GameKey.jump.label, symbol: "arrow.up", size: 82 * k, color: .blue, action: engine.jump)
            ActionButton(key: GameKey.use.label, symbol: "hand.raised.fill", size: 100 * k,
                         color: currentPrompt == nil ? .gray : Palette.button, action: engine.interact)
                .overlay(alignment: Settings.shared.swapSides ? .topLeading : .topTrailing) {
                    if let prompt = currentPrompt {
                        Text("\(GameKey.use.label) · \(prompt)")
                            .font(.game(20))
                            .foregroundStyle(.black)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Palette.gold, in: Capsule())
                            .shadow(radius: 4)
                            .offset(y: -58)
                            .transition(.opacity)
                    }
                }
        }
    }

    /// What E will do right now: the thing you're next to, or the level's stand-anywhere action.
    private var currentPrompt: String? {
        if let i = engine.nearest, i < engine.things.count { return engine.things[i].prompt }
        return engine.hidden ? nil : engine.defaultPrompt
    }

    private var backpack: some View {
        HStack(spacing: 10) {
            Image(systemName: "backpack.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.8))
            ForEach(0..<max(3, inventory.count), id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    if i < inventory.count {
                        let item = inventory[i]
                        Image(systemName: item.symbol)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(item.color)
                            .transition(.scale)
                            .onTapGesture { onInventoryTap(item) }
                    }
                }
            }
        }
        .padding(8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.4, bounce: 0.5), value: inventory)
    }
}

/// Shows how close you are to waking someone up. Hidden when it's quiet.
struct NoiseMeter: View {
    let level: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: level > 70 ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                .font(.system(size: 16, weight: .bold))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(level > 70 ? Color.red : level > 40 ? Color.orange : Color.green)
                    .frame(width: 110 * level / 100)
            }
            .frame(width: 110, height: 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
        .opacity(level > 1 ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: level > 1)
    }
}

struct TimerBadge: View {
    let seconds: Double

    var body: some View {
        let whole = Int(seconds.rounded(.up))
        let low = whole <= 10
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
            Text(String(format: "%d:%02d", whole / 60, whole % 60))
                .monospacedDigit()
        }
        .font(.game(26))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(low ? Color.red : Color.black.opacity(0.45), in: Capsule())
        .scaleEffect(low && whole % 2 == 0 ? 1.1 : 1)
        .animation(.spring(duration: 0.25), value: whole)
    }
}

/// Drag the knob to walk. Works alongside WASD on a keyboard.
struct Joystick: View {
    let engine: GameEngine
    var k: CGFloat = 1
    /// True for player 2's joystick.
    var second = false
    @State private var knob: CGSize = .zero

    var body: some View {
        let radius = 54 * k
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.10), .black.opacity(0.4)], center: .center, startRadius: 4, endRadius: 80 * k))
                .overlay(Circle().stroke((second ? Color.orange : .white).opacity(0.4), lineWidth: 3))
                .frame(width: 150 * k, height: 150 * k)
            if Settings.shared.keyLabels {
                // The four keys that do the same as pushing the stick each way.
                let keys: [GameKey] = second ? [.up2, .left2, .down2, .right2] : [.up, .left, .down, .right]
                let spots: [CGSize] = [CGSize(width: 0, height: -60), CGSize(width: -60, height: 0), CGSize(width: 0, height: 60), CGSize(width: 60, height: 0)]
                ForEach(0..<4, id: \.self) { i in
                    Text(keys[i].label)
                        .font(.game(13 * k, .heavy))
                        .foregroundStyle(.white.opacity(0.55))
                        .offset(x: spots[i].width * k, y: spots[i].height * k)
                }
            }
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 0.75)], center: .topLeading, startRadius: 2, endRadius: 60 * k))
                .frame(width: 64 * k, height: 64 * k)
                .shadow(radius: 4)
                .offset(knob)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var v = value.translation
                    let length = hypot(v.width, v.height)
                    if length > radius {
                        v.width *= radius / length
                        v.height *= radius / length
                    }
                    knob = v
                    let push = CGVector(dx: v.width / radius, dy: v.height / radius)
                    if second { engine.stick2 = push } else { engine.stick = push }
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.2)) { knob = .zero }
                    if second { engine.stick2 = .zero } else { engine.stick = .zero }
                }
        )
    }
}

/// A round game button. It acts the instant your finger touches it (not when you lift off),
/// so jumping, dashing and taunting never wait on you.
struct ActionButton: View {
    let key: String
    let symbol: String
    let size: CGFloat
    let color: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color.opacity(0.9).gradient, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 3))
            if Settings.shared.keyLabels {
                Text(key)
                    .font(.game(14, .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(.white, in: Capsule())
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
        .scaleEffect(pressed ? 0.88 : 1)
        .brightness(pressed ? -0.08 : 0)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    if Settings.shared.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    action()
                }
                .onEnded { _ in pressed = false }
        )
    }
}

/// The player as drawn in a room: shadow, name tag and character, lifted while jumping.
struct PlayerSprite: View {
    let engine: GameEngine
    let look: Look
    let name: String
    var opacity: Double = 1

    var body: some View {
        let range = engine.floor.upperBound - engine.floor.lowerBound
        // Rooms shrink you a little toward the back wall; the top-down maze doesn't.
        let depth = engine.height > 700 ? 1 : 0.86 + (engine.player.y - engine.floor.lowerBound) / max(range, 1) * 0.2
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.3))
                .frame(width: 70 * depth * (1 - min(engine.z, 150) / 400), height: 16)
                .offset(y: 6)
            VStack(spacing: 2) {
                Text(name)
                    .font(.game(18))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.4), in: Capsule())
                    .opacity(Settings.shared.nameTag ? 1 : 0)
                CharacterView(look: look, facingRight: engine.facingRight,
                              walking: engine.walking && engine.z == 0,
                              crouching: engine.crouching || engine.ducking, taunting: engine.taunting,
                              expression: mood)
                    .overlay(alignment: .top) {
                        // The creative crown: only while creative mode is on.
                        if engine.creative { CreativeCrown().offset(y: -34) }
                    }
                    .colorMultiply(engine.hurt ? Color(red: 1, green: 0.45, blue: 0.45) : .white)
            }
            .scaleEffect(depth * engine.sizeScale, anchor: .bottom)
            .background(alignment: .bottom) {
                if engine.flying { FlyingCloud().offset(y: 22) }
            }
            .offset(y: -engine.z)
        }
        .frame(width: 140, height: 200, alignment: .bottom)
        .opacity(engine.hidden ? 0 : engine.coverY != nil ? opacity * 0.55 : opacity)
        .anchored(at: engine.player)
    }

    /// The face your character makes right now. Nil: their usual resting face.
    private var mood: Mood? {
        if engine.hurt || engine.threat == 2 { return .scared }
        if engine.z > 40 && !engine.flying { return .surprised }
        if engine.threat == 1 || engine.noise > 70 { return .worried }
        if engine.ducking || engine.coverY != nil { return .sneaky }
        if engine.sprinting || engine.flying { return .happy }
        return nil
    }
}

/// Floor objects and the player drawn back-to-front, so whoever is lower on the screen is in front.
struct FloorLayer<ThingView: View>: View {
    let engine: GameEngine
    let look: Look
    let name: String
    var playerOpacity: Double = 1
    @ViewBuilder let draw: (Thing) -> ThingView

    var body: some View {
        // Only what's near the screen is drawn (the maze has hundreds of things).
        let view = CGRect(x: engine.camera - 260, y: engine.cameraY - 160, width: engine.viewWidth + 520, height: 1120)
        let floorThings = engine.things.filter { $0.onFloor && !$0.hidden && view.contains($0.pos) }
        // Looked up by id while drawing (faster than searching the list for every thing).
        let byID = Dictionary(floorThings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Hiding under a table draws you behind it.
        let playerY = engine.coverY.map { $0 - 1 } ?? engine.player.y
        let second: [(String, CGFloat)] = engine.player2.map { [("player2", $0.y)] } ?? []
        let order = (floorThings.map { ($0.id, $0.flat ? -1 : $0.pos.y + $0.sortOffset) } + [("player", playerY)] + second).sorted { $0.1 < $1.1 }
        ZStack(alignment: .topLeading) {
            ForEach(order, id: \.0) { id, _ in
                if id == "player" {
                    PlayerSprite(engine: engine, look: look, name: name, opacity: playerOpacity)
                } else if id == "player2", let spot = engine.player2 {
                    PlayerTwoSprite(engine: engine).anchored(at: spot)
                } else if let thing = byID[id] {
                    // Things dropped in by creative mode look the same in every level.
                    if thing.id.hasPrefix("admin-") {
                        Group {
                            if thing.kind == "chair" { ChairView() } else { CardboardBox(open: false) }
                        }
                        .anchored(at: thing.pos)
                    } else {
                        draw(thing).anchored(at: thing.pos)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Places the view so its bottom centre sits on `point` (a spot on the floor).
    func anchored(at point: CGPoint) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .overlay(alignment: .bottom) { self.fixedSize() }
            .position(point)
    }
}
