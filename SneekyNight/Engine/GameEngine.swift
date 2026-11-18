import SwiftUI
import Observation
import GameController
import QuartzCore

/// Something you bump into on the floor that makes a noise and wakes Mom.
enum Hazard {
    case chair, table, lamp, toy, shoes, basket, plank, cans, vines, cat

    var sound: Sound {
        switch self {
        case .chair: .chair
        case .table: .table
        case .lamp: .lamp
        case .toy: .squeak
        case .shoes: .table
        case .basket: .box
        case .plank: .creak
        case .cans: .lamp
        case .vines: .ouch
        case .cat: .squeak
        }
    }

    var noise: String {
        switch self {
        case .chair: "The chair scraped across the floor!"
        case .table: "You bumped the table. THUD!"
        case .lamp: "The lamp fell over. CRASH!"
        case .toy: "You stepped on a squeaky toy!"
        case .shoes: "You tripped over Dad's big shoes. THUMP!"
        case .basket: "You knocked over the laundry basket!"
        case .plank: "A loose plank creaked. CREEEAK!"
        case .cans: "You kicked the paint cans. CLANG!"
        case .vines: "OUCH! The spiky vines got you, and you yelped!"
        case .cat: "You stepped on a cat's tail. MEOWWW!"
        }
    }
}

/// One object in a room. Positions are in room coordinates; `pos` is where it stands on the floor.
struct Thing: Identifiable {
    let id: String
    var kind: String
    var pos: CGPoint
    /// Floor area it covers (width × depth). Zero means it stands against the back wall.
    var footprint: CGSize = .zero
    var solid = false
    var hazard: Hazard?
    var movable = false
    var heavy = false
    /// What pressing E does here, shown on screen. Nil = nothing to do.
    var prompt: String?
    var reach = CGSize(width: 80, height: 160)
    var hidden = false
    var open = false
    /// Rolling toys drive back and forth between these x positions.
    var patrol: ClosedRange<CGFloat>?
    var speed: CGFloat = 0
    /// False for things that make noise even when you crouch (loose planks).
    var crouchSafe = true
    /// Lies flat on the floor, so the player is always drawn on top of it.
    var flat = false
    /// Added to `pos.y` when deciding what's drawn in front (for things whose base isn't at their centre).
    var sortOffset: CGFloat = 0

    var onFloor: Bool { footprint != .zero }

    func covers(_ p: CGPoint, pad: CGSize = .zero) -> Bool {
        abs(p.x - pos.x) <= footprint.width / 2 + pad.width && abs(p.y - pos.y) <= footprint.height / 2 + pad.height
    }
}

struct SceneLayout {
    var width: CGFloat
    var floor: ClosedRange<CGFloat>
    var things: [Thing]
    var spawn: CGPoint
    /// Taller than 700 for top-down areas like the garden maze; the view then scrolls up and down too.
    var height: CGFloat = 700
}

/// Runs a room: player movement (WASD / arrows / joystick), jumping, carrying, hazards and the countdown.
/// Each level supplies the room and reacts through the `on…` hooks.
@Observable
final class GameEngine {
    var width: CGFloat = 1000
    var height: CGFloat = 700
    var floor: ClosedRange<CGFloat> = 560...680
    var things: [Thing] = []

    var player = CGPoint(x: 500, y: 620)
    var z: CGFloat = 0
    var facingRight = true
    var walking = false
    /// Bent down while searching something (can't move).
    var crouching = false
    /// Crouched on purpose (C): slower, safe to touch obstacles, hides you under tables.
    var ducking = false
    var taunting = false
    var sprinting = false
    var hidden = false
    /// Floor position of the table you're hiding under, if any.
    var coverY: CGFloat?
    /// In a closet or under a table.
    var concealed: Bool { hidden || coverY != nil }
    var speedBoost = false
    var jumpBoost = false
    var carrying: String?
    var canDash = false
    var canRun = false
    /// On-screen running switch (Shift on a keyboard).
    var runHeld = false
    /// Silent Slippers: each one lets you bump one obstacle without a sound.
    var shields = 0
    /// Extra speed from star balls: 0.1 = 10% faster.
    var speedBonus: CGFloat = 0
    /// Multipliers from boosting accessories (set by the item belt).
    var speedMult: CGFloat = 1
    var jumpMult: CGFloat = 1
    var dashMult: Double = 1
    /// Noise is divided by this: 1.5 means you're 1.5× quieter.
    var noiseDiv: Double = 1
    /// The player can't move or act, but the room keeps going (e.g. typing a door code while Dad patrols).
    var frozen = false
    /// What E does when you're not next to anything (e.g. "Throw the toy"). Nil = nothing.
    var defaultPrompt: String?
    /// Lets you taunt even while the game is paused (Mom staring right at you).
    var tauntOnly = false

