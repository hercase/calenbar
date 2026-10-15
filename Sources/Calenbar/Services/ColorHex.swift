import AppKit
import CalenbarCore
import SwiftUI

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#888888" }
        let red = Int((rgb.redComponent * 255).rounded())
        let green = Int((rgb.greenComponent * 255).rounded())
        let blue = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Color {
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(digits, radix: 16) ?? 0x88_8888
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension MeetingProvider {
    /// Each service's brand color, so the camera icon tells Meet, Zoom and Teams apart at a glance.
    var tint: Color {
        switch self {
        case .googleMeet: Color(hex: "#34A853")
        case .zoom: Color(hex: "#2D8CFF")
        case .teams: Color(hex: "#7B83EB")
        case .webex: Color(hex: "#00BCEB")
        case .slack: Color(hex: "#E01E5A")
        case .faceTime: Color(hex: "#32D74B")
        default: .accentColor
        }
    }
}
