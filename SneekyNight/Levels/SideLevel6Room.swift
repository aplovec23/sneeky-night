import SwiftUI
import Observation

/// Side Level 6 rules: The Room. Only players with the Guide's Hat can see it. A vault door
/// with a 10-character lock (letters and numbers), and no clues anywhere: you have to know the
/// code, or guess it. Behind the door, on a pedestal, is the golden stick — the same one that
/// very, very rarely turns up on the roof. It's yours to keep: press K in any level to use it.
/// Nobody chases you and there's no clock.
@MainActor
@Observable
final class RoomModel {
    let engine = GameEngine()
    let belt = ItemBelt()
    var popup: Popup?
    var banner: String?
    var vaultOpen = false
    var stickTaken = false
    var showKeypad = false

    @ObservationIgnored var onExit: () -> Void = {}
    /// Gives you the golden stick and marks the side level as done. Returns false if you already had it.
    @ObservationIgnored var claimStick: () -> Bool = { false }
    @ObservationIgnored private var guesses = 0

    static let floor: ClosedRange<CGFloat> = 545...690
    static let width: CGFloat = 1600
    static let vaultX: CGFloat = 1240
    static let code = "1PO98LMJM8"

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTick = { [weak self] dt in self?.belt.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func reset() {
        engine.load(SceneLayout(width: Self.width, floor: Self.floor, things: Self.things(), spawn: CGPoint(x: 240, y: 620)))
        engine.timerOn = false
        engine.showsClock = false
        engine.resetNoise()
        engine.noiseFactor = 0
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        belt.reset()
        popup = nil
        banner = nil
        vaultOpen = false
        stickTaken = false
        showKeypad = false
        guesses = 0
        engine.running = true
        engine.say("The Room. Only the Guide's Hat could have shown me this place...", seconds: 4)
    }

    static func things() -> [Thing] {
        typealias H = HallwayModel
        return [
            H.onWall("exitDoor", "exitDoor", x: 120, prompt: "Leave the Room"),
            H.onWall("portrait", "portrait", x: 560, prompt: "Look at the painting", reach: 80),
            H.onWall("vault", "vault", x: vaultX, prompt: "Try the lock", reach: 110),
        ]
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        switch engine.things[i].kind {
        case "exitDoor": onExit()
        case "portrait":
            engine.say("A painting of the Guide, lantern in hand. His eyes seem to follow me...", seconds: 3)
        case "vault":
            if vaultOpen { return }
            Sound.beep.play()
            engine.running = false
            showKeypad = true
        case "pedestal": takeStick(i)
        default: break
        }
    }

    /// Letters and numbers, 10 of them. Small letters count as capitals.
    func submitCode(_ entry: String) -> Bool {
        let typed = entry.uppercased().filter { !$0.isWhitespace }
        guard typed == Self.code else {
            guesses += 1
            Sound.buzz.play()
            return false
        }
        Sound.unlock.play()
        Sound.door.play()
        showKeypad = false
        vaultOpen = true
        if let v = engine.index(of: "vault") { engine.things[v].prompt = nil }
        // Behind the vault door: a pedestal with the golden stick.
        engine.things.append(Thing(id: "pedestal", kind: "pedestal", pos: CGPoint(x: Self.vaultX, y: 600),
                                   footprint: CGSize(width: 90, height: 30), solid: true,
                                   prompt: "Take the golden stick", reach: CGSize(width: 130, height: 90)))
        engine.running = true
        engine.say(guesses == 0 ? "First try?! The vault swings open..." : "Click... clunk. The vault swings open!", seconds: 3)
        return true
    }

    func closeKeypad() {
        showKeypad = false
        engine.running = true
    }

    private func takeStick(_ i: Int) {
        guard !stickTaken else { return }
        stickTaken = true
        engine.things[i].prompt = nil
        Sound.magic.play()
        Sound.win.play()
        let fresh = claimStick()
        show(Popup(title: "THE GOLDEN STICK",
                   message: fresh ? "It's yours to keep, no rooftop needed.\nPress K in any level: it deletes every obstacle in the room, and Mom, Dad, strangers, guards and the rest, for the whole try. Once per try."
                                  : "You already own the golden stick. It glows a little brighter, as if it remembers you.",
                   symbol: "wand.and.stars", color: Palette.gold, button: "Menu", action: { [weak self] in self?.onExit() },
                   secondButton: "Stay a while", secondAction: {}))
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
        engine.running = true
    }

    /// No clues about the code. Not even from the Guide.
    func hint() {
        engine.say(vaultOpen ? (stickTaken ? "The vault is empty now. The door out is on the left." : "Take the golden stick from the pedestal!")
                             : "Ten letters and numbers. The Guide never writes the code down anywhere...", seconds: 3.5)
    }
}

// MARK: - View

struct RoomLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    @State private var model = RoomModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: "Side Level 6 · The Room", inventory: [],
                      popup: model.popup, banner: model.banner, belt: model.belt,
                      onHome: onExit, onRestart: model.reset, onHint: model.hint) {
            room.allowsHitTesting(false)
        } extra: {
            if model.showKeypad {
                KeypadView(hint: "Ten letters and numbers.", maxLength: 10, onSubmit: model.submitCode, onCancel: model.closeKeypad)
            }
        }
        .onAppear {
            model.onExit = onExit
            model.claimStick = {
                let fresh = !game.hasGoldenStick
                game.hasGoldenStick = true
                game.award(.goldenStick)
                game.finishSide(6)
                return fresh
            }
            model.belt.configure(game: game, engine: model.engine)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var room: some View {
        ZStack(alignment: .topLeading) {
            RoomWall(width: RoomModel.width)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                wallItem(thing).anchored(at: thing.pos)
            }
            if model.vaultOpen {
                // The light from inside the vault.
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.6), .clear], center: .center, startRadius: 10, endRadius: 240))
                    .frame(width: 480, height: 480)
                    .position(x: RoomModel.vaultX, y: 470)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { thing in
                if thing.kind == "pedestal" { PedestalView(hasStick: !model.stickTaken) }
            }
            Palette.shade.opacity(0.2 * Palette.shadeAmount)
        }
        .frame(width: RoomModel.width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private func wallItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "exitDoor": DoorView(color: Color(red: 0.30, green: 0.20, blue: 0.45)) { DoorSign(text: "EXIT", color: .white) }
        case "portrait": GuidePortraitView()
        case "vault": VaultDoorView(open: model.vaultOpen)
        default: EmptyView()
        }
    }
}

