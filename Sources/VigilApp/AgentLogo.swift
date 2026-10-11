import SwiftUI

/// The official marks of the agents Vigil recognises, from Simple Icons
/// (CC0, https://simpleicons.org). Each is an SVG path on a 24 point grid.
/// Agents without a published mark fall back to their initial.
enum AgentLogo {
    static let paths: [String: String] = [
        "claude": "M21 10.5h3v3h-3v3h-1.5v3H18v-3h-1.5v3H15v-3H9v3H7.5v-3H6v3H4.5v-3H3v-3H0v-3h3v-6h18Zm-15 0h1.5v-3H6Zm10.5 0H18v-3h-1.5z",
        "codex": "M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z",
        "gemini": "M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81",
        "copilot": "M23.922 16.997C23.061 18.492 18.063 22.02 12 22.02 5.937 22.02.939 18.492.078 16.997A.641.641 0 0 1 0 16.741v-2.869a.883.883 0 0 1 .053-.22c.372-.935 1.347-2.292 2.605-2.656.167-.429.414-1.055.644-1.517a10.098 10.098 0 0 1-.052-1.086c0-1.331.282-2.499 1.132-3.368.397-.406.89-.717 1.474-.952C7.255 2.937 9.248 1.98 11.978 1.98c2.731 0 4.767.957 6.166 2.093.584.235 1.077.546 1.474.952.85.869 1.132 2.037 1.132 3.368 0 .368-.014.733-.052 1.086.23.462.477 1.088.644 1.517 1.258.364 2.233 1.721 2.605 2.656a.841.841 0 0 1 .053.22v2.869a.641.641 0 0 1-.078.256Zm-11.75-5.992h-.344a4.359 4.359 0 0 1-.355.508c-.77.947-1.918 1.492-3.508 1.492-1.725 0-2.989-.359-3.782-1.259a2.137 2.137 0 0 1-.085-.104L4 11.746v6.585c1.435.779 4.514 2.179 8 2.179 3.486 0 6.565-1.4 8-2.179v-6.585l-.098-.104s-.033.045-.085.104c-.793.9-2.057 1.259-3.782 1.259-1.59 0-2.738-.545-3.508-1.492a4.359 4.359 0 0 1-.355-.508Zm2.328 3.25c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm-5 0c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm3.313-6.185c.136 1.057.403 1.913.878 2.497.442.544 1.134.938 2.344.938 1.573 0 2.292-.337 2.657-.751.384-.435.558-1.15.558-2.361 0-1.14-.243-1.847-.705-2.319-.477-.488-1.319-.862-2.824-1.025-1.487-.161-2.192.138-2.533.529-.269.307-.437.808-.438 1.578v.021c0 .265.021.562.063.893Zm-1.626 0c.042-.331.063-.628.063-.894v-.02c-.001-.77-.169-1.271-.438-1.578-.341-.391-1.046-.69-2.533-.529-1.505.163-2.347.537-2.824 1.025-.462.472-.705 1.179-.705 2.319 0 1.211.175 1.926.558 2.361.365.414 1.084.751 2.657.751 1.21 0 1.902-.394 2.344-.938.475-.584.742-1.44.878-2.497Z",
        "cursor": "M11.503.131 1.891 5.678a.84.84 0 0 0-.42.726v11.188c0 .3.162.575.42.724l9.609 5.55a1 1 0 0 0 .998 0l9.61-5.55a.84.84 0 0 0 .42-.724V6.404a.84.84 0 0 0-.42-.726L12.497.131a1.01 1.01 0 0 0-.996 0M2.657 6.338h18.55c.263 0 .43.287.297.515L12.23 22.918c-.062.107-.229.064-.229-.06V12.335a.59.59 0 0 0-.295-.51l-9.11-5.257c-.109-.063-.064-.23.061-.23",
        "opencode": "M22 24H2V0h20zM17 4.8H7v14.4h10z",
        "qwen": "M23.919 14.545 20.817 9.17l1.47-2.544a.56.56 0 0 0 0-.566l-1.633-2.83a.57.57 0 0 0-.49-.283h-6.207L12.487.402a.57.57 0 0 0-.49-.284H8.732a.56.56 0 0 0-.49.284L5.139 5.775h-2.94a.56.56 0 0 0-.49.284L.077 8.887a.56.56 0 0 0 0 .567L3.18 14.83l-1.47 2.545a.56.56 0 0 0 0 .566l1.634 2.83a.57.57 0 0 0 .49.283h6.205l1.47 2.545a.57.57 0 0 0 .49.284h3.266a.57.57 0 0 0 .49-.284l3.104-5.375h2.94a.57.57 0 0 0 .49-.283l1.634-2.828a.55.55 0 0 0-.004-.568M8.733.686l1.634 2.828-1.634 2.828H21.8L20.164 9.17H7.425L5.63 6.06Zm1.306 19.801-6.205-.002 1.634-2.83h3.265L2.201 6.344h3.267q3.182 5.517 6.367 11.032zm10.124-5.66L18.53 12l-6.532 11.315-1.634-2.83c2.129-3.673 4.25-7.351 6.373-11.028h3.592l3.102 5.374z"
    ]

    static func shape(for id: String) -> LogoShape? {
        paths[id].map { LogoShape(path: SVGPath.parse($0)) }
    }
}

/// A logo path scaled from its 24 point grid to fit the frame.
struct LogoShape: Shape {
    var path: Path

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let transform = CGAffineTransform(translationX: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
            .scaledBy(x: scale, y: scale)
        return path.applying(transform)
    }
}

