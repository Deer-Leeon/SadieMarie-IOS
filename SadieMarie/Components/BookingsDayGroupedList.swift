import SwiftUI

/// Appointments grouped by calendar day — shared by Bookings list and client history.
struct BookingsDayGroupedList: View {
    let appointments: [Appointment]
    var onSelectAppointment: ((Appointment) -> Void)? = nil
    /// Client history nests extras under the visit; the Bookings list does not.
    var showsNestedExtras: Bool = false

    var body: some View {
        LazyVStack(
            alignment: .leading,
            spacing: AdminTheme.Spacing.cardStack,
            pinnedViews: [.sectionHeaders]
        ) {
            BookingsDaySectionRows(
                appointments: appointments,
                onSelectAppointment: onSelectAppointment,
                usesSection: true,
                showsNestedExtras: showsNestedExtras
            )
        }
    }
}

/// Day sections without the outer stack — so the Bookings list can place a
/// past/upcoming seam between two groups in one `LazyVStack`.
struct BookingsDaySectionRows: View {
    let appointments: [Appointment]
    var onSelectAppointment: ((Appointment) -> Void)? = nil
    var headerSurface: Color = AdminTheme.cream.opacity(0.95)
    /// Sticky `Section` headers. Off for past rows so they never pin over upcoming.
    var usesSection: Bool = false
    var showsNestedExtras: Bool = false

    private var sections: [(day: Date, appointments: [Appointment])] {
        BookingDisplay.groupedByDay(appointments)
    }

    var body: some View {
        ForEach(sections, id: \.day) { section in
            if usesSection {
                Section {
                    cards(for: section.appointments)
                } header: {
                    BookingsDaySectionHeader(date: section.day, surface: headerSurface)
                }
            } else {
                VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
                    BookingsDaySectionHeader(date: section.day, surface: headerSurface)
                    cards(for: section.appointments)
                }
            }
        }
    }

    @ViewBuilder
    private func cards(for appointments: [Appointment]) -> some View {
        ForEach(appointments.filter { !$0.isAttachedExtra }) { appointment in
            VStack(alignment: .leading, spacing: 0) {
                BookingCardView(appointment: appointment)
                    .contentShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                    .onTapGesture {
                        onSelectAppointment?(appointment)
                    }

                if showsNestedExtras, !appointment.extras.isEmpty {
                    NestedVisitExtras(
                        extras: appointment.extras,
                        muted: BookingDisplay.isReadOnly(appointment),
                        onSelect: { onSelectAppointment?(appointment) }
                    )
                }
            }
        }
    }
}

/// Sticky day divider — matches `BookingsListView` list mode.
struct BookingsDaySectionHeader: View {
    let date: Date
    var surface: Color = AdminTheme.cream.opacity(0.95)

    var body: some View {
        Text(BookingDisplay.formattedDayHeader(for: date))
            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
            .tracking(AdminTheme.Typography.dayHeaderTracking)
            .textCase(.uppercase)
            .foregroundStyle(AdminTheme.stone700)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AdminTheme.Spacing.stickyHeaderVertical)
            .background(surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 1)
            }
    }
}
