import SwiftUI
import Observation

/// Level 4 rules. Part 1 is a big hedge maze seen from above: water all 100 plants (walking close
/// waters them) and shoo the pests that land every 25 seconds. Spiky vines block some paths — jump
/// them. A radar station shows what's left. Dad checks the garden every 2 minutes: hide in a bush.
/// One special bush gives you vines when shaken (a permanent item). When everything is watered and
/// pest-free, go through the gate — but only while the dogs are away.
/// Part 2, beyond the gate: find 3 keys and type the code ("Plants") to open the street gate.
/// Every 10 plants adds 20 seconds to the clock.
@MainActor
@Observable
final class GardenModel {
    enum Area { case maze, beyond }
    enum Phase { case sneaking, warning, searching, over }

    let engine = GameEngine()
    let belt = ItemBelt()
    var area: Area = .maze
    var phase: Phase = .sneaking
    var popup: Popup?
    var banner: String?
    var hidingIn: String?
    var playerOpacity = 1.0
    var watered = 0
    var pests = 0
    var dogsHere = true
    var keys = 0
    var codeAccepted = false
    var gateOpen = false
    var showRadar = false
    var showKeypad = false
    /// Mom or Dad coming after you. In the maze they follow the paths, like you.
    let chase = Chase()
    /// Seconds until Dad's next check (shown on the radar).
    var dadTime = 120.0

    @ObservationIgnored var onComplete: () -> Void = {}
    @ObservationIgnored var onExit: () -> Void = {}
    @ObservationIgnored var onNext: () -> Void = {}
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var onRetry: () -> Void = {}
    @ObservationIgnored var gotVines: () -> Void = {}
    @ObservationIgnored var hasVines: () -> Bool = { false }
    @ObservationIgnored var rollLoot: () -> Loot? = { nil }
    @ObservationIgnored var take: (Loot) -> Void = { _ in }

    @ObservationIgnored private var run = 0
    @ObservationIgnored private var keySpots: Set<String> = []
    @ObservationIgnored private var pestTime = 25.0
    @ObservationIgnored private var pestCount = 0
    @ObservationIgnored private var dogTime = 10.0
    @ObservationIgnored private var dadStage = 0
    @ObservationIgnored private var dadPause = 0.0
    @ObservationIgnored private var dadLaughed = false
    @ObservationIgnored private var barkTime = 0.0
    @ObservationIgnored private var waterSound = 0.0
    /// Wearing Auntie's Water Hose (from Level 7): every plant you water also waters the four nearest thirsty ones.
    @ObservationIgnored var hasHose = false

    static let plantCount = 100
    /// On Easy the gate code is three numbers and there are only two keys to find.
    static var code: String { Difficulty.current == .easy ? "357" : "Plants" }
    static var codeHint: String {
        Difficulty.current == .easy ? "The code is three numbers: 3, 5, 7" : "The code hint is a green object that can grow"
    }
    static var keysNeeded: Int { Difficulty.current == .easy ? 2 : 3 }
    static let columns = 10
    static let rows = 8
    static let cell = CGSize(width: 220, height: 170)
    static let origin = CGPoint(x: 60, y: 150)
    static let mazeSize = CGSize(width: 2320, height: 1600)
    static let beyondWidth: CGFloat = 2400
    static let searchSpots = ["flowerPots", "wheelbarrow", "birdhouse", "well", "compost", "scarecrow"]

    var allDone: Bool { watered >= Self.plantCount && pests == 0 }

    var inventory: [InventoryItem] {
        (0..<keys).map { InventoryItem(id: "key\($0)", symbol: "key.fill", color: Palette.gold) }
    }

    /// The little status line in the corner of the screen.
    var cornerText: String {
        area == .maze ? "Plants watered \(watered)/\(Self.plantCount)   ·   Pests \(pests)" : Self.codeHint
    }

