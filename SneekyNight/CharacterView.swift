import SwiftUI

/// The player, drawn from simple shapes. Its frame is 100×160 with the feet at the bottom.
struct CharacterView: View {
    var look: Look
    var facingRight = true
    var walking = false
    var crouching = false
    var taunting = false

    init(look: Look, facingRight: Bool = true, walking: Bool = false, crouching: Bool = false, taunting: Bool = false) {
        self.look = look
        self.facingRight = facingRight
        self.walking = walking
        self.crouching = crouching
        self.taunting = taunting
    }

    init(gender: Gender, facingRight: Bool = true) {
        self.init(look: .starter(gender), facingRight: facingRight)
    }

    var body: some View {
        TimelineView(.animation(paused: !walking && !taunting && !crouching)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // Creeping is slower than walking, and a crouched character keeps breathing and looking around.
            figure(swing: walking ? sin(t * (crouching ? 8 : 13)) : 0, wiggle: taunting ? sin(t * 22) : 0,
                   breath: crouching ? sin(t * 2.4) : 0)
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
        look.gender == .boy ? Color(red: 0.33, green: 0.21, blue: 0.12) : Color(red: 0.55, green: 0.30, blue: 0.14)
    }

    private func leg(_ angle: Double) -> some View {
        VStack(spacing: -4) {
            Capsule().fill(shirt).brightness(-0.22).frame(width: 17, height: 40)
            Capsule().fill(Color(red: 0.95, green: 0.95, blue: 0.98)).frame(width: 24, height: 11).offset(x: 4)
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
            Capsule().fill(shirt).brightness(-0.22).frame(width: 34, height: 17).position(x: 20, y: 9)
            Capsule().fill(shirt).brightness(-0.28).frame(width: 16, height: 24).position(x: 30 + shuffle, y: 22)
            Capsule().fill(Color(red: 0.95, green: 0.95, blue: 0.98)).frame(width: 24, height: 11).position(x: 34 + shuffle, y: 34)
        }
        .frame(width: 50, height: 40)
    }

    private func figure(swing: Double, wiggle: Double, breath: Double) -> some View {
        // Taunting: arms waving over the head and a wobble.
        // Crouching: hands out in front, creeping forward one after the other.
        let backArm = taunting ? 160 + wiggle * 20 : crouching ? -48 + swing * 16 : -swing * 30
        let frontArm = taunting ? -160 - wiggle * 20 : crouching ? -72 - swing * 16 : swing * 30
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
            upperBody(backArm: backArm, frontArm: frontArm, swing: swing, glance: crouching ? breath * 2.2 : 0)
                .rotationEffect(.degrees(crouching ? 9 + swing * 2 : 0), anchor: .bottom)
                .offset(y: drop)
        }
        .rotationEffect(.degrees(wiggle * 8), anchor: .bottom)
    }

    private func upperBody(backArm: Double, frontArm: Double, swing: Double, glance: Double = 0) -> some View {
        ZStack {
            if let cape = look.accessory, cape.family == .cape {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cape.color)
                    .frame(width: 34, height: 66)
                    .rotationEffect(.degrees(8 + swing * 6), anchor: .top)
                    .position(x: 34, y: 96)
            }
            hairBehind
            arm(backArm).position(x: 50, y: 82)
            RoundedRectangle(cornerRadius: 14)
                .fill(shirt)
                .frame(width: 46, height: 52)
                .position(x: 50, y: 86)
            if let pattern {
                Image(systemName: pattern)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(look.shirt == 5 ? Color.white : Palette.gold)
                    .position(x: 63, y: 75)
            }
            arm(frontArm).position(x: 50, y: 82)

            // Head
            Circle().fill(skin).frame(width: 54, height: 54).position(x: 50, y: 38)
            if let cap {
                Circle().trim(from: 0.5, to: 1).fill(cap).frame(width: 60, height: 60).position(x: 50, y: 34)
                Capsule().fill(cap).brightness(-0.12).frame(width: 30, height: 9).position(x: 76, y: 31)
                Circle().fill(.white.opacity(0.85)).frame(width: 7).position(x: 50, y: 5)
            } else {
                hairOnTop
            }
            // Face, looking toward the facing direction.
            if taunting {
                Capsule().fill(.black).frame(width: 9, height: 3).position(x: 56, y: 40)
                Capsule().fill(.black).frame(width: 9, height: 3).position(x: 71, y: 40)
                Capsule().fill(Color(red: 1, green: 0.4, blue: 0.5)).frame(width: 9, height: 12).position(x: 66, y: 54)
            } else {
                // While sneaking, the eyes dart from side to side.
                BlinkingEye(size: 7, phase: look.gender == .boy ? 0 : 0.9).position(x: 56 + glance, y: 40)
                BlinkingEye(size: 7, phase: look.gender == .boy ? 0 : 0.9).position(x: 71 + glance, y: 40)
            }
            Circle().fill(Color.pink.opacity(0.45)).frame(width: 10).position(x: 76, y: 50)
            Circle()
                .trim(from: 0.1, to: 0.4)
                .stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 14)
                .position(x: 64, y: 47)
            accessory
        }
    }
}

extension CharacterView {
    private var style: Int { abs(look.hair) % LookOptions.hairStyles.count }

    /// Hair that hangs behind the head (drawn before the head, so it shows even under a cap).
    @ViewBuilder fileprivate var hairBehind: some View {
        switch style {
        case 0:
            if look.gender == .girl {
                RoundedRectangle(cornerRadius: 22).fill(hair).frame(width: 62, height: 66).position(x: 50, y: 50)
            }
        case 3: RoundedRectangle(cornerRadius: 24).fill(hair).frame(width: 64, height: 92).position(x: 48, y: 62)
        case 4:
            Capsule().fill(hair).frame(width: 18, height: 50).rotationEffect(.degrees(28)).position(x: 16, y: 50)
            Circle().fill(Color.pink).frame(width: 10).position(x: 24, y: 30)
        case 6: RoundedRectangle(cornerRadius: 16).fill(hair).frame(width: 66, height: 54).position(x: 50, y: 44)
        default: EmptyView()
        }
    }

    /// Hair on top of the head (hidden by a cap).
    @ViewBuilder fileprivate var hairOnTop: some View {
        switch style {
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
        default:
            Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: 58, height: 58).position(x: 50, y: 35)
            Capsule().fill(hair).frame(width: 30, height: 12).rotationEffect(.degrees(-12)).position(x: 60, y: 18)
            if look.gender == .girl {
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
