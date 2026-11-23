import FossifyCommons
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
                    SettingsItem("Customize colors") { router.push(.customizeColors) }

                    Text("General").sectionHeader(palette)
                    SettingsToggle("Vibrate on button press", isOn: $config.vibrateOnButtonPress)
                    SettingsToggle("Prevent phone from sleeping while the app is in foreground", isOn: $config.preventPhoneFromSleeping)
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }
}

extension AppInfo {
    static let calculator = AppInfo(
        name: "Calculator", icon: "plus.forwardslash.minus", upstream: "Calculator", port: "calculator-ios", policy: "calculator",
        faq: [("How does the C (Clear) button work?",
               "Tapping on it will remove one character at a time. Long pressing it will reset all fields at once.")]
    )
}
