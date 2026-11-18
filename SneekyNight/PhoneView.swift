import SwiftUI

/// The Phone (a boosting item from Ion's shop): press O in a level. It works almost like a real
/// phone, except it can't call anyone: Notes you can type in, and three minigames (Snake, Memory
/// and Moon Catch). The level waits while it's open. Notes and best scores are kept in the save file.
struct PhoneView: View {
    @Environment(GameState.self) private var game
    let onClose: () -> Void
    @State private var app: App = .home

    enum App { case home, notes, snake, memory, moon }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                // The notch and the clock
                HStack {
                    Text(Date.now, style: .time).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    Image(systemName: "battery.75")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .overlay(Capsule().fill(.black).frame(width: 90, height: 24).padding(.top, 8), alignment: .top)
                Group {
                    switch app {
                    case .home: home
                    case .notes: NotesApp()
                    case .snake: SnakeGame()
                    case .memory: MemoryGame()
                    case .moon: MoonCatchGame()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The home bar: back to the home screen, or away if you're already there.
                Button {
                    SoundPlayer.shared.tap()
                    if app == .home { onClose() } else { app = .home }
                } label: {
                    Capsule().fill(.white.opacity(0.8)).frame(width: 120, height: 6).padding(14)
                }
            }
            .frame(width: 340, height: 620)
            .background(LinearGradient(colors: [Color(red: 0.15, green: 0.12, blue: 0.35), Color(red: 0.35, green: 0.18, blue: 0.45)],
                                       startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 44))
            .overlay(RoundedRectangle(cornerRadius: 44).stroke(Color(white: 0.85), lineWidth: 8))
            .shadow(color: .black.opacity(0.5), radius: 20)
        }
    }

    private var home: some View {
        VStack(spacing: 22) {
            Text("Not for calls.\nNotes and games only.").font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6)).padding(.top, 30)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 18), count: 3), spacing: 22) {
                icon("Notes", "note.text", .yellow) { app = .notes }
                icon("Snake", "point.topleft.down.to.point.bottomright.curvepath.fill", .green) { app = .snake }
                icon("Memory", "square.grid.3x3.fill", .orange) { app = .memory }
                icon("Moon Catch", "moon.stars.fill", .indigo) { app = .moon }
                icon("Phone", "phone.fill", .gray) {}
                    .overlay(alignment: .topTrailing) { Image(systemName: "xmark.circle.fill").foregroundStyle(.red).offset(x: -10) }
            }
            Spacer()
        }
    }

    private func icon(_ name: String, _ symbol: String, _ color: Color, open: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            open()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 16))
                Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: Notes

