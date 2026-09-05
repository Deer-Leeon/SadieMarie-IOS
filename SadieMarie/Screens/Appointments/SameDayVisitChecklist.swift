import SwiftUI

struct SameDayVisitChecklist: View {
    let siblings: [SameDayUnsettledVisit]
    let selectedExtraIds: Set<String>
    var disabled: Bool = false
    var onToggle: (String) -> Void

    var body: some View {
        if siblings.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Also today")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)

                Text("Optionally include other unpaid appointments for this client.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)

                VStack(spacing: 0) {
                    ForEach(Array(siblings.enumerated()), id: \.element.id) { index, visit in
                        if index > 0 {
                            Divider()
                        }
                        row(
                            id: visit.id,
                            title: BookingDisplay.cleanServiceName(visit.serviceName),
                            subtitle: timeLabel(visit),
                            cents: visit.quotedCents,
                            checked: selectedExtraIds.contains(visit.id)
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
        checked: Bool
    ) -> some View {
        Button {
            onToggle(id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
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
        .disabled(disabled)
    }
}
