import AppKit
import SwiftUI

/// The candle Vigil is named after: lit while it keeps the Mac awake.
enum Candle {
    /// A template image for the menu bar, 18 points square.
    static func menuBarImage(lit: Bool, lidHeld: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            let body = NSBezierPath(roundedRect: NSRect(x: 6.3, y: 1.3, width: 5.4, height: 8.2), xRadius: 1.3, yRadius: 1.3)
            if lidHeld {
                body.fill()
            } else {
                body.lineWidth = 1.3
                body.stroke()
            }

            let wick = NSBezierPath()
            wick.move(to: NSPoint(x: 9, y: 9.6))
            wick.line(to: NSPoint(x: 9, y: 10.9))
            wick.lineWidth = 1.2
            wick.lineCapStyle = .round
            wick.stroke()

            if lit {
                flame(in: NSRect(x: 6.9, y: 10.6, width: 4.2, height: 7.2)).fill()
            } else {
                let smoke = NSBezierPath()
                smoke.move(to: NSPoint(x: 9, y: 11.9))
                smoke.curve(to: NSPoint(x: 9.4, y: 16.6), controlPoint1: NSPoint(x: 10.8, y: 13.4), controlPoint2: NSPoint(x: 7.4, y: 15))
                smoke.lineWidth = 1
                smoke.lineCapStyle = .round
                smoke.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A teardrop with a rounded base and a pointed tip.
    static func flame(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let tip = NSPoint(x: rect.midX, y: rect.maxY)
        let base = rect.minY + rect.width / 2
        path.move(to: tip)
        path.curve(to: NSPoint(x: rect.maxX, y: base),
                   controlPoint1: NSPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY - rect.height * 0.3),
                   controlPoint2: NSPoint(x: rect.maxX, y: base + rect.height * 0.22))
        path.appendArc(withCenter: NSPoint(x: rect.midX, y: base), radius: rect.width / 2, startAngle: 0, endAngle: 180, clockwise: true)
        path.curve(to: tip,
                   controlPoint1: NSPoint(x: rect.minX, y: base + rect.height * 0.22),
                   controlPoint2: NSPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY - rect.height * 0.3))
        path.close()
        return path
    }
}

/// A flame shape for SwiftUI, drawn in a unit square with the tip at the top.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        let base = rect.maxY - rect.width / 2
        path.move(to: tip)
        path.addCurve(to: CGPoint(x: rect.maxX, y: base),
                      control1: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.3),
                      control2: CGPoint(x: rect.maxX, y: base - rect.height * 0.22))
        path.addArc(center: CGPoint(x: rect.midX, y: base), radius: rect.width / 2,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: tip,
                      control1: CGPoint(x: rect.minX, y: base - rect.height * 0.22),
                      control2: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.3))
        path.closeSubpath()
        return path
    }
}

/// The large candle at the top of the panel. Its flame flickers while lit.
struct CandleView: View {
    var lit: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !lit)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let flicker = lit ? 1 + 0.05 * sin(t * 7.3) + 0.03 * sin(t * 12.1) : 0
            let sway = lit ? 2.5 * sin(t * 2.9) + 1.2 * sin(t * 5.3) : 0
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.flame.opacity(lit ? 0.45 : 0), .clear],
                                         center: .center, startRadius: 2, endRadius: 30))
                    .frame(width: 60, height: 60)
                    .offset(y: -14)
                    .scaleEffect(lit ? 0.96 + 0.06 * flicker : 0.5)
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        FlameShape()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.62), .flame, Color(red: 0.95, green: 0.38, blue: 0.16)],
                                                 startPoint: .bottom, endPoint: .top))
                            .frame(width: 13, height: 21)
                            .scaleEffect(x: 1, y: flicker, anchor: .bottom)
                            .rotationEffect(.degrees(sway), anchor: .bottom)
                            .opacity(lit ? 1 : 0)
                        Capsule().fill(Color.primary.opacity(0.7)).frame(width: 1.6, height: 5)
                    }
                    .frame(height: 24)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.97), Color(red: 0.90, green: 0.86, blue: 0.78)],
                                             startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.black.opacity(0.12)))
                        .frame(width: 20, height: 24)
                }
            }
            .frame(width: 60, height: 60)
        }
        .animation(.easeInOut(duration: 0.4), value: lit)
    }
}

extension Color {
    static let flame = Color(red: 1, green: 0.66, blue: 0.22)
    static let working = Color(red: 0.25, green: 0.78, blue: 0.47)
}

/// A switch in the candle's amber, so it reads the same with any accent color.
struct FlameSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.flame : Color.primary.opacity(0.16))
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                    .frame(width: 16, height: 16)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
