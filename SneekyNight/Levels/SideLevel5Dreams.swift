import SwiftUI

/// Side Level 5: Dreams. You fell asleep, and every dream is different: a random room, a random
/// number of keys (loose or in boxes), random hazards and random dream people with odd things to
/// say. Find every key and get out through the door to wake up. It opens once every level is won.
/// Dreams are built as Level Maker levels, so they play by the same rules (`CustomLevelModel`).
enum DreamMaker {
    private static let names = [
        "The Upside-Down Hallway", "The Endless Lobby", "Cloud Kitchen", "Candy Street", "Mom's Giant Slippers",
        "The Ticking Room", "Grandpa's Lantern Field", "A Very Long Corridor", "The Dungeon of Pillows", "Night Bus to Nowhere",
        "The Floating Garden", "Tomorrow's Classroom", "The Room That Hums", "Puddle Town", "The Staircase That Isn't",
    ]
    private static let lines = [
        "Is this a dream? It must be. The clocks are melting.", "Have you seen my left shoe? It ran away.",
        "The keys are hiding. They're shy tonight.", "Wake up! ...No, wait. Find the door first.",
        "I'm not really here. Neither are you!", "Shh. The furniture is listening.",
        "If you see a giant duck, wave. He's friendly.", "The door is always at the end. Always.",
        "Grandpa says hello. He's in a different dream.", "Everything tastes like blue in here.",
    ]
    private static let momLines = ["Who's dreaming so loudly?!", "Back to sleep... inside your dream!", "I'm dreaming that you're awake!"]
    private static let dadLines = ["Even in dreams, no running in the house!", "Hey! This is MY dream, kiddo!"]

    /// A brand-new random dream.
    static func make() -> CustomLevel {
        var level = CustomLevel()
        level.name = names.randomElement()!
        level.theme = Int.random(in: 0..<CustomLevel.themes.count)
        level.width = Double([2400, 2800, 3200, 3600, 4000].randomElement()!)
        level.seconds = (Double.random(in: 100...170) * Difficulty.current.timeScale).rounded()
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
        for _ in 0..<Int.random(in: 4...9) { items.append(CustomItem(kind: hazards.randomElement()!, x: nextX(), y: floorY())) }
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

    /// Falls asleep again: a brand-new random dream.
    private func newDream() {
        model?.engine.stop()
        let made = CustomLevelModel(level: DreamMaker.make())
        made.onExit = onExit
        made.winTitle = "You woke up!"
        made.winMessage = "You found every key and got out of \"\(made.level.name)\". Every dream is different: fancy another?"
        made.onWin = {
            game.completedSide.insert(5)
            game.award(.dreamer)
        }
        made.onPlayAgain = { newDream() }
        made.belt.configure(game: game, engine: made.engine)
        made.apply(skills: game.skills)
        made.engine.onDefaultInteract = { [weak made] in made?.talkToBrother() }
        made.engine.start()
        dreams += 1
        model = made
    }
}
