import SwiftUI

// The Level Maker's do-it-yourself parts: hazards you design (draw one or pick a sample, then
// set its hitbox and how much it hurts) and your own map (wall, wallpaper, floor and a drawing
// on the wall). Both are saved inside the level.

// MARK: - Your own hazards

/// A hazard made in the Hazard Maker. Placed in the level as items of kind `"custom:<id>"`.
struct CustomHazard: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = "My hazard"
    /// A sample picture (an SF Symbol). Nil: use the drawing instead.
    var sample: String? = "flame.fill"
    /// The sample's colour, from `DrawingPad.colors`.
    var color = 1
    /// Your own drawing (on the 720×430 pad), used when `sample` is nil.
    var drawing: [PadStroke] = []
    /// The hitbox on the floor: how wide, and how far back to front.
    var width: Double = 80
    var depth: Double = 30
    /// How tall it's drawn.
    var height: Double = 80
    /// Health it takes, in % of your full health. 0 = it doesn't hurt, but it's loud: Mom hears it.
    var damage: Double = 20
    /// Crouching past it is safe (jumping over it always is).
    var crouchSafe = false

    var kind: String { "custom:" + id }

    /// Pictures to start from.
    static let samples = ["flame.fill", "bolt.fill", "drop.fill", "snowflake", "tornado", "ladybug.fill", "ant.fill",
                          "leaf.fill", "cone.fill", "burst.fill", "hurricane", "trash.fill", "bandage.fill", "exclamationmark.triangle.fill", "fish.fill", "tortoise.fill"]
}

/// A hazard as drawn in the room: its sample or drawing, standing on the floor, with the hitbox
/// shown as a faint patch on the floor.
struct CustomHazardArt: View {
    let hazard: CustomHazard

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(Color.red.opacity(0.22)).frame(width: hazard.width, height: max(12, hazard.depth))
                .offset(y: max(12, hazard.depth) / 2)
            Group {
                if let sample = hazard.sample {
                    Image(systemName: sample)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(DrawingPad.colors[hazard.color % DrawingPad.colors.count])
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                } else {
                    StrokesView(strokes: hazard.drawing, trim: true)
                }
            }
            .frame(width: max(30, hazard.width * 1.1), height: hazard.height)
        }
        .frame(width: max(40, hazard.width * 1.2), height: hazard.height + max(12, hazard.depth) / 2, alignment: .bottom)
    }
}

/// Draws pad strokes scaled to fit the frame. `trim`: fit just the drawn part (no empty paper around it).
struct StrokesView: View {
    let strokes: [PadStroke]
    var trim = false

