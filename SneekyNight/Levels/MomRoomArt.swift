import SwiftUI

// Drawings for Mom's room, Dad, and the view out of the hallway window.
// Each room view's bottom edge is the spot where it stands on the floor.

struct MomRoomWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.32, green: 0.18, blue: 0.26), Color(red: 0.44, green: 0.26, blue: 0.34)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 450)
            ForEach(0..<32, id: \.self) { i in
                FlowerView()
                    .opacity(0.08)
                    .position(x: CGFloat(i % 8) * 200 + (i / 8 % 2 == 0 ? 60 : 160), y: CGFloat(i / 8) * 105 + 50)
            }
            // Family photo
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Palette.gold.opacity(0.85)).frame(width: 150, height: 110)
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.6, green: 0.8, blue: 0.9)).frame(width: 130, height: 90)
                // The family: Dad, kid, Mom
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach([(46.0, Color.blue), (30.0, Color.orange), (42.0, Color.pink)], id: \.0) { height, color in
                        VStack(spacing: 1) {
                            Circle().fill(Color(red: 0.96, green: 0.80, blue: 0.66)).frame(width: 16)
                            RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 20, height: height - 16)
                        }
                    }
                }
                .offset(y: 8)
            }
            .offset(x: 1100, y: 190)
            Rectangle().fill(Color(red: 0.36, green: 0.22, blue: 0.14)).frame(width: width, height: 16).offset(y: 442)
            LinearGradient(colors: [Color(red: 0.42, green: 0.30, blue: 0.24), Color(red: 0.52, green: 0.38, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(red: 0.70, green: 0.55, blue: 0.62))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.35), lineWidth: 4).padding(12))
                .frame(width: 700, height: 130)
                .offset(x: 800, y: 560)
        }
    }
}

struct VanityView: View {
    let open: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Mirror
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.7), Color.cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Ellipse().stroke(Palette.gold, lineWidth: 6))
                .frame(width: 100, height: 120)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.95, green: 0.90, blue: 0.85)).frame(width: 170, height: 110)
                // Jewelry box on top
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.pink).frame(width: 46, height: 24).offset(y: 10)
                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.85, green: 0.3, blue: 0.5)).frame(width: 50, height: 10)
                        .rotationEffect(.degrees(open ? -60 : 0), anchor: .leading)
                    if !open {
                        Image(systemName: "sparkle").font(.system(size: 14)).foregroundStyle(.yellow).offset(x: 28, y: -10)
                    }
                }
                .offset(y: -30)
                HStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        ZStack {
                            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.88, green: 0.80, blue: 0.74))
                            Circle().fill(Palette.gold).frame(width: 8)
                        }
                        .frame(width: 70, height: 36)
                    }
                }
                .offset(y: 40)
            }
            .frame(height: 110)
            .padding(.top, 30)
        }
        .animation(.spring(duration: 0.4), value: open)
    }
}

struct MomBedView: View {
    /// True while Mom is up and searching.
    let empty: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.45, green: 0.28, blue: 0.20)).frame(width: 40, height: 200)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.28, blue: 0.20)).frame(width: 340, height: 40).offset(x: 20, y: -10)
            // Dark gap under the bed
            Rectangle().fill(.black.opacity(0.55)).frame(width: 300, height: 26).offset(x: 40, y: 0)
            RoundedRectangle(cornerRadius: 10).fill(.white).frame(width: 320, height: 34).offset(x: 34, y: -46)
            Capsule().fill(Color(red: 0.95, green: 0.9, blue: 0.95)).frame(width: 90, height: 34).offset(x: 46, y: -74)
            if !empty {
                Circle().fill(Color(red: 0.96, green: 0.80, blue: 0.66)).frame(width: 48).offset(x: 66, y: -84)
                Circle().trim(from: 0.5, to: 1).fill(Color(red: 0.45, green: 0.28, blue: 0.15)).frame(width: 54).offset(x: 63, y: -88)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in Capsule().fill(Color.cyan).frame(width: 10, height: 15) }
                }
                .offset(x: 68, y: -126)
                Capsule().fill(.black.opacity(0.6)).frame(width: 12, height: 3).offset(x: 90, y: -110)
                Text("z Z z").font(.game(24, .heavy)).foregroundStyle(.white.opacity(0.7)).offset(x: 100, y: -150)
            }
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.45, blue: 0.55), Color(red: 0.65, green: 0.30, blue: 0.45)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 240, height: 70)
                .offset(x: 118, y: -40)
        }
        .frame(width: 380, height: 210, alignment: .bottomLeading)
    }
}

struct AlarmNightstandView: View {
    let turnedBack: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.15)).frame(width: 64, height: 34)
                Text(turnedBack ? "1:30" : "2:00")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .shadow(color: .red, radius: 4)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.55, green: 0.36, blue: 0.24)).frame(width: 90, height: 84)
                Capsule().fill(Palette.gold).frame(width: 22, height: 6).offset(y: -16)
            }
        }
    }
}

