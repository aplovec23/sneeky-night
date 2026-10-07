import SwiftUI

// MARK: - Main menu

struct TitleView: View {
    @Environment(GameState.self) private var game
    let onPlay: () -> Void
    let onLevels: () -> Void
    let onCustomize: () -> Void
    let onBadges: () -> Void
    var onSaves: () -> Void = {}
    var onSideLevels: () -> Void = {}
    var onSettings: () -> Void = {}
    var onUpdateLog: () -> Void = {}
    var onMultiplayer: () -> Void = {}
    var onMaker: () -> Void = {}
    var onLore: () -> Void = {}
    @State private var bob = false

    private var playTitle: String {
        guard game.hasCharacter else { return "Play" }
        if let next = game.nextLevel { return next == 1 && game.completedLevels.isEmpty ? "Play" : "Continue · Level \(next)" }
        return "Play Again"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                NightSky()
                Circle()
                    .fill(Palette.moon)
                    .frame(width: 150, height: 150)
                    .shadow(color: Palette.moon.opacity(0.7), radius: 40)
                    .position(x: geo.size.width * 0.40, y: 115)
                // Rolling hill with the house
                Ellipse()
                    .fill(Color(red: 0.10, green: 0.22, blue: 0.20))
                    .frame(width: geo.size.width * 1.4, height: 360)
                    .position(x: geo.size.width * 0.3, y: geo.size.height + 70)
                HouseView()
                    .position(x: geo.size.width * 0.24, y: geo.size.height - 230)
                Group {
                    if game.hasCharacter {
                        CharacterView(look: game.look, facingRight: true)
                    } else {
                        HStack(spacing: 20) {
                            CharacterView(gender: .boy, facingRight: true)
                            CharacterView(gender: .girl, facingRight: false)
                        }
                    }
                }
                .scaleEffect(1.2)
                .offset(y: bob ? -5 : 5)
                .position(x: geo.size.width * 0.42, y: geo.size.height - 150)

                VStack(spacing: 11) {
                    Text("Sneeky Night")
                        .font(.game(88, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                        .shadow(color: .purple, radius: 0, x: 4, y: 5)
                        .shadow(color: Palette.moon.opacity(0.4), radius: 20)
                    Text("Solve the puzzles. Sneak out of every room.")
                        .font(.game(24, .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 8)
                    MenuButton(title: playTitle, symbol: "play.fill", color: Palette.button, big: true, action: onPlay)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(140), spacing: 10), count: 3), spacing: 10) {
                        MenuTile(title: "Levels", symbol: "map.fill", color: Color(red: 0.35, green: 0.30, blue: 0.70), action: onLevels)
                        MenuTile(title: "Side Levels", symbol: "signpost.right.fill", color: Color(red: 0.20, green: 0.45, blue: 0.45), action: onSideLevels)
                        MenuTile(title: "Multiplayer", symbol: "person.2.fill", color: Color(red: 0.80, green: 0.45, blue: 0.15),
                                 badge: game.multiplayer ? "ON" : nil, action: onMultiplayer)
                        MenuTile(title: "Customize", symbol: "tshirt.fill", color: Color(red: 0.20, green: 0.55, blue: 0.60), action: onCustomize)
                        MenuTile(title: "Badges \(game.badges.count)/\(Badge.allCases.count)", symbol: "rosette",
                                 color: Color(red: 0.70, green: 0.40, blue: 0.20), action: onBadges)
                        MenuTile(title: "Level Maker", symbol: "hammer.fill", color: Color(red: 0.55, green: 0.35, blue: 0.20), action: onMaker)
                        MenuTile(title: "Save Files", symbol: "folder.fill", color: Color(red: 0.30, green: 0.45, blue: 0.30), action: onSaves)
                        MenuTile(title: "Settings", symbol: "gearshape.fill", color: Color(red: 0.40, green: 0.42, blue: 0.50), action: onSettings)
                        MenuTile(title: "Lore", symbol: game.loreUnlocked ? "book.fill" : "lock.fill", color: Color(red: 0.50, green: 0.22, blue: 0.35),
                                 action: onLore)
                    }
                    MenuButton(title: "Update Log", symbol: "newspaper.fill", color: Color(red: 0.55, green: 0.30, blue: 0.55), action: onUpdateLog)
                    if game.hasCharacter {
                        Text("Playing as \(game.playerName)")
                            .font(.game(20, .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 6)
                    }
                }
                .frame(width: min(620, geo.size.width * 0.5))
                .position(x: geo.size.width * 0.72, y: geo.size.height * 0.52)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever()) { bob = true }
        }
        // "boredom" badge: 10 minutes on the menu without leaving it.
        .task {
            try? await Task.sleep(for: .seconds(600))
            if !Task.isCancelled { game.award(.boredom) }
        }
    }
}

