import SwiftUI

struct SameDayVisitChecklist: View {
    let primary: Appointment
    let siblings: [SameDayUnsettledVisit]
    let selectedExtraIds: Set<String>
    var disabled: Bool = false
    var onToggle: (String) -> Void

    var body: some View {
        if siblings.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Same-day visits")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)

                Text("Include other unpaid appointments for this client today.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)

                VStack(spacing: 0) {
                    row(
                        id: primary.id,
                        title: BookingDisplay.appointmentServiceLabel(primary),
                        subtitle: BookingDisplay.CalendarFormatting.formattedTimeRange(for: primary),
                        cents: TerminalDiscount.quotedCents(fromServicePrice: primary.servicePrice),
                        checked: true,
                        locked: true
                    )
                    ForEach(siblings) { visit in
                        Divider()
                        row(
                            id: visit.id,
                            title: BookingDisplay.cleanServiceName(visit.serviceName),
                            subtitle: timeLabel(visit),
                            cents: visit.quotedCents,
                            checked: selectedExtraIds.contains(visit.id),
                            locked: false
                        )
                    }
                }
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
        }
    }

    private func timeLabel(_ visit: SameDayUnsettledVisit) -> String {
        let dummy = Appointment(
            id: visit.id,
            bookingTime: visit.bookingTime,
            endTime: visit.endTime,
            serviceName: visit.serviceName,
            servicePrice: visit.servicePrice
        )
        return BookingDisplay.CalendarFormatting.formattedTimeRange(for: dummy)
    }

    private func row(
        id: String,
        title: String,
        subtitle: String,
        cents: Int,
        checked: Bool,
        locked: Bool
    ) -> some View {
        Button {
            if !locked { onToggle(id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(locked ? AdminTheme.stone500 : AdminTheme.stone900)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(locked ? "\(title) · this visit" : title)
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                }
                Spacer(minLength: 8)
                Text(BookingDisplay.formattedCents(cents))
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled || locked)
    }
}
