import SwiftUI

// Drawings for Level 3 and the roof. Furniture views stand with their bottom edge on the floor.

private let wood = Color(red: 0.50, green: 0.32, blue: 0.20)
private let darkWood = Color(red: 0.36, green: 0.22, blue: 0.14)

private struct RoomShell: View {
    let width: CGFloat
    let wallTop: Color
    let wallBottom: Color
    let floorTop: Color
    let floorBottom: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [wallTop, wallBottom], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 450)
            Rectangle().fill(darkWood).frame(width: width, height: 16).offset(y: 442)
            LinearGradient(colors: [floorTop, floorBottom], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
        }
    }
}

// MARK: - Rooms

struct StairsWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoomShell(width: width, wallTop: Color(red: 0.22, green: 0.18, blue: 0.32), wallBottom: Color(red: 0.32, green: 0.25, blue: 0.40),
                      floorTop: Color(red: 0.42, green: 0.28, blue: 0.19), floorBottom: Color(red: 0.52, green: 0.35, blue: 0.23))
            // Each stripe is one step; they get darker as you go down.
            ForEach(0..<Int(width / 90), id: \.self) { i in
                Rectangle().fill(.black.opacity(0.04 + Double(i) * 0.012)).frame(width: 90, height: 242).offset(x: CGFloat(i) * 90, y: 458)
                Rectangle().fill(.black.opacity(0.35)).frame(width: 4, height: 242).offset(x: CGFloat(i) * 90, y: 458)
            }
            // Banister sloping down the wall
            Path { p in
                p.move(to: CGPoint(x: 0, y: 250))
                p.addLine(to: CGPoint(x: width, y: 400))
            }
            .stroke(darkWood, lineWidth: 14)
            ForEach(0..<Int(width / 120), id: \.self) { i in
                let x = CGFloat(i) * 120 + 60
                Rectangle().fill(darkWood).frame(width: 8, height: 450 - (250 + x / width * 150)).offset(x: x, y: 250 + x / width * 150)
            }
            ForEach(Array([300, 900, 1500].enumerated()), id: \.offset) { i, x in
                PictureFrame(seed: i + 2).offset(x: CGFloat(x), y: 150 + CGFloat(x) / 20)
            }
            Text("↓  DOWN  ↓").font(.game(22, .heavy)).foregroundStyle(.white.opacity(0.25)).position(x: width / 2, y: 480)
        }
    }
}

struct DownstairsWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoomShell(width: width, wallTop: Color(red: 0.20, green: 0.28, blue: 0.30), wallBottom: Color(red: 0.28, green: 0.38, blue: 0.38),
                      floorTop: Color(red: 0.40, green: 0.27, blue: 0.18), floorBottom: Color(red: 0.52, green: 0.35, blue: 0.23))
            // Kitchen: tiled wall and checkered floor
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(red: 0.75, green: 0.80, blue: 0.78)).frame(width: 620, height: 442)
                ForEach(0..<8, id: \.self) { i in
                    Rectangle().fill(.black.opacity(0.08)).frame(width: 620, height: 2).offset(y: CGFloat(i) * 56)
                }
                ForEach(0..<11, id: \.self) { i in
                    Rectangle().fill(.black.opacity(0.08)).frame(width: 2, height: 442).offset(x: CGFloat(i) * 56)
                }
                ForEach(0..<44, id: \.self) { i in
                    let col = i % 11, row = i / 11
                    Rectangle()
                        .fill((col + row) % 2 == 0 ? Color(white: 0.85) : Color(white: 0.30))
                        .frame(width: 56.4, height: 60.5)
                        .offset(x: CGFloat(col) * 56.4, y: 458 + CGFloat(row) * 60.5)
                }
            }
            .offset(x: 1650)
            ForEach(Array([240, 1000, 2440].enumerated()), id: \.offset) { i, x in
                PictureFrame(seed: i + 4).offset(x: CGFloat(x), y: 215)
            }
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.55, green: 0.30, blue: 0.25))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.gold.opacity(0.5), lineWidth: 4).padding(10))
                .frame(width: 520, height: 120)
                .offset(x: 480, y: 565)
        }
    }
}

