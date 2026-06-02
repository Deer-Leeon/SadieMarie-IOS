import SwiftUI

/// Status badge for a booking row — mirrors web list pills.
struct BookingStatusPill: View {
    let status: String?

    private var normalized: String {
        (status ?? "").lowercased()
    }

    private var label: String {
        switch normalized {
        case "confirmed":
            return "Confirmed"
        case "pending":
            return "Awaiting Payment"
        case "no-show":
            return "No-show"
        case "canceled_by_admin":
            return "Cancelled by you"
        case "canceled_by_client_late":
            return "Late cancel ($20)"
        case "canceled_by_client", "cancelled":
            return "Cancelled by client"
        case "canceled_by_system":
            return "Cancelled by system"
        default:
            return status?.capitalized ?? "Unknown"
        }
    }

    private var colors: PillColors {
        switch normalized {
        case "confirmed":
            return PillColors(
                border: AdminTheme.confirmedBorder,
                background: AdminTheme.confirmedBackground,
                foreground: AdminTheme.confirmedText
            )
        case "pending":
            return PillColors(
                border: AdminTheme.awaitingPaymentBorder,
                background: AdminTheme.awaitingPaymentBackground,
                foreground: AdminTheme.awaitingPaymentText
            )
        case "no-show":
            return PillColors(
                border: AdminTheme.noShowBorder,
                background: AdminTheme.noShowBackground,
                foreground: AdminTheme.noShowText
            )
        default:
            return PillColors(
                border: AdminTheme.noShowBorder,
                background: AdminTheme.noShowBackground,
                foreground: AdminTheme.noShowText
            )
        }
    }

    var body: some View {
        Text(label)
            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
            .tracking(AdminTheme.Typography.statusPillTracking)
            .textCase(.uppercase)
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, AdminTheme.Spacing.pillHorizontal)
            .padding(.vertical, AdminTheme.Spacing.pillVertical)
            .background(colors.background)
            .overlay(
                Capsule()
                    .stroke(colors.border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

private struct PillColors {
    let border: Color
    let background: Color
    let foreground: Color
}

#Preview("Status pills") {
    VStack(spacing: 12) {
        BookingStatusPill(status: "confirmed")
        BookingStatusPill(status: "pending")
        BookingStatusPill(status: "no-show")
    }
    .padding()
    .background(AdminTheme.cream)
}