    var body: some View {
        Canvas { gc, size in
            let points = strokes.flatMap(\.points)
            guard !points.isEmpty else { return }
            let box: CGRect = {
                guard trim else { return CGRect(x: 0, y: 0, width: 720, height: 430) }
                let xs = points.map(\.x), ys = points.map(\.y)
                let r = CGRect(x: xs.min()!, y: ys.min()!, width: max(xs.max()! - xs.min()!, 1), height: max(ys.max()! - ys.min()!, 1))
                return r.insetBy(dx: -12, dy: -12)
            }()
            let k = min(size.width / box.width, size.height / box.height)
            let dx = (size.width - box.width * k) / 2 - box.minX * k
            let dy = (size.height - box.height * k) - box.minY * k   // stand on the bottom
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x * k + dx, y: first.y * k + dy))
                if stroke.points.count == 1 { path.addLine(to: CGPoint(x: first.x * k + dx + 0.1, y: first.y * k + dy)) }
                for p in stroke.points.dropFirst() { path.addLine(to: CGPoint(x: p.x * k + dx, y: p.y * k + dy)) }
                gc.stroke(path, with: .color(DrawingPad.colors[stroke.color % DrawingPad.colors.count]),
                          style: StrokeStyle(lineWidth: max(1.5, stroke.width * k), lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// The Hazard Maker: look (sample or drawing), name, hitbox, damage, crouch-safe.
struct HazardMakerView: View {
    @State var hazard: CustomHazard
    let onSave: (CustomHazard) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    @State private var drawing = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            HStack(alignment: .top, spacing: 26) {
                // Preview on a bit of floor
                VStack(spacing: 10) {
                    Text("Preview").font(.game(18, .heavy)).foregroundStyle(.white.opacity(0.7))
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.40, green: 0.28, blue: 0.20)).frame(width: 260, height: 90)
                        CustomHazardArt(hazard: hazard).padding(.bottom, 40)
                    }
                    .frame(width: 260, height: 300, alignment: .bottom)
                    .background(Color(red: 0.22, green: 0.18, blue: 0.32), in: RoundedRectangle(cornerRadius: 14))
                    Text("The red patch is the hitbox.").font(.game(14, .medium)).foregroundStyle(.white.opacity(0.6))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hazard Maker").font(.game(34, .heavy)).foregroundStyle(.white)
                    TextField("Name", text: $hazard.name)
                        .font(.game(20)).padding(.horizontal, 12).padding(.vertical, 6)
                        .frame(width: 300).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    Text("Look: pick a sample, or draw it yourself").font(.game(16, .heavy)).foregroundStyle(.white.opacity(0.8))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: 8), spacing: 6) {
                        ForEach(CustomHazard.samples, id: \.self) { s in
                            Button {
                                SoundPlayer.shared.tap()
                                hazard.sample = s
                            } label: {
                                Image(systemName: s).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 44, height: 40)
                                    .background(hazard.sample == s ? Palette.button : .white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(DrawingPad.colors.indices, id: \.self) { i in
                            Button {
                                SoundPlayer.shared.tap()
                                hazard.color = i
                            } label: {
                                Circle().fill(DrawingPad.colors[i]).frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(hazard.color == i ? Palette.gold : .white.opacity(0.4), lineWidth: hazard.color == i ? 4 : 1.5))
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Spacer()
                        Button {
                            SoundPlayer.shared.tap()
                            drawing = true
                        } label: {
                            Label(hazard.sample == nil ? "Redraw" : "Draw it", systemImage: "pencil.and.scribble")
                                .font(.game(16)).foregroundStyle(.white).lineLimit(1).fixedSize()
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(hazard.sample == nil ? Palette.button : Color.purple.opacity(0.7), in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                    slider("Hitbox width", value: $hazard.width, in: 30...300, unit: "")
                    slider("Hitbox depth", value: $hazard.depth, in: 12...140, unit: "")
                    slider("Height", value: $hazard.height, in: 30...260, unit: "")
                    slider("Damage", value: $hazard.damage, in: 0...100, unit: "%")
                    Text(hazard.damage == 0 ? "0%: it doesn't hurt, but it's loud. Touch it and Mom hears." : "Takes \(Int(hazard.damage))% of your health (more on harder modes). Jump over it to be safe.")
                        .font(.game(14, .medium)).foregroundStyle(.white.opacity(0.7))
                    Toggle("Crouching past it is safe", isOn: $hazard.crouchSafe)
                        .font(.game(17)).foregroundStyle(.white).tint(Palette.button).frame(width: 360)
                    HStack(spacing: 10) {
                        PillButton(title: "Cancel", color: .gray, action: onCancel)
                        if let onDelete { PillButton(title: "Delete", symbol: "trash.fill", color: .red, action: onDelete) }
                        PillButton(title: "Save", symbol: "checkmark", color: Palette.button) { onSave(hazard) }
                    }
                    .padding(.top, 4)
                }
                .frame(width: 440, alignment: .leading)
            }
            .padding(24)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Palette.gold.opacity(0.7), lineWidth: 3))
            if drawing {
                DrawingPad(strokes: hazard.drawing, title: "Draw your hazard") { strokes in
                    hazard.drawing = strokes
                    if !strokes.isEmpty { hazard.sample = nil }
                    drawing = false
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.game(16, .semibold)).foregroundStyle(.white).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: 1).tint(Palette.button).frame(width: 230)
            Text("\(Int(value.wrappedValue))\(unit)").font(.game(16, .heavy)).foregroundStyle(.white).monospacedDigit().frame(width: 50)
        }
    }
}

// MARK: - Your own map

