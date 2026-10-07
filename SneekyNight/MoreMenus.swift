import SwiftUI

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
                        group("Time of day") {
                            picker("The game's sky", ["Night", "Early morning", "Real time"], $settings.skyMode)
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
                Text("Extra places off the main path. Each one needs a few things first.")
                    .font(.game(22, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .top, spacing: 24) {
                    card(1, "The Other Hallway", "signpost.right.fill",
                         "The hallway behind your room. Find the 5 keys hidden in the boxes to open the other door. Boosts turn up a little more often here!",
                         game.sideLevelRequirements)
                    card(2, "The Dungeon", "diamond.fill",
                         "Mine glowing orbs and spend them on upgrades (speed goes up to ×5.7!), accessories and demo-only exclusives. It never ends, but the quest board has a quest.",
                         game.dungeonRequirements)
                }
                Spacer()
            }
            .padding(30)
        }
    }

    private func card(_ id: Int, _ name: String, _ symbol: String, _ about: String, _ needs: [(text: String, met: Bool)]) -> some View {
        let open = needs.allSatisfy(\.met)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: open ? symbol : "lock.fill")
                Text("\(id) · \(name)")
                if game.completedSide.contains(id) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.gold)
                }
            }
            .font(.game(30, .heavy))
            .foregroundStyle(.white)
            Text(about)
                .font(.game(19, .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(needs, id: \.text) { need in
                HStack(spacing: 10) {
                    Image(systemName: need.met ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(need.met ? .green : .white.opacity(0.5))
                    Text(need.text)
                }
                .font(.game(20, .semibold))
                .foregroundStyle(.white)
            }
            if open {
                BigButton(title: "Play", symbol: "play.fill") { onPlay(id) }
                    .padding(.top, 8)
            } else {
                Text("Locked: finish the list above.")
                    .font(.game(20))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(width: 500, alignment: .leading)
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
                Text("Tap the wand in a level for the admin panel (45 commands).")
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

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 18) {
                MenuHeader(title: "Multiplayer", onBack: onBack)
                HStack(spacing: 30) {
                    CharacterView(look: game.look, facingRight: true).scaleEffect(1.3).frame(width: 130, height: 210)
                    PlayerTwoSprite(engine: GameEngine(), firstLook: game.look).scaleEffect(1.3).frame(width: 130, height: 240)
                }
                Text("Two players, one \(Device.isPhone ? "iPhone" : "iPad")")
                    .font(.game(30, .heavy))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 10) {
                    line("gamecontroller.fill", "Player 2 gets a small orange joystick and an orange hand button, next to player 1's joystick.")
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
         "Turns up in practice mode with a lantern that never goes out. Now he walks right into the room and says \"Follow me!\", then leads you to the next place you need to go. His hat is said to hold ten and a half times his power."),
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
        ("Level Maker friends", "hammer.fill", .purple,
         "Uncle, a Friend, a friendly Ghost, the Guide, Guards and Workers can only be placed in your own levels. Give each of them their own line."),
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
        ("Orbs", "circle.hexagongrid.fill", .cyan,
         "Mined from glowing rocks in the dungeon and spent at the Orb Shop."),
        ("The golden stick", "questionmark", Palette.gold,
         "Very, very rare. It's on the roof... sometimes."),
        ("The hotel elevator", "arrow.up.arrow.down.square.fill", .orange,
         "Ten floor buttons and no hints. Uncle's room could be on any of them."),
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
        var families: [Accessory.Family] = []
        for item in Accessory.all where !families.contains(item.family) { families.append(item.family) }
        for family in families {
            let kinds = Accessory.all.filter { $0.family == family }
            let owned = kinds.filter { game.accessories.contains($0) }.count
            let names: [Accessory.Family: String] = [
                .glasses: "Glasses", .crown: "Crown", .bowTie: "Bow Ties", .scarf: "Scarves", .cape: "Capes", .headband: "Headbands",
                .catEars: "Cat Ears", .headphones: "Headphones", .halo: "Halo", .partyHat: "Party Hats", .beanie: "Beanies",
                .topHat: "Top Hats", .hairBow: "Hair Bows", .flower: "Flowers",
            ]
            list.append((names[family] ?? family.rawValue, kinds[0].symbol, kinds[0].color == .black ? .white : kinds[0].color,
                         "Accessory. \(kinds.count) colour\(kinds.count == 1 ? "" : "s") to find in boxes and from rats. You have \(owned)."))
        }
        list.append(("Demo exclusives", "sparkles", .cyan,
                     "Six accessories sold only in the dungeon's Orb Shop, 40 orbs each: \(Accessory.exclusives.map(\.name).joined(separator: ", "))."))
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
         "One night every year, the Lantern Festival lights up the city across the river. Grandpa used to take you. This year his knees won't let him travel, so you made him a promise: you'd bring a lantern back for him. Mom and Dad said \"next year\". You decided next year was too far away. The festival ends at sunrise, so you have exactly one night."),
        ("Mom", "heart.fill",
         "Mom has slept lightly ever since you were a baby. One creak and she's awake. She keeps a spare key in her jewelry box because she always loses the first one, and her phone passcode is 12345 because it's the only one she can remember. She isn't angry when she finds you. She's scared you'll get lost. And yes, she really does get up before the sun to cook breakfast."),
        ("Dad", "mustache.fill",
         "Dad is a night owl. He sits up with a cup of cocoa that's always gone cold, and he checks the rooms and the garden because he once left the gate open and the dogs ate every one of his tomatoes. He laughs when you taunt him because he was exactly the same at your age. He just can't say that in front of Mom."),
        ("Your brother", "teddybear.fill",
         "Your little brother can sleep through thunder, but not through silliness. He leaves his toys all over the floor (sorry about the squeaky ones), and the toy he lends you is his favourite thing in the whole world. He wants to come to the festival too. Maybe next year."),
        ("The dog and Uncle", "pawprint.fill",
         "The dog next door isn't a guard dog, he's a snack dog. The blue key on his collar fits a door in your uncle's hotel downtown. Uncle runs the night shift, drives an old car that somehow still works, and has owed you a favour ever since you found his lost glasses. On his head."),
        ("The Guide", "lightbulb.fill",
         "Nobody knows where the Guide came from. He carries a lantern that never goes out. They say he sneaked out himself once, a long time ago, and made it all the way to the festival. Now he turns up whenever a kid needs to practice. He never says how his own story ended."),
    ]

    static let funFacts = [
        "Crouching makes chairs, tables and lamps safe to touch. Loose planks still creak.",
        "Boxes can be searched again and again: every 4th search has a skill paper until you know Dash and Run.",
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

// MARK: - Update log

struct UpdateLogView: View {
    let onBack: () -> Void

    /// Newest first.
    static let updates: [(title: String, notes: [String])] = [
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
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Self.updates.indices, id: \.self) { i in
                            let update = Self.updates[i]
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
