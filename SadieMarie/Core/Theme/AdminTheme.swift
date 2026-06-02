import SwiftUI
import UIKit

/// Design tokens for the admin Bookings dashboard (cream / stone palette).
/// Maps Tailwind classes from `app/globals.css` and `DashboardUI.tsx`.
enum AdminTheme {

    // MARK: - Backgrounds & surfaces

    /// `bg-[#FAF9F6]` — screen + sticky header scrim.
    static let cream = Color(red: 250 / 255, green: 249 / 255, blue: 246 / 255)

    /// `bg-white` — default card fill.
    static let cardFill = Color.white

    // MARK: - Stone neutrals

    /// `text-stone-900` — primary text on neutral rows.
    static let stone900 = Color(red: 28 / 255, green: 25 / 255, blue: 23 / 255)

    /// `text-stone-600` — inactive toggle, secondary emphasis.
    static let stone600 = Color(red: 87 / 255, green: 83 / 255, blue: 78 / 255)

    /// `text-stone-500` — subtitles, day headers.
    static let stone500 = Color(red: 120 / 255, green: 113 / 255, blue: 108 / 255)

    /// `bg-stone-100` — inputs on white cards (readable on cream screens).
    static let stone100 = Color(red: 245 / 255, green: 245 / 255, blue: 244 / 255)

    /// `bg-stone-50/80` — group service cards.
    static let stone50 = Color(red: 250 / 255, green: 250 / 255, blue: 249 / 255)

    /// `bg-rose-600` — destructive confirm actions.
    static let rose600 = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255)

    /// `border-stone-300` — group card border.
    static let stone300 = Color(red: 214 / 255, green: 211 / 255, blue: 209 / 255)

    /// `text-stone-700` — field labels, secondary actions.
    static let stone700 = Color(red: 68 / 255, green: 64 / 255, blue: 60 / 255)

    /// `border-stone-200` — card borders, section dividers.
    static let stone200 = Color(red: 231 / 255, green: 229 / 255, blue: 228 / 255)

    /// `border-stone-200/70` — sticky header bottom border.
    static let stone200Opacity70 = stone200.opacity(0.7)

    /// `text-gray-400` — no-show strikethrough.
    static let gray400 = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)

    // MARK: - Pending (amber)

    /// `border-amber-200` — pending card border.
    static let pendingBorder = Color(red: 253 / 255, green: 230 / 255, blue: 138 / 255)

    /// `bg-amber-50/40` — pending card background.
    static let pendingBackground = Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255)
        .opacity(0.4)

    /// Awaiting-payment pill: border / background / text.
    static let awaitingPaymentBorder = pendingBorder
    static let awaitingPaymentBackground = Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255)
    static let awaitingPaymentText = Color(red: 180 / 255, green: 83 / 255, blue: 9 / 255)

    // MARK: - Confirmed (emerald)

    /// Confirmed pill: `border-emerald-200` / `bg-emerald-50` / `text-emerald-700`.
    static let confirmedBorder = Color(red: 167 / 255, green: 243 / 255, blue: 208 / 255)
    static let confirmedBackground = Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255)
    static let confirmedText = Color(red: 4 / 255, green: 120 / 255, blue: 87 / 255)

    // MARK: - No-show (stone pill)

    /// No-show pill: stone border / background / text.
    static let noShowBorder = Color(red: 214 / 255, green: 211 / 255, blue: 209 / 255)
    static let noShowBackground = Color(red: 245 / 255, green: 245 / 255, blue: 244 / 255)
    static let noShowText = Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255)

    // MARK: - Service-colored row text

    /// On `service_color` background.
    static let onServiceColorText = Color.white

    /// Service subtitle on color — white at 78% opacity.
    static let onServiceColorTextMuted = Color.white.opacity(0.78)

    // MARK: - Shadows

    /// `hover:shadow-sm` — optional on press.
    static let cardShadow = Color.black.opacity(0.06)

    // MARK: - Typography (custom font names — register in Xcode first)

    enum FontFamily {
        /// PostScript names from the bundled `.ttf` files (see `Fonts/README.md`).
        static let bodoniModaRegular = "BodoniModa-Regular"
        static let dmSansRegular = "DMSans-Regular"
        static let dmSansMedium = "DMSans-Medium"
    }

    enum Typography {
        /// Time column — Bodoni Moda 16pt regular.
        static let timeSize: CGFloat = 16

        /// Client name — DM Sans 14pt medium.
        static let clientNameSize: CGFloat = 14

        /// Service subtitle — DM Sans 12pt regular.
        static let serviceSubtitleSize: CGFloat = 12

        /// Day sticky header — DM Sans 10pt semibold, uppercase, tracking 0.28em.
        static let dayHeaderSize: CGFloat = 10
        static let dayHeaderTracking: CGFloat = 2.8

        /// Status pill — DM Sans 10pt medium, tracking ~0.5pt.
        static let statusPillSize: CGFloat = 10
        static let statusPillTracking: CGFloat = 0.5
    }

    // MARK: - Radii

    enum Radius {
        /// `rounded-lg` — cards.
        static let card: CGFloat = 8

        /// `rounded-full` — pills.
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing

    enum Spacing {
        /// List `px-6 py-6`.
        static let listHorizontal: CGFloat = 24
        static let listVertical: CGFloat = 24

        /// Row `px-4 py-3`.
        static let rowHorizontal: CGFloat = 16
        static let rowVertical: CGFloat = 12

        /// Row grid `gap-4`.
        static let rowGridGap: CGFloat = 16

        /// Time column fixed width.
        static let timeColumnWidth: CGFloat = 80

        /// `max-w-3xl` list column.
        static let listMaxWidth: CGFloat = 768

        /// Section `mb-8` / `last:mb-12`.
        static let sectionBottom: CGFloat = 32
        static let sectionBottomLast: CGFloat = 48

        /// Sticky header `py-2`.
        static let stickyHeaderVertical: CGFloat = 8

        /// `space-y-2` between cards.
        static let cardStack: CGFloat = 8

        /// Status pill `px-2 py-0.5`.
        static let pillHorizontal: CGFloat = 8
        static let pillVertical: CGFloat = 2
    }

    // MARK: - Layout

    enum Layout {
        /// No-show row opacity (still readable on light cards).
        static let noShowOpacity: CGFloat = 0.92

        /// Calendar hour / column guides.
        static let gridLineOpacity: CGFloat = 1

        static let cardShadowRadius: CGFloat = 2
        static let cardShadowY: CGFloat = 1
    }

    // MARK: - Font factories

    /// DM Sans — use for client name, service subtitle, day headers, status pills.
    static func fontAdminSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .adminSans(size: size, weight: weight)
    }

    /// Bodoni Moda — use for the time column.
    static func fontAdminSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .adminSerif(size: size, weight: weight)
    }
}

