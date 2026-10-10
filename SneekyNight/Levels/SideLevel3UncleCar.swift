import SwiftUI
import Combine

/// Side Level 3: nothing to solve. A short scene behind the hotel, then you sit in the back of
/// Uncle's car while he drives to the city where Auntie lives (she knows where Grandpa is).
/// Still in the car after 10 minutes? You get a few scenes from Level 6, "Auntie's House",
/// and the side level counts as finished.
struct UncleCarView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void

    enum Stage { case boarding, driving, preview }

    @State private var stage: Stage = .boarding
    /// Seconds since this stage began.
    @State private var clock = 0.0
    @State private var line = 0
    @State private var lineAge = 0.0
    @State private var slide = 0

    /// How long the ride takes before the Level 6 scenes.
    static let rideSeconds = 600.0
    static let boardingSeconds = 13.0
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    static let chatter = [
        "Seatbelt on? Good. Auntie's city is about ten minutes away.",
        "Your Auntie knows where Grandpa is. She always knows everything.",
        "Don't tell your mother I drove you. ...She'll know anyway. She always does.",
        "This car is older than you are. Older than me, maybe.",
        "See those lights? That's the river. The festival is on the other side.",
        "When I was your age, your Grandpa took ME to the Lantern Festival.",
        "Auntie makes the best hot chocolate. Don't tell your dad I said that.",
        "Are we there yet? No. Stop asking. ...You didn't ask? Sorry. Habit.",
        "You're very quiet back there. Thinking about Grandpa?",
        "He'll be so surprised to see you. He always said you'd find him.",
        "Look for a tall, thin house with a yellow door. That's Auntie's.",
        "Not far now. Stay awake, kiddo.",
    ]

    static let previews: [(title: String, text: String, symbol: String)] = [
        ("Ten minutes later...", "The car slows down. Uncle switches off the engine in front of a tall, thin house with a yellow door.", "car.fill"),
        ("Auntie's house", "Every window is dark except one. Somebody is still awake at the very top.", "house.fill"),
        ("\"You came all this way?\"", "Auntie opens the door in her dressing gown. She doesn't look surprised at all. \"Come in. Quietly. The cats are asleep.\"", "door.left.hand.open"),
        ("The locked study", "Upstairs is a room Auntie keeps locked. On the wall: a map, covered in pins, and a bundle of Grandpa's letters.", "map.fill"),
        ("Level 6: Auntie's House", "Auntie knows where Grandpa is... but she won't just tell you. First, there are chores. Play Level 6 to find out!", "cat.fill"),
    ]

    var body: some View {
        FitToPhone {
            ZStack {
                switch stage {
                case .boarding: boarding
                case .driving: driving
                case .preview: preview
                }
                VStack {
                    HStack {
                        RoundIconButton(symbol: "house.fill", action: onExit)
                        Spacer()
                        Text(title)
                            .font(.game(26))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.45), in: Capsule())
                        Spacer()
                        if stage == .boarding {
                            Button {
                                SoundPlayer.shared.tap()
                                start(.driving)
                            } label: {
                                Text("Skip").font(.game(22)).foregroundStyle(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(.black.opacity(0.45), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        } else {
                            Color.clear.frame(width: 60, height: 60)
                        }
                    }
                    Spacer()
                }
                .padding(24)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onReceive(tick) { _ in advance(0.1) }
    }

    private var title: String {
        switch stage {
        case .boarding: "Side Level 3 · Behind the Hotel"
        case .driving: "Side Level 3 · Uncle's Car"
        case .preview: "A look at Level 6"
        }
    }

    private func start(_ next: Stage) {
        stage = next
        clock = 0
        line = 0
        lineAge = 0
        if next == .preview {
            slide = 0
            game.completedSide.insert(3)
            Sound.win.play()
        }
    }

    private func advance(_ dt: Double) {
        clock += dt
        switch stage {
        case .boarding:
            if clock >= Self.boardingSeconds {
                Sound.door.play()
                start(.driving)
            }
        case .driving:
            // Uncle says something new every 22 seconds (or when you tap him).
            lineAge += dt
            if lineAge > 22 { nextLine() }
            if clock >= Self.rideSeconds { start(.preview) }
        case .preview: break
        }
    }

    private func nextLine() {
        line = (line + 1) % Self.chatter.count
        lineAge = 0
    }

    // MARK: Behind the hotel

    private var boarding: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let ground = h * 0.78
            // You and Uncle walk from the staff door to the car, then get in.
            let walk = min(max((clock - 1.5) / 7, 0), 1)
            let inCar = clock > 9.5
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom)
                // The back wall of the hotel
                Rectangle().fill(Color(red: 0.30, green: 0.18, blue: 0.22)).frame(width: w * 0.62, height: ground).offset(y: 0)
                ForEach(0..<8, id: \.self) { row in
                    Rectangle().fill(.black.opacity(0.12)).frame(width: w * 0.62, height: 3).offset(y: CGFloat(row) * ground / 8)
                }
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.20, green: 0.24, blue: 0.30)).frame(width: 110, height: 220).position(x: w * 0.16, y: ground - 110)
                Text("STAFF ONLY").font(.game(14, .heavy)).foregroundStyle(.yellow).position(x: w * 0.16, y: ground - 240)
                Circle().fill(RadialGradient(colors: [.yellow.opacity(0.5), .clear], center: .center, startRadius: 4, endRadius: 150))
                    .frame(width: 300).position(x: w * 0.16, y: ground - 280)
                // Bins
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.18, green: 0.36, blue: 0.26)).frame(width: 150, height: 110).position(x: w * 0.36, y: ground - 55)
                // The ground
                Rectangle().fill(Color(red: 0.20, green: 0.20, blue: 0.26)).frame(width: w, height: h - ground).offset(y: ground)
                // The car, waiting with its lights on
                UncleCarArt(look: game.look, kidInside: inCar, uncleInside: inCar, lightsOn: true)
                    .position(x: w * 0.76, y: ground - 70)
                if !inCar {
                    PersonView(outfit: .uncle, walking: walk > 0 && walk < 1)
                        .scaleEffect(0.9, anchor: .bottom)
                        .position(x: w * (0.22 + 0.42 * walk), y: ground - 112)
                    CharacterView(look: game.look, facingRight: true, walking: walk > 0 && walk < 1)
                        .scaleEffect(1.15, anchor: .bottom)
                        .position(x: w * (0.14 + 0.44 * walk), y: ground - 90)
                }
                caption(clock < 4 ? "Behind the hotel, Uncle's old car is waiting."
                        : clock < 9.5 ? "Uncle: \"She's old, but she runs. Hop in the back, kiddo.\""
                        : "You climb into the back seat. The engine coughs... and starts.")
                    .position(x: w / 2, y: h * 0.9)
            }
        }
    }

    // MARK: The drive

    private var driving: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let road = h * 0.72
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom)
                    Circle().fill(Palette.moon).frame(width: 100).shadow(color: Palette.moon.opacity(0.7), radius: 30).position(x: w * 0.8, y: h * 0.18)
                    // Far hills, then a city skyline that slowly gets closer, then trees and lamp posts rushing by.
                    scroll(t, speed: 12, spacing: 520, w: w) { _ in
                        Ellipse().fill(Color(red: 0.12, green: 0.16, blue: 0.30)).frame(width: 620, height: 260)
                    }
                    .offset(y: road - 110)
                    scroll(t, speed: 30, spacing: 150, w: w) { i in
                        Rectangle().fill(Color(red: 0.10, green: 0.10, blue: 0.22))
                            .frame(width: 90, height: CGFloat(80 + (i * 37) % 120))
                            .overlay(alignment: .top) {
                                Rectangle().fill(.yellow.opacity(0.7)).frame(width: 8, height: 8).offset(x: CGFloat((i * 13) % 50) - 25, y: 16)
                            }
                    }
                    .frame(height: 200, alignment: .bottom)
                    .offset(y: road - 200)
                    .opacity(min(1, 0.25 + clock / Self.rideSeconds))
                    scroll(t, speed: 260, spacing: 330, w: w) { i in
                        if i % 3 == 0 {
                            ZStack(alignment: .top) {
                                Rectangle().fill(Color(white: 0.2)).frame(width: 7, height: 190)
                                Circle().fill(.yellow).frame(width: 18).shadow(color: .yellow, radius: 14)
                            }
                        } else {
                            ZStack(alignment: .bottom) {
                                Rectangle().fill(Color(red: 0.25, green: 0.16, blue: 0.10)).frame(width: 12, height: 60)
                                Circle().fill(Color(red: 0.10, green: 0.28, blue: 0.18)).frame(width: 90).offset(y: -40)
                            }
                        }
                    }
                    .frame(height: 190, alignment: .bottom)
                    .offset(y: road - 190)
                    // The road
                    Rectangle().fill(Color(red: 0.17, green: 0.17, blue: 0.22)).frame(width: w, height: h - road).offset(y: road)
                    scroll(t, speed: 520, spacing: 170, w: w) { _ in
                        Rectangle().fill(.white.opacity(0.55)).frame(width: 80, height: 7)
                    }
                    .offset(y: road + (h - road) * 0.52)
                    // The car, bumping along
                    UncleCarArt(look: game.look, kidInside: true, uncleInside: true, lightsOn: true, wheelTurn: t * 360)
                        .scaleEffect(1.25, anchor: .bottom)
                        .position(x: w * 0.42, y: road - 78 + CGFloat(sin(t * 9)) * 2)
                        .onTapGesture {
                            SoundPlayer.shared.tap()
                            nextLine()
                        }
                    SpeechBubble(text: "Uncle: \(Self.chatter[line])", tint: .orange)
                        .position(x: w * 0.5, y: road - 330)
                        .id(line)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) { rideBar.padding(.bottom, 26) }
            .animation(.easeInOut(duration: 0.3), value: line)
        }
    }

    /// Scenery that slides past: `make(i)` is drawn every `spacing` points, moving left at `speed`.
    private func scroll<Item: View>(_ t: Double, speed: Double, spacing: CGFloat, w: CGFloat, @ViewBuilder make: @escaping (Int) -> Item) -> some View {
        let count = Int(w / spacing) + 3
        let travelled = t * speed
        let first = Int(floor(travelled / Double(spacing)))
        let shift = CGFloat(travelled.truncatingRemainder(dividingBy: Double(spacing)))
        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<count, id: \.self) { n in
                make(abs(first + n)).frame(width: spacing, alignment: .bottom)
            }
        }
        .frame(width: w, alignment: .leading)
        .offset(x: -shift)
    }

    private var rideBar: some View {
        let left = max(0, Self.rideSeconds - clock)
        let whole = Int(left.rounded(.up))
        return VStack(spacing: 8) {
            Text("Auntie's city: \(whole / 60):\(String(format: "%02d", whole % 60)) to go   ·   tap the car to hear Uncle")
                .font(.game(20, .semibold))
                .foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(Palette.gold).frame(width: 520 * min(1, clock / Self.rideSeconds))
            }
            .frame(width: 520, height: 10)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: Level 6 scenes

    private var preview: some View {
        let scene = Self.previews[slide]
        return ZStack {
            NightSky()
            VStack(spacing: 18) {
                auntiesHouse(lit: slide >= 1, doorOpen: slide == 2)
                    .frame(height: 300)
                HStack(spacing: 12) {
                    Image(systemName: scene.symbol).foregroundStyle(Palette.gold)
                    Text(scene.title)
                }
                .font(.game(40, .heavy))
                .foregroundStyle(.white)
                Text(scene.text)
                    .font(.game(24, .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(width: 720)
                    .fixedSize(horizontal: false, vertical: true)
                if slide < Self.previews.count - 1 {
                    BigButton(title: "Next", symbol: "chevron.right") { slide += 1 }
                } else {
                    BigButton(title: "Back to the menu", symbol: "house.fill", action: onExit)
                }
                Text("\(slide + 1) / \(Self.previews.count)")
                    .font(.game(16, .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 70)
        }
    }

    /// Auntie's tall, thin house with the yellow door.
    private func auntiesHouse(lit: Bool, doorOpen: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.26, green: 0.22, blue: 0.40)).frame(width: 170, height: 250)
            Triangle().fill(Color(red: 0.36, green: 0.20, blue: 0.30)).frame(width: 200, height: 70).offset(y: -250)
            VStack(spacing: 22) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(0..<2, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(lit && row == 0 && col == 1 ? Color.yellow.opacity(0.9) : Color(red: 0.10, green: 0.09, blue: 0.20))
                                .frame(width: 40, height: 44)
                        }
                    }
                }
            }
            .offset(y: -84)
            RoundedRectangle(cornerRadius: 4)
                .fill(doorOpen ? Color(red: 1, green: 0.9, blue: 0.6) : Color(red: 0.95, green: 0.78, blue: 0.2))
                .frame(width: 44, height: 70)
            if doorOpen {
                PersonView(outfit: .worker(1)).scaleEffect(0.26, anchor: .bottom).offset(y: -2)
            }
            UncleCarArt(look: game.look, kidInside: slide == 0, uncleInside: slide == 0, lightsOn: slide == 0)
                .scaleEffect(0.55, anchor: .bottom)
                .offset(x: 250)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.game(26, .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .frame(maxWidth: 820)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
    }
}

