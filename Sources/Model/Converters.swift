import Foundation

/// Exact decimal factor literal ("0.3048", .ratio("1000", "3600")) like the BigDecimal factors upstream.
struct Factor: ExpressibleByStringLiteral {
    let value: Decimal
    init(stringLiteral s: String) { value = Decimal.parse(s)! }
    init(_ value: Decimal) { self.value = value }
    static let one = Factor(1)
    static func ratio(_ a: Factor, _ b: Factor) -> Factor { Factor(a.value / b.value) }
    static func product(_ a: Factor, _ b: Factor) -> Factor { Factor(a.value * b.value) }
}

/// Port of converters/Base.kt Converter.Unit (+ TemperatureConverter's offset units).
struct ConverterUnit: Identifiable, Hashable {
    enum Kind { case linear, celsius, fahrenheit }

    let key: String
    let name: String
    let symbol: String
    let factor: Decimal
    var kind: Kind = .linear

    init(key: String, name: String, symbol: String, factor: Factor, kind: Kind = .linear) {
        self.key = key
        self.name = name
        self.symbol = symbol
        self.factor = factor.value
        self.kind = kind
    }

    var id: String { key }
    var nameWithSymbol: String { "\(name) (\(symbol))" }

    private static let kelvinOffset: Decimal = Decimal.parse("273.15")!
    private static let celsiusOffset: Decimal = 32

    func toBase(_ value: Decimal) -> Decimal {
        switch kind {
        case .linear: return value * factor
        case .celsius: return value + Self.kelvinOffset
        case .fahrenheit: return (value - Self.celsiusOffset) / factor + Self.kelvinOffset
        }
    }

    func fromBase(_ value: Decimal) -> Decimal {
        switch kind {
        case .linear: return value / factor
        case .celsius: return value - Self.kelvinOffset
        case .fahrenheit: return (value - Self.kelvinOffset) * factor + Self.celsiusOffset
        }
    }
}

/// Port of converters/*.kt (unit tables generated from the upstream sources).
struct Converter: Identifiable, Hashable {
    let key: String
    let name: String
    /// SF Symbol standing in for the upstream vector drawable.
    let icon: String
    let units: [ConverterUnit]
    let defaultTop: String
    let defaultBottom: String

    var id: String { key }
    var defaultTopUnit: ConverterUnit { unit(defaultTop)! }
    var defaultBottomUnit: ConverterUnit { unit(defaultBottom)! }
    var isTemperature: Bool { key == "TemperatureConverter" }

    func unit(_ key: String) -> ConverterUnit? { units.first { $0.key == key } }

    func convert(_ value: Decimal, from: ConverterUnit, to: ConverterUnit) -> Decimal {
        to.fromBase(from.toBase(value))
    }

    static let all: [Converter] = [length, area, volume, mass, temperature, time, speed, pressure, energy]

    static let length = Converter(
        key: "LengthConverter", name: "Length", icon: "ruler",
        units: [
            ConverterUnit(key: "Kilometer", name: "Kilometer", symbol: "km", factor: "1000"),
            ConverterUnit(key: "Meter", name: "Meter", symbol: "m", factor: .one),
            ConverterUnit(key: "Centimeter", name: "Centimeter", symbol: "cm", factor: "0.01"),
            ConverterUnit(key: "Millimeter", name: "Millimeter", symbol: "mm", factor: "0.001"),
            ConverterUnit(key: "Micrometer", name: "Micrometer", symbol: "μm", factor: "0.000001"),
            ConverterUnit(key: "Nanometer", name: "Nanometer", symbol: "nm", factor: "0.000000001"),
            ConverterUnit(key: "Angstrom", name: "Angstrom", symbol: "Å", factor: "0.0000000001"),
            ConverterUnit(key: "Mile", name: "Mile", symbol: "mi", factor: "1609.344"),
            ConverterUnit(key: "Yard", name: "Yard", symbol: "yd", factor: "0.9144"),
            ConverterUnit(key: "Foot", name: "Foot", symbol: "ft", factor: "0.3048"),
            ConverterUnit(key: "Inch", name: "Inch", symbol: "in", factor: "0.0254"),
            ConverterUnit(key: "Fathom", name: "Fathom", symbol: "fathom", factor: "1.852"),
            ConverterUnit(key: "NauticalMile", name: "Nautical Mile", symbol: "NM", factor: "1852"),
            ConverterUnit(key: "AstronomicalUnit", name: "Astronomical Unit", symbol: "au", factor: "149597870700"),
            ConverterUnit(key: "Parsec", name: "Parsec", symbol: "pc", factor: "30856775814913673"),
            ConverterUnit(key: "LightYear", name: "Light Year", symbol: "ly", factor: "9460730472580800"),
        ],
        defaultTop: "Kilometer", defaultBottom: "Meter"
    )

