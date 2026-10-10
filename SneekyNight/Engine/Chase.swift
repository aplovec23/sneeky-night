import SwiftUI
import Observation

/// Mom or Dad coming to find you. Instead of appearing next to you, they walk in through a door
/// and head for you. You can outrun them, jump over them, hide (they might still check your
/// hiding place) or stun them. After a minute without catching you they give up.
@MainActor
@Observable
final class Chase {
    enum Who { case mom, dad }

    var who: Who = .mom
    /// Someone is awake and looking for you (they may not have reached this room yet).
    var active = false
    /// They are in the room you're in.
    var visible = false
    var pos = CGPoint.zero
    var facingRight = true
    var walking = false
    /// Seconds left seeing stars (vines, the bat, a thrown toy).
    var stunned = 0.0
    /// Seconds Dad is still laughing at your taunt.
    var laughing = 0.0
    /// Seconds until they give up.
    var timeLeft = 0.0
    /// What they're saying right now (a bubble over their head).
    var speech: String?
    /// The other grown-up, when they've come to see what the noise is. They stop and talk.
    var partner: Who?
    var partnerPos = CGPoint.zero
    var partnerWalking = false
    var partnerSpeech: String?
    /// What your brother is saying back, when a grown-up bumps into him.
    var brotherSpeech: String?
    /// Seconds of talking left. Nobody chases you while they talk.
    var talkLeft = 0.0
    var talking: Bool { talkLeft > 0 }

    @ObservationIgnored weak var engine: GameEngine?
    /// Where they walk in for the room you're in, and how many seconds that takes.
    @ObservationIgnored var entrance: (Who) -> (point: CGPoint, delay: Double) = { _ in (.zero, 2) }
    /// For mazes: the next spot to walk to on the way from A to B. Nil = walk straight there.
    @ObservationIgnored var waypoint: ((CGPoint, CGPoint) -> CGPoint)?
    @ObservationIgnored var onCaught: (Who, String) -> Void = { _, _ in }
    @ObservationIgnored var onGaveUp: (Who) -> Void = { _ in }
    @ObservationIgnored var setBanner: (String?) -> Void = { _ in }
    @ObservationIgnored var award: (Badge) -> Void = { _ in }
    @ObservationIgnored var brotherFollowing: () -> Bool = { false }
    /// Where your brother is standing, if he's awake and in this room.
    @ObservationIgnored var brotherPos: () -> CGPoint? = { nil }
    @ObservationIgnored private var meetIn = Double.infinity
    @ObservationIgnored private var metBrother = false
    @ObservationIgnored private var script: [(Speaker, String)] = []
    @ObservationIgnored private var lineTime = 0.0
    @ObservationIgnored private var linePause = 3.6
    @ObservationIgnored private var speechTime = 0.0
    @ObservationIgnored private var mutterIn = 4.0

    private enum Speaker { case chaser, partner, brother }

    /// Mom and Dad meet in the middle of the night and talk about the noisy house. About a minute.
    private static let houseTalk: [(Who, String)] = [
        (.mom, "Did you hear that noise too?"), (.dad, "I thought it was the fridge again."),
        (.mom, "This house is SO noisy at night."), (.dad, "It's the old floorboards. Creak, creak, creak."),
        (.mom, "And the pipes! Bang, bang, all night."), (.dad, "I'll fix them on Saturday."),
        (.mom, "You said that LAST Saturday."), (.dad, "...Did I?"),
        (.mom, "Maybe it's the kids."), (.dad, "At this hour? They're fast asleep."),
        (.mom, "I'm sure I heard footsteps."), (.dad, "Probably the dog next door."),
        (.mom, "We should get thicker carpets."), (.dad, "Or earplugs. Earplugs are cheaper."),
        (.mom, "Very funny."), (.dad, "Fine. One more look around, then bed."),
    ]

    @ObservationIgnored private var door = CGPoint.zero
    @ObservationIgnored private var enterDelay = 0.0
    @ObservationIgnored private var lookAround = 0.0
    @ObservationIgnored private var bannerTime = 0.0
    @ObservationIgnored private var wasConcealed = false
    @ObservationIgnored private var sawHide = false
    @ObservationIgnored private var checkedHide = false
    @ObservationIgnored private var wander: CGPoint?
    @ObservationIgnored private var brotherUsed = false
    @ObservationIgnored private var laughed = false
    /// How many times they've tried to grab you while you're untouchable (creative mode).
    @ObservationIgnored private var touchedGhost = 0

