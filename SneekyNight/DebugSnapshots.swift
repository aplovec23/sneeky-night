#if DEBUG
import SwiftUI

/// Debug builds only. Launched with `-snapshots`, the app draws its characters in many poses
/// (standing, walking, crouching, every face, facing both ways), saves the pictures as PNG files
/// in Documents/snapshots and quits. GitHub's Mac runs this in the iPad simulator
/// (.github/workflows/snapshots.yml), so the drawings can be checked without a device.
/// `-openLevel N` starts straight in Level N, for a screenshot of a real level.
@MainActor
enum DebugSnapshots {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-snapshots") }
    static var openLevel: Int? {
        let n = UserDefaults.standard.integer(forKey: "openLevel")
        return n > 0 ? n : nil
    }

    static func run(game: GameState) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        save(poses, "poses", dir, game)
        save(faces, "faces", dir, game)
        save(grownUps, "grownups", dir, game)
        for (name, sheet) in extraSheets { save(sheet, name, dir, game) }
        try? "done".write(to: dir.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
        exit(0)
    }

    /// More sheets can be added here while working on something.
    static var extraSheets: [(String, AnyView)] { [("dreams", AnyView(dreams))] }

    /// Six dream backgrounds (made from six seeds) and a few random dream names.
    static var dreams: some View {
        sheet("Dream backgrounds and names") {
            ForEach([11, 2024, 777, 31337, 90210, 123456], id: \.self) { seed in
                VStack(alignment: .leading, spacing: 2) {
                    Text("seed \(seed)").font(.system(size: 12)).foregroundStyle(.black)
                    DreamBackdrop(seed: seed, width: 1800)
                        .scaleEffect(0.5, anchor: .topLeading)
                        .frame(width: 900, height: 350, alignment: .topLeading)
                        .clipped()
                }
            }
            Text((0..<12).map { _ in DreamMaker.randomName() }.joined(separator: "  ·  "))
                .font(.system(size: 13)).foregroundStyle(.black).frame(width: 900, alignment: .leading)
        }
    }

    private static func save<V: View>(_ view: V, _ name: String, _ dir: URL, _ game: GameState) {
        let renderer = ImageRenderer(content: view.environment(game))
        renderer.scale = 2
        if let png = renderer.uiImage?.pngData() {
            try? png.write(to: dir.appendingPathComponent(name + ".png"))
        }
    }

    // MARK: Sheets

    static let boy: Look = {
        var look = Look.starter(.boy)
        look.pants = 0
        return look
    }()
    static let girl = Look(gender: .girl, skin: 3, shirt: 6, pattern: 1, cap: 0, hair: 4, hairColor: 4)

    /// The time that makes the walking (or creeping) swing equal `s` (from -1 to 1).
    static func walkTime(_ s: Double, crouching: Bool = false) -> Double { asin(s) / (crouching ? 8 : 13) }

    static var poses: some View {
        let swings = [-1.0, -0.5, 0, 0.5, 1]
        return sheet("Poses (the line is the floor: feet should stand on it)") {
            row("Standing") {
                cell("right, t=0") { CharacterView(look: boy, facingRight: true, frozenTime: 0) }
                cell("right, t=2") { CharacterView(look: boy, facingRight: true, frozenTime: 2) }
                cell("left, t=0") { CharacterView(look: boy, facingRight: false, frozenTime: 0) }
                cell("girl right") { CharacterView(look: girl, facingRight: true, frozenTime: 0.4) }
                cell("girl left") { CharacterView(look: girl, facingRight: false, frozenTime: 0.4) }
            }
            row("Walking right") {
                ForEach(swings, id: \.self) { s in
                    cell("swing \(s)") { CharacterView(look: boy, facingRight: true, walking: true, frozenTime: walkTime(s)) }
                }
            }
            row("Walking left") {
                ForEach(swings, id: \.self) { s in
                    cell("swing \(s)") { CharacterView(look: boy, facingRight: false, walking: true, frozenTime: walkTime(s)) }
                }
            }
            row("Crouching still") {
                ForEach([0.0, 0.7, 1.3, 2.0], id: \.self) { t in
                    cell("right t=\(t)") { CharacterView(look: boy, facingRight: true, crouching: true, frozenTime: t) }
                }
                cell("left") { CharacterView(look: boy, facingRight: false, crouching: true, frozenTime: 0.3) }
            }
            row("Creeping (crouch-walk) right") {
                ForEach(swings, id: \.self) { s in
                    cell("swing \(s)") {
                        CharacterView(look: boy, facingRight: true, walking: true, crouching: true, frozenTime: walkTime(s, crouching: true))
                    }
                }
            }
            row("Creeping left, girl") {
                ForEach(swings, id: \.self) { s in
                    cell("swing \(s)") {
                        CharacterView(look: girl, facingRight: false, walking: true, crouching: true, frozenTime: walkTime(s, crouching: true))
                    }
                }
            }
            row("Other") {
                cell("taunting") { CharacterView(look: boy, taunting: true, frozenTime: 0.1) }
                cell("scared") { CharacterView(look: boy, expression: .scared, frozenTime: 0) }
                cell("surprised") { CharacterView(look: boy, expression: .surprised, frozenTime: 0) }
                cell("worried L") { CharacterView(look: girl, facingRight: false, expression: .worried, frozenTime: 0) }
                cell("sneaky") { CharacterView(look: girl, expression: .sneaky, frozenTime: 0) }
            }
        }
    }

