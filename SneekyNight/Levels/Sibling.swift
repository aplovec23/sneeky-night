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
    var facing: Facing = .west
    var walking = false
    /// True while the talk menu is open.
    var talking = false
    var line = ""
    /// How many times you've taunted him while he's awake (5 = the Crashout badge).
    var taunts = 0

    /// His face: cross once you've taunted him silly, worried on the way there, happy while you
    /// chat or walk together, and still sleepy just after he wakes up.
    var mood: Mood {
        if taunts >= 5 { return .cross }
        if taunts >= 3 { return .worried }
        if talking { return .happy }
        if state == .awake { return .sleepy }
        return walking ? .happy : .calm
    }

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
            facing = Facing.moving(dx: dx, dy: dy)
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
            CharacterView(look: SiblingBuddy.look, facingRight: buddy.facingRight, walking: buddy.walking, expression: buddy.mood,
                          facing: buddy.walking ? buddy.facing : nil)
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
    /// Picking topics for a proper conversation.
    @State private var chatting = false
    /// The topic being talked about, and how far into it you are.
    @State private var topic: Int?
    @State private var step = 0
    @State private var yourLine: String?

    /// Things to talk about. Each topic goes back and forth a few times.
    static let topics: [(title: String, talk: [(you: String, him: String)])] = [
        ("Where I'm going", [
            ("I'm going to find Grandpa.", "Grandpa?! But nobody will tell us where he is!"),
            ("Auntie knows. Uncle's going to drive me to her city.", "Whoa. That's really far. Farther than school."),
            ("I'll bring him a lantern from the festival.", "Bring me one too? A green one. Please please please."),
        ]),
        ("Your toys", [
            ("Why are your toys ALL over the floor?", "It's not a mess. It's a trap. For burglars."),
            ("I'm the one who keeps stepping on them!", "...Then the trap works."),
            ("Which one's your favourite?", "The squeaky one. I only lend it to people I really like."),
        ]),
        ("Scary stuff", [
            ("Are you scared of the dark?", "No! ...A little. Only the bit under the bed."),
            ("There's only a lockbox under mine.", "That's exactly what a monster would want you to think."),
            ("I'll check under yours when I'm back.", "Okay. Deal. Don't forget."),
        ]),
        ("Mom and Dad", [
            ("Do you think Mom will be mad?", "She'll do the eyebrow thing. Then she'll hug you really hard."),
            ("And Dad?", "Dad will laugh, and then pretend he didn't."),
            ("Cover for me if they ask?", "I'll say you're in the bathroom. For... nine hours."),
        ]),
        ("A joke", [
            ("Tell me a joke.", "Why did the kid bring a ladder to bed?"),
            ("I don't know. Why?", "To get to HIGH sleep! ...Get it? Like high school?"),
            ("That was terrible.", "You laughed. I saw your face do the thing."),
        ]),
        ("When I'm gone", [
            ("What will you do while I'm away?", "Build the biggest block tower ever. Up to the ceiling."),
            ("Don't knock over the lamp.", "No promises."),
            ("I'll miss you, you know.", "...Me too. Come back fast, okay?"),
        ]),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                if let yourLine {
                    Text("You: \(yourLine)")
                        .font(.game(20, .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(width: 420, alignment: .trailing)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 18))
                        .frame(width: 516, alignment: .trailing)
                }
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
                if chatting { conversation } else { menu }
            }
            .padding(30)
            .background(Color(red: 0.14, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 34))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
        }
    }

    /// A conversation: pick a topic, then it goes back and forth.
    @ViewBuilder private var conversation: some View {
        if let topic {
            let talk = Self.topics[topic].talk
            if step + 1 < talk.count {
                option("Keep talking") { say(topic, step + 1) }
            } else {
                option("Talk about something else") {
                    self.topic = nil
                    yourLine = nil
                    buddy.line = "What else do you want to talk about?"
                }
            }
            option("That's enough talking") { endChat() }
        } else {
            LazyVGrid(columns: [GridItem(.fixed(250), spacing: 12), GridItem(.fixed(250), spacing: 12)], spacing: 10) {
                ForEach(Self.topics.indices, id: \.self) { i in
                    option(Self.topics[i].title, width: 250) { say(i, 0) }
                }
            }
            option("That's enough talking") { endChat() }
        }
    }

    private func say(_ topic: Int, _ step: Int) {
        self.topic = topic
        self.step = step
        let exchange = Self.topics[topic].talk[step]
        yourLine = exchange.you
        buddy.line = exchange.him
    }

    private func endChat() {
        chatting = false
        topic = nil
        yourLine = nil
        buddy.line = "That was nice. We should talk more!"
    }

    @ViewBuilder private var menu: some View {
        Group {
                option("Let's talk") {
                    chatting = true
                    buddy.line = "Talk? At night? Okay! What about?"
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
    }

    private func option(_ title: String, width: CGFloat = 440, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Text(title)
                .font(.game(24))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
                .frame(width: width, height: 52)
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
            Popup(title: "RARE BOOST!", message: "\(boost.name)!\n\(boost.about)\n\(boost.origin)\nIt's already on. Boosts stack!",
                  symbol: boost.symbol, color: boost.color, button: "WOW!", action: take)
        case .bat:
            Popup(title: "You found a BAT!", message: "Yours to keep forever. Press B to bonk Mom: she sees stars for 2 seconds (ready again after 5).",
                  symbol: "figure.baseball", color: .orange, button: "Take", action: take)
        }
    }
}
