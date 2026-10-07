import SwiftUI
import Observation

/// Your little brother. Taunting in his room wakes him up; then you can talk to him and
/// ask him to follow you. He's only company — obstacles and grown-ups ignore him.
@MainActor
@Observable
final class SiblingBuddy {
    enum State { case asleep, awake, following }

    var state: State = .asleep
    var pos = CGPoint(x: 1050, y: 610)
    var facingRight = false
    var walking = false
    /// True while the talk menu is open.
    var talking = false
    var line = ""
    /// How many times you've taunted him while he's awake (5 = the Crashout badge).
    var taunts = 0

    static let look = Look(gender: .boy, skin: 1, shirt: 3, pattern: 4, cap: 0)
    static let bedside = CGPoint(x: 1010, y: 610)

    func reset() {
        state = .asleep
        talking = false
        walking = false
        taunts = 0
    }

    /// Returns true on the 5th taunt, when he finally loses it.
    func taunted() -> Bool {
        guard state != .asleep else { return false }
        taunts += 1
        return taunts == 5
    }

    func wake() {
        guard state == .asleep else { return }
        state = .awake
        pos = Self.bedside
        facingRight = false
    }

    /// Jump next to the player (used when you both walk through a door).
    func jump(to player: CGPoint) {
        pos = CGPoint(x: max(60, player.x - 70), y: player.y)
    }

    func update(player: CGPoint, playerFacingRight: Bool, dt: Double) {
        guard state == .following else {
            if walking { walking = false }
            return
        }
        let target = CGPoint(x: player.x + (playerFacingRight ? -85 : 85), y: player.y)
        let dx = target.x - pos.x, dy = target.y - pos.y
        let distance = hypot(dx, dy)
        if distance > 14 {
            let step = min(distance, 330 * CGFloat(dt))
            pos.x += dx / distance * step
            pos.y += dy / distance * step
            if abs(dx) > 4 { facingRight = dx > 0 }
            if !walking { walking = true }
        } else if walking {
            walking = false
        }
    }

    func startTalking() {
        line = state == .following ? "What's up? I'm right behind you!" : "Huh?! What are you doing in my room?"
        talking = true
    }
}

struct BuddyView: View {
    let buddy: SiblingBuddy

    var body: some View {
        VStack(spacing: 2) {
            Text("Brother")
                .font(.game(15))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.black.opacity(0.4), in: Capsule())
            CharacterView(look: SiblingBuddy.look, facingRight: buddy.facingRight, walking: buddy.walking)
        }
        .scaleEffect(0.78, anchor: .bottom)
        .frame(width: 110, height: 150, alignment: .bottom)
        .anchored(at: buddy.pos)
    }
}

/// Talk options with your brother. `tip` is the hint he gives in this level.
struct TalkOverlay: View {
    let buddy: SiblingBuddy
    let tip: String
    /// Set when you're holding a toy you could give him.
    var onGiveToy: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    CharacterView(look: SiblingBuddy.look, facingRight: true)
                        .scaleEffect(0.8)
                        .frame(width: 80, height: 130)
                    Text(buddy.line)
                        .font(.game(24, .semibold))
                        .foregroundStyle(.black)
                        .padding(18)
                        .frame(width: 420, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
                option("What are you doing up?") {
                    buddy.line = "I heard you being silly! Are you sneaking out? That's so cool!"
                }
                option("Got any tips?") { buddy.line = tip }
                if let onGiveToy {
                    option("Give him a toy") {
                        onGiveToy()
                        buddy.line = "A toy? For ME? You're the best!"
                    }
                }
                if buddy.state == .following {
                    option("Wait here") {
                        buddy.state = .awake
                        buddy.line = "Okay. I'll wait right here."
                    }
                } else {
                    option("Follow me") {
                        buddy.state = .following
                        buddy.line = "Yay! I'll be super quiet. Promise!"
                    }
                }
                option("Go back to sleep") {
                    buddy.state = .asleep
                    buddy.talking = false
                    onClose()
                }
                option("Bye") {
                    buddy.talking = false
                    onClose()
                }
            }
            .padding(30)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 34))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
        }
    }

    private func option(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Text(title)
                .font(.game(24))
                .foregroundStyle(.white)
                .frame(width: 440, height: 52)
                .background(Color(red: 0.35, green: 0.30, blue: 0.70), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

extension Popup {
    /// The pop-up for a boost or accessory found while searching.
    static func loot(_ loot: Loot, take: @escaping () -> Void) -> Popup {
        switch loot {
        case .accessory(let item):
            Popup(title: "New accessory!", message: "You found the \(item.name)!\nPut it on in Customize Character on the menu.",
                  symbol: item.symbol, color: item.color == .black ? .white : item.color, button: "Awesome!", action: take)
        case .boost(let boost):
            Popup(title: "RARE BOOST!", message: "\(boost.name)!\n\(boost.about)\nIt's already on. Boosts stack!",
                  symbol: boost.symbol, color: boost.color, button: "WOW!", action: take)
        case .bat:
            Popup(title: "You found a BAT!", message: "Yours to keep forever. Press B to bonk Mom: she sees stars for 2 seconds (ready again after 5).",
                  symbol: "figure.baseball", color: .orange, button: "Take", action: take)
        }
    }
}
