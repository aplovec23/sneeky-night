import SwiftUI

/// One line drawn on the pad.
struct PadStroke: Codable {
    var color: Int
    var width: Double
    var points: [CGPoint]
}

/// Paper from your brother's room: draw with your finger. The picture is kept on the device,
/// so it's still there the next time you pick up the paper.
struct DrawingPad: View {
    let onDone: () -> Void

    @State private var strokes: [PadStroke] = DrawingPad.saved()
    @State private var current: PadStroke?
    @State private var color = 0
    @State private var width = 6.0

    static let colors: [Color] = [.black, .red, .orange, .yellow, .green, .blue, .purple, .pink, .brown, .white]
    private static let key = "drawing.strokes"
    private static let paper = CGSize(width: 720, height: 430)

    static func saved() -> [PadStroke] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PadStroke].self, from: data)) ?? []
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(strokes), forKey: Self.key)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "pencil.and.scribble").foregroundStyle(Palette.gold)
                    Text("Draw something!")
                    Spacer()
                    tool("Undo", "arrow.uturn.backward", .gray) {
                        if !strokes.isEmpty { strokes.removeLast() }
                    }
                    tool("New page", "doc.fill", Color(red: 0.7, green: 0.3, blue: 0.3)) { strokes = [] }
                    tool("Done", "checkmark", Palette.button) {
                        save()
                        onDone()
                    }
                }
                .font(.game(30, .heavy))
                .foregroundStyle(.white)

                Canvas { gc, _ in
                    for stroke in strokes + (current.map { [$0] } ?? []) {
                        var path = Path()
                        guard let first = stroke.points.first else { continue }
                        path.move(to: first)
                        // A single tap leaves a dot.
                        if stroke.points.count == 1 { path.addLine(to: CGPoint(x: first.x + 0.1, y: first.y)) }
                        for point in stroke.points.dropFirst() { path.addLine(to: point) }
                        gc.stroke(path, with: .color(Self.colors[stroke.color % Self.colors.count]),
                                  style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: Self.paper.width, height: Self.paper.height)
                .background(Color(red: 1.0, green: 0.98, blue: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.6, green: 0.5, blue: 0.4), lineWidth: 3))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if current == nil { current = PadStroke(color: color, width: width, points: []) }
                            current?.points.append(value.location)
                        }
                        .onEnded { _ in
                            if let current { strokes.append(current) }
                            current = nil
                        }
                )

                HStack(spacing: 10) {
                    ForEach(Self.colors.indices, id: \.self) { i in
                        Button {
                            SoundPlayer.shared.tap()
                            color = i
                        } label: {
                            Circle()
                                .fill(Self.colors[i])
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(color == i ? Palette.gold : .white.opacity(0.4), lineWidth: color == i ? 5 : 2))
                                .scaleEffect(color == i ? 1.12 : 1)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Spacer()
                    ForEach([3.0, 6.0, 12.0, 22.0], id: \.self) { size in
                        Button {
                            SoundPlayer.shared.tap()
                            width = size
                        } label: {
                            Circle()
                                .fill(.white)
                                .frame(width: size + 6, height: size + 6)
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(width == size ? 0.3 : 0.1), in: Circle())
                                .overlay(Circle().stroke(width == size ? Palette.gold : .clear, lineWidth: 3))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(24)
            .frame(width: Self.paper.width + 48)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
        }
    }

    private func tool(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.game(18))
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(color.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// The stack of paper and crayons next to the toy chest.
struct PaperStackView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                    .frame(width: 62, height: 8)
                    .rotationEffect(.degrees(Double(i % 2 == 0 ? -3 : 4)))
                    .offset(y: -CGFloat(i) * 6)
            }
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill([Color.red, .blue, .green, .orange][i]).frame(width: 6, height: 30)
                        .rotationEffect(.degrees(Double(i - 1) * 9))
                }
            }
            .offset(x: 22, y: -28)
            Image(systemName: "scribble").font(.system(size: 20, weight: .bold)).foregroundStyle(.purple).offset(x: -8, y: -30)
        }
        .frame(width: 90, height: 70, alignment: .bottom)
    }
}