struct GarageWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoomShell(width: width, wallTop: Color(white: 0.30), wallBottom: Color(white: 0.40),
                      floorTop: Color(white: 0.34), floorBottom: Color(white: 0.46))
            // Big roll-up door behind the car
            ZStack {
                Rectangle().fill(Color(white: 0.55))
                VStack(spacing: 30) { ForEach(0..<7, id: \.self) { _ in Rectangle().fill(.black.opacity(0.2)).frame(height: 4) } }
            }
            .frame(width: 520, height: 300)
            .offset(x: 500, y: 142)
            // Pegboard with tools
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.62, green: 0.50, blue: 0.36)).frame(width: 300, height: 150).offset(x: 1060, y: 120)
            HStack(spacing: 34) {
                Image(systemName: "hammer.fill")
                Image(systemName: "wrench.fill")
                Image(systemName: "screwdriver.fill")
                Image(systemName: "scissors")
            }
            .font(.system(size: 34))
            .foregroundStyle(Color(white: 0.2))
            .offset(x: 1085, y: 170)
            Ellipse().fill(.black.opacity(0.25)).frame(width: 240, height: 50).offset(x: 640, y: 600)
        }
    }
}

struct BasementWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoomShell(width: width, wallTop: Color(red: 0.24, green: 0.16, blue: 0.14), wallBottom: Color(red: 0.34, green: 0.22, blue: 0.18),
                      floorTop: Color(white: 0.26), floorBottom: Color(white: 0.36))
            // Brick lines
            ForEach(0..<9, id: \.self) { i in
                Rectangle().fill(.black.opacity(0.18)).frame(width: width, height: 3).offset(y: CGFloat(i) * 50)
            }
            ForEach(0..<Int(width / 110), id: \.self) { i in
                ForEach(0..<9, id: \.self) { row in
                    Rectangle().fill(.black.opacity(0.18)).frame(width: 3, height: 50)
                        .offset(x: CGFloat(i) * 110 + (row % 2 == 0 ? 0 : 55), y: CGFloat(row) * 50)
                }
            }
            // Pipes along the ceiling
            Rectangle().fill(Color(white: 0.5)).frame(width: width, height: 16).offset(y: 60)
            Rectangle().fill(Color(red: 0.6, green: 0.35, blue: 0.2)).frame(width: width, height: 10).offset(y: 86)
        }
    }
}

struct YardScene: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Color(red: 0.20, green: 0.18, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 460)
            ForEach(0..<40, id: \.self) { i in
                Circle().fill(.white.opacity(0.8)).frame(width: CGFloat(2 + i % 3))
                    .position(x: CGFloat((i * 137) % Int(width)), y: CGFloat((i * 59) % 260))
            }
            Circle().fill(Palette.moon).frame(width: 90).shadow(color: Palette.moon, radius: 26).position(x: 900, y: 110)
            // The back of the house
            Rectangle().fill(Color(red: 0.20, green: 0.16, blue: 0.30)).frame(width: 330, height: 460)
            // Fence
            HStack(spacing: 12) {
                ForEach(0..<Int((width - 330) / 46), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.70, green: 0.64, blue: 0.56)).frame(width: 34, height: 150)
                }
            }
            .offset(x: 340, y: 310)
            LinearGradient(colors: [Color(red: 0.10, green: 0.28, blue: 0.18), Color(red: 0.14, green: 0.38, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
            // Stepping-stone path to the garden
            ForEach(0..<9, id: \.self) { i in
                Ellipse().fill(Color(white: 0.55)).frame(width: 90, height: 30).offset(x: 300 + CGFloat(i) * 130, y: 600 + CGFloat(i % 2) * 24)
            }
            // Flower beds by the gate
            ForEach(0..<8, id: \.self) { i in
                FlowerView().scaleEffect(1.6).offset(x: 1180 + CGFloat(i) * 46, y: 500 + CGFloat(i % 3) * 14)
            }
        }
    }
}

