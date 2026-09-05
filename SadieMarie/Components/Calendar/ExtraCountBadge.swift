import SwiftUI

/// Compact +N badge on calendar pills — mirrors web `ExtraCountBadge`.
struct ExtraCountBadge: View {
    enum Size {
        case sm
        case md

        var box: CGFloat {
            switch self {
            case .sm: return 14
            case .md: return 16
            }
        }

        var font: CGFloat {
            switch self {
            case .sm: return 8
            case .md: return 9
            }
        }
    }

    let count: Int
    var size: Size = .sm

    var body: some View {
        if count > 0 {
            Text("+\(count)")
                .font(.system(size: size.font, weight: .semibold).monospacedDigit())
                .foregroundStyle(AdminTheme.stone900)
                .frame(minWidth: size.box, minHeight: size.box)
                .padding(.horizontal, 2)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: Color.black.opacity(0.08), radius: 1, y: 0.5)
                .accessibilityLabel(Appointment.extraDuringVisitLabel(count: count))
        }
    }
}