    /// 0...100. Taunting and running fill it; at 100 someone wakes up. It changes every frame, so the
    /// screen watches `noiseShown` (whole percent) instead, and only redraws when that changes.
    @ObservationIgnored var noise: Double = 0 {
        didSet {
            let shown = Int(noise.rounded())
            if shown != noiseShown { noiseShown = shown }
        }
    }
    var noiseShown = 0
    /// Noise counts double next to a sleeping grown-up.
    var noiseFactor: Double = 1

    /// Seconds on the clock. It changes every frame, so the screen watches `clockSeconds` (what the
    /// clock shows) instead, and only redraws once a second.
    @ObservationIgnored var timeLeft: Double = 100 {
        didSet {
            let shown = Int(timeLeft.rounded(.up))
            if shown != clockSeconds { clockSeconds = shown }
        }
    }
    var clockSeconds = 100
    var timerOn = true
    /// False in places with no time limit (the dungeon): the clock isn't shown.
    var showsClock = true
    /// False while a pop-up is open: nothing moves and the clock stops.
    var running = false
    var bubble: String?
    var bubbleID = 0
    var nearest: Int?
    /// What E does right now: the thing you're next to, or the level's stand-anywhere action.
    /// Worked out once a frame, so the buttons don't have to look through every thing in the room.
    var prompt: String?

    /// Joystick direction, each axis -1...1.
    var stick: CGVector = .zero

    /// The pause menu is open: everything stops, even last-chance taunts.
    var paused = false
    /// Creative mode: slow motion (0.5) or fast forward (2).
    var timeScale: Double = 1
    var clockFrozen = false
    var noiseMuted = false

    /// Levels with strangers (Level 5 on) give you a health bar.
    var usesHP = false
    var hp: Double = 100
    var maxHP: Double = 100
    /// Just got hurt: flashing, and can't be hurt again for a moment.
    var hurt = false
    /// How worried your character looks: 0 nobody about, 1 someone is looking for you, 2 they're close. Set by the chase.
    var threat = 0
    var godMode = false

    /// Riding the cloud: up in the air, over hedges and obstacles.
    var flying = false
    var flyLeft: Double = 0
    /// Creative mode: walk through things.
    var noclip = false
    /// The Guide's Hat is on: you walk through things too.
    var phasing = false
    /// The golden stick was used this try: Mom, Dad and every other grown-up who could catch you are gone.
    var grownUpsGone = false
    /// Creative mode: grown-ups can't catch you.
    var ghost = false
    /// Nobody can catch or hurt you: practice mode, or the creative "ghost" command.
    var safe: Bool { ghost || Settings.shared.practice }
    /// Creative mode: drawn bigger or smaller (looks only).
    var sizeScale: CGFloat = 1
    /// Creative mode is on: you wear the creative crown and get the admin panel.
    var creative = false

    /// Practice mode: the Guide walks in the room and leads you to the next place to go.
    var guidePos: CGPoint?
    var guideWalking = false
    var guideFacingRight = true
    var guideSpeech: String?
    /// The spot the Guide is heading for (set by the level). Nil: he just walks along with you.
    @ObservationIgnored var guideGoal: () -> CGPoint? = { nil }
    /// For mazes: the next spot on the way from A to B, so the Guide follows the paths.
    @ObservationIgnored var guideWaypoint: ((CGPoint, CGPoint) -> CGPoint)?
    @ObservationIgnored private var guideTalk = 0.0
    @ObservationIgnored private var guideArrived = false

    /// Two players on one iPad: player 2 walks around with their own joystick and can use things.
    var multiplayer = false
    var player2: CGPoint?
    var facing2Right = true
    var walking2 = false
    var stick2: CGVector = .zero

