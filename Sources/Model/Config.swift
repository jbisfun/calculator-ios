import Observation
import SwiftUI

/// Port of Fossify's BaseConfig + calculator Config (SharedPreferences -> UserDefaults).
@Observable
final class Config {
    static let shared = Config()

    @ObservationIgnored private let d = UserDefaults.standard

    // Colors
    var theme: ThemeKind { didSet { d.set(theme.rawValue, forKey: "theme") } }
    var customTextColor: UInt32 { didSet { d.set(Int(customTextColor), forKey: "text_color") } }
    var customBackgroundColor: UInt32 { didSet { d.set(Int(customBackgroundColor), forKey: "background_color") } }
    var customPrimaryColor: UInt32 { didSet { d.set(Int(customPrimaryColor), forKey: "primary_color") } }

    // General
    var vibrateOnButtonPress: Bool { didSet { d.set(vibrateOnButtonPress, forKey: "vibrate_on_button_press") } }
    var preventPhoneFromSleeping: Bool { didSet { d.set(preventPhoneFromSleeping, forKey: "prevent_phone_from_sleeping") } }

    private init() {
        theme = ThemeKind(rawValue: d.integer(forKey: "theme")) ?? .system
        customTextColor = UInt32(truncatingIfNeeded: d.object(forKey: "text_color") as? Int ?? 0xFF2D2D2D)
        customBackgroundColor = UInt32(truncatingIfNeeded: d.object(forKey: "background_color") as? Int ?? 0xFFFFFFFF)
        customPrimaryColor = UInt32(truncatingIfNeeded: d.object(forKey: "primary_color") as? Int ?? 0xFF106D1F)
        vibrateOnButtonPress = d.object(forKey: "vibrate_on_button_press") as? Bool ?? true
        preventPhoneFromSleeping = d.object(forKey: "prevent_phone_from_sleeping") as? Bool ?? true
    }

    // MARK: converter units ("converter_last_units.<key>" = "top,bottom")

    func lastConverterUnits(_ converter: Converter) -> (ConverterUnit, ConverterUnit)? {
        guard let stored = d.string(forKey: "converter_last_units.\(converter.key)") else { return nil }
        let parts = stored.split(separator: ",").compactMap { converter.unit(String($0)) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    func putLastConverterUnits(_ converter: Converter, top: ConverterUnit, bottom: ConverterUnit) {
        d.set("\(top.key),\(bottom.key)", forKey: "converter_last_units.\(converter.key)")
    }

    // MARK: calculator state and history (Android: saved instance state + Room "history" table)

    var calculatorState: CalculatorState? {
        get { d.data(forKey: "calculator_state").flatMap { try? JSONDecoder().decode(CalculatorState.self, from: $0) } }
        set { d.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "calculator_state") }
    }

    static let historyLimit = 20

    /// Newest first, at most `historyLimit` entries (CalculatorDao.getHistory).
    var history: [History] {
        get { d.data(forKey: "history").flatMap { try? JSONDecoder().decode([History].self, from: $0) } ?? [] }
        set { d.set(try? JSONEncoder().encode(Array(newValue.prefix(Config.historyLimit))), forKey: "history") }
    }
}
