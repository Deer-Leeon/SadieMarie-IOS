import SwiftUI

/// Tiny settled marker for dense calendar pills — mirrors web
/// `SettlementCheckMarker` (emerald micro-badge, method via icon).
struct SettlementCheckMarker: View {
    enum Size {
        case sm
        case md

        var box: CGFloat {
            switch self {
            case .sm: return 14
            case .md: return 16
            }
        }

        var icon: CGFloat {
            switch self {
            case .sm: return 8
            case .md: return 10
            }
        }
    }

    let payment: AppointmentPaymentSummary?
    var size: Size = .sm

    var body: some View {
        if let payment, payment.isSettled {
            Image(systemName: BookingDisplay.settlementSystemImage(for: payment))
                .font(.system(size: size.icon, weight: .bold))
                .foregroundStyle(AdminTheme.confirmedText)
                .frame(width: size.box, height: size.box)
                .background(AdminTheme.confirmedBackground.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: Color.black.opacity(0.08), radius: 1, y: 0.5)
                .accessibilityLabel(BookingDisplay.settlementLabel(for: payment) ?? "Paid")
        }
    }
}
