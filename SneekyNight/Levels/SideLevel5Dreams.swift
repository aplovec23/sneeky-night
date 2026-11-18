import SwiftUI

/// Side Level 5: Dreams. You fell asleep, and every dream is different: a random room, a random
/// number of keys (loose or in boxes), random hazards and random dream people with odd things to
/// say. Find every key and get out through the door to wake up. It opens once every level is won.
/// Dreams are built as Level Maker levels, so they play by the same rules (`CustomLevelModel`).
/// Every dream you beat adds one to your streak, and each one after that is 1.01 × harder than the
/// last: a shorter clock, more hazards, and faster walkers, moving hazards and chasers.
enum DreamMaker {
    // A dream's name is random words: a describing word and a place, and half the time one more word
    // in front (so "Melting Lighthouse", or "Velvet Melting Lighthouse").
    static let describingWords = [
        "Floating", "Endless", "Sleepy", "Melting", "Whispering", "Glowing", "Upside-Down", "Forgotten", "Spinning", "Hollow",
        "Bouncy", "Starry", "Foggy", "Giant", "Tiny", "Silent", "Echoing", "Inside-Out", "Sticky", "Shiny",
        "Ticking", "Sideways", "Snoring", "Rainy", "Haunted", "Underwater", "Bubbling", "Rattling", "Dusty", "Wandering",
    ]
    static let places = [
        "Hallway", "Lobby", "Kitchen", "Staircase", "Garden", "Corridor", "Attic", "Library", "Classroom", "Castle",
        "Bathtub", "Forest", "Moon", "Cupboard", "Elevator", "Carnival", "Swamp", "Bakery", "Tunnel", "Aquarium",
        "Rooftop", "Station", "Maze", "Playground", "Lighthouse", "Greenhouse", "Basement", "Theatre", "Treehouse", "Bus",
    ]
    static let extraWords = [
        "Purple", "Velvet", "Fizzy", "Golden", "Crooked", "Wobbly", "Ticklish", "Midnight", "Paper", "Jelly",
        "Glass", "Cloudy", "Candy", "Backwards", "Humming", "Marshmallow", "Silver", "Squeaky", "Pickled", "Electric",
    ]

    /// A brand-new dream name: random words, with a 50/50 chance of one more.
    static func randomName() -> String {
        var words = [describingWords.randomElement()!, places.randomElement()!]
        if Bool.random() { words.insert(extraWords.randomElement()!, at: 0) }
        return words.joined(separator: " ")
    }
    private static let lines = [
        "Is this a dream? It must be. The clocks are melting.", "Have you seen my left shoe? It ran away.",
        "The keys are hiding. They're shy tonight.", "Wake up! ...No, wait. Find the door first.",
        "I'm not really here. Neither are you!", "Shh. The furniture is listening.",
        "If you see a giant duck, wave. He's friendly.", "The door is always at the end. Always.",
        "Grandpa says hello. He's in a different dream.", "Everything tastes like blue in here.",
    ]
    private static let momLines = ["Who's dreaming so loudly?!", "Back to sleep... inside your dream!", "I'm dreaming that you're awake!"]
    private static let dadLines = ["Even in dreams, no running in the house!", "Hey! This is MY dream, kiddo!"]

    /// How much harder a dream is with this many dreams already beaten in a row.
    static func hardness(streak: Int) -> Double { pow(1.01, Double(streak)) }