struct DadDeskView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.36, green: 0.22, blue: 0.14)).frame(width: 10, height: 80).offset(x: -40)
            Rectangle().fill(Color(red: 0.36, green: 0.22, blue: 0.14)).frame(width: 10, height: 80).offset(x: 40)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.50, green: 0.32, blue: 0.20)).frame(width: 110, height: 14).offset(y: -80)
            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.9)).frame(width: 40, height: 6).rotationEffect(.degrees(-4)).offset(x: -22, y: -96)
            RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 18, height: 20).offset(x: 26, y: -94)
        }
        .frame(width: 120, height: 120, alignment: .bottom)
    }
}

struct ShoesView: View {
    var body: some View {
        HStack(spacing: 4) {
            shoe
            shoe.offset(y: 4)
        }
        .frame(width: 70, height: 30)
    }

    private var shoe: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule().fill(Color(red: 0.25, green: 0.18, blue: 0.14)).frame(width: 32, height: 14)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.25, green: 0.18, blue: 0.14)).frame(width: 14, height: 20)
        }
    }
}

struct LaundryBasketView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Clothes spilling over the top
            HStack(spacing: -6) {
                Capsule().fill(Color.blue.opacity(0.8)).frame(width: 30, height: 16)
                Capsule().fill(Color.red.opacity(0.8)).frame(width: 26, height: 18)
                Capsule().fill(Color.yellow.opacity(0.9)).frame(width: 24, height: 14)
            }
            .offset(y: -40)
            Trapezoid()
                .fill(Color(red: 0.85, green: 0.75, blue: 0.55))
                .rotationEffect(.degrees(180))
                .frame(width: 70, height: 48)
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(.black.opacity(0.15)).frame(width: 60, height: 3)
                }
            }
            .offset(y: -12)
        }
        .frame(width: 80, height: 70)
    }
}

struct DadView: View {
    /// Tangled in vines: stars circle his head.
    var stunned = false
    var walking = false
    /// You taunted him and he thought it was funny.
    var laughing = false

    private let pajamas = Color(red: 0.35, green: 0.45, blue: 0.70)
    private let skin = Color(red: 0.94, green: 0.76, blue: 0.62)

    var body: some View {
        // Never quite still: standing, he breathes and sways a little.
        TimelineView(.animation(minimumInterval: walking || laughing ? nil : 1 / 24)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            figure(swing: walking ? sin(t * 9) : sin(t * 1.6) * 0.12, shake: laughing ? sin(t * 26) * 3 : sin(t * 1.6 + 1) * 1.2)
        }
        .frame(width: 150, height: 280)
    }

    private func arm(_ angle: Double) -> some View {
        VStack(spacing: -4) {
            Capsule().fill(pajamas).brightness(-0.06).frame(width: 19, height: 66)
            Circle().fill(skin).frame(width: 19, height: 19)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    private func figure(swing: Double, shake: Double) -> some View {
        ZStack {
            arm(16 + swing * 22).offset(x: -48, y: 26)
            // Striped pajamas
            RoundedRectangle(cornerRadius: 22).fill(pajamas).frame(width: 88, height: 160).offset(y: 44)
            VStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in Rectangle().fill(.white.opacity(0.35)).frame(width: 88, height: 6) }
            }
            .offset(y: 44)
            HStack(spacing: 18) {
                Capsule().fill(Color(red: 0.4, green: 0.25, blue: 0.15)).frame(width: 32, height: 14).offset(y: swing * 4)
                Capsule().fill(Color(red: 0.4, green: 0.25, blue: 0.15)).frame(width: 32, height: 14).offset(y: -swing * 4)
            }
            .offset(y: 126)
            // The other arm is bent, holding a mug of cocoa
            arm(-50).offset(x: 46, y: 22)
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 22, height: 26)
                Circle().stroke(.white, lineWidth: 4).frame(width: 14).offset(x: 12)
            }
            .offset(x: 82, y: 22)
            Circle().fill(skin).frame(width: 19).offset(x: 72, y: 34)
            // Head
            Group {
                Circle().fill(skin).frame(width: 64).offset(y: -66)
                Circle().trim(from: 0.55, to: 0.95).fill(Color(red: 0.25, green: 0.18, blue: 0.12)).frame(width: 66).offset(y: -70)
                HStack(spacing: 6) {
                    Circle().stroke(.black, lineWidth: 3).frame(width: 20)
                    Circle().stroke(.black, lineWidth: 3).frame(width: 20)
                }
                .offset(y: -68)
                HStack(spacing: 18) {
                    BlinkingEye(size: 6, phase: 2.4)
                    BlinkingEye(size: 6, phase: 2.4)
                }
                .offset(y: -68)
                Capsule().fill(Color(red: 0.25, green: 0.18, blue: 0.12)).frame(width: 30, height: 8).offset(y: -50)
            }
            .offset(y: shake)
            if stunned {
                StunStars().offset(y: -116)
                Image(systemName: "leaf.fill").font(.system(size: 30)).foregroundStyle(.green).offset(y: 30)
            } else {
                Text(laughing ? "Ha ha!" : "Hmm?").font(.game(28, .heavy)).foregroundStyle(.yellow).offset(x: 62, y: -118)
            }
        }
    }
}

