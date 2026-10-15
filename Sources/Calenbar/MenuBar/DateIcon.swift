import AppKit

/// Menu bar icon: today's day number, bold, inside a rounded outline. Drawn as a template image so
/// macOS tints it like every other menu bar icon (light/dark, highlighted).
enum DateIcon {
    private static var cache: [Int: NSImage] = [:]

    static func image(day: Int) -> NSImage {
        if let cached = cache[day] {
            return cached
        }
        let text = "\(day)" as NSString
        let font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = text.size(withAttributes: attributes)

        // Same height as system menu bar symbols; wide enough for one or two digits.
        let size = NSSize(width: max(19, ceil(textSize.width) + 9), height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 4, yRadius: 4)
            border.lineWidth = 1.5
            NSColor.black.setStroke()
            border.stroke()
            let origin = NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2 + 0.5)
            text.draw(at: origin, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Calendar")
        cache = [day: image]
        return image
    }
}
