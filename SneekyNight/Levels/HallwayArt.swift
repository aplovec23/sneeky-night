import SwiftUI

// Drawings for Level 2. Each view's bottom edge is the spot where it stands on the floor.

private let wood = Color(red: 0.50, green: 0.32, blue: 0.20)
private let darkWood = Color(red: 0.36, green: 0.22, blue: 0.14)

struct HallwayWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.22, green: 0.18, blue: 0.32), Color(red: 0.32, green: 0.25, blue: 0.40)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 450)
            // Striped wallpaper
            ForEach(0..<Int(width / 50), id: \.self) { i in
                Rectangle()
                    .fill(.white.opacity(i % 2 == 0 ? 0.05 : 0.02))
                    .frame(width: 25, height: 450)
                    .offset(x: CGFloat(i) * 50)
            }
            // Picture frames
            // Solo, pet and family photos in turn
            ForEach(Array([760, 1180, 1880, 2440, 3090].enumerated()), id: \.offset) { i, x in
                PictureFrame(seed: i).offset(x: CGFloat(x) - 50, y: 215)
            }
            Rectangle().fill(darkWood).frame(width: width, height: 16).offset(y: 442)
            LinearGradient(colors: [Color(red: 0.38, green: 0.25, blue: 0.17), Color(red: 0.50, green: 0.33, blue: 0.21)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
            // Long carpet runner
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.55, green: 0.16, blue: 0.20))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.gold.opacity(0.6), lineWidth: 5).padding(10))
                .frame(width: width - 160, height: 140)
                .offset(x: 80, y: 555)
        }
    }
}

struct SiblingRoomWall: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.30, green: 0.26, blue: 0.48), Color(red: 0.42, green: 0.34, blue: 0.58)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 450)
            ForEach(0..<30, id: \.self) { i in
                Image(systemName: ["star.fill", "heart.fill", "moon.fill"][i % 3])
                    .font(.system(size: 18))
                    .foregroundStyle([Color.yellow, .pink, .cyan][i % 3].opacity(0.25))
                    .position(x: CGFloat(i % 10) * 150 + (i / 10 % 2 == 0 ? 60 : 130), y: CGFloat(i / 10) * 120 + 70)
            }
            // Rainbow painting
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .trim(from: 0.5, to: 1)
                        .stroke([Color.red, .orange, .yellow, .green][i], lineWidth: 12)
                        .frame(width: CGFloat(150 - i * 26), height: CGFloat(150 - i * 26))
                }
            }
            .frame(width: 160, height: 160)
            .offset(x: 700, y: 120)
            Rectangle().fill(darkWood).frame(width: width, height: 16).offset(y: 442)
            LinearGradient(colors: [Color(red: 0.45, green: 0.36, blue: 0.30), Color(red: 0.55, green: 0.44, blue: 0.36)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: 242)
                .offset(y: 458)
            Ellipse()
                .fill(Color(red: 0.40, green: 0.70, blue: 0.60))
                .overlay(Ellipse().stroke(.white.opacity(0.5), lineWidth: 5).padding(12))
                .frame(width: 520, height: 120)
                .offset(x: 470, y: 570)
        }
    }
}

/// A framed photo on the wall. `seed` picks which kind: a solo portrait, a pet, or the whole family.
struct PictureFrame: View {
    let seed: Int