struct RoofScene: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Color(red: 0.22, green: 0.16, blue: 0.44)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 700)
            ForEach(0..<60, id: \.self) { i in
                Circle().fill(.white.opacity(0.85)).frame(width: CGFloat(2 + i % 3))
                    .position(x: CGFloat((i * 151) % Int(width)), y: CGFloat((i * 67) % 440))
            }
            Circle().fill(Palette.moon).frame(width: 130).shadow(color: Palette.moon, radius: 36).position(x: 1050, y: 150)
            // Chimney
            Rectangle().fill(Color(red: 0.45, green: 0.22, blue: 0.18)).frame(width: 90, height: 170).offset(x: 760, y: 330)
            Rectangle().fill(Color(red: 0.30, green: 0.15, blue: 0.12)).frame(width: 110, height: 22).offset(x: 750, y: 316)
            // Shingles
            Rectangle().fill(Color(red: 0.34, green: 0.20, blue: 0.24)).frame(width: width, height: 220).offset(y: 480)
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<Int(width / 64) + 1, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.42, green: 0.25, blue: 0.28)).frame(width: 60, height: 40)
                    }
                }
                .offset(x: row % 2 == 0 ? 0 : -32, y: 484 + CGFloat(row) * 44)
            }
        }
    }
}

// MARK: - Furniture and doors

struct StairsDoorView: View {
    let up: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.75)).frame(width: 110, height: 300)
            VStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle().fill(wood.opacity(0.5 + Double(up ? 5 - i : i) * 0.08)).frame(width: CGFloat(40 + (up ? 5 - i : i) * 10), height: 14)
                }
            }
            .offset(y: 50)
            Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(size: 40, weight: .heavy)).foregroundStyle(.white.opacity(0.8)).offset(y: -90)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkWood, lineWidth: 10))
    }
}

struct CouchView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.30, green: 0.45, blue: 0.60)).frame(width: 240, height: 120)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.38, green: 0.55, blue: 0.70)).frame(width: 96, height: 44)
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.38, green: 0.55, blue: 0.70)).frame(width: 96, height: 44)
            }
            .offset(y: -22)
            HStack(spacing: 196) {
                RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.25, green: 0.38, blue: 0.52)).frame(width: 34, height: 86)
                RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.25, green: 0.38, blue: 0.52)).frame(width: 34, height: 86)
            }
        }
        .frame(width: 270, height: 130, alignment: .bottom)
    }
}

struct BookshelfView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(darkWood).frame(width: 130, height: 250)
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            Rectangle()
                                .fill([Color.red, .teal, .orange, .green, .purple, .yellow, .blue][(i + row * 3) % 7].opacity(0.85))
                                .frame(width: 12, height: CGFloat(34 + (i * 7 + row * 5) % 14))
                        }
                    }
                    .frame(width: 114, height: 50, alignment: .bottom)
                    .background(wood)
                }
            }
        }
    }
}

struct FridgeView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.88)).frame(width: 120, height: 260)
            Rectangle().fill(.black.opacity(0.2)).frame(width: 120, height: 4).offset(y: -40)
            Capsule().fill(Color(white: 0.55)).frame(width: 8, height: 50).offset(x: 42, y: -85)
            Capsule().fill(Color(white: 0.55)).frame(width: 8, height: 80).offset(x: 42, y: 30)
            Image(systemName: "heart.fill").font(.system(size: 16)).foregroundStyle(.red).offset(x: -20, y: -90)
            RoundedRectangle(cornerRadius: 2).fill(.yellow).frame(width: 26, height: 22).offset(x: -24, y: 10)
        }
    }
}

struct KitchenCounterView: View {
    let open: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 16) {
                Capsule().fill(Color.red.opacity(0.8)).frame(width: 18, height: 34)
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.3)).frame(width: 50, height: 26)
            }
            Rectangle().fill(Color(white: 0.25)).frame(width: 190, height: 12)
            ZStack(alignment: .top) {
                Rectangle().fill(Color(red: 0.90, green: 0.86, blue: 0.78)).frame(width: 180, height: 120)
                HStack(spacing: 10) {
                    drawer(pulled: open)
                    drawer(pulled: false)
                }
                .padding(.top, 12)
            }
        }
        .animation(.spring(duration: 0.3), value: open)
    }

    private func drawer(pulled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.80, green: 0.74, blue: 0.64))
            Capsule().fill(Color(white: 0.4)).frame(width: 24, height: 6)
        }
        .frame(width: 76, height: 34)
        .offset(y: pulled ? 10 : 0)
        .shadow(radius: pulled ? 4 : 0)
    }
}

