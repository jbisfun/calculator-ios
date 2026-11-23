import Foundation

// Port of helpers/Constants.kt (calculator keys).
enum Key {
    static let digit = "digit"
    static let equals = "equals"
    static let plus = "plus"
    static let minus = "minus"
    static let multiply = "multiply"
    static let divide = "divide"
    static let percent = "percent"
    static let power = "power"
    static let root = "root"
    static let decimal = "decimal"
    static let clear = "clear"
    static let reset = "reset"
}

enum NumpadKey: Hashable {
    case digit(Int)
    case decimal
}

struct History: Codable, Hashable {
    var formula: String
    var result: String
    var timestamp: Double
}

/// helpers/Calculator.kt: what the engine reports back to its screen.
protocol Calculator: AnyObject {
    func showNewResult(_ value: String)
    func showNewFormula(_ value: String)
    func toast(_ message: String)
    func addHistory(_ entry: History)
}

/// Saved between launches (Android: onSaveInstanceState JSON).
struct CalculatorState: Codable {
    var res: String
    var previousCalculation: String
    var lastKey: String
    var lastOperation: String
    var baseValue: String
    var secondValue: String
    var inputDisplayedFormula: String
}

enum CalcError: Error { case invalid }

/// Port of helpers/CalculatorImpl.kt. Java BigDecimal + EvalEx -> Foundation Decimal.
final class CalculatorImpl {
    private weak var callback: Calculator?
    private var currentResult = "0"
    private var previousCalculation = ""
    private var baseValue: Decimal = 0
    private var secondValue: Decimal = 0
    private var inputDisplayedFormula = "0"
    private var lastKey = ""
    private var lastOperation = ""
    private let operations: Set<Character> = ["+", "-", "×", "÷", "^", "%", "√"]
    let formatter: NumberFormat

    private var decimalSeparator: String { formatter.decimalSeparator }
    private var groupingSeparator: String { formatter.groupingSeparator }

    init(calculator: Calculator, state: CalculatorState? = nil, formatter: NumberFormat = NumberFormat()) {
        callback = calculator
        self.formatter = formatter
        if let state { restore(state) }
        showNewResult(currentResult)
        showNewFormula(previousCalculation)
    }

    // MARK: helpers mirroring the Kotlin string ops

    private func isOperation(_ s: String) -> Bool { s.count == 1 && operations.contains(s.first!) }
    private func containsOperation(_ s: String) -> Bool { s.contains(where: { operations.contains($0) }) }

    /// `s.substring(s.indexOfAny(operations) + 1)`
    private func afterFirstOperation(_ s: String) -> String {
        guard let i = s.firstIndex(where: { operations.contains($0) }) else { return s }
        return String(s[s.index(after: i)...])
    }

    private func lastChar(_ s: String) -> String { s.last.map(String.init) ?? "" }

    private func format(_ d: Decimal) -> String { formatter.string(d) }
    private func removeGroupSeparator(_ s: String) -> String { formatter.removeGroupingSeparator(s) }

    // MARK: input

    private func addDigit(_ number: Int) {
        if inputDisplayedFormula == "0" {
            inputDisplayedFormula = ""
        }
        inputDisplayedFormula += String(number)
        addThousandsDelimiter()
        showNewResult(inputDisplayedFormula)
    }

    private func zeroClicked() {
        let valueToCheck = removeGroupSeparator(inputDisplayedFormula.trimStart("-"))
        let value = afterFirstOperation(valueToCheck)
        if value != "0" || value.contains(decimalSeparator) {
            addDigit(0)
        }
    }

    private func decimalClicked() {
        let valueToCheck = inputDisplayedFormula.trimStart("-").replacingOccurrences(of: groupingSeparator, with: "")
        let value = afterFirstOperation(valueToCheck)
        if !value.contains(decimalSeparator) {
            if value == "0" && !containsOperation(valueToCheck) {
                inputDisplayedFormula = "0" + decimalSeparator
            } else if value == "" {
                inputDisplayedFormula += "0" + decimalSeparator
            } else {
                inputDisplayedFormula += decimalSeparator
            }
        }
        lastKey = Key.decimal
        showNewResult(inputDisplayedFormula)
    }

