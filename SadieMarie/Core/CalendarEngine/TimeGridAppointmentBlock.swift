import SwiftUI

/// Positioned appointment block inside the 3-day / week time grid.
struct TimeGridAppointmentBlock: View {
    let appointment: Appointment
    var isWeekStyle: Bool = false

    private var usesServiceBackground: Bool {
        BookingDisplay.usesServiceColorBackground(appointment)
    }

    private var background: Color {
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.accent
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBackground
        }
        return AdminTheme.cardFill
    }

    private var border: Color {
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBorder
        }
        return AdminTheme.stone200
    }

    private var primaryText: Color {
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.text
        }
        return AdminTheme.stone900
    }

    private var secondaryText: Color {
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.textMuted
        }
        return AdminTheme.stone500
    }

    var body: some View {
        Group {
            if isWeekStyle {
                weekBlock
            } else {
                threeDayBlock
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, isWeekStyle ? 3 : 5)
        .padding(.vertical, isWeekStyle ? 2 : 4)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(border, lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(BookingDisplay.isNoShow(appointment) ? AdminTheme.Layout.noShowOpacity : 1)
    }

    private var threeDayBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 3) {
                Text(clientName)
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                settlementIcon
            }

            Text(BookingDisplay.CalendarFormatting.formattedTimeRange(for: appointment))
                .font(AdminTheme.fontAdminSans(size: 9))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: 2) {
                Text(clientName)
                    .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                    .foregroundStyle(primaryText)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                settlementIcon
            }

            Text(BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment))
                .font(AdminTheme.fontAdminSans(size: 8))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
        }
    }

    private var clientName: String {
        BookingDisplay.clientDisplayName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
    }

    @ViewBuilder
    private var settlementIcon: some View {
        if let payment = appointment.terminalPayment, payment.isSettled {
            Image(systemName: BookingDisplay.settlementSystemImage(for: payment))
                .font(.system(size: isWeekStyle ? 7 : 8, weight: .bold))
                .foregroundStyle(primaryText)
                .accessibilityLabel(BookingDisplay.settlementLabel(for: payment) ?? "Paid")
        }
    }
}
