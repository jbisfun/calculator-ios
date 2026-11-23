import Foundation

/// Port of views/ConverterView.kt's logic (the view itself lives in UnitConverterView).
struct ConverterState: Equatable {
    let converter: Converter
    var topUnit: ConverterUnit
    var bottomUnit: ConverterUnit
    var topText = "0"
    var bottomText = "0"
    let formatter: NumberFormat

    static func == (a: Self, b: Self) -> Bool {
        a.converter == b.converter && a.topUnit == b.topUnit && a.bottomUnit == b.bottomUnit
            && a.topText == b.topText && a.bottomText == b.bottomText
    }

    init(converter: Converter, top: ConverterUnit? = nil, bottom: ConverterUnit? = nil, formatter: NumberFormat = NumberFormat()) {
        self.converter = converter
        self.formatter = formatter
        topUnit = top ?? converter.defaultTopUnit
        bottomUnit = bottom ?? converter.defaultBottomUnit
        updateBottomValue()
    }

    private var decimalSeparator: String { formatter.decimalSeparator }

    /// UnitConverterActivity.onUnitsChanged: +/- only for temperatures that can go below zero.
    var showsNegativeButton: Bool {
        converter.isTemperature && topUnit.key != "Kelvin" && topUnit.key != "Rankine"
    }

    mutating func clear() {
        topText = "0"
        updateBottomValue()
    }

    mutating func deleteCharacter() {
        let current = topText
        if current.count == 1 {
            topText = "0"
        } else if current.hasPrefix("-") && current.count == 2 {
            topText = "0"
        } else {
            var newValue = String(current.dropLast())
            if let g = formatter.groupingSeparator.first {
                newValue = newValue.trimEnd(g)
            }
            if newValue == "-" || newValue.isEmpty {
                newValue = "0"
            }
            let value = Decimal.parse(formatter.removeGroupingSeparator(newValue)) ?? 0
            topText = formatter.string(value)
        }
        updateBottomValue()
    }

    mutating func numpadClicked(_ key: NumpadKey) {
        switch key {
        case .decimal: decimalClicked()
        case .digit(0): zeroClicked()
        case .digit(let n): addDigit(n)
        }
        updateBottomValue()
    }

    private mutating func decimalClicked() {
        var value = topText
        if !value.contains(decimalSeparator) {
            switch value {
            case "0": value = "0" + decimalSeparator
            case "": value += "0" + decimalSeparator
            default: value += decimalSeparator
            }
            topText = value
        }
    }

    private mutating func zeroClicked() {
        if topText != "0" || topText.contains(decimalSeparator) {
            addDigit(0)
        }
    }

    private mutating func addDigit(_ digit: Int) {
        var value = topText
        if value == "0" {
            value = String(digit)
        } else {
            value += String(digit)
        }
        topText = formatter.formatForDisplay(value)
    }

    mutating func swap() {
        (topUnit, bottomUnit) = (bottomUnit, topUnit)
        updateBottomValue()
    }

    /// RadioGroupDialog callback in setClickListenerForUnitSelector.
    mutating func select(_ unit: ConverterUnit, top: Bool) {
        let other = top ? bottomUnit : topUnit
        let current = top ? topUnit : bottomUnit
        if unit == other {
            swap()
        } else if unit != current {
            if top { topUnit = unit } else { bottomUnit = unit }
            updateBottomValue()
        }
    }

    mutating func toggleNegative() {
        var value = topText
        if value == "0" {
            value = "-"
        } else if value.hasPrefix("-") {
            value = String(value.dropFirst())
        } else {
            value = "-" + value
        }
        topText = value
        updateBottomValue()
    }

    mutating func updateBottomValue() {
        let clamped = checkTemperatureLimits(topText)
        if clamped != topText {
            topText = clamped
        }
        let topValue = Decimal.parse(formatter.removeGroupingSeparator(clamped)) ?? 0

        if converter.isTemperature && (topUnit.key == "Kelvin" || topUnit.key == "Rankine") && topValue < 0 {
            topText = "0"
            return
        }

        bottomText = formatter.string(converter.convert(topValue, from: topUnit, to: bottomUnit))
    }

    private func checkTemperatureLimits(_ value: String) -> String {
        guard converter.isTemperature, let n = Decimal.parse(formatter.removeGroupingSeparator(value)) else { return value }
        switch topUnit.key {
        case "Celsius":
            let min = Decimal.parse("-273.15")!
            return n < min ? formatter.string(min) : value
        case "Fahrenheit":
            let min = Decimal.parse("-459.67")!
            return n < min ? formatter.string(min) : value
        case "Kelvin", "Rankine":
            return n < 0 ? "0" : value
        default:
            return value
        }
    }
}