    private func addThousandsDelimiter() {
        let numberChars = Set("0123456789" + decimalSeparator + groupingSeparator)
        let values = inputDisplayedFormula
            .split(whereSeparator: { !numberChars.contains($0) })
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for value in values {
            let formatted = formatter.formatForDisplay(value)
            inputDisplayedFormula = inputDisplayedFormula.replacingOccurrences(of: value, with: formatted)
        }
    }

    func handleOperation(_ operation: String) {
        if inputDisplayedFormula == "NaN" {
            inputDisplayedFormula = "0"
        }
        if inputDisplayedFormula == "" {
            inputDisplayedFormula = "0"
        }
        if operation == Key.root && inputDisplayedFormula == "0" {
            if lastKey != Key.digit {
                inputDisplayedFormula = "1√"
            }
        }

        let last = lastChar(inputDisplayedFormula)
        if last == decimalSeparator {
            inputDisplayedFormula = String(inputDisplayedFormula.dropLast())
        } else if isOperation(last) {
            inputDisplayedFormula = String(inputDisplayedFormula.dropLast()) + getSign(operation)
        } else if !containsOperation(inputDisplayedFormula.trimStart("-")) {
            inputDisplayedFormula += getSign(operation)
        }

        if lastKey == Key.digit || lastKey == Key.decimal {
            if lastOperation != "" && operation == Key.percent {
                handlePercent()
                lastOperation = ""
            } else {
                secondValue = getSecondValue()
                calculateResult()
                if !isOperation(lastChar(inputDisplayedFormula)) {
                    if !inputDisplayedFormula.contains("÷") {
                        inputDisplayedFormula += getSign(operation)
                    }
                }
            }
        }

        if getSecondValue() == 0 && inputDisplayedFormula.contains("÷") {
            lastKey = Key.divide
            lastOperation = Key.divide
        } else if operation != Key.percent {
            lastKey = operation
            lastOperation = operation
        }

        showNewResult(inputDisplayedFormula)
    }

    @discardableResult
    func turnToNegative() -> Bool {
        if inputDisplayedFormula.isEmpty {
            return false
        }
        let nonZero = Decimal.parse(removeGroupSeparator(inputDisplayedFormula)).map { $0 != 0 } ?? false
        if !containsOperation(inputDisplayedFormula.trimStart("-")) && nonZero {
            if inputDisplayedFormula.first == "-" {
                inputDisplayedFormula = String(inputDisplayedFormula.dropFirst())
            } else {
                inputDisplayedFormula = "-" + inputDisplayedFormula
            }
            showNewResult(inputDisplayedFormula)
            return true
        }
        return false
    }

    /// Cases like 10+200%.
    private func handlePercent() {
        let result = (try? calculatePercentage(baseValue, getSecondValue(), lastOperation)) ?? 0
        showNewFormula("\(format(baseValue))\(getSign(lastOperation))\(format(getSecondValue()))%")
        inputDisplayedFormula = format(result)
        showNewResult(format(result))
        baseValue = result
    }

    func handleEquals() {
        if lastKey == Key.equals {
            calculateResult()
        }
        if lastKey != Key.digit && lastKey != Key.decimal {
            return
        }

        secondValue = getSecondValue()
        calculateResult()
        if (lastOperation == Key.divide || lastOperation == Key.percent) && secondValue == 0 {
            lastKey = Key.digit
            return
        }
        lastKey = Key.equals
    }

    private func getSecondValue() -> Decimal {
        let valueToCheck = removeGroupSeparator(inputDisplayedFormula.trimStart("-"))
        var value = afterFirstOperation(valueToCheck)
        if value == "" {
            value = "0"
        }
        guard let d = Decimal.parse(value) else {
            callback?.toast("An error occurred: invalid number \"\(value)\"")
            return 0
        }
        return d
    }

