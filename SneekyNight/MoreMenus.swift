import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// The top of every extra menu screen: back button and a big title.
private struct MenuHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            HStack {
                RoundIconButton(symbol: "chevron.left", action: onBack)
                Spacer()
            }
            Text(title)
                .font(.game(52, .heavy))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    let onBack: () -> Void
    @Bindable private var settings = Settings.shared

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 16) {
                MenuHeader(title: "Settings", onBack: onBack)
                ScrollView {
                    VStack(spacing: 14) {
                        group("Sound") {
                            slider("Master volume", "speaker.wave.3.fill", $settings.master)
                            slider("Music volume", "music.note", $settings.music)
                            slider("Sound effects", "bell.fill", $settings.effects)
                        }
                        group("Song") {
                            SongPicker()
                        }
                        group("Time of day") {
                            // Shown in time-of-day order; saved as 0 night, 1 morning, 2 real time, 3 afternoon, 4 sunset.
                            let order = [0, 1, 3, 4, 2]
                            picker("Sky", ["Night", "Morning", "Afternoon", "Sunset", "Real time"], Binding(
                                get: { order.firstIndex(of: settings.skyMode) ?? 0 },
                                set: { settings.skyMode = order[$0] }))
                            if settings.skyMode == 2 {
                                TimeZonePicker()
                            }
                        }
                        group("Buttons") {
                            picker("Joystick and button size", ["Small", "Normal", "Big"], $settings.controlSize)
                            picker("Joystick side", ["Left", "Right"], Binding(
                                get: { settings.swapSides ? 1 : 0 }, set: { settings.swapSides = $0 == 1 }))
                            toggle("Show key letters on buttons (E, Space, R...)", $settings.keyLabels)
                            toggle("Buzz when you press a button", $settings.haptics)
                        }
                        group("Other") {
                            toggle("Show my name above my character", $settings.nameTag)
                            // The ID the Guide's Hat is given to (see `GuidesHat.devices`).
                            Text("Device ID: \(GuidesHat.deviceID)")
                                .font(.game(13, .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(width: 760)
                    .padding(.bottom, 30)
                }
            }
            .padding(30)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.game(26, .heavy))
                .foregroundStyle(Palette.gold)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
    }

    private func slider(_ title: String, _ symbol: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).frame(width: 34)
            Text(title).frame(width: 220, alignment: .leading)
            Slider(value: value, in: 0...1) { editing in
                if !editing { SoundPlayer.shared.tap() }
            }
            .tint(Palette.button)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.game(22, .semibold))
        .foregroundStyle(.white)
    }

    private func picker(_ title: String, _ choices: [String], _ value: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.game(22, .semibold))
                .foregroundStyle(.white)
            Spacer()
            ForEach(choices.indices, id: \.self) { i in
                Button {
                    SoundPlayer.shared.tap()
                    value.wrappedValue = i
                } label: {
                    Text(choices[i])
                        .font(.game(20))
                        .foregroundStyle(value.wrappedValue == i ? .black : .white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(value.wrappedValue == i ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .font(.game(22, .semibold))
            .foregroundStyle(.white)
            .tint(Palette.button)
    }
}

// MARK: - Song

/// Pick one of the game's five songs, or bring your own: a video from the photo gallery (its sound
/// is used) or a song from the Files app.
struct SongPicker: View {
    @Bindable private var settings = Settings.shared
    @State private var videoPick: PhotosPickerItem?
    @State private var filesOpen = false
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(170), spacing: 10), count: 4), alignment: .leading, spacing: 10) {
                ForEach(Song.names.indices, id: \.self) { i in
                    choice(Song.names[i], "music.note", on: settings.song == i) { settings.song = i }
                }
                if Song.ownFile != nil {
                    choice("My own song", "star.fill", on: settings.song == Song.own) { settings.song = Song.own }
                }
            }
            HStack(spacing: 12) {
                PhotosPicker(selection: $videoPick, matching: .videos) {
                    Label("From my gallery", systemImage: "photo.on.rectangle.angled")
                        .font(.game(18)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Palette.button.gradient, in: Capsule())
                }
                Button {
                    SoundPlayer.shared.tap()
                    filesOpen = true
                } label: {
                    Label("From Files", systemImage: "folder.fill")
                        .font(.game(18)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            Text(note.isEmpty ? "A video from your gallery plays its sound. Songs from Files can be MP3, M4A or WAV." : note)
                .font(.game(15, .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .onChange(of: videoPick) { _, item in
            guard let item else { return }
            note = "Loading..."
            Task {
                if let video = try? await item.loadTransferable(type: PickedVideo.self), Song.keepOwn(video.url) {
                    try? FileManager.default.removeItem(at: video.url)
                    useOwnSong()
                } else {
                    note = "That video couldn't be used. Try another one."
                }
                videoPick = nil
            }
        }
        .fileImporter(isPresented: $filesOpen, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            let allowed = url.startAccessingSecurityScopedResource()
            defer { if allowed { url.stopAccessingSecurityScopedResource() } }
            if Song.keepOwn(url) { useOwnSong() } else { note = "That song couldn't be used. Try another one." }
        }
    }

    private func useOwnSong() {
        note = "Playing your own song!"
        if settings.song == Song.own { SoundPlayer.shared.restartMusic() } else { settings.song = Song.own }
    }

    private func choice(_ title: String, _ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.game(17))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(on ? .black : .white)
                .frame(width: 170, height: 44)
                .background(on ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Side levels

struct SideLevelsView: View {
    @Environment(GameState.self) private var game
    let onPlay: (Int) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 20) {
                MenuHeader(title: "Side Levels", onBack: onBack)
                Text("Extra places off the main path. Most of them need a few things first.")
                    .font(.game(22, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                ScrollView {
                    LazyVGrid(columns: [GridItem(.fixed(548), spacing: 16, alignment: .top), GridItem(.fixed(548), spacing: 16, alignment: .top)], spacing: 16) {
                        card(1, "The Other Hallway", "signpost.right.fill",
                             "The hallway behind your room. Find the 5 keys hidden in the boxes to open the other door. Boosts turn up a little more often here!",
                             game.sideLevelRequirements)
                        card(2, "The Shop", "cart.fill",
                             "Ion's shop. Boosting items (Nokia, Phone, Sneaky Cape: 1000 moonlights each), two skills (1569 each), upgrades and accessories. Look at the cases and talk to Ion to finish it. Ion is watching.",
                             [])
                        card(3, "Uncle's Car", "car.fill",
                             "Hop into Uncle's car behind the hotel and ride to the city where Auntie lives. She knows where Grandpa is. Still in the car after 10 minutes? You'll see a little of Level 6.",
                             game.carRequirements)
                        card(5, "Dreams", "moon.zzz.fill",
                             "You fell asleep. Every dream is different: a random room, random keys, hazards and dream people. Find every key and get out of the door to wake up.",
                             game.dreamRequirements)
                        // Only players with the Guide's Hat can even see this one.
                        if game.boosts.contains(.guidesHat) {
                            card(6, "The Room", "wand.and.stars",
                                 "A room only the Guide's Hat can show you. Its vault has a 10-letter code, and no clues anywhere. Guess it right and the golden stick is yours, no rooftop needed.",
                                 [("Own the Guide's Hat", true)])
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                Spacer()
            }
            .padding(30)
        }
    }

    private func card(_ id: Int, _ name: String, _ symbol: String, _ about: String, _ needs: [(text: String, met: Bool)]) -> some View {
        let open = needs.allSatisfy(\.met)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                Image(systemName: open ? symbol : "lock.fill")
                Text("\(id) · \(name)")
                if game.completedSide.contains(id) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.gold)
                }
            }
            .font(.game(25, .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            Text(about)
                .font(.game(17, .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(needs, id: \.text) { need in
                HStack(spacing: 10) {
                    Image(systemName: need.met ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(need.met ? .green : .white.opacity(0.5))
                    Text(need.text)
                }
                .font(.game(17, .semibold))
                .foregroundStyle(.white)
            }
            if open {
                BigButton(title: "Play", symbol: "play.fill") { onPlay(id) }
                    .scaleEffect(0.8, anchor: .leading)
            } else {
                Text("Locked: finish the list above.")
                    .font(.game(20))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
            }
        }
        .padding(18)
        .frame(width: 548, alignment: .leading)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 28))
    }
}

// MARK: - Time zone

/// Shows the time zone the sky follows and lets you pick another one.
struct TimeZonePicker: View {
    @Bindable private var settings = Settings.shared
    @State private var open = false
    @State private var search = ""

    private static let zones = TimeZone.knownTimeZoneIdentifiers.sorted()

    private var clock: String {
        let format = DateFormatter()
        format.timeZone = settings.timeZone
        format.dateFormat = "h:mm a"
        return format.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "globe").font(.system(size: 22, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(settings.timeZoneID.replacingOccurrences(of: "_", with: " "))
                        .font(.game(20))
                    Text("It's \(clock) there, so the sky is: \(Sky.at(hour: settings.localHour).title)")
                        .font(.game(15, .medium))
                        .opacity(0.75)
                }
                Spacer()
                Button {
                    SoundPlayer.shared.tap()
                    open.toggle()
                } label: {
                    Text(open ? "Done" : "Change time zone")
                        .font(.game(18))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Palette.gold, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .foregroundStyle(.white)
            if open {
                TextField("Search (city or region)", text: $search)
                    .font(.game(18))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                let shown = Self.zones.filter {
                    search.isEmpty || $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(search)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        Button("Use this iPad's time zone (\(TimeZone.current.identifier))") { pick(TimeZone.current.identifier) }
                            .font(.game(17))
                            .foregroundStyle(Palette.gold)
                            .padding(.vertical, 5)
                        ForEach(shown, id: \.self) { id in
                            Button {
                                pick(id)
                            } label: {
                                HStack {
                                    Text(id.replacingOccurrences(of: "_", with: " "))
                                    Spacer()
                                    if id == settings.timeZoneID { Image(systemName: "checkmark") }
                                }
                                .font(.game(17, .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func pick(_ id: String) {
        SoundPlayer.shared.tap()
        settings.timeZoneID = id
        open = false
        search = ""
    }
}

// MARK: - Creative mode switch

/// The switch in the corner of the Levels screen. Locked until you've beaten everything.
struct CreativeSwitch: View {
    @Environment(GameState.self) private var game
    @State private var showNeeds = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                SoundPlayer.shared.tap()
                if game.creativeUnlocked { game.creativeOn.toggle() } else { showNeeds.toggle() }
            } label: {
                HStack(spacing: 8) {
                    if game.creativeUnlocked {
                        CreativeCrown().scaleEffect(0.6).frame(width: 30, height: 24)
                    } else {
                        Image(systemName: "lock.fill")
                    }
                    Text(game.creativeUnlocked ? "Creative mode: \(game.creativeOn ? "ON" : "OFF")" : "Creative mode")
                }
                .font(.game(20))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(game.creativeActive ? AnyShapeStyle(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(.black.opacity(0.4)), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 2))
            }
            .buttonStyle(PressableStyle())
            if game.creativeActive {
                Text("Tap the wand in a level for the admin panel (60 commands).")
                    .font(.game(14, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if showNeeds && !game.creativeUnlocked {
                VStack(alignment: .leading, spacing: 6) {
                    Text("To unlock creative mode:")
                        .font(.game(16, .heavy))
                        .foregroundStyle(Palette.gold)
                    ForEach(game.creativeRequirements, id: \.text) { need in
                        HStack(spacing: 8) {
                            Image(systemName: need.met ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(need.met ? .green : .white.opacity(0.5))
                            Text(need.text)
                        }
                        .font(.game(16, .semibold))
                        .foregroundStyle(.white)
                    }
                }
                .padding(14)
                .background(Color(red: 0.10, green: 0.09, blue: 0.24), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.gold.opacity(0.6), lineWidth: 2))
            }
        }
    }
}

// MARK: - Multiplayer

struct MultiplayerView: View {
    @Environment(GameState.self) private var game
    let onBack: () -> Void
    var onCustomize: () -> Void = {}

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 18) {
                MenuHeader(title: "Multiplayer", onBack: onBack)
                HStack(spacing: 30) {
                    CharacterView(look: game.look, facingRight: true).scaleEffect(1.3).frame(width: 130, height: 210)
                    PlayerTwoSprite(engine: GameEngine()).scaleEffect(1.3).frame(width: 130, height: 240)
                }
                MenuButton(title: "Customize player 2", symbol: "tshirt.fill", color: .orange, action: onCustomize)
                Text("Two players, one \(Device.isPhone ? "iPhone" : "iPad")")
                    .font(.game(30, .heavy))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 10) {
                    line("gamecontroller.fill", "Player 1's joystick is on the left of the screen; player 2 gets an orange joystick and hand button on the right.")
                    line("keyboard.fill", "With a keyboard: player 1 uses W A S D, player 2 uses the arrow keys and Return.")
                    line("hand.raised.fill", "Player 2 can search boxes, open drawers and doors, and pick things up for the team.")
                    line("eye.fill", "Mom and Dad chase player 1. Only player 1 can hide, jump and use items.")
                }
                .padding(20)
                .frame(width: 720, alignment: .leading)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
                BigButton(title: game.multiplayer ? "Multiplayer is ON  ·  turn off" : "Turn multiplayer ON",
                          symbol: "person.2.fill", color: game.multiplayer ? .green : Palette.button) {
                    game.multiplayer.toggle()
                }
                Text(game.multiplayer ? "Go back and press Play. Player 2 will be there in every level." : "It switches itself off when you close the game.")
                    .font(.game(18, .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .padding(30)
        }
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 30).foregroundStyle(.orange)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.game(20, .medium))
        .foregroundStyle(.white)
    }
}

// MARK: - Lore

struct LoreView: View {
    @Environment(GameState.self) private var game
    let onBack: () -> Void
    @State private var page = 0
    @State private var category = Category.story

    /// The Lore is split into categories. Items and accessories each have their own.
    enum Category: String, CaseIterable {
        case story = "Story", characters = "Characters", items = "Items", accessories = "Accessories", facts = "Fun facts"

        var symbol: String {
            switch self {
            case .story: "book.fill"
            case .characters: "person.3.fill"
            case .items: "backpack.fill"
            case .accessories: "crown.fill"
            case .facts: "lightbulb.fill"
            }
        }
    }

    typealias Entry = (title: String, symbol: String, color: Color, text: String)

    /// Everyone you meet, in the story levels and in the Level Maker.
    static let characters: [Entry] = [
        ("You", "figure.wave", .yellow,
         "A kid with a promise to keep and a very quiet pair of slippers. You've learned to crouch past lamps, hide in closets and taunt at exactly the wrong moment."),
        ("Mom", "heart.fill", .pink,
         "Sleeps lightly, wakes at one creak, and remembers only one passcode: 12345. In Level 5 she's up before the sun, cooking breakfast. Try to grab her while you're untouchable and she'll swear you're a ghost."),
        ("Dad", "mustache.fill", .blue,
         "A night owl with cold cocoa. He checks Mom's room every 9 to 15 seconds and the garden every two minutes, and laughs once per chase if you taunt him."),
        ("Your brother", "teddybear.fill", .green,
         "Leaves squeaky toys everywhere and lends you his favourite one. If he's following you when Mom catches up, he throws his toy at her. Once."),
        ("The Guide", "lightbulb.fill", GuidesHat.color,
         "Turns up in practice mode with a lantern that never goes out. Now he walks right into the room and says \"Follow me!\", then leads you to the next place you need to go. His hat is said to hold ten and a half times his power. You can give him a new look in Customize, but the hat never comes off."),
        ("Grandpa", "figure.walk.motion", .orange,
         "The reason for everything. His knees won't make the trip to the Lantern Festival this year, so you promised to bring a lantern home for him."),
        ("The snack dog", "pawprint.fill", .brown,
         "The dog next door, with the blue key on his collar. Two snacks and he's your best friend."),
        ("The gate dogs", "dog.fill", .brown,
         "Guard the garden gate in Level 4. They come and go about every 10 seconds and grumble if you stand too close."),
        ("Uncle", "car.fill", .orange,
         "Runs the night shift at the hotel downtown. His room is somewhere upstairs, and it's never on the same floor twice. He'll drive you to the next city... eventually."),
        ("Strangers", "figure.walk", .gray,
         "Wander Level 5's street. Touch one and it's 20 HP. Jump over them or wait in a bus stop."),
        ("Hotel guards and workers", "flashlight.on.fill", .indigo,
         "Guards walk in front of the hotel, workers in the lobby. They only see what's in front of them, and much less far if you crouch."),
        ("Rats", "hare.fill", .gray,
         "Show up while you carry snacks. Each one steals a snack and leaves a present: an accessory, and 1 time in 10 a boost."),
        ("The owl", "bird.fill", .teal,
         "Lives by the chimney on the roof. It winks at you. Nobody knows why."),
        ("Grandma", "house.lodge.fill", .purple,
         "Lives at the end of Uncle's road in a blue house with a garden full of Grandpa's lanterns. Takes five seconds to find her slippers, asks a lot of questions, and gives chores like Auntie does. She knows where Grandpa lives."),
        ("Auntie", "house.fill", .teal,
         "Mom's big sister, in a teal dressing gown with her grey hair in a bun. She knows where Grandpa is, but first: ten chores. She thanks you for her kittens with the hose she's had for thirty years."),
        ("Auntie's cats", "cat.fill", .orange,
         "Ginger and fond of sleeping right where you need to walk. Step on one and Auntie takes time off your clock. On Hard they wake up and wander."),
        ("Ion", "cart.fill", .teal,
         "Runs the Shop (Side Level 2, or the Shop button on the menu). Sells the Nokia, the Phone, the Sneaky Cape, two skills, upgrades and accessories for moonlights. His eyes follow you everywhere, and in the shop window they follow your finger too."),
        ("The robbers", "figure.baseball", .gray,
         "A gang in stripy jumpers and eye masks who ambush Uncle's car in Level 9. They talk the whole time, pull bits off the car, and run away after three bonks of the bat."),
        ("The Friend", "figure.2.arms.open", .green,
         "Only lives in the Level Maker. Sneaking out too, apparently, and always up for a race to the exit."),
        ("The Ghost", "theatermasks.fill", .white,
         "Also only in the Level Maker. Says \"Boooo\", then admits it's friendly, and points you to the keys."),
        ("Level Maker friends", "hammer.fill", .purple,
         "Uncle, the Friend, the Ghost, the Guide, Guards and Workers can be placed in your own levels. Give each of them their own line."),
        ("Auntie's kittens", "cat.fill", .orange,
         "Auntie's newest litter. They slip out of their pen at the first splash of the hose, and they love bushes, sheds and old doghouses."),
        ("Dream people", "moon.zzz.fill", .purple,
         "Faces from your own dreams (Side Level 5). They say strange things, and they're never in the same place twice."),
        ("Player 2", "person.2.fill", .orange,
         "Your partner in sneaking. In multiplayer they have their own look and name (Multiplayer → Customize player 2)."),
    ]

    /// Permanent items, keys and things you pick up.
    static let items: [Entry] = [
        ("Vines (V)", "leaf.arrow.triangle.circlepath", .green,
         "From the strange sparkly bush in the garden maze. Tangles up a grown-up for 10 seconds. Ready again after 35."),
        ("Brother's toy (G)", "teddybear.fill", .pink,
         "Your reward for being nice. Stuns Mom for a whole minute. Ready again after 50 seconds."),
        ("The bat (B)", "figure.baseball", .orange,
         "1 search in 12 finds it. A quick bonk: Mom sees stars for 2 seconds, ready again after 5."),
        ("Lightning Ball power (F)", "bolt.fill", .yellow,
         "25 seconds of speed, dash and jump ×3.5, and quieter steps. 1 minute to recharge."),
        ("Cloud ride (X)", "cloud.fill", Color(red: 0.6, green: 0.8, blue: 1),
         "10 seconds of flying over everything, even the garden hedges. 30 seconds to rest."),
        ("Zoom Slippers and Spring Socks", "shoe.fill", .cyan,
         "In the hallway drawers: faster feet and higher jumps, for the rest of Level 2."),
        ("Silent Slippers", "shoeprints.fill", .purple,
         "Under Mom's bed. One free bump: the next obstacle you touch makes no sound."),
        ("Keys", "key.fill", Palette.gold,
         "Under tables, in lockboxes, on window ledges, made from metal scraps at the workbench, and on a dog's collar. The blue one opens Uncle's door."),
        ("Skill papers", "doc.text.fill", .white,
         "Every 4th box search has one until you know Dash (Q) and Run (Shift)."),
        ("Star balls", "star.circle.fill", .yellow,
         "On the roof. +6% speed each for the rest of Level 3, up to +60%."),
        ("Moonlights", "moon.stars.fill", Color(red: 0.75, green: 0.85, blue: 1),
         "The game's money (they used to be called orbs). Win a level or a side level, again or for the first time, and you get some: more for later levels and harder modes. Spend them in Ion's Shop."),
        ("Car parts", "wrench.and.screwdriver.fill", .orange,
         "The tyre, battery, spark plug, headlight and fan belt the robbers pulled off Uncle's car in Level 9. Pick them up and fit them back at the car."),
        ("Upgrade Items", "wrench.and.screwdriver.fill", Palette.gold,
         "Uncle's thank-you for Level 9: a skill that lets you upgrade boosting items (stronger boosts) and defensive items (longer stuns, shorter waits) in the Shop, up to level 3."),
        ("The golden stick (K)", "wand.and.stars", Palette.gold,
         "Very, very rare. It's on the roof... sometimes. Or behind the vault in The Room, for those with the Guide's Hat and the right 10-letter code. Kept for good, press K once per try: every obstacle in the room is gone, and so are Mom, Dad, strangers, guards, workers, rats, pests, the gate dogs, spikes, lasers and lava, for the rest of the try."),
        ("Drawing paper", "pencil.and.scribble", .white,
         "Next to the toy chest in your brother's room. Grab a sheet and draw whatever you like; the game stops while you draw."),
        ("The hotel elevator", "arrow.up.arrow.down.square.fill", .orange,
         "Ten floor buttons and no hints. Uncle's room could be on any of them."),
        ("Water spray (J)", "drop.fill", Boost.waterHose.color,
         "From Auntie's Water Hose. Spray whoever is chasing you so they can't see for 8 seconds; ready again after 25."),
    ]

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 16) {
                MenuHeader(title: "Lore", onBack: onBack)
                if game.loreUnlocked {
                    HStack(alignment: .top, spacing: 20) {
                        switch category {
                        case .story: storyCard
                        case .facts: factsCard
                        case .characters: entriesCard("Characters", Self.characters)
                        case .items: entriesCard("Items", Self.items)
                        case .accessories: entriesCard("Accessories", accessoryEntries)
                        }
                        VStack(spacing: 10) {
                            ForEach(Category.allCases, id: \.self) { kind in
                                categoryButton(kind)
                            }
                        }
                        .frame(width: 180)
                    }
                } else {
                    locked
                }
                Spacer()
            }
            .padding(30)
        }
    }

    /// Accessories: every boost (with what it does), every kind of accessory, and the demo exclusives.
    private var accessoryEntries: [Entry] {
        var list: [Entry] = Boost.findable.map { boost in
            (boost.name + (game.boosts.contains(boost) ? "  ✓" : ""), boost.symbol, boost.color, "Boost. \(boost.about)")
        }
        list.append(game.boosts.contains(.guidesHat)
            ? (Boost.guidesHat.name + "  ✓", Boost.guidesHat.symbol, Boost.guidesHat.color, "Boost. \(Boost.guidesHat.about) The chance of finding it is exactly zero. Yours was a gift.")
            : ("???", "questionmark", GuidesHat.color, "A boost that can't be found, bought or won. The chance is exactly zero. Only the Guide knows who gets one."))
        list.append((Boost.waterHose.name + (game.boosts.contains(.waterHose) ? "  ✓" : ""), Boost.waterHose.symbol, Boost.waterHose.color,
                     "Boost, only in Level 7: Auntie gives it to you. \(Boost.waterHose.about)"))
        for boost in Boost.shopOnly {
            list.append((boost.name + (game.boosts.contains(boost) ? "  ✓" : ""), boost.symbol, boost.color == Color(white: 0.85) ? .white : boost.color,
                         "Boost from Ion's Shop (\(GameState.shopItemPrice) moonlights). \(boost.about)"))
        }
        var families: [Accessory.Family] = []
        for item in Accessory.all where !families.contains(item.family) { families.append(item.family) }
        for family in families {
            let kinds = Accessory.all.filter { $0.family == family }
            let owned = kinds.filter { game.accessories.contains($0) }.count
            let names: [Accessory.Family: String] = [
                .glasses: "Glasses", .crown: "Crown", .bowTie: "Bow Ties", .scarf: "Scarves", .cape: "Capes", .headband: "Headbands",
                .catEars: "Cat Ears", .headphones: "Headphones", .halo: "Halo", .partyHat: "Party Hats", .beanie: "Beanies",
                .topHat: "Top Hats", .hairBow: "Hair Bows", .flower: "Flowers", .bunnyEars: "Bunny Ears", .wizardHat: "Wizard Hats",
                .bandana: "Bandanas", .monocle: "Monocles", .starClip: "Star Clips", .cowboyHat: "Cowboy Hats",
            ]
            list.append((names[family] ?? family.rawValue, kinds[0].symbol, kinds[0].color == .black ? .white : kinds[0].color,
                         "Accessory. \(kinds.count) colour\(kinds.count == 1 ? "" : "s") to find in boxes and from rats. You have \(owned)."))
        }
        list.append(("Demo exclusives", "sparkles", .cyan,
                     "Six accessories sold only in Ion's Shop, \(ShopPanel.exclusivePrice) moonlights each: \(Accessory.exclusives.map(\.name).joined(separator: ", "))."))
        return list
    }

    private func entriesCard(_ title: String, _ entries: [Entry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.game(34, .heavy))
                    .foregroundStyle(.white)
                ForEach(entries.indices, id: \.self) { i in
                    let entry = entries[i]
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.symbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(entry.color)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title).font(.game(22, .heavy)).foregroundStyle(.white)
                            Text(entry.text)
                                .font(.game(18, .medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                            if let origin = ItemLore.origin(of: entry.title) {
                                Text("Where it came from: \(origin)")
                                    .font(.game(16, .medium))
                                    .italic()
                                    .foregroundStyle(Palette.gold.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
            .padding(26)
        }
        .frame(width: 760, height: 470)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.gold.opacity(0.5), lineWidth: 3))
    }

    private func categoryButton(_ kind: Category) -> some View {
        Button {
            SoundPlayer.shared.tap()
            category = kind
        } label: {
            Label(kind.rawValue, systemImage: kind.symbol)
                .font(.game(19))
                .foregroundStyle(category == kind ? .black : .white)
                .frame(width: 170, height: 52)
                .background(category == kind ? AnyShapeStyle(Palette.gold.gradient) : AnyShapeStyle(.white.opacity(0.14)),
                            in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }

    static let pages: [(title: String, symbol: String, text: String)] = [
        ("Why sneak out?", "moon.stars.fill",
         "One night every year, the Lantern Festival lights up the city across the river. Grandpa always took you. This year he didn't come, and whenever you ask where he is, the grown-ups change the subject. So you made a promise to yourself: find Grandpa, and bring him a lantern. Uncle says Auntie knows where he is, and she lives in the next city. The festival ends at sunrise, so you have exactly one night."),
        ("Mom", "heart.fill",
         "Mom has slept lightly ever since you were a baby. One creak and she's awake. She keeps a spare key in her jewelry box because she always loses the first one, and her phone passcode is 12345 because it's the only one she can remember. She isn't angry when she finds you. She's scared you'll get lost. And yes, she really does get up before the sun to cook breakfast."),
        ("Dad", "mustache.fill",
         "Dad is a night owl. He sits up with a cup of cocoa that's always gone cold, and he checks the rooms and the garden because he once left the gate open and the dogs ate every one of his tomatoes. He laughs when you taunt him because he was exactly the same at your age. He just can't say that in front of Mom."),
        ("Your brother", "teddybear.fill",
         "Your little brother can sleep through thunder, but not through silliness. He leaves his toys all over the floor (sorry about the squeaky ones), and the toy he lends you is his favourite thing in the whole world. He wants to come to the festival too. Maybe next year."),
        ("Grandpa", "figure.walk.motion",
         "Grandpa taught you to whistle, to fold paper lanterns and to walk on the creaky stairs without a sound (on the edges, never the middle). Every year he took you to the Lantern Festival on his shoulders. This year his knees won't make the trip, and nobody wanted to say so. He's waiting somewhere, and he'd love a lantern."),
        ("Grandma", "house.lodge.fill",
         "Grandma lives far out, past the end of Uncle's road, in a house with a garden full of lanterns. She takes five whole seconds to open the door because she has to find her slippers first. She asks a lot of questions. Then she gives you chores, because that's how this family says \"I love you\"."),
        ("The snack dog", "pawprint.fill",
         "The dog next door isn't a guard dog, he's a snack dog. The blue key on his collar fits a door in your uncle's hotel downtown. He'll trade it for two snacks, and by Level 5 he's brought fourteen friends who all want one. Out at Grandma's there's another one, too full to want anything at all."),
        ("Uncle", "car.fill",
         "Uncle runs the night shift at the hotel downtown, drives an old car that somehow still works, and has owed you a favour ever since you found his lost glasses. On his head. His room is never on the same floor twice, and he doesn't always check his back seat."),
        ("Auntie", "house.fill",
         "Mom's big sister. She wears a teal dressing gown, keeps her grey hair in a bun, and can never find her glasses. She knows exactly where Grandpa is, but she's a firm believer in chores first. When you find her kittens she gives you her thirty-year-old garden hose, which is the highest honour she knows."),
        ("Auntie's cats and kittens", "cat.fill",
         "The big ginger cats sleep wherever you most need to walk, and they have very loud opinions about tails. Their kittens escape at the first splash of the hose and hide in bushes, sheds and an old doghouse that says REX on it. Nobody remembers who Rex was."),
        ("The gate dogs", "dog.fill",
         "Two dogs guard Dad's garden gate, mostly by lying in front of it. They wander off every ten seconds or so to sniff something, then wander back. They grumble if you get too close, which is how Dad knows to come and check."),
        ("Strangers", "figure.walk",
         "People out on the street in the middle of the night, hoods up and hands in their pockets. They aren't looking for you. They just don't look where they're going, and bumping into one hurts. They're back out at Grandma's, too."),
        ("Hotel guards and workers", "flashlight.on.fill",
         "The guards sweep their flashlights in front of the hotel, and the workers push trolleys of towels through the lobby and the corridors. They only see what's in front of them, and much less if you crouch. They'll send you back to the start, politely."),
        ("Rats", "hare.fill",
         "The street rats can smell a snack from a whole block away. They always pay for it, though: a shiny button, an accessory, and once in a while something really rare."),
        ("The owl", "bird.fill",
         "Lives by the chimney on your roof. It winks at you. Some say it drops the golden stick now and then, on nights when nobody's looking. The owl isn't saying."),
        ("Ion", "cart.fill",
         "Ion used to keep the striped stall at the mouth of the old dungeon, until the dungeon caved in one night (nobody was hurt; the rocks were mostly sulking). Now he has a proper shop, fairy lights and all, and takes moonlights instead of orbs. He's a teenager, he says, \"in shopkeeper years\". His eyes follow you wherever you go. He says it's good customer service."),
        ("The robbers", "figure.baseball",
         "Nobody knows their real names. One of them is definitely called Gary. They wait on dark country roads for old cars, pull off the shiny bits, and talk far too much while doing it. They are not brave. Three bonks with a bat and they run for it, and they always drop what they took."),
        ("The Friend and the Ghost", "theatermasks.fill",
         "Two characters who only live in the Level Maker. The Friend is sneaking out too and always wants to race you to the exit. The Ghost says \"Boooo\", immediately apologises, and points you to the keys."),
        ("Dream people", "moon.zzz.fill",
         "Faces from your dreams. They say strange things (the clocks are melting, the keys are shy), and they're never in the same place twice. The more dreams you win in a row, the faster your dreams get."),
        ("Player 2", "person.2.fill",
         "Your partner in sneaking, with their own look and name. Two kids are twice as likely to giggle at the wrong moment, but also twice as good at finding keys."),
        ("The Guide", "lightbulb.fill",
         "Nobody knows where the Guide came from. He carries a lantern that never goes out. They say he sneaked out himself once, a long time ago, and made it all the way to the festival. Now he turns up whenever a kid needs to practice. On No Mercy nights he gets things wrong, and he can get hurt, though he never stays hurt for long. He never says how his own story ended."),
    ]

    static let funFacts = [
        "Crouching makes chairs, tables and lamps safe to touch. Loose planks still creak.",
        "Each box can only be searched once. In the hallway, the boxes after the first one hold skill papers until you know Dash and Run.",
        "A search gives an accessory 1 time in 5, a boost 1 time in 15, and the bat 1 time in 12.",
        "If nobody catches you for one minute, they give up. Mom then sleeps for 2 more minutes.",
        "4 chases out of 10, the other grown-up comes over and they talk for a whole minute. That's your chance.",
        "Grown-ups can't catch you while you're in the air. Jump over them!",
        "If they didn't see you hide, they only look in your hiding place half the time.",
        "Dad laughs at one taunt per chase and gives you 10 seconds.",
        "On the roof, taunting makes no noise and each star ball is +6% speed.",
        "In the other hallway, boosts are almost twice as common.",
        "In Level 5, every boost you wear adds 45 HP.",
        "A rat takes one snack but leaves an accessory. Sometimes even a boost.",
        "The Cloud lets you fly over the garden hedges and still water the plants.",
        "Dungeon speed upgrades go up to ×5.7, but the game stops you getting too fast to steer.",
        "Too many boosts on your head? Tap the eye in Customize to hide them. They still work.",
    ]

    private var storyCard: some View {
        let current = Self.pages[page]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: current.symbol).foregroundStyle(Palette.gold)
                Text(current.title)
                Spacer()
                Text("\(page + 1)/\(Self.pages.count)").font(.game(18)).opacity(0.6)
            }
            .font(.game(34, .heavy))
            .foregroundStyle(.white)
            Text(current.text)
                .font(.game(22, .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                pageButton("Back", "chevron.left", page > 0) { page = max(0, page - 1) }
                Spacer()
                pageButton("Next", "chevron.right", page < Self.pages.count - 1) { page = min(Self.pages.count - 1, page + 1) }
            }
        }
        .padding(26)
        .frame(width: 760, height: 470, alignment: .topLeading)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.gold.opacity(0.5), lineWidth: 3))
    }

    private func pageButton(_ title: String, _ symbol: String, _ enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.game(22))
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(Palette.button.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
    }

    private var factsCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fun facts")
                    .font(.game(34, .heavy))
                    .foregroundStyle(.white)
                ForEach(Self.funFacts.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.game(16, .heavy))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(Palette.gold, in: Circle())
                        Text(Self.funFacts[i]).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.game(20, .medium))
                    .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(26)
        }
        .frame(width: 760, height: 470)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.gold.opacity(0.5), lineWidth: 3))
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                Text("The story is locked")
            }
            .font(.game(32, .heavy))
            .foregroundStyle(.white)
            Text("Beat the game to find out why you're sneaking out, and what Mom, Dad, your brother and the Guide are really like.")
                .font(.game(20, .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(game.loreRequirements, id: \.text) { need in
                HStack(spacing: 10) {
                    Image(systemName: need.met ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(need.met ? .green : .white.opacity(0.5))
                    Text(need.text)
                }
                .font(.game(22, .semibold))
                .foregroundStyle(.white)
            }
        }
        .padding(28)
        .frame(width: 640, alignment: .leading)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 28))
    }
}

/// Where every item came from, and how it was made or found. Shown under each entry in the Lore.
enum ItemLore {
    static func origin(of title: String) -> String? {
        let name = title.replacingOccurrences(of: "  ✓", with: "")
        if let boost = Boost.allCases.first(where: { $0.name == name }) { return boost.origin }
        return origins[name]
    }

    static let origins: [String: String] = [
        "Vines (V)": "The strange bush grew from a seed Grandpa brought home from the festival years ago. Nobody ever planted it; it planted itself.",
        "Brother's toy (G)": "A birthday present from Auntie. Its squeaker has been repaired with sticky tape three times.",
        "The bat (B)": "Dad's bat from when he was nine. He hid it in a box so Mom wouldn't find out about the broken window.",
        "Lightning Ball power (F)": "It comes from the marble inside the Lightning Ball, which soaked up a whole thunderstorm on the roof.",
        "Cloud ride (X)": "The cloud remembers being fog over the river, and carries you the way it used to drift.",
        "Zoom Slippers and Spring Socks": "Knitted by Grandma. She always made things a little too fast and a little too bouncy.",
        "Silent Slippers": "Mom bought them so she wouldn't wake YOU when you were a baby. They've been under her bed ever since.",
        "Keys": "Most were cut by the old locksmith on the corner. The ones you make yourself come from metal scraps and Dad's workbench; the blue one was hung on the dog's collar by Uncle so he'd never lose it.",
        "Skill papers": "Pages from Grandpa's old notebook, \"How to Be Quick and Quiet\". Someone tore them out and hid them at the bottom of boxes.",
        "Star balls": "Tiny pieces of shooting stars. They only land on roofs where somebody is awake to catch them.",
        "Moonlights": "Little drops of moonlight that collect wherever a kid finishes something brave. Ion keeps them in a jar on his counter; they used to be called orbs, back when he dug them out of the dungeon rocks.",
        "Car parts": "Uncle's car is older than Grandma's clock. Every part in it has been mended at least twice, mostly with string.",
        "Upgrade Items": "Uncle learned it fixing that car by the roadside for thirty years. \"Tighten, polish, believe,\" he says.",
        "The golden stick (K)": "Nobody made it and nobody has found it twice. Some say the owl drops it. The owl isn't saying.",
        "The hotel elevator": "Built the same year as the hotel. Uncle swears it rearranges the floors when nobody is looking.",
        "Water spray (J)": "Auntie's hose has watered her backyard for thirty years. It sprays harder than it looks.",
        "Drawing paper": "Auntie posts your brother a fresh pad every birthday. He draws on the first page and saves the rest \"for something important\".",
        "Glasses": "Lost and found: every pair was left behind by a visitor and forgotten in a box.",
        "Crown": "Cut from a cereal box for a school play. It was never returned.",
        "Bow Ties": "Dad wore one to every wedding he ever went to. He has been to a lot of weddings.",
        "Scarves": "Grandma's knitting again. She never made two the same colour.",
        "Capes": "Old curtains, cut down and hemmed by Mom for superhero days.",
        "Headbands": "Sweatbands from Mom's running club. Tie one on and you feel like a ninja.",
        "Cat Ears": "From a costume party three years ago. The cat costume itself has never been seen again.",
        "Headphones": "Uncle's old pair from the hotel's lost property. One side is a tiny bit louder.",
        "Halo": "A bent lampshade ring that somehow still glows a little.",
        "Party Hats": "Left over from birthdays. Each one still has a bit of cake on the elastic.",
        "Beanies": "Winter hats that the rats have borrowed and, for once, given back.",
        "Top Hats": "From the hotel's magic-show night. No rabbit has come out of any of them. Yet.",
        "Hair Bows": "Ribbons saved from every present Auntie ever sent.",
        "Flowers": "Picked from the garden maze. They stay fresh as long as the plants get watered.",
        "Demo exclusives": "Made by Ion out of moonlight dust. They only exist while the game is a demo.",
        "Bunny Ears": "From the school play where every child was a rabbit. They still twitch a little.",
        "Wizard Hats": "Ion sews them from his old shop curtains. The stars are real; the magic isn't. Probably.",
        "Bandanas": "Uncle keeps a drawer of them in the car for windy days with the windows down.",
        "Monocles": "Grandpa's reading lens, and a few copies Ion had made. Wear one and you feel very important.",
        "Star Clips": "They fell off the cinema's star curtain, one by one, over many years.",
        "Cowboy Hats": "From the hotel's Wild West week. The hotel would like them back.",
    ]
}

// MARK: - Update log

struct UpdateLogView: View {
    let onBack: () -> Void
    /// Nil shows everything; otherwise only the notes in one of `categories`.
    @State private var category: String?

    static let categories = ["Levels", "Characters", "Items", "Modes & menus", "Fixes"]

    /// Which category a note belongs to, from the words in it.
    static func category(of note: String) -> String {
        let text = note.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["fixed", "fix ", "smoother", "slightly smaller"]) { return "Fixes" }
        if has(["boost", "item", "accessor", "bat", "vines", "orb", "hat", "hose", "toy", "slippers"]) { return "Items" }
        if has(["level", "room", "hotel", "maze", "dungeon", "cinema", "roof", "garden", "backyard", "dream"]) { return "Levels" }
        if has(["hair", "customize", "character", "mom", "dad", "brother", "guide", "face", "t-shirt", "auntie", "uncle", "player 2"]) { return "Characters" }
        return "Modes & menus"
    }

    /// Newest first.
    static let updates: [(title: String, notes: [String])] = [
        ("Sneeky Nights: Level badges and dream names", [
            "New badges: Level 5, 6, 7, 8, 9 and 10, one for winning each level. Levels you already won count straight away. Levels 8 to 10 say \"soon\" until they're out.",
            "Smoother play: the clock, noise meter and buttons only redraw when they change, so moving around takes much less work every frame.",
            "Friendlier faces: softer, rounder eyes with a shine, gentler eyebrows, and a scared face gets a little drop of sweat instead of a scream. Mom, Dad, Auntie, Uncle, the strangers and the Ghost got friendlier faces too.",
            "Fixed Ion's scary eyes: they're big and warm with a shine now, instead of a small pupil staring out of a lot of white. They still follow you around the shop.",
            "Fixed your arms: they hang on the side you're facing, so your hand goes where you go instead of sitting on your tummy. You also only turn left or right when you're really going sideways.",
            "Every dream has a name made of random words, like \"Floating Moon\" or \"Crooked Melting Kitchen\" (a 50/50 chance of an extra word), and its wallpaper, sky, moons and floor are made up by a randomizer.",
            "Fixed the weird crouch: it's a real squat now, knees in front and both feet flat on the floor.",
        ]),
        ("Sneeky Nights: Raid", [
            "Level 9: Raid. Uncle slams on the brakes and a gang of robbers jumps out. Bonk them with the bat (three bonks each, and they talk the whole time), pick up the car parts they pulled off, and fit them back at the car.",
            "Win Level 9 and Uncle teaches you the Upgrade Items skill: upgrade your boosting and defensive items in the Shop, up to level 3.",
            "In Level 9 with practice mode on, the Guide fights the robbers with you.",
            "New side level: The Shop, run by Ion. His eyes follow you around the shop, and your finger or pointer in the shop window.",
            "The Shop is on the main menu too.",
            "Ion sells three boosting items for 1000 moonlights each: the Nokia (health ×2), the Phone (press O: notes you can type in, plus Snake, Memory and Moon Catch) and the Sneaky Cape (no noise at all, and every stat ×1.2).",
            "Ion also sells two new skills for 1569 moonlights each: Double Jump (Space again in the air) and Slide (press C while running).",
            "Orbs are now called moonlights. You earn them every time you win a level or a side level, even ones you've won before; harder modes pay more.",
            "The dungeon is gone. Its upgrades, mystery accessories and demo exclusives are in Ion's Shop now.",
            "Everyone faces north, south, east and west now: your character follows the joystick (you see their back walking up the room and their face walking down), and Mom, Dad, your brother, the Guide and the robbers face the way they walk.",
            "Customize: 60 new colours for tops, trousers, shoes, hair, caps and eyes, and your own colour for any of them (and your skin) from the colour wheel.",
            "80 new accessories: the missing colours of the first ten kinds, plus bunny ears, wizard hats, bandanas, monocles, star clips and cowboy hats.",
            "The cinema (Side Level 4) has been removed.",
            "Level Maker: toy cars, spikes, strangers, guards, workers and Dad now show their path, and you can change how far they walk each way (or make them stand still).",
        ]),
        ("Sneeky Nights: Somewhere", [
            "Level 8: Somewhere. 50 seconds in Uncle's car, then Grandma's garden: tidy it, find all 20 lanterns and the blue key. Grandma takes a moment to open the door and asks a few questions, then it's chores. Afterwards, chase Uncle's car down the road until he checks his mirror.",
            "Each box can only be searched once now.",
            "Lasers are a beam at chest height: crouch under them. Touching one takes half your health instead of ending the level.",
            "Lava looks like lava now, not a portal.",
            "Level Maker: make your own hazards (draw one or pick a sample, then set its hitbox and damage), and your own map (colours, wallpaper, floor and a drawing on the wall).",
            "Chaos mode: Mom and Dad move at 75% of your speed.",
            "No Mercy: more damage, water puddles in Levels 2 and 3 (they slow you down and wake Mom), the Guide really gets things wrong and can get hurt, and practice mode stays locked until you win the level.",
            "Modes unlock one level at a time: win a level on Mild to open Hard, Hard to open Chaos, and Chaos (plus 1000 orbs and 35 badges) to open No Mercy. Side levels are open on every mode.",
            "More to customize: trousers, shorts or a skirt; slippers, sneakers or boots; and five new pictures for your top.",
            "Settings: the sky can be Afternoon or Sunset now, and Real time shows the afternoon too.",
            "A less squashed crouch, and lots of small polish.",
            "The Lore's story has a page for every character.",
        ]),
        ("Sneeky Nights: The Room", [
            "New side level for Guide's Hat owners only: The Room. Its vault has a 10-letter code and no clues. Guess it and the golden stick is yours, no rooftop needed.",
            "The golden stick is kept for good: press K once per try in any level. Every obstacle in the room vanishes, and so do Mom, Dad and every other grown-up, plus strangers, guards, workers, rats, pests, the gate dogs, spikes, lasers and lava. In Level 3 it clears the whole house.",
            "Dreams have a streak: every dream you beat in a row counts, and each one after that is 1.01× harder (a shorter clock, more hazards, faster everything). Lose one or leave it unfinished and the streak starts again. Your best streak is kept.",
            "Creative mode has 5 new commands (60 in all): Golden stick, Bring everyone back, Go to the next goal, Hide right here, and Disco.",
            "Everyone has expressions now, like you: Mom, Dad, Auntie, Uncle, your brother, the Guide, strangers, guards and workers. Cross when they chase you, sneaky when they search, surprised, happy, sleepy...",
            "Customize the Guide: give him a new look (in Customize Character). His hat stays on.",
            "Every character is in the Lore now, including Auntie, her cats, the Orb Shop keeper, the Friend and the Ghost.",
            "New badge: \"how did we get here\". Complete the whole game: every level, and Side Levels 1 to 5.",
        ]),
        ("Sneeky Nights: Auntie's backyard", [
            "Level 7: Auntie's Backyard. The first level with an entry fee: 32 badges, and 10 orbs paid at the gate. Wash the mud off the yard with the hose, then find every missing kitten.",
            "Auntie thanks you with a new boost only she gives: the Water Hose. Press J to spray whoever is chasing you so they can't see. In Level 4 it waters five plants at once.",
            "Then Auntie walks you to Uncle's car, in a short scene.",
            "New side level: Dreams. Every dream is random: a new room, keys, hazards and dream people each time. Win every level to open it.",
            "Customize Character has categories now (Body, Hair, Clothes, Accessories, Boosts, Extras) and lots more to pick: eye colour, trousers, shoes, hoodies, stripes and jackets, freckles, rosy cheeks and your usual face.",
            "Put your own picture on your T-shirt: pick a photo from your gallery.",
            "Characters show how they feel: worried when someone is looking for you, scared when they're close, surprised in the air, sneaky when crouching.",
            "Characters are more alive: they breathe, sway, glance around and bob as they walk. Mom, Dad and Auntie too.",
            "A slightly more grown-up look: cleaner lettering, eyebrows and shinier eyes.",
            "Five songs to choose from in Settings, or your own: a video from your gallery or a song from Files.",
            "The house on the menu matches the sky: dark at night, warm at sunrise and sunset, bright in the day.",
            "With Real time on, the sun really rises in the early morning and sets in the evening, moving slowly across the menu sky with the clock. The moon crosses at night.",
            "Multiplayer: customize player 2 (their own look and name), and the two joysticks are on opposite sides of the screen.",
            "The Badges screen and this Update Log have categories along the top.",
            "Two new badges: Cat whisperer and Sweet dreams.",
        ]),
        ("The cinema", [
            "New side level: The Cinema. Pick one of 10 shows and pick your seat.",
            "Every show is one hour long. If you leave, your place is kept for next time.",
            "Each show now tells one whole story in 8 parts. Every part is different: nothing repeats.",
            "Each time you watch a show to the end you get 1000 orbs.",
            "The films are more alive: the cast walks to new spots, hops, crouches, taunts and looks around on every line, the camera moves in close and back out, and the sets move too (rising lanterns, rolling toys, steam, glowing orbs).",
            "Cinema sounds and music: a lobby tune, four kinds of film music, the projector starting, seats, tickets, popcorn, a chime for each new part, and applause at the end.",
        ]),
        ("Biggest update", [
            "Five difficulty modes: Easy, Mild, Hard, Chaos and No Mercy. Pick one under the Play button. Mild is the game as it was.",
            "Easy: slower hazards, a longer clock, quieter steps, you're faster, 3-number codes, fewer dogs and keys, and Mom can't check hiding places.",
            "Hard: faster hazards that hurt more, a shorter clock, 50 dogs and 20 hotel floors.",
            "Chaos: Mom and Dad are as fast as you, hiding never works, and hotel workers check hiding places.",
            "No Mercy: a very short clock, Mom outruns you, boxes can be traps, strangers come after you, and the Guide gets things wrong.",
            "Harder modes find boosts more often and get more orbs in the dungeon.",
            "Level 6: Auntie's House. Do Auntie's 10 chores, then follow her to the backyard door. Mind the cats!",
            "20 hair styles, hair colours, and \"My own\": make your own haircut with six sliders.",
            "The Guide explains every step and which button to press, and walks at your speed.",
            "Press dash again in the middle of a dash to stop it.",
            "Level Maker: two instant-fail hazards, lava and a blinking laser.",
        ]),
        ("Uncle's car and cool things", [
            "New side level: Uncle's car. Hop in behind the hotel and ride to Auntie's city. Stay for the whole 10 minutes and you'll see scenes from Level 6: Auntie's House.",
            "Have a real conversation with your brother: pick \"Let's talk\" and choose what to talk about.",
            "Hair styles! Eight of them, in Customize Character.",
            "Every item in the Lore now says where it came from and how it was made or found.",
            "The roof is much bigger. Walk to either edge to look down at the street and the garden.",
            "Grab drawing paper next to your brother's toy chest and draw.",
        ]),
        ("Sneeky Nights: better performance and more fun", [
            "The game runs smoother: less work every frame when drawing rooms and checking what's next to you.",
            "The Level Maker has no limits now: as many objects and hazards as you like, and levels as long as you like.",
            "Creative mode: status commands stack (press Speed ×2 three times for ×8), and there are 10 new commands (55 in all).",
            "Creative mode gives you immortality and the untouchable buff. Mom gets very confused when she can't grab you... and sometimes thinks you're a ghost!",
            "The Lore has grown: every character, plus Items and Accessories in their own categories.",
            "Uncle's hotel: the first floor is now the lobby. Take the elevator (10 floors) to find Uncle's room. It's somewhere different every try, and there are no hints... except from the Guide in practice mode.",
            "Level Maker only characters: Uncle, a Friend, a friendly Ghost, the Guide, Guards and Workers. And creative mode works on your own levels (switch it on in the editor).",
            "A new boosting accessory: the Guide's Hat. Press H to switch it on or off: everything ×10.5, and you walk through things. The chance of finding it is exactly zero.",
            "In practice mode the Guide walks with you: \"Follow me!\" He leads you to the right place.",
            "Fixed the crouch animation: your feet stay on the floor and the legs don't flicker any more.",
        ]),
        ("Level 5 update", [
            "Level 5: The Street. Feed 15 dogs, dodge strangers (you have HP now!), trade with rats, and reach Uncle's hotel.",
            "New side level: The Dungeon. Mine orbs, buy upgrades (speed up to ×5.7), accessories and demo exclusives.",
            "Pause button in every level, with settings and Practice mode: meet the Guide, and nobody can catch you.",
            "Multiplayer mode: two players on one screen.",
            "Level Maker: build your own levels with up to 100 objects and 20 hazards. Add Mom, Dad and your brother, with your own words for them.",
            "Mom and Dad sometimes meet and talk about the noisy house for a minute. They talk to your brother too, and mutter while they search.",
            "The sky can follow the real time in your time zone (Settings).",
            "New boost: Cloud. Fly for 10 seconds (30 second cooldown). It flies over the garden maze too.",
            "Every boost you wear gives +45 HP in Level 5.",
            "New badge: the world revolving. The multiplayer badge can be earned now.",
            "Lore (beat everything + 30 badges) and Creative mode with a 45-command admin panel (beat everything + 33 badges).",
            "Fixed: tapping a pop-up's button many times gave you the item more than once.",
            "Prettier speech bubbles, livelier crouching, fireflies, shooting stars and shinier buttons. Footsteps are a bit louder.",
        ]),
        ("Invisible boosts", [
            "Too messy? In Customize Character, tap the eye next to a boost to make it invisible. It still works! You pick which ones.",
        ]),
        ("Minor update and some balancing", [
            "Mom and Dad no longer pop up next to you: they come out of their room and look for you. Outrun them, hide, or stun them!",
            "If nobody catches you for one minute they give up. Mom then sleeps for two more minutes.",
            "Bigger joystick and buttons, and no more waiting after a jump, taunt or dash.",
            "Dash in any direction: point the joystick, then dash.",
            "Characters blink. Mom and Dad have hands. New crouch-walk pose.",
            "Slightly smaller hitboxes.",
            "New permanent item: the bat (hiding in a box). Bonk Mom for 2 seconds, ready again after 5.",
            "The gate dogs in Level 4 grumble if you stand too close.",
            "New: Settings, this Update Log, and Side Levels.",
            "Side Level 1: the other hallway.",
            "New badges: Just in case, Im unstoppable!",
        ]),
        ("Family photos", ["The pictures on the walls are now solo, pet and family photos."]),
        ("New save slot files", [
            "Make as many save files as you like.",
            "Level 4 pests stop when every plant is watered, or while Dad is checking.",
            "Roof boosts fall about once a minute, and the timer waits while you're on the roof.",
            "New boost: arrow (dash x1.9, walk x1.2).",
            "Some missing pictures fixed.",
        ]),
        ("iPhone version", ["Plays on iPhone with small see-through controls at the bottom of the screen."]),
        ("Badge chaos and a big update", [
            "Level 4: The Garden, with a hedge maze.",
            "25 badges, 50 new accessories, 5 boosts, vines, the toy reward and Custom Sounds.",
        ]),
        ("Small update", [
            "Smaller hitboxes, three new badges, Mom calls your name on the roof.",
            "A brother who follows you throws his toy at Mom.",
        ]),
        ("Huge update", [
            "Level 3: Downstairs, and the roof sub-level up the ladder.",
            "Jump over boxes, 10 accessories in boxes, 10 badges, surprises on the window ledge.",
            "Your brother wakes up if you taunt, and can follow you.",
        ]),
        ("Major update", [
            "Win levels in order. Mom's room, with Dad checking in.",
            "Crouch, taunt, skill papers (dash and run) and Customize Character.",
        ]),
        ("Sneeky Nights", [
            "Keyboard keys, a timer on every level, sounds and a joystick.",
            "Level 2: The Hallway.",
        ]),
        ("First version", ["Sneeky Night begins! Pick a boy or girl, type a name, and escape Level 1: the Bedroom."]),
    ]

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 16) {
                MenuHeader(title: "Update Log", onBack: onBack)
                CategoryBar(choices: Self.categories, picked: $category)
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Self.updates.indices.filter { i in category == nil || Self.updates[i].notes.contains { Self.category(of: $0) == category } }, id: \.self) { i in
                            let update = (title: Self.updates[i].title, notes: Self.updates[i].notes.filter { category == nil || Self.category(of: $0) == category })
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(update.title)
                                        .font(.game(26, .heavy))
                                        .foregroundStyle(Palette.gold)
                                    if i == 0 {
                                        Text("NEW")
                                            .font(.game(16, .heavy))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 3)
                                            .background(.red, in: Capsule())
                                    }
                                }
                                ForEach(update.notes, id: \.self) { note in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("•")
                                        Text(note).fixedSize(horizontal: false, vertical: true)
                                    }
                                    .font(.game(20, .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .frame(width: 760)
                    .padding(.bottom, 30)
                }
            }
            .padding(30)
        }
    }
}
