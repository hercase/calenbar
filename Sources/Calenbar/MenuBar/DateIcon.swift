import AppKit

/// Menu bar icon: today's day number inside a rounded square. Drawn as a template image so macOS
/// tints it like every other menu bar icon (light/dark, highlighted).
///
/// Geometry copies SF Symbols' `N.square` family as the status bar renders it (13 pt, regular):
/// a 15×14 pt image with a 12×12 pt box at (1.5, 1), 1 pt stroke, ~2.5 pt corners. Digits are set
/// heavier than the symbol's for legibility, centered on their cap height, and condensed for
/// two-digit days so the box stays the same size all month.
enum DateIcon {
    private static let imageHeight: CGFloat = 14
    private static let box = NSRect(x: 1.5, y: 1, width: 12, height: 12)
    private static let stroke: CGFloat = 1
    private static let cornerRadius: CGFloat = 2.4
    private static let fontSize: CGFloat = 9.5

    private static var cache: [Int: NSImage] = [:]

    static func image(day: Int) -> NSImage {
        if let cached = cache[day] {
            return cached
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold, width: day > 9 ? .condensed : .standard)
        let text = "\(day)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textWidth = text.size(withAttributes: attributes).width

        let image = NSImage(size: NSSize(width: box.maxX + box.minX, height: imageHeight), flipped: false) { _ in
            let border = NSBezierPath(
                roundedRect: box.insetBy(dx: stroke / 2, dy: stroke / 2), xRadius: cornerRadius, yRadius: cornerRadius)
            border.lineWidth = stroke
            NSColor.black.setStroke()
            border.stroke()
            // Digits have no descenders, so center the cap height in the box rather than the line box.
            let baseline = box.midY - font.capHeight / 2
            text.draw(at: NSPoint(x: box.midX - textWidth / 2, y: baseline + font.descender), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Calendar, day \(day)")
        cache[day] = image
        return image
    }
}