    private func calculateResult() {
        if lastOperation == Key.root && inputDisplayedFormula.hasPrefix("√") {
            baseValue = 1
        }

        if lastKey != Key.equals {
            let valueToCheck = removeGroupSeparator(inputDisplayedFormula.trimStart("-"))
            if inputDisplayedFormula.hasPrefix("√") {
                let numberAfterRoot = String(valueToCheck.dropFirst())
                if let d = Decimal.parse(numberAfterRoot) {
                    secondValue = d
                } else {
                    callback?.toast("An error occurred: invalid number \"\(numberAfterRoot)\"")
                    secondValue = 0
                }
            } else {
                let parts = valueToCheck.split(whereSeparator: { operations.contains($0) }).map(String.init)
                if parts.isEmpty {
                    return
                }
                if let d = Decimal.parse(parts[0]) {
                    baseValue = d
                } else {
                    callback?.toast("An error occurred: invalid number \"\(parts[0])\"")
                }
                if inputDisplayedFormula.hasPrefix("-") {
                    baseValue = -baseValue
                }
                if parts.count > 1, let d = Decimal.parse(parts[1]) {
                    secondValue = d
                }
            }
        }

        if lastOperation != "" {
            let sign = getSign(lastOperation)
            // Like the original, operands go through the display formatter (15 fraction digits).
            let base = Decimal.parse(removeGroupSeparator(format(baseValue))) ?? baseValue
            let second = Decimal.parse(removeGroupSeparator(format(secondValue))) ?? secondValue

            if sign == "÷" && secondValue == 0 {
                callback?.toast("Error: division by zero")
                return
            }

            do {
                let result: Decimal
                if sign == "%" {
                    // 10%200: the percentage of the base value.
                    let percent = Decimal.parse(removeGroupSeparator(format(second / 100))) ?? 0
                    result = try checked(base * percent)
                } else {
                    result = try evaluate(base, sign, second)
                }

                showNewResult(format(result))
                let newFormula = "\(format(baseValue))\(sign)\(format(secondValue))"
                callback?.addHistory(History(formula: newFormula, result: format(result), timestamp: Date().timeIntervalSince1970))
                showNewFormula(newFormula)
                inputDisplayedFormula = format(result)
                baseValue = result
            } catch {
                callback?.toast("An unknown error occurred")
            }
        }
    }

    /// Replaces EvalEx's evaluation of "base<sign>second" (and "base*SQRT(second)").
    private func evaluate(_ a: Decimal, _ sign: String, _ b: Decimal) throws -> Decimal {
        switch sign {
        case "-": return try checked(a - b)
        case "×": return try checked(a * b)
        case "÷": return try checked(a / b)
        case "^": return try power(a, b)
        case "√": return try checked(a * squareRoot(b))
        default: return try checked(a + b)
        }
    }

    private func checked(_ d: Decimal) throws -> Decimal {
        if d.isNaN || !d.isFinite { throw CalcError.invalid }
        return d
    }

    private func power(_ a: Decimal, _ b: Decimal) throws -> Decimal {
        if b.isInteger, let n = Int(exactly: NSDecimalNumber(decimal: b).int64Value), abs(n) <= 999_999_999,
           Decimal(n) == b {
            if n >= 0 { return try checked(pow(a, n)) }
            if a == 0 { throw CalcError.invalid }
            return try checked(1 / pow(a, -n))
        }
        let r = Foundation.pow(NSDecimalNumber(decimal: a).doubleValue, NSDecimalNumber(decimal: b).doubleValue)
        guard r.isFinite, let d = Decimal.parse(String(r)) ?? Optional(Decimal(r)) else { throw CalcError.invalid }
        return try checked(d)
    }

