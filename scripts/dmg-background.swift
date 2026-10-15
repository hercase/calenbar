// Draws the DMG window background: "drag to Applications" arrow and a first-launch hint.
// Usage: swift scripts/dmg-background.swift <output.png> <scale>
// Layout matches scripts/package.sh: 640x400 window, app icon at (160, 190), Applications at (480, 190).
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let scale = Double(args[2]) else { fatalError("usage: dmg-background.swift out.png scale") }
let size = NSSize(width: 640, height: 400)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("bitmap") }
rep.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Soft background in the app icon's palette; light so Finder's dark icon labels stay readable.
let top = NSColor(srgbRed: 0.97, green: 0.97, blue: 1.0, alpha: 1)
let bottom = NSColor(srgbRed: 0.90, green: 0.91, blue: 0.98, alpha: 1)
NSGradient(starting: bottom, ending: top)?.draw(in: NSRect(origin: .zero, size: size), angle: 90)

let indigo = NSColor(srgbRed: 0.24, green: 0.25, blue: 0.75, alpha: 1)
let secondary = NSColor(srgbRed: 0.40, green: 0.42, blue: 0.55, alpha: 1)

func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
    let height = (text as NSString).size(withAttributes: attributes).height
    (text as NSString).draw(in: NSRect(x: 0, y: y, width: size.width, height: height), withAttributes: attributes)
}

// AppKit's origin is bottom-left: y = 400 - (distance from top).
drawCentered("Drag Calenbar to Applications", y: 400 - 70, font: .systemFont(ofSize: 22, weight: .semibold), color: indigo)

// Arrow between the two icons (icon centers at y = 190 from the top).
let arrowY = 400 - 190.0
let arrow = NSBezierPath()
arrow.lineWidth = 6
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 255, y: arrowY))
arrow.line(to: NSPoint(x: 385, y: arrowY))
arrow.move(to: NSPoint(x: 362, y: arrowY + 20))
arrow.line(to: NSPoint(x: 387, y: arrowY))
arrow.line(to: NSPoint(x: 362, y: arrowY - 20))
indigo.withAlphaComponent(0.85).setStroke()
arrow.stroke()

drawCentered("First launch: System Settings › Privacy & Security › Open Anyway",
             y: 34, font: .systemFont(ofSize: 12, weight: .regular), color: secondary)

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try png.write(to: URL(fileURLWithPath: args[1]))