    init() {
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onTimeUp = { [weak self] in self?.momWakesUp(tooLoud: false) }
        engine.onTooLoud = { [weak self] in self?.momWakesUp(tooLoud: true) }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.taunted() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.chase.stun(seconds, momOnly: momOnly) ?? false }
        chase.engine = engine
        chase.entrance = { [weak self] _ in
            self?.area == .maze ? (CGPoint(x: Self.center(0, 0).x - 60, y: Self.center(0, 0).y), 3) : (CGPoint(x: 110, y: 600), 4)
        }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.award = { [weak self] in self?.award($0) }
        chase.onCaught = { [weak self] who, message in self?.caught(who, message) }
        chase.onGaveUp = { [weak self] who in self?.gaveUp(who) }
        // Practice mode: the Guide leads you to the next place to go.
        engine.guideGoal = { [weak self] in self?.guideGoal() }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func retry() {
        onRetry()
        reset()
    }

    func reset() {
        run += 1
        belt.reset()
        area = .maze
        keySpots = Set(Self.searchSpots.shuffled().prefix(Self.keysNeeded))
        engine.load(SceneLayout(width: Self.mazeSize.width, floor: Self.origin.y...(Self.origin.y + CGFloat(Self.rows) * Self.cell.height),
                                things: Self.mazeThings(), spawn: Self.center(0, 0), height: Self.mazeSize.height))
        engine.timeLeft = Levels.time(4)
        engine.timerOn = true
        engine.resetNoise()
        engine.noiseFactor = 1
        engine.speedBoost = false
        engine.jumpBoost = false
        engine.shields = 0
        engine.speedBonus = 0
        engine.runHeld = false
        engine.tauntOnly = false
        chase.reset()
        chase.waypoint = { from, to in GardenModel.nextStep(from: from, to: to) }
        // The Guide follows the maze paths too.
        engine.guideWaypoint = { from, to in GardenModel.nextStep(from: from, to: to) }
        engine.crouching = false
        engine.facingRight = true
        engine.bubble = nil
        phase = .sneaking
        popup = nil
        banner = nil
        hidingIn = nil
        playerOpacity = 1
        watered = 0
        pests = 0
        pestTime = 25
        dogsHere = true
        dogTime = 10
        keys = 0
        codeAccepted = false
        gateOpen = false
        showRadar = false
        showKeypad = false
        dadTime = 120
        dadStage = 0
        dadPause = 0
        dadLaughed = false
        engine.running = true
        engine.say("So many thirsty plants! Walking close waters them. The radar shows what's left.", seconds: 5)
    }

    // MARK: Building the maze

    static func center(_ c: Int, _ r: Int) -> CGPoint {
        CGPoint(x: origin.x + (CGFloat(c) + 0.5) * cell.width, y: origin.y + (CGFloat(r) + 0.5) * cell.height)
    }

    /// The maze is built once: its hedges, plants and so on, plus which paths between cells are open.
    static let built = buildMaze()

    static func mazeThings() -> [Thing] { built.things }

    static func cell(of p: CGPoint) -> (c: Int, r: Int) {
        (min(max(Int((p.x - origin.x) / cell.width), 0), columns - 1), min(max(Int((p.y - origin.y) / cell.height), 0), rows - 1))
    }

    /// Path-finding for whoever is chasing you: the next spot to walk to on the way from A to B
    /// without going through a hedge.
    static func nextStep(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let start = cell(of: a), goal = cell(of: b)
        if start == goal { return b }
        // Search outward from the goal; the first neighbour that reaches `start` is the way to go.
        var cameFrom: [Int: Int] = [goal.c + goal.r * columns: -1]
        var queue = [goal]
        var head = 0
        while head < queue.count {
            let (c, r) = queue[head]
            head += 1
            if (c, r) == start { break }
            var around: [(Int, Int)] = []
            if c + 1 < columns, built.open.contains("v \(c) \(r)") { around.append((c + 1, r)) }
            if c > 0, built.open.contains("v \(c - 1) \(r)") { around.append((c - 1, r)) }
            if r + 1 < rows, built.open.contains("h \(c) \(r)") { around.append((c, r + 1)) }
            if r > 0, built.open.contains("h \(c) \(r - 1)") { around.append((c, r - 1)) }
            for n in around where cameFrom[n.0 + n.1 * columns] == nil {
                cameFrom[n.0 + n.1 * columns] = c + r * columns
                queue.append(n)
            }
        }
        guard let next = cameFrom[start.c + start.r * columns], next >= 0 else { return b }
        // Line up with the middle of the path first, so corners aren't cut through the hedges.
        let here = center(start.c, start.r)
        let sideways = next / columns == start.r ? abs(a.y - here.y) : abs(a.x - here.x)
        return sideways > 30 ? here : center(next % columns, next / columns)
    }

