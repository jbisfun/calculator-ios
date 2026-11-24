# calculator-ios

[Fossify Calculator](https://github.com/FossifyOrg/Calculator) re-created for iOS in SwiftUI.

    idl build -c release     # -> build/release/FossifyCalculator.ipa (ad-hoc signed; re-sign to install)
    idl install "<device>" FossifyCalculator

Ported: the calculator engine (CalculatorImpl, with Foundation `Decimal` in place of BigDecimal/EvalEx) with its portrait and landscape keypads, long-press C to reset, long-press minus to negate, long-press the formula/result to copy; history (last 20, tap to reuse, long-press to copy, clear); all nine unit converters with every upstream unit and the remembered unit pair; colors, vibrate on button press and prevent phone from sleeping; the home-screen calculator widget (4x4, resizable to 3x3, with AC, tap the display to open the app) and its configure screen (background color + transparency, text color).

Differences forced by iOS: the widget is available inside launcher-ios only (iOS home-screen widgets would need a WidgetKit extension), no in-app language switch, and converter icons are SF Symbols.

GPL-3.0, like the original.