    private let skin = Color(red: 0.96, green: 0.80, blue: 0.66)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Palette.gold.opacity(0.85)).frame(width: 100, height: 80)
            ZStack {
                switch seed % 3 {
                case 0: solo
                case 1: pet
                default: family
                }
            }
            .frame(width: 84, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private func person(head: CGFloat, shirt: Color, hair: Color, body: CGSize) -> some View {
        VStack(spacing: -2) {
            ZStack {
                Circle().fill(skin).frame(width: head)
                Circle().trim(from: 0.5, to: 1).fill(hair).frame(width: head + 2).offset(y: -1)
                HStack(spacing: head * 0.22) {
                    Circle().fill(.black).frame(width: head * 0.11)
                    Circle().fill(.black).frame(width: head * 0.11)
                }
                .offset(y: head * 0.08)
                Circle().trim(from: 0.1, to: 0.4).stroke(.black.opacity(0.7), lineWidth: 1.2).frame(width: head * 0.3).offset(y: head * 0.16)
            }
            RoundedRectangle(cornerRadius: body.width * 0.3).fill(shirt).frame(width: body.width, height: body.height)
        }
    }

    /// One smiling person, school-photo style.
    private var solo: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.35, green: 0.55, blue: 0.85)], startPoint: .top, endPoint: .bottom)
            person(head: 30, shirt: [Color.red, .green, .orange, .purple][seed / 3 % 4],
                   hair: Color(red: 0.33, green: 0.21, blue: 0.12), body: CGSize(width: 44, height: 26))
                .offset(y: 6)
        }
    }

    /// The family pet: a dog or a cat.
    private var pet: some View {
        let cat = seed / 3 % 2 == 1
        let fur = cat ? Color(red: 0.95, green: 0.60, blue: 0.25) : Color(red: 0.78, green: 0.58, blue: 0.36)
        return ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.88, blue: 0.60), Color(red: 0.90, green: 0.70, blue: 0.45)], startPoint: .top, endPoint: .bottom)
            if cat {
                Triangle().fill(fur).frame(width: 14, height: 14).offset(x: -13, y: -16)
                Triangle().fill(fur).frame(width: 14, height: 14).offset(x: 13, y: -16)
            } else {
                Ellipse().fill(Color(red: 0.50, green: 0.34, blue: 0.20)).frame(width: 12, height: 24).offset(x: -19, y: -2)
                Ellipse().fill(Color(red: 0.50, green: 0.34, blue: 0.20)).frame(width: 12, height: 24).offset(x: 19, y: -2)
            }
            Circle().fill(fur).frame(width: 38)
            Ellipse().fill(.white.opacity(0.75)).frame(width: 20, height: 14).offset(y: 8)
            Circle().fill(.black).frame(width: 5).offset(x: -8, y: -4)
            Circle().fill(.black).frame(width: 5).offset(x: 8, y: -4)
            Ellipse().fill(.black).frame(width: 8, height: 6).offset(y: 5)
            if !cat {
                Capsule().fill(Color(red: 1, green: 0.45, blue: 0.5)).frame(width: 6, height: 9).offset(y: 15)
            }
            RoundedRectangle(cornerRadius: 12).fill(fur).frame(width: 46, height: 20).offset(y: 30)
        }
    }

    /// Dad, the two kids and Mom.
    private var family: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.60, green: 0.85, blue: 0.70), Color(red: 0.35, green: 0.65, blue: 0.50)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 1) {
                person(head: 17, shirt: Color(red: 0.35, green: 0.45, blue: 0.70), hair: Color(red: 0.25, green: 0.18, blue: 0.12), body: CGSize(width: 20, height: 26))
                person(head: 13, shirt: Color(red: 0.26, green: 0.52, blue: 0.92), hair: Color(red: 0.33, green: 0.21, blue: 0.12), body: CGSize(width: 15, height: 15))
                person(head: 12, shirt: Color(red: 0.25, green: 0.70, blue: 0.40), hair: Color(red: 0.40, green: 0.25, blue: 0.12), body: CGSize(width: 14, height: 12))
                person(head: 16, shirt: Color(red: 0.85, green: 0.45, blue: 0.60), hair: Color(red: 0.45, green: 0.28, blue: 0.15), body: CGSize(width: 19, height: 24))
            }
            .offset(y: 3)
        }
    }
}

struct DoorSign: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.game(14, .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 6))
            .rotationEffect(.degrees(-4))
    }
}

struct DoorView<Sign: View>: View {
    let color: Color
    var open = false
    @ViewBuilder let sign: () -> Sign

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color(red: 0.95, green: 0.80, blue: 0.50)).frame(width: 104, height: 300)
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(color)
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.2), lineWidth: 4).frame(width: 66, height: 110)
                    RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.2), lineWidth: 4).frame(width: 66, height: 120)
                }
                Circle().fill(Palette.gold).frame(width: 14).offset(x: 34, y: 12)
            }
            .frame(width: 104, height: 300)
            .scaleEffect(x: open ? 0.2 : 1, anchor: .leading)
            .animation(.easeInOut(duration: 0.5), value: open)
            sign().padding(.top, 40)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkWood, lineWidth: 10))
    }
}

