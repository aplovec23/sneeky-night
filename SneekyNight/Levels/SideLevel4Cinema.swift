import SwiftUI
import Combine

/// Who can appear in a cinema show.
enum MovieActor {
    case you, brother, mom, dad, uncle, auntie, guide, dog, cat, rat, stranger
}

/// Where a cinema show is set.
enum MovieSet {
    case hills, hallway, street, kitchen, dungeon, roof, auntie, lobby
}

/// One of the ten shows. Every show runs for a full hour.
struct CinemaShow: Identifiable {
    let id: Int
    let title: String
    let tagline: String
    let symbol: String
    let color: Color
    let set: MovieSet
    let cast: [MovieActor]
    /// The story, one subtitle at a time. It plays through in chapters until the hour is up.
    let lines: [String]

    static let length = 3600.0
    static let reward = 1000

    static let all: [CinemaShow] = [
        CinemaShow(id: 1, title: "The Lantern Festival", tagline: "One night. One promise.", symbol: "moon.stars.fill", color: .orange,
                   set: .hills, cast: [.you, .guide, .dog],
                   lines: ["Every year, the lanterns rise over the river.", "This year, one kid is walking there alone.", "\"It's further than it looks,\" says the stranger with the lantern.",
                           "\"I don't mind far,\" says the kid.", "A dog falls into step beside them.", "The hills go on. So do they.",
                           "Somewhere ahead, the first lantern lifts into the sky.", "\"Almost,\" says the Guide. He always says almost."]),
        CinemaShow(id: 2, title: "Night of the Squeaky Toy", tagline: "It only takes one step.", symbol: "teddybear.fill", color: .pink,
                   set: .hallway, cast: [.you, .brother, .mom],
                   lines: ["The hallway is dark. The floor is covered in toys.", "One of them squeaks. Nobody knows which.", "\"Don't. Move,\" whispers the little brother.",
                           "A door opens. Slippers on the carpet.", "\"Who's up?\" says Mom, who is always up.", "They freeze like statues. Very bad statues.",
                           "Mom looks left. Mom looks right.", "SQUEAK.", "\"...It was the house,\" says the brother. Nobody believes him."]),
        CinemaShow(id: 3, title: "Dad vs. the Tomatoes", tagline: "He left the gate open. Once.", symbol: "leaf.fill", color: .green,
                   set: .hills, cast: [.dad, .dog, .dog],
                   lines: ["Dad grew seven perfect tomatoes.", "Dad also left the garden gate open.", "The dogs next door are not guard dogs. They are snack dogs.",
                           "Tomato one: gone. Tomato two: gone.", "\"Not the big one!\" The big one: gone.", "Dad builds a fence. The dogs admire it.",
                           "Dad builds a taller fence. The dogs admire that too.", "Next spring, Dad plants fourteen tomatoes. Just in case."]),
        CinemaShow(id: 4, title: "The Owl Who Winked", tagline: "Nobody knows why.", symbol: "bird.fill", color: .teal,
                   set: .roof, cast: [.you, .cat],
                   lines: ["There is an owl on the roof, by the chimney.", "It has lived there longer than the chimney.", "If you look at it, it winks.",
                           "Scientists have no explanation.", "The cat has an explanation, but the cat isn't talking.", "Some nights a star lands on the roof.",
                           "The owl looks at the star. The star looks at the owl.", "Wink."]),
        CinemaShow(id: 5, title: "Uncle's Car: The Movie", tagline: "She's old. But she runs.", symbol: "car.fill", color: .yellow,
                   set: .street, cast: [.uncle, .you, .stranger],
                   lines: ["Uncle's car is older than Uncle.", "It has one door that doesn't match.", "It has a radio that only plays one song.",
                           "\"She's never let me down,\" says Uncle.", "The car makes a noise like a kettle.", "\"That's normal,\" says Uncle.",
                           "The car makes a noise like a goose.", "\"That one's new,\" says Uncle. They drive on anyway."]),
        CinemaShow(id: 6, title: "Auntie and the Nine Cats", tagline: "There were only supposed to be two.", symbol: "cat.fill", color: .purple,
                   set: .auntie, cast: [.auntie, .cat, .cat, .cat],
                   lines: ["Auntie has two cats.", "That is what Auntie says.", "There is a cat on the stairs. There is a cat in the sink.",
                           "\"That one's just visiting,\" says Auntie.", "There is a cat asleep on the chores list.", "\"Don't wake him. He's had a long day.\"",
                           "By midnight there are nine.", "Auntie puts out nine bowls. She knew all along."]),
        CinemaShow(id: 7, title: "Rats! The Musical", tagline: "A snack for a song.", symbol: "music.note", color: .gray,
                   set: .street, cast: [.rat, .rat, .rat, .you],
                   lines: ["♪ We are the rats of the midnight street ♪", "♪ We take one snack, and we leave a treat ♪", "♪ A bow tie, a scarf, or a party hat ♪",
                           "♪ What could be fairer, friend, than that? ♪", "The kid checks their pockets. One snack short.", "And one pair of sunglasses richer.",
                           "♪ It isn't stealing, it's a trade ♪", "♪ That's how accessories are made! ♪"]),
        CinemaShow(id: 8, title: "Mom's Midnight Breakfast", tagline: "She gets up before the sun.", symbol: "frying.pan.fill", color: .red,
                   set: .kitchen, cast: [.mom, .you],
                   lines: ["It is very early. Or very late.", "Mom is cooking. Mom is humming.", "Mom cannot see what is behind her.",
                           "What is behind her is tiptoeing to the fridge.", "The fridge door opens. The little light comes on.", "Mom stops humming.",
                           "...Mom starts humming again.", "She left one extra pancake on the plate. She always does."]),
        CinemaShow(id: 9, title: "The Deep, Deep Dungeon", tagline: "It never ends.", symbol: "diamond.fill", color: .cyan,
                   set: .dungeon, cast: [.you, .guide],
                   lines: ["Under the house there is a cave.", "Under the cave there is another cave.", "The rocks glow. The orbs grow back.",
                           "\"How deep does it go?\" asks the kid.", "\"Nobody has ever found the bottom,\" says the Guide.", "\"Has anybody looked?\"",
                           "\"...I got as far as the shop,\" says the Guide.", "They keep walking. The orbs keep glowing."]),
        CinemaShow(id: 10, title: "The Night Shift", tagline: "Uncle's hotel never sleeps.", symbol: "building.2.fill", color: .indigo,
                   set: .lobby, cast: [.uncle, .stranger, .you],
                   lines: ["The hotel has twenty floors. Sometimes.", "The elevator has opinions.", "A guest asks for room 1204.",
                           "\"It was on the twelfth floor yesterday,\" says Uncle.", "The cleaner mops. The bellhop naps standing up.", "At 3 a.m. the lobby plant is watered.",
                           "Something behind the plant says \"thank you\".", "Uncle doesn't look. Uncle has worked nights for a long time."]),
    ]
}