    static let area = Converter(
        key: "AreaConverter", name: "Area", icon: "cube",
        units: [
            ConverterUnit(key: "SquareKilometer", name: "Square Kilometer", symbol: "km²", factor: "1000000"),
            ConverterUnit(key: "SquareMeter", name: "Square Meter", symbol: "m²", factor: .one),
            ConverterUnit(key: "SquareCentimeter", name: "Square Centimeter", symbol: "cm²", factor: "0.0001"),
            ConverterUnit(key: "SquareMillimeter", name: "Square Millimeter", symbol: "mm²", factor: "0.000001"),
            ConverterUnit(key: "SquareMile", name: "Square Mile", symbol: "sq mi", factor: "2589988.110336"),
            ConverterUnit(key: "SquareYard", name: "Square Yard", symbol: "sq yd", factor: "0.83612736"),
            ConverterUnit(key: "SquareFoot", name: "Square Foot", symbol: "sq ft", factor: "0.09290304"),
            ConverterUnit(key: "SquareInch", name: "Square Inch", symbol: "sq in", factor: "0.00064516"),
            ConverterUnit(key: "Acre", name: "Acre", symbol: "ac", factor: "4046.8564224"),
            ConverterUnit(key: "Hectare", name: "Hectare", symbol: "ha", factor: "10000"),
        ],
        defaultTop: "SquareKilometer", defaultBottom: "SquareMeter"
    )

    static let volume = Converter(
        key: "VolumeConverter", name: "Volume", icon: "drop",
        units: [
            ConverterUnit(key: "CubicMeter", name: "Cubic Meter", symbol: "m³", factor: .one),
            ConverterUnit(key: "CubicDecimeter", name: "Cubic Decimeter", symbol: "dm³", factor: "0.001"),
            ConverterUnit(key: "CubicCentimeter", name: "Cubic Centimeter", symbol: "cm³", factor: "0.000001"),
            ConverterUnit(key: "CubicMillimeter", name: "Cubic Millimeter", symbol: "mm³", factor: "0.000000001"),
            ConverterUnit(key: "Liter", name: "Liter", symbol: "L", factor: "0.001"),
            ConverterUnit(key: "Centiliter", name: "Centiliter", symbol: "cL", factor: "0.00001"),
            ConverterUnit(key: "Deciliter", name: "Deciliter", symbol: "dL", factor: "0.0001"),
            ConverterUnit(key: "Milliliter", name: "Milliliter", symbol: "mL", factor: "0.000001"),
            ConverterUnit(key: "AcreFoot", name: "Acre Foot", symbol: "ac ft", factor: "1233.48183754752"),
            ConverterUnit(key: "CubicFoot", name: "Cubic Foot", symbol: "ft³", factor: "0.028316846592"),
            ConverterUnit(key: "CubicInch", name: "Cubic Inch", symbol: "in³", factor: "0.000016387064"),
            ConverterUnit(key: "BarrelUS", name: "Barrel (US)", symbol: "fl bl (US)", factor: "0.119240471196"),
            ConverterUnit(key: "GallonUS", name: "Gallon (US)", symbol: "gal (US)", factor: "0.003785411784"),
            ConverterUnit(key: "QuartUS", name: "Quart (US)", symbol: "qt (US)", factor: "0.000946352946"),
            ConverterUnit(key: "PintUS", name: "Pint (US)", symbol: "pt (US fl)", factor: "0.000473176473"),
            ConverterUnit(key: "LegalCupUS", name: "Legal Cup (US)", symbol: "cup (US)", factor: "0.00024"),
            ConverterUnit(key: "CustomaryCupUS", name: "Customary Cup (US)", symbol: "cup (US)", factor: "0.0002365882365"),
            ConverterUnit(key: "GillUS", name: "Gill (US)", symbol: "gi (US)", factor: "0.00011829411825"),
            ConverterUnit(key: "FluidOunceUS", name: "Fluid Ounce (US)", symbol: "US fl oz", factor: "0.00003"),
            ConverterUnit(key: "BarrelImperial", name: "Barrel (Imperial)", symbol: "bl (imp)", factor: "0.16365924"),
            ConverterUnit(key: "GallonImperial", name: "Gallon (Imperial)", symbol: "gal (imp)", factor: "0.00454609"),
            ConverterUnit(key: "QuartImperial", name: "Quart (Imperial)", symbol: "qt (imp)", factor: "0.0011365225"),
            ConverterUnit(key: "PintImperial", name: "Pint (Imperial)", symbol: "pt (imp)", factor: "0.00056826125"),
            ConverterUnit(key: "GillImperial", name: "Gill (Imperial)", symbol: "gi (imp)", factor: "0.0001420653125"),
            ConverterUnit(key: "FluidOunceImperial", name: "Fluid Ounce (Imperial)", symbol: "fl oz (imp)", factor: "0.0000284130625"),
        ],
        defaultTop: "Liter", defaultBottom: "CubicMeter"
    )