struct ExitDoorView: View {
    let open: Bool
    let codeAccepted: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.25, blue: 0.5), Color(red: 0.1, green: 0.1, blue: 0.25)],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: "moon.stars.fill").font(.system(size: 40)).foregroundStyle(Palette.moon)
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.25, green: 0.40, blue: 0.30))
                    VStack(spacing: 26) {
                        padlock
                        padlock
                    }
                    .offset(x: 30)
                    Circle().fill(Palette.gold).frame(width: 18).offset(x: 40, y: 70)
                }
                .scaleEffect(x: open ? 0.15 : 1, anchor: .leading)
                .animation(.easeInOut(duration: 0.8), value: open)
            }
            .frame(width: 124, height: 320)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkWood, lineWidth: 10))
            // Code keypad on the wall
            VStack(spacing: 5) {
                Circle().fill(codeAccepted ? Color.green : Color.red).frame(width: 12)
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.7)).frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(red: 0.2, green: 0.2, blue: 0.24), in: RoundedRectangle(cornerRadius: 8))
            .offset(y: -20)
        }
        .padding(.leading, 70)
    }

    private var padlock: some View {
        Image(systemName: open ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 26))
            .foregroundStyle(Palette.gold)
    }
}

struct ClosetView: View {
    let hiding: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(wood).frame(width: 140, height: 300)
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 7) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle().fill(.black.opacity(0.22)).frame(width: 46, height: 4)
                        }
                    }
                    .frame(width: 60, height: 280)
                    .background(Color(red: 0.58, green: 0.38, blue: 0.24), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            if hiding {
                // Peeking out through the slats
                Rectangle().fill(.black).frame(width: 6, height: 260)
                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 10)
                    Circle().fill(.white).frame(width: 10)
                }
                .offset(y: -40)
            }
            Circle().fill(Palette.gold).frame(width: 10).offset(x: -10, y: 10)
            Circle().fill(Palette.gold).frame(width: 10).offset(x: 10, y: 10)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkWood, lineWidth: 6))
    }
}

struct DresserView: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6).fill(wood).frame(width: 150, height: 140).padding(.top, 16)
            // A small framed pet photo standing on top
            PictureFrame(seed: 1)
                .scaleEffect(0.38)
                .frame(width: 38, height: 30)
                .offset(y: -14)
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.60, green: 0.40, blue: 0.26))
                        Capsule().fill(Palette.gold).frame(width: 26, height: 6)
                    }
                    .frame(width: i == 0 && open ? 150 : 130, height: 32)
                    .offset(y: i == 0 && open ? 10 : 0)
                    .shadow(radius: i == 0 && open ? 4 : 0)
                }
            }
            .padding(.top, 30)
        }
        .frame(width: 160, height: 160)
        .animation(.spring(duration: 0.3), value: open)
    }
}

struct NightstandView: View {
    let open: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.yellow.opacity(0.9))
                .frame(width: 22)
                .shadow(color: .yellow, radius: 14)
            Rectangle().fill(.gray).frame(width: 6, height: 14)
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.95, green: 0.75, blue: 0.85)).frame(width: 84, height: 80)
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 1, green: 0.85, blue: 0.92))
                    Capsule().fill(.purple).frame(width: 20, height: 6)
                }
                .frame(width: open ? 84 : 70, height: 28)
                .offset(y: open ? -10 : -16)
                .shadow(radius: open ? 3 : 0)
            }
        }
        .animation(.spring(duration: 0.3), value: open)
    }
}

struct HallWindowView: View {
    let open: Bool
    let keyTaken: Bool

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(darkWood).frame(width: 190, height: 180)
                LinearGradient(colors: [Palette.skyTop, Color(red: 0.15, green: 0.18, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                    .frame(width: 164, height: 150)
                Circle().fill(Palette.moon).frame(width: 40).shadow(color: Palette.moon, radius: 12).offset(x: -40, y: -35)
                if open && !keyTaken {
                    Image(systemName: "key.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Palette.silver)
                        .shadow(color: .white, radius: 8)
                        .rotationEffect(.degrees(-30))
                        .offset(x: 30, y: 52)
                        .symbolEffect(.pulse)
                }
                // Two glass panes that swing open
                HStack(spacing: 0) {
                    pane.scaleEffect(x: open ? 0.15 : 1, anchor: .leading)
                    pane.scaleEffect(x: open ? 0.15 : 1, anchor: .trailing)
                }
                .frame(width: 164, height: 150)
                .animation(.easeInOut(duration: 0.6), value: open)
                Rectangle().fill(darkWood).frame(width: 200, height: 12).offset(y: 86)
            }
            Spacer()
        }
        .frame(width: 210, height: 420)
    }

    private var pane: some View {
        ZStack {
            Rectangle().fill(Color.cyan.opacity(0.18))
            Rectangle().stroke(darkWood, lineWidth: 5)
        }
    }
}

struct SiblingBedView: View {
    /// True once he's awake and out of bed.
    var empty = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.95, green: 0.65, blue: 0.40)).frame(width: 30, height: 170)
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.95, green: 0.65, blue: 0.40)).frame(width: 300, height: 34).offset(x: 10, y: -20)
            RoundedRectangle(cornerRadius: 10).fill(.white).frame(width: 270, height: 30).offset(x: 26, y: -50)
            Capsule().fill(Color(red: 0.9, green: 0.9, blue: 1)).frame(width: 74, height: 30).offset(x: 34, y: -76)
            if !empty {
                Circle().fill(Color(red: 0.96, green: 0.78, blue: 0.62)).frame(width: 46).offset(x: 48, y: -84)
                Circle().trim(from: 0.5, to: 1).fill(Color(red: 0.4, green: 0.25, blue: 0.12)).frame(width: 50).offset(x: 46, y: -88)
                Capsule().fill(.black.opacity(0.6)).frame(width: 10, height: 3).offset(x: 72, y: -108)
            }
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color.pink.opacity(0.9), Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .frame(width: 210, height: 62)
                .offset(x: 92, y: -44)
            if !empty {
                Text("z Z z").font(.game(22, .heavy)).foregroundStyle(.white.opacity(0.7)).offset(x: 60, y: -140)
            }
        }
        .frame(width: 320, height: 180, alignment: .bottomLeading)
    }
}