    /// A brand-new random dream. `hardness` 1 is an ordinary one.
    static func make(hardness: Double = 1) -> CustomLevel {
        var level = CustomLevel()
        level.name = randomName()
        level.theme = Int.random(in: 0..<CustomLevel.themes.count)
        // The background is made up from this number: every dream gets its own.
        level.dreamSeed = Int.random(in: 1...2_000_000_000)
        level.width = Double([2400, 2800, 3200, 3600, 4000].randomElement()!)
        level.seconds = max(30, (Double.random(in: 100...170) * Difficulty.current.timeScale / hardness).rounded())
        let w = level.width
        var items: [CustomItem] = [
            CustomItem(kind: "start", x: 200, y: 620),
            CustomItem(kind: "exit", x: w - 150, y: 545),
        ]
        func floorY() -> Double { Double.random(in: 565...680) }
        // Spread things out along the room so nothing lands on the start or the door.
        var spots = Array(stride(from: 460.0, to: w - 320, by: 130)).shuffled()
        func nextX() -> Double { spots.isEmpty ? Double.random(in: 460...(w - 320)) : spots.removeLast() }

        let keys = Int.random(in: 2...5)
        for k in 0..<keys {
            if k % 2 == 0 {
                items.append(CustomItem(kind: "key", x: nextX(), y: floorY()))
            } else {
                items.append(CustomItem(kind: "box", x: nextX(), y: floorY(), hasKey: true))
            }
        }
        for _ in 0..<Int.random(in: 2...5) { items.append(CustomItem(kind: "box", x: nextX(), y: floorY())) }
        for _ in 0..<Int.random(in: 1...3) { items.append(CustomItem(kind: ["closet", "plant"].randomElement()!, x: nextX(), y: 545)) }
        for _ in 0..<Int.random(in: 1...3) { items.append(CustomItem(kind: "picture", x: nextX(), y: 545)) }
        if Bool.random() { items.append(CustomItem(kind: "dog", x: nextX(), y: floorY())) }
        if Bool.random() { items.append(CustomItem(kind: "crate", x: nextX(), y: floorY())) }

        // Hazards: ordinary ones, and now and then lava or a laser.
        let hazards = ["chair", "table", "lamp", "cans", "car", "spikes", "stranger"]
        let hazardCount = (Double(Int.random(in: 4...9)) * hardness).rounded()
        for _ in 0..<Int(hazardCount) { items.append(CustomItem(kind: hazards.randomElement()!, x: nextX(), y: floorY())) }
        if Int.random(in: 0..<3) == 0 { items.append(CustomItem(kind: "lava", x: nextX(), y: floorY())) }
        if Int.random(in: 0..<4) == 0 { items.append(CustomItem(kind: "laser", x: nextX(), y: 545)) }

        // Dream people with odd things to say, and sometimes Mom or Dad (or a guard).
        let talkers = ["ghost", "friend", "guide", "uncle", "brother"].shuffled()
        for who in talkers.prefix(Int.random(in: 1...3)) {
            items.append(CustomItem(kind: who, x: nextX(), y: floorY(), text: lines.randomElement()!))
        }
        if Bool.random() { items.append(CustomItem(kind: "mom", x: nextX(), y: 545, text: momLines.randomElement()!)) }
        if Int.random(in: 0..<5) < 2 { items.append(CustomItem(kind: "dad", x: nextX(), y: floorY(), text: dadLines.randomElement()!)) }
        if Int.random(in: 0..<4) == 0 { items.append(CustomItem(kind: "guard", x: nextX(), y: floorY(), text: "No dreaming in this corridor!")) }
        level.items = items
        return level
    }
}

/// A dream's background, made up from its seed by a randomizer: the colours of the sky and the
/// floor, a pattern on the wall (dots, stripes, checks, stars, waves or hills), a moon or planets,
/// things floating in the air (clocks, keys, fish, teddies...) and what the floor is made of.
/// The same seed always makes the same picture, so it doesn't change while you play.
struct DreamBackdrop: View {
    let seed: Int
    let width: CGFloat

