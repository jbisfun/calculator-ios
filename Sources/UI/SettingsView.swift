import SwiftUI

/// SettingsActivity / compose/SettingsScreen.kt.
struct SettingsView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var config = config
        VStack(spacing: 0) {
            TopBar(title: "Settings")
            ScrollView {
                VStack(spacing: 0) {
                    Text("Color customization").sectionHeader(palette)
                    item("Customize colors") { router.push(.customizeColors) }

                    Text("General").sectionHeader(palette)
                    toggle("Vibrate on button press", $config.vibrateOnButtonPress)
                    toggle("Prevent phone from sleeping while the app is in foreground", $config.preventPhoneFromSleeping)
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private func item(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ title: String, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
        }
        .tint(palette.primaryColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// CustomizationActivity (theme, text/background/primary colors).
struct CustomizeColorsView: View {
    @Environment(Config.self) private var config
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @State private var pickTheme = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Customize colors")
            ScrollView {
                VStack(spacing: 0) {
                    Button { pickTheme = true } label: {
                        row("Theme") { Text(config.theme.title).foregroundStyle(palette.secondaryText) }
                    }
                    .buttonStyle(.plain)
                    colorRow("Text color", \.customTextColor)
                    colorRow("Background color", \.customBackgroundColor)
                    colorRow("Primary color", \.customPrimaryColor)
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $pickTheme) {
            RadioDialog(title: nil, items: ThemeKind.allCases.map { ($0, $0.title) }, selected: config.theme) { kind in
                if kind == .custom && config.theme != .custom {
                    // Start the custom theme from what is currently on screen.
                    config.customTextColor = palette.text
                    config.customBackgroundColor = palette.background
                    config.customPrimaryColor = palette.primary
                }
                config.theme = kind
            }
        }
    }

    private func row<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(title).font(.system(size: 16))
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func colorRow(_ title: String, _ key: ReferenceWritableKeyPath<Config, UInt32>) -> some View {
        let current: UInt32 = {
            switch key {
            case \Config.customTextColor: return palette.text
            case \Config.customBackgroundColor: return palette.background
            default: return palette.primary
            }
        }()
        return row(title) {
            ColorPicker("", selection: Binding(
                get: { Color(argb: current) },
                set: { c in
                    if config.theme != .custom {
                        config.customTextColor = palette.text
                        config.customBackgroundColor = palette.background
                        config.customPrimaryColor = palette.primary
                        config.theme = .custom
                    }
                    config[keyPath: key] = c.argb | 0xFF000000
                }), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// AboutActivity (trimmed to what applies on iOS).
struct AboutView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        VStack(spacing: 0) {
            TopBar(title: "About")
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Circle().fill(palette.primaryColor).frame(width: 80, height: 80)
                            .overlay(Image(systemName: "plus.forwardslash.minus").font(.system(size: 34)).foregroundStyle(palette.onPrimary))
                        Text("Fossify Calculator").font(.system(size: 22, weight: .medium))
                        Text("Version \(version)").foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 24)
                    Text("Frequently asked questions").sectionHeader(palette)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How does the C (Clear) button work?").font(.system(size: 16, weight: .medium))
                        Text("Tapping on it will remove one character at a time. Long pressing it will reset all fields at once.")
                            .font(.system(size: 15)).foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    link("More questions", "https://www.fossify.org/faq")
                    Text("Help us").sectionHeader(palette)
                    link("Contribute", "https://github.com/FossifyOrg/Calculator/blob/master/CONTRIBUTING.md")
                    link("Donate", "https://fossify.org/donate")
                    Text("Social").sectionHeader(palette)
                    link("Reddit", "https://www.reddit.com/r/Fossify")
                    link("Telegram", "https://t.me/Fossify")
                    Text("Other").sectionHeader(palette)
                    link("Website", "https://www.fossify.org")
                    link("Source code (Android)", "https://github.com/FossifyOrg/Calculator")
                    link("Source code (iOS port)", "https://github.com/jbisfun/calculator-ios")
                    link("Privacy policy", "https://www.fossify.org/policy/calculator")
                    link("License (GPL-3.0)", "https://www.gnu.org/licenses/gpl-3.0.html")
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private func link(_ title: String, _ url: String) -> some View {
        Button { Launcher.open(URL(string: url)) } label: {
            Text(title)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