struct MomView: View {
    /// Hit by a toy, the bat or vines: dizzy, with stars circling.
    var stunned = false
    var walking = false
    /// Her face, like the player's: cross when she's after you, surprised when stunned, and so on.
    var expression: Mood = .cross

    /// Mom's pink dressing gown. Auntie wears the same cut in teal.
    var robe = Color(red: 0.85, green: 0.45, blue: 0.60)
    private let skin = Color(red: 0.96, green: 0.80, blue: 0.66)

    var body: some View {
        // Never quite still: standing, she breathes and her arms sway a little.
        TimelineView(.animation(minimumInterval: walking ? nil : 1 / 24)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            figure(swing: walking ? sin(t * 9) : sin(t * 1.7) * 0.12)
                .offset(y: walking ? 0 : sin(t * 1.7 + 0.8) * 1.2)
        }
        .frame(width: 140, height: 260)
        .rotationEffect(.degrees(stunned ? 6 : 0), anchor: .bottom)
    }

    private func arm(_ angle: Double) -> some View {
        VStack(spacing: -4) {
            Capsule().fill(robe).brightness(-0.06).frame(width: 18, height: 62)
            Circle().fill(skin).frame(width: 18, height: 18)
        }
        .rotationEffect(.degrees(angle), anchor: .top)
    }

    private func figure(swing: Double) -> some View {
        ZStack {
            arm(18 + swing * 22).offset(x: -46, y: 22)
            arm(-18 - swing * 22).offset(x: 46, y: 22)
            // Robe
            RoundedRectangle(cornerRadius: 24).fill(robe).frame(width: 84, height: 150).offset(y: 40)
            Rectangle().fill(Color(red: 0.70, green: 0.30, blue: 0.45)).frame(width: 84, height: 10).offset(y: 40)
            HStack(spacing: 14) {
                Capsule().fill(.white).frame(width: 30, height: 14).offset(y: swing * 4)
                Capsule().fill(.white).frame(width: 30, height: 14).offset(y: -swing * 4)
            }
            .offset(y: 118)
            // Head with curlers
            Circle().fill(skin).frame(width: 62).offset(y: -62)
            Circle().trim(from: 0.5, to: 1).fill(Color(red: 0.45, green: 0.28, blue: 0.15)).frame(width: 68).offset(y: -66)
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(Color.cyan).frame(width: 12, height: 18)
                }
            }
            .offset(y: -100)
            GrownUpFace(mood: stunned ? .surprised : expression, gap: 22, phase: 1.3).offset(y: -62)
            if stunned {
                StunStars().offset(y: -112)
            } else if expression == .cross || expression == .surprised {
                Text("?!").font(.game(34, .heavy)).foregroundStyle(.yellow).offset(x: 50, y: -110)
            }
        }
    }
}

/// An eye that blinks every few seconds. `phase` staggers different characters.
struct BlinkingEye: View {
    var size: CGFloat = 7
    var phase = 0.0

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 0.14)) { ctx in
            let closed = (ctx.date.timeIntervalSinceReferenceDate + phase).truncatingRemainder(dividingBy: 3.6) < 0.16
            Capsule().fill(.black).frame(width: size, height: closed ? max(1.5, size * 0.22) : size)
        }
        .frame(width: size, height: size)
    }
}

