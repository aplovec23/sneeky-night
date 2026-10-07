import SwiftUI

// Art for Level 5 (the street, the kitchen, Uncle's hotel) and the dungeon. All drawn from shapes.

/// A grown-up you don't know: strangers on the street, hotel guards and workers, and Uncle.
/// The frame is 140×250 with the feet at the bottom; they face right.
struct PersonView: View {
    enum Outfit: Equatable { case stranger(Int), guardian, worker(Int), uncle }

    let outfit: Outfit
    var walking = false

    private var coat: Color {
        switch outfit {
        case .stranger(let i): [Color(white: 0.32), Color(red: 0.22, green: 0.35, blue: 0.25), Color(red: 0.45, green: 0.18, blue: 0.22),
                                Color(red: 0.18, green: 0.22, blue: 0.42)][abs(i) % 4]
        case .guardian: Color(red: 0.12, green: 0.16, blue: 0.32)
        case .worker(let i): i % 2 == 0 ? Color(red: 0.62, green: 0.14, blue: 0.20) : Color(red: 0.85, green: 0.85, blue: 0.90)
        case .uncle: Color(red: 0.35, green: 0.28, blue: 0.22)
        }
    }
    private var skin: Color {
        switch outfit {
        case .stranger(let i): LookOptions.skins[abs(i * 2 + 1) % LookOptions.skins.count]
        case .guardian: LookOptions.skins[3]
        case .worker(let i): LookOptions.skins[abs(i + 1) % LookOptions.skins.count]
        case .uncle: LookOptions.skins[1]
        }
    }

    var body: some View {
        TimelineView(.animation(paused: !walking)) { ctx in
            figure(swing: walking ? sin(ctx.date.timeIntervalSinceReferenceDate * 8) : 0)
        }
        .frame(width: 140, height: 250)
    }

    private func figure(swing: Double) -> some View {
        ZStack {
            // Legs
            Capsule().fill(Color(white: 0.16)).frame(width: 22, height: 82)
                .rotationEffect(.degrees(swing * 20), anchor: .top).position(x: 60, y: 205)
            Capsule().fill(Color(white: 0.20)).frame(width: 22, height: 82)
                .rotationEffect(.degrees(-swing * 20), anchor: .top).position(x: 80, y: 205)
            // Back arm, body, front arm
            arm.rotationEffect(.degrees(-swing * 22), anchor: .top).position(x: 64, y: 132)
            RoundedRectangle(cornerRadius: 22).fill(coat).frame(width: 74, height: 104).position(x: 70, y: 128)
            extras
            arm.rotationEffect(.degrees(frontArmAngle(swing)), anchor: .top).position(x: 78, y: 132)
            // Head
            Circle().fill(skin).frame(width: 60, height: 60).position(x: 72, y: 52)
            hat
            face
        }
    }

    private func frontArmAngle(_ swing: Double) -> Double {
        // Guards hold a flashlight out in front; workers hold a mop.
        switch outfit {
        case .guardian: -62
        case .worker: -35
        default: swing * 22
        }
    }

    private var arm: some View {
        VStack(spacing: -4) {
            Capsule().fill(coat).brightness(-0.08).frame(width: 20, height: 62)
            Circle().fill(skin).frame(width: 18, height: 18)
        }
    }

