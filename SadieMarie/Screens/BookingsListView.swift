import SwiftUI

/// Bookings list (List mode) — grouped by day with sticky section headers.
struct BookingsListView: View {
    let appointments: [Appointment]
    /// When `false`, an empty API result does not show the “no bookings” copy (e.g. while an error banner is visible).
    var showsEmptyState: Bool = true
    var onSelectAppointment: ((Appointment) -> Void)? = nil

    var body: some View {
        Group {
            if appointments.isEmpty, showsEmptyState {
                emptyState
            } else if appointments.isEmpty {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AdminTheme.cream)
            } else {
                appointmentsList
            }
        }
    }

    private var appointmentsList: some View {
        ScrollView {
            BookingsDayGroupedList(
                appointments: appointments,
                onSelectAppointment: onSelectAppointment
            )
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.vertical, AdminTheme.Spacing.listVertical)
            .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(AdminTheme.cream)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No upcoming bookings")
                .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
            Text("Appointments will appear here when scheduled.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone700)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream)
    }
}

#Preview("Bookings list") {
    BookingsListView(appointments: Appointment.mockList.visibleForBookingsList())
}