struct FrontDoorView: View {
    let dogWaiting: Bool
    let gaveKey: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            DoorView(color: Color(red: 0.25, green: 0.40, blue: 0.30)) { DoorSign(text: "FRONT DOOR", color: .white) }
            // Pet flap
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.15)).frame(width: 60, height: 46)
                if dogWaiting {
                    DogView(happy: gaveKey).scaleEffect(0.45).frame(width: 56, height: 42).clipped()
                    if !gaveKey {
                        Image(systemName: "key.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.cyan).offset(x: 16, y: 12)
                    }
                }
            }
            .offset(y: -8)
        }
    }
}

struct DogView: View {
    let happy: Bool
    @State private var wag = false

    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.72, green: 0.52, blue: 0.32)).frame(width: 14, height: 36)
                .rotationEffect(.degrees(wag ? 50 : 20), anchor: .bottom).offset(x: -44, y: 8)
            RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.78, green: 0.58, blue: 0.36)).frame(width: 80, height: 50).offset(y: 22)
            Circle().fill(Color(red: 0.78, green: 0.58, blue: 0.36)).frame(width: 58).offset(x: 26, y: -10)
            Ellipse().fill(Color(red: 0.50, green: 0.34, blue: 0.20)).frame(width: 18, height: 34).offset(x: 4, y: -12)
            Ellipse().fill(Color(red: 0.92, green: 0.82, blue: 0.68)).frame(width: 30, height: 22).offset(x: 40, y: 2)
            Circle().fill(.black).frame(width: 10).offset(x: 50, y: -2)
            Circle().fill(.black).frame(width: 7).offset(x: 30, y: -18)
            if happy {
                Capsule().fill(Color(red: 1, green: 0.45, blue: 0.5)).frame(width: 9, height: 14).offset(x: 42, y: 14)
            }
            HStack(spacing: 34) {
                Capsule().fill(Color(red: 0.72, green: 0.52, blue: 0.32)).frame(width: 14, height: 22)
                Capsule().fill(Color(red: 0.72, green: 0.52, blue: 0.32)).frame(width: 14, height: 22)
            }
            .offset(y: 52)
        }
        .frame(width: 130, height: 130)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.25).repeatForever()) { wag = true }
        }
    }
}

struct LockboxWallView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.55, green: 0.55, blue: 0.62)).frame(width: 76, height: 44).offset(y: 14)
            Image(systemName: open ? "lock.open.fill" : "lock.fill").font(.system(size: 16)).foregroundStyle(Palette.gold).offset(y: 26)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.42, green: 0.42, blue: 0.50)).frame(width: 82, height: 14)
                .rotationEffect(.degrees(open ? -70 : 0), anchor: .leading)
        }
        .frame(width: 84, height: 60)
        .animation(.spring(duration: 0.5, bounce: 0.4), value: open)
    }
}

struct LightSwitchView: View {
    let on: Bool

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.9)).frame(width: 40, height: 60)
                RoundedRectangle(cornerRadius: 3).fill(on ? Color.yellow : Color(white: 0.5)).frame(width: 14, height: 26).offset(y: on ? -8 : 8)
            }
            Spacer()
        }
        .frame(width: 50, height: 220)
    }
}

struct BinView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Trapezoid().fill(Color(red: 0.20, green: 0.50, blue: 0.75)).rotationEffect(.degrees(180)).frame(width: 80, height: 100)
            Image(systemName: "arrow.3.trianglepath").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).offset(y: -30)
        }
    }
}