/// Side Level 4: the cinema. Pick one of ten shows, pick a seat, and watch. Every show is one
/// hour long; your place in a show is remembered if you leave. Each time you watch one to the
/// end you get 1000 orbs.
struct CinemaView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void

    enum Stage: Equatable { case lobby, seats(Int), watching(Int) }

    @State private var stage: Stage = .lobby
    @State private var seat: (row: Int, col: Int)?
    @State private var elapsed = 0.0
    @State private var sinceSave = 0.0
    @State private var finished = false
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    static let rows = 6
    static let cols = 10

    var body: some View {
        FitToPhone(night: true) {
            ZStack {
                if !Device.isPhone { NightSky() }
                switch stage {
                case .lobby: lobby
                case .seats(let id): seats(show(id))
                case .watching(let id): watching(show(id))
                }
            }
        }
        .onReceive(tick) { _ in advance(0.5) }
        .onDisappear {
            keepPlace()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func show(_ id: Int) -> CinemaShow { CinemaShow.all.first { $0.id == id } ?? CinemaShow.all[0] }

    private func clock(_ seconds: Double) -> String {
        let whole = Int(max(0, seconds).rounded(.up))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    // MARK: Watching

    private func advance(_ dt: Double) {
        guard case .watching(let id) = stage, !finished else { return }
        elapsed += dt
        sinceSave += dt
        if elapsed >= CinemaShow.length {
            finished = true
            game.cinemaTime[id] = nil
            game.cinemaWatched.insert(id)
            game.orbs += CinemaShow.reward
            if game.cinemaWatched.count == CinemaShow.all.count { game.completedSide.insert(4) }
            UIApplication.shared.isIdleTimerDisabled = false
            Sound.win.play()
        } else if sinceSave >= 15 {
            keepPlace()
        }
    }

    /// Remembers how far into the show you are.
    private func keepPlace() {
        sinceSave = 0
        if case .watching(let id) = stage, !finished, elapsed > 1 { game.cinemaTime[id] = elapsed }
    }

    private func leave() {
        keepPlace()
        UIApplication.shared.isIdleTimerDisabled = false
        finished = false
        stage = .lobby
    }

    private func start(_ id: Int) {
        elapsed = game.cinemaTime[id] ?? 0
        sinceSave = 0
        finished = false
        // An hour is a long time: don't let the screen go to sleep in the middle of the film.
        UIApplication.shared.isIdleTimerDisabled = true
        stage = .watching(id)
    }

    // MARK: Lobby

    private var lobby: some View {
        VStack(spacing: 14) {
            ZStack {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onExit)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(RadialGradient(colors: [.white, .cyan], center: .center, startRadius: 1, endRadius: 12)).frame(width: 22)
                        Text("\(game.orbs)").font(.game(26, .heavy)).foregroundStyle(.cyan).monospacedDigit()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                }
                Text("The Cinema").font(.game(52, .heavy)).foregroundStyle(.white)
            }
            Text("Ten shows, each one hour long. Watch one to the end and you get \(CinemaShow.reward) orbs, every time. Watched \(game.cinemaWatched.count) of \(CinemaShow.all.count).")
                .font(.game(19, .semibold))
                .foregroundStyle(.white.opacity(0.85))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(206), spacing: 14), count: 5), spacing: 14) {
                ForEach(CinemaShow.all) { show in
                    poster(show)
                }
            }
            Spacer()
        }
        .padding(30)
    }

    private func poster(_ show: CinemaShow) -> some View {
        let watched = game.cinemaWatched.contains(show.id)
        let place = game.cinemaTime[show.id]
        return Button {
            SoundPlayer.shared.tap()
            seat = nil
            stage = .seats(show.id)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: show.symbol).font(.system(size: 46, weight: .bold)).frame(height: 60)
                Text(show.title).font(.game(19, .heavy)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7).frame(height: 48)
                Text(show.tagline).font(.game(13, .medium)).opacity(0.85).multilineTextAlignment(.center).lineLimit(2).frame(height: 34)
                Text(place.map { "Carry on · \(clock(CinemaShow.length - $0)) left" } ?? (watched ? "✓ Watched · watch again" : "1 hour"))
                    .font(.game(13, .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(watched || place != nil ? Palette.gold : .white.opacity(0.85), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(width: 206, height: 232)
            .background(LinearGradient(colors: [show.color.opacity(0.9), Color(red: 0.12, green: 0.10, blue: 0.24)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Picking a seat

    /// Other people already sitting down (the same seats every time for a show).
    private func taken(_ show: CinemaShow, _ row: Int, _ col: Int) -> Bool {
        (row * 7 + col * 13 + show.id * 5) % 10 < 3
    }

    private func seats(_ show: CinemaShow) -> some View {
        VStack(spacing: 14) {
            ZStack {
                HStack {
                    RoundIconButton(symbol: "chevron.left") { stage = .lobby }
                    Spacer()
                }
                Text("Pick your seat").font(.game(46, .heavy)).foregroundStyle(.white)
            }
            Text("\(show.title)  ·  1 hour").font(.game(22, .semibold)).foregroundStyle(Palette.gold)
            // The screen
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.white, Color(white: 0.75)], startPoint: .top, endPoint: .bottom))
                .frame(width: 620, height: 34)
                .overlay(Text("SCREEN").font(.game(15, .heavy)).foregroundStyle(.black.opacity(0.5)))
                .shadow(color: .white.opacity(0.6), radius: 18)
            VStack(spacing: 10) {
                ForEach(0..<Self.rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        Text(["A", "B", "C", "D", "E", "F"][row]).font(.game(18, .heavy)).foregroundStyle(.white.opacity(0.6)).frame(width: 24)
                        ForEach(0..<Self.cols, id: \.self) { col in
                            seatButton(show, row, col)
                        }
                    }
                }
            }
            HStack(spacing: 18) {
                legend(Color(red: 0.75, green: 0.18, blue: 0.22), "Free")
                legend(Color(white: 0.3), "Taken")
                legend(Palette.gold, "Yours")
            }
            if let seat {
                BigButton(title: "Sit in \(["A", "B", "C", "D", "E", "F"][seat.row])\(seat.col + 1) and start", symbol: "play.fill") { start(show.id) }
            } else {
                Text("Tap a red seat. The front rows are closer to the screen; the back rows see more of it.")
                    .font(.game(18, .semibold)).foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(30)
    }

    private func seatButton(_ show: CinemaShow, _ row: Int, _ col: Int) -> some View {
        let isTaken = taken(show, row, col)
        let mine = seat?.row == row && seat?.col == col
        return Button {
            SoundPlayer.shared.tap()
            seat = (row, col)
        } label: {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                    .fill(mine ? Palette.gold : isTaken ? Color(white: 0.3) : Color(red: 0.75, green: 0.18, blue: 0.22))
                    .frame(width: 50, height: 44)
                if isTaken { Circle().fill(Color(white: 0.12)).frame(width: 24).offset(y: -12) }
                if mine { Image(systemName: "person.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.black).offset(y: 10) }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(isTaken)
        .padding(.leading, col == 5 ? 26 : 0)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 20, height: 18)
            Text(text).font(.game(15, .semibold)).foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: The film

    private func watching(_ show: CinemaShow) -> some View {
        let row = seat?.row ?? 3, col = seat?.col ?? 4
        // Closer rows see a bigger screen; side seats see it from an angle.
        let scale = 1.12 - CGFloat(row) * 0.06
        let side = CGFloat(col) - 4.5
        return ZStack {
            // The heads are an overlay so that, however wide the rows are, they can't push the buttons off the screen.
            Color.black.ignoresSafeArea().overlay(alignment: .bottom) {
            // The rows of heads in front of you.
                VStack(spacing: -34) {
                    Spacer()
                    ForEach(0..<max(row, 1), id: \.self) { r in
                        HStack(spacing: 34 + CGFloat(r) * 10) {
                            ForEach(0..<9, id: \.self) { c in
                                Circle().fill(Color(white: 0.05)).frame(width: 70 + CGFloat(r) * 14)
                                    .opacity(taken(show, r, c) ? 1 : 0)
                            }
                        }
                        .offset(x: side * -10, y: 40)
                    }
                }
            }
            VStack(spacing: 0) {
                MovieScreen(show: show, elapsed: elapsed, look: game.look)
                    .frame(width: 900, height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.2), lineWidth: 6))
                    .shadow(color: .white.opacity(0.25), radius: 30)
                    .rotation3DEffect(.degrees(Double(side) * -3), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .scaleEffect(scale)
                    .offset(x: -side * 12)
                    .frame(height: 580)
                Spacer(minLength: 0)
            }
            .padding(.top, 60)
            VStack {
                HStack(spacing: 12) {
                    RoundIconButton(symbol: "chevron.left", action: leave)
                    Text("\(show.title)  ·  seat \(["A", "B", "C", "D", "E", "F"][row])\(col + 1)")
                        .font(.game(20)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("\(clock(CinemaShow.length - elapsed)) left")
                        .font(.game(22)).monospacedDigit().foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                Spacer()
            }
            .padding(20)
            if finished {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("THE END").font(.game(64, .heavy)).foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Circle().fill(RadialGradient(colors: [.white, .cyan], center: .center, startRadius: 1, endRadius: 16)).frame(width: 30)
                        Text("+\(CinemaShow.reward) orbs").font(.game(40, .heavy)).foregroundStyle(.cyan)
                    }
                    Text(game.cinemaWatched.count == CinemaShow.all.count ? "You've watched all ten shows!" : "\(game.cinemaWatched.count) of \(CinemaShow.all.count) shows watched.")
                        .font(.game(22, .semibold)).foregroundStyle(.white.opacity(0.85))
                    BigButton(title: "Back to the lobby", symbol: "ticket.fill", action: leave)
                }
            }
        }
    }
}

/// What's on the cinema screen: a set from the game, the cast walking about, and the story in subtitles.
struct MovieScreen: View {
    let show: CinemaShow
    let elapsed: Double
    let look: Look

    private static let lineSeconds = 14.0

    var body: some View {
        let beat = Int(elapsed / Self.lineSeconds)
        let chapter = beat / show.lines.count + 1
        let line = show.lines[beat % show.lines.count]
        // The first seconds of every chapter show a title card.
        let intoChapter = elapsed - Double((chapter - 1) * show.lines.count) * Self.lineSeconds
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ZStack(alignment: .topLeading) {
                    backdrop
                    ForEach(show.cast.indices, id: \.self) { i in
                        let phase = t * (0.16 + Double(i) * 0.05) + Double(i) * 2.1
                        let x = 700 + CGFloat(sin(phase)) * (430 - CGFloat(i) * 40)
                        actor(show.cast[i], right: cos(phase) > 0)
                            .anchored(at: CGPoint(x: x, y: 548 + CGFloat(i) * 16))
                    }
                }
                .frame(width: 1400, height: 700, alignment: .topLeading)
                // A slow pan, like a camera.
                .offset(x: CGFloat(sin(t * 0.07)) * 60)
                .scaleEffect(0.72)
                .frame(width: 900, height: 500)
                .clipped()
                // Film grain and letterbox bars
                Rectangle().fill(.white.opacity(0.03 + 0.02 * abs(sin(t * 23))))
                VStack {
                    Rectangle().fill(.black).frame(height: 34)
                    Spacer()
                    Rectangle().fill(.black).frame(height: 78)
                }
                VStack {
                    Spacer()
                    Text(line)
                        .font(.game(22, .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(width: 820, height: 62)
                        .padding(.bottom, 8)
                }
                if intoChapter < 4 {
                    Color.black
                    VStack(spacing: 10) {
                        Text(show.title).font(.game(46, .heavy)).foregroundStyle(.white)
                        Text(chapter == 1 ? show.tagline : "Part \(chapter)").font(.game(24, .semibold)).foregroundStyle(Palette.gold)
                    }
                }
            }
        }
        .frame(width: 900, height: 500)
    }

    @ViewBuilder private var backdrop: some View {
        switch show.set {
        case .hills:
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom).frame(width: 1400, height: 700)
                Circle().fill(Palette.moon).frame(width: 120).position(x: 1050, y: 150)
                Ellipse().fill(Color(red: 0.10, green: 0.22, blue: 0.20)).frame(width: 1900, height: 420).position(x: 600, y: 720)
                ForEach(0..<6, id: \.self) { i in
                    Circle().fill(Color.orange.opacity(0.8)).frame(width: 18).shadow(color: .orange, radius: 10)
                        .position(x: 200 + CGFloat(i) * 210, y: 240 - CGFloat(i % 3) * 60)
                }
            }
        case .hallway: HallwayWall(width: 1400)
        case .street: StreetScene(width: 1400)
        case .kitchen: KitchenWall(width: 1400)
        case .dungeon: DungeonWall(width: 1400)
        case .roof: RoofScene(width: 3400).offset(x: -900)
        case .auntie: AuntieWall(width: 1400, upstairs: false)
        case .lobby: LobbyWall(width: 1400)
        }
    }

    @ViewBuilder private func actor(_ who: MovieActor, right: Bool) -> some View {
        switch who {
        case .you: CharacterView(look: look, facingRight: right, walking: true)
        case .brother: CharacterView(look: SiblingBuddy.look, facingRight: right, walking: true).scaleEffect(0.8, anchor: .bottom)
        case .mom: MomView(stunned: false, walking: true).scaleEffect(x: right ? 1 : -1, y: 1)
        case .dad: DadView(stunned: false, walking: true, laughing: false).scaleEffect(x: right ? 1 : -1, y: 1)
        case .uncle: PersonView(outfit: .uncle, walking: true).scaleEffect(x: right ? 1 : -1, y: 1)
        case .auntie: AuntieView(walking: true).scaleEffect(x: right ? 1 : -1, y: 1)
        case .guide: GuideView(walking: true).scaleEffect(x: right ? 1 : -1, y: 1)
        case .dog: DogView(happy: true).scaleEffect(x: right ? 1 : -1, y: 1)
        case .cat: SleepingCatView(awake: true, facingRight: right)
        case .rat: RatView().scaleEffect(x: right ? 1 : -1, y: 1)
        case .stranger: PersonView(outfit: .stranger(2), walking: true).scaleEffect(x: right ? 1 : -1, y: 1)
        }
    }
}
