import SwiftUI

/// A decorated speech bubble: cream paper, a coloured rim, little sparkles and a tail.
struct SpeechBubble: View {
    let text: String
    var tint: Color = Palette.gold
    /// Smaller text, for grown-ups muttering.
    var small = false

    var body: some View {
        VStack(spacing: -2) {
            Text(text)
                .font(.game(small ? 18 : 22, .semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.30))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: small ? 260 : 320)
                .background(
                    LinearGradient(colors: [.white, Color(red: 1.0, green: 0.95, blue: 0.84)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(tint, lineWidth: 3.5))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(tint.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])).padding(5))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "sparkle").font(.system(size: 15, weight: .bold)).foregroundStyle(tint).offset(x: -7, y: -8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "sparkle").font(.system(size: 11, weight: .bold)).foregroundStyle(tint).offset(x: 6, y: 6)
                }
            Triangle()
                .fill(Color(red: 1.0, green: 0.95, blue: 0.84))
                .overlay(Triangle().stroke(tint, lineWidth: 3).mask(Rectangle().padding(.top, -6).offset(y: 5)))
                .frame(width: 22, height: 14)
                .rotationEffect(.degrees(180))
        }
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Health for levels with strangers (Level 5 on).
struct HealthBar: View {
    let hp: Double
    let max: Double

    var body: some View {
        let part = Swift.max(0, min(1, hp / Swift.max(max, 1)))
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.red)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(part > 0.5 ? Color.green : part > 0.25 ? Color.orange : Color.red)
                    .frame(width: 120 * part)
            }
            .frame(width: 120, height: 14)
            Text("\(Int(hp.rounded(.up)))")
                .font(.game(16, .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
        .animation(.easeOut(duration: 0.25), value: hp)
    }
}

/// The Guide: he turns up in practice mode to help you through a level.
struct GuideView: View {
    static let look = Look(gender: .boy, skin: 2, shirt: 7, pattern: 3, cap: 0,
                           accessory: Accessory(id: "guide-hat", family: .topHat, name: "Guide's Hat", color: GuidesHat.color))
    var walking = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CharacterView(look: Self.look, facingRight: true, walking: walking)
            // His lantern
            VStack(spacing: 0) {
                Rectangle().fill(Color(white: 0.3)).frame(width: 3, height: 14)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.yellow)
                    .frame(width: 18, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(white: 0.25), lineWidth: 3))
                    .shadow(color: .yellow, radius: 10)
            }
            .offset(x: 14, y: -34)
        }
        .frame(width: 100, height: 160)
    }
}

/// Practice mode: the Guide himself, walking in the room ahead of you. "Follow me!"
struct GuideWalker: View {
    let engine: GameEngine

    var body: some View {
        if let spot = engine.guidePos {
            GuideView(walking: engine.guideWalking)
                .scaleEffect(x: engine.guideFacingRight ? 0.92 : -0.92, y: 0.92, anchor: .bottom)
                .opacity(0.92)
                .anchored(at: spot)
            if let text = engine.guideSpeech {
                SpeechBubble(text: text, tint: GuidesHat.color, small: true)
                    .position(x: spot.x, y: spot.y - 215)
            }
        }
    }
}

/// Practice mode: the Guide's portrait with the tip he's giving. Tap him for the next one.
struct GuideCard: View {
    let tips: [String]
    let onHint: () -> Void
    @State private var index = 0

    private static let general = [
        "I'm the Guide! While practice mode is on, nobody can catch you.",
        "Crouch to touch chairs and lamps safely.",
        "The lightbulb at the top tells you what to do next.",
        "Search boxes more than once. Good things hide at the bottom.",
        "Ready for the real thing? Turn practice mode off in the pause menu.",
    ]