/// "My map": a room you design. Colours, a wallpaper, a floor and a drawing on the wall.
struct CustomMap: Codable, Equatable {
    var wallTop = 8
    var wallBottom = 9
    var floor = 4
    /// 0 plain, then stripes, stars, hearts, bricks, dots, clouds.
    var wallpaper = 1
    /// 0 wood, 1 tiles, 2 carpet, 3 grass, 4 stone.
    var floorStyle = 0
    /// Drawn on the 720×430 pad; shown big on the wall, repeated along the room.
    var drawing: [PadStroke] = []

    static let colors: [Color] = [
        Color(red: 0.05, green: 0.06, blue: 0.20), Color(red: 0.22, green: 0.18, blue: 0.32), Color(red: 0.36, green: 0.22, blue: 0.30),
        Color(red: 0.20, green: 0.28, blue: 0.30), Color(red: 0.45, green: 0.30, blue: 0.20), Color(red: 0.25, green: 0.45, blue: 0.30),
        Color(red: 0.60, green: 0.20, blue: 0.25), Color(red: 0.85, green: 0.60, blue: 0.30), Color(red: 0.30, green: 0.30, blue: 0.55),
        Color(red: 0.45, green: 0.35, blue: 0.60), Color(red: 0.75, green: 0.75, blue: 0.80), Color(white: 0.15),
    ]
    static let wallpapers = ["Plain", "Stripes", "Stars", "Hearts", "Bricks", "Dots", "Clouds"]
    static let floors = ["Wood", "Tiles", "Carpet", "Grass", "Stone"]
}

/// The room drawn from a `CustomMap`.
struct CustomMapBackdrop: View {
    let map: CustomMap
    let width: CGFloat

    private func color(_ i: Int) -> Color { CustomMap.colors[abs(i) % CustomMap.colors.count] }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [color(map.wallTop), color(map.wallBottom)], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 545)
            wallpaper
            if !map.drawing.isEmpty {
                // Your drawing, big on the wall, every 1200 points along the room.
                ForEach(0..<max(1, Int(width / 1200) + 1), id: \.self) { i in
                    StrokesView(strokes: map.drawing)
                        .frame(width: 720 * 0.7, height: 430 * 0.7)
                        .position(x: CGFloat(i) * 1200 + 420, y: 260)
                }
            }
            Rectangle().fill(.black.opacity(0.22)).frame(width: width, height: 14).offset(y: 531)
            floor.frame(width: width, height: 155).clipped().offset(y: 545)
        }
        .frame(width: width, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private var wallpaper: some View {
        let ink = Color.white.opacity(0.08)
        switch map.wallpaper {
        case 1:
            ForEach(0..<Int(width / 60), id: \.self) { i in Rectangle().fill(ink).frame(width: 26, height: 530).offset(x: CGFloat(i) * 60) }
        case 2, 3, 5, 6:
            let symbol = ["", "", "star.fill", "heart.fill", "", "circle.fill", "cloud.fill"][map.wallpaper]
            ForEach(0..<Int(width / 120) * 4, id: \.self) { n in
                Image(systemName: symbol).font(.system(size: map.wallpaper == 5 ? 10 : map.wallpaper == 6 ? 34 : 18)).foregroundStyle(ink)
                    .position(x: CGFloat(n / 4) * 120 + (n % 2 == 0 ? 40 : 100), y: CGFloat(n % 4) * 120 + 70)
            }
        case 4:
            ForEach(0..<10, id: \.self) { row in
                Rectangle().fill(.black.opacity(0.15)).frame(width: width, height: 3).offset(y: CGFloat(row) * 54)
                ForEach(0..<Int(width / 110), id: \.self) { i in
                    Rectangle().fill(.black.opacity(0.15)).frame(width: 3, height: 54)
                        .offset(x: CGFloat(i) * 110 + (row % 2 == 0 ? 0 : 55), y: CGFloat(row) * 54)
                }
            }
        default: EmptyView()
        }
    }

    @ViewBuilder private var floor: some View {
        let base = color(map.floor)
        ZStack(alignment: .topLeading) {
            base
            switch map.floorStyle {
            case 1:
                ForEach(0..<(Int(width / 60) * 3), id: \.self) { n in
                    Rectangle().fill((n / 3 + n % 3) % 2 == 0 ? Color.white.opacity(0.12) : .black.opacity(0.08))
                        .frame(width: 60, height: 52).offset(x: CGFloat(n / 3) * 60, y: CGFloat(n % 3) * 52)
                }
            case 2:
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)).frame(width: width - 140, height: 100).offset(x: 70, y: 28)
            case 3:
                ForEach(0..<Int(width / 18), id: \.self) { i in
                    Capsule().fill(Color.green.opacity(0.35)).frame(width: 3, height: 12).offset(x: CGFloat(i) * 18, y: CGFloat((i * 37) % 130))
                }
            case 4:
                ForEach(0..<Int(width / 90) * 2, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.12)).frame(width: 80, height: 60)
                        .offset(x: CGFloat(n / 2) * 90 + (n % 2 == 0 ? 0 : 45), y: n % 2 == 0 ? 8 : 82)
                }
            default:
                ForEach(0..<Int(width / 110), id: \.self) { i in
                    Rectangle().fill(.black.opacity(0.10)).frame(width: 2, height: 155).offset(x: CGFloat(i) * 110)
                }
            }
        }
    }
}

