import SwiftUI

/// The player, drawn from simple shapes. Its frame is 100×160 with the feet at the bottom.
struct CharacterView: View {
    var look: Look
    var facingRight = true
    var walking = false
    var crouching = false
    var taunting = false
    /// The face to make. Nil: the resting face picked in Customize Character.
    var expression: Mood?

    init(look: Look, facingRight: Bool = true, walking: Bool = false, crouching: Bool = false, taunting: Bool = false,
         expression: Mood? = nil) {
        self.look = look
        self.facingRight = facingRight
        self.walking = walking
        self.crouching = crouching
        self.taunting = taunting
        self.expression = expression
    }

    private var mood: Mood { expression ?? Mood(rawValue: look.face) ?? .calm }

    init(gender: Gender, facingRight: Bool = true) {
        self.init(look: .starter(gender), facingRight: facingRight)
    }

    var body: some View {
        // Always a little alive: standing still you breathe, sway and look about; moving runs at full speed.
        TimelineView(.animation(minimumInterval: walking || taunting ? nil : 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // Creeping is slower than walking, and a crouched character keeps breathing and looking around.
            figure(swing: walking ? sin(t * (crouching ? 8 : 13)) : 0, wiggle: taunting ? sin(t * 22) : 0,
                   breath: sin(t * (crouching ? 2.4 : 1.8) + Double(look.skin)), time: t)
        }
        .frame(width: 100, height: 160)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
        .animation(.easeInOut(duration: 0.15), value: crouching)
    }

    private var skin: Color { LookOptions.skins[look.skin % LookOptions.skins.count] }
    private var shirt: Color { LookOptions.allShirts[look.shirt % LookOptions.allShirts.count] }
    private var pattern: String? { LookOptions.patterns[look.pattern % LookOptions.patterns.count] }
    private var cap: Color? { LookOptions.allCaps[look.cap % LookOptions.allCaps.count] }
    private var hair: Color {
        if look.hairColor > 0, let picked = LookOptions.hairColors[look.hairColor % LookOptions.hairColors.count] { return picked }
        return look.gender == .boy ? Color(red: 0.33, green: 0.21, blue: 0.12) : Color(red: 0.55, green: 0.30, blue: 0.14)
    }

    /// Trousers: the chosen colour, or the T-shirt colour a little darker (the original look).
    private var trousers: Color { look.pants >= 0 ? LookOptions.pants[look.pants % LookOptions.pants.count] : shirt }
    private var trouserShade: Double { look.pants >= 0 ? 0 : -0.22 }
    private var shoe: Color { LookOptions.shoes[abs(look.shoes) % LookOptions.shoes.count] }
    private var eyeColor: Color { LookOptions.eyes[abs(look.eyes) % LookOptions.eyes.count] }

    private func leg(_ angle: Double) -> some View {
        VStack(spacing: -4) {
            Capsule().fill(trousers).brightness(trouserShade).frame(width: 17, height: 40)
            Capsule().fill(shoe).frame(width: 24, height: 11).offset(x: 4)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    private func arm(_ angle: Double) -> some View {
        VStack(spacing: -3) {
            Capsule().fill(shirt).frame(width: 14, height: 36)
            Circle().fill(skin).frame(width: 13, height: 13)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    /// A bent leg for crouching: thigh pointing forward, shin tucked under, slipper on the floor.
    private func bentLeg(shuffle: Double) -> some View {
        ZStack {
            Capsule().fill(trousers).brightness(trouserShade).frame(width: 34, height: 17).position(x: 20, y: 9)
            Capsule().fill(trousers).brightness(trouserShade - 0.06).frame(width: 16, height: 24).position(x: 30 + shuffle, y: 22)
            Capsule().fill(shoe).frame(width: 24, height: 11).position(x: 34 + shuffle, y: 34)
        }
        .frame(width: 50, height: 40)
    }

    private func figure(swing: Double, wiggle: Double, breath: Double, time: Double) -> some View {
        // Standing still: the arms hang loose and sway a little with each breath.
        let idle = walking || taunting || crouching ? 0 : breath
        // Taunting: arms waving over the head and a wobble.
        // Crouching: hands out in front, creeping forward one after the other.
        // Scared: hands up by the face.
        let scared = mood == .scared && !taunting && !crouching
        let backArm = taunting ? 160 + wiggle * 20 : crouching ? -48 + swing * 16 : scared ? -140 + idle * 6 : -swing * 30 + 4 + idle * 4
        let frontArm = taunting ? -160 - wiggle * 20 : crouching ? -72 - swing * 16 : scared ? -150 - idle * 6 : swing * 30 - 4 - idle * 4
        // Crouching is its own pose: knees bent, the upper body lowered and leaning forward,
        // rising and sinking a little with each breath and each careful step.
        // The slippers stay on the floor line (y 150, same as standing), so the feet never sink
        // into the floor, and the body sits just on top of the bent knees.
        let drop: CGFloat = crouching ? 24 + breath * 1.2 - abs(swing) * 2 : 0
        return ZStack {
            if crouching {
                bentLeg(shuffle: -swing * 6).position(x: 42, y: 131 - max(0, swing) * 3)
                    .transition(.identity)
                bentLeg(shuffle: swing * 6).position(x: 56, y: 131 - max(0, -swing) * 3)
                    .transition(.identity)
            } else {
                leg(swing * 28).position(x: 42, y: 126)
                    .transition(.identity)
                leg(-swing * 28).position(x: 58, y: 126)
                    .transition(.identity)
            }
            // Every few seconds a standing character glances one way, then the other.
            let eyesTurn = crouching ? breath * 2.2 : walking ? 0 : glanceAt(time)
            upperBody(backArm: backArm, frontArm: frontArm, swing: swing, glance: eyesTurn, time: time)
                .rotationEffect(.degrees(crouching ? 9 + swing * 2 : idle * 1.2), anchor: .bottom)
                .offset(y: drop + CGFloat(idle) * 1.2 + (walking && !crouching ? -abs(CGFloat(swing)) * 2.5 : 0))
        }
        .rotationEffect(.degrees(wiggle * 8), anchor: .bottom)
    }

    /// A slow look around: mostly straight ahead, sometimes a glance to one side.
    private func glanceAt(_ t: Double) -> Double {
        let cycle = (t + Double(look.skin) * 1.7).truncatingRemainder(dividingBy: 7)
        if cycle < 1.2 { return sin(cycle / 1.2 * .pi) * 3 }
        if cycle > 3.6 && cycle < 4.6 { return -sin((cycle - 3.6) * .pi) * 2.5 }
        return 0
    }

    private func upperBody(backArm: Double, frontArm: Double, swing: Double, glance: Double = 0, time: Double = 0) -> some View {
        ZStack {
            if let cape = look.accessory, cape.family == .cape {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cape.color)
                    .frame(width: 34, height: 66)
                    .rotationEffect(.degrees(8 + swing * 6), anchor: .top)
                    .position(x: 34, y: 96)
            }
            if look.shirtStyle == 1 {
                // The hood, behind the head
                Ellipse().fill(shirt).brightness(-0.1).frame(width: 50, height: 30).position(x: 34, y: 62)
            }
            hairBehind
            arm(backArm).position(x: 50, y: 82)
            torso
            arm(frontArm).position(x: 50, y: 82)

            // Head
            Circle().fill(skin).frame(width: 54, height: 54).position(x: 50, y: 38)
            // Ears
            Ellipse().fill(skin).brightness(-0.05).frame(width: 9, height: 13).position(x: 40, y: 42)
            if let cap {
                Circle().trim(from: 0.5, to: 1).fill(cap).frame(width: 60, height: 60).position(x: 50, y: 34)
                Capsule().fill(cap).brightness(-0.12).frame(width: 30, height: 9).position(x: 76, y: 31)
                Circle().fill(.white.opacity(0.85)).frame(width: 7).position(x: 50, y: 5)
            } else {
                hairOnTop
            }
            face(glance: glance, time: time)
            accessory
        }
    }
}

extension CharacterView {
    /// The top: T-shirt, hoodie, stripes or an open jacket, with its picture (or your own photo).
    @ViewBuilder fileprivate var torso: some View {
        RoundedRectangle(cornerRadius: 14).fill(shirt).frame(width: 46, height: 52).position(x: 50, y: 86)
        switch look.shirtStyle {
        case 1:
            // Hoodie: a pocket and two strings
            RoundedRectangle(cornerRadius: 6).fill(shirt).brightness(-0.08).frame(width: 30, height: 12).position(x: 54, y: 102)
            Capsule().fill(.white.opacity(0.85)).frame(width: 2.5, height: 14).position(x: 58, y: 70)
            Capsule().fill(.white.opacity(0.85)).frame(width: 2.5, height: 12).position(x: 66, y: 70)
        case 2:
            // Stripes
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(.white.opacity(0.35)).frame(width: 44, height: 4).position(x: 50, y: 70 + CGFloat(i) * 11)
            }
        case 3:
            // An open jacket over a white top
            Rectangle().fill(Color.white.opacity(0.92)).frame(width: 12, height: 50).position(x: 60, y: 86)
            Rectangle().fill(shirt).brightness(-0.12).frame(width: 3, height: 50).position(x: 54, y: 86)
            Rectangle().fill(shirt).brightness(-0.12).frame(width: 3, height: 50).position(x: 67, y: 86)
        default: EmptyView()
        }
        if let id = look.photo, let picture = ShirtPhotos.image(id) {
            Image(uiImage: picture)
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.7), lineWidth: 1.5))
                .position(x: 60, y: 82)
        } else if let pattern, look.shirtStyle != 3 {
            Image(systemName: pattern)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(look.shirt == 5 ? Color.white : Palette.gold)
                .position(x: 63, y: 75)
        }
    }

