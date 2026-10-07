import SwiftUI

// Drawings for Level 4: the hedge maze (seen from above) and the garden beyond the gate.

private let leaf = Color(red: 0.16, green: 0.46, blue: 0.24)
private let darkLeaf = Color(red: 0.10, green: 0.32, blue: 0.17)

/// The lawn under the maze, with a hedge border all the way round.
struct MazeGround: View {
    let size: CGSize

    var body: some View {
        Canvas { gc, _ in
            gc.fill(Path(CGRect(origin: .zero, size: size)), with: .color(darkLeaf))
            let lawn = CGRect(x: 60, y: 150, width: size.width - 120, height: size.height - 240)
            gc.fill(Path(lawn), with: .color(Color(red: 0.45, green: 0.68, blue: 0.36)))
            // Mowing stripes
            var x = lawn.minX
            var dark = false
            while x < lawn.maxX {
                if dark {
                    gc.fill(Path(CGRect(x: x, y: lawn.minY, width: min(110, lawn.maxX - x), height: lawn.height)), with: .color(.black.opacity(0.06)))
                }
                dark.toggle()
                x += 110
            }
            // Leafy bumps on the border hedge
            var bx: CGFloat = 20
            while bx < size.width {
                gc.fill(Path(ellipseIn: CGRect(x: bx, y: 96, width: 70, height: 60)), with: .color(leaf))
                gc.fill(Path(ellipseIn: CGRect(x: bx, y: size.height - 96, width: 70, height: 60)), with: .color(leaf))
                bx += 58
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A hedge wall. `size` is the ground it covers; it's drawn a bit taller so it looks solid.
struct HedgeView: View {
    let size: CGSize

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12).fill(darkLeaf).frame(width: size.width, height: size.height + 44)
            RoundedRectangle(cornerRadius: 12).fill(leaf).frame(width: size.width, height: size.height + 6)
            RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 3).frame(width: size.width - 8, height: size.height - 2).offset(y: 4)
        }
    }
}

struct PlantView: View {
    let watered: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Trapezoid().fill(Color(red: 0.70, green: 0.40, blue: 0.25)).rotationEffect(.degrees(180)).frame(width: 30, height: 18)
            if watered {
                Rectangle().fill(Color(red: 0.2, green: 0.7, blue: 0.3)).frame(width: 4, height: 30).offset(y: -16)
                FlowerView().offset(y: -38)
                Ellipse().fill(Color(red: 0.2, green: 0.7, blue: 0.3)).frame(width: 14, height: 7).offset(x: 9, y: -24)
            } else {
                // Droopy and brown
                Capsule().fill(Color(red: 0.55, green: 0.45, blue: 0.22)).frame(width: 4, height: 22).rotationEffect(.degrees(28), anchor: .bottom).offset(y: -16)
                Ellipse().fill(Color(red: 0.60, green: 0.48, blue: 0.20)).frame(width: 14, height: 8).offset(x: 14, y: -26)
            }
        }
        .frame(width: 44, height: 64, alignment: .bottom)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: watered)
    }
}

struct PestView: View {
    @State private var wiggle = false

    var body: some View {
        ZStack {
            Ellipse().fill(Color(red: 0.75, green: 0.15, blue: 0.15)).frame(width: 28, height: 20)
            Rectangle().fill(.black).frame(width: 2, height: 20)
            Circle().fill(.black).frame(width: 10).offset(x: 14)
            Circle().fill(.black).frame(width: 5).offset(x: -6, y: -4)
            Circle().fill(.black).frame(width: 5).offset(x: -6, y: 4)
        }
        .rotationEffect(.degrees(wiggle ? 12 : -12))
        .offset(y: -30)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever()) { wiggle = true }
        }
    }
}

