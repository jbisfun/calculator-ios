import FossifyCommons
import Observation
import SwiftUI
import UIKit

enum Route: Hashable {
    case unitConverterPicker
    case converter(String)
    case settings
    case customizeColors
    case about
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var toast: String?

    func push(_ r: Route) { path.append(r) }
}

struct CalculatorApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(Config.shared)
                .fossifyTheme()
        }
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            MainView()
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .unitConverterPicker: UnitConverterPickerView()
                        case .converter(let key): UnitConverterView(converter: Converter.all.first { $0.key == key } ?? .length)
                        case .settings: SettingsView()
                        case .customizeColors: CustomizeColorsView()
                        case .about: AboutView(app: .calculator)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .paletteBackground()
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .toast($router.toast)
        .onAppear(perform: updateIdleTimer)
        .onChange(of: phase) { updateIdleTimer() }
        .onChange(of: config.preventPhoneFromSleeping) { updateIdleTimer() }
    }

    /// FLAG_KEEP_SCREEN_ON while the app is in front.
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = config.preventPhoneFromSleeping && phase == .active
    }
}