    @ObservationIgnored var onInteract: (Int) -> Void = { _ in }
    @ObservationIgnored var onHazard: (Int) -> Void = { _ in }
    @ObservationIgnored var onTimeUp: () -> Void = {}
    /// E / Return / Space while a pop-up is open.
    @ObservationIgnored var onConfirm: () -> Void = {}
    @ObservationIgnored var onTooLoud: () -> Void = {}
    @ObservationIgnored var onShieldUsed: () -> Void = {}
    @ObservationIgnored var onDefaultInteract: () -> Void = {}
    @ObservationIgnored var onTaunt: () -> Void = {}
    /// V, F or G pressed (items 0, 1, 2). Works even in a last-chance pause.
    @ObservationIgnored var onItemKey: (Int) -> Void = { _ in }
    /// Called every frame while the game is running, for a level's own moving characters.
    @ObservationIgnored var onTick: (Double) -> Void = { _ in }
    /// Health ran out.
    @ObservationIgnored var onKO: () -> Void = {}
    /// Esc or P on a keyboard.
    @ObservationIgnored var onPause: () -> Void = {}
    /// Menu (M), restart (N), hint (L) or the creative wand (Z) was pressed on a keyboard.
    @ObservationIgnored var onMenuKey: (GameKey) -> Void = { _ in }
    @ObservationIgnored private var hurtTime = 0.0
    /// Things already touched once on No Mercy (so each can only be a trap the first time).
    @ObservationIgnored private var testedItems: Set<String> = []
    /// How fast you'd be walking right now without crouching or running (boosts and difficulty included).
    private(set) var walkSpeed: CGFloat = 290
    /// How fast you can go right now: walking speed, or running speed while you sprint.
    var pace: CGFloat { walkSpeed * (sprinting ? 1.5 : 1) }
    /// Counts room changes, so player 2's "use" can tell when it walked everyone through a door.
    @ObservationIgnored private var loads = 0

    @ObservationIgnored private var link: DisplayLink?
    @ObservationIgnored private var vz: CGFloat = 0
    @ObservationIgnored private var lastKeys: Set<GCKeyCode> = []
    @ObservationIgnored private var stepClock: Double = 0
    @ObservationIgnored private var lastWholeSecond = Int.max
    @ObservationIgnored private var dashTime: Double = 0
    @ObservationIgnored private var dashDirection = CGVector(dx: 1, dy: 0)
    /// The way the joystick / keys are pointing right now (zero when let go).
    @ObservationIgnored private var input = CGVector.zero
    @ObservationIgnored private var dashCooldown: Double = 0
    @ObservationIgnored private var tauntTime: Double = 0
    @ObservationIgnored private var graceTime: Double = 0
    @ObservationIgnored private var tooLoudSent = false

    private static let gravity: CGFloat = 1800

    /// How much of the room's width fits on screen (1000 on iPad; more on a wide iPhone).
    var viewWidth: CGFloat = 1000
    var camera: CGFloat { min(max(player.x - viewWidth / 2, 0), max(width - viewWidth, 0)) }
    /// Vertical scroll for tall worlds; 0 for ordinary rooms.
    var cameraY: CGFloat { height > 700 ? min(max(player.y - 430, -80), height - 700) : 0 }

    func load(_ layout: SceneLayout) {
        width = layout.width
        height = layout.height
        floor = layout.floor
        things = layout.things
        player = layout.spawn
        carrying = nil
        hidden = false
        ducking = false
        coverY = nil
        taunting = false
        tauntTime = 0
        dashTime = 0
        frozen = false
        defaultPrompt = nil
        z = 0
        vz = 0
        nearest = nil
        prompt = nil
        flying = false
        flyLeft = 0
        loads += 1
        placePlayer2()
        guidePos = nil
        guideArrived = false
        testedItems = []
    }

    /// Puts player 2 next to player 1 (or takes them away when multiplayer is off).
    func placePlayer2() {
        player2 = multiplayer ? CGPoint(x: max(50, player.x - 70), y: min(player.y + 14, floor.upperBound)) : nil
        walking2 = false
    }

    /// Fly on the cloud for this many seconds.
    func fly(_ seconds: Double) {
        flying = true
        flyLeft = seconds
        ducking = false
        carrying = nil
    }

    /// Takes health away (Level 5's strangers). Returns false when nothing happened:
    /// you were just hurt, you're in practice mode, or this level has no health bar.
    @discardableResult func damage(_ amount: Double) -> Bool {
        guard usesHP, running, hurtTime <= 0, !godMode, !safe, !hidden else { return false }
        hp = max(0, hp - amount * Difficulty.current.damageScale)
        hurtTime = 1.3
        hurt = true
        Sound.ouch.play()
        if hp <= 0 {
            running = false
            walking = false
            onKO()
        }
        return true
    }