    static let giveUpAfter = 60.0

    var momOut: Bool { active && who == .mom }
    var dadOut: Bool { active && who == .dad }
    private var speed: CGFloat {
        Difficulty.current.chaserSpeed(base: who == .mom ? 225 : 245, yours: engine?.pace ?? 290)
    }

    func reset() {
        active = false
        visible = false
        walking = false
        stunned = 0
        laughing = 0
        bannerTime = 0
        brotherUsed = false
        laughed = false
        speech = nil
        partner = nil
        partnerSpeech = nil
        brotherSpeech = nil
        talkLeft = 0
        script = []
        meetIn = .infinity
        metBrother = false
    }

    /// Someone heard or saw you. Does nothing if a chase is already on.
    /// Pass `from` when they're already standing somewhere in this room.
    func alarm(_ who: Who, _ text: String, from start: CGPoint? = nil) {
        guard let engine, !active else { return }
        self.who = who
        active = true
        timeLeft = Self.giveUpAfter
        stunned = 0
        laughing = 0
        laughed = false
        wasConcealed = engine.concealed
        sawHide = false
        checkedHide = false
        wander = nil
        speech = nil
        partner = nil
        talkLeft = 0
        mutterIn = 4
        // Four chases in ten, the other grown-up comes to see what's going on.
        meetIn = Int.random(in: 0..<10) < 4 ? Double.random(in: 9...20) : .infinity
        if let start {
            door = start
            pos = start
            visible = true
            enterDelay = 0
            lookAround = 0
        } else {
            let way = entrance(who)
            door = way.point
            enterDelay = way.delay
            visible = false
        }
        engine.timerOn = false
        setBanner(text)
        bannerTime = 3.5
        (who == .mom ? Sound.mom : Sound.dad).play()
    }

    /// You went through a door: they follow a couple of seconds later through the same one.
    func playerChangedRoom(entry: CGPoint) {
        guard active else { return }
        visible = false
        walking = false
        door = entry
        enterDelay = 2.4
        sawHide = false
        wander = nil
    }

    /// Creative mode: the other grown-up comes over right now and they start talking.
    func forceMeet() {
        if active && visible && partner == nil && !talking { meetIn = 0 }
    }

    /// Returns false when there's nobody here to stun.
    func stun(_ seconds: Double, momOnly: Bool) -> Bool {
        guard active, visible, !(momOnly && who == .dad) else { return false }
        stunned = max(stunned, seconds)
        walking = false
        return true
    }

    /// Taunting in front of them: badges for Mom, and Dad laughs (once) and gives you 10 seconds.
    func taunted() {
        guard active, visible, let engine else { return }
        if stunned > 0 {
            if who == .mom { award(.trolledAgain) }
            return
        }
        guard !engine.concealed, hypot(engine.player.x - pos.x, engine.player.y - pos.y) < 560 else { return }
        if who == .mom {
            award(.trolledMom)
        } else if !laughed {
            laughed = true
            laughing = Difficulty.current.dadLaugh
            walking = false
            award(.funnySon)
            setBanner("Dad: \"Ha! That's funny, son. You've got \(laughing >= 60 ? "a whole minute" : "10 seconds")...\"")
            bannerTime = 4
        }
    }

    func tick(_ dt: Double) {
        guard active, let engine else { return }
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { setBanner(nil) }
        }
        if !talking { timeLeft -= dt }
        if timeLeft <= 0 {
            let who = self.who
            reset()
            setBanner(nil)
            onGaveUp(who)
            return
        }
        if stunned > 0 {
            stunned -= dt
            return
        }
        if laughing > 0 {
            laughing -= dt
            return
        }
        if !visible {
            enterDelay -= dt
            if enterDelay <= 0 {
                visible = true
                pos = door
                // A moment in the doorway to look around, so you're never caught the instant they arrive.
                lookAround = 1.2
                Sound.door.play(volume: 0.5)
            }
            return
        }
        if lookAround > 0 {
            lookAround -= dt
            return
        }