struct CarView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 40).fill(Color(red: 0.75, green: 0.20, blue: 0.22)).frame(width: 240, height: 80).offset(x: -10, y: -76)
            RoundedRectangle(cornerRadius: 20).fill(Color.cyan.opacity(0.5)).frame(width: 190, height: 50).offset(x: -10, y: -90)
            RoundedRectangle(cornerRadius: 30).fill(Color(red: 0.80, green: 0.22, blue: 0.24)).frame(width: 380, height: 90).offset(y: -24)
            HStack(spacing: 170) {
                Circle().fill(Color(white: 0.1)).frame(width: 74).overlay(Circle().fill(Color(white: 0.6)).frame(width: 30))
                Circle().fill(Color(white: 0.1)).frame(width: 74).overlay(Circle().fill(Color(white: 0.6)).frame(width: 30))
            }
            Circle().fill(.yellow.opacity(0.8)).frame(width: 22).offset(x: 176, y: -56)
        }
        .frame(width: 400, height: 190, alignment: .bottom)
    }
}

struct WorkbenchView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(darkWood).frame(width: 12, height: 100).offset(x: -60)
            Rectangle().fill(darkWood).frame(width: 12, height: 100).offset(x: 60)
            RoundedRectangle(cornerRadius: 4).fill(wood).frame(width: 160, height: 18).offset(y: -100)
            // Vise and hammer on top
            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.35)).frame(width: 40, height: 26).offset(x: -40, y: -118)
            Image(systemName: "hammer.fill").font(.system(size: 30)).foregroundStyle(Color(white: 0.75)).offset(x: 34, y: -118)
        }
        .frame(width: 170, height: 150, alignment: .bottom)
    }
}

struct ToolboxView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5).fill(Color.red).frame(width: 90, height: 50).offset(y: 16)
            RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.7, green: 0.1, blue: 0.1)).frame(width: 96, height: 16)
                .rotationEffect(.degrees(open ? -60 : 0), anchor: .leading)
            Capsule().fill(Color(white: 0.2)).frame(width: 36, height: 8).offset(y: open ? -200 : -8).opacity(open ? 0 : 1)
        }
        .frame(width: 100, height: 70)
        .animation(.spring(duration: 0.4), value: open)
    }
}

struct LadderView: View {
    var body: some View {
        ZStack {
            HStack(spacing: 44) {
                Rectangle().fill(Color(red: 0.75, green: 0.60, blue: 0.35)).frame(width: 10, height: 290)
                Rectangle().fill(Color(red: 0.75, green: 0.60, blue: 0.35)).frame(width: 10, height: 290)
            }
            VStack(spacing: 30) {
                ForEach(0..<7, id: \.self) { _ in Rectangle().fill(Color(red: 0.68, green: 0.54, blue: 0.30)).frame(width: 54, height: 8) }
            }
        }
        .rotationEffect(.degrees(6), anchor: .bottom)
    }
}

struct TrunkView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6).fill(darkWood).frame(width: 130, height: 70).offset(y: 24)
            Rectangle().fill(Palette.gold.opacity(0.7)).frame(width: 12, height: 70).offset(y: 24)
            RoundedRectangle(cornerRadius: 14).fill(wood).frame(width: 136, height: 30)
                .rotationEffect(.degrees(open ? -55 : 0), anchor: .leading)
        }
        .frame(width: 140, height: 96)
        .animation(.spring(duration: 0.4), value: open)
    }
}

struct WasherView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.85)).frame(width: 120, height: 150)
            Circle().fill(Color(white: 0.3)).frame(width: 76).overlay(Circle().fill(Color.cyan.opacity(0.35)).frame(width: 58)).offset(y: 16)
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 10)
                Circle().fill(.green).frame(width: 10)
            }
            .offset(x: -30, y: -56)
        }
    }
}

struct GardenGateView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().trim(from: 0.5, to: 1).stroke(Color(red: 0.25, green: 0.55, blue: 0.30), lineWidth: 26).frame(width: 190, height: 190).offset(y: -90)
            HStack(spacing: 150) {
                Rectangle().fill(Color(red: 0.25, green: 0.55, blue: 0.30)).frame(width: 26, height: 190)
                Rectangle().fill(Color(red: 0.25, green: 0.55, blue: 0.30)).frame(width: 26, height: 190)
            }
            ForEach(0..<6, id: \.self) { i in
                FlowerView().offset(x: CGFloat(i * 34 - 85), y: -180 - CGFloat(i == 0 || i == 5 ? 0 : (i == 1 || i == 4 ? 60 : 85)))
            }
            Text("GARDEN").font(.game(18, .heavy)).foregroundStyle(.white).offset(y: -120)
        }
        .frame(width: 220, height: 300, alignment: .bottom)
    }
}

