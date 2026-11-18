import SwiftUI

/// How hard the whole game is. Picked on the menu; saved on the device for every save file.
/// Mild is the game as it always was. Every other mode changes the numbers below.
enum Difficulty: Int, CaseIterable, Identifiable {
    case easy, mild, hard, chaos, noMercy

    var id: Int { rawValue }
    static var current: Difficulty { Difficulty(rawValue: Settings.shared.difficulty) ?? .mild }

    var name: String {
        switch self {
        case .easy: "Easy"
        case .mild: "Mild"
        case .hard: "Hard"
        case .chaos: "Chaos"
        case .noMercy: "No Mercy"
        }
    }
    var symbol: String {
        switch self {
        case .easy: "leaf.fill"
        case .mild: "moon.fill"
        case .hard: "flame.fill"
        case .chaos: "tornado"
        case .noMercy: "bolt.trianglebadge.exclamationmark.fill"
        }
    }
    var color: Color {
        switch self {
        case .easy: Color(red: 0.25, green: 0.70, blue: 0.40)
        case .mild: Color(red: 0.35, green: 0.45, blue: 0.85)
        case .hard: Color(red: 0.90, green: 0.50, blue: 0.15)
        case .chaos: Color(red: 0.80, green: 0.20, blue: 0.25)
        case .noMercy: Color(red: 0.45, green: 0.05, blue: 0.20)
        }
    }
    /// What changes, in a few short lines for the picker.
    var about: [String] {
        switch self {
        case .easy: ["Slower hazards, quieter steps, longer clock", "You're faster and jump a little higher",
                     "Mom and Dad can't check hiding places", "Codes are just 3 numbers; fewer dogs and keys, smaller chores",
                     "10 taunts to wake Mom; Dad laughs for a whole minute"]
        case .mild: ["The game as it has always been", "The main difficulty"]
        case .hard: ["Hazards are faster and hurt more", "More to collect: 50 dogs, 20 hotel floors, more chores",
                     "A slightly shorter clock", "Boosts and moonlights turn up more often"]
        case .chaos: ["Everything in Hard, but worse", "Mom and Dad move at 75% of your speed",
                      "Hiding never works: they always find you", "Hotel workers check hiding places"]
        case .noMercy: ["Everything in Chaos, plus:", "A very short clock, and Mom outruns you",
                        "Hurts much more; water puddles in Levels 2–3", "Boxes and drawers can turn out to be traps (50-50)",
                        "Strangers come after you", "The Guide really gets things wrong, and can get hurt",
                        "No practice mode until you win the level"]
        }
    }

    var atLeastHard: Bool { rawValue >= Difficulty.hard.rawValue }
    var atLeastChaos: Bool { rawValue >= Difficulty.chaos.rawValue }

    /// Picks a number by how much there is to do: fewer on Easy, more on Hard and above.
    func pick<T>(easy: T, mild: T, hard: T) -> T {
        self == .easy ? easy : self == .mild ? mild : hard
    }

    /// Every level's clock is multiplied by this.
    var timeScale: Double {
        switch self {
        case .easy: 1.4
        case .mild: 1
        case .hard, .chaos: 0.85
        case .noMercy: 0.5
        }
    }
    /// Rolling toys, strangers, spikes and everything else that moves and hurts.
    var hazardSpeed: CGFloat {
        switch self {
        case .easy: 0.6
        case .mild: 1
        case .hard: 1.3
        case .chaos: 1.6
        case .noMercy: 1.8
        }
    }
    var damageScale: Double {
        switch self {
        case .easy, .mild: 1
        case .hard: 1.5
        case .chaos: 2
        case .noMercy: 3.5
        }
    }
    var playerSpeed: CGFloat { self == .easy ? 1.15 : 1 }
    /// Multiplies the jump's push (1.06 is a little higher).
    var playerJump: CGFloat { self == .easy ? 1.06 : 1 }
    /// All noise is divided by this.
    var quiet: Double { self == .easy ? 1.5 : 1 }
    /// Noise from one taunt. On Easy it takes about 10 taunts in a row to wake Mom.
    var tauntNoise: Double { self == .easy ? 18 : 34 }
    /// Seconds Dad laughs when you taunt him.
    var dadLaugh: Double { self == .easy ? 60 : 10 }
    /// Boosts turn up this many times more often.
    var lootScale: Double {
        switch self {
        case .easy, .mild: 1
        case .hard: 1.5
        case .chaos: 2
        case .noMercy: 3
        }
    }
    /// Moonlights for winning a level are multiplied by this.
    var moonlightScale: Double {
        switch self {
        case .easy: 0.5
        case .mild: 1
        case .hard: 1.5
        case .chaos: 2
        case .noMercy: 3
        }
    }
    /// Orbs from each hit in the dungeon are multiplied by this.
    var orbScale: Int {
        switch self {
        case .easy, .mild: 1
        case .hard: 2
        case .chaos: 3
        case .noMercy: 4
        }
    }

