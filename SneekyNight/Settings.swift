import SwiftUI
import Observation

/// Choices from the Settings screen. Shared by every save file and kept between launches.
@Observable
final class Settings {
    static let shared = Settings()

    var master: Double { didSet { save() } }
    var music: Double { didSet { save() } }
    var effects: Double { didSet { save() } }
    /// 0 = always night, 1 = always early morning, 2 = follow the real clock in `timeZoneID`,
    /// 3 = always afternoon, 4 = always sunset.
    var skyMode: Int { didSet { save() } }
    /// The time zone picked in Settings (used when the sky follows the real clock).
    var timeZoneID: String { didSet { save() } }
    /// Practice mode: the Guide gives tips and nobody can catch or hurt you.
    var practice: Bool { didSet { save() } }
    /// Set while a story level is played on No Mercy that you haven't won on No Mercy yet:
    /// practice mode can't be used there until you have. Not saved.
    var practiceLocked = false
    /// Practice mode, if it's allowed right now.
    var practiceOn: Bool { practice && !practiceLocked }
    /// Creative mode's sky command. Not saved.
    var skyOverride: Sky?

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The time of day right now in the chosen time zone, in hours with a fraction (13.5 = half past one).
    var localTime: Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: Date())
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
    }

    /// Where the sun (or the moon at night) is in the menu's sky: `across` goes 0 (rising, left)
    /// to 1 (setting, right), `height` 0 (on the horizon) to 1 (high up). With the real clock it
    /// moves all day: the sun comes up slowly from 5 o'clock and goes down slowly until 7 in the evening.
    var skyBody: (across: Double, height: Double, sun: Bool) {
        if skyOverride == nil && skyMode == 2 {
            let h = localTime
            if h >= 5 && h < 19 {
                let p = (h - 5) / 14
                return (p, sin(p * .pi), true)
            }
            // The moon crosses the night sky from 7 in the evening to 5 in the morning.
            let p = (h >= 19 ? h - 19 : h + 5) / 10
            return (p, sin(p * .pi) * 0.85, false)
        }
        switch sky {
        case .night: return (0.4, 0.85, false)
        case .dawn: return (0.12, 0.22, true)
        case .day: return (0.5, 1, true)
        case .afternoon: return (0.7, 0.62, true)
        case .dusk: return (0.88, 0.2, true)
        }
    }

    /// The hour (0–23) right now in the chosen time zone.
    var localHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.hour, from: Date())
    }

    /// What the sky looks like right now.
    var sky: Sky {
        if let skyOverride { return skyOverride }
        switch skyMode {
        case 1: return .dawn
        case 2: return Sky.at(hour: localHour)
        case 3: return .afternoon
        case 4: return .dusk
        default: return .night
        }
    }
    /// The difficulty mode (a `Difficulty` raw value; 1 = Mild).
    var difficulty: Int { didSet { save() } }
    /// The song that plays: 0–4 from `Song.names`, or `Song.own` for your own song.
    var song: Int { didSet { save(); if song != oldValue { SoundPlayer.shared.restartMusic() } } }
    /// 0 = small, 1 = normal, 2 = big joystick and buttons.
    var controlSize: Int { didSet { save() } }
    /// Joystick on the right and buttons on the left.
    var swapSides: Bool { didSet { save() } }
    var haptics: Bool { didSet { save() } }
    /// The little key letters (E, Space, R…) on the buttons.
    var keyLabels: Bool { didSet { save() } }
    /// The name tag floating over your character.
    var nameTag: Bool { didSet { save() } }

    var controlScale: CGFloat { [0.85, 1.0, 1.2][min(max(controlSize, 0), 2)] }

    private init() {
        let d = UserDefaults.standard
        func value(_ key: String, _ fallback: Double) -> Double { d.object(forKey: key) == nil ? fallback : d.double(forKey: key) }
        func flag(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) == nil ? fallback : d.bool(forKey: key) }
        master = value("set.master", 1)
        music = value("set.music", 0.5)
        effects = value("set.effects", 1)
        skyMode = d.object(forKey: "set.skyMode") == nil ? (flag("set.dawn", false) ? 1 : 0) : d.integer(forKey: "set.skyMode")
        timeZoneID = d.string(forKey: "set.timeZone") ?? TimeZone.current.identifier
        practice = flag("set.practice", false)
        difficulty = d.object(forKey: "set.difficulty") == nil ? 1 : d.integer(forKey: "set.difficulty")
        song = d.integer(forKey: "set.song")
        controlSize = d.object(forKey: "set.controlSize") == nil ? 1 : d.integer(forKey: "set.controlSize")
        swapSides = flag("set.swapSides", false)
        haptics = flag("set.haptics", true)
        keyLabels = flag("set.keyLabels", true)
        nameTag = flag("set.nameTag", true)
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(master, forKey: "set.master")
        d.set(music, forKey: "set.music")
        d.set(effects, forKey: "set.effects")
        d.set(skyMode, forKey: "set.skyMode")
        d.set(timeZoneID, forKey: "set.timeZone")
        d.set(practice, forKey: "set.practice")
        d.set(difficulty, forKey: "set.difficulty")
        d.set(song, forKey: "set.song")
        d.set(controlSize, forKey: "set.controlSize")
        d.set(swapSides, forKey: "set.swapSides")
        d.set(haptics, forKey: "set.haptics")
        d.set(keyLabels, forKey: "set.keyLabels")
        d.set(nameTag, forKey: "set.nameTag")
        SoundPlayer.shared.updateMusicVolume()
    }
}

/// The four looks of the sky. With "real time" on, the hour in your time zone picks one.
enum Sky: String, CaseIterable {
    case night, dawn, day, afternoon, dusk

    static func at(hour: Int) -> Sky {
        switch hour {
        case 5..<7: .dawn
        case 7..<13: .day
        case 13..<17: .afternoon
        case 17..<19: .dusk
        default: .night
        }
    }

    var title: String {
        switch self {
        case .night: "Night"
        case .dawn: "Sunrise"
        case .day: "Day"
        case .afternoon: "Afternoon"
        case .dusk: "Sunset"
        }
    }
}