struct SpikyVineView: View {
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.25, green: 0.12, blue: 0.30).opacity(0.85)).frame(width: size.width, height: size.height)
            Canvas { gc, canvas in
                // Thorns scattered along the vine
                let long = max(canvas.width, canvas.height)
                var d: CGFloat = 8
                var flip = false
                while d < long - 6 {
                    let p = canvas.width > canvas.height ? CGPoint(x: d, y: canvas.height / 2 + (flip ? -5 : 5))
                                                         : CGPoint(x: canvas.width / 2 + (flip ? -5 : 5), y: d)
                    var spike = Path()
                    spike.move(to: CGPoint(x: p.x - 6, y: p.y + 6))
                    spike.addLine(to: CGPoint(x: p.x, y: p.y - 9))
                    spike.addLine(to: CGPoint(x: p.x + 6, y: p.y + 6))
                    spike.closeSubpath()
                    gc.fill(spike, with: .color(Color(red: 0.75, green: 0.30, blue: 0.80)))
                    flip.toggle()
                    d += 16
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

struct BushView: View {
    let hiding: Bool
    /// The one bush that looks a little odd: shake it for vines.
    let strange: Bool

    var body: some View {
        ZStack {
            Circle().fill(strange ? Color(red: 0.20, green: 0.60, blue: 0.45) : leaf).frame(width: 54).offset(x: -24, y: 6)
            Circle().fill(strange ? Color(red: 0.20, green: 0.60, blue: 0.45) : leaf).frame(width: 54).offset(x: 24, y: 6)
            Circle().fill(strange ? Color(red: 0.26, green: 0.70, blue: 0.52) : Color(red: 0.20, green: 0.54, blue: 0.28)).frame(width: 64).offset(y: -8)
            if strange {
                Image(systemName: "sparkle").font(.system(size: 16)).foregroundStyle(.yellow).offset(x: 26, y: -30)
                Capsule().fill(Color(red: 0.1, green: 0.4, blue: 0.2)).frame(width: 5, height: 26).rotationEffect(.degrees(30)).offset(x: -34, y: 22)
            }
            if hiding {
                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 10).overlay(Circle().fill(.black).frame(width: 4))
                    Circle().fill(.white).frame(width: 10).overlay(Circle().fill(.black).frame(width: 4))
                }
                .offset(y: -6)
            }
        }
        .frame(width: 110, height: 76)
    }
}

struct RadarStationView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(white: 0.4)).frame(width: 8, height: 50)
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.2)).frame(width: 60, height: 44).offset(y: -44)
            TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
                ZStack {
                    Circle().stroke(.green.opacity(0.7), lineWidth: 2).frame(width: 30)
                    Rectangle().fill(.green).frame(width: 2, height: 15).offset(y: -7.5)
                        .rotationEffect(.degrees(ctx.date.timeIntervalSinceReferenceDate * 120))
                }
            }
            .frame(width: 34, height: 34)
            .offset(y: -49)
        }
        .frame(width: 70, height: 100, alignment: .bottom)
    }
}

struct MazeGateView: View {
    let open: Bool
    let dogs: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 64) {
                Rectangle().fill(Color(red: 0.50, green: 0.32, blue: 0.20)).frame(width: 14, height: 110)
                Rectangle().fill(Color(red: 0.50, green: 0.32, blue: 0.20)).frame(width: 14, height: 110)
            }
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(open ? Color(red: 0.55, green: 0.80, blue: 0.45) : Color(red: 0.70, green: 0.60, blue: 0.45))
                        .frame(width: 8, height: 86)
                }
            }
            Image(systemName: open ? "lock.open.fill" : "lock.fill").font(.system(size: 18)).foregroundStyle(open ? .green : Palette.gold).offset(y: -92)
            if dogs {
                HStack(spacing: 30) {
                    DogView(happy: false).scaleEffect(0.5).frame(width: 60, height: 60)
                    DogView(happy: false).scaleEffect(x: -0.5, y: 0.5).frame(width: 60, height: 60)
                }
                .offset(x: -110, y: 6)
            }
        }
        .frame(width: 110, height: 124, alignment: .bottom)
        .animation(.easeInOut(duration: 0.4), value: dogs)
    }
}

