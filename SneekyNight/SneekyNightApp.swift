import SwiftUI

@main
struct SneekyNightApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

enum Screen: Equatable {
    case title, customize, levels, badges, sounds, saves, settings, updateLog, sideLevels, side(Int), level(Int)
    case difficulty, multiplayer, lore, maker, makerEdit(String), makerPlay(String), customizeP2, customizeGuide, shop
}

struct ContentView: View {
    @State private var game = GameState()
    @State private var screen: Screen = .title
    /// First-time players make their character, then go straight into the game.
    @State private var playAfterCustomize = false

    var body: some View {
        ZStack {
            switch screen {
            // A story level on a mode it hasn't been unlocked for yet: say what's needed instead.
            case .level(let n) where n <= Levels.all.count && !game.modeUnlocked(Difficulty.current, level: n):
                FitToPhone(night: true) { ModeLockedView(level: n, onBack: { screen = .title }) }
            case .title:
                FitToPhone(night: true) {
                    TitleView(onPlay: play, onLevels: { screen = .levels }, onCustomize: { screen = .customize },
                              onBadges: { screen = .badges }, onSaves: { screen = .saves },
                              onSideLevels: { screen = .sideLevels }, onSettings: { screen = .settings },
                              onUpdateLog: { screen = .updateLog }, onMultiplayer: { screen = .multiplayer },
                              onMaker: { screen = .maker }, onLore: { screen = .lore }, onDifficulty: { screen = .difficulty },
                              onShop: { screen = .shop })
                }
            case .shop:
                FitToPhone(night: true) { ShopMenuView(onBack: { screen = .title }) }
            case .saves:
                FitToPhone(night: true) {
                    SaveFilesView(onPick: { slot in
                        switchTo(slot)
                        screen = .title
                    }, onNew: {
                        // A new file is a new player: straight to making their character.
                        switchTo(GameState.newSlot())
                        game.note(saveFiles: GameState.slots.count)
                        screen = .customize
                    }, onBack: { screen = .title })
                }
            case .settings:
                FitToPhone(night: true) { SettingsView(onBack: { screen = .title }) }
            case .updateLog:
                FitToPhone(night: true) { UpdateLogView(onBack: { screen = .title }) }
            case .sideLevels:
                FitToPhone(night: true) { SideLevelsView(onPlay: { screen = .side($0) }, onBack: { screen = .title }) }
            case .side(6):
                RoomLevelView(onExit: { screen = .sideLevels })
            case .side(5):
                DreamLevelView(onExit: { screen = .sideLevels })
            case .side(3):
                UncleCarView(onExit: { screen = .sideLevels })
            case .side(2):
                ShopLevelView(onExit: { screen = .sideLevels })
            case .side:
                OtherHallwayLevelView(onExit: { screen = .sideLevels })
            case .difficulty:
                FitToPhone(night: true) { DifficultyView(onBack: { screen = .title }) }
            case .multiplayer:
                FitToPhone(night: true) { MultiplayerView(onBack: { screen = .title }, onCustomize: { screen = .customizeP2 }) }
            case .customizeP2:
                FitToPhone(night: true) { CustomizeView(onDone: { screen = .multiplayer }, onBack: { screen = .multiplayer }, player2: true) }
            case .customizeGuide:
                FitToPhone(night: true) { CustomizeView(onDone: { screen = .customize }, onBack: { screen = .customize }, guide: true) }
            case .lore:
                FitToPhone(night: true) { LoreView(onBack: { screen = .title }) }
            case .maker:
                FitToPhone(night: true) {
                    LevelMakerListView(onEdit: { screen = .makerEdit($0) }, onPlay: { screen = .makerPlay($0) }, onBack: { screen = .title })
                }
            case .makerEdit(let id):
                FitToPhone(night: true) { LevelEditorView(levelID: id, onTest: { screen = .makerPlay(id) }, onBack: { screen = .maker }) }
            case .makerPlay(let id):
                CustomLevelView(levelID: id, onExit: { screen = .maker }, onEdit: { screen = .makerEdit(id) })
            case .badges:
                FitToPhone(night: true) { BadgesView(onBack: { screen = .title }) }
            case .customize:
                FitToPhone(night: true) { CustomizeView(onDone: {
                    if playAfterCustomize {
                        playAfterCustomize = false
                        play()
                    } else {
                        screen = .title
                    }
                }, onBack: {
                    playAfterCustomize = false
                    screen = .title
                }, onSounds: { screen = .sounds }, onGuide: { screen = .customizeGuide }) }
            case .sounds:
                FitToPhone(night: true) { SoundSettingsView(onBack: { screen = .customize }) }
            case .levels:
                FitToPhone(night: true) { LevelSelectView(onPick: { screen = .level($0) }, onBack: { screen = .title }) }
            case .level(1):
                BedroomLevelView(onExit: { screen = .title }, onNext: { screen = .level(2) })
            case .level(2):
                HallwayLevelView(onExit: { screen = .title }, onNext: { screen = .level(3) })
            case .level(3):
                DownstairsLevelView(onExit: { screen = .title }, onNext: { screen = .level(4) })
            case .level(4):
                GardenLevelView(onExit: { screen = .title }, onNext: { screen = .level(5) })
            case .level(5):
                StreetLevelView(onExit: { screen = .title }, onNext: { screen = .level(6) })
            case .level(6):
                AuntieLevelView(onExit: { screen = .title }, onNext: play)
            case .level(7):
                BackyardLevelView(onExit: { screen = .title }, onNext: { screen = .level(8) })
            case .level(8):
                GrandmaLevelView(onExit: { screen = .title }, onNext: { screen = .level(9) })
            case .level(9):
                RaidLevelView(onExit: { screen = .title }, onNext: play)
            case .level:
                FitToPhone(night: true) { LevelSelectView(onPick: { screen = .level($0) }, onBack: { screen = .title }) }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: screen)
        .overlay(alignment: .top) {
            if let badge = game.badgeToast {
                BadgeToast(badge: badge)
                    .scaleEffect(Device.isPhone ? 0.6 : 1, anchor: .top)
                    .padding(.top, Device.isPhone ? 44 : 96)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: game.badgeToast)
        .overlay(alignment: .bottom) {
            if let amount = game.moonlightToast {
                MoonlightToast(amount: amount)
                    .scaleEffect(Device.isPhone ? 0.6 : 1, anchor: .bottom)
                    .padding(.bottom, Device.isPhone ? 20 : 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.4), value: game.moonlightToast)
        .environment(game)
        .onChange(of: screen) { updatePracticeLock() }
        .onChange(of: Settings.shared.difficulty) { updatePracticeLock() }
        .onAppear {
            #if DEBUG
            // Test builds on GitHub's Mac: draw the characters to pictures, or open a level straight away.
            if DebugSnapshots.requested {
                DebugSnapshots.run(game: game)
                return
            }
            if let level = DebugSnapshots.openLevel { screen = .level(level) }
            #endif
            game.awardLaunchBadges()
            game.note(saveFiles: GameState.slots.count)
            SoundPlayer.shared.startMusic()
        }
    }

    /// No Mercy: practice mode stays off in a story level until you've won it on No Mercy.
    private func updatePracticeLock() {
        if case .level(let n) = screen, Difficulty.current == .noMercy {
            Settings.shared.practiceLocked = !(game.beatenOn[n] ?? []).contains(Difficulty.noMercy.rawValue)
        } else {
            Settings.shared.practiceLocked = false
        }
    }

    private func switchTo(_ slot: Int) {
        GameState.currentSlot = slot
        game = GameState(slot: slot)
        game.awardLaunchBadges()
    }

    /// Play goes straight to the first level you haven't won.
    private func play() {
        if !game.hasCharacter {
            playAfterCustomize = true
            screen = .customize
        } else if let next = game.nextLevel {
            screen = .level(next)
        } else {
            screen = .levels
        }
    }
}