    static let mass = Converter(
        key: "MassConverter", name: "Mass", icon: "scalemass",
        units: [
            ConverterUnit(key: "Gram", name: "Gram", symbol: "g", factor: "0.001"),
            ConverterUnit(key: "Kilogram", name: "Kilogram", symbol: "kg", factor: .one),
            ConverterUnit(key: "Milligram", name: "Milligram", symbol: "mg", factor: "0.000001"),
            ConverterUnit(key: "Microgram", name: "Microgram", symbol: "μm", factor: "0.000000001"),
            ConverterUnit(key: "Tonne", name: "Tonne", symbol: "t", factor: "1000"),
            ConverterUnit(key: "Pound", name: "Pound", symbol: "lb", factor: "0.45359237"),
            ConverterUnit(key: "Ounce", name: "Ounce", symbol: "oz", factor: "0.028349523125"),
            ConverterUnit(key: "Grain", name: "Grain", symbol: "gr", factor: "0.00006479891"),
            ConverterUnit(key: "Dram", name: "Dram", symbol: "dr", factor: "0.0017718451953125"),
            ConverterUnit(key: "Stone", name: "Stone", symbol: "st", factor: "6.35029318"),
            ConverterUnit(key: "LongTon", name: "Long Ton", symbol: "ton", factor: "1016.0469088"),
            ConverterUnit(key: "ShortTon", name: "Short Ton", symbol: "sh tn", factor: "907.18474"),
            ConverterUnit(key: "Carat", name: "Carat", symbol: "kt", factor: "0.0002051965483"),
            ConverterUnit(key: "CaratMetric", name: "Carat (Metric)", symbol: "ct", factor: "0.0002"),
        ],
        defaultTop: "Pound", defaultBottom: "Kilogram"
    )

    static let temperature = Converter(
        key: "TemperatureConverter", name: "Temperature", icon: "thermometer.medium",
        units: [
            ConverterUnit(key: "Celsius", name: "Celsius", symbol: "°C", factor: .one, kind: .celsius),
            ConverterUnit(key: "Fahrenheit", name: "Fahrenheit", symbol: "°F", factor: .ratio("9", "5"), kind: .fahrenheit),
            ConverterUnit(key: "Rankine", name: "Rankine", symbol: "°R", factor: .ratio("5", "9")),
            ConverterUnit(key: "Kelvin", name: "Kelvin", symbol: "K", factor: .one),
        ],
        defaultTop: "Celsius", defaultBottom: "Kelvin"
    )

    static let time = Converter(
        key: "TimeConverter", name: "Time", icon: "clock",
        units: [
            ConverterUnit(key: "Hour", name: "Hour", symbol: "h", factor: "3600"),
            ConverterUnit(key: "Minute", name: "Minute", symbol: "m", factor: "60"),
            ConverterUnit(key: "Second", name: "Second", symbol: "s", factor: .one),
            ConverterUnit(key: "Millisecond", name: "Millisecond", symbol: "ms", factor: "0.001"),
            ConverterUnit(key: "Day", name: "Day", symbol: "d", factor: "86400"),
            ConverterUnit(key: "Week", name: "Week", symbol: "wk", factor: "604800"),
            ConverterUnit(key: "Year", name: "Year", symbol: "y", factor: .product("86400", "365.2425")),
        ],
        defaultTop: "Hour", defaultBottom: "Second"
    )