// MARK: - Hex color parsing

extension Color {
    /// Parses `#RRGGBB` (6-digit hex with leading `#`). Used for CMS `service_color`.
    init?(adminHex hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        trimmed.removeFirst()

        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Font helpers

extension Font {
    /// Bodoni Moda with system serif fallback when the font isn't in the bundle yet.
    static func adminSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard AdminFont.isRegistered(AdminTheme.FontFamily.bodoniModaRegular) else {
            return .system(size: size, weight: weight, design: .serif)
        }
        return .custom(AdminTheme.FontFamily.bodoniModaRegular, size: size)
    }

    /// DM Sans with system sans fallback when the font isn't in the bundle yet.
    static func adminSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let postScript: String
        switch weight {
        case .medium, .semibold, .bold, .heavy, .black:
            postScript = AdminFont.isRegistered(AdminTheme.FontFamily.dmSansMedium)
                ? AdminTheme.FontFamily.dmSansMedium
                : AdminTheme.FontFamily.dmSansRegular
        default:
            postScript = AdminTheme.FontFamily.dmSansRegular
        }

        guard AdminFont.isRegistered(postScript) else {
            return .system(size: size, weight: weight, design: .default)
        }
        return .custom(postScript, size: size)
    }
}

// MARK: - Font registration probe

enum AdminFont {
    static func isRegistered(_ postScriptName: String) -> Bool {
        UIFont(name: postScriptName, size: 12) != nil
    }

    #if DEBUG
    /// Call once at launch to log missing bundle fonts (see `Fonts/README.md`).
    static func logRegistrationStatus() {
        let required = [
            AdminTheme.FontFamily.bodoniModaRegular,
            AdminTheme.FontFamily.dmSansRegular,
            AdminTheme.FontFamily.dmSansMedium,
        ]
        for name in required {
            let ok = isRegistered(name)
            print(ok ? "✅ [AdminFont] \(name)" : "⚠️ [AdminFont] Missing \(name) — add .ttf + UIAppFonts")
        }
    }
    #endif
}

// MARK: - Layout & shared UI aliases

enum AppLayout {
    static let screenPadding: CGFloat = 20
}

enum AppFont {
    static func body() -> Font {
        AdminTheme.fontAdminSans(size: 14)
    }
}

extension Color {
    static let semanticRed = AdminTheme.rose600
    static let accent = AdminTheme.stone900
}

enum AppLogger {
    static func debug(_ message: String) { log("DEBUG", message) }
    static func authInfo(_ message: String) { log("AUTH", message) }
    static func authError(_ message: String) { log("AUTH", message) }
    static func syncInfo(_ message: String) { log("SYNC", message) }
    static func syncError(_ message: String) { log("SYNC", message) }

    private static func log(_ tag: String, _ message: String) {
        #if DEBUG
        print("[\(tag)] \(message)")
        #endif
    }
}
