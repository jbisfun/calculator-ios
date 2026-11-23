import FossifyCommons
import SwiftUI
import UIKit

/// performHapticFeedback(), gated by the "Vibrate on button press" setting.
enum Device {
    static func haptic() {
        if Config.shared.vibrateOnButtonPress {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

/// Fossify "pill_background": primary color at LOWER (digits) or MEDIUM (operators) alpha.
struct PillButton: View {
    @Environment(\.palette) private var palette
    let title: String
    var strong = false
    var fontSize: CGFloat = 34
    var onLongPress: (() -> Void)?
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Group {
            if let onLongPress {
                label
                    .opacity(pressed ? 0.6 : 1)
                    .onTapGesture { tap() }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        onLongPress()
                        Device.haptic()
                    } onPressingChanged: { pressed = $0 }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { tap() }
            } else {
                Button(action: tap) { label }.buttonStyle(PressedStyle())
            }
        }
        .padding(8)
    }

    private func tap() {
        action()
        Device.haptic()
    }

    private var label: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .light))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(palette.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(palette.primaryColor.opacity(strong ? 90.0 / 255 : 30.0 / 255))
            )
            .contentShape(Rectangle())
    }
}
