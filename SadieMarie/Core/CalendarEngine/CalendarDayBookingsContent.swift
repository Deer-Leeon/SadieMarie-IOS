import HorizonCalendar
import SwiftUI

/// HorizonCalendar day cell — reuses `BookingCardView` for parity with List mode.
struct CalendarDayBookingsContent: View {
    let day: DayComponents
    let appointments: [Appointment]
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            dayNumberLabel

            if appointments.isEmpty {
                Spacer(minLength: 0)
            } else if isCompact {
                compactContent
            } else {
                expandedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(isCompact ? 2 : 4)
        .background(AdminTheme.cream)
    }

    // MARK: - Layouts

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
            ForEach(appointments) { appointment in
                BookingCardView(appointment: appointment)
            }
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        if let first = appointments.first {
            compactSummary(for: first)
        }

        if appointments.count > 1 {
            moreBookingsBadge(remaining: appointments.count - 1)
        }
    }

    // MARK: - Chrome

    private var dayNumberLabel: some View {
        Text("\(day.day)")
            .font(AdminTheme.fontAdminSans(
                size: isCompact ? 10 : 11,
                weight: .semibold
            ))
            .foregroundStyle(AdminTheme.stone500)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func compactSummary(for appointment: Appointment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(BookingDisplay.clientDisplayName(
                first: appointment.clientFirstName,
                last: appointment.clientLastName
            ))
            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
            .foregroundStyle(AdminTheme.stone900)
            .lineLimit(1)

            Text(BookingDisplay.formattedTime(for: appointment))
                .font(AdminTheme.fontAdminSerif(size: 11))
                .foregroundStyle(AdminTheme.stone500)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(AdminTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }

    private func moreBookingsBadge(remaining: Int) -> some View {
        Text("+\(remaining) more")
            .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
            .foregroundStyle(AdminTheme.stone600)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AdminTheme.stone200.opacity(0.45))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