    /// Obstacles can't be set off for this many seconds.
    func ignoreHazards(for seconds: Double) {
        graceTime = seconds
    }

    func resetNoise() {
        noise = 0
        tooLoudSent = false
    }

    func start() {
        guard link == nil else { return }
        link = DisplayLink { [weak self] dt in self?.step(dt) }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    func say(_ text: String, seconds: Double = 2.8) {
        bubbleID += 1
        bubble = text
        let id = bubbleID
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.bubbleID == id { self?.bubble = nil }
        }
    }

    func index(of id: String) -> Int? { things.firstIndex { $0.id == id } }

    /// Where a thing in this room stands (nil when it isn't here or is hidden). Used for the Guide's "follow me".
    func spot(_ id: String) -> CGPoint? { things.first { $0.id == id && !$0.hidden }?.pos }

    /// The closest thing (to you) that matches, for the Guide's "follow me".
    func nearestSpot(where match: (Thing) -> Bool) -> CGPoint? {
        things.filter { !$0.hidden && match($0) }
            .min { hypot($0.pos.x - player.x, $0.pos.y - player.y) < hypot($1.pos.x - player.x, $1.pos.y - player.y) }?.pos
    }

    // MARK: Actions (keyboard or on-screen buttons)

    func interact() {
        guard running, !frozen else { return }
        if let nearest {
            if springsTrap(nearest) { return }
            onInteract(nearest)
        } else if defaultPrompt != nil && !hidden {
            onDefaultInteract()
        }
    }

    /// No Mercy: the first time you touch a box, drawer or rock, it's 50-50 whether it was a trap.
    /// A trap snaps shut: a lot of noise, and it hurts in levels with health. After that it's safe.
    private func springsTrap(_ i: Int) -> Bool {
        guard Difficulty.current == .noMercy, !safe, i < things.count,
              ["box", "dresser", "nightstand", "rock", "crate", "trunk", "toolbox"].contains(things[i].kind),
              !testedItems.contains(things[i].id) else { return false }
        testedItems.insert(things[i].id)
        guard Bool.random() else { return false }
        Sound.buzz.play()
        Sound.ouch.play()
        say("OW! It was a trap!", seconds: 1.8)
        addNoise(45)
        damage(15)
        return true
    }

    func jump() {
        guard running, !frozen, z == 0, vz == 0, !hidden, !flying else { return }
        if ducking {
            ducking = false
            return
        }
        vz = (jumpBoost ? 820 : 640) * jumpMult.squareRoot() * Difficulty.current.playerJump
        Sound.jump.play(volume: 0.6)
    }

    func toggleCrouch() {
        guard running, !frozen, !hidden, z == 0, !flying else { return }
        ducking.toggle()
        if ducking { carrying = nil }
        Sound.crouch.play(volume: 0.6)
    }

    func taunt() {
        guard running || tauntOnly, !hidden, tauntTime <= 0 else { return }
        taunting = true
        tauntTime = 0.9
        Sound.taunt.play(volume: 0.8)
        say(["Nyeh nyeh!", "Can't catch me!", "Hee hee hee!", "Ninja mode!", "Too sneaky for you!"].randomElement()!, seconds: 1.4)
        addNoise(Difficulty.current.tauntNoise, plain: true)
        onTaunt()
    }

    func dash() {
        // Pressing dash again in the middle of a dash stops it right there.
        if dashTime > 0 {
            dashTime = 0
            return
        }
        guard running, !frozen, canDash, !hidden, dashCooldown <= 0 else { return }
        ducking = false
        // Dash the way you're steering; if you're not steering, the way you're facing.
        let length = hypot(input.dx, input.dy)
        dashDirection = length > 0.2 ? CGVector(dx: input.dx / length, dy: input.dy / length) : CGVector(dx: facingRight ? 1 : -1, dy: 0)
        dashTime = min(1.0, 0.17 * dashMult)
        dashCooldown = 1.2
        Sound.dash.play()
    }

    /// `plain`: the amount is already set for the difficulty (taunts), so Easy's quieter steps don't apply again.
    func addNoise(_ amount: Double, plain: Bool = false) {
        guard !noiseMuted else { return }
        noise = min(100, noise + amount * noiseFactor / noiseDiv / (plain ? 1 : Difficulty.current.quiet))
    }