/// A grown-up's face: the same eight moods as the player's (eyes, eyebrows and mouth),
/// drawn a size bigger. The middle of the eyes is the middle of the view.
struct GrownUpFace: View {
    var mood: Mood = .calm
    /// From one eye to the other.
    var gap: CGFloat = 22
    var size: CGFloat = 7
    /// Staggers the blinking between characters.
    var phase = 0.0
    var brows: Color = .black
    /// Some faces (Dad's moustache) draw their own mouth area.
    var showMouth = true
    /// Moves the mouth down (below a moustache) and the eyebrows up (above glasses).
    var mouthDrop: CGFloat = 0
    var browRise: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 0.14)) { ctx in
            let blink = (ctx.date.timeIntervalSinceReferenceDate + phase).truncatingRemainder(dividingBy: 3.6) < 0.16
            face(blink: blink)
        }
        .frame(width: gap + 40, height: 50)
    }

    private func face(blink: Bool) -> some View {
        // Eyes: wider when surprised or scared, half shut when sleepy, narrow when sneaky.
        let tall: CGFloat = blink ? max(1.5, size * 0.22) : mood == .surprised || mood == .scared ? size * 1.35 : mood == .sleepy ? size * 0.35 : mood == .sneaky ? size * 0.55 : size
        let tilt: Double = mood == .worried || mood == .scared ? -16 : mood == .cross ? 18 : mood == .sneaky ? 8 : 0
        let lift: CGFloat = mood == .surprised ? -5 : mood == .scared ? -3 : 0
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(.black).frame(width: size, height: tall).offset(x: side * gap / 2)
                Capsule().fill(brows).frame(width: size * 2, height: 3)
                    .rotationEffect(.degrees(side * tilt * -1))
                    .offset(x: side * gap / 2, y: -size - 4 + lift - browRise)
            }
            if showMouth { mouth.offset(y: size + 9 + mouthDrop) }
        }
    }

    @ViewBuilder private var mouth: some View {
        let w = gap * 0.8
        switch mood {
        case .happy:
            Circle().trim(from: 0.05, to: 0.45).stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: w).offset(y: -w / 2 + 2)
        case .worried:
            Circle().trim(from: 0.6, to: 0.9).stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: w).offset(y: w / 2 + 2)
        case .scared, .surprised:
            Ellipse().fill(Color(red: 0.35, green: 0.10, blue: 0.12)).frame(width: w * 0.5, height: mood == .scared ? w * 0.55 : w * 0.45)
        case .sneaky:
            Capsule().fill(.black.opacity(0.7)).frame(width: w * 0.65, height: 3).rotationEffect(.degrees(-10)).offset(x: 3)
        case .sleepy:
            Ellipse().fill(Color(red: 0.35, green: 0.10, blue: 0.12).opacity(0.8)).frame(width: 6, height: 6)
        case .cross:
            Circle().trim(from: 0.62, to: 0.88).stroke(.black.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: w).offset(y: w / 2 + 2)
        case .calm:
            Circle().trim(from: 0.1, to: 0.4).stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: w * 0.85).offset(y: -w * 0.42 + 2)
        }
    }
}

/// Three little stars circling a dizzy head.
struct StunStars: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 3
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill").font(.system(size: 18)).foregroundStyle(.yellow)
                        .offset(x: cos(t + Double(i) * 2.1) * 40, y: sin(t + Double(i) * 2.1) * 10)
                }
            }
        }
        .frame(width: 100, height: 30)
    }
}

struct CardboardBox: View {
    let open: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.78, green: 0.58, blue: 0.36))
                .frame(width: 76, height: 54)
                .overlay(Rectangle().fill(Color(red: 0.65, green: 0.47, blue: 0.28)).frame(width: 12))
                .padding(.top, 14)
            if open {
                HStack(spacing: 40) {
                    Rectangle().fill(Color(red: 0.70, green: 0.52, blue: 0.32)).frame(width: 30, height: 10).rotationEffect(.degrees(-35))
                    Rectangle().fill(Color(red: 0.70, green: 0.52, blue: 0.32)).frame(width: 30, height: 10).rotationEffect(.degrees(35))
                }
                .offset(y: 8)
            }
        }
        .frame(width: 100, height: 70)
    }
}

