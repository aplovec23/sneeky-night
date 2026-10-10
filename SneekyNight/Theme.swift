import SwiftUI

extension Font {
    static func game(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum Palette {
    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    // The whole game is tinted by the sky: night, sunrise, day or sunset (Settings, or the real clock).
    static var skyTop: Color {
        switch Settings.shared.sky {
        case .night: rgb(0.05, 0.06, 0.20)
        case .dawn: rgb(0.35, 0.50, 0.80)
        case .day: rgb(0.25, 0.58, 0.95)
        case .dusk: rgb(0.22, 0.18, 0.48)
        }
    }
    static var skyBottom: Color {
        switch Settings.shared.sky {
        case .night: rgb(0.22, 0.13, 0.40)
        case .dawn: rgb(0.98, 0.65, 0.45)
        case .day: rgb(0.66, 0.86, 1.0)
        case .dusk: rgb(0.95, 0.48, 0.36)
        }
    }
    /// The moon — or the sun when it's up.
    static var moon: Color {
        switch Settings.shared.sky {
        case .night: rgb(1.0, 0.95, 0.75)
        case .dawn: rgb(1.0, 0.85, 0.35)
        case .day: rgb(1.0, 0.93, 0.45)
        case .dusk: rgb(1.0, 0.62, 0.30)
        }
    }
    /// The wash of colour over every room, and how strong it is (rooms are brighter when the sun is up).
    static var shade: Color {
        switch Settings.shared.sky {
        case .night: rgb(0.02, 0.02, 0.12)
        case .dawn: rgb(1.0, 0.75, 0.45)
        case .day: rgb(1.0, 0.97, 0.80)
        case .dusk: rgb(0.55, 0.20, 0.25)
        }
    }
    static var shadeAmount: Double {
        switch Settings.shared.sky {
        case .night: 1
        case .dawn: 0.3
        case .day: 0.12
        case .dusk: 0.5
        }
    }
    /// How bright the stars are.
    static var starlight: Double {
        switch Settings.shared.sky {
        case .night: 1
        case .dawn: 0.25
        case .day: 0
        case .dusk: 0.45
        }
    }
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let silver = Color(red: 0.80, green: 0.84, blue: 0.90)
    static let button = Color(red: 0.98, green: 0.62, blue: 0.20)
}

/// Starry night background used on the menu screens.
struct NightSky: View {
    private let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, phase: Double)] = {
        var rng = SeededRandom(seed: 7)
        return (0..<90).map { _ in
            (rng.next(), rng.next() * 0.8, 1 + rng.next() * 2.5, Double(rng.next()) * 6)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for s in stars {
                    let a = (0.45 + 0.55 * abs(sin(t * 0.8 + s.phase))) * Palette.starlight
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.r * 2, height: s.r * 2)
                    gc.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
                }
                // A shooting star every 7 seconds or so.
                let cycle = t.truncatingRemainder(dividingBy: 7)
                if cycle < 0.9 && Palette.starlight > 0.3 {
                    let n = floor(t / 7)
                    let startX = CGFloat((n * 0.37).truncatingRemainder(dividingBy: 0.6) + 0.1) * size.width
                    let startY = CGFloat((n * 0.23).truncatingRemainder(dividingBy: 0.3) + 0.05) * size.height
                    let head = CGPoint(x: startX + CGFloat(cycle) * 380, y: startY + CGFloat(cycle) * 150)
                    var trail = Path()
                    trail.move(to: head)
                    trail.addLine(to: CGPoint(x: head.x - 90, y: head.y - 36))
                    gc.stroke(trail, with: .linearGradient(Gradient(colors: [.white.opacity(0.9 * (1 - cycle)), .clear]),
                                                           startPoint: head, endPoint: CGPoint(x: head.x - 90, y: head.y - 36)), lineWidth: 2.5)
                }
            }
        }
        .background(LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

/// Buttons shrink a little while pressed; menu buttons also click.
struct PressableStyle: ButtonStyle {
    var haptic = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic && Settings.shared.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }
    }
}

struct BigButton: View {
    let title: String
    var symbol: String? = nil
    var color: Color = Palette.button
    let action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.game(30))
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .top, endPoint: .bottom), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 2))
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.22)).frame(height: 10).padding(.horizontal, 22).padding(.top, 5)
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        }
        .buttonStyle(PressableStyle())
    }
}

struct RoundIconButton: View {
    let symbol: String
    /// The keyboard key that does the same thing, shown as a small letter (when key letters are on).
    var key: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.game(26))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(RadialGradient(colors: [Color(red: 0.30, green: 0.24, blue: 0.55).opacity(0.85), .black.opacity(0.6)],
                                           center: .top, startRadius: 2, endRadius: 60), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.5), lineWidth: 2))
                .overlay(alignment: .bottomTrailing) {
                    if let key, Settings.shared.keyLabels {
                        Text(key)
                            .font(.game(13, .heavy))
                            .foregroundStyle(.black)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(.white, in: Capsule())
                            .offset(x: 4, y: 4)
                    }
                }
        }
        .buttonStyle(PressableStyle())
    }
}

enum Device {
    /// The game was designed for the iPad; on an iPhone the layouts below shrink things to fit.
    static let isPhone = UIDevice.current.userInterfaceIdiom == .phone
}

/// On an iPhone, draws its content as if the screen were 820 points tall (like the iPad) and
/// shrinks it to fit, keeping clear of the notch. On an iPad it does nothing.
struct FitToPhone<Content: View>: View {
    var night = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if Device.isPhone {
            GeometryReader { geo in
                let scale = geo.size.height / 820
                let inset: CGFloat = 54
                ZStack {
                    if night { NightSky() }
                    content()
                        .frame(width: (geo.size.width - inset * 2) / scale, height: 820)
                        .scaleEffect(scale)
                        .frame(width: geo.size.width - inset * 2, height: geo.size.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
        } else {
            content()
        }
    }
}
