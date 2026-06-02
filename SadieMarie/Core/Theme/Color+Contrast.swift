import SwiftUI
import UIKit

extension Color {
    /// sRGB relative luminance (0 = black, 1 = white). Used for text contrast on service fills.
    var relativeLuminance: CGFloat {
        let rgba = UIColor(self).rgbaComponents
        func linearized(_ channel: CGFloat) -> CGFloat {
            if channel <= 0.03928 { return channel / 12.92 }
            return pow((channel + 0.055) / 1.055, 2.4)
        }
        let red = linearized(rgba.red)
        let green = linearized(rgba.green)
        let blue = linearized(rgba.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// `true` when white / light foreground reads better on this fill.
    var prefersLightForeground: Bool {
        relativeLuminance < 0.52
    }
}

private extension UIColor {
    struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    var rgbaComponents: RGBA {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }
}
