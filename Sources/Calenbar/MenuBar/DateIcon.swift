import AppKit

/// Menu bar icon: today's day number inside a rounded square. Drawn as a template image so macOS
/// tints it like every other menu bar icon (light/dark, highlighted).
///
/// 16×16 pt, the height of third-party app icons in the menu bar: SF Symbols at the status bar's
/// 13 pt render a 12 pt box that looks lost next to them. One-point outline, 3 pt corners, semibold
/// digits centered on their cap height and condensed for two-digit days so the box keeps one size.
enum DateIcon {
    private static let size = NSSize(width: 16, height: 16)
    private static let stroke: CGFloat = 1
    private static let cornerRadius: CGFloat = 3
    private static let fontSize: CGFloat = 10.5

    private static var cache: [Int: NSImage] = [:]

    static func image(day: Int) -> NSImage {
        if let cached = cache[day] {
            return cached
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold, width: day > 9 ? .condensed : .standard)
        let text = "\(day)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textWidth = text.size(withAttributes: attributes).width

        let image = NSImage(size: size, flipped: true) { rect in
            let outline = NSBezierPath(
                roundedRect: rect.insetBy(dx: stroke / 2, dy: stroke / 2), xRadius: cornerRadius, yRadius: cornerRadius)
            outline.lineWidth = stroke
            NSColor.black.setStroke()
            outline.stroke()
            // Digits have no descenders: center the cap height, not the line box.
            let baseline = rect.midY + font.capHeight / 2
            // In a flipped context `draw(at:)` takes the line box's top-left; the baseline sits one ascender below.
            text.draw(at: NSPoint(x: (rect.width - textWidth) / 2, y: baseline - font.ascender), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Calendar, day \(day)")
        cache[day] = image
        return image
    }
}
