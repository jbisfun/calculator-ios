import FossifyCommons
import Observation
import SwiftUI

/// MainActivity's side of the Calculator interface: holds what the screen shows.
@MainActor
@Observable
final class CalculatorModel: Calculator {
    var result = "0"
    var formula = ""
    @ObservationIgnored var onToast: ((String) -> Void)?
    @ObservationIgnored private(set) var calc: CalculatorImpl!

    init() {
        calc = CalculatorImpl(calculator: self, state: Config.shared.calculatorState)
    }

    nonisolated func showNewResult(_ value: String) { MainActor.assumeIsolated { result = value } }
    nonisolated func showNewFormula(_ value: String) { MainActor.assumeIsolated { formula = value } }
    nonisolated func toast(_ message: String) { MainActor.assumeIsolated { onToast?(message) } }
    nonisolated func addHistory(_ entry: History) {
        MainActor.assumeIsolated { Config.shared.history.insert(entry, at: 0) }
    }

    func save() { Config.shared.calculatorState = calc.state }
}

enum CalcKey: Hashable {
    case digit(Int)
    case decimal
    case op(String)
    case clear
    case equals

    /// view_calculator.xml (portrait; AC is hidden upstream, long-press C instead).
    static let portrait: [[CalcKey]] = [
        [.op(Key.percent), .op(Key.power), .op(Key.root), .op(Key.divide)],
        [.digit(7), .digit(8), .digit(9), .op(Key.multiply)],
        [.digit(4), .digit(5), .digit(6), .op(Key.minus)],
        [.digit(1), .digit(2), .digit(3), .op(Key.plus)],
        [.digit(0), .decimal, .clear, .equals],
    ]

    /// layout-land/activity_main.xml.
    static let landscape: [[CalcKey]] = [
        [.digit(7), .digit(8), .digit(9), .op(Key.divide), .clear],
        [.digit(4), .digit(5), .digit(6), .op(Key.multiply), .op(Key.root)],
        [.digit(1), .digit(2), .digit(3), .op(Key.minus), .op(Key.power)],
        [.digit(0), .decimal, .equals, .op(Key.plus), .op(Key.percent)],
    ]
}

/// MainActivity.
struct MainView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var phase
    @State private var model = CalculatorModel()
    @State private var history: [History]?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                CloseAppButton()
                Spacer()
                IconButton(icon: "clock.arrow.circlepath") { showHistory() }
                IconButton(icon: "ruler") { router.push(.unitConverterPicker) }
                IconButton(icon: "gearshape") { router.push(.settings) }
                Menu {
                    Button("About") { router.push(.about) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 19)).frame(width: 44, height: 48)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 56)

            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                let rows = landscape ? CalcKey.landscape : CalcKey.portrait
                let total = 2.1 + 1.8 + 2.0 * Double(rows.count)
                let unit = geo.size.height / total
                VStack(spacing: 0) {
                    Text(model.formula)
                        .font(.system(size: 20, weight: .light))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.horizontal, 16)
                        .frame(height: unit * 2.1)
                        .contentShape(Rectangle())
                        .onLongPressGesture { copy(model.formula) }
                    Text(model.result)
                        .font(.system(size: landscape ? 40 : 56, weight: .light))
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                        .frame(height: unit * 1.8)
                        .contentShape(Rectangle())
                        .onLongPressGesture { copy(model.result) }
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(row, id: \.self) { key in button(key, size: landscape ? 26 : 34) }
                        }
                        .frame(height: unit * 2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { model.onToast = { router.toast = $0 } }
        .onChange(of: phase) { if phase != .active { model.save() } }
        .sheet(item: Binding(get: { history.map(HistoryList.init) }, set: { history = $0?.items })) { list in
            HistoryDialog(items: list.items) { model.calc.addNumberToFormula($0) }
        }
    }

    @ViewBuilder
    private func button(_ key: CalcKey, size: CGFloat) -> some View {
        let calc = model.calc!
        switch key {
        case .digit(let n):
            PillButton(title: "\(n)", fontSize: size) { calc.numpadClicked(.digit(n)) }
        case .decimal:
            PillButton(title: calc.formatter.decimalSeparator, strong: true, fontSize: size) { calc.numpadClicked(.decimal) }
        case .op(let op):
            PillButton(title: Self.sign(op), strong: true, fontSize: size,
                       onLongPress: op == Key.minus ? { calc.turnToNegative() } : nil) {
                calc.handleOperation(op)
            }
        case .clear:
            PillButton(title: "C", strong: true, fontSize: size, onLongPress: { calc.handleReset() }) { calc.handleClear() }
        case .equals:
            PillButton(title: "=", strong: true, fontSize: size) { calc.handleEquals() }
        }
    }

    private static func sign(_ op: String) -> String {
        switch op {
        case Key.percent: return "%"
        case Key.power: return "^"
        case Key.root: return "√"
        case Key.divide: return "÷"
        case Key.multiply: return "×"
        case Key.minus: return "-"
        default: return "+"
        }
    }

    private func copy(_ value: String) {
        guard !value.isEmpty else { return }
        router.toast = Launcher.copy(value)
    }

    private func showHistory() {
        let items = Config.shared.history
        if items.isEmpty {
            router.toast = "History is empty"
        } else {
            history = items
        }
    }
}

struct HistoryList: Identifiable {
    let items: [History]
    var id: Int { items.hashValue }
}

/// dialogs/HistoryDialog.kt + adapters/HistoryAdapter.kt.
struct HistoryDialog: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let items: [History]
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogFrame(title: "History") {
                ForEach(items, id: \.self) { item in
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.formula).font(.system(size: 18)).foregroundStyle(palette.secondaryText)
                        Text(item.result).font(.system(size: 22))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onPick(item.result)
                        dismiss()
                    }
                    .onLongPressGesture { router.toast = Launcher.copy(item.result) }
                }
            }
            HStack(spacing: 24) {
                Button("Clear") {
                    Config.shared.history = []
                    router.toast = "History has been cleared"
                    dismiss()
                }
                Spacer()
                Button("OK") { dismiss() }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.primaryColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(palette.surface.ignoresSafeArea())
        }
    }
}