    @ViewBuilder private var extras: some View {
        switch outfit {
        case .guardian:
            // Belt, badge and the flashlight's beam
            Rectangle().fill(Color(white: 0.1)).frame(width: 74, height: 8).position(x: 70, y: 150)
            Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(Palette.gold).position(x: 86, y: 104)
            Triangle().fill(LinearGradient(colors: [.yellow.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 110, height: 190).rotationEffect(.degrees(-78), anchor: .top).position(x: 128, y: 250)
        case .worker(let i):
            if i % 2 == 0 {
                // Bellhop: gold buttons
                ForEach(0..<3, id: \.self) { n in
                    Circle().fill(Palette.gold).frame(width: 7).position(x: 84, y: 100 + CGFloat(n) * 18)
                }
            } else {
                // Cleaner: apron and a mop
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.3, green: 0.55, blue: 0.75)).frame(width: 50, height: 70).position(x: 74, y: 142)
                Capsule().fill(Color(red: 0.6, green: 0.45, blue: 0.3)).frame(width: 6, height: 150).rotationEffect(.degrees(14)).position(x: 118, y: 170)
                Ellipse().fill(Color(white: 0.85)).frame(width: 40, height: 16).position(x: 100, y: 244)
            }
        case .uncle:
            // Shirt and tie
            Triangle().fill(.white).frame(width: 30, height: 34).rotationEffect(.degrees(180)).position(x: 78, y: 94)
            Capsule().fill(Color.red).frame(width: 9, height: 40).position(x: 78, y: 108)
        case .stranger:
            // Hands deep in a hoodie pocket
            RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.18)).frame(width: 46, height: 22).position(x: 74, y: 150)
        }
    }

    @ViewBuilder private var hat: some View {
        switch outfit {
        case .stranger:
            // A hood
            Circle().trim(from: 0.42, to: 1.0).fill(coat).brightness(-0.06).frame(width: 72, height: 72).position(x: 68, y: 50)
        case .guardian:
            Circle().trim(from: 0.5, to: 1).fill(coat).frame(width: 64, height: 60).position(x: 72, y: 46)
            Capsule().fill(Color(white: 0.08)).frame(width: 40, height: 9).position(x: 94, y: 44)
        case .worker(let i):
            if i % 2 == 0 {
                RoundedRectangle(cornerRadius: 4).fill(coat).frame(width: 44, height: 20).position(x: 72, y: 22)
            } else {
                Circle().trim(from: 0.5, to: 1).fill(Color(red: 0.3, green: 0.55, blue: 0.75)).frame(width: 62, height: 56).position(x: 72, y: 46)
            }
        case .uncle:
            Circle().trim(from: 0.5, to: 1).fill(Color(white: 0.55)).frame(width: 62, height: 58).position(x: 72, y: 48)
        }
    }

    @ViewBuilder private var face: some View {
        BlinkingEye(size: 7, phase: 1.7).position(x: 78, y: 52)
        BlinkingEye(size: 7, phase: 1.7).position(x: 92, y: 52)
        switch outfit {
        case .stranger:
            // Grumpy eyebrows
            Capsule().fill(.black.opacity(0.75)).frame(width: 12, height: 3).rotationEffect(.degrees(18)).position(x: 77, y: 44)
            Capsule().fill(.black.opacity(0.75)).frame(width: 12, height: 3).rotationEffect(.degrees(-18)).position(x: 93, y: 44)
            Capsule().fill(.black.opacity(0.6)).frame(width: 14, height: 3).position(x: 86, y: 67)
        case .uncle:
            // A big friendly moustache and glasses on his forehead
            Capsule().fill(Color(white: 0.45)).frame(width: 26, height: 8).position(x: 86, y: 65)
            Circle().stroke(Color(white: 0.2), lineWidth: 2).frame(width: 13).position(x: 76, y: 34)
            Circle().stroke(Color(white: 0.2), lineWidth: 2).frame(width: 13).position(x: 92, y: 34)
        default:
            Capsule().fill(.black.opacity(0.6)).frame(width: 12, height: 3).position(x: 86, y: 67)
        }
    }
}

struct RatView: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.85, green: 0.6, blue: 0.65)).frame(width: 40, height: 4).offset(x: -34, y: 6)
            Ellipse().fill(Color(white: 0.5)).frame(width: 50, height: 28)
            Circle().fill(Color(white: 0.55)).frame(width: 24).offset(x: 24, y: -4)
            Circle().fill(Color(red: 0.9, green: 0.65, blue: 0.7)).frame(width: 13).offset(x: 20, y: -16)
            Circle().fill(.black).frame(width: 4).offset(x: 29, y: -6)
            Circle().fill(Color(red: 0.9, green: 0.5, blue: 0.6)).frame(width: 5).offset(x: 36, y: -1)
        }
        .frame(width: 90, height: 40)
    }
}