    var body: some View {
        let real = tips.isEmpty ? Self.general : [Self.general[0]] + tips + [Self.general[4]]
        // No Mercy: every third thing he says is wrong.
        let wrong = Difficulty.current == .noMercy && index % 3 == 2
        let all = wrong ? GuideTips.mistakes : real
        Button {
            SoundPlayer.shared.tap()
            index += 1
            onHint()
        } label: {
            HStack(alignment: .center, spacing: 4) {
                GuideView()
                    .scaleEffect(0.42)
                    .frame(width: 46, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wrong ? "GUIDE  ·  hmm..." : "GUIDE  ·  tip \(index % real.count + 1) of \(real.count)  ·  tap for the next")
                        .font(.game(11, .heavy))
                        .foregroundStyle(Color(red: 0.45, green: 0.25, blue: 0.75))
                    Text(all[index % all.count])
                        .font(.game(15, .semibold))
                        .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.30))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 330, alignment: .leading)
                .background(LinearGradient(colors: [.white, Color(red: 0.93, green: 0.90, blue: 1.0)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.55, green: 0.35, blue: 0.85), lineWidth: 3))
            }
        }
        .buttonStyle(PressableStyle())
        .task {
            // A new tip every 12 seconds.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                index += 1
            }
        }
    }
}

