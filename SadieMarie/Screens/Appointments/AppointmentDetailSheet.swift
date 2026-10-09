import SwiftUI

/// Deep-dive sheet for a single booking (mirrors web `AppointmentModal`).
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    var knownAppointments: [Appointment] = []
    var onDismiss: () -> Void
    var onMutated: () -> Void
    var onPaymentMutated: (AppointmentPaymentSummary?, [String], [AppointmentPaymentSummary]?) -> Void
    var onVisitUpdated: (Appointment) -> Void

    @State private var statusAction: StatusAction?
    @State private var statusError: String?
    @State private var statusSuccessMessage: String?
    @State private var showStatusSuccessAlert = false
    @State private var showNoShowConfirm = false
    @State private var showCancelConfirm = false
    @State private var cancelSendSms = true
    @State private var showReschedule = false
    @State private var showChangeService = false
    @State private var clientProfileEntry: ClientProfileEntry?
    /// Live settlement snapshot so Comp/Cash/Charge update the open sheet
    /// immediately without relying on a close/reopen cycle.
    @State private var livePayment: AppointmentPaymentSummary?
    @State private var liveVisit: Appointment
    @State private var liveExtras: [Appointment]
    @State private var extraBusy = false
    @State private var extraError: String?
    @State private var showExtraPicker = false

    init(
        appointment: Appointment,
        knownAppointments: [Appointment] = [],
        onDismiss: @escaping () -> Void,
        onMutated: @escaping () -> Void,
        onPaymentMutated: @escaping (AppointmentPaymentSummary?, [String], [AppointmentPaymentSummary]?) -> Void = { _, _, _ in },
        onVisitUpdated: @escaping (Appointment) -> Void = { _ in }
    ) {
        self.appointment = appointment
        self.knownAppointments = knownAppointments
        self.onDismiss = onDismiss
        self.onMutated = onMutated
        self.onPaymentMutated = onPaymentMutated
        self.onVisitUpdated = onVisitUpdated
        _livePayment = State(initialValue: appointment.terminalPayment)
        _liveVisit = State(initialValue: appointment)
        _liveExtras = State(initialValue: appointment.extras)
    }

    private var liveAppointment: Appointment {
        liveVisit
            .withTerminalPayment(livePayment)
            .withExtras(liveExtras)
    }

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

    /// Unpaid confirmed visit whose start is still in the future.
    /// A saved card is not payment.
    private var canChangeService: Bool {
        let visit = liveAppointment
        guard !BookingDisplay.isReadOnly(visit) else { return false }
        guard visit.attachedToAppointmentId == nil else { return false }
        guard BookingDisplay.isConfirmed(visit) else { return false }
        guard visit.terminalPayment?.isSettled != true else { return false }
        guard let iso = visit.bookingTime,
              let start = BookingDisplay.iso8601Date(from: iso) else {
            return false
        }
        return start > Date()
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
                    headerBlock

                    if let statusError {
                        errorBanner(statusError)
                    }

                    clientCard
                    timeCard
                    serviceCard
                    if !isReadOnly || !liveExtras.isEmpty {
                        VisitExtrasCard(
                            extras: liveExtras,
                            chairMins: ChairDuration.displayedMinutes(for: liveAppointment),
                            catalogueMins: liveAppointment.catalogueDurationMins,
                            parentLabel: BookingDisplay.appointmentServiceLabel(liveAppointment),
                            timeRangeLabel: BookingDisplay.formattedDetailTimeRange(for: liveAppointment),
                            canEdit: !isReadOnly && BookingDisplay.isConfirmed(liveAppointment),
                            isBusy: extraBusy || isBusy,
                            errorMessage: extraError,
                            onAdd: { showExtraPicker = true },
                            onRemove: { extraId in
                                Task { await removeExtra(extraId) }
                            },
                            onStepDuration: { delta in
                                Task { await stepVisitLength(delta) }
                            }
                        )
                    }
                    if !isReadOnly {
                        AppointmentPaymentCard(
                            appointment: liveAppointment,
                            payment: $livePayment,
                            knownAppointments: knownAppointments,
                            onPaymentChanged: { payment, ids, payments in
                                liveAppointmentUpdated(
                                    payment: payment,
                                    ids: ids,
                                    payments: payments
                                )
                            }
                        )
                    }
                    if let notes = BookingDisplay.clientBookingNotes(for: appointment) {
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
        .sheet(isPresented: $showExtraPicker) {
            ExtraServicePickerSheet(
                onSelect: { service in
                    showExtraPicker = false
                    Task { await addExtra(service) }
                },
                onCancel: { showExtraPicker = false }
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
        .fullScreenCover(isPresented: $showChangeService) {
            ChangeServiceView(
                appointment: liveAppointment,
                onBack: { showChangeService = false },
                onSuccess: {
                    showChangeService = false
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
        .overlay {
            if showCancelConfirm {
                CancelAppointmentConfirmOverlay(
                    clientName: BookingDisplay.clientDisplayName(
                        first: appointment.clientFirstName,
                        last: appointment.clientLastName
                    ),
                    bookingHasEnded: !BookingDisplay.isUpcoming(appointment),
                    sendSms: $cancelSendSms,
                    busy: statusAction == .cancel,
                    onDismiss: {
                        if statusAction != .cancel {
                            showCancelConfirm = false
                        }
                    },
                    onConfirm: {
                        Task { await performStatusChange(.cancel, sendSms: cancelSendSms) }
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCancelConfirm)
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

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerStatus.label.uppercased())
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(headerStatus.color)

            Text("Appointment")
                .font(AdminTheme.fontAdminSerif(size: 28))
                .foregroundStyle(AdminTheme.stone900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Cards

    private var clientCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Client", icon: "person")

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(BookingDisplay.clientDisplayName(
                        first: appointment.clientFirstName,
                        last: appointment.clientLastName
                    ))
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(AdminTheme.stone900)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }

                if let phone = appointment.clientPhone, !phone.isEmpty {
                    CopyablePhoneButton(
                        phone: phone,
                        font: AdminTheme.fontAdminSans(size: 14),
                        iconPointSize: 12,
                        spacing: 8
                    )
                }

                if let email = appointment.clientEmail, !email.isEmpty {
                    detailLine(icon: "envelope", text: email)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openClientProfile()
        }
        .accessibilityAddTraits(.isButton)
        .opacity(appointment.clientPhone?.filter(\.isNumber).isEmpty ?? true ? 0.55 : 1)
        .allowsHitTesting(!(appointment.clientPhone?.filter(\.isNumber).isEmpty ?? true))
    }

    private var timeCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Date & Time", icon: "calendar")

                Text(BookingDisplay.formattedDetailDate(for: liveAppointment))
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                    Text(BookingDisplay.formattedDetailTimeRange(for: liveAppointment))
                        .font(AdminTheme.fontAdminSans(size: 15))
                        .foregroundStyle(AdminTheme.stone700)
                }
                .padding(.top, 2)
            }
        }
    }

    private var serviceCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Service", icon: "scissors")

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(BookingDisplay.appointmentServiceLabel(liveAppointment))
                            .font(AdminTheme.fontAdminSerif(size: 18))
                            .foregroundStyle(AdminTheme.stone900)

                        if let description = appointment.serviceDescription,
                           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(description)
                                .font(AdminTheme.fontAdminSans(size: 14))
                                .foregroundStyle(AdminTheme.stone500)
                                .italic()
                                .lineLimit(4)
                        }
                    }

                    Spacer(minLength: 8)

                    if let priceText = BookingDisplay.formattedPrice(appointment.servicePrice) {
                        Text(priceText)
                            .font(AdminTheme.fontAdminSerif(size: 18))
                            .foregroundStyle(AdminTheme.stone900)
                    }
                }
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Booking notes", icon: "text.alignleft")
                Text(notes)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)
            Text(title.uppercased())
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(AdminTheme.stone500)
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

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if canChangeService {
                        actionButton(
                            title: "Change service",
                            style: .neutral,
                            disabled: isBusy
                        ) {
                            showChangeService = true
                        }
                    }

                    actionButton(
                        title: "Reschedule",
                        style: .neutral,
                        disabled: !canReschedule || isBusy
                    ) {
                        openReschedule()
                    }
                }

                HStack(spacing: 8) {
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
                        cancelSendSms = true
                        showCancelConfirm = true
                    }
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

    private func liveAppointmentUpdated(
        payment: AppointmentPaymentSummary?,
        ids: [String],
        payments: [AppointmentPaymentSummary]?
    ) {
        let patched = liveAppointment.withPatchedPayments(
            ids: ids,
            payment: payment,
            payments: payments
        )
        liveVisit = patched
        livePayment = patched.terminalPayment
        liveExtras = patched.extras
        onPaymentMutated(payment, ids, payments)
    }

    private func applyVisit(_ visit: Appointment) {
        liveVisit = liveVisit.mergingVisit(visit)
        liveExtras = visit.extras
        if let payment = visit.terminalPayment {
            livePayment = payment
        }
        onVisitUpdated(liveAppointment)
    }

    private func addExtra(_ service: ManualBookingServiceOption) async {
        guard !extraBusy else { return }
        extraBusy = true
        extraError = nil
        defer { extraBusy = false }
        do {
            let response = try await AdminAPIClient.shared.addAppointmentExtra(
                appointmentId: appointment.id,
                eventTypeId: service.eventTypeId
            )
            if let visit = response.appointment {
                applyVisit(visit)
            } else if let extra = response.extra {
                liveExtras.append(extra)
                liveVisit = liveVisit.withExtras(liveExtras)
                onVisitUpdated(liveAppointment)
            }
        } catch {
            extraError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func removeExtra(_ extraId: String) async {
        guard !extraBusy else { return }
        extraBusy = true
        extraError = nil
        defer { extraBusy = false }
        do {
            let response = try await AdminAPIClient.shared.deleteAppointmentExtra(
                appointmentId: appointment.id,
                extraId: extraId
            )
            if let visit = response.appointment {
                applyVisit(visit)
            } else {
                liveExtras.removeAll { $0.id == extraId }
                liveVisit = liveVisit.withExtras(liveExtras)
                onVisitUpdated(liveAppointment)
            }
        } catch {
            extraError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func stepVisitLength(_ deltaMins: Int) async {
        guard !extraBusy, !isReadOnly else { return }
        let next = ChairDuration.displayedMinutes(for: liveAppointment) + deltaMins
        guard next >= ChairDuration.minMinutes, next <= ChairDuration.maxMinutes else { return }
        extraBusy = true
        extraError = nil
        defer { extraBusy = false }
        do {
            let visit = try await AdminAPIClient.shared.patchAppointmentDuration(
                appointmentId: appointment.id,
                durationMins: next
            )
            applyVisit(visit)
        } catch {
            extraError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

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

    private func performStatusChange(_ action: StatusAction, sendSms: Bool = true) async {
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
                chargeNoShow: chargeNoShow,
                sendSms: action == .cancel ? sendSms : nil
            )
            if let calError = response.calCancelError, !calError.isEmpty {
                let expectedPastReject =
                    action == .cancel
                    && !BookingDisplay.isUpcoming(appointment)
                    && calError.range(
                        of: "already ended",
                        options: .caseInsensitive
                    ) != nil
                if !expectedPastReject {
                    statusError = "Canceled locally, but Cal.com reported: \(calError)"
                    showCancelConfirm = false
                    onMutated()
                    return
                }
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
            showCancelConfirm = false
            onMutated()
            onDismiss()
        } catch {
            showCancelConfirm = false
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

/// Card overlay for admin cancel (confirmationDialog cannot host a toggle).
private struct CancelAppointmentConfirmOverlay: View {
    let clientName: String
    var bookingHasEnded: Bool
    @Binding var sendSms: Bool
    var busy: Bool
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    private var displayName: String {
        clientName.isEmpty ? "this client" : clientName
    }

    var body: some View {
        GeometryReader { geo in
            let maxWidth = min(geo.size.width - 40, 420)

            ZStack {
                ZStack {
                    AdminTheme.cream.opacity(0.72)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !busy { onDismiss() }
                }
                .accessibilityLabel("Dismiss cancel")

                VStack(spacing: 0) {
                    header
                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)
                    bodyCopy
                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)
                    footer
                }
                .frame(width: maxWidth)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cancel booking")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                Text("Cancel this appointment?")
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(AdminTheme.stone900)
            }
            Spacer(minLength: 8)
            Button {
                if !busy { onDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 28, height: 28)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bodyCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if bookingHasEnded {
                    Text("This booking for \(displayName) has already ended.")
                } else {
                    Text("This will cancel the booking for \(displayName).")
                }
            }
            .font(AdminTheme.fontAdminSans(size: 14))
            .foregroundStyle(AdminTheme.stone600)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                numberedStep(1, "It comes off your dashboard.")
                numberedStep(
                    2,
                    bookingHasEnded
                        ? "Cal.com keeps it as a completed visit. They don’t allow cancelling a booking that has already ended."
                        : "Cal.com cancels the booking, including their cancellation email to the client."
                )
                numberedStep(
                    3,
                    "A studio text still goes out unless you uncheck below."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if bookingHasEnded {
                Text("If they didn’t come, go back and use No-show instead.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AdminSendSmsToggle(isOn: $sendSms, disabled: busy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func numberedStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                .foregroundStyle(AdminTheme.stone600)
                .frame(width: 20, height: 20)
                .background(AdminTheme.stone100)
                .clipShape(Circle())
            Text(text)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                if !busy { onDismiss() }
            } label: {
                Text("Go back")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone600)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(
                        Capsule().stroke(AdminTheme.stone200, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Button {
                if !busy { onConfirm() }
            } label: {
                HStack(spacing: 6) {
                    if busy {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    }
                    Text(busy ? "Canceling" : "Confirm cancel")
                }
                .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AdminTheme.rose600)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    AppointmentDetailSheet(
        appointment: .mockConfirmed,
        onDismiss: {},
        onMutated: {}
    )
}
