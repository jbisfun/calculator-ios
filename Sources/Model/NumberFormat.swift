import Foundation

/// Port of NumberFormatHelper: Decimal <-> locale-formatted strings.
struct NumberFormat {
    static let maxFractionDigits = 15

    let locale: Locale
    let decimalSeparator: String
    let groupingSeparator: String

    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
        decimalSeparator = locale.decimalSeparator ?? "."
        groupingSeparator = locale.groupingSeparator ?? ","
    }

    func string(_ value: Decimal) -> String {
        value.formatted(
            .number.locale(locale)
                .precision(.fractionLength(0...NumberFormat.maxFractionDigits))
                .grouping(.automatic)
        )
        .replacingOccurrences(of: "\u{2212}", with: "-")
    }

    func addGroupingSeparators(_ str: String) -> String {
        guard let value = Decimal.parse(removeGroupingSeparator(str)) else { return str }
        return string(value)
    }

    func removeGroupingSeparator(_ str: String) -> String {
        str.replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
    }

    /// Keeps what was typed after the decimal separator (e.g. "0.00" while entering 0.003).
    func formatForDisplay(_ input: String) -> String {
        var formatted = addGroupingSeparators(input)
        if input.contains(decimalSeparator) {
            let firstPart = formatted.substringBefore(decimalSeparator)
            let lastPart = input.substringAfter(decimalSeparator)
            formatted = firstPart + decimalSeparator + lastPart
        }
        return formatted
    }
}

extension Decimal {
    /// Strict parse of a plain "." number like java.math.BigDecimal(String); nil on any junk.
    static func parse(_ s: String) -> Decimal? {
        guard s.wholeMatch(of: #/[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/#) != nil else { return nil }
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Integer part, rounded toward zero.
    var truncated: Decimal {
        var src = self < 0 ? -self : self
        var out = Decimal()
        NSDecimalRound(&out, &src, 0, .down)
        return self < 0 ? -out : out
    }

    var isInteger: Bool { self == truncated }
}

extension String {
    func substringBefore(_ sep: String) -> String {
        guard let r = range(of: sep) else { return self }
        return String(self[..<r.lowerBound])
    }

    func substringAfter(_ sep: String) -> String {
        guard let r = range(of: sep) else { return self }
        return String(self[r.upperBound...])
    }

    func trimStart(_ c: Character) -> String { String(drop(while: { $0 == c })) }

    func trimEnd(_ c: Character) -> String {
        var s = Substring(self)
        while s.last == c { s = s.dropLast() }
        return String(s)
    }
}