    /// The same maze every time (so you can learn it): a winding path with a few shortcuts.
    private static func buildMaze() -> (things: [Thing], open: Set<String>) {
        var rng = SeededRandom(seed: 4)
        // "v c r" = the slot between (c,r) and (c+1,r); "h c r" = between (c,r) and (c,r+1).
        var open: Set<String> = []
        var visited = Array(repeating: Array(repeating: false, count: rows), count: columns)
        var stack = [(0, 0)]
        visited[0][0] = true
        while let (c, r) = stack.last {
            var options: [(Int, Int, String)] = []
            if c + 1 < columns, !visited[c + 1][r] { options.append((c + 1, r, "v \(c) \(r)")) }
            if c > 0, !visited[c - 1][r] { options.append((c - 1, r, "v \(c - 1) \(r)")) }
            if r + 1 < rows, !visited[c][r + 1] { options.append((c, r + 1, "h \(c) \(r)")) }
            if r > 0, !visited[c][r - 1] { options.append((c, r - 1, "h \(c) \(r - 1)")) }
            if options.isEmpty {
                stack.removeLast()
            } else {
                let pick = options[min(options.count - 1, Int(rng.next() * CGFloat(options.count)))]
                open.insert(pick.2)
                visited[pick.0][pick.1] = true
                stack.append((pick.0, pick.1))
            }
        }

        var things: [Thing] = []
        var passages: [(String, CGPoint, Bool)] = []
        let thick: CGFloat = 34
        for c in 0..<columns {
            for r in 0..<rows {
                if c + 1 < columns {
                    let key = "v \(c) \(r)"
                    let pos = CGPoint(x: origin.x + CGFloat(c + 1) * cell.width, y: origin.y + (CGFloat(r) + 0.5) * cell.height)
                    if !open.contains(key) && rng.next() < 0.16 { open.insert(key) }
                    if open.contains(key) {
                        passages.append((key, pos, true))
                    } else {
                        var t = Thing(id: key, kind: "hedge", pos: pos, footprint: CGSize(width: thick, height: cell.height + thick), solid: true)
                        t.sortOffset = t.footprint.height / 2
                        things.append(t)
                    }
                }
                if r + 1 < rows {
                    let key = "h \(c) \(r)"
                    let pos = CGPoint(x: origin.x + (CGFloat(c) + 0.5) * cell.width, y: origin.y + CGFloat(r + 1) * cell.height)
                    if !open.contains(key) && rng.next() < 0.16 { open.insert(key) }
                    if open.contains(key) {
                        passages.append((key, pos, false))
                    } else {
                        var t = Thing(id: key, kind: "hedge", pos: pos, footprint: CGSize(width: cell.width + thick, height: thick), solid: true)
                        t.sortOffset = t.footprint.height / 2
                        things.append(t)
                    }
                }
            }
        }

        // Spiky vines stretch right across some paths, so the only way past is to jump.
        for (n, passage) in passages.enumerated() where n % 6 == 3 && passage.0 != "v 0 0" && passage.0 != "h 0 0" {
            var vine = Thing(id: "vine \(passage.0)", kind: "spikyVine", pos: passage.1,
                             footprint: passage.2 ? CGSize(width: 30, height: cell.height - thick + 14) : CGSize(width: cell.width - thick + 14, height: 26),
                             hazard: .vines)
            vine.crouchSafe = false
            vine.flat = true
            things.append(vine)
        }

        // 100 plants: one in every cell, and a second one in a quarter of them.
        var plants = 0
        for r in 0..<rows {
            for c in 0..<columns {
                let p = center(c, r)
                plants += 1
                things.append(Thing(id: "plant\(plants)", kind: "plant", pos: CGPoint(x: p.x - 48, y: p.y - 18), footprint: CGSize(width: 30, height: 16)))
            }
        }
        var n = 0
        while plants < plantCount {
            let p = center((n * 3) % columns, (n * 5) % rows)
            plants += 1
            things.append(Thing(id: "plant\(plants)", kind: "plant", pos: CGPoint(x: p.x + 48, y: p.y + 26), footprint: CGSize(width: 30, height: 16)))
            n += 1
        }

        for (i, spot) in [(2, 1), (6, 0), (8, 3), (4, 5), (1, 6), (7, 6), (3, 3), (9, 5), (5, 7)].enumerated() {
            let p = center(spot.0, spot.1)
            things.append(Thing(id: "bush\(i)", kind: "bush", pos: CGPoint(x: p.x + 50, y: p.y - 30), footprint: CGSize(width: 70, height: 30),
                                prompt: "Hide in the bush", reach: CGSize(width: 70, height: 60)))
        }
        let shaky = center(5, 2)
        things.append(Thing(id: "shakyBush", kind: "shakyBush", pos: CGPoint(x: shaky.x + 50, y: shaky.y - 30), footprint: CGSize(width: 70, height: 30),
                            prompt: "Shake the strange bush", reach: CGSize(width: 70, height: 60)))
        let radar = center(4, 3)
        things.append(Thing(id: "radar", kind: "radar", pos: CGPoint(x: radar.x - 50, y: radar.y + 34), footprint: CGSize(width: 50, height: 24),
                            prompt: "Check the radar", reach: CGSize(width: 70, height: 70)))
        let gate = center(columns - 1, rows - 1)
        things.append(Thing(id: "gate", kind: "mazeGate", pos: CGPoint(x: gate.x + 62, y: gate.y + 20), footprint: CGSize(width: 60, height: 40),
                            prompt: "Go through the gate", reach: CGSize(width: 90, height: 90)))
        return (things, open)
    }

