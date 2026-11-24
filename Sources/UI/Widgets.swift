import FossifyCommons
import SwiftUI

/// The Android home-screen widget (helpers/MyWidgetProvider.kt + res/xml/widget_info.xml), drawn by
/// launcher-ios on its home grid, with WidgetConfigureActivity as its configure screen.
public enum CalculatorWidgets {
    public static let all: [HomeWidgetKind] = [
        // targetCell 4x4; minResize 180dp (3 cells); resizeMode horizontal|vertical.
        HomeWidgetKind(
            id: "calculator.calculator",
            title: "Calculator",
            defaultSize: CGSize(width: 4, height: 4),
            minSize: CGSize(width: 3, height: 3),
            resizable: true,
            configure: { context, done in AnyView(CalculatorWidgetConfigure(context: context, done: done)) },
            content: { context in AnyView(CalculatorWidgetView(context: context)) }
        ),
    ]
}

/// The palette the app would use, without FossifyTheme's preferredColorScheme (the widget lives
/// inside the launcher's window).
private struct WidgetPalette: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.environment(\.palette, Palette.resolve(BaseConfig.shared, scheme: scheme))
    }
}

/// layout/widget.xml: widget_round_background tinted with the widget color behind view_calculator
/// with btn_reset (AC) visible; every text uses the widget text color at widget_text_size (26sp)
/// and the buttons have no background.
struct CalculatorWidgetFace: View {
    var formula: String
    var result: String
    var textColor: Color
    var background: Color
    var decimalSeparator: String
    var onKey: ((CalcKey?) -> Void)?
    var onDisplay: (() -> Void)?

    /// view_calculator.xml rows; nil is btn_reset ("AC").
    private static let rows: [[CalcKey?]] = [
        [.op(Key.percent), .op(Key.power), .op(Key.root), nil, .op(Key.divide)],
        [.digit(7), .digit(8), .digit(9), .op(Key.multiply)],
        [.digit(4), .digit(5), .digit(6), .op(Key.minus)],
        [.digit(1), .digit(2), .digit(3), .op(Key.plus)],
        [.digit(0), .decimal, .clear, .equals],
    ]

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / (2.1 + 1.8 + 2 * Double(Self.rows.count))
            VStack(spacing: 0) {
                display(formula, alignment: .bottomTrailing).frame(height: unit * 2.1)
                display(result, alignment: .trailing).frame(height: unit * 1.8)
                ForEach(Self.rows.indices, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(Self.rows[r].indices, id: \.self) { c in key(Self.rows[r][c]) }
                    }
                    .frame(height: unit * 2)
                }
            }
        }
        .foregroundStyle(textColor)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background))
        .environment(\.layoutDirection, .leftToRight)
    }

    private func display(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .light))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture { onDisplay?() }
    }

    private func key(_ key: CalcKey?) -> some View {
        Button {
            onKey?(key)
        } label: {
            Text(Self.title(key, decimal: decimalSeparator))
                .font(.system(size: 26, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedStyle())
        .padding(4)
        .allowsHitTesting(onKey != nil)
    }

    private static func title(_ key: CalcKey?, decimal: String) -> String {
        switch key {
        case nil: return "AC"
        case .digit(let n): return "\(n)"
        case .decimal: return decimal
        case .clear: return "C"
        case .equals: return "="
        case .op(let op):
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
    }
}

/// MyWidgetProvider: buttons drive the shared widget calculator, formula/result open the app.
struct CalculatorWidgetView: View {
    let context: HomeWidgetContext
    @State private var model = WidgetCalculator.shared
    @AppStorage private var bgColor: Int?
    @AppStorage private var textColor: Int?

    init(context: HomeWidgetContext) {
        self.context = context
        _bgColor = AppStorage(context.key("bg_color"))
        _textColor = AppStorage(context.key("text_color"))
    }

    var body: some View {
        Inner(model: model,
              background: bgColor.map { UInt32(truncatingIfNeeded: $0) } ?? WidgetColors.defaultBackground,
              text: textColor.map { UInt32(truncatingIfNeeded: $0) },
              openApp: { context.openApp(nil) })
            .modifier(WidgetPalette())
    }

    private struct Inner: View {
        @Environment(\.palette) private var palette
        @Bindable var model: WidgetCalculator
        let background: UInt32
        let text: UInt32?
        let openApp: () -> Void

        var body: some View {
            let calc = model.calc!
            CalculatorWidgetFace(
                formula: model.formula, result: model.result,
                textColor: text.map { Color(argb: $0) } ?? palette.primaryColor,
                background: Color(argb: background),
                decimalSeparator: calc.formatter.decimalSeparator,
                onKey: { key in
                    switch key {
                    case nil: calc.handleReset()
                    case .digit(let n): calc.numpadClicked(.digit(n))
                    case .decimal: calc.numpadClicked(.decimal)
                    case .op(let op): calc.handleOperation(op)
                    case .clear: calc.handleClear()
                    case .equals: calc.handleEquals()
                    }
                },
                onDisplay: openApp
            )
            .overlay(alignment: .bottom) {
                if let message = model.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.8)))
                        .padding(8)
                        .transition(.opacity)
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { model.message = nil }
                        }
                }
            }
            .animation(.default, value: model.message)
        }
    }
}