struct ChairView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(darkWood).frame(width: 8, height: 100).offset(x: -26)
            Rectangle().fill(wood).frame(width: 66, height: 12).offset(y: -40)
            Rectangle().fill(darkWood).frame(width: 7, height: 40).offset(x: -26)
            Rectangle().fill(darkWood).frame(width: 7, height: 40).offset(x: 26)
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.75, green: 0.25, blue: 0.25)).frame(width: 46, height: 8).offset(y: -50)
        }
        .frame(width: 72, height: 104)
    }
}

struct FloorLampView: View {
    var body: some View {
        VStack(spacing: 0) {
            Trapezoid().fill(Color(red: 0.95, green: 0.85, blue: 0.60)).frame(width: 54, height: 40)
                .shadow(color: .yellow.opacity(0.6), radius: 14)
            Rectangle().fill(Color(red: 0.3, green: 0.3, blue: 0.35)).frame(width: 6, height: 120)
            Capsule().fill(Color(red: 0.3, green: 0.3, blue: 0.35)).frame(width: 40, height: 10)
        }
    }
}

struct SideTableView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(darkWood).frame(width: 10, height: 64).offset(x: -46)
            Rectangle().fill(darkWood).frame(width: 10, height: 64).offset(x: 46)
            RoundedRectangle(cornerRadius: 4).fill(wood).frame(width: 116, height: 14).offset(y: -62)
            // Vase with a flower
            VStack(spacing: 0) {
                FlowerView()
                Capsule().fill(Color.teal).frame(width: 22, height: 30)
            }
            .offset(x: 20, y: -74)
        }
        .frame(width: 120, height: 130)
    }
}

/// A flower drawn from shapes (five petals and a stem).
struct FlowerView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.2, green: 0.6, blue: 0.3)).frame(width: 3, height: 14).offset(y: 12)
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Color.pink).frame(width: 10)
                    .offset(y: -7)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle().fill(Color.yellow).frame(width: 8)
        }
        .frame(width: 26, height: 30)
    }
}

struct BlocksView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 2) {
                block(.red, "A")
                block(.blue, "B")
            }
            block(.green, "C").offset(y: -24)
        }
        .frame(width: 60, height: 50)
    }

    private func block(_ color: Color, _ letter: String) -> some View {
        Text(letter).font(.game(14, .heavy)).foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: RoundedRectangle(cornerRadius: 3))
    }
}

struct DuckView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.yellow).frame(width: 40, height: 26).offset(y: 8)
            Circle().fill(.yellow).frame(width: 22).offset(x: 10, y: -8)
            Capsule().fill(.orange).frame(width: 12, height: 6).offset(x: 24, y: -6)
            Circle().fill(.black).frame(width: 4).offset(x: 14, y: -11)
        }
        .frame(width: 50, height: 44)
    }
}

struct ToyCarView: View {
    let facingRight: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.red).frame(width: 62, height: 20).offset(y: 2)
            RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.85)).frame(width: 30, height: 14).offset(x: -4, y: -12)
            Rectangle().fill(.cyan.opacity(0.8)).frame(width: 10, height: 8).offset(x: 4, y: -12)
            HStack(spacing: 26) {
                Circle().fill(.black).frame(width: 16)
                Circle().fill(.black).frame(width: 16)
            }
            .offset(y: 13)
        }
        .frame(width: 66, height: 44)
        .scaleEffect(x: facingRight ? 1 : -1)
    }
}

struct ToyBallView: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let angle = ctx.date.timeIntervalSinceReferenceDate * 360
            ZStack {
                Circle().fill(Color.orange)
                Circle().trim(from: 0, to: 0.5).fill(Color.blue)
                Circle().stroke(.white, lineWidth: 3)
            }
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(angle))
        }
        .frame(width: 42, height: 42)
    }
}

struct ToyRobotView: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let bob = sin(ctx.date.timeIntervalSinceReferenceDate * 12) * 2
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray).frame(width: 34, height: 28).offset(y: 10)
                RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.75)).frame(width: 28, height: 22).offset(y: -16 + bob)
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 6)
                    Circle().fill(.red).frame(width: 6)
                }
                .offset(y: -16 + bob)
                Rectangle().fill(.gray).frame(width: 2, height: 10).offset(y: -32 + bob)
                Circle().fill(.yellow).frame(width: 6).offset(y: -38 + bob)
            }
            .frame(width: 44, height: 64)
        }
        .frame(width: 44, height: 64)
    }
}
