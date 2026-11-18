import AVFoundation
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

/// Plays the short sound effects in `Sounds/` (made by tools/make_sounds.py).
enum Sound: String, CaseIterable {
    case click, step, jump, land, key, powerup, drawer, box, paper, window, door, closet
    case unlock, buzz, beep, chair, table, lamp, squeak, caught, mom, win, tick, heavy
    case taunt, dash, dad, crouch, magic, woof, creak, craft, lightSwitch, star
    case ouch, water, bug, rustle, whip, bonk
    case applause, projector, seat, ticket, popcorn, chime

    func play(volume: Float = 1) {
        SoundPlayer.shared.play(self, volume: volume)
    }

    /// What this sound is for, shown on the Custom Sounds screen.
    var title: String {
        switch self {
        case .click: "Button click"
        case .step: "Footstep"
        case .jump: "Jump"
        case .land: "Landing"
        case .key: "Found a key"
        case .powerup: "Power-up"
        case .drawer: "Drawer"
        case .box: "Box"
        case .paper: "Paper"
        case .window: "Window"
        case .door: "Door"
        case .closet: "Closet"
        case .unlock: "Unlock"
        case .buzz: "Wrong code"
        case .beep: "Keypad beep"
        case .chair: "Chair bump"
        case .table: "Table bump"
        case .lamp: "Lamp crash"
        case .squeak: "Squeaky toy"
        case .caught: "Caught"
        case .mom: "Mom wakes up"
        case .win: "Level complete"
        case .tick: "Clock tick"
        case .heavy: "Too heavy"
        case .taunt: "Taunt"
        case .dash: "Dash"
        case .dad: "Dad's footsteps"
        case .crouch: "Crouch"
        case .magic: "Badge / surprise"
        case .woof: "Dog"
        case .creak: "Loose plank"
        case .craft: "Crafting"
        case .lightSwitch: "Light switch"
        case .star: "Star ball"
        case .ouch: "Spiky vines"
        case .water: "Watering"
        case .bug: "Pest"
        case .rustle: "Bush"
        case .whip: "Vine whip"
        case .bonk: "Bat bonk"
        case .applause: "applause"
        case .projector: "projector starting"
        case .seat: "sitting down"
        case .ticket: "ticket"
        case .popcorn: "popcorn"
        case .chime: "new part"
        }
    }

    /// The 20 effects you can swap any game sound for.
    static let choices: [Sound] = [.click, .jump, .key, .powerup, .box, .window, .door, .unlock, .buzz, .beep,
                                   .squeak, .caught, .win, .taunt, .dash, .magic, .woof, .creak, .star, .whip]
}

/// The game's songs (Settings → Song). The last choice is your own song from the gallery or Files.
enum Song {
    static let names = ["Night Lullaby", "Sneaky Steps", "Moonlit Stroll", "Sunrise", "Midnight Run"]
    static let files = ["music", "songSteps", "songStroll", "songSunrise", "songRun"]
    /// `Settings.song` for "my own song".
    static let own = 99

    /// Where your own song is kept on the device (one at a time).
    static var ownFolder: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("MySong", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static var ownFile: URL? {
        (try? FileManager.default.contentsOfDirectory(at: ownFolder, includingPropertiesForKeys: nil))?.first
    }

    /// Copies a picked song (or video) in as "my own song", replacing the last one. Returns false if it failed.
    @discardableResult static func keepOwn(_ source: URL) -> Bool {
        for old in (try? FileManager.default.contentsOfDirectory(at: ownFolder, includingPropertiesForKeys: nil)) ?? [] {
            try? FileManager.default.removeItem(at: old)
        }
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        do {
            try FileManager.default.copyItem(at: source, to: ownFolder.appendingPathComponent("song." + ext))
            return true
        } catch {
            return false
        }
    }
}

/// A video picked from the photo gallery, to use its sound as "my own song".
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}

/// Speaks a line out loud in a grown-up voice (Mom calling your name).
enum Voice {
    private static let synthesizer = AVSpeechSynthesizer()

    static func momCalls(_ name: String) {
        let who = name.isEmpty ? "Sweetie" : name
        let utterance = AVSpeechUtterance(string: "\(who)? \(who)! Where are you?")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.35
        utterance.volume = 1
        synthesizer.speak(utterance)
    }
}