struct RoofWindowView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(darkWood).frame(width: 150, height: 170)
            RoundedRectangle(cornerRadius: 4).fill(Color(red: 1, green: 0.85, blue: 0.5)).frame(width: 124, height: 144)
            Image(systemName: "arrow.down.left").font(.system(size: 40, weight: .heavy)).foregroundStyle(darkWood)
        }
    }
}

/// A small owl perched on top of the roof's chimney. Easy to miss!
struct OwlView: View {
    @State private var blink = false

    var body: some View {
        VStack {
            ZStack {
                Ellipse().fill(Color(red: 0.50, green: 0.36, blue: 0.22)).frame(width: 40, height: 50)
                Triangle().fill(Color(red: 0.50, green: 0.36, blue: 0.22)).frame(width: 12, height: 12).offset(x: -13, y: -26)
                Triangle().fill(Color(red: 0.50, green: 0.36, blue: 0.22)).frame(width: 12, height: 12).offset(x: 13, y: -26)
                HStack(spacing: 4) {
                    Circle().fill(.yellow).frame(width: 13).overlay(Circle().fill(.black).frame(width: 5))
                    Capsule().fill(.yellow).frame(width: 13, height: blink ? 3 : 13).overlay(Circle().fill(.black).frame(width: blink ? 0 : 5))
                }
                .offset(y: -8)
                Triangle().fill(.orange).frame(width: 8, height: 7).rotationEffect(.degrees(180)).offset(y: 2)
            }
            Spacer()
        }
        .frame(width: 50, height: 280)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.25).repeatForever().delay(2)) { blink = true }
        }
    }
}

struct ToyChestView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 10) {
                TeddyView()
                Circle().fill(.red).frame(width: 26)
            }
            .offset(y: -64)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.95, green: 0.55, blue: 0.25)).frame(width: 110, height: 70)
            Text("TOYS").font(.game(18, .heavy)).foregroundStyle(.white).offset(y: -24)
        }
        .frame(width: 120, height: 120, alignment: .bottom)
    }
}

struct PhoneNightstandView: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.1))
                .overlay(RoundedRectangle(cornerRadius: 2).fill(Color.cyan.opacity(0.7)).padding(3))
                .frame(width: 34, height: 12)
                .shadow(color: .cyan, radius: 8)
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.55, green: 0.36, blue: 0.24)).frame(width: 90, height: 84)
                Capsule().fill(Palette.gold).frame(width: 22, height: 6).offset(y: -16)
            }
        }
    }
}

// MARK: - Things on the floor

struct PlankView: View {
    let size: CGSize

    var body: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.72, green: 0.52, blue: 0.32)).frame(width: size.width, height: size.height)
            Rectangle().stroke(.black.opacity(0.5), lineWidth: 3).frame(width: size.width, height: size.height)
            // Popped nails and a crack: this one is loose.
            Circle().fill(Color(white: 0.8)).frame(width: 7).offset(x: -size.width / 2 + 10, y: -size.height / 2 + 9)
            Circle().fill(Color(white: 0.8)).frame(width: 7).offset(x: size.width / 2 - 10, y: size.height / 2 - 9)
            Path { p in
                p.move(to: CGPoint(x: size.width * 0.3, y: 0))
                p.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.5))
                p.addLine(to: CGPoint(x: size.width * 0.4, y: size.height))
            }
            .stroke(.black.opacity(0.45), lineWidth: 2)
            .frame(width: size.width, height: size.height)
        }
        .rotationEffect(.degrees(-3))
    }
}

/// A glowing gift that holds a boosting accessory (roof only).
struct BoostBallView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white, .cyan, .purple], center: .center, startRadius: 2, endRadius: 24)).frame(width: 44)
            RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 18, height: 16)
            Rectangle().fill(Color.pink).frame(width: 4, height: 16)
            Rectangle().fill(Color.pink).frame(width: 18, height: 4)
        }
        .shadow(color: .cyan, radius: glow ? 20 : 6)
        .offset(y: glow ? -12 : -2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) { glow = true }
        }
    }
}

