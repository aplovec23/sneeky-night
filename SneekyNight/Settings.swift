import SwiftUI
import Observation

/// Choices from the Settings screen. Shared by every save file and kept between launches.
@Observable
final class Settings {
    static let shared = Settings()

    var master: Double { didSet { save() } }
    var music: Double { didSet { save() } }
    var effects: Double { didSet { save() } }
    /// 0 = always night, 1 = always early morning, 2 = follow the real clock in `timeZoneID`.
    var skyMode: Int { didSet { save() } }
    /// The time zone picked in Settings (used when the sky follows the real clock).
    var timeZoneID: String { didSet { save() } }
    /// Practice mode: the Guide gives tips and nobody can catch or hurt you.
    var practice: Bool { didSet { save() } }
    /// Creative mode's sky command. Not saved.
    var skyOverride: Sky?

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

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
        default: return .night
        }
    }
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
    case night, dawn, day, dusk

    static func at(hour: Int) -> Sky {
        switch hour {
        case 5..<7: .dawn
        case 7..<17: .day
        case 17..<19: .dusk
        default: .night
        }
    }

    var title: String {
        switch self {
        case .night: "Night"
        case .dawn: "Sunrise"
        case .day: "Day"
        case .dusk: "Sunset"
        }
    }
}