    /// Eyes, eyebrows, mouth, cheeks and freckles, for the face being made.
    @ViewBuilder fileprivate func face(glance: Double, time: Double) -> some View {
        let mood = taunting ? Mood.happy : (expression ?? Mood(rawValue: look.face) ?? .calm)
        let blink = (time + (look.gender == .boy ? 0 : 0.9)).truncatingRemainder(dividingBy: 3.6) < 0.16
        if taunting {
            Capsule().fill(.black).frame(width: 9, height: 3).position(x: 56, y: 40)
            Capsule().fill(.black).frame(width: 9, height: 3).position(x: 71, y: 40)
            Capsule().fill(Color(red: 1, green: 0.4, blue: 0.5)).frame(width: 9, height: 12).position(x: 66, y: 54)
        } else {
            // Eyes: wider when surprised or scared, half shut when sleepy, narrow when sneaky.
            let tall: CGFloat = blink ? 1.6 : mood == .surprised || mood == .scared ? 9.5 : mood == .sleepy ? 3 : mood == .sneaky ? 4.5 : 7.5
            ForEach([56.0, 71.0], id: \.self) { x in
                ZStack {
                    Capsule().fill(eyeColor).frame(width: 6.5, height: tall)
                    if !blink && tall > 4 {
                        Circle().fill(.white).frame(width: 2.2).offset(x: 1, y: -tall / 4)
                    }
                }
                .position(x: x + glance, y: 40)
            }
            // Eyebrows
            let tilt: Double = mood == .worried || mood == .scared ? -16 : mood == .cross ? 18 : mood == .sneaky ? 8 : 0
            let lift: CGFloat = mood == .surprised ? -4 : mood == .scared ? -3 : 0
            Capsule().fill(hair).brightness(-0.1).frame(width: 9, height: 2.5).rotationEffect(.degrees(tilt)).position(x: 56 + glance * 0.5, y: 32 + lift)
            Capsule().fill(hair).brightness(-0.1).frame(width: 9, height: 2.5).rotationEffect(.degrees(-tilt)).position(x: 71 + glance * 0.5, y: 32 + lift)
            mouth(mood)
        }
        if look.blush {
            Circle().fill(Color.pink.opacity(mood == .happy ? 0.5 : 0.32)).frame(width: 9).position(x: 76, y: 50)
        }
        if look.freckles {
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color(red: 0.55, green: 0.32, blue: 0.20).opacity(0.6)).frame(width: 2.2)
                    .position(x: 70 + CGFloat(i % 2) * 5 + CGFloat(i / 2) * 2, y: 46 + CGFloat(i / 2) * 3)
            }
        }
    }

    @ViewBuilder private func mouth(_ mood: Mood) -> some View {
        switch mood {
        case .happy:
            Circle().trim(from: 0.05, to: 0.45).stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 16).position(x: 64, y: 46)
        case .worried:
            Circle().trim(from: 0.6, to: 0.9).stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 14).position(x: 64, y: 56)
        case .scared, .surprised:
            Ellipse().fill(Color(red: 0.35, green: 0.10, blue: 0.12)).frame(width: 8, height: mood == .scared ? 9 : 7).position(x: 64, y: 52)
        case .sneaky:
            Capsule().fill(.black.opacity(0.7)).frame(width: 10, height: 2.5).rotationEffect(.degrees(-10)).position(x: 66, y: 51)
        case .sleepy:
            Ellipse().fill(Color(red: 0.35, green: 0.10, blue: 0.12).opacity(0.8)).frame(width: 5, height: 5).position(x: 64, y: 52)
        case .cross:
            Circle().trim(from: 0.62, to: 0.88).stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 12).position(x: 64, y: 57)
        case .calm:
            Circle().trim(from: 0.1, to: 0.4).stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 14).position(x: 64, y: 47)
        }
    }

    private var style: Int { look.hair == LookOptions.ownHaircut ? -1 : abs(look.hair) % LookOptions.hairStyles.count }
    /// One of the six numbers of the haircut you made yourself.
    private func own(_ part: Int) -> CGFloat { part < look.ownHair.count ? CGFloat(min(max(look.ownHair[part], 0), 1)) : 0 }

    /// The usual hair on top of the head: a cap of hair and a fringe.
    private var topHair: some View {
        ZStack {
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            Capsule().fill(hair).frame(width: 30, height: 12).rotationEffect(.degrees(-12)).position(x: 60, y: 18)
        }
        .frame(width: 100, height: 160)
    }

    /// Hair that hangs behind the head (drawn before the head, so it shows even under a cap).
    @ViewBuilder fileprivate var hairBehind: some View {
        switch style {
        case -1:
            // Your own haircut: the back and the sides.
            if own(3) > 0.05 {
                RoundedRectangle(cornerRadius: 22).fill(hair).frame(width: 62, height: 34 + own(3) * 80).position(x: 48, y: 36 + (34 + own(3) * 80) / 2 - 10)
            }
            if own(2) > 0.05 {
                Capsule().fill(hair).frame(width: 16, height: 14 + own(2) * 56).position(x: 26, y: 36 + (14 + own(2) * 56) / 2)
            }
        case 0:
            if look.gender == .girl {
                RoundedRectangle(cornerRadius: 22).fill(hair).frame(width: 62, height: 66).position(x: 50, y: 50)
            }
        case 3: RoundedRectangle(cornerRadius: 24).fill(hair).frame(width: 64, height: 92).position(x: 48, y: 62)
        case 4:
            Capsule().fill(hair).frame(width: 18, height: 50).rotationEffect(.degrees(28)).position(x: 16, y: 50)
            Circle().fill(Color.pink).frame(width: 10).position(x: 24, y: 30)
        case 6: RoundedRectangle(cornerRadius: 16).fill(hair).frame(width: 66, height: 54).position(x: 50, y: 44)
        case 8:
            // Pigtails
            Capsule().fill(hair).frame(width: 16, height: 46).rotationEffect(.degrees(24)).position(x: 14, y: 54)
            Capsule().fill(hair).frame(width: 16, height: 46).rotationEffect(.degrees(10)).position(x: 30, y: 62)
            Circle().fill(Color.pink).frame(width: 9).position(x: 21, y: 36)
        case 9: Circle().fill(hair).frame(width: 88).position(x: 48, y: 28)
        case 12:
            // A long braid down the back
            ForEach(0..<6, id: \.self) { i in
                Circle().fill(hair).brightness(i % 2 == 0 ? 0 : -0.06).frame(width: 16 - CGFloat(i))
                    .position(x: 22 - CGFloat(i) * 1.5, y: 44 + CGFloat(i) * 12)
            }
        case 18:
            RoundedRectangle(cornerRadius: 26).fill(hair).frame(width: 68, height: 96).position(x: 47, y: 64)
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(hair).frame(width: 22).position(x: 20 + CGFloat(i) * 18, y: 110)
            }
        default: EmptyView()
        }
    }

    /// Hair on top of the head (hidden by a cap).
    @ViewBuilder fileprivate var hairOnTop: some View {
        switch style {
        case -1:
            // Your own haircut: the top, the fringe, then spikes and curls.
            let tall = 44 + own(0) * 44
            Ellipse().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: tall).position(x: 50, y: 35)
            if own(1) > 0.05 {
                Capsule().fill(hair).frame(width: 32, height: 8 + own(1) * 20).rotationEffect(.degrees(-12)).position(x: 60, y: 16 + own(1) * 8)
            }
            let spikes = Int((own(4) * 7).rounded())
            ForEach(0..<spikes, id: \.self) { i in
                Triangle().fill(hair).frame(width: 14, height: 14 + own(4) * 14)
                    .rotationEffect(.degrees((Double(i) - Double(spikes - 1) / 2) * 16))
                    .position(x: 50 + (CGFloat(i) - CGFloat(spikes - 1) / 2) * 10, y: 36 - tall / 2 - 4 + abs(CGFloat(i) - CGFloat(spikes - 1) / 2) * 3)
            }
            let curls = Int((own(5) * 8).rounded())
            ForEach(0..<curls, id: \.self) { i in
                Circle().fill(hair).brightness(i % 2 == 0 ? 0.04 : -0.04).frame(width: 18)
                    .position(x: 50 + (CGFloat(i) - CGFloat(curls - 1) / 2) * 8.5, y: 36 - tall / 2 + 4 + abs(CGFloat(i) - CGFloat(curls - 1) / 2) * 3.5)
            }
        case 1:
            // Spiky
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 36)
            ForEach(0..<5, id: \.self) { i in
                Triangle().fill(hair).frame(width: 16, height: 22)
                    .rotationEffect(.degrees(Double(i - 2) * 22))
                    .position(x: 26 + CGFloat(i) * 12, y: 6 + abs(CGFloat(i) - 2) * 4)
            }
        case 2:
            // Curly
            ForEach(0..<7, id: \.self) { i in
                Circle().fill(hair).frame(width: 22)
                    .position(x: 24 + CGFloat(i) * 9, y: 20 - sin(CGFloat(i) / 6 * .pi) * 14)
            }
            Circle().fill(hair).frame(width: 20).position(x: 24, y: 30)
        case 3:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 60, height: 60).position(x: 50, y: 35)
            Capsule().fill(hair).frame(width: 34, height: 13).rotationEffect(.degrees(-16)).position(x: 62, y: 18)
        case 4:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            Capsule().fill(hair).frame(width: 26, height: 11).rotationEffect(.degrees(-10)).position(x: 62, y: 17)
        case 5:
            // Buzz cut: short and close to the head
            Circle().trim(from: 0.56, to: 0.97).fill(hair).brightness(-0.05).frame(width: 55, height: 55).position(x: 50, y: 38)
        case 6:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 60, height: 60).position(x: 50, y: 35)
            RoundedRectangle(cornerRadius: 5).fill(hair).frame(width: 34, height: 12).position(x: 60, y: 22)
        case 7:
            // Mohawk
            Circle().trim(from: 0.56, to: 0.97).fill(hair).brightness(-0.08).frame(width: 55, height: 55).position(x: 50, y: 38)
            Capsule().fill(hair).frame(width: 44, height: 18).position(x: 50, y: 7)
            Capsule().fill(hair).brightness(0.08).frame(width: 30, height: 12).position(x: 54, y: 2)
        case 8: topHair
        case 9:
            // Afro: the big round shape is behind; this is the front of it.
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 66, height: 70).position(x: 50, y: 34)
        case 10:
            topHair
            Circle().fill(hair).frame(width: 26).position(x: 46, y: 0)
        case 11:
            topHair
            Circle().fill(hair).frame(width: 22).position(x: 30, y: 6)
            Circle().fill(hair).frame(width: 22).position(x: 66, y: 4)
        case 12: topHair
        case 13:
            // Bowl cut
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 62, height: 66).position(x: 50, y: 37)
            RoundedRectangle(cornerRadius: 4).fill(hair).frame(width: 58, height: 11).position(x: 51, y: 32)
        case 14:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            Capsule().fill(hair).frame(width: 44, height: 15).rotationEffect(.degrees(-24)).position(x: 62, y: 20)
        case 15:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            Ellipse().fill(hair).frame(width: 36, height: 26).rotationEffect(.degrees(-18)).position(x: 64, y: 9)
        case 16:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            RoundedRectangle(cornerRadius: 3).fill(hair).frame(width: 52, height: 18).position(x: 50, y: 6)
        case 17: EmptyView()
        case 18: topHair
        case 19:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(hair).frame(width: 8, height: 10 + CGFloat(i % 2) * 4).position(x: 50 + CGFloat(i) * 8, y: 30)
            }
        default:
            topHair
            if look.gender == .girl && style == 0 {
                HStack(spacing: 2) {
                    Circle().fill(Color.pink).frame(width: 13)
                    Circle().fill(Color.pink).frame(width: 13)
                }
                .position(x: 34, y: 14)
            }
        }
    }

    /// The one accessory being worn, drawn over the figure (capes are drawn behind, above),
    /// followed by any boosting accessories, which all show at once.
    @ViewBuilder fileprivate var accessory: some View {
        if let item = look.accessory {
            wear(item.family, item.color)
        }
        boostGear
    }

    @ViewBuilder private func wear(_ family: Accessory.Family, _ color: Color) -> some View {
        switch family {
        case .glasses:
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 13, height: 10).position(x: 56, y: 40)
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 13, height: 10).position(x: 71, y: 40)
            Rectangle().fill(color).frame(width: 30, height: 3).position(x: 58, y: 37)
        case .crown:
            Image(systemName: "crown.fill").font(.system(size: 26)).foregroundStyle(color).position(x: 50, y: 4)
        case .bowTie:
            HStack(spacing: 0) {
                Triangle().fill(color).frame(width: 10, height: 12).rotationEffect(.degrees(90))
                Triangle().fill(color).frame(width: 10, height: 12).rotationEffect(.degrees(-90))
            }
            .position(x: 60, y: 66)
        case .scarf:
            Capsule().fill(color).frame(width: 46, height: 11).position(x: 50, y: 64)
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 24).position(x: 38, y: 76)
        case .headband:
            Capsule().fill(color).frame(width: 56, height: 8).position(x: 50, y: 27)
            Capsule().fill(color).frame(width: 20, height: 6).rotationEffect(.degrees(25)).position(x: 16, y: 32)
        case .catEars:
            Triangle().fill(color).frame(width: 18, height: 18).position(x: 34, y: 8)
            Triangle().fill(color).frame(width: 18, height: 18).position(x: 64, y: 6)
            Triangle().fill(Color.pink).frame(width: 8, height: 9).position(x: 34, y: 11)
            Triangle().fill(Color.pink).frame(width: 8, height: 9).position(x: 64, y: 9)
        case .headphones:
            Circle().trim(from: 0.55, to: 0.95).stroke(Color(white: 0.2), lineWidth: 6).frame(width: 62).position(x: 50, y: 36)
            RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 16, height: 22).position(x: 44, y: 40)
        case .halo:
            Ellipse().stroke(color, lineWidth: 4).frame(width: 44, height: 11).shadow(color: color, radius: 6).position(x: 50, y: -4)
        case .partyHat:
            Triangle().fill(color).frame(width: 30, height: 36).position(x: 50, y: -4)
            Circle().fill(Color.yellow).frame(width: 9).position(x: 50, y: -22)
        case .beanie:
            Circle().trim(from: 0.5, to: 1).fill(color).frame(width: 60, height: 62).position(x: 50, y: 32)
            Capsule().fill(color).brightness(-0.15).frame(width: 62, height: 10).position(x: 50, y: 30)
            Circle().fill(.white).frame(width: 12).position(x: 50, y: 0)
        case .topHat:
            Rectangle().fill(color).frame(width: 40, height: 30).position(x: 50, y: -2)
            Capsule().fill(color).frame(width: 66, height: 8).position(x: 50, y: 14)
            Rectangle().fill(.white.opacity(0.7)).frame(width: 40, height: 5).position(x: 50, y: 8)
        case .hairBow:
            HStack(spacing: 0) {
                Triangle().fill(color).frame(width: 14, height: 16).rotationEffect(.degrees(90))
                Triangle().fill(color).frame(width: 14, height: 16).rotationEffect(.degrees(-90))
            }
            .position(x: 40, y: 10)
            Circle().fill(color).brightness(-0.15).frame(width: 8).position(x: 40, y: 10)
        case .flower:
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(color).frame(width: 9)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(i) * 72))
                    .position(x: 36, y: 14)
            }
            Circle().fill(Color.yellow).frame(width: 7).position(x: 36, y: 14)
        case .cape:
            EmptyView()
        }
    }

    @ViewBuilder private var boostGear: some View {
        if look.shownBoosts.contains(.coolCap) {
            Circle().trim(from: 0.5, to: 1).fill(Color.red).frame(width: 60, height: 60).position(x: 50, y: 34)
            Capsule().fill(Color(red: 0.7, green: 0, blue: 0)).frame(width: 30, height: 9).position(x: 76, y: 31)
            // The can on top
            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.8)).frame(width: 14, height: 20).position(x: 50, y: -4)
            Rectangle().fill(Color.green).frame(width: 14, height: 8).position(x: 50, y: -4)
        }
        if look.shownBoosts.contains(.windCrown) {
            Image(systemName: "crown.fill").font(.system(size: 22)).foregroundStyle(.cyan)
                .position(x: 50, y: look.shownBoosts.contains(.coolCap) ? -24 : 4)
        }
        if look.shownBoosts.contains(.goldenCrown) {
            Image(systemName: "crown.fill").font(.system(size: 26)).foregroundStyle(Palette.gold)
                .shadow(color: .yellow, radius: 6)
                .position(x: 50, y: (look.shownBoosts.contains(.coolCap) ? -24 : 4) - (look.shownBoosts.contains(.windCrown) ? 18 : 0))
        }
        if look.shownBoosts.contains(.arrow) {
            // An arrow slung across the back
            Capsule().fill(Color(red: 0.6, green: 0.4, blue: 0.2)).frame(width: 5, height: 70).rotationEffect(.degrees(35)).position(x: 30, y: 82)
            Triangle().fill(Color.orange).frame(width: 14, height: 14).rotationEffect(.degrees(35)).position(x: 50, y: 52)
        }
        if look.shownBoosts.contains(.leaf) {
            Image(systemName: "leaf.fill").font(.system(size: 20)).foregroundStyle(.green).rotationEffect(.degrees(-30)).position(x: 26, y: 70)
        }
        if look.shownBoosts.contains(.cloud) {
            // A little cloud that follows you around
            ZStack {
                Ellipse().fill(.white).frame(width: 30, height: 11)
                Circle().fill(.white).frame(width: 14).offset(x: -6, y: -5)
                Circle().fill(.white).frame(width: 17).offset(x: 4, y: -7)
            }
            .shadow(color: Color(red: 0.6, green: 0.8, blue: 1), radius: 4)
            .position(x: 92, y: 14)
        }
        if look.shownBoosts.contains(.guidesHat) {
            // The Guide's own purple top hat, with a little lantern-light glow.
            Rectangle().fill(GuidesHat.color).frame(width: 40, height: 30).position(x: 50, y: -2)
            Capsule().fill(GuidesHat.color).brightness(-0.1).frame(width: 66, height: 8).position(x: 50, y: 14)
            Rectangle().fill(Palette.gold).frame(width: 40, height: 5).position(x: 50, y: 8)
            Image(systemName: "sparkle").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow)
                .shadow(color: .yellow, radius: 5)
                .position(x: 60, y: -6)
        }
        if look.shownBoosts.contains(.waterHose) {
            // Auntie's green hose, coiled over one shoulder, with its brass nozzle
            Circle().stroke(Color(red: 0.20, green: 0.62, blue: 0.30), lineWidth: 4).frame(width: 26).position(x: 38, y: 78)
            Circle().stroke(Color(red: 0.20, green: 0.62, blue: 0.30), lineWidth: 4).frame(width: 18).position(x: 38, y: 78)
            Capsule().fill(Palette.gold).frame(width: 6, height: 12).rotationEffect(.degrees(30)).position(x: 48, y: 92)
        }
        if look.shownBoosts.contains(.lightningBall) {
            Image(systemName: "bolt.circle.fill").font(.system(size: 22)).foregroundStyle(.yellow)
                .shadow(color: .yellow, radius: 8)
                .position(x: 14, y: 40)
        }
    }
}

#Preview {
    HStack {
        CharacterView(look: Look(gender: .boy, skin: 3, shirt: 2, pattern: 2, cap: 1, accessory: Accessory.find("scarf-blue"), boosts: [.leaf, .goldenCrown]))
        CharacterView(look: .starter(.girl), facingRight: false, taunting: true)
    }
    .padding()
    .background(.indigo)
}
