import SwiftUI

/// Liquid Glass on macOS 26 and later, frosted material on older systems.
extension View {
    /// A floating glass card. A tint colours the glass, for example amber
    /// while an agent holds the Mac awake.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint?.opacity(0.22)).interactive(interactive), in: shape)
        } else {
            background(shape.fill((tint ?? .clear).opacity(0.12)))
                .background(shape.fill(.thinMaterial))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    /// A glass capsule, for small chips such as the battery gauge.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint?.opacity(0.3)), in: Capsule())
        } else {
            background(Capsule().fill((tint ?? .primary).opacity(tint == nil ? 0.06 : 0.18)))
        }
    }

    /// The system glass button where available.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// Groups glass shapes so they blend and refract into each other.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// A switch tinted with the candle's amber. macOS 26 draws its own glass
/// switch; older systems get the hand drawn one.
struct AmberToggle: View {
    @Binding var isOn: Bool
    var help: String

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Toggle("", isOn: $isOn).toggleStyle(.switch).tint(.flame)
            } else {
                Toggle("", isOn: $isOn).toggleStyle(FlameSwitch())
            }
        }
        .labelsHidden()
        .help(help)
    }
}

/// A soft wash of colour behind the panel that the glass picks up. It glows
/// amber from the candle while the Mac is held awake.
struct PanelBackdrop: View {
    var lit: Bool

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.flame.opacity(lit ? 0.38 : 0.0), .clear],
                           center: UnitPoint(x: 0.12, y: 0.02), startRadius: 0, endRadius: 280)
            RadialGradient(colors: [Color.working.opacity(lit ? 0.14 : 0.0), .clear],
                           center: UnitPoint(x: 0.95, y: 0.35), startRadius: 0, endRadius: 240)
            RadialGradient(colors: [Color.accentColor.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.1, y: 1.0), startRadius: 0, endRadius: 300)
        }
        .animation(.easeInOut(duration: 0.8), value: lit)
        .allowsHitTesting(false)
    }
}
