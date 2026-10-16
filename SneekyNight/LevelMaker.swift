import SwiftUI
import Observation

// MARK: - Data

/// One thing placed in a custom level.
struct CustomItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: String
    var x: Double
    var y: Double
    /// What Mom, Dad or your brother says.
    var text = ""
    /// For boxes: a key is hidden inside.
    var hasKey = false
}

/// A level made in the Level Maker. Saved on the device and shared by every save file.
struct CustomLevel: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name = "My Level"
    var width: Double = 2000
    var seconds: Double = 120
    /// 0 hallway, 1 dungeon, 2 hotel, 3 street.
    var theme = 0
    var items: [CustomItem] = [
        CustomItem(kind: "start", x: 200, y: 620),
        CustomItem(kind: "exit", x: 1850, y: 545),
    ]
    /// Creative mode (admin panel, crown, immortality) while playing this level. Optional so older saved levels still load.
    var creative: Bool?

    /// There's no limit any more: place as many objects and hazards as you like, and make the level as long as you like.
    static let themes = ["Hallway", "Dungeon", "Hotel", "Street"]

    var hazardCount: Int { items.filter { CustomKind.find($0.kind).group == .hazard }.count }
    var objectCount: Int { items.filter { CustomKind.find($0.kind).group == .object }.count }
    var keyCount: Int { items.filter { $0.kind == "key" || ($0.kind == "box" && $0.hasKey) }.count }
}

/// Everything the Level Maker can place.
struct CustomKind: Identifiable {
    enum Group { case object, hazard, character }

    let id: String
    let name: String
    let symbol: String
    let group: Group
    /// Stands against the back wall (true) or anywhere on the floor (false).
    let onWall: Bool
    /// Only one allowed (start, exit, Mom, Dad, brother).
    var single = false

    static let all: [CustomKind] = [
        CustomKind(id: "start", name: "Start", symbol: "flag.fill", group: .object, onWall: false, single: true),
        CustomKind(id: "exit", name: "Exit door", symbol: "door.left.hand.closed", group: .object, onWall: true, single: true),
        CustomKind(id: "key", name: "Key", symbol: "key.fill", group: .object, onWall: false),
        CustomKind(id: "box", name: "Box", symbol: "shippingbox.fill", group: .object, onWall: false),
        CustomKind(id: "crate", name: "Rock", symbol: "mountain.2.fill", group: .object, onWall: false),
        CustomKind(id: "closet", name: "Closet", symbol: "cabinet.fill", group: .object, onWall: true),
        CustomKind(id: "plant", name: "Big plant", symbol: "leaf.fill", group: .object, onWall: true),
        CustomKind(id: "picture", name: "Picture", symbol: "photo.fill", group: .object, onWall: true),
        CustomKind(id: "dog", name: "Dog", symbol: "pawprint.fill", group: .object, onWall: false),
        CustomKind(id: "chair", name: "Chair", symbol: "chair.fill", group: .hazard, onWall: false),
        CustomKind(id: "table", name: "Table", symbol: "table.furniture.fill", group: .hazard, onWall: false),
        CustomKind(id: "lamp", name: "Lamp", symbol: "lamp.floor.fill", group: .hazard, onWall: false),
        CustomKind(id: "cans", name: "Cans", symbol: "cylinder.fill", group: .hazard, onWall: false),
        CustomKind(id: "car", name: "Toy car", symbol: "car.fill", group: .hazard, onWall: false),
        CustomKind(id: "spikes", name: "Spikes", symbol: "triangle.fill", group: .hazard, onWall: false),
        CustomKind(id: "stranger", name: "Stranger", symbol: "figure.walk", group: .hazard, onWall: false),
        // Instant-fail hazards: one touch and the level is over.
        CustomKind(id: "lava", name: "Lava (instant)", symbol: "flame.fill", group: .hazard, onWall: false),
        CustomKind(id: "laser", name: "Laser (instant)", symbol: "bolt.horizontal.fill", group: .hazard, onWall: true),
        CustomKind(id: "mom", name: "Mom", symbol: "figure.dress.line.vertical.figure", group: .character, onWall: true, single: true),
        CustomKind(id: "dad", name: "Dad", symbol: "mustache.fill", group: .character, onWall: false, single: true),
        CustomKind(id: "brother", name: "Brother", symbol: "figure.child", group: .character, onWall: false, single: true),
        // Only in the Level Maker: you'll never meet these in the story levels.
        CustomKind(id: "uncle", name: "Uncle", symbol: "car.fill", group: .character, onWall: false),
        CustomKind(id: "friend", name: "Friend", symbol: "figure.2.arms.open", group: .character, onWall: false),
        CustomKind(id: "ghost", name: "Ghost", symbol: "theatermasks.fill", group: .character, onWall: false),
        CustomKind(id: "guide", name: "The Guide", symbol: "lightbulb.fill", group: .character, onWall: false),
        CustomKind(id: "guard", name: "Guard", symbol: "flashlight.on.fill", group: .character, onWall: false),
        CustomKind(id: "worker", name: "Worker", symbol: "bell.fill", group: .character, onWall: false),
    ]

    /// Characters you talk to (E next to them) to hear their line.
    static let talkers: Set<String> = ["brother", "uncle", "friend", "ghost", "guide"]
    /// Characters who walk up and down and send you back to the start if they see you.
    static let watchers: Set<String> = ["guard", "worker"]

    static func find(_ id: String) -> CustomKind { all.first { $0.id == id } ?? all[3] }

