import Foundation
import Observation

/// MyWidgetProvider's side of the Calculator interface. Upstream keeps one CalculatorImpl in the
/// provider's companion object, shared by every placed widget and kept only in memory (dropped
/// when a widget is deleted); results still go to the shared history like the app's.
@MainActor
@Observable
final class WidgetCalculator: Calculator {
    static let shared = WidgetCalculator()

    var result = "0"
    var formula = ""
    /// Last toast (Android shows it as a system Toast; the widget draws it over itself).
    var message: String?
    @ObservationIgnored private(set) var calc: CalculatorImpl!

    private init() {
        calc = CalculatorImpl(calculator: self)
    }

    nonisolated func showNewResult(_ value: String) { MainActor.assumeIsolated { result = value } }
    nonisolated func showNewFormula(_ value: String) { MainActor.assumeIsolated { formula = value } }
    nonisolated func toast(_ value: String) { MainActor.assumeIsolated { message = value } }
    nonisolated func addHistory(_ entry: History) {
        MainActor.assumeIsolated { Config.shared.history.insert(entry, at: 0) }
    }
}

/// Widget colors (Config.widgetBgColor / widgetTextColor). Upstream keeps one pair for all widgets;
/// here each widget keeps its own under `HomeWidgetContext.key`, and the last saved pair seeds the
/// configure screen of the next widget, like upstream's shared values do.
enum WidgetColors {
    /// commons default_widget_bg_color (#AA000000).
    static let defaultBackground: UInt32 = 0xAA00_0000
    static let lastBackgroundKey = "calculator_widget_bg_color"
    static let lastTextKey = "calculator_widget_text_color"

    static func color(_ key: String) -> UInt32? {
        (UserDefaults.standard.object(forKey: key) as? Int).map { UInt32(truncatingIfNeeded: $0) }
    }

    static func save(background: UInt32, text: UInt32, bgKey: String, textKey: String) {
        let d = UserDefaults.standard
        d.set(Int(background), forKey: bgKey)
        d.set(Int(text), forKey: textKey)
        d.set(Int(background), forKey: lastBackgroundKey)
        d.set(Int(text), forKey: lastTextKey)
    }
}
