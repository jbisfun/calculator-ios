import SwiftUI
import UIKit

/// RadioGroupDialog from Fossify Commons.
struct RadioDialog<T: Hashable>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let items: [(T, String)]
    let selected: T
    let onPick: (T) -> Void

    var body: some View {
        DialogFrame(title: title) {
            ForEach(items, id: \.0) { item in
                Button {
                    onPick(item.0)
                    dismiss()
                } label: {
                    RadioRow(title: item.1, on: item.0 == selected)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RadioRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let on: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
            Text(title).foregroundStyle(palette.textColor)
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct CheckRow: View {
    @Environment(\.palette) private var palette
    let title: String
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 16) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
                Text(title).foregroundStyle(palette.textColor).multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Material-style dialog body presented as a sheet.
struct DialogFrame<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String?
    var scroll = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(palette.textColor)
                    .padding(.bottom, 8)
            }
            if scroll {
                ScrollView { VStack(alignment: .leading, spacing: 0, content: content) }
            } else {
                VStack(alignment: .leading, spacing: 0, content: content)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DialogButtons: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var ok = "OK"
    var okEnabled = true
    let onOK: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            Button("Cancel") { dismiss() }
            Button(ok) { onOK() }.disabled(!okEnabled)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(palette.primaryColor)
        .padding(.top, 16)
    }
}

/// Toast replacement (Android Toast -> transient capsule).
struct ToastModifier: ViewModifier {
    @Binding var text: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 100)
                    .transition(.opacity)
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.text = nil }
                    }
            }
        }
        .animation(.default, value: text)
    }
}

extension View {
    func toast(_ text: Binding<String?>) -> some View { modifier(ToastModifier(text: text)) }

    /// Fossify settings section header ("Color customization", "General", ...).
    func sectionHeader(_ palette: Palette) -> some View {
        self.font(.system(size: 14, weight: .bold))
            .foregroundStyle(palette.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

/// Wraps a View in a NavigationStack-less themed screen with a top app bar.
struct TopBar<Trailing: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onBack: (() -> Void)?
    var background: Color?
    var tint: Color?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image(systemName: "arrow.left").font(.system(size: 20)).frame(width: 48, height: 48)
            }
            Text(title)
                .font(.system(size: 21, weight: .medium))
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .foregroundStyle(tint ?? palette.textColor)
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(background ?? palette.backgroundColor)
    }
}

extension TopBar where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, background: nil, tint: nil, trailing: { EmptyView() })
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 44, height: 48)
        }
    }
}
enum Launcher {
    static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}

/// Fossify's copyToClipboard + performHapticFeedback.
enum Device {
    static func copy(_ value: String) -> String {
        UIPasteboard.general.string = value
        return "Value copied to clipboard"
    }

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

/// Ripple stand-in: dim while pressed.
struct PressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