/// A teddy bear drawn from shapes.
struct TeddyView: View {
    var color = Color(red: 0.70, green: 0.48, blue: 0.30)

    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 30).offset(y: 14)
            Circle().fill(color).frame(width: 24)
            Circle().fill(color).frame(width: 10).offset(x: -10, y: -10)
            Circle().fill(color).frame(width: 10).offset(x: 10, y: -10)
            Circle().fill(.black).frame(width: 3).offset(x: -4, y: -2)
            Circle().fill(.black).frame(width: 3).offset(x: 4, y: -2)
            Circle().fill(.black.opacity(0.6)).frame(width: 4).offset(y: 3)
        }
        .frame(width: 36, height: 48)
    }
}

struct StarBallView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white, .yellow, .orange], center: .center, startRadius: 2, endRadius: 22)).frame(width: 40)
            Image(systemName: "star.fill").font(.system(size: 18)).foregroundStyle(.white)
        }
        .shadow(color: .yellow, radius: glow ? 18 : 6)
        .offset(y: glow ? -10 : -2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever()) { glow = true }
        }
    }
}

struct PaintCansView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            can(.blue, height: 40)
            can(.yellow, height: 30)
        }
        .frame(width: 70, height: 46, alignment: .bottom)
    }

    private func can(_ color: Color, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.75)).frame(width: 30, height: height)
            Rectangle().fill(color).frame(width: 30, height: 10).offset(y: height * 0.35)
        }
    }
}

struct ThrownToyView: View {
    var body: some View {
        TeddyView(color: Color(red: 1, green: 0.55, blue: 0.7))
            .rotationEffect(.degrees(80))
            .frame(width: 50, height: 40)
    }
}

// MARK: - Overlays