// MARK: - Art

/// Deep purple walls, the colour of the Guide's Hat, with little lanterns.
struct RoomWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.06, blue: 0.22), GuidesHat.color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            ForEach(0..<Int(width / 200), id: \.self) { i in
                Image(systemName: "hat.widebrim.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.06))
                    .position(x: CGFloat(i) * 200 + 100, y: i % 2 == 0 ? 160 : 290)
            }
            ForEach(0..<Int(width / 400), id: \.self) { i in
                ZStack {
                    Circle().fill(RadialGradient(colors: [.yellow.opacity(0.35), .clear], center: .center, startRadius: 2, endRadius: 90)).frame(width: 180)
                    RoundedRectangle(cornerRadius: 5).fill(Color.yellow).frame(width: 18, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(white: 0.25), lineWidth: 3))
                }
                .position(x: CGFloat(i) * 400 + 340, y: 90)
            }
            Rectangle().fill(Palette.gold.opacity(0.4)).frame(width: width, height: 6).offset(y: 530)
            LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.24), Color(red: 0.24, green: 0.16, blue: 0.32)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 155)
                .offset(y: 545)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// A painting of the Guide in a gold frame.
struct GuidePortraitView: View {
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Palette.gold).frame(width: 150, height: 190)
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.20, green: 0.14, blue: 0.30)).frame(width: 128, height: 168)
                GuideView().scaleEffect(0.95).frame(width: 120, height: 160).clipped()
            }
            Spacer()
        }
        .frame(width: 160, height: 330)
    }
}

/// A round vault door with a lock panel. Open, it swings aside to show the dark vault behind.
struct VaultDoorView: View {
    let open: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.12)).frame(width: 240, height: 300)
            if open {
                RoundedRectangle(cornerRadius: 12).fill(Color.black).frame(width: 200, height: 260)
                Circle().fill(Color(white: 0.45)).frame(width: 190).scaleEffect(x: 0.22, y: 1).offset(x: -130)
            } else {
                Circle().fill(Color(white: 0.55)).frame(width: 200)
                Circle().stroke(Color(white: 0.35), lineWidth: 10).frame(width: 170)
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Color(white: 0.35)).frame(width: 10, height: 70).offset(y: -35).rotationEffect(.degrees(Double(i) * 60))
                }
                Circle().fill(Palette.gold).frame(width: 40)
                // The lock panel: room for ten characters.
                RoundedRectangle(cornerRadius: 6).fill(.black).frame(width: 150, height: 30)
                    .overlay(Text("··········").font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundStyle(.green))
                    .offset(y: 120)
            }
        }
        .frame(width: 260, height: 320, alignment: .bottom)
    }
}

/// A stone pedestal. With the stick on it, it glows.
struct PedestalView: View {
    let hasStick: Bool
    @State private var glow = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.62)).frame(width: 90, height: 90)
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.72)).frame(width: 110, height: 16).offset(y: -84)
            if hasStick {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Palette.gold)
                    .shadow(color: .yellow, radius: glow ? 22 : 8)
                    .offset(y: glow ? -112 : -100)
            }
        }
        .frame(width: 120, height: 170, alignment: .bottom)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) { glow = true }
        }
    }
}
