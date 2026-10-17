import SwiftUI

/// What creative mode's commands can reach in the level being played.
struct AdminContext {
    let engine: GameEngine
    let chase: Chase?
    /// The level's items (for the golden stick's extras in each level).
    let belt: ItemBelt?
    let restart: () -> Void
    let confetti: () -> Void
}

struct AdminCommand: Identifiable {
    let id: Int
    let group: String
    let name: String
    let symbol: String
    let run: @MainActor (AdminContext) -> Void
}

/// Creative mode's 60 commands. They change the level you're in, your status, the sky and the music.
/// Status commands stack: press "Speed ×2" three times for ×8.
@MainActor
enum Admin {
    static let groups = ["You", "Clock", "Noise", "Grown-ups", "Level", "Sky", "Music & fun"]
    /// Stacking stops here, so nothing breaks.
    static let most: CGFloat = 1000

    static let commands: [AdminCommand] = {
        var list: [(String, String, String, @MainActor (AdminContext) -> Void)] = []
        func add(_ group: String, _ name: String, _ symbol: String, _ run: @escaping @MainActor (AdminContext) -> Void) {
            list.append((group, name, symbol, run))
        }
        // You (15)
        add("You", "Speed ×2", "hare.fill") { $0.engine.speedMult = min($0.engine.speedMult * 2, Admin.most) }
        add("You", "Normal speed", "tortoise.fill") { $0.engine.speedBonus = 0; $0.engine.speedMult = 1 }
        add("You", "Super jump ×3", "arrow.up.to.line") { $0.engine.jumpMult = min($0.engine.jumpMult * 3, Admin.most) }
        add("You", "Normal jump", "arrow.up") { $0.engine.jumpBoost = false; $0.engine.jumpMult = 1 }
        add("You", "Super dash ×4", "wind") { $0.engine.canDash = true; $0.engine.dashMult = min($0.engine.dashMult * 4, Double(Admin.most)) }
        add("You", "Learn Dash", "figure.run") { $0.engine.canDash = true }
        add("You", "Learn Run", "figure.run.circle.fill") { $0.engine.canRun = true }
        add("You", "Fly for 30 s", "cloud.fill") { $0.engine.fly(30) }
        add("You", "Walk through things", "square.dashed") { $0.engine.noclip.toggle() }
        add("You", "Ghost (can't be caught)", "eye.slash.fill") { $0.engine.ghost.toggle() }
        add("You", "Can't be hurt", "shield.fill") { $0.engine.godMode.toggle() }
        add("You", "Heal", "heart.fill") { $0.engine.hp = $0.engine.maxHP }
        add("You", "Giant", "arrow.up.left.and.arrow.down.right") { $0.engine.sizeScale = min($0.engine.sizeScale * 1.6, 4) }
        add("You", "Tiny", "arrow.down.right.and.arrow.up.left") { $0.engine.sizeScale = max($0.engine.sizeScale * 0.6, 0.2) }
        add("You", "Normal size", "person.fill") { $0.engine.sizeScale = 1 }
        // Clock (7)
        add("Clock", "+60 seconds", "plus.circle.fill") { $0.engine.timeLeft += 60 }
        add("Clock", "−30 seconds", "minus.circle.fill") { $0.engine.timeLeft = max(5, $0.engine.timeLeft - 30) }
        add("Clock", "Freeze the clock", "snowflake") { $0.engine.clockFrozen = true }
        add("Clock", "Unfreeze the clock", "clock.fill") { $0.engine.clockFrozen = false }
        add("Clock", "Slow motion", "tortoise") { $0.engine.timeScale = 0.5 }
        add("Clock", "Fast forward", "forward.fill") { $0.engine.timeScale = 2 }
        add("Clock", "Normal game speed", "play.fill") { $0.engine.timeScale = 1 }
        // Noise (3)
        add("Noise", "Clear the noise", "speaker.slash.fill") { $0.engine.resetNoise() }
        add("Noise", "Fill the noise meter", "speaker.wave.3.fill") { $0.engine.noiseMuted = false; $0.engine.noise = 100 }
        add("Noise", "No noise at all", "ear.badge.checkmark") { $0.engine.noiseMuted.toggle(); $0.engine.resetNoise() }
        // Grown-ups (5)
        add("Grown-ups", "Summon Mom", "figure.dress.line.vertical.figure") { $0.chase?.alarm(.mom, "You summoned Mom!") }
        add("Grown-ups", "Summon Dad", "mustache.fill") { $0.chase?.alarm(.dad, "You summoned Dad!") }
        add("Grown-ups", "Send them away", "figure.walk.departure") { c in
            c.chase?.reset()
            c.chase?.setBanner(nil)
            c.engine.timerOn = true
        }
        add("Grown-ups", "Stun for 30 s", "sparkles") { _ = $0.chase?.stun(30, momOnly: false) }
        add("Grown-ups", "Make them talk", "bubble.left.and.bubble.right.fill") { $0.chase?.forceMeet() }
        // Level (7)
        add("Level", "Drop a box", "shippingbox.fill") { c in
            let e = c.engine
            e.things.append(Thing(id: "admin-box\(e.things.count)", kind: "box",
                                  pos: CGPoint(x: e.player.x + (e.facingRight ? 90 : -90), y: e.player.y),
                                  footprint: CGSize(width: 72, height: 30), solid: true, movable: true))
        }
        add("Level", "Drop a chair", "chair.fill") { c in
            let e = c.engine
            e.ignoreHazards(for: 1)
            e.things.append(Thing(id: "admin-chair\(e.things.count)", kind: "chair",
                                  pos: CGPoint(x: e.player.x + (e.facingRight ? 110 : -110), y: e.player.y),
                                  footprint: CGSize(width: 64, height: 30), hazard: .chair))
        }
        add("Level", "Remove every obstacle", "trash.fill") { c in
            for i in c.engine.things.indices where c.engine.things[i].hazard != nil { c.engine.things[i].hidden = true }
        }
        add("Level", "Remove nearest thing", "xmark.bin.fill") { c in
            let e = c.engine
            // Only things with nothing to "use", so the level can still be finished.
            let near = e.things.indices.filter { !e.things[$0].hidden && e.things[$0].onFloor && e.things[$0].prompt == nil }
                .min { abs(e.things[$0].pos.x - e.player.x) < abs(e.things[$1].pos.x - e.player.x) }
            if let near, abs(e.things[near].pos.x - e.player.x) < 260 { e.things[near].hidden = true }
        }
        add("Level", "Jump to the start", "backward.end.fill") { $0.engine.player.x = 120 }
        add("Level", "Jump to the far end", "forward.end.fill") { $0.engine.player.x = $0.engine.width - 160 }
        add("Level", "Restart the level", "arrow.counterclockwise") { $0.restart() }
        // Sky (4)
        add("Sky", "Night", "moon.stars.fill") { _ in Settings.shared.skyOverride = .night }
        add("Sky", "Sunrise", "sunrise.fill") { _ in Settings.shared.skyOverride = .dawn }
        add("Sky", "Day", "sun.max.fill") { _ in Settings.shared.skyOverride = .day }
        add("Sky", "Sunset", "sunset.fill") { _ in Settings.shared.skyOverride = .dusk }
        // Music & fun (4)
        add("Music & fun", "Music on / off", "music.note") { _ in SoundPlayer.shared.toggleMusic() }
        add("Music & fun", "Fast music", "hare") { _ in SoundPlayer.shared.setMusic(rate: 1.5) }
        add("Music & fun", "Slow music", "tortoise.circle") { _ in SoundPlayer.shared.setMusic(rate: 0.7) }
        add("Music & fun", "Confetti!", "party.popper.fill") { $0.confetti() }
        // New in the Sneeky Nights update (10)
        add("You", "Jump ×2", "arrow.up.circle.fill") { $0.engine.jumpMult = min($0.engine.jumpMult * 2, Admin.most) }
        add("You", "Dash ×2", "wind.circle.fill") { $0.engine.canDash = true; $0.engine.dashMult = min($0.engine.dashMult * 2, Double(Admin.most)) }
        add("You", "Quiet ×2", "speaker.zzz.fill") { $0.engine.noiseDiv = min($0.engine.noiseDiv * 2, Double(Admin.most)) }
        add("You", "Everything ×2", "bolt.circle.fill") { c in
            let e = c.engine
            e.speedMult = min(e.speedMult * 2, Admin.most)
            e.jumpMult = min(e.jumpMult * 2, Admin.most)
            e.dashMult = min(e.dashMult * 2, Double(Admin.most))
            e.noiseDiv = min(e.noiseDiv * 2, Double(Admin.most))
        }
        add("You", "Double health", "heart.circle.fill") { c in
            c.engine.usesHP = true
            c.engine.maxHP = min(c.engine.maxHP * 2, 1_000_000)
            c.engine.hp = c.engine.maxHP
        }
        add("You", "Reset every stat", "arrow.uturn.backward.circle.fill") { c in
            let e = c.engine
            e.speedBonus = 0; e.speedMult = 1; e.jumpMult = 1; e.jumpBoost = false
            e.dashMult = 1; e.noiseDiv = 1; e.sizeScale = 1
        }
        add("Clock", "+5 minutes", "clock.badge.checkmark.fill") { $0.engine.timeLeft += 300 }
        add("Grown-ups", "Stun for 5 minutes", "moon.zzz.fill") { _ = $0.chase?.stun(300, momOnly: false) }
        add("Level", "Drop a lamp", "lamp.floor.fill") { c in
            let e = c.engine
            e.ignoreHazards(for: 1)
            e.things.append(Thing(id: "admin-lamp\(e.things.count)", kind: "lamp",
                                  pos: CGPoint(x: e.player.x + (e.facingRight ? 110 : -110), y: e.player.y),
                                  footprint: CGSize(width: 40, height: 26), hazard: .lamp))
        }
        add("Music & fun", "Confetti storm", "sparkles.rectangle.stack.fill") { c in
            c.confetti()
            Task { @MainActor in
                for _ in 0..<4 {
                    try? await Task.sleep(for: .seconds(0.5))
                    c.confetti()
                }
            }
        }
        // New in The Room update (5)
        add("Grown-ups", "Golden stick", "wand.and.stars") { c in
            // Everything the golden stick does, without needing to own it: obstacles, Mom, Dad and the rest, gone.
            c.engine.things.removeAll { $0.hazard != nil }
            c.engine.grownUpsGone = true
            c.belt?.goldenStick()
            c.chase?.setBanner(nil)
            Sound.magic.play()
        }
        add("Grown-ups", "Bring everyone back", "person.3.fill") { c in
            c.engine.grownUpsGone = false
            c.engine.say("Everyone's back... (restart the level for the obstacles)", seconds: 2.5)
        }
        add("Level", "Go to the next goal", "location.fill") { c in
            // Wherever the Guide would lead you next: a key, a box, a door.
            if let spot = c.engine.guideGoal() {
                c.engine.player = CGPoint(x: min(max(spot.x, 60), c.engine.width - 60), y: min(max(spot.y + 20, c.engine.floor.lowerBound), c.engine.floor.upperBound))
            } else {
                c.engine.say("Nothing to go to here!", seconds: 1.5)
            }
        }
        add("You", "Hide right here", "eye.slash.circle.fill") { c in
            // No closet needed. Press it again to come out.
            c.engine.hidden.toggle()
            Sound.closet.play()
        }
        add("Music & fun", "Disco", "light.beacon.max.fill") { c in
            // The sky flashes through the day for a few seconds, with confetti and fast music.
            SoundPlayer.shared.setMusic(rate: 1.5)
            let before = Settings.shared.skyOverride
            Task { @MainActor in
                for n in 0..<12 {
                    Settings.shared.skyOverride = Sky.allCases[n % Sky.allCases.count]
                    if n % 3 == 0 { c.confetti() }
                    try? await Task.sleep(for: .seconds(0.4))
                }
                Settings.shared.skyOverride = before
                SoundPlayer.shared.setMusic(rate: 1)
            }
        }
        return list.enumerated().map { AdminCommand(id: $0.offset + 1, group: $0.element.0, name: $0.element.1, symbol: $0.element.2, run: $0.element.3) }
    }()
}