/// A number keypad drawn on screen. The room keeps moving behind it.
struct NumberPadOverlay: View {
    let title: String
    let digits: Int
    let onSubmit: (String) -> Bool
    let onCancel: () -> Void
    @State private var entry = ""
    @State private var wrong = false

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Text(title).font(.game(22, .heavy)).foregroundStyle(.white)
                Text(entry.padding(toLength: digits, withPad: "•", startingAt: 0))
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .foregroundStyle(wrong ? .red : .green)
                    .frame(width: 220, height: 56)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .offset(x: wrong ? -8 : 0)
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(1..<4, id: \.self) { col in key("\(row * 3 + col)") }
                    }
                }
                HStack(spacing: 10) {
                    padButton("xmark", color: .gray, action: onCancel)
                    key("0")
                    padButton("delete.left.fill", color: .orange) { entry = String(entry.dropLast()) }
                }
            }
            .padding(22)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
            .padding(.trailing, 40)
        }
    }

    private func key(_ digit: String) -> some View {
        Button {
            Sound.beep.play(volume: 0.6)
            wrong = false
            guard entry.count < digits else { return }
            entry += digit
            if entry.count == digits && !onSubmit(entry) {
                withAnimation(.spring(duration: 0.15, bounce: 0.8)) { wrong = true }
                entry = ""
            }
        } label: {
            Text(digit).font(.game(28)).foregroundStyle(.white).frame(width: 66, height: 56)
                .background(Color(white: 0.3), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
    }

    private func padButton(_ symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.game(22)).foregroundStyle(.white).frame(width: 66, height: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Mom's phone: a passcode lock screen, then a home screen where Notes holds the door code.
struct PhoneOverlay: View {
    let passcode: String
    let code: String
    let onNoteRead: () -> Void
    var onFiveFails: () -> Void = {}
    var onOpenApp: (String) -> Void = { _ in }
    let onClose: () -> Void

    enum Page: Equatable { case locked, home, app(String) }
    @State private var page: Page = .locked
    @State private var entry = ""
    @State private var wrong = false
    @State private var fails = 0

    private let apps: [(name: String, symbol: String, color: Color)] = [
        ("Notes", "note.text", .yellow), ("Photos", "photo.fill", .pink), ("Clock", "alarm.fill", .orange),
        ("Music", "music.note", .red), ("Camera", "camera.fill", .gray), ("Messages", "message.fill", .green),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            HStack(spacing: 30) {
                ZStack {
                    RoundedRectangle(cornerRadius: 44).fill(.black)
                    RoundedRectangle(cornerRadius: 34)
                        .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.20, blue: 0.55), Color(red: 0.15, green: 0.30, blue: 0.60)],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(12)
                    screen.padding(26)
                }
                .frame(width: 380, height: 640)
                BigButton(title: "Put it back", symbol: "xmark", color: .gray, action: onClose)
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch page {
        case .locked:
            VStack(spacing: 14) {
                Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(.white)
                Text(wrong ? "Wrong passcode" : "Enter Passcode").font(.game(22)).foregroundStyle(wrong ? .red : .white)
                HStack(spacing: 14) {
                    ForEach(0..<passcode.count, id: \.self) { i in
                        Circle().fill(i < entry.count ? Color.white : Color.white.opacity(0.25)).frame(width: 16, height: 16)
                    }
                }
                .padding(.bottom, 6)
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(1..<4, id: \.self) { col in digitKey("\(row * 3 + col)") }
                    }
                }
                HStack(spacing: 14) {
                    Color.clear.frame(width: 76, height: 66)
                    digitKey("0")
                    Button { entry = String(entry.dropLast()) } label: {
                        Image(systemName: "delete.left").font(.game(24)).foregroundStyle(.white).frame(width: 76, height: 66)
                    }
                }
            }
        case .home:
            VStack(spacing: 26) {
                Text("2:04").font(.game(56, .heavy)).foregroundStyle(.white)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(92), spacing: 10), count: 3), spacing: 22) {
                    ForEach(apps, id: \.name) { app in
                        Button {
                            Sound.click.play()
                            page = .app(app.name)
                            onOpenApp(app.name)
                            if app.name == "Notes" { onNoteRead() }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: app.symbol).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 66, height: 66).background(app.color, in: RoundedRectangle(cornerRadius: 16))
                                Text(app.name).font(.game(15)).foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Spacer()
            }
            .padding(.top, 30)
        case .app(let name):
            VStack(spacing: 18) {
                HStack {
                    Button {
                        Sound.click.play()
                        page = .home
                    } label: {
                        Label("Back", systemImage: "chevron.left").font(.game(20)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text(name).font(.game(22, .heavy)).foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 60, height: 10)
                }
                if name == "Notes" {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Basement door").font(.game(20, .heavy))
                        Text(code).font(.system(size: 64, weight: .heavy, design: .monospaced))
                        Text("(don't tell the kids!)").font(.game(16, .medium))
                    }
                    .foregroundStyle(.black)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 1, green: 0.95, blue: 0.7), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(appText(name))
                        .font(.game(22, .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                }
                Spacer()
            }
            .padding(.top, 20)
        }
    }

    private func appText(_ name: String) -> String {
        switch name {
        case "Photos": "437 pictures of you as a baby. And one of Dad asleep on the couch."
        case "Clock": "Alarm set for 6:00 AM. Yikes."
        case "Music": "Now playing: 'Relaxing Whale Sounds, Volume 9'."
        case "Camera": "You take a blurry selfie. Better delete that."
        default: "Grandma: \"Are the kids asleep?\"\nMom: \"Of course! Like little angels.\""
        }
    }

    private func digitKey(_ digit: String) -> some View {
        Button {
            Sound.beep.play(volume: 0.6)
            wrong = false
            guard entry.count < passcode.count else { return }
            entry += digit
            if entry.count == passcode.count {
                if entry == passcode {
                    Sound.unlock.play()
                    page = .home
                } else {
                    Sound.buzz.play()
                    wrong = true
                    fails += 1
                    if fails == 5 { onFiveFails() }
                }
                entry = ""
            }
        } label: {
            Text(digit).font(.game(30)).foregroundStyle(.white).frame(width: 76, height: 66)
                .background(.white.opacity(0.2), in: Circle())
        }
        .buttonStyle(PressableStyle())
    }
}