    static func defaultLine(_ id: String) -> String {
        switch id {
        case "mom": "Who is making that noise?!"
        case "dad": "Hey! Back to bed, kiddo!"
        case "uncle": "Need a ride, kiddo? Find the keys first!"
        case "friend": "You're sneaking out too? Cool! Race you to the exit!"
        case "ghost": "Boooo... just kidding. I'm friendly! The keys are that way."
        case "guide": "Follow your nose... and check every box."
        case "guard": "Hey! No kids allowed here!"
        case "worker": "Lost, little one? Back to the start you go!"
        default: "Good luck! I won't tell."
        }
    }
}

enum CustomStore {
    private static let key = "customLevels"

    static func all() -> [CustomLevel] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CustomLevel].self, from: data)) ?? []
    }

    static func find(_ id: String) -> CustomLevel? { all().first { $0.id == id } }

    static func save(_ level: CustomLevel) {
        var levels = all()
        if let i = levels.firstIndex(where: { $0.id == level.id }) { levels[i] = level } else { levels.append(level) }
        write(levels)
    }

    static func delete(_ id: String) {
        write(all().filter { $0.id != id })
    }

    private static func write(_ levels: [CustomLevel]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(levels), forKey: key)
    }
}

// MARK: - Shared drawing

/// How a placed thing looks, in the editor and in the game.
struct CustomItemArt: View {
    let kind: String
    var open = false
    var hiding = false

    var body: some View {
        switch kind {
        case "start":
            VStack(spacing: 0) {
                Image(systemName: "flag.fill").font(.system(size: 44, weight: .bold)).foregroundStyle(.green)
                Text("START").font(.game(16, .heavy)).foregroundStyle(.white)
            }
        case "exit": DoorView(color: Color(red: 0.25, green: 0.55, blue: 0.35), open: open) { DoorSign(text: "EXIT", color: .yellow) }
        case "key":
            Image(systemName: "key.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Palette.gold)
                .shadow(color: .yellow, radius: 8).rotationEffect(.degrees(-30))
        case "box": CardboardBox(open: open)
        case "crate":
            RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.4)).frame(width: 90, height: 64)
                .overlay(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.5)).frame(width: 50, height: 30).offset(x: -12, y: -10))
        case "closet": ClosetView(hiding: hiding)
        case "plant": LobbyPlantView(hiding: hiding)
        case "picture": PictureFrame(seed: 3).offset(y: -230)
        case "dog": DogView(happy: true)
        case "chair": ChairView()
        case "table": SideTableView()
        case "lamp": FloorLampView()
        case "cans": PaintCansView()
        case "car": ToyCarView(facingRight: true)
        case "spikes": SpikeTrapView()
        case "stranger": PersonView(outfit: .stranger(1))
        case "lava": LavaPoolView()
        case "laser": LaserBeamView(on: !open).offset(y: 150)
        case "mom": MomView(stunned: false, walking: false)
        case "dad": DadView(stunned: false, walking: false, laughing: false)
        case "brother": CharacterView(look: SiblingBuddy.look, facingRight: false).scaleEffect(0.78, anchor: .bottom)
        case "uncle": PersonView(outfit: .uncle).scaleEffect(x: -1, y: 1)
        case "friend": CharacterView(look: CustomItemArt.friendLook, facingRight: false)
        case "ghost": GhostView()
        case "guide": GuideView()
        case "guard": PersonView(outfit: .guardian)
        case "worker": PersonView(outfit: .worker(0))
        default: EmptyView()
        }
    }
}

extension CustomItemArt {
    static let friendLook = Look(gender: .girl, skin: 4, shirt: 3, pattern: 4, cap: 0)
}

/// A friendly ghost (Level Maker only): a see-through kid in a sheet, bobbing up and down.
struct GhostView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let bob = sin(ctx.date.timeIntervalSinceReferenceDate * 2.2) * 6
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 40)
                    .fill(.white.opacity(0.85))
                    .frame(width: 80, height: 118)
                HStack(spacing: 14) {
                    Ellipse().fill(Color(white: 0.15)).frame(width: 12, height: 18)
                    Ellipse().fill(Color(white: 0.15)).frame(width: 12, height: 18)
                }
                .offset(y: -22)
                Ellipse().fill(Color(white: 0.2)).frame(width: 14, height: 10).offset(y: 4)
            }
            .shadow(color: .white.opacity(0.7), radius: 12)
            .offset(y: -24 + bob)
            .frame(width: 100, height: 160, alignment: .bottom)
        }
    }
}

struct CustomBackdrop: View {
    let theme: Int
    let width: CGFloat

    var body: some View {
        switch theme {
        case 1: DungeonWall(width: width)
        case 2: LobbyWall(width: width)
        case 3: StreetScene(width: max(width, 1200))
        default: HallwayWall(width: width)
        }
    }
}

// MARK: - List of levels