    func moveObject() {
        guard running, !frozen, !hidden else { return }
        if carrying != nil {
            carrying = nil
            Sound.box.play(volume: 0.5)
            return
        }
        let candidates = things.indices.filter {
            let t = things[$0]
            return (t.movable || t.heavy) && !t.hidden
                && abs(t.pos.x - player.x) <= max(110, t.reach.width) && abs(t.pos.y - player.y) <= t.reach.height
        }
        guard let i = candidates.min(by: { abs(things[$0].pos.x - player.x) < abs(things[$1].pos.x - player.x) }) else {
            say("There's nothing here I can move.")
            return
        }
        if things[i].heavy {
            Sound.heavy.play()
            say("Too heavy! I can't move that.")
        } else {
            carrying = things[i].id
            Sound.box.play(volume: 0.5)
        }
    }

    // MARK: Game loop

    private func step(_ realDt: Double) {
        let dt = realDt * timeScale
        let keys = pressedKeys()
        let pressed = keys.subtracting(lastKeys)
        lastKeys = keys

        if pressed.contains(.escape) || pressed.contains(GameKey.pause.code) { onPause() }
        guard !paused else {
            if walking { walking = false }
            if walking2 { walking2 = false }
            return
        }
        // The buttons along the top of the level have keys too.
        for key in [GameKey.menu, .restart, .hint, .admin] where pressed.contains(key.code) { onMenuKey(key) }

        guard running else {
            walking = false
            sprinting = false
            if tauntOnly {
                updateTimers(dt)
                if pressed.contains(GameKey.taunt.code) { taunt() }
                itemKeys(pressed)
            } else if !pressed.isDisjoint(with: [GameKey.use.code, GameKey.use2.code, GameKey.jump.code]) {
                onConfirm()
            }
            return
        }
        let shift = keys.contains(GameKey.run.code) || keys.contains(.rightShift)

        if timerOn && !clockFrozen {
            timeLeft = max(0, timeLeft - dt)
            let whole = Int(timeLeft.rounded(.up))
            if whole != lastWholeSecond {
                lastWholeSecond = whole
                if whole <= 10 && whole > 0 { Sound.tick.play(volume: 0.6) }
            }
            if timeLeft <= 0 {
                timerOn = false
                walking = false
                onTimeUp()
                return
            }
        }

        let wantsRun = canRun && (shift || runHeld) && !ducking
        movePlayer(keys: keys, run: wantsRun, dt: CGFloat(dt))
        movePlayer2(keys: keys, dt: CGFloat(dt))
        updateJump(dt: CGFloat(dt))
        updateThings(dt: CGFloat(dt))
        updateTimers(dt)
        if checkHazards() { return }
        updateNearest()
        refreshPrompt()
        updateCover()
        updateNoise(dt)
        onTick(dt)
        updateGuide(dt)

        if pressed.contains(GameKey.use.code) { interact() }
        if pressed.contains(GameKey.jump.code) { jump() }
        if pressed.contains(GameKey.carry.code) { moveObject() }
        if pressed.contains(GameKey.crouch.code) { toggleCrouch() }
        if pressed.contains(GameKey.taunt.code) { taunt() }
        if pressed.contains(GameKey.dash.code) { dash() }
        if pressed.contains(GameKey.use2.code) { interact2() }
        itemKeys(pressed)
    }

    // MARK: Player 2

    private func movePlayer2(keys: Set<GCKeyCode>, dt: CGFloat) {
        guard var p = player2 else { return }
        var v = stick2
        if keys.contains(GameKey.left2.code) { v.dx -= 1 }
        if keys.contains(GameKey.right2.code) { v.dx += 1 }
        if keys.contains(GameKey.up2.code) { v.dy -= 1 }
        if keys.contains(GameKey.down2.code) { v.dy += 1 }
        let length = hypot(v.dx, v.dy)
        if length > 1 { v.dx /= length; v.dy /= length }
        let speed: CGFloat = 300
        let stuck = blocked(p)
        // Player 2 stays on the screen with player 1.
        let left = max(40, camera + 40), right = min(width - 40, camera + viewWidth - 40)
        let nx = CGPoint(x: min(max(p.x + v.dx * speed * dt, left), right), y: p.y)
        if stuck || !blocked(nx) { p = nx }
        let top = height > 700 ? max(floor.lowerBound, cameraY + 120) : floor.lowerBound
        let bottom = height > 700 ? min(floor.upperBound, cameraY + 660) : floor.upperBound
        let ny = CGPoint(x: p.x, y: min(max(p.y + v.dy * speed * 0.7 * dt, top), bottom))
        if stuck || !blocked(ny) { p = ny }
        if p != player2 { player2 = p }
        let moving = length > 0.15
        if moving != walking2 { walking2 = moving }
        if Self.turns(v), (v.dx > 0) != facing2Right { facing2Right = v.dx > 0 }
    }