    static let floaters = ["clock.fill", "key.fill", "star.fill", "moon.fill", "cloud.fill", "sparkles", "fish.fill",
                           "teddybear.fill", "cup.and.saucer.fill", "door.left.hand.closed", "umbrella.fill", "balloon.fill",
                           "lightbulb.fill", "bed.double.fill", "music.note", "leaf.fill", "bird.fill", "hare.fill", "tortoise.fill",
                           "paperplane.fill", "gift.fill", "crown.fill", "shoe.fill", "lamp.floor.fill"]

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: UInt64(seed))
            func r() -> Double { Double(rng.next()) }
            func between(_ a: Double, _ b: Double) -> Double { a + (b - a) * r() }
            let w = size.width
            let wallBottom: CGFloat = 545

            // The sky (or the wall): two random colours, darker at the top.
            let hue = r()
            let hue2 = (hue + between(0.1, 0.6)).truncatingRemainder(dividingBy: 1)
            let top = Color(hue: hue, saturation: between(0.4, 0.85), brightness: between(0.16, 0.38))
            let low = Color(hue: hue2, saturation: between(0.3, 0.75), brightness: between(0.38, 0.68))
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: wallBottom)),
                     with: .linearGradient(Gradient(colors: [top, low]), startPoint: .zero, endPoint: CGPoint(x: 0, y: wallBottom)))

            // A pattern over it.
            let ink = Color(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.3, brightness: 1).opacity(between(0.08, 0.2))
            switch Int(r() * 6) {
            case 0:
                // Polka dots
                let gap = between(60, 140), dot = between(8, 26)
                var y = gap / 2
                var row = 0
                while y < wallBottom {
                    var x = row % 2 == 0 ? gap / 2 : gap
                    while x < w { ctx.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: .color(ink)); x += gap }
                    y += gap; row += 1
                }
            case 1:
                // Stripes, straight or leaning
                let gap = between(50, 130), lean = r() < 0.5 ? 0 : between(-180, 180)
                var x = -abs(lean)
                while x < w + abs(lean) {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + gap / 2, y: 0))
                    p.addLine(to: CGPoint(x: x + gap / 2 + lean, y: wallBottom)); p.addLine(to: CGPoint(x: x + lean, y: wallBottom))
                    ctx.fill(p, with: .color(ink)); x += gap
                }
            case 2:
                // Checks
                let side = between(60, 120)
                for i in 0..<Int(w / side) + 1 {
                    for j in 0..<Int(wallBottom / side) + 1 where (i + j) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: Double(i) * side, y: Double(j) * side, width: side, height: side)), with: .color(ink))
                    }
                }
            case 3:
                // A sky full of stars
                for _ in 0..<Int(w / 18) {
                    let s = between(1.5, 4.5)
                    ctx.fill(Path(ellipseIn: CGRect(x: r() * w, y: r() * (wallBottom - 60), width: s, height: s)), with: .color(.white.opacity(between(0.4, 0.95))))
                }
            case 4:
                // Waves
                let rows = Int(between(4, 9)), height = between(14, 40), length = between(120, 300)
                for k in 0..<rows {
                    var p = Path()
                    let base = wallBottom * (Double(k) + 0.5) / Double(rows)
                    p.move(to: CGPoint(x: 0, y: base))
                    var x = 0.0
                    while x <= w { p.addLine(to: CGPoint(x: x, y: base + sin(x / length * .pi * 2 + Double(k)) * height)); x += 20 }
                    ctx.stroke(p, with: .color(ink), lineWidth: between(4, 12))
                }
            default:
                // Far-away hills, one row behind another
                for layer in 0..<3 {
                    var p = Path()
                    let base = wallBottom - 40 - Double(layer) * between(40, 90)
                    p.move(to: CGPoint(x: 0, y: wallBottom))
                    var x = 0.0
                    let bump = between(40, 140), span = between(200, 500)
                    while x <= w + span { p.addLine(to: CGPoint(x: x, y: base - abs(sin(x / span * .pi + Double(layer))) * bump)); x += 25 }
                    p.addLine(to: CGPoint(x: w, y: wallBottom)); p.closeSubpath()
                    ctx.fill(p, with: .color(Color(hue: hue2, saturation: 0.4, brightness: 0.2 + Double(layer) * 0.08).opacity(0.75)))
                }
            }

            // A moon, a sun or a few planets.
            let bodies = Int(between(1, 4))
            for _ in 0..<bodies {
                let d = between(50, 190)
                let rect = CGRect(x: r() * (w - d), y: between(20, 220), width: d, height: d)
                let shade = Color(hue: r(), saturation: between(0.1, 0.6), brightness: between(0.75, 1))
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: -d * 0.25, dy: -d * 0.25)), with: .color(shade.opacity(0.12)))
                ctx.fill(Path(ellipseIn: rect), with: .color(shade))
                if r() < 0.4 {
                    // A ring, like Saturn
                    ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -d * 0.35, dy: d * 0.35)), with: .color(shade.opacity(0.8)), lineWidth: 4)
                }
            }

            // Things floating in the air, the size of furniture or of a bird.
            let kinds = (0..<Int(between(3, 7))).map { _ in Self.floaters[Int(r() * Double(Self.floaters.count)) % Self.floaters.count] }
            for _ in 0..<Int(w / between(110, 220)) {
                let name = kinds[Int(r() * Double(kinds.count)) % kinds.count]
                let s = between(28, 110)
                var symbol = ctx.resolve(Image(systemName: name))
                symbol.shading = .color(Color(hue: r(), saturation: between(0.3, 0.8), brightness: between(0.7, 1)).opacity(between(0.35, 0.8)))
                var turned = ctx
                let centre = CGPoint(x: r() * w, y: between(60, wallBottom - 70))
                turned.translateBy(x: centre.x, y: centre.y)
                turned.rotate(by: .degrees(between(-35, 35)))
                turned.draw(symbol, in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
            }

            // The floor: a random colour, made of planks, tiles, grass, clouds or a carpet.
            let floorColour = Color(hue: r(), saturation: between(0.25, 0.7), brightness: between(0.3, 0.6))
            let floorRect = CGRect(x: 0, y: wallBottom, width: w, height: size.height - wallBottom)
            ctx.fill(Path(floorRect), with: .color(floorColour))
            ctx.fill(Path(CGRect(x: 0, y: wallBottom - 6, width: w, height: 6)), with: .color(.black.opacity(0.25)))
            let lines = Color.black.opacity(0.14)
            switch Int(r() * 5) {
            case 0:
                var x = 0.0
                while x < w { ctx.fill(Path(CGRect(x: x, y: wallBottom, width: 2, height: floorRect.height)), with: .color(lines)); x += between(70, 140) }
            case 1:
                let side = between(50, 90)
                for i in 0..<Int(w / side) + 1 {
                    for j in 0..<Int(floorRect.height / side) + 1 where (i + j) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: Double(i) * side, y: wallBottom + Double(j) * side, width: side, height: side)), with: .color(.white.opacity(0.1)))
                    }
                }
            case 2:
                for _ in 0..<Int(w / 6) {
                    let x = r() * w, y = wallBottom + r() * floorRect.height, h = between(6, 16)
                    var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + between(-4, 4), y: y - h))
                    ctx.stroke(p, with: .color(Color(hue: 0.3, saturation: 0.6, brightness: 0.5).opacity(0.5)), lineWidth: 2)
                }
            case 3:
                for _ in 0..<Int(w / 60) {
                    let d = between(40, 110)
                    ctx.fill(Path(ellipseIn: CGRect(x: r() * w, y: wallBottom + r() * (floorRect.height - d / 2), width: d * 1.6, height: d / 2)), with: .color(.white.opacity(0.18)))
                }
            default:
                for k in 0..<4 {
                    ctx.fill(Path(CGRect(x: 0, y: wallBottom + 12 + Double(k) * 38, width: w, height: 8)), with: .color(.white.opacity(0.08)))
                }
            }
        }
        .frame(width: width, height: 700)
    }
}