final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [Sound: [AVAudioPlayer]] = [:]
    private var musicPlayer: AVAudioPlayer?
    /// Your own song plays through this instead (it can be a video from the gallery), looping.
    private var ownPlayer: AVQueuePlayer?
    private var ownLooper: AVPlayerLooper?
    private var filmPlayer: AVAudioPlayer?
    private var filmName: String?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            // A few copies of each so quick repeats (footsteps, clicks) can overlap.
            players[sound] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    /// Custom Sounds: which effect actually plays for each game sound. Saved on the iPad.
    private(set) var swaps: [Sound: Sound] = {
        let saved = UserDefaults.standard.dictionary(forKey: "soundSwaps") as? [String: String] ?? [:]
        var result: [Sound: Sound] = [:]
        for (from, to) in saved {
            if let from = Sound(rawValue: from), let to = Sound(rawValue: to) { result[from] = to }
        }
        return result
    }()

    func setSwap(_ sound: Sound, to replacement: Sound?) {
        swaps[sound] = replacement
        var saved: [String: String] = [:]
        for (from, to) in swaps { saved[from.rawValue] = to.rawValue }
        UserDefaults.standard.set(saved, forKey: "soundSwaps")
    }

    func play(_ original: Sound, volume: Float) {
        let sound = swaps[original] ?? original
        guard let pool = players[sound], let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.volume = volume * Float(Settings.shared.master * Settings.shared.effects)
        player.currentTime = 0
        player.play()
    }

    /// The looping song picked in Settings (the quiet night tune unless you chose another).
    func startMusic() {
        guard musicPlayer == nil && ownPlayer == nil else { return }
        let pick = Settings.shared.song
        if pick == Song.own, let url = Song.ownFile {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            ownLooper = AVPlayerLooper(player: player, templateItem: item)
            ownPlayer = player
            updateMusicVolume()
            if filmPlayer == nil { player.play() }
            return
        }
        let file = Song.files[min(max(pick, 0), Song.files.count - 1)]
        guard let url = Bundle.main.url(forResource: file, withExtension: "wav") else { return }
        musicPlayer = try? AVAudioPlayer(contentsOf: url)
        musicPlayer?.numberOfLoops = -1
        updateMusicVolume()
        if filmPlayer == nil { musicPlayer?.play() }
    }

    /// A different song was picked: stop this one and start that one.
    func restartMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        ownPlayer?.pause()
        ownLooper = nil
        ownPlayer = nil
        startMusic()
    }

    /// Creative mode: faster or slower music (1 = normal).
    func setMusic(rate: Float) {
        musicPlayer?.enableRate = true
        musicPlayer?.rate = rate
        if let ownPlayer, ownPlayer.rate != 0 { ownPlayer.rate = rate }
    }

    func toggleMusic() {
        if let ownPlayer {
            if ownPlayer.rate != 0 { ownPlayer.pause() } else { ownPlayer.play() }
            return
        }
        guard let musicPlayer else { return }
        if musicPlayer.isPlaying { musicPlayer.pause() } else { musicPlayer.play() }
    }

    /// The cinema has its own music: a tune for the lobby and one for each kind of film
    /// (Sounds/film….wav). While it plays, the game's usual tune is paused.
    func playFilmMusic(_ name: String) {
        guard name != filmName else { return }
        filmPlayer?.stop()
        filmPlayer = nil
        filmName = name
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        musicPlayer?.pause()
        ownPlayer?.pause()
        filmPlayer = try? AVAudioPlayer(contentsOf: url)
        filmPlayer?.numberOfLoops = -1
        updateMusicVolume()
        filmPlayer?.play()
    }

    /// Leaving the cinema: its music stops and the usual tune carries on.
    func stopFilmMusic() {
        filmPlayer?.stop()
        filmPlayer = nil
        filmName = nil
        musicPlayer?.play()
        ownPlayer?.play()
    }

    func updateMusicVolume() {
        filmPlayer?.volume = Float(Settings.shared.master * Settings.shared.music) * 0.7
        musicPlayer?.volume = Float(Settings.shared.master * Settings.shared.music) * 0.6
        ownPlayer?.volume = Float(Settings.shared.master * Settings.shared.music) * 0.6
    }

    /// Button press: click sound plus a light tap of the iPad's haptics.
    func tap() {
        play(.click, volume: 0.7)
        if Settings.shared.haptics { haptic.impactOccurred() }
    }
}
