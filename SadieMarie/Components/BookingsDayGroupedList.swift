import SwiftUI

/// Appointments grouped by calendar day — shared by Bookings list and client history.
struct BookingsDayGroupedList: View {
    let appointments: [Appointment]
    var onSelectAppointment: ((Appointment) -> Void)? = nil

    private var sections: [(day: Date, appointments: [Appointment])] {
        BookingDisplay.groupedByDay(appointments)
    }

    var body: some View {
        LazyVStack(
            alignment: .leading,
            spacing: AdminTheme.Spacing.cardStack,
            pinnedViews: [.sectionHeaders]
        ) {
            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.appointments) { appointment in
                        BookingCardView(appointment: appointment)
                            .contentShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                            .onTapGesture {
                                onSelectAppointment?(appointment)
                            }
                    }
                } header: {
                    BookingsDaySectionHeader(date: section.day)
                }
            }
        }
    }
}

/// Sticky day divider — matches `BookingsListView` list mode.
struct BookingsDaySectionHeader: View {
    let date: Date

    var body: some View {
        Text(BookingDisplay.formattedDayHeader(for: date))
            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
            .tracking(AdminTheme.Typography.dayHeaderTracking)
            .textCase(.uppercase)
            .foregroundStyle(AdminTheme.stone700)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AdminTheme.Spacing.stickyHeaderVertical)
            .background(AdminTheme.cream.opacity(0.95))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 1)
            }
    }
}