    static func beyondThings() -> [Thing] {
        func wall(_ id: String, _ kind: String, _ x: CGFloat, _ prompt: String?, reach: CGFloat = 70) -> Thing {
            HallwayModel.onWall(id, kind, x: x, prompt: prompt, reach: reach)
        }
        func vine(_ id: String, x: CGFloat) -> Thing {
            var t = Thing(id: id, kind: "spikyVine", pos: CGPoint(x: x, y: 617), footprint: CGSize(width: 40, height: 150), hazard: .vines)
            t.crouchSafe = false
            t.flat = true
            return t
        }
        return [
            wall("backGate", "backGate", 110, "Look back at the maze"),
            wall("bushA", "bushWall", 300, "Hide in the bush"),
            wall("flowerPots", "flowerPots", 480, "Search the flower pots"),
            vine("vineA", x: 610),
            wall("wheelbarrow", "wheelbarrow", 740, "Search the wheelbarrow", reach: 80),
            wall("birdhouse", "birdhouse", 970, "Search the birdhouse"),
            HallwayModel.obstacle("cans", .cans, x: 1100, y: 650, size: CGSize(width: 60, height: 26)),
            wall("well", "well", 1230, "Search the well", reach: 80),
            wall("compost", "compost", 1490, "Search the compost bin"),
            vine("vineB", x: 1620),
            wall("scarecrow", "scarecrow", 1750, "Search the scarecrow"),
            wall("bushB", "bushWall", 1970, "Hide in the bush"),
            wall("streetGate", "streetGate", 2250, "Unlock the gate", reach: 90),
        ]
    }

