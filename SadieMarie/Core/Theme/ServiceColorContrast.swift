import SwiftUI

/// YIQ luminance → black/white text, ported from `app/admin/serviceColors.ts`.
enum ServiceColorContrast {
    /// Values at or above this get black labels; darker fills keep white.
    private static let yiqBlackTextThreshold = 128.0

    /// Prefer black text when the background is light enough that white
    /// labels fail contrast (sky blue, medium pink, pastels, etc.).
    static func usesBlackText(hex: String) -> Bool {
        guard let rgb = rgbComponents(hex: hex) else { return false }
        let yiq = (Double(rgb.r) * 299 + Double(rgb.g) * 587 + Double(rgb.b) * 114) / 1000
        return yiq >= yiqBlackTextThreshold
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