    /// Player 2's "use" button: does whatever E would do where player 2 is standing.
    func interact2() {
        guard running, !frozen, let p2 = player2 else { return }
        let p1 = player, before = loads
        player = p2
        updateNearest()
        if let nearest {
            if things[nearest].prompt?.hasPrefix("Hide") == true {
                say("Only player 1 can hide in there.")
            } else {
                onInteract(nearest)
            }
        }
        // Unless that walked everyone through a door, player 1 goes back to where they were.
        if loads == before { player = p1 }
        updateNearest()
        refreshPrompt()
    }

    private func itemKeys(_ pressed: Set<GCKeyCode>) {
        for (n, key) in GameKey.items.enumerated() where pressed.contains(key.code) { onItemKey(n) }
    }

    private func updateTimers(_ dt: Double) {
        dashTime = max(0, dashTime - dt)
        dashCooldown = max(0, dashCooldown - dt)
        graceTime = max(0, graceTime - dt)
        if hurtTime > 0 {
            hurtTime -= dt
            if hurtTime <= 0 { hurt = false }
        }
        if flying {
            flyLeft -= dt
            if flyLeft <= 0 {
                flying = false
                flyLeft = 0
            }
        }
        if tauntTime > 0 {
            tauntTime -= dt
            if tauntTime <= 0 { taunting = false }
        }
    }

    private func updateNoise(_ dt: Double) {
        if sprinting { addNoise(15 * dt) }
        noise = max(0, noise - 9 * dt)
        if noise >= 99.5 && !tooLoudSent {
            tooLoudSent = true
            onTooLoud()
        }
    }

    /// Crouching inside a table's footprint hides you under it.
    private func updateCover() {
        var y: CGFloat?
        if ducking && !hidden {
            y = things.first { $0.hazard == .table && !$0.hidden && $0.covers(player, pad: CGSize(width: 6, height: 10)) }?.pos.y
        }
        if y != coverY { coverY = y }
    }

    private func movePlayer(keys: Set<GCKeyCode>, run: Bool, dt: CGFloat) {
        var v = stick
        // With two players the arrow keys belong to player 2.
        let arrows = player2 == nil
        if keys.contains(GameKey.left.code) || (arrows && keys.contains(GameKey.left2.code)) { v.dx -= 1 }
        if keys.contains(GameKey.right.code) || (arrows && keys.contains(GameKey.right2.code)) { v.dx += 1 }
        if keys.contains(GameKey.up.code) || (arrows && keys.contains(GameKey.up2.code)) { v.dy -= 1 }
        if keys.contains(GameKey.down.code) || (arrows && keys.contains(GameKey.down2.code)) { v.dy += 1 }
        let length = hypot(v.dx, v.dy)
        if length > 1 { v.dx /= length; v.dy /= length }
        input = v
        if hidden || crouching || frozen { v = .zero }

        // Boosts stack, but anything past 1100 is too fast to steer (creative mode and the Guide's Hat go further).
        let cap: CGFloat = creative || phasing ? 3200 : 1100
        var speed: CGFloat = min(cap, (speedBoost ? 440 : 290) * (1 + speedBonus) * speedMult * Difficulty.current.playerSpeed)
        if speed != walkSpeed { walkSpeed = speed }
        if ducking { speed *= 0.5 } else if run { speed *= 1.5 }
        if dashTime > 0 {
            v = dashDirection
            speed = 1050
        }
        let stuck = blocked(player)
        var p = player
        let nx = CGPoint(x: min(max(p.x + v.dx * speed * dt, 40), width - 40), y: p.y)
        if stuck || !blocked(nx) { p = nx }
        let ny = CGPoint(x: p.x, y: min(max(p.y + v.dy * speed * 0.7 * dt, floor.lowerBound), floor.upperBound))
        if stuck || !blocked(ny) { p = ny }
        if p != player { player = p }

        let isWalking = (length > 0.15 || dashTime > 0) && !hidden && !crouching
        if isWalking != walking { walking = isWalking }
        let isSprinting = run && isWalking
        if isSprinting != sprinting { sprinting = isSprinting }
        if Self.turns(v), (v.dx > 0) != facingRight { facingRight = v.dx > 0 }
        if walking && z == 0 {
            stepClock += Double(dt)
            if stepClock > (sprinting ? 0.2 : 0.32) {
                stepClock = 0
                Sound.step.play(volume: ducking ? 0.18 : sprinting ? 0.65 : 0.45)
            }
        }
    }