    // MARK: Pressing E

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "bush", "bushWall": toggleHiding(in: thing)
        case "shakyBush": shakeBush(i)
        case "radar":
            Sound.beep.play()
            engine.running = false
            showRadar = true
        case "pest":
            engine.things.remove(at: i)
            pests -= 1
            Sound.bug.play()
            engine.say(["Shoo, bug!", "Bye bye, beetle!", "Off you go!"].randomElement()!, seconds: 1.2)
            checkDone()
        case "mazeGate": useMazeGate()
        case "backGate": engine.say("No going back now. The street gate is at the other end!")
        case "flowerPots", "wheelbarrow", "birdhouse", "well", "compost", "scarecrow": search(i)
        case "streetGate": useStreetGate()
        default: break
        }
    }

    private func toggleHiding(in bush: Thing) {
        Sound.rustle.play()
        if engine.hidden {
            engine.hidden = false
            hidingIn = nil
        } else {
            engine.ducking = false
            engine.player = area == .maze ? CGPoint(x: bush.pos.x, y: bush.pos.y + 4) : CGPoint(x: bush.pos.x, y: bush.pos.y + 8)
            engine.hidden = true
            hidingIn = bush.id
        }
    }

    private func shakeBush(_ i: Int) {
        Sound.rustle.play()
        if hasVines() || engine.things[i].open {
            engine.say("Just leaves now.")
            return
        }
        engine.things[i].open = true
        Sound.powerup.play()
        show(Popup(title: "You found VINES!", message: "Yours to keep forever. Press V to tangle up Mom or Dad for 10 seconds (once every 35 seconds).",
                   symbol: "leaf.arrow.triangle.circlepath", color: .green, button: "Take") { [weak self] in
            guard let self else { return }
            gotVines()
            belt.owned.insert(.vines)
        })
    }

    private func useMazeGate() {
        if !allDone {
            let left = Self.plantCount - watered
            engine.say(left > 0 ? "The gate won't open yet. \(left) plants still need water!" : "Almost! \(pests) pests still need shooing.")
        } else if dogsHere {
            Sound.woof.play()
            engine.say("Dogs are guarding the gate! I'll wait until they wander off.")
        } else {
            Sound.door.play()
            area = .beyond
            hidingIn = nil
            chase.waypoint = nil
            engine.guideWaypoint = nil
            chase.playerChangedRoom(entry: CGPoint(x: 110, y: 600))
            engine.load(SceneLayout(width: Self.beyondWidth, floor: HallwayModel.floor, things: Self.beyondThings(), spawn: CGPoint(x: 210, y: 610)))
            engine.timeLeft += 60
            banner = nil
            engine.say("Made it! Now: \(Self.keysNeeded) keys and a code for the street gate.", seconds: 4)
        }
    }

    private func search(_ i: Int) {
        guard !engine.things[i].open else {
            engine.say("Nothing else here.")
            return
        }
        engine.things[i].open = true
        Sound.rustle.play()
        if keySpots.contains(engine.things[i].id) {
            Sound.key.play()
            show(Popup(title: "You found a key!", message: "Key \(keys + 1) of \(Self.keysNeeded) for the street gate.",
                       symbol: "key.fill", color: Palette.gold, button: "Take Key") { [weak self] in
                self?.keys += 1
                self?.award(.patienceIsKey)
            })
        } else if let loot = rollLoot() {
            Sound.magic.play()
            show(.loot(loot) { [weak self] in self?.take(loot) })
        } else {
            engine.say(["Just dirt and worms.", "A snail. Hello, snail.", "Nothing but old leaves."].randomElement()!)
        }
    }

    private func useStreetGate() {
        guard !gateOpen else { return }
        if !codeAccepted {
            Sound.beep.play()
            engine.running = false
            showKeypad = true
        } else {
            tryKeys()
        }
    }

    func submitCode(_ entry: String) -> Bool {
        guard entry.trimmingCharacters(in: .whitespaces).lowercased() == Self.code.lowercased() else {
            Sound.buzz.play()
            return false
        }
        Sound.unlock.play()
        codeAccepted = true
        closeKeypad()
        tryKeys()
        return true
    }

    func closeKeypad() {
        showKeypad = false
        engine.running = phase == .sneaking || phase == .warning
    }

    func closeRadar() {
        showRadar = false
        engine.running = phase == .sneaking || phase == .warning
    }

    private func tryKeys() {
        guard keys >= Self.keysNeeded else {
            engine.say("The code worked! But the gate has \(Self.keysNeeded) locks. I have \(keys) of \(Self.keysNeeded) keys.")
            return
        }
        gateOpen = true
        phase = .over
        engine.running = false
        engine.timerOn = false
        onComplete()
        let thisRun = run
        Task { @MainActor in
            Sound.unlock.play()
            try? await Task.sleep(for: .seconds(0.5))
            Sound.door.play()
            try? await Task.sleep(for: .seconds(0.6))
            guard run == thisRun else { return }
            engine.walking = true
            withAnimation(.linear(duration: 0.7)) {
                engine.player = CGPoint(x: 2290, y: 560)
                playerOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.8))
            engine.walking = false
            Sound.win.play()
            show(Popup(title: "Level Complete!", message: "Every plant watered, every pest gone, and you're out on the street!",
                       symbol: "star.fill", color: Palette.gold, button: "Next", action: { [weak self] in self?.onNext() },
                       secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
        }
    }

    private func checkDone() {
        if allDone && area == .maze {
            Sound.star.play()
            banner = "Checkpoint! All done. Head for the garden gate!"
            let thisRun = run
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if run == thisRun && banner?.hasPrefix("Checkpoint") == true { banner = nil }
            }
        }
    }

    // MARK: Every frame

    private func tick(_ dt: Double) {
        belt.tick(dt)
        chase.tick(dt)
        if dadPause > 0 {
            dadPause -= dt
            if dadPause <= 0, banner?.contains("funny") == true { banner = nil }
        }
        guard phase == .sneaking else { return }
        if area == .maze {
            waterPlants(dt)
            tickPests(dt)
            dogTime -= dt
            if dogTime <= 0 {
                dogsHere.toggle()
                dogTime = dogsHere ? 10 : 9
            }
            // The dogs grumble if you stand too close to them: a tiny bit of noise each time.
            barkTime -= dt
            if dogsHere, barkTime <= 0, let gate = engine.things.first(where: { $0.kind == "mazeGate" }),
               hypot(gate.pos.x - engine.player.x, gate.pos.y - engine.player.y) < 230, !engine.hidden {
                barkTime = 1.6
                Sound.woof.play(volume: 0.35)
                engine.addNoise(7)
            }
        }
        if !chase.active { tickDad(dt) }
    }

    private func waterPlants(_ dt: Double) {
        waterSound -= dt
        let p = engine.player
        for i in engine.things.indices where engine.things[i].kind == "plant" && !engine.things[i].open {
            let q = engine.things[i].pos
            guard abs(q.x - p.x) < 75, abs(q.y - p.y) < 62, !engine.things[i].open else { continue }
            let before = watered
            var group = [i]
            if hasHose {
                // The hose reaches further: five plants at once instead of one.
                let thirsty = engine.things.indices.filter { $0 != i && engine.things[$0].kind == "plant" && !engine.things[$0].open }
                group += thirsty.sorted {
                    hypot(engine.things[$0].pos.x - q.x, engine.things[$0].pos.y - q.y) < hypot(engine.things[$1].pos.x - q.x, engine.things[$1].pos.y - q.y)
                }.prefix(4)
            }
            for j in group {
                engine.things[j].open = true
                watered += 1
            }
            if waterSound <= 0 {
                Sound.water.play(volume: 0.6)
                waterSound = 0.3
            }
            // +20 seconds for every ten plants (the hose can pass several tens at once).
            let tens = min(watered, Self.plantCount - 1) / 10 - before / 10
            if tens > 0 {
                engine.timeLeft += 20 * Double(tens)
                engine.say("\(watered) plants watered! +\(20 * tens) seconds", seconds: 1.6)
            }
            checkDone()
        }
    }

    private func tickPests(_ dt: Double) {
        // No new pests once every plant is watered, or while Dad is on his way or checking.
        guard watered < Self.plantCount, dadStage == 0, !chase.active else { return }
        pestTime -= dt
        guard pestTime <= 0 else { return }
        pestTime = 25
        let plants = engine.things.filter { $0.kind == "plant" }
        guard pests < 6, let plant = plants.randomElement() else { return }
        pestCount += 1
        pests += 1
        engine.things.append(Thing(id: "pest\(pestCount)", kind: "pest", pos: CGPoint(x: plant.pos.x + 6, y: plant.pos.y + 3),
                                   footprint: CGSize(width: 26, height: 14), prompt: "Shoo the pest", reach: CGSize(width: 70, height: 60)))
        Sound.bug.play(volume: 0.5)
        if banner == nil {
            let text = "A pest landed on a plant! The radar shows where."
            banner = text
            let thisRun = run
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                if run == thisRun && banner == text { banner = nil }
            }
        }
    }

    /// Dad walks out to check the garden every 2 minutes. You hear him 10 seconds before.
    /// If you're in a bush when he arrives he sees nothing and goes back in; otherwise he comes after you.
    private func tickDad(_ dt: Double) {
        switch dadStage {
        case 0:
            dadTime -= dt
            if dadTime <= 10 {
                dadStage = 1
                Sound.dad.play()
            }
        default:
            let before = Int(dadTime.rounded(.up))
            dadTime -= dt
            let now = Int(max(dadTime, 0).rounded(.up))
            if dadPause <= 0 { banner = "Dad is coming to check the garden! Hide in a bush! \(now)" }
            if now != before && now % 3 == 0 { Sound.dad.play(volume: 0.7) }
            guard dadTime <= 0, dadPause <= 0 else { return }
            banner = nil
            dadLaughed = false
            dadStage = 0
            dadTime = 120
            if engine.hidden {
                award(.shh)
                engine.say("Phew... Dad looked around and went back inside.")
            } else {
                chase.alarm(.dad, "Dad came out and spotted you! RUN!")
            }
        }
    }

    // MARK: Taunts

    private func taunted() {
        chase.taunted()
        // Taunting while he's on his way: he laughs, and you get 10 extra seconds to hide.
        if dadStage == 1 && !dadLaughed && !chase.active {
            dadLaughed = true
            dadPause = 10
            award(.funnySon)
            banner = "Dad: \"Ha! That's funny, son. You've got 10 seconds...\""
        }
    }

    // MARK: Getting caught

    /// Spiky vines (or a clatter of cans) make you yelp, and Dad comes to see what happened.
    private func bumped(_ i: Int) {
        let hazard = engine.things[i].hazard
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        guard !chase.active else { return }
        chase.alarm(.dad, "\(hazard?.noise ?? "CRASH!") Dad heard it. He's coming!")
    }

    /// Out of time or too loud: Mom comes out into the garden to find you.
    private func momWakesUp(tooLoud: Bool) {
        guard phase == .sneaking else { return }
        guard !chase.active else {
            engine.resetNoise()
            return
        }
        if !tooLoud { award(.amNotPm) }
        showRadar = false
        showKeypad = false
        engine.running = true
        chase.alarm(.mom, tooLoud ? "Too loud! Mom is coming out to find you!" : "Time's up! Mom is coming out to find you!")
    }

    /// A minute went by without catching you.
    private func gaveUp(_ who: Chase.Who) {
        award(.shh)
        engine.resetNoise()
        engine.timerOn = true
        if who == .mom {
            engine.timeLeft = 120
            engine.say("Mom gave up and went back to bed. 2 minutes until she wakes up again!", seconds: 4)
        } else {
            dadStage = 0
            dadTime = 120
            engine.say("Dad gave up and went back inside. Phew!", seconds: 3)
        }
    }

    private func caught(_ who: Chase.Who, _ message: String) {
        award(.oopsies)
        if who == .dad { award(.hiDad) }
        showKeypad = false
        showRadar = false
        phase = .over
        banner = nil
        engine.running = false
        Sound.caught.play()
        show(Popup(title: "Caught!", message: message, symbol: "exclamationmark.triangle.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.retry() },
                   secondButton: "Menu", secondAction: { [weak self] in self?.onExit() }))
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        wrapped.action = { [weak self] in
            newPopup.action()
            self?.closePopup()
        }
        wrapped.secondAction = { [weak self] in
            newPopup.secondAction()
            self?.closePopup()
        }
        withAnimation { popup = wrapped }
    }

    private func closePopup() {
        withAnimation { popup = nil }
        engine.running = phase == .sneaking || phase == .warning
    }

    /// Practice mode: the Guide leads you to the nearest thirsty plant, then the pests, then the gate.
    /// Beyond the gate: the spots with keys, then the street gate.
    private func guideGoal() -> CGPoint? {
        if area == .maze {
            if allDone { return engine.spot("gate") }
            if watered < Self.plantCount { return engine.nearestSpot { $0.kind == "plant" && !$0.open } }
            return engine.nearestSpot { $0.kind == "pest" }
        }
        if keys < Self.keysNeeded, let spot = engine.things.first(where: { keySpots.contains($0.id) && !$0.open }) { return spot.pos }
        return engine.spot("streetGate")
    }

    func hint() {
        if area == .maze {
            if allDone {
                engine.say(dogsHere ? "Everything's done! Wait by the gate until the dogs leave." : "The dogs are gone. Go through the gate, quick!", seconds: 4)
            } else if watered < Self.plantCount {
                engine.say("Walk close to the droopy plants to water them. The radar station shows which ones are left.", seconds: 4.5)
            } else {
                engine.say("Only pests left! The radar shows them in red. Press E next to one.", seconds: 4)
            }
        } else if keys < 3 {
            engine.say("Search everything out here: pots, the well, the scarecrow... 3 of them hide keys.", seconds: 4)
        } else {
            engine.say("The code is a green thing that grows... and I've just watered 100 of them!", seconds: 4.5)
        }
    }
}

