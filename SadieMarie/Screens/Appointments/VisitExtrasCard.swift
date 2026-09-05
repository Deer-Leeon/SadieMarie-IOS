import SwiftUI

/// Extras list + Add extra on the appointment detail sheet.
struct VisitExtrasCard: View {
    let extras: [Appointment]
    var canEdit: Bool
    var isBusy: Bool
    var errorMessage: String?
    var onAdd: () -> Void
    var onRemove: (String) -> Void

    var body: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Extras")
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AdminTheme.stone500)
                    Spacer()
                    if canEdit {
                        Button(action: onAdd) {
                            Label("Add extra", systemImage: "plus")
                                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                                .tracking(1.6)
                                .textCase(.uppercase)
                                .foregroundStyle(AdminTheme.stone700)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                    }
                }

                Text("Done during this visit.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)

                if extras.isEmpty {
                    Text("No extras yet.")
                        .font(AdminTheme.fontAdminSans(size: 14))
                        .italic()
                        .foregroundStyle(AdminTheme.stone500)
                        .padding(.top, 4)
                } else {
                    ForEach(extras) { extra in
                        extraRow(extra)
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }
            }
        }
    }

    private func extraRow(_ extra: Appointment) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(BookingDisplay.appointmentServiceLabel(extra))
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                HStack(spacing: 6) {
                    if let price = BookingDisplay.formattedPrice(extra.servicePrice) {
                        Text(price)
                    } else {
                        Text("No price")
                    }
                    Text("·")
                    if extra.terminalPayment?.isSettled == true {
                        Text(BookingDisplay.settlementLabel(for: extra.terminalPayment) ?? "Paid")
                    } else {
                        Text("Unpaid")
                    }
                }
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
            }
            Spacer(minLength: 8)
            if canEdit, extra.terminalPayment?.isSettled != true {
                Button {
                    onRemove(extra.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel("Remove extra")
            }
        }
        .padding(.vertical, 4)
    }
}