    private func updateJump(dt: CGFloat) {
        if flying {
            // Float up to cloud height and stay there.
            z = min(130, z + 420 * dt)
            vz = 0
            return
        }
        guard z > 0 || vz > 0 else { return }
        vz -= Self.gravity * dt
        z = max(0, z + vz * dt)
        if z == 0 {
            vz = 0
            Sound.land.play(volume: 0.5)
            // Landed on top of a box: slide off to the nearer side.
            if let box = things.first(where: { $0.solid && !$0.hidden && $0.id != carrying && $0.covers(player, pad: CGSize(width: 6, height: 0)) }) {
                let side: CGFloat = player.x >= box.pos.x ? 1 : -1
                player.x = min(max(box.pos.x + side * (box.footprint.width / 2 + 20), 40), width - 40)
            }
        }
    }

    private func updateThings(dt: CGFloat) {
        if let id = carrying, let i = index(of: id) {
            things[i].pos = CGPoint(x: min(max(player.x + (facingRight ? 78 : -78), 40), width - 40), y: player.y + 2)
        }
        for i in things.indices {
            guard let range = things[i].patrol, !things[i].hidden else { continue }
            things[i].pos.x += things[i].speed * dt * Difficulty.current.hazardSpeed
            if things[i].pos.x > range.upperBound {
                things[i].pos.x = range.upperBound
                things[i].speed = -abs(things[i].speed)
            } else if things[i].pos.x < range.lowerBound {
                things[i].pos.x = range.lowerBound
                things[i].speed = abs(things[i].speed)
            }
        }
    }

    /// Landing on or walking into an obstacle makes a noise. Jumping clears it.
    private func checkHazards() -> Bool {
        guard z < 14, !hidden, graceTime <= 0 else { return false }
        // A little forgiving: you have to really step on something to set it off.
        let pad = CGSize(width: -4, height: -6)
        guard let i = things.indices.first(where: {
            things[$0].hazard != nil && !things[$0].hidden && !(ducking && things[$0].crouchSafe)
                && things[$0].covers(player, pad: pad)
        }) else { return false }
        if shields > 0 {
            shields -= 1
            graceTime = 1.2
            Sound.crouch.play()
            say("Phew! My Silent Slippers kept it quiet.")
            onShieldUsed()
            return false
        }
        running = false
        walking = false
        things[i].hazard?.sound.play()
        onHazard(i)
        return true
    }

    /// Whether steering this way turns you to face left or right: only when you're really going
    /// sideways, not when the joystick wobbles a little while you walk up or down.
    private static func turns(_ v: CGVector) -> Bool {
        abs(v.dx) >= 0.3 && abs(v.dx) >= abs(v.dy) * 0.4
    }

    private func refreshPrompt() {
        var now: String?
        if let i = nearest, i < things.count { now = things[i].prompt }
        if now == nil && !hidden { now = defaultPrompt }
        if now != prompt { prompt = now }
    }

    private func updateNearest() {
        // One pass, no temporary arrays: this runs every frame.
        var best: Int?
        var bestDistance = CGFloat.infinity
        for i in things.indices {
            let t = things[i]
            guard t.prompt != nil, !t.hidden, t.id != carrying else { continue }
            let dx = abs(t.pos.x - player.x)
            guard dx <= t.reach.width, abs(t.pos.y - player.y) <= t.reach.height, dx < bestDistance else { continue }
            best = i
            bestDistance = dx
        }
        if best != nearest { nearest = best }
    }

    private func blocked(_ p: CGPoint) -> Bool {
        if flying || noclip || phasing { return false }
        let pad = CGSize(width: 6, height: 0)
        // In the air you clear small things like boxes.
        return things.contains { $0.solid && !$0.hidden && $0.id != carrying && !(z > 24 && $0.movable) && $0.covers(p, pad: pad) }
    }

    // MARK: The Guide (practice mode)

