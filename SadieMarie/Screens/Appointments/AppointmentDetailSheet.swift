import SwiftUI

/// Deep-dive sheet for a single booking (mirrors web `AppointmentModal`).
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    var onDismiss: () -> Void
    var onMutated: () -> Void

    @State private var statusAction: StatusAction?
    @State private var statusError: String?
    @State private var showNoShowConfirm = false
    @State private var showCancelConfirm = false
    @State private var rescheduleLink: RescheduleSafariLink?
    @State private var clientProfileEntry: ClientProfileEntry?

    private var headerStatus: BookingDisplay.DetailHeaderStatus {
        BookingDisplay.detailHeaderStatus(for: appointment)
    }

    private var canReschedule: Bool {
        guard let slug = appointment.serviceSlug, !slug.isEmpty,
              let uid = appointment.calUid, !uid.isEmpty else {
            return false
        }
        return true
    }

    private var canChargeNoShow: Bool {
        guard let stripeId = appointment.stripeCustomerId, !stripeId.isEmpty,
              let price = appointment.servicePrice, price > 0 else {
            return false
        }
        return true
    }

    private var isBusy: Bool { statusAction != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerEyebrow

                    if let statusError {
                        errorBanner(statusError)
                    }

                    clientCard
                    timeCard
                    serviceCard
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AdminTheme.cream)
            .safeAreaInset(edge: .bottom) {
                actionFooter
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                    .disabled(isBusy)
                }
            }
            .toolbarBackground(AdminTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .sheet(item: $clientProfileEntry) { entry in
            ClientProfileView(
                entry: entry,
                backLabel: "Appointment",
                onBack: { clientProfileEntry = nil },
                onClose: { clientProfileEntry = nil },
                onMutated: {
                    onMutated()
                    clientProfileEntry = nil
                }
            )
        }
        .sheet(item: $rescheduleLink) { link in
            AdminSafariView(url: link.url)
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "Mark as no-show?",
            isPresented: $showNoShowConfirm,
            titleVisibility: .visible
        ) {
            Button("Charge 50% & mark no-show", role: .destructive) {
                Task { await performStatusChange(.noShow) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will charge the client's vaulted card for 50% of the service price.")
        }
        .confirmationDialog(
            "Cancel appointment?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel appointment", role: .destructive) {
                Task { await performStatusChange(.cancel) }
            }
            Button("Keep appointment", role: .cancel) {}
        } message: {
            Text("The client will be notified and the booking will be removed from your calendar.")
        }
    }

    // MARK: - Header

    private var headerEyebrow: some View {
        Text(headerStatus.label.uppercased())
            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
            .tracking(AdminTheme.Typography.dayHeaderTracking)
            .foregroundStyle(headerStatus.color)
    }

    // MARK: - Cards

    private var clientCard: some View {
        Button {
            openClientProfile()
        } label: {
            AdminDetailCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Client")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                            .foregroundStyle(AdminTheme.stone700)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone500)
                    }

                    Text(BookingDisplay.clientDisplayName(
                        first: appointment.clientFirstName,
                        last: appointment.clientLastName
                    ))
                    .font(AdminTheme.fontAdminSerif(size: 20))
                    .foregroundStyle(AdminTheme.stone900)

                    if let phone = appointment.clientPhone, !phone.isEmpty {
                        detailLine(icon: "phone", text: Client(id: "preview", phone: phone).formattedPhone)
                    }

                    if let email = appointment.clientEmail, !email.isEmpty {
                        detailLine(icon: "envelope", text: email)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(appointment.clientPhone?.filter(\.isNumber).isEmpty ?? true)
        .opacity(appointment.clientPhone?.filter(\.isNumber).isEmpty ?? true ? 0.55 : 1)
    }

    private var timeCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Date & time")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                Text(BookingDisplay.formattedDetailDate(for: appointment))
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)

                Text(BookingDisplay.formattedDetailTimeRange(for: appointment))
                    .font(AdminTheme.fontAdminSans(size: 15))
                    .foregroundStyle(AdminTheme.stone700)
            }
        }
    }

    private var serviceCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Service")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                Text(BookingDisplay.appointmentServiceLabel(appointment))
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)

                if let mins = BookingDisplay.appointmentDurationMinutes(appointment) {
                    Text("\(mins) min")
                        .font(AdminTheme.fontAdminSans(size: 14))
                        .foregroundStyle(AdminTheme.stone700)
                }

                if let priceText = BookingDisplay.formattedPrice(appointment.servicePrice) {
                    Text(priceText)
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                }

                if let description = appointment.serviceDescription,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(AdminTheme.fontAdminSans(size: 14))
                        .foregroundStyle(AdminTheme.stone700)
                        .italic()
                        .padding(.top, 4)
                }
            }
        }
    }

    private func detailLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)
                .frame(width: 16)
            Text(text)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
        }
    }

    // MARK: - Actions

    private var actionFooter: some View {
        VStack(spacing: 0) {
            Divider().overlay(AdminTheme.stone200)

            HStack(spacing: 8) {
                actionButton(
                    title: "Reschedule",
                    style: .neutral,
                    disabled: !canReschedule || isBusy
                ) {
                    openReschedule()
                }

                actionButton(
                    title: statusAction == .noShow ? "Charging…" : "No-show",
                    style: .amber,
                    disabled: !canChargeNoShow || isBusy
                ) {
                    if canChargeNoShow {
                        showNoShowConfirm = true
                    } else {
                        statusError = "Requires a vaulted card and service price on file."
                    }
                }

                actionButton(
                    title: statusAction == .cancel ? "Canceling…" : "Cancel",
                    style: .destructive,
                    disabled: isBusy
                ) {
                    showCancelConfirm = true
                }
            }
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.vertical, 14)
            .background(AdminTheme.cardFill)
        }
    }

    private enum ActionStyle {
        case neutral, amber, destructive
    }

    private func actionButton(
        title: String,
        style: ActionStyle,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(foreground(for: style))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AdminTheme.cardFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(border(for: style), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func foreground(for style: ActionStyle) -> Color {
        switch style {
        case .neutral: return AdminTheme.stone700
        case .amber: return AdminTheme.awaitingPaymentText
        case .destructive: return AdminTheme.rose600
        }
    }

    private func border(for style: ActionStyle) -> Color {
        switch style {
        case .neutral: return AdminTheme.stone200
        case .amber: return AdminTheme.awaitingPaymentBorder
        case .destructive: return AdminTheme.rose600.opacity(0.35)
        }
    }

    // MARK: - Logic

    private func openClientProfile() {
        clientProfileEntry = .fromAppointment(appointment)
    }

    private func openReschedule() {
        guard let uid = appointment.calUid,
              let encoded = uid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cal.com/reschedule/\(encoded)") else {
            return
        }
        rescheduleLink = RescheduleSafariLink(url: url)
    }

    private enum StatusAction {
        case noShow, cancel
    }

    private func performStatusChange(_ action: StatusAction) async {
        statusAction = action
        statusError = nil
        defer { statusAction = nil }

        let status: String
        switch action {
        case .noShow:
            status = AppointmentStatus.noShow.rawValue
        case .cancel:
            status = AppointmentStatus.canceledByAdmin.rawValue
        }

        do {
            try await AdminAPIClient.shared.updateAppointmentStatus(
                id: appointment.id,
                status: status
            )
            onMutated()
            onDismiss()
        } catch {
            statusError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(Color.semanticRed)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }
}

private struct RescheduleSafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    AppointmentDetailSheet(
        appointment: .mockConfirmed,
        onDismiss: {},
        onMutated: {}
    )
}