/// Uncle's old car from the side, with whoever is inside showing through the windows.
struct UncleCarArt: View {
    let look: Look
    var kidInside = false
    var uncleInside = false
    var lightsOn = false
    /// Degrees the wheels have turned.
    var wheelTurn = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            if lightsOn {
                Triangle().fill(LinearGradient(colors: [.yellow.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 260).rotationEffect(.degrees(-90)).offset(x: 310, y: 40)
            }
            // Roof and windows
            RoundedRectangle(cornerRadius: 40).fill(Color(red: 0.62, green: 0.42, blue: 0.16)).frame(width: 250, height: 90).offset(x: -14, y: -72)
            RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.55, green: 0.80, blue: 0.95).opacity(0.55)).frame(width: 206, height: 56).offset(x: -14, y: -92)
            // You in the back seat, Uncle at the wheel
            if kidInside {
                CharacterView(look: look, facingRight: true)
                    .scaleEffect(0.62, anchor: .top)
                    .frame(width: 70, height: 50, alignment: .top)
                    .clipped()
                    .offset(x: -70, y: -106)
            }
            if uncleInside {
                PersonView(outfit: .uncle)
                    .scaleEffect(0.5, anchor: .top)
                    .frame(width: 70, height: 52, alignment: .top)
                    .clipped()
                    .offset(x: 28, y: -104)
            }
            Rectangle().fill(Color(red: 0.62, green: 0.42, blue: 0.16)).frame(width: 8, height: 56).offset(x: -18, y: -92)
            // Body
            RoundedRectangle(cornerRadius: 30).fill(Color(red: 0.70, green: 0.48, blue: 0.18)).frame(width: 390, height: 92).offset(y: -22)
            Rectangle().fill(.black.opacity(0.15)).frame(width: 390, height: 4).offset(y: -62)
            Circle().fill(lightsOn ? Color.yellow : Color(white: 0.8)).frame(width: 20).offset(x: 184, y: -70)
            Circle().fill(Color.red.opacity(0.85)).frame(width: 14).offset(x: -188, y: -72)
            // A dent and a mismatched door: she's old
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.55, green: 0.55, blue: 0.50)).frame(width: 86, height: 64).offset(x: -60, y: -36)
            HStack(spacing: 176) {
                wheel
                wheel
            }
        }
        .frame(width: 400, height: 190, alignment: .bottom)
    }

    private var wheel: some View {
        ZStack {
            Circle().fill(Color(white: 0.1)).frame(width: 76)
            Circle().fill(Color(white: 0.6)).frame(width: 32)
            Rectangle().fill(Color(white: 0.25)).frame(width: 30, height: 4)
            Rectangle().fill(Color(white: 0.25)).frame(width: 4, height: 30)
        }
        .rotationEffect(.degrees(wheelTurn))
    }
}