/// The street at night: houses with a few lit windows, lamp posts, your house on the left and
/// Uncle's hotel at the far right.
struct StreetScene: View {
    let width: CGFloat

    private let houses: [(x: CGFloat, w: CGFloat, h: CGFloat, lit: Int, tone: Double)] = {
        var rng = SeededRandom(seed: 55)
        var list: [(CGFloat, CGFloat, CGFloat, Int, Double)] = []
        var x: CGFloat = 330
        while x < 4850 {
            let w = 200 + rng.next() * 160
            list.append((x, w, 200 + rng.next() * 170, Int(rng.next() * 4), Double(rng.next())))
            x += w + 24
        }
        return list
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 520)
            Circle().fill(Palette.moon).frame(width: 90).shadow(color: Palette.moon.opacity(0.7), radius: 30).position(x: 700, y: 150)
            ForEach(houses.indices, id: \.self) { i in
                house(houses[i])
            }
            // Your house
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color(red: 0.30, green: 0.24, blue: 0.42)).frame(width: 300, height: 330)
                Triangle().fill(Color(red: 0.40, green: 0.22, blue: 0.30)).frame(width: 340, height: 110).offset(y: -330)
                RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.85)).frame(width: 60, height: 54).offset(x: 80, y: -210)
            }
            .frame(width: 340, height: 440, alignment: .bottom)
            .position(x: 150, y: 310)
            // The hotel
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color(red: 0.42, green: 0.26, blue: 0.30)).frame(width: 640, height: 470)
                VStack(spacing: 26) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 34) {
                            ForEach(0..<6, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill((row + col) % 3 == 0 ? Color.yellow.opacity(0.85) : Color(red: 0.14, green: 0.12, blue: 0.24))
                                    .frame(width: 54, height: 62)
                            }
                        }
                    }
                }
                .offset(y: -150)
                Text("HOTEL")
                    .font(.game(54, .heavy))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 12)
                    .offset(y: -420)
                // Awning over the door
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.75, green: 0.15, blue: 0.2)).frame(width: 220, height: 30).offset(x: 20, y: -300)
            }
            .frame(width: 640, height: 520, alignment: .bottom)
            .position(x: width - 330, y: 260)
            // Pavement and road
            Rectangle().fill(Color(red: 0.36, green: 0.36, blue: 0.42)).frame(width: width, height: 190).offset(y: 510)
            Rectangle().fill(Color(red: 0.50, green: 0.50, blue: 0.56)).frame(width: width, height: 10).offset(y: 510)
            ForEach(0..<Int(width / 260), id: \.self) { i in
                Rectangle().fill(.white.opacity(0.12)).frame(width: 3, height: 190).offset(x: CGFloat(i) * 260 + 130, y: 520)
            }
            // Lamp posts
            ForEach(0..<Int(width / 620), id: \.self) { i in
                lamp.position(x: CGFloat(i) * 620 + 430, y: 372)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }

    private func house(_ h: (x: CGFloat, w: CGFloat, h: CGFloat, lit: Int, tone: Double)) -> some View {
        let wall = Color(red: 0.16 + h.tone * 0.10, green: 0.14 + h.tone * 0.06, blue: 0.28 + h.tone * 0.08)
        return ZStack(alignment: .bottom) {
            Rectangle().fill(wall).frame(width: h.w, height: h.h)
            Triangle().fill(wall).brightness(-0.05).frame(width: h.w + 30, height: 70).offset(y: -h.h)
            HStack(spacing: h.w / 5) {
                ForEach(0..<3, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(n == h.lit ? Color.yellow.opacity(0.8) : Color(red: 0.08, green: 0.07, blue: 0.16))
                        .frame(width: 36, height: 44)
                }
            }
            .offset(y: -h.h * 0.5)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.30, green: 0.20, blue: 0.16)).frame(width: 44, height: 78)
        }
        .frame(width: h.w + 30, height: h.h + 70, alignment: .bottom)
        .position(x: h.x + h.w / 2, y: 520 - (h.h + 70) / 2)
    }

    private var lamp: some View {
        ZStack(alignment: .top) {
            Circle().fill(RadialGradient(colors: [.yellow.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 150))
                .frame(width: 300, height: 300).offset(y: -130)
            Rectangle().fill(Color(white: 0.2)).frame(width: 8, height: 300)
            Capsule().fill(Color(white: 0.2)).frame(width: 50, height: 8).offset(x: 20)
            Circle().fill(Color.yellow).frame(width: 22).offset(x: 40, y: 2)
        }
        .frame(width: 60, height: 300, alignment: .top)
    }
}