/// The map editor: colours, wallpaper, floor, and a drawing for the wall.
struct MapMakerView: View {
    @State var map: CustomMap
    let onSave: (CustomMap) -> Void
    let onCancel: () -> Void
    @State private var drawing = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("My map").font(.game(34, .heavy)).foregroundStyle(.white)
                CustomMapBackdrop(map: map, width: 1300)
                    .frame(width: 1300, height: 700)
                    .scaleEffect(0.5, anchor: .topLeading)
                    .frame(width: 650, height: 350, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                colorRow("Wall (top)", $map.wallTop)
                colorRow("Wall (bottom)", $map.wallBottom)
                colorRow("Floor", $map.floor)
                chips("Wallpaper", CustomMap.wallpapers, $map.wallpaper)
                chips("Floor style", CustomMap.floors, $map.floorStyle)
                HStack(spacing: 10) {
                    Button {
                        SoundPlayer.shared.tap()
                        drawing = true
                    } label: {
                        Label(map.drawing.isEmpty ? "Draw on the wall" : "Redraw the wall", systemImage: "pencil.and.scribble")
                            .font(.game(17)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.purple.opacity(0.75), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Spacer()
                    PillButton(title: "Cancel", color: .gray, action: onCancel)
                    PillButton(title: "Use this map", symbol: "checkmark", color: Palette.button) { onSave(map) }
                }
            }
            .padding(24)
            .frame(width: 700)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Palette.gold.opacity(0.7), lineWidth: 3))
            if drawing {
                DrawingPad(strokes: map.drawing, title: "Draw on your wall") { strokes in
                    map.drawing = strokes
                    drawing = false
                }
            }
        }
    }

    private func colorRow(_ title: String, _ value: Binding<Int>) -> some View {
        HStack(spacing: 7) {
            Text(title).font(.game(16, .semibold)).foregroundStyle(.white).frame(width: 130, alignment: .leading)
            ForEach(CustomMap.colors.indices, id: \.self) { i in
                Button {
                    SoundPlayer.shared.tap()
                    value.wrappedValue = i
                } label: {
                    RoundedRectangle(cornerRadius: 6).fill(CustomMap.colors[i]).frame(width: 34, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(value.wrappedValue == i ? Palette.gold : .white.opacity(0.3), lineWidth: value.wrappedValue == i ? 3 : 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func chips(_ title: String, _ names: [String], _ value: Binding<Int>) -> some View {
        HStack(spacing: 7) {
            Text(title).font(.game(16, .semibold)).foregroundStyle(.white).frame(width: 130, alignment: .leading)
            ForEach(names.indices, id: \.self) { i in
                Button {
                    SoundPlayer.shared.tap()
                    value.wrappedValue = i
                } label: {
                    Text(names[i]).font(.game(14, .heavy)).foregroundStyle(value.wrappedValue == i ? .black : .white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(value.wrappedValue == i ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.15)), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// A compact button for the Level Maker's panels (never wraps its label).
struct PillButton: View {
    let title: String
    var symbol: String?
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Group {
                if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
            }
            .font(.game(19))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(color.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}