private struct NotesApp: View {
    @Environment(GameState.self) private var game
    @State private var editing: Int?
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(editing == nil ? "Notes" : "Note").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                Spacer()
                if editing == nil {
                    Button {
                        game.phoneNotes.insert("", at: 0)
                        editing = 0
                        text = ""
                    } label: { Image(systemName: "square.and.pencil").font(.system(size: 22)).foregroundStyle(.yellow) }
                } else {
                    Button("Done") { finish() }.font(.system(size: 17, weight: .semibold)).foregroundStyle(.yellow)
                }
            }
            if editing != nil {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(red: 1, green: 0.97, blue: 0.8), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
                Button("Delete note", role: .destructive) {
                    if let n = editing, n < game.phoneNotes.count { game.phoneNotes.remove(at: n) }
                    editing = nil
                }
                .font(.system(size: 15, weight: .semibold))
            } else if game.phoneNotes.isEmpty {
                Text("No notes yet. Tap the pencil to write one.").foregroundStyle(.white.opacity(0.6)).font(.system(size: 15))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(game.phoneNotes.indices, id: \.self) { n in
                            Button {
                                editing = n
                                text = game.phoneNotes[n]
                            } label: {
                                Text(game.phoneNotes[n].isEmpty ? "New note" : game.phoneNotes[n])
                                    .lineLimit(2)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color(red: 1, green: 0.97, blue: 0.8), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .onDisappear { finish() }
    }

    private func finish() {
        guard let n = editing else { return }
        if n < game.phoneNotes.count {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { game.phoneNotes.remove(at: n) } else { game.phoneNotes[n] = text }
        }
        editing = nil
    }
}

// MARK: Snake

private struct SnakeGame: View {
    @Environment(GameState.self) private var game
    private static let size = 14
    @State private var snake: [CGPoint] = [CGPoint(x: 6, y: 7), CGPoint(x: 5, y: 7), CGPoint(x: 4, y: 7)]
    @State private var direction = CGPoint(x: 1, y: 0)
    @State private var nextDirection = CGPoint(x: 1, y: 0)
    @State private var food = CGPoint(x: 10, y: 7)
    @State private var alive = true
    @State private var started = false

    private var score: Int { snake.count - 3 }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Snake").font(.system(size: 24, weight: .bold))
                Spacer()
                Text("\(score)  ·  best \(game.phoneBest["snake"] ?? 0)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.white)
            board
                .gesture(DragGesture(minimumDistance: 12).onEnded { drag in
                    let d = drag.translation
                    turn(abs(d.width) > abs(d.height) ? CGPoint(x: d.width > 0 ? 1 : -1, y: 0) : CGPoint(x: 0, y: d.height > 0 ? 1 : -1))
                })
            if !alive || !started {
                Button(alive ? "Start" : "Play again") { restart() }
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.green)
            }
            // Arrow buttons, for anyone who'd rather tap than swipe
            VStack(spacing: 4) {
                arrow("chevron.up", CGPoint(x: 0, y: -1))
                HStack(spacing: 40) {
                    arrow("chevron.left", CGPoint(x: -1, y: 0))
                    arrow("chevron.right", CGPoint(x: 1, y: 0))
                }
                arrow("chevron.down", CGPoint(x: 0, y: 1))
            }
        }
        .padding(18)
        .task(id: started) {
            while started && alive && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(max(70, 160 - score * 4)))
                step()
            }
        }
    }

    private var board: some View {
        let cell: CGFloat = 19
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(red: 0.62, green: 0.75, blue: 0.35))
            ForEach(snake.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.12, green: 0.2, blue: 0.08).opacity(i == 0 ? 1 : 0.85))
                    .frame(width: cell - 2, height: cell - 2)
                    .offset(x: snake[i].x * cell + 1, y: snake[i].y * cell + 1)
            }
            Circle().fill(Color(red: 0.12, green: 0.2, blue: 0.08)).frame(width: cell - 6)
                .offset(x: food.x * cell + 3, y: food.y * cell + 3)
            if !alive {
                Text("Game over!").font(.system(size: 22, weight: .heavy)).foregroundStyle(.black)
                    .frame(width: cell * CGFloat(Self.size), height: cell * CGFloat(Self.size))
            }
        }
        .frame(width: cell * CGFloat(Self.size), height: cell * CGFloat(Self.size))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func arrow(_ symbol: String, _ way: CGPoint) -> some View {
        Button { turn(way) } label: {
            Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                .frame(width: 48, height: 40).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func turn(_ way: CGPoint) {
        if !started { started = true }
        // No turning straight back into yourself.
        if way.x != -direction.x || way.y != -direction.y { nextDirection = way }
    }

    private func restart() {
        snake = [CGPoint(x: 6, y: 7), CGPoint(x: 5, y: 7), CGPoint(x: 4, y: 7)]
        direction = CGPoint(x: 1, y: 0)
        nextDirection = direction
        food = CGPoint(x: 10, y: 7)
        alive = true
        started = true
    }

    private func step() {
        direction = nextDirection
        let n = CGFloat(Self.size)
        let head = CGPoint(x: snake[0].x + direction.x, y: snake[0].y + direction.y)
        if head.x < 0 || head.y < 0 || head.x >= n || head.y >= n || snake.dropLast().contains(head) {
            alive = false
            Sound.buzz.play(volume: 0.5)
            if score > (game.phoneBest["snake"] ?? 0) { game.phoneBest["snake"] = score }
            return
        }
        snake.insert(head, at: 0)
        if head == food {
            Sound.star.play(volume: 0.5)
            var spot: CGPoint
            repeat { spot = CGPoint(x: .random(in: 0..<Self.size), y: .random(in: 0..<Self.size)) } while snake.contains(spot)
            food = spot
        } else {
            snake.removeLast()
        }
    }
}

// MARK: Memory

private struct MemoryGame: View {
    @Environment(GameState.self) private var game
    private static let symbols = ["moon.fill", "star.fill", "flame.fill", "leaf.fill", "bolt.fill", "heart.fill"]
    @State private var cards: [String] = (symbols + symbols).shuffled()
    @State private var up: Set<Int> = []
    @State private var matched: Set<Int> = []
    @State private var moves = 0
    @State private var busy = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Memory").font(.system(size: 24, weight: .bold))
                Spacer()
                Text("\(moves) moves").font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.white)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(66), spacing: 10), count: 4), spacing: 10) {
                ForEach(cards.indices, id: \.self) { i in
                    let shown = up.contains(i) || matched.contains(i)
                    Button { flip(i) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(shown ? Color.white : Color.orange)
                            if shown {
                                Image(systemName: cards[i]).font(.system(size: 28, weight: .bold)).foregroundStyle(.purple)
                            } else {
                                Image(systemName: "questionmark").font(.system(size: 24, weight: .heavy)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 66, height: 80)
                        .opacity(matched.contains(i) ? 0.55 : 1)
                    }
                    .disabled(shown || busy)
                }
            }
            if matched.count == cards.count {
                Text("All pairs in \(moves) moves!  Best: \(game.phoneBest["memory"] ?? moves)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.yellow)
                Button("Play again") {
                    cards = (Self.symbols + Self.symbols).shuffled()
                    up = []
                    matched = []
                    moves = 0
                }
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(18)
    }

    private func flip(_ i: Int) {
        Sound.click.play(volume: 0.5)
        up.insert(i)
        guard up.count == 2 else { return }
        moves += 1
        let pair = Array(up)
        if cards[pair[0]] == cards[pair[1]] {
            matched.formUnion(pair)
            up = []
            Sound.star.play(volume: 0.5)
            if matched.count == cards.count {
                let best = game.phoneBest["memory"] ?? Int.max
                if moves < best { game.phoneBest["memory"] = moves }
            }
        } else {
            busy = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                up = []
                busy = false
            }
        }
    }
}