// MARK: - View

struct GardenLevelView: View {
    @Environment(GameState.self) private var game
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var model = GardenModel()

    var body: some View {
        LevelScaffold(engine: model.engine, title: model.area == .maze ? "Level 4 · Garden Maze" : "Level 4 · Beyond the Gate",
                      inventory: model.inventory, popup: model.popup, banner: model.banner, belt: model.belt,
                      cornerHint: model.cornerText, chase: model.chase, guideTips: GuideTips.level4,
                      onHome: onExit, onRestart: model.retry, onHint: model.hint) {
            Group {
                if model.area == .maze { maze } else { beyond }
            }
            .allowsHitTesting(false)
        } extra: {
            if model.showRadar {
                RadarOverlay(model: model, onClose: model.closeRadar)
            }
            if model.showKeypad {
                KeypadView(hint: GardenModel.codeHint + ".", onSubmit: model.submitCode, onCancel: model.closeKeypad)
            }
        }
        .onAppear {
            model.onComplete = { game.complete(level: 4) }
            model.onExit = onExit
            model.onNext = onNext
            model.award = { badge in if badge == .oopsies { game.noteCaught() } else { game.award(badge) } }
            model.onRetry = { game.noteRetry() }
            model.gotVines = { game.hasVines = true }
            model.hasVines = { game.hasVines }
            model.rollLoot = { game.rollLoot() }
            model.take = { game.take($0) }
            model.belt.configure(game: game, engine: model.engine)
            model.hasHose = game.look.boosts.contains(.waterHose)
            model.apply(skills: game.skills)
            model.engine.start()
        }
        .onDisappear { model.engine.stop() }
    }