/// Beyond the gate: the back of the garden, with a fence along the street.
struct BeyondScene: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.skyTop, Color(red: 0.20, green: 0.18, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 460)
            ForEach(0..<50, id: \.self) { i in
                Circle().fill(.white.opacity(0.8)).frame(width: CGFloat(2 + i % 3))
                    .position(x: CGFloat((i * 173) % Int(width)), y: CGFloat((i * 61) % 250))
            }
            Circle().fill(Palette.moon).frame(width: 90).shadow(color: Palette.moon, radius: 26).position(x: 1500, y: 110)
            HStack(spacing: 10) {
                ForEach(0..<Int(width / 44) + 1, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.62, green: 0.56, blue: 0.48)).frame(width: 34, height: 170)
                }
            }
            .offset(y: 290)
            LinearGradient(colors: [Color(red: 0.10, green: 0.30, blue: 0.18), Color(red: 0.15, green: 0.40, blue: 0.23)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
        }
    }
}

struct FlowerPotsView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            PlantView(watered: true)
            PlantView(watered: true).scaleEffect(1.3, anchor: .bottom)
            PlantView(watered: true)
        }
    }
}

struct WheelbarrowView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().fill(Color(white: 0.15)).frame(width: 36).offset(x: -46)
            Trapezoid().fill(Color(red: 0.75, green: 0.25, blue: 0.2)).rotationEffect(.degrees(180)).frame(width: 110, height: 50).offset(y: -26)
            Rectangle().fill(Color(red: 0.5, green: 0.32, blue: 0.2)).frame(width: 70, height: 7).rotationEffect(.degrees(-14)).offset(x: 64, y: -52)
            Ellipse().fill(Color(red: 0.35, green: 0.22, blue: 0.12)).frame(width: 90, height: 22).offset(y: -70)
        }
        .frame(width: 170, height: 100, alignment: .bottom)
    }
}

struct BirdhouseView: View {
    var body: some View {
        VStack(spacing: 0) {
            Triangle().fill(Color(red: 0.7, green: 0.2, blue: 0.2)).frame(width: 70, height: 30)
            ZStack {
                Rectangle().fill(Color(red: 0.85, green: 0.70, blue: 0.45)).frame(width: 54, height: 50)
                Circle().fill(.black).frame(width: 20)
            }
            Rectangle().fill(Color(red: 0.42, green: 0.27, blue: 0.17)).frame(width: 8, height: 160)
        }
    }
}

struct WellView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 96) {
                Rectangle().fill(Color(red: 0.42, green: 0.27, blue: 0.17)).frame(width: 10, height: 170)
                Rectangle().fill(Color(red: 0.42, green: 0.27, blue: 0.17)).frame(width: 10, height: 170)
            }
            Triangle().fill(Color(red: 0.55, green: 0.25, blue: 0.2)).frame(width: 150, height: 50).offset(y: -160)
            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.55)).frame(width: 130, height: 70)
            ForEach(0..<3, id: \.self) { i in
                Rectangle().fill(.black.opacity(0.2)).frame(width: 130, height: 2).offset(y: -CGFloat(i * 22 + 12))
            }
            Rectangle().fill(Color(white: 0.85)).frame(width: 3, height: 70).offset(y: -90)
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.5, green: 0.32, blue: 0.2)).frame(width: 26, height: 24).offset(y: -72)
        }
        .frame(width: 160, height: 220, alignment: .bottom)
    }
}

struct CompostView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.18, green: 0.30, blue: 0.20)).frame(width: 96, height: 110)
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.12, green: 0.22, blue: 0.14)).frame(width: 104, height: 16).offset(y: -106)
            Image(systemName: "leaf.fill").font(.system(size: 30)).foregroundStyle(.green.opacity(0.7)).offset(y: -44)
        }
    }
}