/// The admin panel: every command as a button. Tap one and it happens straight away.
struct AdminPanel: View {
    let context: AdminContext
    let onClose: () -> Void
    @State private var last = ""
    /// Redrawn after every command, so the status line shows the new stacked values.
    @State private var presses = 0

    /// Your stacked status right now.
    private var status: some View {
        let e = context.engine
        let speed = (1 + e.speedBonus) * e.speedMult
        return HStack(spacing: 10) {
            stat("hare.fill", Double(speed))
            stat("arrow.up", Double(e.jumpMult))
            stat("wind", e.dashMult)
            stat("speaker.slash.fill", e.noiseDiv)
            if e.usesHP {
                Label("\(Int(e.hp))", systemImage: "heart.fill")
            }
            if e.godMode { Image(systemName: "shield.fill").foregroundStyle(.green) }
            if e.ghost { Image(systemName: "eye.slash.fill").foregroundStyle(.cyan) }
        }
        .font(.game(14, .heavy))
        .foregroundStyle(.white.opacity(0.85))
        .id(presses)
    }

    private func stat(_ symbol: String, _ value: Double) -> some View {
        Label(value >= 100 ? "×\(Int(value))" : String(format: "×%.1f", value), systemImage: symbol)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                HStack {
                    CreativeCrown().scaleEffect(0.8)
                    Text("Admin Panel")
                        .font(.game(34, .heavy))
                        .foregroundStyle(.white)
                    Text("\(Admin.commands.count) commands")
                        .font(.game(16, .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    status
                    if !last.isEmpty {
                        Text("✓ \(last)")
                            .font(.game(16, .heavy))
                            .foregroundStyle(.green)
                    }
                    RoundIconButton(symbol: "xmark", action: onClose).scaleEffect(0.8)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Admin.groups, id: \.self) { group in
                            Text(group)
                                .font(.game(18, .heavy))
                                .foregroundStyle(Palette.gold)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(228), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
                                ForEach(Admin.commands.filter { $0.group == group }) { command in
                                    Button {
                                        SoundPlayer.shared.tap()
                                        command.run(context)
                                        last = command.name
                                        presses += 1
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text("\(command.id)")
                                                .font(.game(12, .heavy))
                                                .foregroundStyle(.white.opacity(0.5))
                                                .frame(width: 20)
                                            Image(systemName: command.symbol).frame(width: 24)
                                            Text(command.name).lineLimit(1).minimumScaleFactor(0.7)
                                            Spacer(minLength: 0)
                                        }
                                        .font(.game(16))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .frame(width: 228, height: 42)
                                        .background(Color(red: 0.35, green: 0.30, blue: 0.70).gradient, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
            .frame(width: 1000, height: 640)
            .background(Color(red: 0.10, green: 0.09, blue: 0.24), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(
                LinearGradient(colors: [.red, .orange, .yellow, .green, .cyan, .purple], startPoint: .leading, endPoint: .trailing), lineWidth: 4))
        }
    }
}
