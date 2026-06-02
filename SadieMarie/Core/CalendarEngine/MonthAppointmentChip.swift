import SwiftUI

/// Small time chip inside a month grid cell (web month view).
struct MonthAppointmentChip: View {
    let appointment: Appointment

    private var background: Color {
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
        if BookingDisplay.usesServiceColorBackground(appointment) {
            return AdminTheme.onServiceColorText
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.awaitingPaymentText
        }
        return AdminTheme.stone600
    }

    var body: some View {
        Text(BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment))
            .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
    }
}
