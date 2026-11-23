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
        }
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(Config.self) private var config
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase

    var body: some View {
        @Bindable var router = router
        let palette = Palette.resolve(config, scheme: scheme)
        NavigationStack(path: $router.path) {
            MainView()
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .unitConverterPicker: UnitConverterPickerView()
                        case .converter(let key): UnitConverterView(converter: Converter.all.first { $0.key == key } ?? .length)
                        case .settings: SettingsView()
                        case .customizeColors: CustomizeColorsView()
                        case .about: AboutView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .background(palette.backgroundColor.ignoresSafeArea())
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.palette, palette)
        .tint(palette.primaryColor)
        .foregroundStyle(palette.textColor)
        .preferredColorScheme(config.theme == .system ? nil : (palette.dark ? .dark : .light))
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

/// Re-enable the interactive swipe-back gesture with hidden navigation bars.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