struct BusStopView: View {
    let hiding: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.55, green: 0.80, blue: 0.95).opacity(0.35)).frame(width: 170, height: 220)
            RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.25), lineWidth: 6).frame(width: 170, height: 220)
            Rectangle().fill(Color(red: 0.2, green: 0.4, blue: 0.75)).frame(width: 190, height: 22).offset(y: -214)
            Rectangle().fill(Color(red: 0.5, green: 0.35, blue: 0.2)).frame(width: 130, height: 12).offset(y: -50)
            Image(systemName: "bus.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).offset(y: -214)
            if hiding {
                HStack(spacing: 12) {
                    Circle().fill(.white).frame(width: 12).overlay(Circle().fill(.black).frame(width: 6))
                    Circle().fill(.white).frame(width: 12).overlay(Circle().fill(.black).frame(width: 6))
                }
                .offset(y: -110)
            }
        }
        .frame(width: 190, height: 240, alignment: .bottom)
    }
}

/// The kitchen while Mom cooks: tiled wall, a long counter with the stove and the sink, a window.
struct KitchenWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.36, green: 0.42, blue: 0.48).frame(width: width, height: 545)
            ForEach(0..<Int(width / 60), id: \.self) { i in
                Rectangle().fill(.white.opacity(0.05)).frame(width: 2, height: 545).offset(x: CGFloat(i) * 60)
            }
            Rectangle().fill(Color(red: 0.55, green: 0.42, blue: 0.30)).frame(width: width, height: 155).offset(y: 545)
            // Window with the first light of morning
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom))
                .frame(width: 180, height: 130)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 8))
                .position(x: 800, y: 260)
            // Counter with stove and sink
            Rectangle().fill(Color(red: 0.85, green: 0.83, blue: 0.78)).frame(width: 560, height: 16).position(x: 800, y: 438)
            Rectangle().fill(Color(red: 0.40, green: 0.28, blue: 0.20)).frame(width: 540, height: 106).position(x: 800, y: 499)
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.2)).frame(width: 130, height: 100).position(x: 620, y: 496)
            HStack(spacing: 14) {
                Circle().stroke(.orange, lineWidth: 4).frame(width: 34)
                Circle().stroke(.orange, lineWidth: 4).frame(width: 34)
            }
            .position(x: 620, y: 426)
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.72)).frame(width: 120, height: 14).position(x: 980, y: 428)
            Capsule().fill(Color(white: 0.6)).frame(width: 8, height: 44).position(x: 980, y: 404)
            Text("Mom's kitchen").font(.game(20, .heavy)).foregroundStyle(.white.opacity(0.25)).position(x: 300, y: 200)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// Mom at the stove or the sink. With her back turned she can't see you.
struct CookingMomView: View {
    let backTurned: Bool
    let facingRight: Bool
    let walking: Bool