// MARK: Moon Catch

private struct MoonCatchGame: View {
    @Environment(GameState.self) private var game
    @State private var spot = CGPoint(x: 140, y: 160)
    @State private var caught = 0
    @State private var timeLeft = 0.0
    @State private var playing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Moon Catch").font(.system(size: 24, weight: .bold))
                Spacer()
                Text("\(caught)  ·  best \(game.phoneBest["moon"] ?? 0)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.white)
            Text(playing ? "\(Int(timeLeft.rounded(.up))) seconds" : "Tap the moon as many times as you can in 20 seconds.")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.05, green: 0.06, blue: 0.2))
                if playing {
                    Button {
                        caught += 1
                        Sound.star.play(volume: 0.4)
                        spot = CGPoint(x: .random(in: 10...230), y: .random(in: 10...290))
                    } label: {
                        Image(systemName: "moon.fill").font(.system(size: 36)).foregroundStyle(.yellow).shadow(color: .yellow, radius: 8)
                    }
                    .offset(x: spot.x, y: spot.y)
                }
            }
            .frame(width: 290, height: 350)
            if !playing {
                Button(caught > 0 ? "Play again" : "Start") {
                    caught = 0
                    timeLeft = 20
                    playing = true
                }
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.yellow)
            }
        }
        .padding(18)
        .task(id: playing) {
            while playing && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                timeLeft -= 0.1
                if timeLeft <= 0 {
                    playing = false
                    if caught > (game.phoneBest["moon"] ?? 0) { game.phoneBest["moon"] = caught }
                }
            }
        }
    }
}
