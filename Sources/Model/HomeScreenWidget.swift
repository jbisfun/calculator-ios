import FossifyCommons
import Foundation

/// The iOS home-screen calculator widget (fossify-ios/widgets-ios): the extension runs
/// `CalculatorWidgetEngine.press` for every key (an App Intent in its own process), so the widget
/// calculator lives in the launcher's app group instead of MyWidgetProvider's memory.
public enum CalculatorWidgetEngine {
    private static let key = "calculator_widget"
    private static let historyKey = "calculator_widget_pending_history"

    /// The current display (also what the widget shows before any key press).
    public static func snapshot() -> CalculatorWidgetSnapshot {
        WidgetBridge.load(CalculatorWidgetSnapshot.self, key) ?? CalculatorWidgetSnapshot(decimalSeparator: NumberFormat().decimalSeparator)
    }

    /// Applies one widget key (view_calculator ids: "digit0"..."digit9", "decimal", "plus", "minus",
    /// "multiply", "divide", "percent", "power", "root", "clear", "reset", "equals").
    @discardableResult
    public static func press(_ name: String) -> CalculatorWidgetSnapshot {
        let old = snapshot()
        let state = old.state.isEmpty ? nil : try? JSONDecoder().decode(CalculatorState.self, from: Data(old.state.utf8))
        let sink = Sink()
        let calc = CalculatorImpl(calculator: sink, state: state)
        switch name {
        case _ where name.hasPrefix(Key.digit): calc.numpadClicked(.digit(Int(name.dropFirst(Key.digit.count)) ?? 0))
        case Key.decimal: calc.numpadClicked(.decimal)
        case Key.clear: calc.handleClear()
        case Key.reset: calc.handleReset()
        case Key.equals: calc.handleEquals()
        default: calc.handleOperation(name)
        }
        let json = (try? JSONEncoder().encode(calc.state)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let new = CalculatorWidgetSnapshot(formula: sink.formula, result: sink.result, state: json,
                                           decimalSeparator: calc.formatter.decimalSeparator, message: sink.message)
        WidgetBridge.save(new, key)
        if !sink.history.isEmpty, let d = WidgetBridge.defaults {
            let pending = (d.data(forKey: historyKey).flatMap { try? JSONDecoder().decode([History].self, from: $0) } ?? [])
            d.set(try? JSONEncoder().encode(sink.history + pending), forKey: historyKey)
        }
        return new
    }

    /// Moves results calculated on the widget into the app's history (CalculatorDao.insertOrUpdate).
    @MainActor
    static func mergePendingHistory() {
        guard let d = WidgetBridge.defaults, let data = d.data(forKey: historyKey),
              let pending = try? JSONDecoder().decode([History].self, from: data), !pending.isEmpty else { return }
        d.removeObject(forKey: historyKey)
        Config.shared.history = pending + Config.shared.history
    }

    private final class Sink: Calculator {
        var result = "0"
        var formula = ""
        var message: String?
        var history: [History] = []

        func showNewResult(_ value: String) { result = value }
        func showNewFormula(_ value: String) { formula = value }
        func toast(_ value: String) { message = value }
        func addHistory(_ entry: History) { history.insert(entry, at: 0) }
    }
}

/// launcher-ios hooks for the home-screen widget.
public enum CalculatorWidgetData {
    /// Call once at launch (LauncherApp.init): keeps widget results in the app's history.
    @MainActor
    public static func install() {
        CalculatorWidgetEngine.mergePendingHistory()
        NotificationCenter.default.addObserver(forName: Notification.Name("UIApplicationWillEnterForegroundNotification"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CalculatorWidgetEngine.mergePendingHistory() }
        }
    }

    /// `fossify://open/calculator`: nothing to restore, the app opens as it was.
    @MainActor
    public static func handle(_ url: URL) {}
}