    static let speed = Converter(
        key: "SpeedConverter", name: "Speed", icon: "gauge.with.dots.needle.67percent",
        units: [
            ConverterUnit(key: "MeterPerSecond", name: "Meter per second", symbol: "m/s", factor: .one),
            ConverterUnit(key: "KilometerPerSecond", name: "Kilometer per second", symbol: "km/s", factor: "1000"),
            ConverterUnit(key: "KilometerPerHour", name: "Kilometer per hour", symbol: "km/h", factor: .ratio("1000", "3600")),
            ConverterUnit(key: "MilePerHour", name: "Mile per hour", symbol: "mph", factor: "0.44704"),
            ConverterUnit(key: "Knot", name: "Knot", symbol: "kn", factor: .ratio("1852", "3600")),
            ConverterUnit(key: "FootPerSecond", name: "Foot per second", symbol: "ft/s", factor: "0.3048"),
            ConverterUnit(key: "Mach", name: "Mach", symbol: "Ma", factor: "340.27"),
            ConverterUnit(key: "SpeedOfLight", name: "Speed of light", symbol: "c", factor: "299792458"),
        ],
        defaultTop: "KilometerPerHour", defaultBottom: "MilePerHour"
    )

    static let pressure = Converter(
        key: "PressureConverter", name: "Pressure", icon: "barometer",
        units: [
            ConverterUnit(key: "Pascal", name: "Pascal", symbol: "Pa", factor: .one),
            ConverterUnit(key: "Kilopascal", name: "Kilopascal", symbol: "kPa", factor: "1000"),
            ConverterUnit(key: "Megapascal", name: "Megapascal", symbol: "MPa", factor: "1000000"),
            ConverterUnit(key: "Bar", name: "Bar", symbol: "bar", factor: "100000"),
            ConverterUnit(key: "Millibar", name: "Millibar", symbol: "mbar", factor: "100"),
            ConverterUnit(key: "Atmosphere", name: "Atmosphere", symbol: "atm", factor: "101325"),
            ConverterUnit(key: "Psi", name: "Pound per square inch", symbol: "psi", factor: "6894.757293168"),
            ConverterUnit(key: "Torr", name: "Torr", symbol: "Torr", factor: "133.32236842105"),
            ConverterUnit(key: "MillimeterOfMercury", name: "Millimeter of mercury", symbol: "mmHg", factor: "133.322387415"),
            ConverterUnit(key: "InchOfMercury", name: "Inch of mercury", symbol: "inHg", factor: "3386.389"),
        ],
        defaultTop: "Bar", defaultBottom: "Psi"
    )

    static let energy = Converter(
        key: "EnergyConverter", name: "Energy", icon: "bolt",
        units: [
            ConverterUnit(key: "Joule", name: "Joule", symbol: "J", factor: .one),
            ConverterUnit(key: "Kilojoule", name: "Kilojoule", symbol: "kJ", factor: "1000"),
            ConverterUnit(key: "Megajoule", name: "Megajoule", symbol: "MJ", factor: "1000000"),
            ConverterUnit(key: "Gigajoule", name: "Gigajoule", symbol: "GJ", factor: "1000000000"),
            ConverterUnit(key: "Calorie", name: "Calorie", symbol: "cal", factor: "4.184"),
            ConverterUnit(key: "Kilocalorie", name: "Kilocalorie", symbol: "kcal", factor: "4184"),
            ConverterUnit(key: "WattHour", name: "Watt hour", symbol: "Wh", factor: "3600"),
            ConverterUnit(key: "KilowattHour", name: "Kilowatt hour", symbol: "kWh", factor: "3600000"),
            ConverterUnit(key: "MegawattHour", name: "Megawatt hour", symbol: "MWh", factor: "3600000000"),
            ConverterUnit(key: "Electronvolt", name: "Electronvolt", symbol: "eV", factor: "1.602176634E-19"),
            ConverterUnit(key: "BritishThermalUnit", name: "British thermal unit", symbol: "BTU", factor: "1055.05585262"),
            ConverterUnit(key: "Therm", name: "Therm", symbol: "thm", factor: "105505585.262"),
            ConverterUnit(key: "FootPound", name: "Foot-pound", symbol: "ft⋅lbf", factor: "1.3558179483314004"),
            ConverterUnit(key: "Erg", name: "Erg", symbol: "erg", factor: "0.0000001"),
        ],
        defaultTop: "Kilocalorie", defaultBottom: "Kilojoule"
    )
}
