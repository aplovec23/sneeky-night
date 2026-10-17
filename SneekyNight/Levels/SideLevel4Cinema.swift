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

    /// The story: every line of every part, in order, with the part it belongs to (1, 2, 3…).
    /// The text is in `CinemaStories`. Nothing repeats: the lines are spread over the whole hour.
    var script: [(part: Int, text: String)] { Self.scripts[id] ?? [(1, "...")] }
    var partCount: Int { script.last?.part ?? 1 }
    /// How long each line has before the next one.
    var secondsPerLine: Double { Self.length / Double(max(script.count, 1)) }

    /// Which line is playing at a moment in the show, and how many seconds into it we are.
    func line(at time: Double) -> (index: Int, part: Int, text: String, into: Double, opensPart: Bool) {
        let all = script
        let index = min(max(Int(time / secondsPerLine), 0), all.count - 1)
        return (index, all[index].part, all[index].text, time - Double(index) * secondsPerLine,
                index == 0 || all[index - 1].part != all[index].part)
    }

    private static let scripts: [Int: [(part: Int, text: String)]] = {
        var result: [Int: [(part: Int, text: String)]] = [:]
        for (show, parts) in CinemaStories.all {
            result[show] = parts.enumerated().flatMap { n, lines in lines.map { (part: n + 1, text: $0) } }
        }
        return result
    }()

    /// Which of the film tunes plays during this show.
    var music: String {
        switch id {
        case 1, 5, 9: "filmAdventure"
        case 2, 3, 7: "filmFunny"
        case 4, 10: "filmMystery"
        default: "filmCosy"
        }
    }

    static let length = 3600.0
    static let reward = 1000

    static let all: [CinemaShow] = [
        CinemaShow(id: 1, title: "The Lantern Festival", tagline: "One night. One promise.", symbol: "moon.stars.fill", color: .orange,
                   set: .hills, cast: [.you, .guide, .dog]),
        CinemaShow(id: 2, title: "Night of the Squeaky Toy", tagline: "It only takes one step.", symbol: "teddybear.fill", color: .pink,
                   set: .hallway, cast: [.you, .brother, .mom]),
        CinemaShow(id: 3, title: "Dad vs. the Tomatoes", tagline: "He left the gate open. Once.", symbol: "leaf.fill", color: .green,
                   set: .hills, cast: [.dad, .dog, .dog]),
        CinemaShow(id: 4, title: "The Owl Who Winked", tagline: "Nobody knows why.", symbol: "bird.fill", color: .teal,
                   set: .roof, cast: [.you, .cat]),
        CinemaShow(id: 5, title: "Uncle's Car: The Movie", tagline: "She's old. But she runs.", symbol: "car.fill", color: .yellow,
                   set: .street, cast: [.uncle, .you, .stranger]),
        CinemaShow(id: 6, title: "Auntie and the Nine Cats", tagline: "There were only supposed to be two.", symbol: "cat.fill", color: .purple,
                   set: .auntie, cast: [.auntie, .cat, .cat, .cat]),
        CinemaShow(id: 7, title: "Rats! The Musical", tagline: "A snack for a song.", symbol: "music.note", color: .gray,
                   set: .street, cast: [.rat, .rat, .rat, .you]),
        CinemaShow(id: 8, title: "Mom's Midnight Breakfast", tagline: "She gets up before the sun.", symbol: "frying.pan.fill", color: .red,
                   set: .kitchen, cast: [.mom, .you]),
        CinemaShow(id: 9, title: "The Deep, Deep Dungeon", tagline: "It never ends.", symbol: "diamond.fill", color: .cyan,
                   set: .dungeon, cast: [.you, .guide]),
        CinemaShow(id: 10, title: "The Night Shift", tagline: "Uncle's hotel never sleeps.", symbol: "building.2.fill", color: .indigo,
                   set: .lobby, cast: [.uncle, .stranger, .you]),
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
    /// Seconds until someone in the audience next crunches popcorn.
    @State private var munchIn = 30.0
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
        .onAppear { SoundPlayer.shared.playFilmMusic("filmLobby") }
        .onDisappear {
            keepPlace()
            UIApplication.shared.isIdleTimerDisabled = false
            SoundPlayer.shared.stopFilmMusic()
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
        let partBefore = show(id).line(at: elapsed).part
        elapsed += dt
        sinceSave += dt
        // A little chime when a new part of the story begins, and now and then somebody eats popcorn.
        if elapsed < CinemaShow.length, show(id).line(at: elapsed).part != partBefore { Sound.chime.play(volume: 0.6) }
        munchIn -= dt
        if munchIn <= 0 {
            munchIn = .random(in: 35...80)
            Sound.popcorn.play(volume: 0.25)
        }
        if elapsed >= CinemaShow.length {
            finished = true
            game.cinemaTime[id] = nil
            game.cinemaWatched.insert(id)
            game.orbs += CinemaShow.reward
            if game.cinemaWatched.count == CinemaShow.all.count { game.completedSide.insert(4) }
            UIApplication.shared.isIdleTimerDisabled = false
            SoundPlayer.shared.playFilmMusic("filmLobby")
            Sound.applause.play()
            Sound.win.play(volume: 0.6)
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
        SoundPlayer.shared.playFilmMusic("filmLobby")
    }

    private func start(_ id: Int) {
        elapsed = game.cinemaTime[id] ?? 0
        sinceSave = 0
        finished = false
        // An hour is a long time: don't let the screen go to sleep in the middle of the film.
        UIApplication.shared.isIdleTimerDisabled = true
        munchIn = .random(in: 20...50)
        Sound.ticket.play()
        Sound.projector.play(volume: 0.8)
        SoundPlayer.shared.playFilmMusic(show(id).music)
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
            Sound.seat.play()
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
                TimelineView(.animation(minimumInterval: 1 / 15)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    VStack(spacing: -34) {
                        Spacer()
                        ForEach(0..<max(row, 1), id: \.self) { r in
                            HStack(spacing: 34 + CGFloat(r) * 10) {
                                ForEach(0..<9, id: \.self) { c in
                                    // Everybody shifts in their seat a little; now and then someone leans over to whisper.
                                    let fidget = sin(t * (0.5 + Double((r + c) % 4) * 0.13) + Double(r * 3 + c))
                                    Circle().fill(Color(white: 0.05)).frame(width: 70 + CGFloat(r) * 14)
                                        .opacity(taken(show, r, c) ? 1 : 0)
                                        .offset(x: CGFloat(fidget) * 5, y: CGFloat(abs(sin(t * 0.21 + Double(c)))) * 4)
                                }
                            }
                            .offset(x: side * -10, y: 40)
                        }
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
                    Text("\(show.title)  ·  part \(show.line(at: elapsed).part) of \(show.partCount)  ·  seat \(["A", "B", "C", "D", "E", "F"][row])\(col + 1)")
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

/// What's on the cinema screen: a set from the game, the cast acting the story out, and subtitles.
///
/// Every subtitle is one "beat". On each beat the camera picks a shot (wide, or closer in on one
/// of the cast), everyone walks to a new mark, and then does something there: hops, crouches,
/// taunts, looks around, or turns to whoever the camera is on. The sets move too: lanterns
/// rise, toys roll, steam drifts, orbs pulse.
struct MovieScreen: View {
    let show: CinemaShow
    let elapsed: Double
    let look: Look
    /// When `elapsed` last changed, so the picture can move smoothly between the half-second ticks.
    @State private var stamp = Date()

    /// How often the cast moves to new marks and the camera changes shot.
    static let beatSeconds = 14.0
    /// How long a subtitle stays up before the picture carries on without words.
    static let subtitleSeconds = 24.0

    /// A number from 0 to 1 that is always the same for the same show, actor and beat.
    private func roll(_ a: Int, _ b: Int) -> Double {
        let x = sin(Double(a * 127 + b * 311 + show.id * 71) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }

    private func ease(_ p: Double) -> Double {
        let q = min(max(p, 0), 1)
        return q * q * (3 - 2 * q)
    }

    /// Where actor `i` stands on beat `b`.
    private func mark(_ i: Int, _ b: Int) -> CGFloat {
        guard b >= 0 else { return 300 + CGFloat(i) * 260 }
        return 230 + CGFloat(roll(i, b)) * 940
    }

    /// The camera for a beat: how far it's zoomed in and what it's centred on.
    private func shot(_ b: Int) -> (zoom: CGFloat, centre: CGFloat, focus: Int) {
        let focus = Int(roll(99, b) * Double(show.cast.count)) % max(show.cast.count, 1)
        // Every fourth beat is a wide shot of everyone.
        if b % 4 == 0 || b < 0 { return (1, 700, focus) }
        return (1.08 + CGFloat(roll(55, b)) * 0.3, mark(focus, b), focus)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // The film's own clock, smoothed between ticks.
            let now = elapsed + min(0.5, max(0, ctx.date.timeIntervalSince(stamp)))
            let beat = Int(now / Self.beatSeconds)
            let p = now / Self.beatSeconds - Double(beat)
            // The story moves on one line at a time, and never goes back.
            let line = show.line(at: now)
            let shown = min(Self.subtitleSeconds, show.secondsPerLine - 1.5)
            let words = min(1, line.into / 0.8) * min(1, max(0, (shown - line.into) / 1.5))
            // The camera glides from the last shot to this one at the start of each beat.
            let from = shot(beat - 1), to = shot(beat)
            let glide = CGFloat(ease(p / 0.14))
            let zoom = from.zoom + (to.zoom - from.zoom) * glide
            let centre = from.centre + (to.centre - from.centre) * glide
            let scale = 0.72 * zoom
            let room = max(0, (1400 * scale - 900) / 2)
            ZStack {
                ZStack(alignment: .topLeading) {
                    backdrop
                    scenery(t)
                    ForEach(show.cast.indices, id: \.self) { i in
                        performer(i, beat: beat, p: p, t: t, focus: to.focus)
                    }
                }
                .frame(width: 1400, height: 700, alignment: .topLeading)
                .scaleEffect(scale)
                .offset(x: min(max((700 - centre) * scale, -room), room) + CGFloat(sin(t * 0.3)) * 6,
                        y: -(zoom - 1) * 95 + CGFloat(sin(t * 0.23)) * 3)
                .frame(width: 900, height: 500)
                .clipped()
                // Film grain, a flickering projector and letterbox bars
                Rectangle().fill(.white.opacity(0.03 + 0.02 * abs(sin(t * 23))))
                VStack {
                    Rectangle().fill(.black).frame(height: 34)
                    Spacer()
                    Rectangle().fill(.black).frame(height: 78)
                }
                VStack {
                    Spacer()
                    Text(line.text)
                        .font(.game(22, .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(width: 820, height: 62)
                        .padding(.bottom, 8)
                        // Each subtitle fades in, stays a while, and fades out.
                        .opacity(words)
                }
                if line.opensPart && line.into < 4 {
                    Color.black
                    VStack(spacing: 10) {
                        Text(show.title).font(.game(46, .heavy)).foregroundStyle(.white)
                        Text(line.part == 1 ? show.tagline : "Part \(line.part) of \(show.partCount)").font(.game(24, .semibold)).foregroundStyle(Palette.gold)
                    }
                    .scaleEffect(1 + CGFloat(line.into) * 0.02)
                }
            }
        }
        .frame(width: 900, height: 500)
        .onChange(of: elapsed) { _, _ in stamp = Date() }
    }

    /// One of the cast on this beat: walking to their mark, then acting.
    private func performer(_ i: Int, beat: Int, p: Double, t: Double, focus: Int) -> some View {
        let who = show.cast[i]
        let start = mark(i, beat - 1), end = mark(i, beat)
        // Different actors set off at slightly different moments, so they don't move like one machine.
        let delay = 0.03 + roll(i + 20, beat) * 0.12
        let travel = ease((p - delay) / 0.38)
        let x = start + (end - start) * CGFloat(travel)
        let moving = travel > 0.001 && travel < 0.999 && abs(end - start) > 24
        // What they do once they've arrived.
        let act = roll(i + 7, beat)
        let arrived = !moving && p > delay
        let hop = arrived && act < 0.25
        let crouch = arrived && act >= 0.25 && act < 0.42
        let taunt = arrived && act >= 0.42 && act < 0.55
        let glance = arrived && act >= 0.55 && act < 0.78
        var right = end >= start
        if arrived {
            let target = i == focus ? 700 : mark(focus, beat)
            right = glance ? sin(t * 1.6 + Double(i)) > 0 : target >= x
        }
        // A hop is a few quick bounces; small animals bounce along all the time.
        let small = who == .dog || who == .cat || who == .rat
        let lift = hop ? abs(sin(t * 7 + Double(i))) * 34 : small && moving ? abs(sin(t * 12)) * 8 : 0
        // The one the camera is on leans into it a little.
        let size: CGFloat = i == focus && arrived ? 1.05 : 1
        return actor(who, right: right, walking: moving, crouching: crouch, taunting: taunt, excited: hop || taunt)
            .scaleEffect(size, anchor: .bottom)
            .offset(y: -CGFloat(lift))
            .anchored(at: CGPoint(x: x, y: 548 + CGFloat(i) * 16))
    }

    /// Things in the set that move by themselves.
    @ViewBuilder private func scenery(_ t: Double) -> some View {
        switch show.set {
        case .hills:
            // Lanterns drifting up into the sky (only in the festival film; Dad's garden has fireflies instead)
            ForEach(0..<(show.id == 1 ? 9 : 0), id: \.self) { i in
                let rise = (t * (14 + Double(i % 3) * 5) + Double(i) * 80).truncatingRemainder(dividingBy: 560)
                RoundedRectangle(cornerRadius: 5).fill(Color.orange).frame(width: 16, height: 22)
                    .shadow(color: .orange, radius: 12)
                    .opacity(0.9 - rise / 700)
                    .position(x: 120 + CGFloat(i) * 150 + CGFloat(sin(t * 0.7 + Double(i))) * 16, y: 500 - CGFloat(rise))
            }
            ForEach(0..<(show.id == 1 ? 0 : 8), id: \.self) { i in
                Circle().fill(Color(red: 1, green: 0.95, blue: 0.5)).frame(width: 6)
                    .shadow(color: .yellow, radius: 6)
                    .opacity(abs(sin(t * 1.4 + Double(i) * 1.7)))
                    .position(x: 150 + CGFloat(i) * 160 + CGFloat(sin(t * 0.5 + Double(i))) * 30, y: 380 + CGFloat(cos(t * 0.4 + Double(i) * 2)) * 60)
            }
        case .hallway:
            // The toys that started all the trouble
            let roll = CGFloat((t * 110).truncatingRemainder(dividingBy: 1700))
            ToyCarView(facingRight: true).position(x: roll - 150, y: 596)
            ToyBallView().position(x: 1100 + CGFloat(sin(t * 0.9)) * 180, y: 604 - CGFloat(abs(sin(t * 3.1))) * 34)
        case .street:
            if show.id == 5 {
                // Uncle's car rattles past
                let drive = CGFloat((t * 190).truncatingRemainder(dividingBy: 2300))
                UncleCarArt(look: look, kidInside: true, uncleInside: true, lightsOn: true, wheelTurn: t * 300)
                    .scaleEffect(0.8)
                    .position(x: drive - 400, y: 470 + CGFloat(sin(t * 10)) * 2)
            }
            if show.id == 7 {
                notes(t)
            }
        case .kitchen:
            // Steam from the pan
            ForEach(0..<5, id: \.self) { i in
                let up = (t * 26 + Double(i) * 30).truncatingRemainder(dividingBy: 150)
                Circle().fill(.white.opacity(0.35 - up / 500)).frame(width: 18 + CGFloat(up) * 0.2)
                    .position(x: 620 + CGFloat(sin(t + Double(i))) * 12, y: 410 - CGFloat(up))
            }
        case .dungeon:
            // Orbs pulsing in the dark
            ForEach(0..<7, id: \.self) { i in
                let glow = 0.4 + 0.6 * abs(sin(t * 1.3 + Double(i) * 0.9))
                Circle().fill(RadialGradient(colors: [.white, [Color.cyan, .purple, .green][i % 3]], center: .center, startRadius: 1, endRadius: 14))
                    .frame(width: 22).shadow(color: .cyan, radius: 12 * glow).opacity(glow)
                    .position(x: 140 + CGFloat(i) * 190, y: i % 2 == 0 ? 500 : 440)
            }
        case .roof:
            // A star falling toward the roof, over and over
            let fall = (t * 0.25).truncatingRemainder(dividingBy: 1)
            Circle().fill(.yellow).frame(width: 14).shadow(color: .yellow, radius: 14)
                .position(x: 300 + CGFloat(fall) * 700, y: 60 + CGFloat(fall) * 400)
                .opacity(1 - fall * 0.6)
        case .auntie:
            // A ball of wool that never stays put
            Circle().fill(Color.pink).frame(width: 30)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2).padding(5))
                .rotationEffect(.degrees(t * 120))
                .position(x: 700 + CGFloat(sin(t * 0.6)) * 420, y: 600)
        case .lobby:
            // The chandeliers glint
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(Palette.gold)
                    .opacity(abs(sin(t * 1.7 + Double(i) * 1.3)))
                    .position(x: 200 + CGFloat(i) * 210, y: 150 + CGFloat(i % 2) * 60)
            }
        }
    }

    /// Music notes floating up, for the musical.
    private func notes(_ t: Double) -> some View {
        ForEach(0..<7, id: \.self) { i in
            let up = (t * 40 + Double(i) * 60).truncatingRemainder(dividingBy: 380)
            Image(systemName: i % 2 == 0 ? "music.note" : "music.quarternote.3")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle([Color.yellow, .pink, .cyan, .white][i % 4])
                .opacity(1 - up / 380)
                .position(x: 200 + CGFloat(i) * 170 + CGFloat(sin(t * 2 + Double(i))) * 20, y: 470 - CGFloat(up))
        }
    }

    @ViewBuilder private var backdrop: some View {
        switch show.set {
        case .hills:
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom).frame(width: 1400, height: 700)
                Circle().fill(Palette.moon).frame(width: 120).position(x: 1050, y: 150)
                Ellipse().fill(Color(red: 0.10, green: 0.22, blue: 0.20)).frame(width: 1900, height: 420).position(x: 600, y: 720)
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

    @ViewBuilder private func actor(_ who: MovieActor, right: Bool, walking: Bool, crouching: Bool, taunting: Bool, excited: Bool) -> some View {
        switch who {
        case .you: CharacterView(look: look, facingRight: right, walking: walking, crouching: crouching, taunting: taunting,
                                 expression: excited ? .happy : crouching ? .sneaky : nil)
        case .brother:
            CharacterView(look: SiblingBuddy.look, facingRight: right, walking: walking, crouching: crouching, taunting: taunting,
                          expression: excited ? .happy : crouching ? .sneaky : nil)
                .scaleEffect(0.8, anchor: .bottom)
        // On screen everyone's an actor: happy in the exciting bits, calm otherwise.
        case .mom: MomView(stunned: false, walking: walking, expression: excited ? .happy : .calm).scaleEffect(x: right ? 1 : -1, y: 1)
        // Dad laughs when he's pleased with himself.
        case .dad: DadView(stunned: false, walking: walking, laughing: excited, expression: .calm).scaleEffect(x: right ? 1 : -1, y: 1)
        case .uncle: PersonView(outfit: .uncle, walking: walking, expression: excited ? .surprised : .happy).scaleEffect(x: right ? 1 : -1, y: 1)
        case .auntie: AuntieView(walking: walking, expression: excited ? .surprised : .happy).scaleEffect(x: right ? 1 : -1, y: 1)
        case .guide: GuideView(walking: walking, expression: excited ? .surprised : .happy).scaleEffect(x: right ? 1 : -1, y: 1)
        case .dog: DogView(happy: excited || walking).scaleEffect(x: right ? 1 : -1, y: 1)
        // Cats curl up and sleep when nothing is happening.
        case .cat: SleepingCatView(awake: walking || excited || taunting, facingRight: right)
        case .rat: RatView().scaleEffect(x: right ? 1 : -1, y: 1)
        case .stranger: PersonView(outfit: .stranger(2), walking: walking, expression: excited ? .surprised : .cross).scaleEffect(x: right ? 1 : -1, y: 1)
        }
    }
}