        if speechTime > 0 {
            speechTime -= dt
            if speechTime <= 0 { speech = nil }
        }
        if talking {
            tickTalk(dt)
            return
        }
        if let other = partner {
            // The other grown-up is walking over. Whoever was chasing you waits for them.
            walking = false
            let dx = pos.x - partnerPos.x, dy = pos.y - partnerPos.y
            let distance = hypot(dx, dy)
            if distance > 95 {
                let step = min(distance - 95, 230 * CGFloat(dt))
                partnerPos.x += dx / distance * step
                partnerPos.y += dy / distance * step
                partnerWalking = true
            } else {
                partnerWalking = false
                facingRight = partnerPos.x > pos.x
                let mine = who
                start(talk: Self.houseTalk.map { ($0.0 == mine ? .chaser : .partner, $0.1) }, pause: 3.6)
                setBanner("\(mine == .mom ? "Mom and Dad" : "Dad and Mom") are talking about the noise. You've got a minute!")
                bannerTime = 4.5
                _ = other
            }
            return
        }
        meetIn -= dt
        if meetIn <= 0 {
            meetIn = .infinity
            partner = who == .mom ? .dad : .mom
            partnerPos = door
            say(who == .mom ? "Huh? Is that you, dear?" : "Honey? What are you doing up?", for: 2.5)
            Sound.door.play(volume: 0.4)
            return
        }
        if !metBrother, let brother = brotherPos(), hypot(brother.x - pos.x, brother.y - pos.y) < 130 {
            metBrother = true
            facingRight = brother.x > pos.x
            walking = false
            start(talk: who == .mom
                  ? [(.chaser, "What are YOU doing up?"), (.brother, "Um... getting a glass of water!"), (.chaser, "Back to bed. Right now, mister.")]
                  : [(.chaser, "Hey, buddy. Can't sleep?"), (.brother, "I dreamed about a giant duck."), (.chaser, "...Okay. Off to bed, champ.")],
                  pause: 2.8)
            return
        }

        let player = engine.player
        let hiding = engine.concealed
        mutterIn -= dt
        if mutterIn <= 0 {
            mutterIn = .random(in: 5...9)
            let lines = hiding && !sawHide
                ? ["Where did you go?", "I know you're in here...", "Come out, come out...", "Hmm. Nobody here?"]
                : who == .mom ? ["Back to bed!", "Stop right there!", "I can SEE you!", "It's the middle of the night!"]
                              : ["Hold it, kiddo!", "Hey! Come back!", "No running in the house!", "I'm too old for this..."]
            say(lines.randomElement()!, for: 2.4)
        }
        if hiding && !wasConcealed {
            // Did they see you duck into your hiding place?
            sawHide = hypot(player.x - pos.x, player.y - pos.y) < 380
            checkedHide = false
        }
        if !hiding { sawHide = false }
        wasConcealed = hiding

        // Easy: they never look in hiding places. Chaos and No Mercy: they always know where you are.
        let mode = Difficulty.current
        if mode.atLeastChaos && hiding { sawHide = true }
        var target = player
        if hiding && !sawHide {
            // Lost you: wander about, sometimes drifting back to where you are.
            if wander == nil || hypot(pos.x - wander!.x, pos.y - wander!.y) < 30 {
                wander = Int.random(in: 0..<3) == 0 ? player
                    : CGPoint(x: .random(in: 80...max(81, engine.width - 80)), y: .random(in: engine.floor))
            }
            target = wander!
        }
        let next = waypoint?(pos, target) ?? target
        let dx = next.x - pos.x, dy = next.y - pos.y
        let distance = hypot(dx, dy)
        if distance > 4 {
            let step = min(distance, speed * CGFloat(dt))
            pos.x += dx / distance * step
            pos.y += dy / distance * step * (abs(dx) > abs(dy) ? 1 : 0.8)
            if abs(dx) > 3 { facingRight = dx > 0 }
            if !walking { walking = true }
        } else if walking {
            walking = false
        }