/// The pause menu: a small settings screen you can open in the middle of a level.
struct PauseOverlay: View {
    let engine: GameEngine
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void
    @Bindable private var settings = Settings.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill").foregroundStyle(Palette.gold)
                    Text("Paused")
                }
                .font(.game(46, .heavy))
                .foregroundStyle(.white)

                // Practice mode
                HStack(spacing: 12) {
                    GuideView().scaleEffect(0.5).frame(width: 54, height: 80)
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Practice mode", isOn: $settings.practice)
                            .font(.game(24))
                            .tint(Palette.button)
                        Text("The Guide helps you through the level, and Mom and Dad can't catch you. Turn it off when you're ready.")
                            .font(.game(15, .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 8) {
                    slider("Master volume", "speaker.wave.3.fill", $settings.master)
                    slider("Music", "music.note", $settings.music)
                    slider("Sound effects", "bell.fill", $settings.effects)
                    HStack(spacing: 8) {
                        Text("Button size").frame(width: 170, alignment: .leading)
                        ForEach(0..<3, id: \.self) { i in
                            choice(["Small", "Normal", "Big"][i], on: settings.controlSize == i) { settings.controlSize = i }
                        }
                        Spacer()
                        choice(settings.swapSides ? "Joystick: right" : "Joystick: left", on: false) { settings.swapSides.toggle() }
                    }
                    .font(.game(18, .semibold))
                    .foregroundStyle(.white)
                }
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 14) {
                    bottomButton("Menu", "house.fill", .gray, onHome)
                    bottomButton("Restart", "arrow.counterclockwise", Color(red: 0.35, green: 0.30, blue: 0.70), onRestart)
                    bottomButton("Resume", "play.fill", Palette.button, onResume)
                }
            }
            .padding(28)
            .frame(width: 640)
            .background(
                LinearGradient(colors: [Color(red: 0.25, green: 0.18, blue: 0.48), Color(red: 0.12, green: 0.10, blue: 0.30)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 36)
            )
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
        }
        .transition(.opacity)
    }

    private func bottomButton(_ title: String, _ symbol: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.game(24))
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background(color.gradient, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
    }

    private func slider(_ title: String, _ symbol: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 28)
            Text(title).frame(width: 140, alignment: .leading)
            Slider(value: value, in: 0...1).tint(Palette.button)
            Text("\(Int((value.wrappedValue * 100).rounded()))%").frame(width: 54, alignment: .trailing)
        }
        .font(.game(18, .semibold))
        .foregroundStyle(.white)
    }

    private func choice(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Text(title)
                .font(.game(16))
                .foregroundStyle(on ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(on ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.14)), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Little lights drifting through every room: fireflies at night, dust in the sunshine.
struct AmbientLayer: View {
    private let dots: [(x: CGFloat, y: CGFloat, r: CGFloat, phase: Double, speed: Double)] = {
        var rng = SeededRandom(seed: 21)
        return (0..<16).map { _ in (rng.next(), rng.next(), 1.5 + rng.next() * 2.5, Double(rng.next()) * 6.28, 0.3 + Double(rng.next()) * 0.5) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let sunny = Settings.shared.sky == .day || Settings.shared.sky == .dawn
            Canvas { gc, size in
                for d in dots {
                    let x = (d.x + CGFloat(sin(t * d.speed * 0.25 + d.phase)) * 0.06) * size.width
                    let drift = CGFloat((t * d.speed * 0.02 + d.phase).truncatingRemainder(dividingBy: 1))
                    let y = (1 - (d.y + drift).truncatingRemainder(dividingBy: 1)) * size.height
                    let glow = 0.25 + 0.75 * abs(sin(t * d.speed * 1.6 + d.phase))
                    let color = sunny ? Color.white.opacity(0.35 * glow) : Color(red: 1, green: 0.95, blue: 0.5).opacity(0.75 * glow)
                    let rect = CGRect(x: x - d.r, y: y - d.r, width: d.r * 2, height: d.r * 2)
                    if !sunny {
                        gc.fill(Path(ellipseIn: rect.insetBy(dx: -d.r * 1.6, dy: -d.r * 1.6)), with: .color(color.opacity(0.18)))
                    }
                    gc.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

/// A burst of paper bits falling down the screen.
struct ConfettiView: View {
    @State private var fall = false
    private let bits: [(x: CGFloat, delay: Double, color: Color, spin: Double, size: CGFloat)] = {
        let colors: [Color] = [.red, .yellow, .green, .cyan, .pink, .orange, .purple]
        return (0..<70).map { i in
            (CGFloat.random(in: 0...1), Double.random(in: 0...0.6), colors[i % colors.count], Double.random(in: 180...900), CGFloat.random(in: 8...16))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(bits.indices, id: \.self) { i in
                let bit = bits[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(bit.color)
                    .frame(width: bit.size, height: bit.size * 0.6)
                    .rotationEffect(.degrees(fall ? bit.spin : 0))
                    .position(x: bit.x * geo.size.width, y: fall ? geo.size.height + 40 : -40)
                    .animation(.easeIn(duration: 2.4).delay(bit.delay), value: fall)
            }
        }
        .onAppear { fall = true }
    }
}

/// Worn only while creative mode is on: a rainbow crown.
struct CreativeCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [.red, .orange, .yellow, .green, .cyan, .purple], startPoint: .leading, endPoint: .trailing))
            .shadow(color: .white, radius: 8)
    }
}

/// The cloud you ride while flying.
struct FlyingCloud: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.white).frame(width: 110, height: 34)
            Circle().fill(.white).frame(width: 46).offset(x: -26, y: -12)
            Circle().fill(.white).frame(width: 56).offset(x: 6, y: -18)
            Circle().fill(.white).frame(width: 40).offset(x: 36, y: -8)
        }
        .shadow(color: Color(red: 0.6, green: 0.8, blue: 1), radius: 10)
        .opacity(0.95)
    }
}

/// Player 2 in multiplayer mode.
struct PlayerTwoSprite: View {
    @Environment(GameState.self) private var game
    let engine: GameEngine

    var body: some View {
        // Player 2's own look, from Multiplayer → Customize player 2.
        let look = game.player2Look
        ZStack(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.3)).frame(width: 64, height: 15).offset(y: 6)
            VStack(spacing: 2) {
                Text(game.player2Name.isEmpty ? "P2" : game.player2Name)
                    .font(.game(16, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.85), in: Capsule())
                CharacterView(look: look, facingRight: engine.facing2Right, walking: engine.walking2)
            }
            .scaleEffect(0.95, anchor: .bottom)
        }
        .frame(width: 130, height: 195, alignment: .bottom)
    }
}