    /// Double estimate refined with Newton steps in Decimal (EvalEx's SQRT is high precision).
    private func squareRoot(_ b: Decimal) throws -> Decimal {
        if b < 0 { throw CalcError.invalid }
        if b == 0 { return 0 }
        let guess = Foundation.sqrt(NSDecimalNumber(decimal: b).doubleValue)
        var x = Decimal.parse(String(guess)) ?? Decimal(guess)
        for _ in 0..<3 { x = (x + b / x) / 2 }
        return try checked(x)
    }

    private func calculatePercentage(_ baseValue: Decimal, _ secondValue: Decimal, _ sign: String) throws -> Decimal {
        if secondValue == 0 {
            throw CalcError.invalid
        }
        switch sign {
        case Key.multiply:
            return baseValue / (100 / secondValue)
        case Key.divide:
            return baseValue * (100 / secondValue)
        case Key.plus:
            return baseValue + baseValue / (100 / secondValue)
        case Key.minus:
            return baseValue - baseValue / (100 / secondValue)
        case Key.percent:
            let remainder = baseValue - (baseValue / secondValue).truncated * secondValue
            return remainder / 100
        default:
            return baseValue / (100 * secondValue)
        }
    }

    private func showNewResult(_ value: String) {
        currentResult = value
        callback?.showNewResult(value)
    }

    private func showNewFormula(_ value: String) {
        previousCalculation = value
        callback?.showNewFormula(value)
    }

    func handleClear() {
        let lastDeletedValue = lastChar(inputDisplayedFormula)

        var newValue = String(inputDisplayedFormula.dropLast())
        if newValue == "" || newValue == "0" {
            newValue = "0"
            lastKey = Key.clear
            resetValues()
        } else {
            if isOperation(lastDeletedValue) || lastKey == Key.equals {
                lastOperation = ""
            }
            let lastValue = lastChar(newValue)
            if isOperation(lastValue) {
                lastKey = Key.clear
            } else if lastValue == decimalSeparator {
                lastKey = Key.decimal
            } else {
                lastKey = Key.digit
            }
        }

        if let g = groupingSeparator.first {
            newValue = newValue.trimEnd(g)
        }
        inputDisplayedFormula = newValue
        addThousandsDelimiter()
        showNewResult(inputDisplayedFormula)
    }

    func handleReset() {
        resetValues()
        showNewResult("0")
        showNewFormula("")
        inputDisplayedFormula = ""
    }

    private func resetValues() {
        baseValue = 0
        secondValue = 0
        lastKey = ""
        lastOperation = ""
    }

    private func getSign(_ operation: String) -> String {
        switch operation {
        case Key.minus: return "-"
        case Key.multiply: return "×"
        case Key.divide: return "÷"
        case Key.percent: return "%"
        case Key.power: return "^"
        case Key.root: return "√"
        default: return "+"
        }
    }

    func numpadClicked(_ key: NumpadKey) {
        if inputDisplayedFormula == "NaN" {
            inputDisplayedFormula = ""
        }
        if lastKey == Key.equals {
            lastOperation = Key.equals
        }
        lastKey = Key.digit

        switch key {
        case .decimal: decimalClicked()
        case .digit(0): zeroClicked()
        case .digit(let n): addDigit(n)
        }
    }

    func addNumberToFormula(_ number: String) {
        handleReset()
        inputDisplayedFormula = number
        addThousandsDelimiter()
        showNewResult(inputDisplayedFormula)
    }

    var state: CalculatorState {
        CalculatorState(
            res: currentResult,
            previousCalculation: previousCalculation,
            lastKey: lastKey,
            lastOperation: lastOperation,
            baseValue: "\(baseValue)",
            secondValue: "\(secondValue)",
            inputDisplayedFormula: inputDisplayedFormula
        )
    }

    private func restore(_ s: CalculatorState) {
        currentResult = s.res
        previousCalculation = s.previousCalculation
        lastKey = s.lastKey
        lastOperation = s.lastOperation
        baseValue = Decimal.parse(s.baseValue) ?? 0
        secondValue = Decimal.parse(s.secondValue) ?? 0
        inputDisplayedFormula = s.inputDisplayedFormula
    }
}
