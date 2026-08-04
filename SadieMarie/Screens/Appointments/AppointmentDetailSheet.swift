import SwiftUI

/// Deep-dive sheet for a single booking (mirrors web `AppointmentModal`).
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    var onDismiss: () -> Void
    var onMutated: () -> Void
    var onPaymentMutated: (AppointmentPaymentSummary?) -> Void = { _ in }

    @State private var statusAction: StatusAction?
    @State private var statusError: String?
    @State private var statusSuccessMessage: String?
    @State private var showStatusSuccessAlert = false
    @State private var showNoShowConfirm = false
    @State private var showCancelConfirm = false
    @State private var showReschedule = false
    @State private var clientProfileEntry: ClientProfileEntry?

    private var headerStatus: BookingDisplay.DetailHeaderStatus {
        BookingDisplay.detailHeaderStatus(for: appointment)
    }

    private var isReadOnly: Bool {
        BookingDisplay.isReadOnly(appointment)
    }

    private var canReschedule: Bool {
        guard !isReadOnly else { return false }
        guard let slug = appointment.serviceSlug, !slug.isEmpty else {
            return false
        }
        return true
    }

    private var canChargeNoShow: Bool {
        guard !isReadOnly else { return false }
        guard let stripeId = appointment.stripeCustomerId, !stripeId.isEmpty,
              let price = appointment.servicePrice, price > 0 else {
            return false
        }
        return true
    }

    private var noShowFeeCents: Int {
        guard let price = appointment.servicePrice else { return 0 }
        return BookingDisplay.noShowPenaltyCents(servicePriceDollars: price)
    }

    private var noShowFeeLabel: String {
        BookingDisplay.formattedCents(noShowFeeCents)
    }

    private var chargeNoShowButtonTitle: String {
        "Charge \(noShowFeeLabel) & mark no-show"
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
                    if !isReadOnly {
                        AppointmentPaymentCard(
                            appointment: appointment,
                            onPaymentChanged: onPaymentMutated
                        )
                    }
                    if let notes = appointment.bookingNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !notes.isEmpty {
                        notesCard(notes)
                    }
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AdminTheme.cream)
            .safeAreaInset(edge: .bottom) {
                if !isReadOnly {
                    actionFooter
                }
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
        .fullScreenCover(isPresented: $showReschedule) {
            RescheduleBookingView(
                appointment: appointment,
                onBack: { showReschedule = false },
                onSuccess: {
                    showReschedule = false
                    onMutated()
                    onDismiss()
                }
            )
        }
        .confirmationDialog(
            "Mark as no-show?",
            isPresented: $showNoShowConfirm,
            titleVisibility: .visible
        ) {
            if canChargeNoShow {
                Button(chargeNoShowButtonTitle, role: .destructive) {
                    Task { await performStatusChange(.noShowCharged) }
                }
            }
            Button("Mark no-show · flag (no charge)") {
                Task { await performStatusChange(.noShowNoCharge) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if canChargeNoShow {
                Text("This always adds 1 to their no-show count. Charge 100% (\(noShowFeeLabel)) of the service price on the card saved at checkout, or choose no charge to also flag them on the calendar and profile.")
            } else {
                Text("No vaulted card or service price on file. Marking no-show will flag them and increase their no-show count. A fee cannot be charged automatically.")
            }
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
        .alert(
            "No-show fee charged",
            isPresented: $showStatusSuccessAlert
        ) {
            Button("OK") {
                onMutated()
                onDismiss()
            }
        } message: {
            Text(statusSuccessMessage ?? "The no-show fee was charged successfully.")
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

    private func notesCard(_ notes: String) -> some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Booking notes")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
                Text(notes)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
                    .fixedSize(horizontal: false, vertical: true)
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
                    title: statusAction?.isNoShow == true ? "Saving…" : "No-show",
                    style: .amber,
                    disabled: isBusy
                ) {
                    showNoShowConfirm = true
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
        showReschedule = true
    }

    private enum StatusAction {
        case noShowCharged
        case noShowNoCharge
        case cancel

        var isNoShow: Bool {
            switch self {
            case .noShowCharged, .noShowNoCharge: return true
            case .cancel: return false
            }
        }
    }

    private func performStatusChange(_ action: StatusAction) async {
        guard !isReadOnly else { return }

        statusAction = action
        statusError = nil
        defer { statusAction = nil }

        let status: String
        let chargeNoShow: Bool?
        switch action {
        case .noShowCharged:
            status = AppointmentStatus.noShow.rawValue
            chargeNoShow = true
        case .noShowNoCharge:
            status = AppointmentStatus.noShow.rawValue
            chargeNoShow = false
        case .cancel:
            status = AppointmentStatus.canceledByAdmin.rawValue
            chargeNoShow = nil
        }

        do {
            let response = try await AdminAPIClient.shared.updateAppointmentStatus(
                id: appointment.id,
                status: status,
                chargeNoShow: chargeNoShow
            )
            if let calError = response.calCancelError, !calError.isEmpty {
                statusError = "Canceled locally, but Cal.com reported: \(calError)"
                onMutated()
                return
            }
            if action == .noShowCharged,
               let cents = response.noShowCharge?.amountCents,
               cents > 0 {
                let amount = BookingDisplay.formattedCents(
                    cents,
                    currency: response.noShowCharge?.currency
                )
                statusSuccessMessage = "Charged \(amount) to the card on file."
                showStatusSuccessAlert = true
                return
            }
            onMutated()
            onDismiss()
        } catch {
            statusError = Self.friendlyStatusError(error)
        }
    }

    private static func friendlyStatusError(_ error: Error) -> String {
        if let apiError = error as? AdminAPIError,
           case .server(_, let body) = apiError,
           let body,
           let parsed = parseServerErrorBody(body) {
            let code = parsed.error ?? ""
            let message = parsed.message ?? code
            switch code {
            case "card_declined",
                 "authentication_required",
                 "no_payment_method",
                 "no_vaulted_card":
                return "Card charge failed: \(message.isEmpty ? code : message)"
            default:
                if !message.isEmpty {
                    return message
                }
            }
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func parseServerErrorBody(_ body: String) -> (error: String?, message: String?)? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let error = json["error"] as? String
        let message = json["message"] as? String
        if error == nil && message == nil { return nil }
        return (error, message)
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

#Preview {
    AppointmentDetailSheet(
        appointment: .mockConfirmed,
        onDismiss: {},
        onMutated: {}
    )
}