    /// "Follow me!": the Guide waits for you, then walks a little ahead toward the next place to go.
    private func updateGuide(_ dt: Double) {
        guard Settings.shared.practice else {
            if guidePos != nil { guidePos = nil; guideSpeech = nil }
            return
        }
        var pos = guidePos ?? CGPoint(x: min(max(player.x - 120, 40), width - 40), y: min(player.y + 10, floor.upperBound))
        if guideTalk > 0 {
            guideTalk -= dt
            if guideTalk <= 0 { guideSpeech = nil }
        }
        let goal = guideGoal()
        var target: CGPoint
        if let goal {
            let goalSpot = CGPoint(x: min(max(goal.x, 40), width - 40), y: min(max(goal.y, floor.lowerBound), floor.upperBound))
            let toGoal = hypot(goalSpot.x - pos.x, goalSpot.y - pos.y)
            let fromPlayer = hypot(player.x - pos.x, player.y - pos.y)
            if fromPlayer > 360 {
                // You fell behind: he comes back for you.
                target = CGPoint(x: player.x + (goalSpot.x > player.x ? 90 : -90), y: player.y)
                if guideSpeech == nil { guideSay(["I'll wait for you. Walk toward me!", "This way! I won't go faster than you.", "Over here! Follow my lantern."].randomElement()!) }
            } else if toGoal > 40 {
                // Stay a little ahead of you on the way there.
                let dir: CGFloat = goalSpot.x >= player.x ? 1 : -1
                let ahead = CGPoint(x: player.x + dir * 170, y: goalSpot.y)
                target = abs(goalSpot.x - player.x) < 170 ? goalSpot : ahead
                if !guideArrived && guideSpeech == nil && Int.random(in: 0..<240) == 0 { guideSay("Follow me to the next thing to do!") }
            } else {
                target = goalSpot
            }
            let arrived = toGoal < 50 && fromPlayer < 140
            if arrived && !guideArrived { guideSay("Here! Stand next to it and press the hand button (E).") }
            guideArrived = arrived
        } else {
            target = CGPoint(x: player.x - (facingRight ? 110 : -110), y: player.y)
            guideArrived = false
        }
        target.x = min(max(target.x, 40), width - 40)
        target.y = min(max(target.y, floor.lowerBound), floor.upperBound)
        if let guideWaypoint { target = guideWaypoint(pos, target) }
        let dx = target.x - pos.x, dy = target.y - pos.y
        let distance = hypot(dx, dy)
        let moving = distance > 12
        if moving {
            // He walks at your speed (crouching or running too), a touch faster only to get back in front.
            let yours = max(120, walkSpeed * (ducking ? 0.5 : sprinting ? 1.5 : 1))
            let step = min(distance, yours * (distance > 150 ? 1.12 : 1) * CGFloat(dt))
            pos.x += dx / distance * step
            pos.y += dy / distance * step
            if abs(dx) > 4, (dx > 0) != guideFacingRight { guideFacingRight = dx > 0 }
        }
        if moving != guideWalking { guideWalking = moving }
        if pos != guidePos { guidePos = pos }
    }

    private func guideSay(_ text: String) {
        guideSpeech = text
        guideTalk = 2.6
    }

    /// Every key the game listens for: all of `GameKey`, plus the extras that share a job.
    private static let watchedKeys: [GCKeyCode] = GameKey.allCases.map(\.code) + GameKey.alsoWatched

    private func pressedKeys() -> Set<GCKeyCode> {
        // No keyboard (most iPads and iPhones): nothing to check.
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput else { return [] }
        var keys = Set<GCKeyCode>()
        for key in Self.watchedKeys where keyboard.button(forKeyCode: key)?.isPressed == true { keys.insert(key) }
        return keys
    }
}

/// Calls `tick` once per screen refresh with the seconds since the last one.
private final class DisplayLink: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private let tick: (Double) -> Void

    init(tick: @escaping (Double) -> Void) {
        self.tick = tick
        super.init()
        link = CADisplayLink(target: self, selector: #selector(fire(_:)))
        link?.add(to: .main, forMode: .common)
    }

    @objc private func fire(_ link: CADisplayLink) {
        let dt = last == 0 ? 1.0 / 60 : link.timestamp - last
        last = link.timestamp
        tick(min(dt, 1.0 / 20))
    }

    func invalidate() {
        link?.invalidate()
        link = nil
    }
}
