import SwiftUI

/// What creative mode's commands can reach in the level being played.
struct AdminContext {
    let engine: GameEngine
    let chase: Chase?
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

/// Creative mode's 45 commands. They change the level you're in, your status, the sky and the music.
@MainActor
enum Admin {
    static let groups = ["You", "Clock", "Noise", "Grown-ups", "Level", "Sky", "Music & fun"]

    static let commands: [AdminCommand] = {
        var list: [(String, String, String, @MainActor (AdminContext) -> Void)] = []
        func add(_ group: String, _ name: String, _ symbol: String, _ run: @escaping @MainActor (AdminContext) -> Void) {
            list.append((group, name, symbol, run))
        }
        // You (15)
        add("You", "Speed ×2", "hare.fill") { $0.engine.speedBonus += 1 }
        add("You", "Normal speed", "tortoise.fill") { $0.engine.speedBonus = 0 }
        add("You", "Super jump", "arrow.up.to.line") { $0.engine.jumpBoost = true; $0.engine.jumpMult = 3 }
        add("You", "Normal jump", "arrow.up") { $0.engine.jumpBoost = false; $0.engine.jumpMult = 1 }
        add("You", "Super dash", "wind") { $0.engine.canDash = true; $0.engine.dashMult = 4 }
        add("You", "Learn Dash", "figure.run") { $0.engine.canDash = true }
        add("You", "Learn Run", "figure.run.circle.fill") { $0.engine.canRun = true }
        add("You", "Fly for 30 s", "cloud.fill") { $0.engine.fly(30) }
        add("You", "Walk through things", "square.dashed") { $0.engine.noclip.toggle() }
        add("You", "Ghost (can't be caught)", "eye.slash.fill") { $0.engine.ghost.toggle() }
        add("You", "Can't be hurt", "shield.fill") { $0.engine.godMode.toggle() }
        add("You", "Heal", "heart.fill") { $0.engine.hp = $0.engine.maxHP }
        add("You", "Giant", "arrow.up.left.and.arrow.down.right") { $0.engine.sizeScale = 1.6 }
        add("You", "Tiny", "arrow.down.right.and.arrow.up.left") { $0.engine.sizeScale = 0.6 }
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
        return list.enumerated().map { AdminCommand(id: $0.offset + 1, group: $0.element.0, name: $0.element.1, symbol: $0.element.2, run: $0.element.3) }
    }()
}

/// The admin panel: every command as a button. Tap one and it happens straight away.
struct AdminPanel: View {
    let context: AdminContext
    let onClose: () -> Void
    @State private var last = ""

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
