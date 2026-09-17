import SwiftUI

/// Visit length stepper + extras list on the appointment detail sheet.
struct VisitExtrasCard: View {
    let extras: [Appointment]
    var chairMins: Int
    var catalogueMins: Int?
    var canEdit: Bool
    var isBusy: Bool
    var errorMessage: String?
    var onAdd: () -> Void
    var onRemove: (String) -> Void
    var onStepDuration: (Int) -> Void

    private var canShorten: Bool {
        chairMins - ChairDuration.stepMinutes >= ChairDuration.minMinutes
    }

    private var canLengthen: Bool {
        chairMins + ChairDuration.stepMinutes <= ChairDuration.maxMinutes
    }

    private var customNote: String {
        if let catalogueMins, catalogueMins != chairMins {
            return "Catalogue default \(ChairDuration.formatLabel(catalogueMins))."
        }
        if extras.isEmpty == false {
            return "Grows with extras; shorten if you will finish early."
        }
        return "Shorten or extend the chair block. Later public slots stay free when you cut time."
    }

    var body: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Visit length")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone500)

                HStack(spacing: 12) {
                    if canEdit {
                        stepButton(
                            systemImage: "minus",
                            enabled: canShorten,
                            label: "Shorten visit by \(ChairDuration.stepMinutes) minutes"
                        ) {
                            onStepDuration(-ChairDuration.stepMinutes)
                        }
                    }

                    Text(ChairDuration.formatLabel(chairMins))
                        .font(AdminTheme.fontAdminSerif(size: 18))
                        .foregroundStyle(AdminTheme.stone900)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if canEdit {
                        stepButton(
                            systemImage: "plus",
                            enabled: canLengthen,
                            label: "Lengthen visit by \(ChairDuration.stepMinutes) minutes"
                        ) {
                            onStepDuration(ChairDuration.stepMinutes)
                        }
                    }
                }

                Text(customNote)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)

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
                .padding(.top, 4)

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

    private func stepButton(
        systemImage: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdminTheme.stone700)
                .frame(width: 32, height: 32)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || !enabled)
        .opacity(isBusy || !enabled ? 0.4 : 1)
        .accessibilityLabel(label)
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