    var body: some View {
        ZStack(alignment: .top) {
            MomView(stunned: false, walking: walking)
                .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                .brightness(backTurned ? -0.12 : 0)
            if backTurned {
                // Steam from the pan, and a little tune
                Image(systemName: "music.note").font(.system(size: 22, weight: .bold)).foregroundStyle(.white.opacity(0.8)).offset(x: 44, y: -6)
                Image(systemName: "flame.fill").font(.system(size: 18)).foregroundStyle(.orange).offset(x: -36, y: 150)
            } else {
                Image(systemName: "eye.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.yellow).offset(x: facingRight ? 40 : -40, y: -10)
            }
        }
    }
}

struct LobbyWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.36, green: 0.16, blue: 0.20), Color(red: 0.48, green: 0.24, blue: 0.26)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            ForEach(0..<Int(width / 120), id: \.self) { i in
                Image(systemName: "sparkle").font(.system(size: 18)).foregroundStyle(Palette.gold.opacity(0.25))
                    .position(x: CGFloat(i) * 120 + 60, y: i % 2 == 0 ? 180 : 300)
            }
            Rectangle().fill(Palette.gold.opacity(0.5)).frame(width: width, height: 6).offset(y: 440)
            Rectangle().fill(Color(red: 0.30, green: 0.12, blue: 0.16)).frame(width: width, height: 100).offset(y: 446)
            // Carpet
            Rectangle().fill(Color(red: 0.22, green: 0.26, blue: 0.42)).frame(width: width, height: 155).offset(y: 545)
            Rectangle().fill(Palette.gold.opacity(0.35)).frame(width: width, height: 5).offset(y: 600)
            // Reception desk and a chandelier
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.42, green: 0.28, blue: 0.18)).frame(width: 360, height: 120).position(x: 1100, y: 486)
            Rectangle().fill(Palette.gold).frame(width: 380, height: 10).position(x: 1100, y: 424)
            Text("RECEPTION").font(.game(22, .heavy)).foregroundStyle(Palette.gold).position(x: 1100, y: 480)
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(RadialGradient(colors: [.yellow.opacity(0.5), .clear], center: .center, startRadius: 4, endRadius: 120))
                    .frame(width: 240).position(x: 500 + CGFloat(i) * 700, y: 120)
                Image(systemName: "light.cylindrical.ceiling.fill").font(.system(size: 60)).foregroundStyle(Palette.gold)
                    .position(x: 500 + CGFloat(i) * 700, y: 110)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// A big potted plant in the hotel lobby. You can hide behind it.
struct LobbyPlantView: View {
    let hiding: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { i in
                Ellipse().fill(Color(red: 0.16, green: 0.50 + Double(i % 3) * 0.06, blue: 0.26))
                    .frame(width: 46, height: 150)
                    .rotationEffect(.degrees(Double(i - 3) * 20), anchor: .bottom)
                    .offset(y: -70)
            }
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.70, green: 0.42, blue: 0.26)).frame(width: 96, height: 84)
            if hiding {
                HStack(spacing: 10) {
                    Circle().fill(.white).frame(width: 12).overlay(Circle().fill(.black).frame(width: 6))
                    Circle().fill(.white).frame(width: 12).overlay(Circle().fill(.black).frame(width: 6))
                }
                .offset(y: -130)
            }
        }
        .frame(width: 180, height: 240, alignment: .bottom)
    }
}

struct OfficeWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.30, green: 0.36, blue: 0.34).frame(width: width, height: 545)
            Rectangle().fill(Color(red: 0.45, green: 0.32, blue: 0.22)).frame(width: width, height: 155).offset(y: 545)
            // Window onto the car park, with Uncle's old car
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom))
                .frame(width: 320, height: 190)
                .overlay(CarView().scaleEffect(0.5).offset(y: 40))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 8))
                .position(x: 330, y: 280)
            // Desk
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.36, green: 0.22, blue: 0.14)).frame(width: 300, height: 100).position(x: 720, y: 496)
            Rectangle().fill(Color(red: 0.50, green: 0.32, blue: 0.20)).frame(width: 320, height: 12).position(x: 720, y: 442)
            Text("MANAGER").font(.game(16, .heavy)).foregroundStyle(Palette.gold).position(x: 720, y: 500)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

// MARK: Dungeon

struct DungeonWall: View {
    let width: CGFloat