    static var faces: some View {
        sheet("Faces (the player's eight moods, three times bigger)") {
            ForEach([boy, girl], id: \.gender) { look in
                row(look.gender == .boy ? "Boy" : "Girl") {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        cell(mood.name, width: 170, height: 170) {
                            CharacterView(look: look, expression: mood, frozenTime: 0.5)
                                .scaleEffect(2.6, anchor: .top)
                                .frame(width: 170, height: 170, alignment: .top)
                                .offset(x: -20, y: 20)
                                .clipped()
                        }
                    }
                }
            }
            row("Eye colours") {
                ForEach(LookOptions.eyes.indices, id: \.self) { i in
                    cell("eyes \(i)", width: 170, height: 170) {
                        CharacterView(look: { var l = boy; l.eyes = i; return l }(), frozenTime: 0.5)
                            .scaleEffect(2.6, anchor: .top)
                            .frame(width: 170, height: 170, alignment: .top)
                            .offset(x: -20, y: 20)
                            .clipped()
                    }
                }
            }
        }
    }

    static var grownUps: some View {
        sheet("Grown-ups and friends") {
            row("Mom") {
                ForEach(Mood.allCases, id: \.self) { mood in
                    cell(mood.name, width: 170, height: 300) { MomView(stunned: false, walking: false, expression: mood) }
                }
            }
            row("Dad") {
                ForEach(Mood.allCases, id: \.self) { mood in
                    cell(mood.name, width: 170, height: 320) { DadView(stunned: false, walking: false, laughing: false, expression: mood) }
                }
            }
            row("Others") {
                cell("stranger", width: 170, height: 300) { PersonView(outfit: .stranger(1)) }
                cell("guard", width: 170, height: 300) { PersonView(outfit: .guardian) }
                cell("worker", width: 170, height: 300) { PersonView(outfit: .worker(0)) }
                cell("uncle", width: 170, height: 300) { PersonView(outfit: .uncle) }
                cell("Auntie", width: 170, height: 300) { AuntieView() }
                cell("Guide", width: 170, height: 300) { GuideView() }
                cell("brother", width: 170, height: 300) { CharacterView(look: SiblingBuddy.look, frozenTime: 0) }
            }
            row("Ion (the Shop)") {
                cell("Ion", width: 170, height: 300) { IonView() }
                cell("talking", width: 170, height: 300) { IonView(talking: true) }
                cell("looks left", width: 170, height: 300) { IonView(gaze: CGVector(dx: -1, dy: 0)) }
                cell("looks up right", width: 170, height: 300) { IonView(gaze: CGVector(dx: 0.8, dy: -0.6)) }
                cell("looks down", width: 170, height: 300) { IonView(gaze: CGVector(dx: 0, dy: 1)) }
            }
        }
    }

    // MARK: Layout

    static func sheet<C: View>(_ title: String, @ViewBuilder _ rows: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
            rows()
        }
        .padding(16)
        .background(Color.white)
    }

    static func row<C: View>(_ title: String, @ViewBuilder _ cells: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
            HStack(alignment: .bottom, spacing: 8) { cells() }
        }
    }

    /// One picture with a floor line 10 points above the bottom (where a character's feet stand).
    static func cell<C: View>(_ label: String, width: CGFloat = 140, height: CGFloat = 190, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                Color(red: 0.78, green: 0.84, blue: 0.95)
                Rectangle().fill(Color.red.opacity(0.7)).frame(height: 1).offset(y: -10)
                content()
            }
            .frame(width: width, height: height)
            .clipped()
            Text(label).font(.system(size: 11)).foregroundStyle(.black).frame(width: width)
        }
    }
}
#endif
