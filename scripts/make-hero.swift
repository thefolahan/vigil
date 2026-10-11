import AppKit

// swift scripts/make-hero.swift panel.png docs/hero.jpg
// panel.png is the demo panel captured with window-shot.swift --no-shadow.
let panel = NSImage(contentsOfFile: CommandLine.arguments[1])!
let output = CommandLine.arguments[2]
let width: CGFloat = 1600
let height: CGFloat = 873

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(red: r, green: g, blue: b, alpha: a).cgColor
}

// Night sky, as in the icon.
let sky = CGGradient(colorsSpace: space, colors: [rgb(0.16, 0.13, 0.32), rgb(0.04, 0.035, 0.10)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(sky, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
var seed: UInt64 = 7
func next() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(1 << 31)
}
for _ in 0..<90 {
    let x = next() * width, y = next() * (height - 60), r = 0.6 + next() * 1.8
    // Keep the area behind the title and tagline clear.
    if x < 860, y > 100, y < 520 { continue }
    context.setFillColor(rgb(1, 1, 1, 0.15 + next() * 0.45))
    context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// Menu bar.
let barHeight: CGFloat = 44
context.setFillColor(rgb(0.07, 0.06, 0.14, 0.72))
context.fill(CGRect(x: 0, y: height - barHeight, width: width, height: barHeight))

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at point: CGPoint, tracking: CGFloat = 0) -> CGSize {
    let attributed = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: tracking
    ])
    attributed.draw(at: point)
    return attributed.size()
}

// The panel hangs under the candle in the menu bar.
// The preview window is borderless, so the capture is the panel alone.
let source = NSRect(x: 0, y: 0, width: panel.size.width, height: panel.size.height)
let panelWidth: CGFloat = 470
let panelHeight = panelWidth * source.height / source.width
let panelRect = CGRect(x: width - 140 - panelWidth, y: height - barHeight - 12 - panelHeight, width: panelWidth, height: panelHeight)

let clock = "Sun 11 Oct  02:14"
let clockSize = NSAttributedString(string: clock, attributes: [.font: NSFont.systemFont(ofSize: 17, weight: .medium)]).size()
_ = text(clock, size: 17, weight: .medium, color: NSColor(white: 1, alpha: 0.9), at: CGPoint(x: width - 28 - clockSize.width, y: height - barHeight + 11))
var iconX = width - 28 - clockSize.width - 30
for symbol in ["wifi", "battery.75percent", "magnifyingglass"] {
    if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 17, weight: .medium).applying(.init(paletteColors: [NSColor(white: 1, alpha: 0.9)]))) {
        iconX -= image.size.width
        image.draw(in: CGRect(x: iconX, y: height - barHeight + (barHeight - image.size.height) / 2, width: image.size.width, height: image.size.height))
        iconX -= 30
    }
}
let candleX = iconX - 30

// Lit candle and agent count in the bar, with a highlight behind them.
context.setFillColor(rgb(1, 1, 1, 0.16))
context.addPath(CGPath(roundedRect: CGRect(x: candleX - 22, y: height - barHeight + 7, width: 58, height: 30), cornerWidth: 8, cornerHeight: 8, transform: nil))
context.fillPath()
let candleColor = rgb(1, 1, 1, 0.95)
context.setFillColor(candleColor)
context.setStrokeColor(candleColor)
context.setLineWidth(2.4)
context.addPath(CGPath(roundedRect: CGRect(x: candleX - 5, y: height - barHeight + 11, width: 10, height: 14), cornerWidth: 2.4, cornerHeight: 2.4, transform: nil))
context.strokePath()
let flame = CGMutablePath()
let flameBase = CGPoint(x: candleX, y: height - barHeight + 29.5)
flame.move(to: CGPoint(x: candleX, y: height - barHeight + 39))
flame.addCurve(to: CGPoint(x: candleX + 4, y: flameBase.y), control1: CGPoint(x: candleX + 1, y: flameBase.y + 6), control2: CGPoint(x: candleX + 4, y: flameBase.y + 2.5))
flame.addArc(center: flameBase, radius: 4, startAngle: 0, endAngle: .pi, clockwise: true)
flame.addCurve(to: CGPoint(x: candleX, y: height - barHeight + 39), control1: CGPoint(x: candleX - 4, y: flameBase.y + 2.5), control2: CGPoint(x: candleX - 1, y: flameBase.y + 6))
context.addPath(flame)
context.fillPath()
_ = text("3", size: 17, weight: .medium, color: NSColor(white: 1, alpha: 0.95), at: CGPoint(x: candleX + 12, y: height - barHeight + 11))

_ = text("Vigil", size: 17, weight: .bold, color: NSColor(white: 1, alpha: 0.95), at: CGPoint(x: 64, y: height - barHeight + 11))

// Glow behind the panel, then the panel itself.
let glow = CGGradient(colorsSpace: space, colors: [rgb(1, 0.62, 0.22, 0.30), rgb(1, 0.55, 0.2, 0)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: panelRect.minX + 70, y: panelRect.maxY - 60), startRadius: 0,
                           endCenter: CGPoint(x: panelRect.minX + 70, y: panelRect.maxY - 60), endRadius: 340, options: [])
let panelPath = CGPath(roundedRect: panelRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: rgb(0, 0, 0, 0.6))
context.addPath(panelPath)
context.setFillColor(rgb(0.16, 0.16, 0.17))
context.fillPath()
context.restoreGState()
context.saveGState()
context.addPath(panelPath)
context.clip()
panel.draw(in: panelRect, from: source, operation: .sourceOver, fraction: 1)
context.restoreGState()
context.addPath(panelPath)
context.setStrokeColor(rgb(1, 1, 1, 0.14))
context.setLineWidth(1)
context.strokePath()

// Title and tagline on the left.
let left: CGFloat = 112
let titleSize = text("Vigil", size: 118, weight: .bold, color: .white, at: CGPoint(x: left - 6, y: 470), tracking: -4)
_ = titleSize
let lines = ["Keeps your Mac awake while", "your coding agents work.", "Not a minute longer."]
for (index, line) in lines.enumerated() {
    _ = text(line, size: 38, weight: index == 2 ? .semibold : .regular,
             color: index == 2 ? NSColor(red: 1, green: 0.72, blue: 0.36, alpha: 1) : NSColor(white: 1, alpha: 0.78),
             at: CGPoint(x: left, y: 400 - CGFloat(index) * 52))
}
let chips = ["Claude Code", "Codex", "Gemini CLI", "Cursor", "Aider", "+ 6 more"]
var chipX = left
for chip in chips {
    let attributed = NSAttributedString(string: chip, attributes: [.font: NSFont.systemFont(ofSize: 19, weight: .medium),
                                                                    .foregroundColor: NSColor(white: 1, alpha: 0.82)])
    let size = attributed.size()
    if chipX + size.width + 28 > panelRect.minX - 60 { break }
    context.addPath(CGPath(roundedRect: CGRect(x: chipX, y: 180, width: size.width + 28, height: 40), cornerWidth: 20, cornerHeight: 20, transform: nil))
    context.setFillColor(rgb(1, 1, 1, 0.09))
    context.fillPath()
    attributed.draw(at: CGPoint(x: chipX + 14, y: 180 + (40 - size.height) / 2))
    chipX += size.width + 40
}
_ = text("Lid closed mode  ·  heat and battery guards  ·  alerts on your phone", size: 19, weight: .regular,
         color: NSColor(white: 1, alpha: 0.55), at: CGPoint(x: left, y: 128))

let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
try! data.write(to: URL(fileURLWithPath: output))
