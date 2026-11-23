import SwiftUI

/// UnitConverterPickerActivity.
struct UnitConverterPickerView: View {
    @Environment(Router.self) private var router
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Unit converter")
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(Converter.all) { converter in
                        Button { router.push(.converter(converter.key)) } label: {
                            VStack(spacing: 8) {
                                Image(systemName: converter.icon)
                                    .font(.system(size: 30))
                                    .foregroundStyle(palette.primaryColor)
                                    .frame(height: 40)
                                Text(converter.name)
                                    .font(.system(size: 15))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(palette.textColor)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.divider, lineWidth: 1))
                        }
                        .buttonStyle(PressedStyle())
                    }
                }
                .padding(16)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}

/// UnitConverterActivity + views/ConverterView.kt.
struct UnitConverterView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    let converter: Converter
    @State private var state: ConverterState
    @State private var picking: PickTarget?

    init(converter: Converter) {
        self.converter = converter
        let stored = Config.shared.lastConverterUnits(converter)
        _state = State(initialValue: ConverterState(converter: converter, top: stored?.0, bottom: stored?.1))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            VStack(spacing: 0) {
                TopBar(title: converter.name, onBack: nil, background: nil, tint: nil) {
                    if landscape {
                        IconButton(icon: "arrow.up.arrow.down") { swap() }
                    }
                }
                if landscape {
                    HStack(spacing: 0) {
                        converterView(swapButton: false).frame(maxWidth: .infinity)
                        keypad.frame(maxWidth: .infinity)
                    }
                } else {
                    converterView(swapButton: true).frame(height: (geo.size.height - 56) * 0.42)
                    keypad
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(item: $picking) { target in
            RadioDialog(title: nil, items: converter.units.map { ($0, $0.nameWithSymbol) },
                        selected: target == .top ? state.topUnit : state.bottomUnit) { unit in
                state.select(unit, top: target == .top)
                save()
            }
        }
    }

    private func converterView(swapButton: Bool) -> some View {
        VStack(spacing: 0) {
            unitHolder(top: true)
                .background(palette.primaryColor.opacity(0.12))
            if swapButton {
                Button(action: swap) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 24))
                        .foregroundStyle(palette.primaryColor)
                        .frame(width: 64, height: 48)
                }
            } else {
                Spacer().frame(height: 8)
            }
            unitHolder(top: false)
        }
    }

    private func unitHolder(top: Bool) -> some View {
        let unit = top ? state.topUnit : state.bottomUnit
        let text = top ? state.topText : state.bottomText
        return VStack(alignment: .leading, spacing: 4) {
            Button { picking = top ? .top : .bottom } label: {
                HStack(spacing: 4) {
                    Text(unit.name).font(.system(size: 18))
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 10)).foregroundStyle(palette.primaryColor)
                }
                .foregroundStyle(palette.textColor)
            }
            HStack(spacing: 12) {
                Text(text)
                    .font(.system(size: 40, weight: .light))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(unit.symbol)
                    .font(.system(size: 18))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 40, minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.primaryColor.opacity(90.0 / 255)))
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { picking = top ? .top : .bottom }
        .onLongPressGesture { router.toast = Device.copy(text) }
    }

    /// view_unit_converter.xml keypad.
    private var keypad: some View {
        let decimal = NumberFormat().decimalSeparator
        return VStack(spacing: 0) {
            ForEach([[7, 8, 9], [4, 5, 6], [1, 2, 3]], id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { n in
                        PillButton(title: "\(n)") { state.numpadClicked(.digit(n)) }
                    }
                }
            }
            HStack(spacing: 0) {
                PillButton(title: "0") { state.numpadClicked(.digit(0)) }
                PillButton(title: decimal, strong: true) { state.numpadClicked(.decimal) }
                PillButton(title: "C", strong: true, onLongPress: { state.clear() }) { state.deleteCharacter() }
            }
            if state.showsNegativeButton {
                PillButton(title: "+/-", strong: true) { state.toggleNegative() }
                    .frame(height: 72)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func swap() {
        state.swap()
        save()
    }

    private func save() {
        config.putLastConverterUnits(converter, top: state.topUnit, bottom: state.bottomUnit)
    }
}

enum PickTarget: Identifiable {
    case top, bottom
    var id: Self { self }
}
