import SwiftUI

/// Liquid Glass on macOS 26 and later, frosted material on older systems.
extension View {
    /// A content card. The menu bar panel is already glass, so cards are a
    /// light wash with a hairline edge rather than glass on glass.
    func glassCard(cornerRadius: CGFloat = 14, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(shape.fill((tint ?? .primary).opacity(tint == nil ? 0.05 : 0.10)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
    }

    /// A glass disc behind a symbol or the candle.
    @ViewBuilder
    func glassDisc(tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint?.opacity(0.25)), in: Circle())
        } else {
            background(Circle().fill((tint ?? .primary).opacity(tint == nil ? 0.06 : 0.16)))
        }
    }

    /// A small chip such as the battery gauge.
    func glassCapsule(tint: Color? = nil) -> some View {
        background(Capsule().fill((tint ?? .primary).opacity(tint == nil ? 0.06 : 0.16)))
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

/// A switch in the candle's amber. The system switch on macOS always takes
/// the accent colour and ignores a tint, so Vigil draws its own.
struct AmberToggle: View {
    @Binding var isOn: Bool
    var help: String

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(FlameSwitch())
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
            RadialGradient(colors: [Color.flame.opacity(lit ? 0.22 : 0.0), .clear],
                           center: UnitPoint(x: 0.12, y: 0.02), startRadius: 0, endRadius: 280)
            RadialGradient(colors: [Color.working.opacity(lit ? 0.08 : 0.0), .clear],
                           center: UnitPoint(x: 0.95, y: 0.35), startRadius: 0, endRadius: 240)
        }
        .animation(.easeInOut(duration: 0.8), value: lit)
        .allowsHitTesting(false)
    }
}
