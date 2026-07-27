import SwiftUI

/// Pastel → black text accents, ported from `app/admin/serviceColors.ts`.
enum ServiceColorContrast {
    /// Only these backgrounds render black labels. Everything else keeps white.
    private static let blackTextAccents: [(r: Int, g: Int, b: Int)] = [
        (0xfe, 0xdc, 0xea), // lightest pink
        (0xcb, 0xe5, 0xcb), // lightest green
        (0xfe, 0xf4, 0xb4), // yellow
    ]

    /// Max city-block RGB distance to count as one of the three pastels.
    private static let rgbSlop = 18

    static func usesBlackText(hex: String) -> Bool {
        guard let rgb = rgbComponents(hex: hex) else { return false }
        return blackTextAccents.contains { target in
            abs(rgb.r - target.r) + abs(rgb.g - target.g) + abs(rgb.b - target.b) <= rgbSlop
        }
    }

    private static func rgbComponents(hex: String) -> (r: Int, g: Int, b: Int)? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        trimmed.removeFirst()
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        return (
            Int((value >> 16) & 0xFF),
            Int((value >> 8) & 0xFF),
            Int(value & 0xFF)
        )
    }
}