/// WidgetConfigureActivity / layout/widget_config.xml: a live preview ("15,937*5" = "79,685"),
/// background color + alpha seekbar, text color and OK.
struct CalculatorWidgetConfigure: View {
    let context: HomeWidgetContext
    let done: (Bool) -> Void

    var body: some View {
        Inner(context: context, done: done).modifier(WidgetPalette())
    }

    private enum Picker: Int, Identifiable {
        case background, text
        var id: Int { rawValue }
    }

    private struct Inner: View {
        @Environment(\.palette) private var palette
        let context: HomeWidgetContext
        let done: (Bool) -> Void

        @State private var loaded = false
        @State private var bgWithoutAlpha: UInt32 = 0xFF00_0000
        @State private var bgAlpha: Double = 0
        @State private var text: UInt32 = 0
        @State private var picker: Picker?

        private var bgColor: UInt32 {
            UInt32((bgAlpha * 255).rounded()) << 24 | (bgWithoutAlpha & 0xFFFFFF)
        }

        var body: some View {
            VStack(spacing: 0) {
                TopBar(title: "Calculator widget", onBack: { done(false) })
                VStack(spacing: 16) {
                    CalculatorWidgetFace(formula: "15,937*5", result: "79,685", textColor: Color(argb: text),
                                         background: Color(argb: bgColor),
                                         decimalSeparator: NumberFormat().decimalSeparator)
                        .frame(maxWidth: 420, maxHeight: .infinity)
                    HStack(spacing: 12) {
                        swatch(bgColor) { picker = .background }
                        Slider(value: $bgAlpha, in: 0...1)
                            .padding(.horizontal, 16)
                            .frame(maxHeight: .infinity)
                            .background(Capsule().fill(palette.surface))
                    }
                    .frame(height: 50)
                    HStack {
                        swatch(text) { picker = .text }
                        Spacer()
                        Button("OK") {
                            WidgetColors.save(background: bgColor, text: text,
                                              bgKey: context.key("bg_color"), textKey: context.key("text_color"))
                            done(true)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 28)
                        .frame(height: 50)
                        .background(Capsule().fill(palette.primaryColor))
                    }
                }
                .padding(16)
            }
            .background(palette.backgroundColor.ignoresSafeArea())
            .foregroundStyle(palette.textColor)
            .tint(palette.primaryColor)
            .onAppear(perform: load)
            .sheet(item: $picker) { which in
                switch which {
                case .background:
                    ColorPickerDialog(color: bgWithoutAlpha) { bgWithoutAlpha = $0 | 0xFF00_0000 }
                case .text:
                    ColorPickerDialog(color: text) { text = $0 | 0xFF00_0000 }
                }
            }
        }

        private func swatch(_ color: UInt32, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Circle()
                    .fill(Color(argb: color))
                    .overlay(Circle().stroke(palette.textColor.opacity(0.3), lineWidth: 1))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(PressedStyle())
        }

        /// initVariables(): this widget's colors when reconfiguring, else the last saved ones,
        /// else the defaults (#AA000000 background, primary color text).
        private func load() {
            guard !loaded else { return }
            loaded = true
            let bg = WidgetColors.color(context.key("bg_color"))
                ?? WidgetColors.color(WidgetColors.lastBackgroundKey) ?? WidgetColors.defaultBackground
            bgAlpha = Double(bg >> 24) / 255
            bgWithoutAlpha = bg | 0xFF00_0000
            text = WidgetColors.color(context.key("text_color"))
                ?? WidgetColors.color(WidgetColors.lastTextKey) ?? palette.primary
        }
    }
}