struct MenuButton: View {
    let title: String
    let symbol: String
    let color: Color
    var big = false
    let action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .frame(width: 36)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.game(20))
                    .opacity(0.6)
            }
            .font(.game(big ? 34 : 26))
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(width: 440, height: big ? 80 : 60)
            .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
        }
        .buttonStyle(PressableStyle())
    }
}

/// A small square-ish menu button, three to a row.
struct MenuTile: View {
    let title: String
    let symbol: String
    let color: Color
    /// A little tag in the corner, e.g. "ON".
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button {
            SoundPlayer.shared.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .bold))
                Text(title)
                    .font(.game(17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(width: 140, height: 70)
            .background(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.game(12, .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Palette.gold, in: Capsule())
                        .offset(x: 4, y: -6)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

/// The family's house at night, one window lit.
struct HouseView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(red: 0.16, green: 0.13, blue: 0.26)).frame(width: 300, height: 200)
            Triangle().fill(Color(red: 0.24, green: 0.14, blue: 0.24)).frame(width: 360, height: 140).offset(y: -195)
            Rectangle().fill(Color(red: 0.22, green: 0.16, blue: 0.30)).frame(width: 36, height: 70).offset(x: 90, y: -250)
            HStack(spacing: 60) {
                window(lit: true)
                window(lit: false)
            }
            .offset(y: -110)
            HStack(spacing: 60) {
                window(lit: false)
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.35, green: 0.22, blue: 0.15)).frame(width: 54, height: 90)
            }
        }
        .frame(width: 380, height: 360, alignment: .bottom)
    }

    private func window(lit: Bool) -> some View {
        ZStack {
            Rectangle().fill(lit ? Color(red: 1, green: 0.85, blue: 0.45) : Color(red: 0.08, green: 0.08, blue: 0.18))
            Rectangle().fill(Color(red: 0.16, green: 0.13, blue: 0.26)).frame(width: 4)
            Rectangle().fill(Color(red: 0.16, green: 0.13, blue: 0.26)).frame(height: 4)
        }
        .frame(width: 60, height: 54)
        .shadow(color: lit ? .yellow.opacity(0.7) : .clear, radius: 16)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Customize character

struct CustomizeView: View {
    @Environment(GameState.self) private var game
    let onDone: () -> Void
    let onBack: () -> Void
    var onSounds: () -> Void = {}

    @State private var look = Look.starter(.boy)
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            NightSky()
                .onTapGesture { nameFocused = false }
            HStack(spacing: 40) {
                // Live preview
                VStack(spacing: 16) {
                    Text(trimmedName.isEmpty ? "Your character" : trimmedName)
                        .font(.game(34, .heavy))
                        .foregroundStyle(.white)
                    ZStack(alignment: .bottom) {
                        Ellipse().fill(.white.opacity(0.15)).frame(width: 220, height: 50).offset(y: 20)
                        CharacterView(look: look, facingRight: true, walking: false)
                            .scaleEffect(2.1, anchor: .bottom)
                    }
                    .frame(width: 300, height: 380, alignment: .bottom)
                }
                .frame(width: 340)

                // Choices
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Customize Character")
                            .font(.game(44, .heavy))
                            .foregroundStyle(.white)
                        section("Name") {
                            TextField("Type a name", text: $name)
                                .focused($nameFocused)
                                .font(.game(30))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .frame(width: 360)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                                .onChange(of: name) { _, new in
                                    if new.count > 12 { name = String(new.prefix(12)) }
                                }
                        }
                        section("Boy or girl") {
                            HStack(spacing: 14) {
                                ForEach(Gender.allCases, id: \.self) { g in
                                    chip(g == .boy ? "Boy" : "Girl", selected: look.gender == g) { look.gender = g }
                                }
                            }
                        }
                        section("Skin tone") {
                            HStack(spacing: 12) {
                                ForEach(LookOptions.skins.indices, id: \.self) { i in
                                    swatch(LookOptions.skins[i], selected: look.skin == i) { look.skin = i }
                                }
                            }
                        }
                        section("T-shirt") {
                            HStack(spacing: 12) {
                                ForEach((game.extraColors ? LookOptions.allShirts : LookOptions.shirts).indices, id: \.self) { i in
                                    swatch(LookOptions.allShirts[i], selected: look.shirt == i) { look.shirt = i }
                                }
                            }
                        }
                        section("T-shirt picture") {
                            HStack(spacing: 12) {
                                ForEach(LookOptions.patterns.indices, id: \.self) { i in
                                    iconChoice(LookOptions.patterns[i] ?? "circle.slash", selected: look.pattern == i) { look.pattern = i }
                                }
                            }
                        }
                        section("Cap") {
                            HStack(spacing: 12) {
                                ForEach((game.extraColors ? LookOptions.allCaps : LookOptions.caps).indices, id: \.self) { i in
                                    if let color = LookOptions.allCaps[i] {
                                        swatch(color, selected: look.cap == i) { look.cap = i }
                                    } else {
                                        iconChoice("circle.slash", selected: look.cap == 0) { look.cap = 0 }
                                    }
                                }
                            }
                        }
                        section("Accessories (find them in boxes!)  \(game.regularAccessories)/\(Accessory.all.count)") {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 12), count: 8), alignment: .leading, spacing: 12) {
                                iconChoice("circle.slash", selected: look.accessory == nil) { look.accessory = nil }
                                ForEach(Accessory.all) { item in
                                    if game.accessories.contains(item) {
                                        iconChoice(item.symbol, selected: look.accessory == item, tint: item.color) { look.accessory = item }
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.35))
                                            .frame(width: 50, height: 50)
                                            .background(.white.opacity(0.05), in: Circle())
                                    }
                                }
                            }
                        }
                        if !game.accessories.isDisjoint(with: Accessory.exclusives) {
                            section("Demo exclusives (from the dungeon's orb shop)") {
                                HStack(spacing: 12) {
                                    ForEach(Accessory.exclusives.filter { game.accessories.contains($0) }) { item in
                                        iconChoice(item.symbol, selected: look.accessory == item, tint: item.color) { look.accessory = item }
                                    }
                                }
                            }
                        }
                        section("Boosts (very rare! They all stack. Tap the eye to hide one)  \(game.boosts.intersection(Boost.findable).count)/\(Boost.findable.count)") {
                            VStack(alignment: .leading, spacing: 10) {
                                // The Guide's Hat only shows up on a device that was given it.
                                ForEach(Boost.findable + (game.boosts.contains(.guidesHat) ? [Boost.guidesHat] : [])) { boost in
                                    boostRow(boost)
                                }
                            }
                        }
                        MenuButton(title: "Custom Sounds", symbol: "speaker.wave.2.fill", color: Color(red: 0.45, green: 0.30, blue: 0.65)) {
                            // Keep what's been picked so far before leaving this screen.
                            if !trimmedName.isEmpty {
                                game.look = look
                                game.playerName = trimmedName
                                game.hasCharacter = true
                            }
                            onSounds()
                        }
                        BigButton(title: "Done", symbol: "checkmark", action: save)
                            .opacity(trimmedName.isEmpty ? 0.4 : 1)
                            .disabled(trimmedName.isEmpty)
                            .padding(.top, 6)
                        if trimmedName.isEmpty {
                            Text("Type a name to finish.")
                                .font(.game(18, .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 30)
                }
                .scrollIndicators(.hidden)
                .frame(width: 560)
            }

            VStack {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onBack)
                    Spacer()
                }
                Spacer()
            }
            .padding(30)
        }
        .animation(.spring(duration: 0.3), value: look)
        .onAppear {
            look = game.look
            name = game.playerName
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        game.look = look
        game.playerName = trimmedName
        game.hasCharacter = true
        game.checkName()
        onDone()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.game(22, .semibold))
                .foregroundStyle(.white.opacity(0.85))
            content()
        }
    }

    private func pick(_ action: @escaping () -> Void) -> () -> Void {
        {
            SoundPlayer.shared.tap()
            action()
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: pick(action)) {
            Text(title)
                .font(.game(24))
                .foregroundStyle(.white)
                .frame(width: 120, height: 52)
                .background(.white.opacity(selected ? 0.3 : 0.08), in: Capsule())
                .overlay(Capsule().stroke(selected ? Palette.gold : .white.opacity(0.2), lineWidth: selected ? 4 : 2))
        }
        .buttonStyle(PressableStyle())
    }

    private func swatch(_ color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: pick(action)) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(selected ? Palette.gold : .white.opacity(0.3), lineWidth: selected ? 5 : 2))
                .scaleEffect(selected ? 1.12 : 1)
        }
        .buttonStyle(PressableStyle())
    }

    private func boostRow(_ boost: Boost) -> some View {
        let owned = game.boosts.contains(boost)
        let worn = look.boosts.contains(boost)
        let hidden = look.hiddenBoosts.contains(boost)
        return HStack(spacing: 10) {
            boostButton(boost, owned: owned, worn: worn)
            // The eye: keep the boost's power but don't draw it on your character.
            if owned {
                Button(action: pick {
                    if hidden { look.hiddenBoosts.remove(boost) } else { look.hiddenBoosts.insert(boost) }
                }) {
                    VStack(spacing: 1) {
                        Image(systemName: hidden ? "eye.slash.fill" : "eye.fill").font(.system(size: 20, weight: .bold))
                        Text(hidden ? "Hidden" : "Shown").font(.game(12, .heavy))
                    }
                    .foregroundStyle(hidden ? .white.opacity(0.55) : .white)
                    .frame(width: 66, height: 60)
                    .background(.white.opacity(hidden ? 0.06 : 0.16), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(PressableStyle())
                .opacity(worn ? 1 : 0.4)
                .disabled(!worn)
            }
        }
    }

    private func boostButton(_ boost: Boost, owned: Bool, worn: Bool) -> some View {
        Button(action: pick {
            guard owned else { return }
            if worn { look.boosts.remove(boost) } else { look.boosts.insert(boost) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: owned ? boost.symbol : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(owned ? boost.color : .white.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(boost.name).font(.game(19)).foregroundStyle(.white.opacity(owned ? 1 : 0.5))
                    Text(boost.about).font(.game(13, .medium)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.leading)
                }
                Spacer()
                if owned {
                    Text(worn ? "ON" : "OFF").font(.game(16, .heavy)).foregroundStyle(worn ? .green : .white.opacity(0.5))
                }
            }
            .padding(8)
            .frame(width: 500)
            .background(.white.opacity(worn ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(worn ? Palette.gold : .clear, lineWidth: 3))
        }
        .buttonStyle(PressableStyle())
    }

    private func iconChoice(_ symbol: String, selected: Bool, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: pick(action)) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(.white.opacity(selected ? 0.3 : 0.08), in: Circle())
                .overlay(Circle().stroke(selected ? Palette.gold : .white.opacity(0.3), lineWidth: selected ? 5 : 2))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Save files

/// Every save file, with a button to start a new one. Each file is its own player:
/// name, look, levels, badges, accessories and items.
struct SaveFilesView: View {
    @Environment(GameState.self) private var game
    let onPick: (Int) -> Void
    let onNew: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 18) {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onBack)
                    Spacer()
                }
                Text("Save Files")
                    .font(.game(52, .heavy))
                    .foregroundStyle(.white)
                Text("Tap a file to play it. Make as many as you like.")
                    .font(.game(20, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(330), spacing: 18), count: 3), spacing: 18) {
                        ForEach(GameState.slots, id: \.self) { slot in
                            fileCard(slot)
                        }
                        Button {
                            SoundPlayer.shared.tap()
                            onNew()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 44))
                                Text("New File").font(.game(26))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 330, height: 150)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
                            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [10, 8])))
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
            .padding(30)
        }
    }

    private func fileCard(_ slot: Int) -> some View {
        let info = GameState.summary(of: slot)
        let current = slot == game.slot
        return Button {
            SoundPlayer.shared.tap()
            onPick(slot)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(info.name.isEmpty ? "New player" : info.name)
                        .font(.game(28, .heavy))
                        .lineLimit(1)
                    Spacer()
                    if current {
                        Text("PLAYING").font(.game(14, .heavy)).foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Palette.gold, in: Capsule())
                    }
                }
                Label("Levels won: \(info.levels)", systemImage: "star.fill").font(.game(19, .semibold))
                Label("Badges: \(info.badges)/\(Badge.allCases.count)", systemImage: "rosette").font(.game(19, .semibold))
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(width: 330, height: 150, alignment: .leading)
            .background(current ? AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.white.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Custom sounds

/// Every sound in the game, each with a play button and a choice of 20 effects to swap it for.
struct SoundSettingsView: View {
    let onBack: () -> Void
    @State private var swaps = SoundPlayer.shared.swaps

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 16) {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onBack)
                    Spacer()
                    Button("Reset all") {
                        SoundPlayer.shared.tap()
                        for sound in Sound.allCases { SoundPlayer.shared.setSwap(sound, to: nil) }
                        swaps = [:]
                    }
                    .font(.game(22))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.35), in: Capsule())
                }
                Text("Custom Sounds")
                    .font(.game(48, .heavy))
                    .foregroundStyle(.white)
                Text("Tap ▶ to listen. Pick a different effect for any sound in the game.")
                    .font(.game(20, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(520), spacing: 16), count: 2), spacing: 10) {
                        ForEach(Sound.allCases, id: \.self) { sound in
                            row(sound)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .padding(30)
        }
    }

    private func row(_ sound: Sound) -> some View {
        HStack(spacing: 12) {
            Button {
                sound.play()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Palette.button, in: Circle())
            }
            .buttonStyle(PressableStyle())
            Text(sound.title)
                .font(.game(20))
                .foregroundStyle(.white)
            Spacer()
            Menu {
                Button("Original") { choose(sound, nil) }
                ForEach(Sound.choices.filter { $0 != sound }, id: \.self) { option in
                    Button(option.title) { choose(sound, option) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(swaps[sound]?.title ?? "Original")
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.game(17))
                .foregroundStyle(swaps[sound] == nil ? .white.opacity(0.7) : Palette.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func choose(_ sound: Sound, _ replacement: Sound?) {
        SoundPlayer.shared.setSwap(sound, to: replacement)
        swaps = SoundPlayer.shared.swaps
        sound.play()
    }
}

// MARK: - Badges

struct BadgesView: View {
    @Environment(GameState.self) private var game
    let onBack: () -> Void

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 20) {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onBack)
                    Spacer()
                    Text("\(game.badges.count) of \(Badge.allCases.count) earned")
                        .font(.game(24))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.35), in: Capsule())
                }
                Text("Badges")
                    .font(.game(52, .heavy))
                    .foregroundStyle(.white)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(200), spacing: 16), count: 5), spacing: 16) {
                        ForEach(Badge.allCases) { badge in
                            badgeCard(badge)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .padding(30)
        }
    }

    private func badgeCard(_ badge: Badge) -> some View {
        let earned = game.badges.contains(badge)
        return VStack(spacing: 8) {
            Image(systemName: earned ? badge.symbol : "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(earned ? badge.color : Color.white.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(earned ? Palette.gold : .white.opacity(0.2), lineWidth: 4))
            Text(badge.name)
                .font(.game(19, .heavy))
                .foregroundStyle(.white.opacity(earned ? 1 : 0.6))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(badge.how)
                .font(.game(13, .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(12)
        .frame(width: 200, height: 200)
        .background(.white.opacity(earned ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}

/// Slides down from the top whenever a badge is earned, on any screen.
struct BadgeToast: View {
    let badge: Badge

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: badge.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(badge.color, in: Circle())
                .overlay(Circle().stroke(Palette.gold, lineWidth: 3))
            VStack(alignment: .leading, spacing: 2) {
                Text("Badge earned!")
                    .font(.game(16, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(badge.name)
                    .font(.game(24, .heavy))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color(red: 0.16, green: 0.12, blue: 0.34), in: Capsule())
        .overlay(Capsule().stroke(Palette.gold, lineWidth: 3))
        .shadow(radius: 10)
    }
}

// MARK: - Level progress

/// Shows how far you've got. You can only play levels you've won, plus the next one.
struct LevelSelectView: View {
    @Environment(GameState.self) private var game
    let onPick: (Int) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 26) {
                HStack {
                    RoundIconButton(symbol: "chevron.left", action: onBack)
                    Spacer()
                    HStack(spacing: 4) {
                        CharacterView(look: game.look)
                            .scaleEffect(0.45)
                            .frame(width: 50, height: 74)
                        Text(game.playerName)
                            .font(.game(28))
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 20)
                    .padding(.leading, 6)
                    .background(.black.opacity(0.35), in: Capsule())
                }
                .overlay(alignment: .top) { CreativeSwitch() }
                Text("Levels")
                    .font(.game(56, .heavy))
                    .foregroundStyle(.white)
                Text(game.nextLevel == nil ? "You won every level so far! More rooms are coming soon."
                     : "Win each level to unlock the next one.")
                    .font(.game(22, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(170), spacing: 26), count: 5), spacing: 22) {
                    ForEach(Levels.all) { level in
                        levelCard(level)
                    }
                }
                Spacer()
            }
            .padding(30)
        }
    }

    private func levelCard(_ level: LevelInfo) -> some View {
        let unlocked = game.isUnlocked(level)
        let done = game.completedLevels.contains(level.id)
        return Button {
            SoundPlayer.shared.tap()
            onPick(level.id)
        } label: {
            VStack(spacing: 10) {
                Text("\(level.id)")
                    .font(.game(44, .heavy))
                Image(systemName: unlocked ? level.symbol : "lock.fill")
                    .font(.system(size: 30))
                Text(level.isReady ? level.room : "Coming soon")
                    .font(.game(18, .semibold))
            }
            .foregroundStyle(.white.opacity(unlocked ? 1 : 0.45))
            .frame(width: 170, height: 170)
            .background(
                unlocked ? AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 28)
            )
            .overlay(alignment: .topTrailing) {
                if done {
                    Image(systemName: "star.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Palette.gold)
                        .shadow(radius: 3)
                        .padding(10)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!unlocked)
    }
}