/// The dream's light: a purple haze over the room, with Zs and little stars drifting up.
struct DreamHaze: View {
    let width: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color.purple.opacity(0.22), Color.indigo.opacity(0.12), Color.pink.opacity(0.16)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: width, height: 700)
                ForEach(0..<Int(width / 160), id: \.self) { i in
                    let rise = (t * 0.05 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                    Text(i % 3 == 0 ? "z" : i % 3 == 1 ? "Z" : "✦")
                        .font(.game(CGFloat(14 + (i % 4) * 6), .heavy))
                        .foregroundStyle(.white.opacity(0.5 * (1 - rise)))
                        .position(x: CGFloat(i) * 160 + 60 + CGFloat(sin(t + Double(i))) * 20, y: 640 - CGFloat(rise) * 560)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct DreamLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    @State private var model: CustomLevelModel?
    @State private var dreams = 0

    var body: some View {
        ZStack {
            if let model {
                CustomLevelStage(model: model, onExit: onExit, dream: true).id(dreams)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear { if model == nil { newDream() } }
        .onDisappear { model?.engine.stop() }
    }

    /// Falls asleep again: a brand-new random dream, a little harder for every dream in your streak.
    private func newDream() {
        model?.engine.stop()
        let hardness = DreamMaker.hardness(streak: game.dreamStreak)
        let made = CustomLevelModel(level: DreamMaker.make(hardness: hardness))
        made.hardness = CGFloat(hardness)
        made.reset()
        made.titleExtra = streakText
        // Leaving a dream before you wake up ends the streak too.
        made.onExit = { [weak made] in
            if made?.over == false { loseStreak() }
            onExit()
        }
        made.onLose = { loseStreak() }
        made.winTitle = "You woke up!"
        made.onWin = { [weak made] in
            game.finishSide(5)
            game.award(.dreamer)
            game.dreamStreak += 1
            game.dreamBest = max(game.dreamBest, game.dreamStreak)
            let next = DreamMaker.hardness(streak: game.dreamStreak)
            made?.titleExtra = streakText
            made?.winMessage = "You got out of \"\(made?.level.name ?? "the dream")\".\nDream streak: \(game.dreamStreak) (best \(game.dreamBest)). "
                + "The next dream is ×\(String(format: "%.2f", next)) harder."
        }
        made.onPlayAgain = { newDream() }
        made.belt.configure(game: game, engine: made.engine)
        made.apply(skills: game.skills)
        made.engine.onDefaultInteract = { [weak made] in made?.talkToBrother() }
        made.engine.start()
        dreams += 1
        model = made
    }

    private var streakText: String {
        game.dreamStreak == 0 ? "" : "  ·  streak \(game.dreamStreak) (×\(String(format: "%.2f", DreamMaker.hardness(streak: game.dreamStreak))))"
    }

    private func loseStreak() {
        guard game.dreamStreak > 0 else { return }
        game.dreamStreak = 0
        model?.titleExtra = ""
    }
}