/// Peeking out of the opened hallway window. Just for fun — something silly each time.
struct WindowViewOverlay: View {
    static let sceneCount = 5
    let scene: Int
    let onClose: () -> Void
    @State private var go = false

    private var caption: String {
        switch scene {
        case 0: "A cat is dancing on the fence!"
        case 1: "Was that... a UFO?!"
        case 2: "An owl winked at you. Hoo hoo!"
        case 3: "The neighbor is sleepwalking with his teddy bear!"
        default: "A shooting star! Make a wish!"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    outside
                    // Window frame
                    RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.36, green: 0.22, blue: 0.14), lineWidth: 22)
                    Rectangle().fill(Color(red: 0.36, green: 0.22, blue: 0.14)).frame(width: 14)
                }
                .frame(width: 700, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(caption)
                    .font(.game(34, .heavy))
                    .foregroundStyle(.white)
                BigButton(title: "Close the window", symbol: "xmark", action: onClose)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) { go = true }
        }
    }

    private var outside: some View {
        ZStack {
            LinearGradient(colors: [Palette.skyTop, Color(red: 0.20, green: 0.18, blue: 0.45)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<30, id: \.self) { i in
                Circle().fill(.white.opacity(0.8)).frame(width: CGFloat(2 + i % 3))
                    .position(x: CGFloat((i * 97) % 700), y: CGFloat((i * 53) % 200))
            }
            Circle().fill(Palette.moon).frame(width: 70).shadow(color: Palette.moon, radius: 20).position(x: 580, y: 80)
            // Neighbors' houses and the tree
            HStack(alignment: .bottom, spacing: 30) {
                house(lit: false).frame(width: 160, height: 150)
                house(lit: true).frame(width: 190, height: 180)
                house(lit: false).frame(width: 150, height: 140)
            }
            .position(x: 330, y: 290)
            Rectangle().fill(Color(red: 0.08, green: 0.20, blue: 0.14)).frame(width: 700, height: 80).position(x: 350, y: 390)
            // Fence
            HStack(spacing: 10) {
                ForEach(0..<20, id: \.self) { _ in Rectangle().fill(Color(red: 0.75, green: 0.70, blue: 0.62)).frame(width: 24, height: 60) }
            }
            .position(x: 350, y: 360)
            sceneEvent
        }
    }

    @ViewBuilder private var sceneEvent: some View {
        switch scene {
        case 0:
            Image(systemName: "cat.fill")
                .font(.system(size: 60))
                .foregroundStyle(.black)
                .rotationEffect(.degrees(go ? 15 : -15))
                .offset(y: go ? -12 : 0)
                .position(x: 300, y: 300)
            Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(.yellow)
                .position(x: go ? 360 : 340, y: go ? 230 : 250)
        case 1:
            ZStack {
                Ellipse().fill(Color.gray).frame(width: 110, height: 30)
                Ellipse().fill(Color.cyan.opacity(0.7)).frame(width: 50, height: 34).offset(y: -16)
                HStack(spacing: 16) { ForEach(0..<3, id: \.self) { _ in Circle().fill(.yellow).frame(width: 8) } }.offset(y: 4)
            }
            .position(x: go ? 600 : 100, y: go ? 120 : 170)
        case 2:
            ZStack {
                Ellipse().fill(Color(red: 0.55, green: 0.40, blue: 0.25)).frame(width: 70, height: 90)
                HStack(spacing: 8) {
                    Circle().fill(.yellow).frame(width: 22).overlay(Circle().fill(.black).frame(width: 9))
                    Capsule().fill(.yellow).frame(width: 22, height: go ? 4 : 22)
                }
                .offset(y: -16)
                Triangle().fill(.orange).frame(width: 12, height: 10).rotationEffect(.degrees(180)).offset(y: 2)
            }
            .position(x: 140, y: 290)
        case 3:
            VStack(spacing: 0) {
                Circle().fill(Color(red: 0.94, green: 0.78, blue: 0.64)).frame(width: 34)
                RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.8)).frame(width: 40, height: 60)
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "teddybear.fill").font(.system(size: 26)).foregroundStyle(.brown).offset(x: 18, y: 10)
            }
            .overlay(alignment: .top) { Text("zzz").font(.game(18, .heavy)).foregroundStyle(.white).offset(y: -24) }
            .position(x: go ? 520 : 180, y: 400)
        default:
            Image(systemName: "sparkle")
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .shadow(color: .white, radius: 10)
                .position(x: go ? 120 : 620, y: go ? 180 : 40)
        }
    }

    private func house(lit: Bool) -> some View {
        VStack(spacing: 0) {
            Triangle().fill(Color(red: 0.18, green: 0.12, blue: 0.22))
                .frame(height: 50)
            ZStack {
                Rectangle().fill(Color(red: 0.14, green: 0.12, blue: 0.24))
                Rectangle().fill(lit ? Color(red: 1, green: 0.85, blue: 0.45) : Color(red: 0.08, green: 0.08, blue: 0.16))
                    .frame(width: 34, height: 30)
            }
        }
    }
}