        let name = who == .mom ? "Mom" : "Dad"
        if hiding {
            guard mode != .easy, abs(player.x - pos.x) < 46, abs(player.y - pos.y) < 110 else { return }
            if sawHide {
                caught("\(name) saw where you hid... and found you!")
            } else if !checkedHide {
                // Walking past your hiding place: half the time they look inside.
                checkedHide = true
                if Bool.random() {
                    Sound.closet.play()
                    caught("\(name) looked in your hiding place... and found you!")
                }
            }
        } else if abs(player.x - pos.x) < 48, abs(player.y - pos.y) < 42, engine.z < 50 {
            caught("\(name) caught you!")
        }
    }

    private func say(_ text: String, for seconds: Double) {
        speech = text
        speechTime = seconds
    }

    private func start(talk lines: [(Speaker, String)], pause: Double) {
        script = lines
        linePause = pause
        lineTime = 0
        talkLeft = Double(lines.count) * pause
        speechTime = 0
    }

    private func tickTalk(_ dt: Double) {
        talkLeft -= dt
        lineTime -= dt
        if lineTime <= 0, !script.isEmpty {
            lineTime = linePause
            let (speaker, text) = script.removeFirst()
            speech = speaker == .chaser ? text : nil
            partnerSpeech = speaker == .partner ? text : nil
            brotherSpeech = speaker == .brother ? text : nil
        }
        guard talkLeft <= 0 else { return }
        talkLeft = 0
        speech = nil
        partnerSpeech = nil
        brotherSpeech = nil
        if partner != nil {
            // The other one goes back to bed; the chase carries on.
            partner = nil
            Sound.door.play(volume: 0.4)
        }
    }

    private func caught(_ message: String) {
        // Practice mode (and creative "ghost"): nobody can catch you.
        if engine?.safe == true {
            stunned = 4
            walking = false
            if Settings.shared.practice {
                say("Just practice... carry on.", for: 3)
                engine?.say("Practice mode: I would have been caught right here!", seconds: 2.5)
            } else {
                // The untouchable buff: their hands go straight through you, and it's very confusing.
                stunned = 3
                touchedGhost += 1
                let ghostly = touchedGhost >= 3 || Int.random(in: 0..<3) == 0
                let confused = who == .mom
                    ? ["Why can't I touch you?!", "What?! My hands went right through you!", "Hold still! Why can't I grab you?!",
                       "This is impossible... I'm still dreaming, aren't I?"]
                    : ["Huh? Why can't I grab you, kiddo?!", "My hands... went right through you?!", "I need more coffee. Or less."]
                let ghostLines = who == .mom
                    ? ["Are you... a GHOST?!", "AAAH! A ghost! A ghost in my house!", "You're not my child, you're a GHOST!"]
                    : ["Honey! HONEY! There's a ghost in the house!", "Wait... are you a ghost?!"]
                say((ghostly ? ghostLines : confused).randomElement()!, for: 3)
                engine?.say(["Hee hee. Untouchable!", "Boo!", "Can't touch this!"].randomElement()!, seconds: 2)
            }
            return
        }
        // Once per try, a brother who's following you throws his toy at Mom.
        if who == .mom && brotherFollowing() && !brotherUsed {
            brotherUsed = true
            stunned = 60
            walking = false
            award(.goAwayMom)
            Sound.squeak.play()
            Sound.table.play()
            engine?.say("My brother threw his toy at Mom! She's seeing stars. RUN!", seconds: 3.5)
            return
        }
        let who = self.who
        active = false
        walking = false
        setBanner(nil)
        onCaught(who, message)
    }
}

/// Draws whoever is chasing you, where they are in the room.
struct ChaserView: View {
    let chase: Chase

    var body: some View {
        if chase.active && chase.visible {
            Group {
                if chase.who == .mom {
                    MomView(stunned: chase.stunned > 0, walking: chase.walking)
                } else {
                    DadView(stunned: chase.stunned > 0, walking: chase.walking, laughing: chase.laughing > 0)
                }
            }
            .scaleEffect(x: chase.talking && !chase.facingRight ? -1 : 1, y: 1)
            .anchored(at: chase.pos)
            if let other = chase.partner {
                Group {
                    if other == .mom {
                        MomView(stunned: false, walking: chase.partnerWalking)
                    } else {
                        DadView(stunned: false, walking: chase.partnerWalking, laughing: false)
                    }
                }
                .anchored(at: chase.partnerPos)
                if let text = chase.partnerSpeech {
                    SpeechBubble(text: text, tint: other == .mom ? .pink : .blue, small: true)
                        .position(x: chase.partnerPos.x, y: chase.partnerPos.y - 270)
                }
            }
            if let text = chase.speech {
                SpeechBubble(text: text, tint: chase.who == .mom ? .pink : .blue, small: true)
                    .position(x: chase.pos.x, y: chase.pos.y - 270)
            }
            if let text = chase.brotherSpeech, let brother = chase.brotherPos() {
                SpeechBubble(text: text, tint: .green, small: true)
                    .position(x: brother.x, y: brother.y - 190)
            }
        }
    }
}