/// Parses SVG path data: every command, absolute and relative, including arcs.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var scanner = Tokens(Array(data.utf8))
        var path = Path()
        var current = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: UInt8 = 0
        var command: UInt8 = 0

        while let next = scanner.nextCommand(after: command) {
            command = next
            let relative = command >= 97
            let base = relative ? current : .zero
            func point() -> CGPoint {
                let x = scanner.number(), y = scanner.number()
                return CGPoint(x: base.x + x, y: base.y + y)
            }
            var control: CGPoint?
            switch command | 0x20 {
            case UInt8(ascii: "m"):
                current = point(); start = current
                path.move(to: current)
                // Further pairs after a move are lines.
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                current = point(); path.addLine(to: current)
            case UInt8(ascii: "h"):
                current.x = (relative ? current.x : 0) + scanner.number(); path.addLine(to: current)
            case UInt8(ascii: "v"):
                current.y = (relative ? current.y : 0) + scanner.number(); path.addLine(to: current)
            case UInt8(ascii: "c"):
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                control = c2; current = end
            case UInt8(ascii: "s"):
                let c1 = reflect(lastControl, about: current, if: "cs", lastCommand)
                let c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                control = c2; current = end
            case UInt8(ascii: "q"):
                let c = point(), end = point()
                path.addQuadCurve(to: end, control: c)
                control = c; current = end
            case UInt8(ascii: "t"):
                let c = reflect(lastControl, about: current, if: "qt", lastCommand)
                let end = point()
                path.addQuadCurve(to: end, control: c)
                control = c; current = end
            case UInt8(ascii: "a"):
                let rx = scanner.number(), ry = scanner.number(), angle = scanner.number()
                let large = scanner.flag(), sweep = scanner.flag()
                let end = point()
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, angle: angle, large: large, sweep: sweep)
                current = end
            case UInt8(ascii: "z"):
                path.closeSubpath(); current = start
            default:
                return path
            }
            lastControl = control
            lastCommand = command | 0x20
        }
        return path
    }

    private static func reflect(_ control: CGPoint?, about point: CGPoint, if kinds: String, _ last: UInt8) -> CGPoint {
        guard let control, kinds.utf8.contains(last) else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// Converts an SVG endpoint arc to cubic curves (SVG spec, appendix B.2.4).
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: Double, ry: Double,
                               angle: Double, large: Bool, sweep: Bool) {
        var rx = abs(rx), ry = abs(ry)
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = angle * .pi / 180, cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy, y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= lambda.squareRoot(); ry *= lambda.squareRoot() }
        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
        var factor = (numerator / (rx * rx * y1 * y1 + ry * ry * x1 * x1)).squareRoot()
        if large == sweep { factor = -factor }
        let cx1 = factor * rx * y1 / ry, cy1 = -factor * ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (p0.x + p1.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (p0.y + p1.y) / 2
        func angleOf(_ ux: Double, _ uy: Double) -> Double { atan2(uy, ux) }
        let theta1 = angleOf((x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angleOf((-x1 - cx1) / rx, (-y1 - cy1) / ry) - theta1
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(segments)
        let k = 4.0 / 3.0 * tan(step / 4)
        func onEllipse(_ t: Double) -> (CGPoint, CGPoint) {
            let x = rx * cos(t), y = ry * sin(t)
            let tx = -rx * sin(t), ty = ry * cos(t)
            let point = CGPoint(x: cx + cosPhi * x - sinPhi * y, y: cy + sinPhi * x + cosPhi * y)
            let tangent = CGPoint(x: cosPhi * tx - sinPhi * ty, y: sinPhi * tx + cosPhi * ty)
            return (point, tangent)
        }
        var t = theta1
        for index in 0..<segments {
            let (a, ta) = onEllipse(t)
            let (b, tb) = onEllipse(t + step)
            let end = index == segments - 1 ? p1 : b
            path.addCurve(to: end,
                          control1: CGPoint(x: a.x + k * ta.x, y: a.y + k * ta.y),
                          control2: CGPoint(x: b.x - k * tb.x, y: b.y - k * tb.y))
            t += step
        }
    }

    /// Reads commands and numbers, including the compact forms SVG allows
    /// such as "-.5.5" and arc flags written without separators.
    private struct Tokens {
        let bytes: [UInt8]
        var index = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        mutating func skipSeparators() {
            while index < bytes.count, bytes[index] == 32 || bytes[index] == 44 || bytes[index] == 10 || bytes[index] == 9 { index += 1 }
        }

        /// The next explicit command, or the previous one repeated when
        /// more numbers follow.
        mutating func nextCommand(after previous: UInt8) -> UInt8? {
            skipSeparators()
            guard index < bytes.count else { return nil }
            let byte = bytes[index]
            if (65...90).contains(byte) || (97...122).contains(byte), byte != 101, byte != 69 {
                index += 1
                return byte
            }
            return previous == 0 ? nil : previous
        }

        mutating func flag() -> Bool {
            skipSeparators()
            guard index < bytes.count else { return false }
            defer { index += 1 }
            return bytes[index] == 49
        }

        mutating func number() -> Double {
            skipSeparators()
            let begin = index
            if index < bytes.count, bytes[index] == 45 || bytes[index] == 43 { index += 1 }
            var seenDot = false
            while index < bytes.count {
                let byte = bytes[index]
                if (48...57).contains(byte) {
                    index += 1
                } else if byte == 46, !seenDot {
                    seenDot = true; index += 1
                } else if byte == 101 || byte == 69 {
                    index += 1
                    if index < bytes.count, bytes[index] == 45 || bytes[index] == 43 { index += 1 }
                } else {
                    break
                }
            }
            return Double(String(decoding: bytes[begin..<index], as: UTF8.self)) ?? 0
        }
    }
}
