import GameController

/// Every keyboard control in one place. The key the game listens for (`code`) and the letter
/// drawn on the matching on-screen button (`label`) both come from here, so they can never
/// disagree. To change a key, change it in this file only.
enum GameKey: CaseIterable {
    // Player 1
    case up, left, down, right
    case use, jump, carry, crouch, taunt, dash, run
    // Items, in the order of `ItemBelt.Item`
    case vines, lightning, toy, bat, cloud, hat
    // The buttons along the top of a level
    case pause, menu, restart, hint, admin
    // Player 2 (multiplayer)
    case up2, left2, down2, right2, use2

    var code: GCKeyCode {
        switch self {
        case .up: .keyW
        case .left: .keyA
        case .down: .keyS
        case .right: .keyD
        case .use: .keyE
        case .jump: .spacebar
        case .carry: .keyR
        case .crouch: .keyC
        case .taunt: .keyT
        case .dash: .keyQ
        case .run: .leftShift
        case .vines: .keyV
        case .lightning: .keyF
        case .toy: .keyG
        case .bat: .keyB
        case .cloud: .keyX
        case .hat: .keyH
        case .pause: .keyP
        case .menu: .keyM
        case .restart: .keyN
        case .hint: .keyL
        case .admin: .keyZ
        case .up2: .upArrow
        case .left2: .leftArrow
        case .down2: .downArrow
        case .right2: .rightArrow
        case .use2: .returnOrEnter
        }
    }

    /// What's written on the on-screen button for this control.
    var label: String {
        switch self {
        case .up: "W"
        case .left: "A"
        case .down: "S"
        case .right: "D"
        case .use: "E"
        case .jump: "Space"
        case .carry: "R"
        case .crouch: "C"
        case .taunt: "T"
        case .dash: "Q"
        case .run: "Shift"
        case .vines: "V"
        case .lightning: "F"
        case .toy: "G"
        case .bat: "B"
        case .cloud: "X"
        case .hat: "H"
        case .pause: "P"
        case .menu: "M"
        case .restart: "N"
        case .hint: "L"
        case .admin: "Z"
        case .up2: "↑"
        case .left2: "←"
        case .down2: "↓"
        case .right2: "→"
        case .use2: "↩"
        }
    }

    /// The item keys, in the same order as the items on the belt.
    static let items: [GameKey] = [.vines, .lightning, .toy, .bat, .cloud, .hat]
    /// Extra keys that do the same job as one above: Esc also pauses, and either Shift runs.
    static let alsoWatched: [GCKeyCode] = [.escape, .rightShift]
}