    private var engine: GameEngine { model.engine }

    private var maze: some View {
        ZStack(alignment: .topLeading) {
            MazeGround(size: GardenModel.mazeSize)
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                mazeItem(thing)
            }
            grownUps
            Palette.shade.opacity((0.16) * Palette.shadeAmount)
        }
        .frame(width: GardenModel.mazeSize.width, height: GardenModel.mazeSize.height, alignment: .topLeading)
    }

    private var beyond: some View {
        ZStack(alignment: .topLeading) {
            BeyondScene(width: GardenModel.beyondWidth)
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                beyondItem(thing).anchored(at: thing.pos)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName, playerOpacity: model.playerOpacity) { thing in
                if thing.kind == "spikyVine" {
                    SpikyVineView(size: thing.footprint).offset(y: thing.footprint.height / 2)
                } else {
                    PaintCansView()
                }
            }
            grownUps
            Palette.shade.opacity((0.12) * Palette.shadeAmount)
        }
        .frame(width: GardenModel.beyondWidth, height: 700, alignment: .topLeading)
    }

    @ViewBuilder private var grownUps: some View {
        ChaserView(chase: model.chase)
    }

    @ViewBuilder private func mazeItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "hedge": HedgeView(size: thing.footprint).offset(y: thing.footprint.height / 2)
        case "plant": PlantView(watered: thing.open)
        case "pest": PestView()
        case "spikyVine": SpikyVineView(size: thing.footprint).offset(y: thing.footprint.height / 2)
        case "bush": BushView(hiding: model.hidingIn == thing.id, strange: false)
        case "shakyBush": BushView(hiding: false, strange: !thing.open)
        case "radar": RadarStationView()
        case "mazeGate": MazeGateView(open: model.allDone, dogs: model.dogsHere)
        default: EmptyView()
        }
    }

    @ViewBuilder private func beyondItem(_ thing: Thing) -> some View {
        switch thing.kind {
        case "backGate": GardenGateView()
        case "bushWall": BushView(hiding: model.hidingIn == thing.id, strange: false).scaleEffect(1.5, anchor: .bottom)
        case "flowerPots": FlowerPotsView()
        case "wheelbarrow": WheelbarrowView()
        case "birdhouse": BirdhouseView()
        case "well": WellView()
        case "compost": CompostView()
        case "scarecrow": ScarecrowView()
        case "streetGate": StreetGateView(open: model.gateOpen, codeAccepted: model.codeAccepted)
        default: EmptyView()
        }
    }
}
