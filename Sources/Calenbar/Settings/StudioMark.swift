import AppKit
import SwiftUI

/// The studio's monogram at badge size. Its brand rules pair the ink tile with dark surfaces and the paper
/// tile with light ones, and keep it small next to the product's own icon.
struct StudioMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let image = Self.image(colorScheme == .dark ? "keis-ink" : "keis-paper") {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }

    private static func image(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Brand").flatMap(NSImage.init(contentsOf:))
    }
}
