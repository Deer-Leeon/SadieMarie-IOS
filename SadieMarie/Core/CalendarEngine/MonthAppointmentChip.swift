import SwiftUI

/// Small time chip inside a month grid cell (web month view).
struct MonthAppointmentChip: View {
    let appointment: Appointment

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var hasNoShowFlag: Bool { appointment.clientNoShowFlag }

    private var background: Color {
        if isNoShow {
            return AdminTheme.stone50
        }
        if BookingDisplay.usesServiceColorBackground(appointment),
           let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.accent.opacity(0.92)
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.awaitingPaymentBackground
        }
        return Color(red: 245 / 255, green: 245 / 255, blue: 244 / 255)
    }

    private var foreground: Color {
        if isNoShow {
            return AdminTheme.gray400
        }
        if BookingDisplay.usesServiceColorBackground(appointment),
           let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.text
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.awaitingPaymentText
        }
        return AdminTheme.stone600
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment))
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .strikethrough(isNoShow, color: foreground)

            if hasNoShowFlag {
                Image(systemName: "flag.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AdminTheme.awaitingPaymentText)
                    .accessibilityLabel("No-show flag")
            }

            if let payment = appointment.terminalPayment, payment.isSettled {
                Image(systemName: BookingDisplay.settlementSystemImage(for: payment))
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(foreground)
                    .accessibilityLabel(BookingDisplay.settlementLabel(for: payment) ?? "Paid")
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay {
            if hasNoShowFlag && !isNoShow {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AdminTheme.awaitingPaymentText.opacity(0.55), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(isNoShow ? AdminTheme.Layout.noShowOpacity : 1)
        .allowsHitTesting(false)
    }
}

struct MonthTimeBlockChip: View {
    let block: TimeBlock

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 7, weight: .bold))
            Text(block.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? block.note!
                : "Blocked")
                .lineLimit(1)
        }
        .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
        .foregroundStyle(AdminTheme.stone600)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdminTheme.stone100)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    AdminTheme.stone500.opacity(0.4),
                    style: StrokeStyle(lineWidth: 0.7, dash: [2, 2])
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .allowsHitTesting(false)
    }
}