    private let stones: [(x: CGFloat, y: CGFloat, w: CGFloat)] = {
        var rng = SeededRandom(seed: 91)
        return (0..<120).map { _ in (rng.next(), rng.next(), 50 + rng.next() * 70) }
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.16), Color(red: 0.20, green: 0.16, blue: 0.26)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            ForEach(stones.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04))
                    .frame(width: stones[i].w, height: 34)
                    .position(x: stones[i].x * width, y: 60 + stones[i].y * 460)
            }
            Rectangle().fill(Color(red: 0.24, green: 0.20, blue: 0.24)).frame(width: width, height: 155).offset(y: 545)
            // Torches
            ForEach(0..<Int(width / 520), id: \.self) { i in
                ZStack {
                    Circle().fill(RadialGradient(colors: [.orange.opacity(0.4), .clear], center: .center, startRadius: 4, endRadius: 140)).frame(width: 280)
                    Capsule().fill(Color(red: 0.4, green: 0.26, blue: 0.16)).frame(width: 10, height: 50).offset(y: 30)
                    Image(systemName: "flame.fill").font(.system(size: 34)).foregroundStyle(.orange)
                }
                .position(x: CGFloat(i) * 520 + 300, y: 330)
            }
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }
}

/// A rock with glowing orbs in it. `left` is how many orbs are still inside (0 = mined out).
struct OrbRockView: View {
    let left: Int
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 26).fill(Color(white: 0.34)).frame(width: 110, height: 76)
            RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.42)).frame(width: 70, height: 50).offset(x: -18, y: -30)
            ForEach(0..<max(left, 0), id: \.self) { i in
                Circle().fill(RadialGradient(colors: [.white, color], center: .center, startRadius: 1, endRadius: 12))
                    .frame(width: 22)
                    .shadow(color: color, radius: 8)
                    .offset(x: CGFloat(i - 1) * 30, y: -24 - CGFloat(i % 2) * 22)
            }
        }
        .frame(width: 120, height: 110, alignment: .bottom)
        .opacity(left > 0 ? 1 : 0.55)
    }
}

struct OrbShopView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.42, green: 0.26, blue: 0.16)).frame(width: 220, height: 110)
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle().fill(i % 2 == 0 ? Color.purple : Color.white).frame(width: 48, height: 40)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .offset(y: -190)
            Rectangle().fill(Color(white: 0.25)).frame(width: 8, height: 200).offset(x: -110)
            Rectangle().fill(Color(white: 0.25)).frame(width: 8, height: 200).offset(x: 110)
            Text("ORB SHOP").font(.game(20, .heavy)).foregroundStyle(Palette.gold).offset(y: -70)
            PersonView(outfit: .worker(1)).scaleEffect(0.62, anchor: .bottom).offset(y: -100)
        }
        .frame(width: 250, height: 250, alignment: .bottom)
    }
}

struct QuestBoardView: View {
    let done: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.40, green: 0.28, blue: 0.18)).frame(width: 10, height: 190).offset(x: -50)
            Rectangle().fill(Color(red: 0.40, green: 0.28, blue: 0.18)).frame(width: 10, height: 190).offset(x: 50)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.55, green: 0.40, blue: 0.26)).frame(width: 150, height: 120).offset(y: -70)
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 1, green: 0.96, blue: 0.82)).frame(width: 90, height: 80).rotationEffect(.degrees(-4)).offset(y: -88)
            Image(systemName: done ? "checkmark.seal.fill" : "exclamationmark").font(.system(size: 38, weight: .heavy))
                .foregroundStyle(done ? .green : .red).offset(y: -106)
        }
        .frame(width: 160, height: 200, alignment: .bottom)
    }
}

/// Spikes that slide along the dungeon floor.
struct SpikeTrapView: View {
    var body: some View {
        HStack(spacing: -2) {
            ForEach(0..<4, id: \.self) { _ in
                Triangle().fill(Color(white: 0.75)).frame(width: 20, height: 34)
            }
        }
        .frame(width: 80, height: 36, alignment: .bottom)
    }
}