struct ScarecrowView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.5, green: 0.36, blue: 0.2)).frame(width: 8, height: 230)
            Rectangle().fill(Color(red: 0.5, green: 0.36, blue: 0.2)).frame(width: 150, height: 8).offset(y: -150)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.75, green: 0.30, blue: 0.25)).frame(width: 70, height: 80).offset(y: -100)
            Circle().fill(Color(red: 0.92, green: 0.80, blue: 0.50)).frame(width: 52).offset(y: -178)
            HStack(spacing: 14) {
                Text("x").font(.game(14, .heavy))
                Text("x").font(.game(14, .heavy))
            }
            .offset(y: -196)
            Trapezoid().fill(Color(red: 0.45, green: 0.32, blue: 0.16)).frame(width: 74, height: 26).offset(y: -222)
        }
        .frame(width: 160, height: 260, alignment: .bottom)
    }
}

struct StreetGateView: View {
    let open: Bool
    let codeAccepted: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ZStack {
                Rectangle().fill(Color(red: 0.12, green: 0.12, blue: 0.2))
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.2)).frame(width: 8, height: 260)
                    }
                }
                .scaleEffect(x: open ? 0.15 : 1, anchor: .leading)
                .animation(.easeInOut(duration: 0.8), value: open)
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: open ? "lock.open.fill" : "lock.fill").font(.system(size: 20)).foregroundStyle(Palette.gold)
                    }
                }
                .opacity(open ? 0 : 1)
            }
            .frame(width: 130, height: 290)
            .overlay(Rectangle().stroke(Color(white: 0.25), lineWidth: 10))
            VStack(spacing: 4) {
                Circle().fill(codeAccepted ? Color.green : Color.red).frame(width: 12)
                Text("ABC").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
            }
            .padding(8)
            .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 8))
            .offset(y: -120)
        }
    }
}

/// The radar screen: the whole maze from above, with what's still left to do.
struct RadarOverlay: View {
    let model: GardenModel
    let onClose: () -> Void

    var body: some View {
        let size = GardenModel.mazeSize
        let scale: CGFloat = 0.3
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("RADAR")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.green)
                Canvas { gc, _ in
                    for thing in model.engine.things {
                        let p = CGPoint(x: thing.pos.x * scale, y: thing.pos.y * scale)
                        func dot(_ r: CGFloat, _ color: Color) {
                            gc.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
                        }
                        switch thing.kind {
                        case "hedge":
                            let w = thing.footprint.width * scale, h = thing.footprint.height * scale
                            gc.fill(Path(CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)), with: .color(.green.opacity(0.45)))
                        case "plant": if !thing.open { dot(4, .yellow) }
                        case "pest": dot(6, .red)
                        case "bush", "shakyBush": dot(5, Color(red: 0.3, green: 0.9, blue: 0.5))
                        case "spikyVine": dot(4, .purple)
                        case "mazeGate": dot(7, .white)
                        default: break
                        }
                    }
                    let me = CGPoint(x: model.engine.player.x * scale, y: model.engine.player.y * scale)
                    gc.fill(Path(ellipseIn: CGRect(x: me.x - 7, y: me.y - 7, width: 14, height: 14)), with: .color(.cyan))
                }
                .frame(width: size.width * scale, height: size.height * scale)
                .background(Color(red: 0.02, green: 0.10, blue: 0.05))
                .overlay(Rectangle().stroke(.green, lineWidth: 2))
                HStack(spacing: 18) {
                    legend(.cyan, "You")
                    legend(.yellow, "Thirsty plant (\(GardenModel.plantCount - model.watered))")
                    legend(.red, "Pest (\(model.pests))")
                    legend(Color(red: 0.3, green: 0.9, blue: 0.5), "Bush")
                    legend(.purple, "Spiky vine")
                    legend(.white, "Gate")
                }
                Text(model.dadTime <= 10 ? "DAD IS COMING!" : "Dad's next check: about \(Int(model.dadTime)) seconds")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.dadTime <= 30 ? .red : .green)
                BigButton(title: "Close", symbol: "xmark", action: onClose)
            }
            .padding(24)
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(.green.opacity(0.6), lineWidth: 3))
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(text).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
    }
}