    /// How fast a grown-up chases, given their usual speed and how fast you're going right now.
    func chaserSpeed(base: CGFloat, yours: CGFloat) -> CGFloat {
        switch self {
        // Chaos: always 75% of your speed.
        case .chaos: yours * 0.75
        case .noMercy: max(base, yours * 1.12)
        default: base
        }
    }
}

/// The difficulty picker.
struct DifficultyView: View {
    let onBack: () -> Void
    @Bindable private var settings = Settings.shared

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 14) {
                ZStack {
                    HStack {
                        RoundIconButton(symbol: "chevron.left", action: onBack)
                        Spacer()
                    }
                    Text("Difficulty").font(.game(52, .heavy)).foregroundStyle(.white)
                }
                Text("Pick how hard the game is. You can change it any time; it applies the next time a level starts.")
                    .font(.game(19, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Difficulty.allCases) { mode in
                        card(mode)
                    }
                }
                Text("Modes open one story level at a time: win a level on Mild to open Hard for it, Hard to open Chaos, and Chaos (with 1000 moonlights and 35 badges) to open No Mercy. Side levels are open on every mode. The harder the mode, the more boosts and moonlights.")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.game(17, .semibold))
                    .foregroundStyle(Palette.gold)
                Spacer()
            }
            .padding(30)
        }
    }

    private func card(_ mode: Difficulty) -> some View {
        let on = settings.difficulty == mode.rawValue
        return Button {
            SoundPlayer.shared.tap()
            settings.difficulty = mode.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: mode.symbol)
                    Text(mode.name).lineLimit(1).minimumScaleFactor(0.7)
                }
                .font(.game(24, .heavy))
                ForEach(mode.about, id: \.self) { line in
                    HStack(alignment: .top, spacing: 5) {
                        Text("•")
                        Text(line).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.game(14, .medium))
                    .opacity(0.92)
                }
                Spacer(minLength: 0)
                Text(on ? "✓ PLAYING" : "Tap to pick")
                    .font(.game(15, .heavy))
                    .foregroundStyle(on ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(on ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.18)), in: Capsule())
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(width: 208, height: 390, alignment: .topLeading)
            .background(LinearGradient(colors: [mode.color, mode.color.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(on ? Palette.gold : .white.opacity(0.25), lineWidth: on ? 5 : 2))
            .scaleEffect(on ? 1.03 : 1)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Shown instead of a story level when the chosen difficulty isn't open for it yet:
/// what it still needs, and a button to play on the hardest mode you've unlocked.
struct ModeLockedView: View {
    @Environment(GameState.self) private var game
    let level: Int
    let onBack: () -> Void

    var body: some View {
        let mode = Difficulty.current
        let fallback = game.playableMode(mode, level: level)
        ZStack {
            NightSky()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                    Text("\(mode.name) is locked for Level \(level)")
                }
                .font(.game(36, .heavy))
                .foregroundStyle(.white)
                Text("Each mode opens one level at a time. Win a level on Mild to open Hard for it, on Hard to open Chaos, and on Chaos to open No Mercy. Side levels are open on every mode.")
                    .font(.game(19, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(game.modeNeeds(mode, level: level), id: \.text) { need in
                    HStack(spacing: 10) {
                        Image(systemName: need.met ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(need.met ? .green : .white.opacity(0.5))
                        Text(need.text)
                    }
                    .font(.game(22, .semibold))
                    .foregroundStyle(.white)
                }
                HStack(spacing: 14) {
                    BigButton(title: "Back", color: .gray, action: onBack)
                    BigButton(title: "Play on \(fallback.name)", symbol: fallback.symbol, color: fallback.color) {
                        Settings.shared.difficulty = fallback.rawValue
                    }
                }
                .scaleEffect(0.85, anchor: .leading)
                .padding(.top, 6)
            }
            .padding(30)
            .frame(width: 720, alignment: .leading)
            .background(Color(red: 0.12, green: 0.10, blue: 0.28), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(mode.color.opacity(0.8), lineWidth: 3))
        }
    }
}
