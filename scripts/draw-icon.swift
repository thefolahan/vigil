import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(red: r, green: g, blue: b, alpha: a).cgColor
}

func flame(_ rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let tip = CGPoint(x: rect.midX, y: rect.maxY)
    let base = rect.minY + rect.width / 2
    path.move(to: tip)
    path.addCurve(to: CGPoint(x: rect.maxX, y: base),
                  control1: CGPoint(x: rect.midX + rect.width * 0.14, y: rect.maxY - rect.height * 0.32),
                  control2: CGPoint(x: rect.maxX, y: base + rect.height * 0.24))
    path.addArc(center: CGPoint(x: rect.midX, y: base), radius: rect.width / 2, startAngle: 0, endAngle: .pi, clockwise: true)
    path.addCurve(to: tip,
                  control1: CGPoint(x: rect.minX, y: base + rect.height * 0.24),
                  control2: CGPoint(x: rect.midX - rect.width * 0.14, y: rect.maxY - rect.height * 0.32))
    path.closeSubpath()
    return path
}

// Tile: a night sky in deep indigo.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
context.addPath(tilePath)
context.setFillColor(rgb(0.08, 0.07, 0.16))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(tilePath)
context.clip()
let sky = CGGradient(colorsSpace: space, colors: [rgb(0.15, 0.13, 0.30), rgb(0.05, 0.04, 0.11)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(sky, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

// Warm halo around the flame.
let halo = CGGradient(colorsSpace: space, colors: [rgb(1, 0.66, 0.25, 0.55), rgb(1, 0.5, 0.15, 0.14), rgb(1, 0.5, 0.15, 0)] as CFArray,
                      locations: [0, 0.45, 1])!
context.drawRadialGradient(halo, startCenter: CGPoint(x: 512, y: 640), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 640), endRadius: 420, options: [])

// A few stars.
for (x, y, r) in [(250.0, 800.0, 7.0), (330.0, 700.0, 4.5), (770.0, 815.0, 6.0), (720.0, 735.0, 3.5), (215.0, 610.0, 3.5), (815.0, 590.0, 4.0)] {
    context.setFillColor(rgb(1, 1, 1, 0.55))
    context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}
context.restoreGState()

// Candle body.
let candle = CGRect(x: 412, y: 190, width: 200, height: 330)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0, 0, 0, 0.45))
context.addPath(CGPath(roundedRect: candle, cornerWidth: 34, cornerHeight: 34, transform: nil))
context.setFillColor(rgb(0.95, 0.92, 0.86))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(CGPath(roundedRect: candle, cornerWidth: 34, cornerHeight: 34, transform: nil))
context.clip()
let wax = CGGradient(colorsSpace: space, colors: [rgb(0.84, 0.79, 0.70), rgb(1, 0.98, 0.94), rgb(0.88, 0.83, 0.75)] as CFArray,
                     locations: [0, 0.42, 1])!
context.drawLinearGradient(wax, start: CGPoint(x: candle.minX, y: 0), end: CGPoint(x: candle.maxX, y: 0), options: [])
let glowOnWax = CGGradient(colorsSpace: space, colors: [rgb(1, 0.72, 0.35, 0.45), rgb(1, 0.72, 0.35, 0)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(glowOnWax, start: CGPoint(x: 0, y: candle.maxY), end: CGPoint(x: 0, y: candle.maxY - 140), options: [])
// A terminal prompt pressed into the wax.
context.setStrokeColor(rgb(0.55, 0.46, 0.36, 0.75))
context.setLineWidth(17)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 462, y: 392))
context.addLine(to: CGPoint(x: 502, y: 357))
context.addLine(to: CGPoint(x: 462, y: 322))
context.strokePath()
context.move(to: CGPoint(x: 525, y: 318))
context.addLine(to: CGPoint(x: 568, y: 318))
context.strokePath()
context.restoreGState()

// Wick.
context.setStrokeColor(rgb(0.18, 0.14, 0.12))
context.setLineWidth(13)
context.setLineCap(.round)
context.move(to: CGPoint(x: 512, y: 515))
context.addLine(to: CGPoint(x: 512, y: 562))
context.strokePath()

// Flame, outer then inner.
context.saveGState()
context.setShadow(offset: .zero, blur: 60, color: rgb(1, 0.6, 0.2, 0.9))
context.addPath(flame(CGRect(x: 438, y: 538, width: 148, height: 268)))
context.clip()
let outer = CGGradient(colorsSpace: space, colors: [rgb(1, 0.86, 0.45), rgb(1, 0.58, 0.18), rgb(0.93, 0.32, 0.12)] as CFArray,
                       locations: [0, 0.55, 1])!
context.drawLinearGradient(outer, start: CGPoint(x: 0, y: 545), end: CGPoint(x: 0, y: 806), options: [])
context.restoreGState()

context.addPath(flame(CGRect(x: 476, y: 552, width: 72, height: 150)))
context.setFillColor(rgb(1, 0.97, 0.82))
context.fillPath()

let data = bitmap.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: output))