struct LevelMakerListView: View {
    let onEdit: (String) -> Void
    let onPlay: (String) -> Void
    let onBack: () -> Void
    @State private var levels = CustomStore.all()

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 16) {
                ZStack {
                    HStack {
                        RoundIconButton(symbol: "chevron.left", action: onBack)
                        Spacer()
                        small("New level", "plus", Palette.button) {
                            let level = CustomLevel(name: "My Level \(levels.count + 1)")
                            CustomStore.save(level)
                            onEdit(level.id)
                        }
                    }
                    Text("Level Maker").font(.game(52, .heavy)).foregroundStyle(.white)
                }
                Text("Build your own levels with no limits: as many objects and hazards as you like, as long as you like. Add Mom, Dad, your brother and Level Maker characters, and write what they say.")
                    .font(.game(19, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                if levels.isEmpty {
                    Text("No levels yet. Tap \"New level\" to make your first one!")
                        .font(.game(24))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 80)
                }
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(levels) { level in
                            HStack(spacing: 14) {
                                Image(systemName: "hammer.fill").font(.system(size: 28)).foregroundStyle(Palette.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.name).font(.game(26, .heavy))
                                    Text("\(CustomLevel.themes[level.theme % 4]) · \(level.objectCount) objects · \(level.hazardCount) hazards · \(level.keyCount) keys · \(Int(level.seconds)) s")
                                        .font(.game(16, .medium)).opacity(0.75)
                                }
                                Spacer()
                                small("Play", "play.fill", Palette.button) { onPlay(level.id) }
                                small("Edit", "pencil", Color(red: 0.35, green: 0.30, blue: 0.70)) { onEdit(level.id) }
                                small("Delete", "trash.fill", .red) {
                                    CustomStore.delete(level.id)
                                    levels = CustomStore.all()
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .frame(width: 900)
                            .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
                        }
                    }
                }
            }
            .padding(30)
        }
    }

    private func small(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.game(18))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(color.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Editor

struct LevelEditorView: View {
    let levelID: String
    let onTest: () -> Void
    let onBack: () -> Void

    @State private var level = CustomLevel()
    @State private var tool: String? = "box"
    @State private var selected: UUID?
    @State private var note = "Pick something below, then tap the room to place it. Drag a thing to move it. Drag an empty spot to slide the room."
    @FocusState private var typing: Bool
    @State private var scroll: CGFloat = 0
    @State private var scrollStart: CGFloat = 0
    @State private var touching = false
    @State private var grabbed: UUID?
    @State private var hadSelection = false

    private static let scale: CGFloat = 0.6
    private static let top: CGFloat = 80
    private static let floor: ClosedRange<Double> = 560...685

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 10) {
                header
                stage
                Text(note)
                    .font(.game(16, .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let i = level.items.firstIndex(where: { $0.id == selected }) {
                    inspector(i)
                } else {
                    palette
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onAppear { level = CustomStore.find(levelID) ?? CustomLevel(id: levelID) }
        .onChange(of: level) { _, new in CustomStore.save(new) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundIconButton(symbol: "chevron.left", action: onBack).scaleEffect(0.85)
            TextField("Level name", text: $level.name)
                .focused($typing)
                .font(.game(22))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(width: 230)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
            stepper("Length", "\(Int(level.width))") { change in
                level.width = max(1000, level.width + Double(change) * 500)
                for i in level.items.indices { level.items[i].x = min(level.items[i].x, level.width - 80) }
            }
            stepper("Time", "\(Int(level.seconds)) s") { change in
                level.seconds = max(30, level.seconds + Double(change) * 30)
            }
            Button {
                SoundPlayer.shared.tap()
                level.theme = (level.theme + 1) % CustomLevel.themes.count
            } label: {
                Label(CustomLevel.themes[level.theme % 4], systemImage: "paintbrush.fill")
                    .font(.game(17)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Button {
                SoundPlayer.shared.tap()
                level.creative = !(level.creative ?? false)
            } label: {
                Label(level.creative == true ? "Creative: on" : "Creative: off", systemImage: "wand.and.stars")
                    .font(.game(17)).foregroundStyle(level.creative == true ? .black : .white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(level.creative == true ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.15)), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Objects \(level.objectCount)")
                Text("Hazards \(level.hazardCount)")
            }
            .font(.game(14, .heavy))
            .foregroundStyle(.white.opacity(0.85))
            Button {
                SoundPlayer.shared.tap()
                CustomStore.save(level)
                onTest()
            } label: {
                Label("Test", systemImage: "play.fill")
                    .font(.game(22))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Palette.button.gradient, in: Capsule())
                    .fixedSize()
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func stepper(_ title: String, _ value: String, change: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Button { SoundPlayer.shared.tap(); change(-1) } label: { Image(systemName: "minus.circle.fill") }
            VStack(spacing: 0) {
                Text(title).font(.game(11, .heavy)).opacity(0.7)
                Text(value).font(.game(16, .heavy)).monospacedDigit()
            }
            .frame(width: 62)
            Button { SoundPlayer.shared.tap(); change(1) } label: { Image(systemName: "plus.circle.fill") }
        }
        .font(.system(size: 24))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.12), in: Capsule())
    }

    /// The room, shrunk to fit. Drag an empty spot to slide along it.
    private var stage: some View {
        let k = Self.scale
        return GeometryReader { geo in
            let furthest = max(0, level.width * k - geo.size.width)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    CustomBackdrop(theme: level.theme, width: level.width)
                    ForEach(level.items.sorted { $0.y < $1.y }) { item in
                        CustomItemArt(kind: item.kind)
                            .overlay(alignment: .top) {
                                if item.kind == "box" && item.hasKey {
                                    Image(systemName: "key.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.gold).offset(y: -26)
                                }
                            }
                            .overlay {
                                if item.id == selected {
                                    RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, style: StrokeStyle(lineWidth: 5, dash: [10, 6])).padding(-8)
                                }
                            }
                            .anchored(at: CGPoint(x: item.x, y: item.y))
                    }
                }
                .frame(width: level.width, height: 700, alignment: .topLeading)
                .offset(y: -Self.top)
                .scaleEffect(k, anchor: .topLeading)
                .offset(x: -min(scroll, furthest))
                .allowsHitTesting(false)
                // One touch layer for placing, picking, dragging and sliding the view.
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !touching {
                                    touching = true
                                    typing = false
                                    hadSelection = selected != nil
                                    scrollStart = min(scroll, furthest)
                                    grabbed = hit(point(value.startLocation))?.id
                                    selected = grabbed
                                }
                                if let i = level.items.firstIndex(where: { $0.id == grabbed }) {
                                    if hypot(value.translation.width, value.translation.height) > 6 { move(i, to: point(value.location)) }
                                } else {
                                    scroll = min(max(scrollStart - value.translation.width, 0), furthest)
                                }
                            }
                            .onEnded { value in
                                touching = false
                                let tapped = hypot(value.translation.width, value.translation.height) < 6
                                // A tap on an empty spot places the picked thing (or just lets go of the selected one).
                                if tapped, grabbed == nil, !hadSelection { place(at: point(value.location)) }
                            }
                    )
            }
            .frame(width: geo.size.width, height: (700 - Self.top) * k, alignment: .topLeading)
            .clipped()
        }
        .frame(height: (700 - Self.top) * k)
        .background(.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 2))
    }

    /// Turns a touch on the small stage into a spot in the room.
    private func point(_ location: CGPoint) -> CGPoint {
        CGPoint(x: (location.x + scroll) / Self.scale, y: location.y / Self.scale + Self.top)
    }

    private func hit(_ at: CGPoint) -> CustomItem? {
        level.items.reversed().first { item in
            let kind = CustomKind.find(item.kind)
            let tall: Double = kind.onWall || kind.group == .character || item.kind == "stranger" ? 260 : 90
            return abs(item.x - at.x) < 60 && at.y < item.y + 16 && at.y > item.y - tall
        }
    }

    private func move(_ i: Int, to at: CGPoint) {
        let kind = CustomKind.find(level.items[i].kind)
        level.items[i].x = min(max(Double(at.x), 80), level.width - 80)
        level.items[i].y = kind.onWall ? 545 : min(max(Double(at.y), Self.floor.lowerBound), Self.floor.upperBound)
    }

    private func place(at: CGPoint) {
        guard let tool else { return }
        let kind = CustomKind.find(tool)
        if kind.single, let i = level.items.firstIndex(where: { $0.kind == tool }) {
            // There's only one of these: move it here.
            move(i, to: at)
            return
        }
        var item = CustomItem(kind: tool, x: 0, y: 0)
        if kind.group == .character { item.text = CustomKind.defaultLine(tool) }
        level.items.append(item)
        move(level.items.count - 1, to: at)
        Sound.box.play(volume: 0.5)
        note = "\(kind.name) placed. Tap it to move or change it."
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(CustomKind.all) { kind in
                    Button {
                        SoundPlayer.shared.tap()
                        tool = kind.id
                        note = "Tap the room to place: \(kind.name)."
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: kind.symbol).font(.system(size: 22, weight: .bold))
                            Text(kind.name).font(.game(12, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 78, height: 62)
                        .background((kind.group == .hazard ? Color.red : kind.group == .character ? Color.purple : Color.teal)
                            .opacity(tool == kind.id ? 0.95 : 0.4), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tool == kind.id ? Color.yellow : .clear, lineWidth: 3))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Text("Teal = objects   ·   Red = hazards   ·   Purple = characters (tap them after placing to write what they say). Uncle, Friend, Ghost, the Guide, Guard and Worker are Level Maker only!")
                .font(.game(13, .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func inspector(_ i: Int) -> some View {
        let item = level.items[i]
        let kind = CustomKind.find(item.kind)
        return HStack(spacing: 12) {
            Label(kind.name, systemImage: kind.symbol).font(.game(22, .heavy)).foregroundStyle(.white)
            Text("Drag it to move.").font(.game(15, .semibold)).foregroundStyle(.white.opacity(0.7))
            if item.kind == "box" {
                Toggle("Key inside", isOn: $level.items[i].hasKey)
                    .font(.game(18)).foregroundStyle(.white).tint(Palette.button).frame(width: 190)
            }
            if kind.group == .character {
                TextField("What do they say?", text: $level.items[i].text)
                    .focused($typing)
                    .font(.game(18))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .frame(width: 380)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: level.items[i].text) { _, new in
                        if new.count > 80 { level.items[i].text = String(new.prefix(80)) }
                    }
            }
            Spacer()
            if item.kind != "start" && item.kind != "exit" {
                Button {
                    Sound.box.play(volume: 0.5)
                    level.items.remove(at: i)
                    selected = nil
                } label: {
                    Label("Delete", systemImage: "trash.fill").font(.game(18)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9).background(Color.red.gradient, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            Button {
                SoundPlayer.shared.tap()
                typing = false
                selected = nil
            } label: {
                Label("Done", systemImage: "checkmark").font(.game(18)).foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 9).background(Palette.gold.gradient, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(10)
        .frame(height: 62)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Playing a custom level

/// Runs a level from the Level Maker: collect every key (loose or hidden in boxes), then use the exit.
/// Mom wakes up when the clock runs out, you're too loud or you bump a hazard; Dad patrols and
/// chases you if he sees you; your brother says his line when you talk to him.
@MainActor
@Observable
final class CustomLevelModel {
    let engine = GameEngine()
    let level: CustomLevel
    var inventory: [InventoryItem] = []
    var popup: Popup?
    var banner: String?
    var hidingIn: String?
    var doorOpen = false
    var over = false
    var strangers: [Walker] = []
    /// Where the laser beams are, and whether they're switched on right now (they blink).
    var lasers: [CGFloat] = []
    var lasersOn = true
    @ObservationIgnored private var laserClock = 0.0
    var dadX: CGFloat = 0
    var dadRight = true
    var dadHere = false
    /// Someone you talked to is saying their line: where they stand, and what they say.
    var talkLine: (spot: CGPoint, text: String)?
    /// Level Maker guards and workers walking their beat.
    var watchers: [Walker] = []
    let chase = Chase()
    let belt = ItemBelt()

    @ObservationIgnored var onExit: () -> Void = {}
    /// Dreams (Side Level 5) use custom levels too: they count the win, and "again" makes a brand-new dream.
    @ObservationIgnored var onWin: () -> Void = {}
    @ObservationIgnored var onPlayAgain: (() -> Void)?
    @ObservationIgnored var winTitle = "You did it!"
    @ObservationIgnored var winMessage: String?
    @ObservationIgnored var onEdit: () -> Void = {}
    @ObservationIgnored private var keyBoxes: Set<String> = []
    @ObservationIgnored private var dadHome: CGPoint = .zero
    @ObservationIgnored private var talkTime = 0.0
    @ObservationIgnored private var bannerTime = 0.0
    /// The character you're standing next to (E talks to them).
    @ObservationIgnored private var nearTalker: CustomItem?
    /// What each guard or worker says when they see you, by walker id.
    @ObservationIgnored private var watcherLines: [Int: String] = [:]
    @ObservationIgnored private var start = CGPoint(x: 200, y: 620)

    static let floor: ClosedRange<CGFloat> = 545...690

    private func item(_ kind: String) -> CustomItem? { level.items.first { $0.kind == kind } }
    private func line(_ kind: String) -> String {
        let text = item(kind)?.text.trimmingCharacters(in: .whitespaces) ?? ""
        return text.isEmpty ? CustomKind.defaultLine(kind) : text
    }
    var mom: CustomItem? { item("mom") }
    var brother: CustomItem? { item("brother") }
    /// Everyone you can talk to: your brother and the Level Maker characters.
    var talkers: [CustomItem] { level.items.filter { CustomKind.talkers.contains($0.kind) } }
    private func line(of item: CustomItem) -> String {
        let text = item.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? CustomKind.defaultLine(item.kind) : text
    }

    init(level: CustomLevel) {
        self.level = level
        engine.onInteract = { [weak self] i in self?.interact(i) }
        engine.onHazard = { [weak self] i in self?.bumped(i) }
        engine.onTimeUp = { [weak self] in self?.wakeMom("Time's up!") }
        engine.onTooLoud = { [weak self] in self?.wakeMom("Too loud!") }
        engine.onConfirm = { [weak self] in self?.popup?.action() }
        engine.onTaunt = { [weak self] in self?.chase.taunted() }
        engine.onTick = { [weak self] dt in self?.tick(dt) }
        engine.onKO = { [weak self] in self?.end("Ouch!", "You ran out of health.") }
        engine.onItemKey = { [weak self] i in
            if let item = ItemBelt.Item(rawValue: i) { self?.belt.use(item) }
        }
        belt.stun = { [weak self] seconds, momOnly in self?.chase.stun(seconds, momOnly: momOnly) ?? false }
        chase.engine = engine
        chase.entrance = { [weak self] _ in
            guard let self else { return (.zero, 2) }
            // With no Mom placed, she comes in where you started.
            return (CGPoint(x: mom?.x ?? item("start")?.x ?? 150, y: 600), mom == nil ? 3 : 0.5)
        }
        chase.setBanner = { [weak self] in self?.banner = $0 }
        chase.onCaught = { [weak self] _, message in self?.end("Caught!", message) }
        chase.onGaveUp = { [weak self] who in
            guard let self else { return }
            engine.timerOn = true
            engine.timeLeft = max(engine.timeLeft, 60)
            engine.resetNoise()
            dadHere = item("dad") != nil
            engine.say("\(who == .mom ? "Mom" : "Dad") gave up. Phew!", seconds: 2.5)
        }
        chase.brotherPos = { [weak self] in self?.brother.map { CGPoint(x: $0.x, y: $0.y) } }
        // Practice mode: the Guide leads you to the next key (or the box hiding it), then the exit.
        engine.guideGoal = { [weak self] in
            guard let self else { return nil }
            if let key = engine.nearestSpot(where: { $0.kind == "key" || self.keyBoxes.contains($0.id) }) { return key }
            return engine.nearestSpot { $0.kind == "exit" }
        }
        reset()
    }

    func apply(skills: Set<Skill>) {
        engine.canDash = skills.contains(.dash)
        engine.canRun = skills.contains(.run)
    }

    func reset() {
        var things: [Thing] = []
        keyBoxes = []
        strangers = []
        lasers = []
        lasersOn = true
        laserClock = 0
        watchers = []
        watcherLines = [:]
        for (n, item) in level.items.enumerated() {
            let id = "\(item.kind)\(n)"
            let pos = CGPoint(x: item.x, y: item.y)
            switch item.kind {
            case "exit": things.append(HallwayModel.onWall(id, "exit", x: pos.x, prompt: "Open the exit door", reach: 90))
            case "closet": things.append(HallwayModel.onWall(id, "closet", x: pos.x, prompt: "Hide in the closet"))
            case "plant": things.append(HallwayModel.onWall(id, "plant", x: pos.x, prompt: "Hide behind the plant"))
            case "picture": things.append(HallwayModel.onWall(id, "picture", x: pos.x, prompt: nil))
            case "key":
                things.append(Thing(id: id, kind: "key", pos: pos, footprint: CGSize(width: 34, height: 16),
                                    prompt: "Pick up the key", reach: CGSize(width: 70, height: 50), flat: true))
            case "box":
                var box = HallwayModel.box(id, x: pos.x, y: pos.y)
                box.kind = "box"
                things.append(box)
                if item.hasKey { keyBoxes.insert(id) }
            case "crate": things.append(Thing(id: id, kind: "crate", pos: pos, footprint: CGSize(width: 86, height: 34), solid: true))
            case "dog":
                things.append(Thing(id: id, kind: "dog", pos: pos, footprint: CGSize(width: 70, height: 22),
                                    prompt: "Pet the dog", reach: CGSize(width: 80, height: 60)))
            case "chair": things.append(Thing(id: id, kind: "chair", pos: pos, footprint: CGSize(width: 64, height: 30), hazard: .chair))
            case "table": things.append(Thing(id: id, kind: "table", pos: pos, footprint: CGSize(width: 110, height: 36), hazard: .table))
            case "lamp": things.append(Thing(id: id, kind: "lamp", pos: pos, footprint: CGSize(width: 40, height: 26), hazard: .lamp))
            case "cans": things.append(Thing(id: id, kind: "cans", pos: pos, footprint: CGSize(width: 60, height: 24), hazard: .cans))
            case "car":
                var car = Thing(id: id, kind: "car", pos: pos, footprint: CGSize(width: 60, height: 26), hazard: .toy)
                car.patrol = max(60, pos.x - 220)...min(level.width - 60, pos.x + 220)
                car.speed = 220
                things.append(car)
            case "lava":
                things.append(Thing(id: id, kind: "lava", pos: pos, footprint: CGSize(width: 120, height: 40), flat: true))
            case "laser": lasers.append(pos.x)
            case "spikes", "stranger":
                strangers.append(Walker(id: n, kind: item.kind == "spikes" ? .rat : .stranger, pos: pos,
                                        range: max(60, pos.x - 240)...min(level.width - 60, pos.x + 240),
                                        speed: item.kind == "spikes" ? 170 : 110, style: n))
            case "guard", "worker":
                watchers.append(Walker(id: n, kind: item.kind == "guard" ? .guardian : .worker, pos: pos,
                                       range: max(60, pos.x - 300)...min(level.width - 60, pos.x + 300),
                                       speed: item.kind == "guard" ? 115 : 100, style: n))
                watcherLines[n] = line(of: item)
            default: break
            }
        }
        start = item("start").map { CGPoint(x: $0.x, y: $0.y) } ?? CGPoint(x: 200, y: 620)
        engine.load(SceneLayout(width: level.width, floor: Self.floor, things: things, spawn: start))
        engine.usesHP = !strangers.isEmpty || watchers.contains { $0.kind == .guardian }
        engine.timeLeft = level.seconds
        engine.timerOn = true
        engine.resetNoise()
        engine.bubble = nil
        chase.reset()
        belt.reset()
        inventory = []
        popup = nil
        banner = nil
        hidingIn = nil
        doorOpen = false
        over = false
        talkLine = nil
        nearTalker = nil
        bannerTime = 0
        if let dad = item("dad") {
            dadHome = CGPoint(x: dad.x, y: dad.y)
            dadX = dad.x
            dadHere = true
        } else {
            dadHere = false
        }
        engine.defaultPrompt = nil
        engine.running = true
        let keys = level.keyCount
        engine.say(keys == 0 ? "Find the exit door!" : "I need \(keys) key\(keys == 1 ? "" : "s") to open the exit.", seconds: 3)
    }

    private func interact(_ i: Int) {
        let thing = engine.things[i]
        switch thing.kind {
        case "closet", "plant":
            Sound.closet.play()
            if engine.hidden {
                engine.hidden = false
                hidingIn = nil
            } else {
                engine.ducking = false
                engine.carrying = nil
                engine.player = CGPoint(x: thing.pos.x, y: Self.floor.lowerBound + 8)
                engine.hidden = true
                hidingIn = thing.id
            }
        case "key":
            engine.things[i].hidden = true
            gotKey()
        case "box":
            engine.things[i].open = true
            Sound.box.play()
            if keyBoxes.remove(thing.id) != nil { gotKey() } else { engine.say("Nothing in this one.") }
        case "dog":
            Sound.woof.play()
            engine.say("Good dog!", seconds: 1.4)
        case "exit":
            let missing = level.keyCount - inventory.count
            if missing > 0 {
                Sound.buzz.play()
                engine.say("Locked! I still need \(missing) key\(missing == 1 ? "" : "s").")
            } else {
                win()
            }
        default: break
        }
    }

    private func gotKey() {
        Sound.key.play()
        inventory.append(InventoryItem(id: "key\(inventory.count)", symbol: "key.fill", color: Palette.gold))
        engine.say("A key! \(inventory.count) of \(level.keyCount).", seconds: 1.6)
    }

    private func win() {
        over = true
        doorOpen = true
        engine.timerOn = false
        chase.reset()
        Sound.unlock.play()
        Sound.win.play()
        onWin()
        show(Popup(title: winTitle, message: winMessage ?? "You beat \"\(level.name)\"!", symbol: "star.fill", color: Palette.gold,
                   button: onPlayAgain == nil ? "Play again" : "Dream again",
                   action: { [weak self] in
                       if let again = self?.onPlayAgain { again() } else { self?.reset() }
                   },
                   secondButton: "Back", secondAction: { [weak self] in self?.onExit() }))
    }

    private func tick(_ dt: Double) {
        chase.tick(dt)
        belt.tick(dt)
        guard !over else { return }
        let player = engine.player
        if talkTime > 0 {
            talkTime -= dt
            if talkTime <= 0 { talkLine = nil }
        }
        if bannerTime > 0 {
            bannerTime -= dt
            if bannerTime <= 0 { banner = nil }
        }
        // Talking to someone is the stand-anywhere action when you're next to them.
        let near = talkers.filter { abs(player.x - $0.x) < 90 && abs(player.y - $0.y) < 70 }
            .min { abs(player.x - $0.x) < abs(player.x - $1.x) }
        nearTalker = near
        let prompt: String? = near.map { $0.kind == "brother" ? "Talk to your brother" : "Talk to \(CustomKind.find($0.kind).name)" }
        if engine.defaultPrompt != prompt { engine.defaultPrompt = prompt }
        walkWatchers(dt)
        // Instant-fail hazards. Lava: jump over it. Lasers: they blink, so walk through while they're off.
        laserClock += dt
        let on = laserClock.truncatingRemainder(dividingBy: 3) < 1.7
        if on != lasersOn { lasersOn = on }
        if !engine.safe && !engine.godMode && !engine.hidden {
            if engine.z < 14, engine.things.contains(where: { $0.kind == "lava" && $0.covers(player, pad: CGSize(width: -8, height: -4)) }) {
                end("Melted!", "You stepped in the lava. One touch is all it takes!")
                return
            }
            if lasersOn, lasers.contains(where: { abs($0 - player.x) < 24 }) {
                end("Zapped!", "You walked into a laser beam. Wait until it blinks off!")
                return
            }
        }
        for i in strangers.indices {
            strangers[i].pos.x += strangers[i].speed * CGFloat(dt) * Difficulty.current.hazardSpeed
            if strangers[i].pos.x >= strangers[i].range.upperBound || strangers[i].pos.x <= strangers[i].range.lowerBound {
                strangers[i].pos.x = min(max(strangers[i].pos.x, strangers[i].range.lowerBound), strangers[i].range.upperBound)
                strangers[i].speed = -strangers[i].speed
            }
            strangers[i].facingRight = strangers[i].speed > 0
            let spikes = strangers[i].kind == .rat
            if abs(player.x - strangers[i].pos.x) < 44, abs(player.y - strangers[i].pos.y) < (spikes ? 20 : 28),
               engine.z < (spikes ? 14 : 40), engine.damage(spikes ? 15 : 20) {
                engine.say("Ouch!", seconds: 1)
            }
        }
        // Dad walks up and down near where you put him, and chases you if he sees you.
        if dadHere && !chase.active {
            dadX += (dadRight ? 1 : -1) * 105 * CGFloat(dt)
            if dadX > min(dadHome.x + 230, level.width - 80) { dadRight = false }
            if dadX < max(dadHome.x - 230, 80) { dadRight = true }
            let ahead = (player.x - dadX) * (dadRight ? 1 : -1)
            if ahead > 0, ahead < (engine.ducking ? 110 : 280), abs(player.y - dadHome.y) < 90, !engine.concealed, !engine.safe {
                dadHere = false
                chase.alarm(.dad, "Dad: \"\(line("dad"))\"", from: CGPoint(x: dadX, y: dadHome.y))
            }
        }
    }

    func talkToBrother() {
        guard let who = nearTalker else { return }
        Sound.squeak.play(volume: 0.3)
        talkLine = (CGPoint(x: who.x, y: who.y), line(of: who))
        talkTime = 4
    }

    /// Guards and workers walk up and down. If one sees you, you're sent back to the start (guards hurt, too).
    private func walkWatchers(_ dt: Double) {
        let player = engine.player
        for i in watchers.indices {
            if watchers[i].wait > 0 {
                watchers[i].wait -= dt
            } else {
                watchers[i].pos.x += watchers[i].speed * CGFloat(dt)
                let range = watchers[i].range
                if watchers[i].pos.x >= range.upperBound || watchers[i].pos.x <= range.lowerBound {
                    watchers[i].pos.x = min(max(watchers[i].pos.x, range.lowerBound), range.upperBound)
                    watchers[i].speed = -watchers[i].speed
                    watchers[i].wait = .random(in: 1...2)
                }
                watchers[i].facingRight = watchers[i].speed > 0
            }
            let w = watchers[i]
            let dx = player.x - w.pos.x, dy = player.y - w.pos.y
            let ahead = dx * (w.facingRight ? 1 : -1)
            guard ahead > 0, ahead < (engine.ducking ? 110 : 290), abs(dy) < 85, !engine.concealed, engine.z < 60, !engine.safe else { continue }
            if w.kind == .guardian { engine.damage(25) }
            guard !over else { return }
            Sound.buzz.play()
            banner = "\(w.kind == .guardian ? "Guard" : "Worker"): \"\(watcherLines[w.id] ?? CustomKind.defaultLine(w.kind == .guardian ? "guard" : "worker"))\""
            bannerTime = 2.6
            engine.player = start
            engine.hidden = false
            hidingIn = nil
            return
        }
    }

    private func bumped(_ i: Int) {
        engine.ignoreHazards(for: 2.5)
        engine.running = true
        wakeMom(engine.things[i].hazard?.noise ?? "CRASH!")
    }

    private func wakeMom(_ why: String) {
        guard !over, !chase.active else {
            engine.resetNoise()
            return
        }
        if let mom {
            chase.alarm(.mom, "\(why) Mom: \"\(line("mom"))\"", from: CGPoint(x: mom.x, y: 590))
        } else {
            chase.alarm(.mom, "\(why) Mom is coming!")
        }
    }

    private func end(_ title: String, _ message: String) {
        over = true
        banner = nil
        engine.running = false
        Sound.caught.play()
        show(Popup(title: title, message: message, symbol: "exclamationmark.triangle.fill", color: .red,
                   button: "Try Again", action: { [weak self] in self?.reset() },
                   secondButton: "Back", secondAction: { [weak self] in self?.onExit() }))
    }

    private func show(_ newPopup: Popup) {
        engine.running = false
        var wrapped = newPopup
        wrapped.action = { [weak self] in
            withAnimation { self?.popup = nil }
            newPopup.action()
        }
        wrapped.secondAction = { [weak self] in
            withAnimation { self?.popup = nil }
            newPopup.secondAction()
        }
        withAnimation { popup = wrapped }
    }

    func hint() {
        let missing = level.keyCount - inventory.count
        engine.say(missing > 0 ? "\(missing) more key\(missing == 1 ? "" : "s") to find. Check the boxes!" : "I have every key. To the exit door!")
    }
}

struct CustomLevelView: View {
    @Environment(GameState.self) private var game
    let levelID: String
    let onExit: () -> Void
    let onEdit: () -> Void
    @State private var model: CustomLevelModel?

    var body: some View {
        ZStack {
            if let model {
                CustomLevelStage(model: model, onExit: onExit)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            guard model == nil, let level = CustomStore.find(levelID) else { return }
            let made = CustomLevelModel(level: level)
            made.onExit = onExit
            made.onEdit = onEdit
            made.belt.configure(game: game, engine: made.engine)
            made.apply(skills: game.skills)
            made.engine.onDefaultInteract = { [weak made] in made?.talkToBrother() }
            made.engine.start()
            model = made
        }
        .onDisappear { model?.engine.stop() }
    }
}

struct CustomLevelStage: View {
    @Environment(GameState.self) private var game
    let model: CustomLevelModel
    let onExit: () -> Void
    /// Side Level 5: the room is a dream (purple light, floating Zs).
    var dream = false

    var body: some View {
        LevelScaffold(engine: model.engine, title: "\(dream ? "Dream · " : "")\(model.level.name)  ·  keys \(model.inventory.count)/\(model.level.keyCount)",
                      inventory: model.inventory, popup: model.popup, banner: model.banner, belt: model.belt,
                      chase: model.chase, creativeHere: model.level.creative == true, onHome: onExit, onRestart: model.reset, onHint: model.hint) {
            world.allowsHitTesting(false)
        } extra: {
            EmptyView()
        }
    }

    private var engine: GameEngine { model.engine }

    private var world: some View {
        ZStack(alignment: .topLeading) {
            CustomBackdrop(theme: model.level.theme, width: CGFloat(model.level.width))
            ForEach(engine.things.filter { !$0.onFloor }) { thing in
                CustomItemArt(kind: thing.kind, open: model.doorOpen, hiding: model.hidingIn == thing.id)
                    .anchored(at: thing.pos)
            }
            if let mom = model.mom, !model.chase.momOut {
                MomView(stunned: false, walking: false)
                    .overlay(alignment: .top) { Text("Zzz").font(.game(26, .heavy)).foregroundStyle(.white.opacity(0.8)).offset(x: 40, y: -6) }
                    .anchored(at: CGPoint(x: mom.x, y: 590))
            }
            if model.dadHere && !model.chase.active {
                DadView(stunned: false, walking: true, laughing: false)
                    .scaleEffect(x: model.dadRight ? 1 : -1, y: 1)
                    .anchored(at: CGPoint(x: model.dadX, y: model.level.items.first { $0.kind == "dad" }?.y ?? 610))
            }
            ForEach(model.talkers) { who in
                CustomItemArt(kind: who.kind).anchored(at: CGPoint(x: who.x, y: who.y))
            }
            ForEach(model.watchers) { walker in
                PersonView(outfit: walker.kind == .guardian ? .guardian : .worker(walker.style), walking: walker.wait <= 0)
                    .scaleEffect(x: walker.facingRight ? 1 : -1, y: 1)
                    .anchored(at: walker.pos)
            }
            if let talk = model.talkLine {
                SpeechBubble(text: talk.text, tint: .green, small: true).position(x: talk.spot.x, y: talk.spot.y - 200)
            }
            ForEach(model.lasers, id: \.self) { x in
                LaserBeamView(on: model.lasersOn).anchored(at: CGPoint(x: x, y: 700))
            }
            ForEach(model.strangers) { walker in
                Group {
                    if walker.kind == .rat { SpikeTrapView() } else { PersonView(outfit: .stranger(walker.style), walking: true) }
                }
                .scaleEffect(x: walker.facingRight ? 1 : -1, y: 1)
                .anchored(at: walker.pos)
            }
            FloorLayer(engine: engine, look: game.look, name: game.playerName) { thing in
                CustomItemArt(kind: thing.kind, open: thing.open)
            }
            ChaserView(chase: model.chase)
            Palette.shade.opacity(0.2 * Palette.shadeAmount)
            if dream { DreamHaze(width: CGFloat(model.level.width)) }
        }
        .frame(width: CGFloat(model.level.width), height: 700, alignment: .topLeading)
    }
}

/// A pool of lava for the Level Maker. Touching it ends the level at once.
struct LavaPoolView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(red: 0.55, green: 0.10, blue: 0.05)).frame(width: 130, height: 44)
            Ellipse().fill(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)).frame(width: 116, height: 34)
            Circle().fill(.yellow.opacity(0.9)).frame(width: 12).offset(x: -26, y: -4)
            Circle().fill(.yellow.opacity(0.8)).frame(width: 8).offset(x: 22, y: 3)
        }
        .shadow(color: .orange, radius: 12)
        .frame(width: 130, height: 46)
    }
}

/// A laser from ceiling to floor for the Level Maker. It blinks; touching it while it's on ends the level.
struct LaserBeamView: View {
    let on: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color.red.opacity(on ? 0.9 : 0.12)).frame(width: 8, height: 560)
                .shadow(color: .red, radius: on ? 14 : 0)
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.25)).frame(width: 34, height: 16)
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.25)).frame(width: 34, height: 16).offset(y: -556)
        }
        .frame(width: 40, height: 580, alignment: .bottom)
    }
}
