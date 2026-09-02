import SwiftUI

/// Payment box for the appointment detail sheet.
/// Unsettled: three side-by-side Charge / Cash / Comp actions.
/// Settled: emerald banner matching web `PaymentBox` (replaces the box).
struct AppointmentPaymentCard: View {
    let appointment: Appointment
    @Binding var payment: AppointmentPaymentSummary?
    var knownAppointments: [Appointment] = []
    var onPaymentChanged: (AppointmentPaymentSummary?, [String]) -> Void

    @State private var showTerminal = false
    @State private var settlementMethod: AppointmentSettlementMethod?
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showUndoConfirmation = false
    @State private var pendingPatches: [(AppointmentPaymentSummary?, [String])] = []
    @State private var siblings: [SameDayUnsettledVisit] = []
    @State private var selectedExtraIds: Set<String> = []

    private var succeededPayment: AppointmentPaymentSummary? {
        guard payment?.isSettled == true else { return nil }
        return payment
    }

    private var isConfirmed: Bool {
        BookingDisplay.isConfirmed(appointment)
    }

    var body: some View {
        Group {
            if let succeededPayment {
                settlementBanner(succeededPayment)
            } else {
                unsettledBox
            }
        }
        .fullScreenCover(isPresented: $showTerminal) {
            TerminalChargeView(
                appointment: appointment.withTerminalPayment(payment),
                initialPayment: payment,
                knownAppointments: knownAppointments,
                onPaymentChanged: { updated, ids in
                    commitPayment(updated, relatedIds: ids)
                },
                onClose: { showTerminal = false }
            )
        }
        .sheet(item: $settlementMethod, onDismiss: flushPendingPaymentApply) { method in
            settlementSheet(method)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AdminTheme.cream)
                .task { await loadSiblings() }
        }
        .confirmationDialog(
            "Undo settlement?",
            isPresented: $showUndoConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "Undo \(BookingDisplay.settlementLabel(for: payment) ?? "settlement")",
                role: .destructive
            ) {
                Task { await undoSettlement() }
            }
            Button("Keep settlement", role: .cancel) {}
        } message: {
            Text("The appointment will return to unpaid. Card payments can only be refunded in Stripe.")
        }
    }

    // MARK: - Unsettled box

    private var unsettledBox: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Payment")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                Text(
                    isConfirmed
                        ? "Choose how this appointment was settled."
                        : "Only confirmed appointments can be settled."
                )
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone700)

                HStack(spacing: 8) {
                    paymentAction("Charge", icon: "creditcard") {
                        showTerminal = true
                    }
                    .disabled(!isConfirmed || isSubmitting || !hasChargeablePrice)

                    paymentAction("Cash", icon: "dollarsign") {
                        prepareSettlement(.cash)
                    }
                    .disabled(!isConfirmed || isSubmitting || appointment.servicePrice == nil)

                    paymentAction("Comp", icon: "heart") {
                        prepareSettlement(.complimentary)
                    }
                    .disabled(!isConfirmed || isSubmitting)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func paymentAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(title.uppercased())
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                    .tracking(1)
            }
            .foregroundStyle(AdminTheme.stone900)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(AdminTheme.stone50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settled banner (web PaymentBox)

    private func settlementBanner(_ payment: AppointmentPaymentSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AdminTheme.confirmedText)
                        .frame(width: 32, height: 32)
                        .background(Color(red: 209 / 255, green: 250 / 255, blue: 229 / 255))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(BookingDisplay.settlementBannerEyebrow(for: payment).uppercased())
                            .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                            .tracking(2.2)
                            .foregroundStyle(AdminTheme.confirmedText)

                        Text(BookingDisplay.settlementBannerSubtitle(for: payment))
                            .font(AdminTheme.fontAdminSans(size: 14))
                            .foregroundStyle(Color(red: 2 / 255, green: 44 / 255, blue: 34 / 255))

                        if let note = payment.note, !note.isEmpty {
                            Text(note)
                                .font(AdminTheme.fontAdminSans(size: 12))
                                .foregroundStyle(AdminTheme.confirmedText.opacity(0.8))
                                .padding(.top, 2)
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(BookingDisplay.settlementBannerAmount(for: payment))
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(Color(red: 2 / 255, green: 44 / 255, blue: 34 / 255))
            }

            if BookingDisplay.canUndoSettlement(payment) {
                Button {
                    showUndoConfirmation = true
                } label: {
                    Text(isSubmitting ? "UNDOING…" : "UNDO SETTLEMENT")
                        .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(AdminTheme.confirmedText.opacity(0.85))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdminTheme.confirmedBackground.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.confirmedBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }

    // MARK: - Settlement confirm sheet

    private func settlementSheet(_ method: AppointmentSettlementMethod) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(method == .cash ? "Mark paid cash" : "Mark complimentary")
                                .font(AdminTheme.fontAdminSerif(size: 23))
                                .foregroundStyle(AdminTheme.stone900)
                            Text(settlementExplanation(method))
                                .font(AdminTheme.fontAdminSans(size: 13))
                                .foregroundStyle(AdminTheme.stone700)
                        }

                        SameDayVisitChecklist(
                            primary: appointment,
                            siblings: siblings,
                            selectedExtraIds: selectedExtraIds,
                            disabled: isSubmitting
                        ) { id in
                            if selectedExtraIds.contains(id) {
                                selectedExtraIds.remove(id)
                            } else {
                                selectedExtraIds.insert(id)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note (optional)")
                                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                                .foregroundStyle(AdminTheme.stone700)
                            TextField("Add context for your records", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Button {
                    Task { await settle(method) }
                } label: {
                    Text(isSubmitting ? "Saving…" : confirmationTitle(method))
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AdminTheme.stone900)
                        .clipShape(Capsule())
                }
                .disabled(isSubmitting)
            }
            .padding(AdminTheme.Spacing.listHorizontal)
            .background(AdminTheme.cream)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { settlementMethod = nil }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    // MARK: - Actions

    private var hasChargeablePrice: Bool {
        guard let price = appointment.servicePrice else { return false }
        return price >= 0.5
    }

    private var selectedCashTotalCents: Int {
        let extra = siblings
            .filter { selectedExtraIds.contains($0.id) }
            .reduce(0) { $0 + $1.quotedCents }
        return TerminalDiscount.quotedCents(fromServicePrice: appointment.servicePrice) + extra
    }

    private var selectedVisitCount: Int {
        1 + selectedExtraIds.count
    }

    private func settlementExplanation(_ method: AppointmentSettlementMethod) -> String {
        switch method {
        case .cash:
            if selectedVisitCount > 1 {
                return "Record \(BookingDisplay.formattedCents(selectedCashTotalCents)) across \(selectedVisitCount) visits as paid outside Stripe."
            }
            return "Record \(BookingDisplay.formattedPrice(appointment.servicePrice) ?? "the service price") as paid outside Stripe."
        case .complimentary:
            if selectedVisitCount > 1 {
                return "Record \(selectedVisitCount) visits as settled with no payment collected."
            }
            return "Record this service as settled with no payment collected."
        }
    }

    private func confirmationTitle(_ method: AppointmentSettlementMethod) -> String {
        method == .cash ? "Mark paid cash" : "Mark complimentary"
    }

    private func prepareSettlement(_ method: AppointmentSettlementMethod) {
        errorMessage = nil
        note = ""
        selectedExtraIds = []
        settlementMethod = method
    }

    @MainActor
    private func loadSiblings() async {
        let local = SameDayUnsettledMatching.visits(
            of: appointment,
            among: knownAppointments
        )
        siblings = local
        do {
            let remote = try await AdminAPIClient.shared.fetchSameDayUnsettled(
                appointmentId: appointment.id
            )
            siblings = SameDayUnsettledMatching.preferRemote(remote, local: local)
        } catch {
            siblings = local
        }
    }

    @MainActor
    private func settle(_ method: AppointmentSettlementMethod) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let extras = Array(selectedExtraIds)
        do {
            let result = try await AdminAPIClient.shared.settleAppointment(
                appointmentId: appointment.id,
                method: method,
                note: note,
                additionalAppointmentIds: extras
            )
            if result.succeeded, let payments = result.response.payments, !payments.isEmpty {
                pendingPatches = paymentPatches(from: payments, extras: extras)
                settlementMethod = nil
                return
            }
            if result.succeeded, let updated = result.response.payment {
                pendingPatches = [(updated, [appointment.id] + extras)]
                settlementMethod = nil
                return
            }
            if let updated = result.response.payment, updated.isSettled {
                pendingPatches = [(updated, [appointment.id] + extras)]
                settlementMethod = nil
                return
            }
            errorMessage = result.response.message ?? "Could not save this settlement."
            settlementMethod = nil
        } catch {
            errorMessage = error.localizedDescription
            settlementMethod = nil
        }
    }

    private func paymentPatches(
        from payments: [AppointmentPaymentSummary],
        extras: [String]
    ) -> [(AppointmentPaymentSummary?, [String])] {
        if payments.count == 1 {
            return [(payments[0], [appointment.id] + extras)]
        }
        return payments.map { payment in
            (payment, [payment.appointmentId ?? appointment.id])
        }
    }

    @MainActor
    private func undoSettlement() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let result = try await AdminAPIClient.shared.undoAppointmentSettlement(
                appointmentId: appointment.id
            )
            if result.succeeded {
                commitPayment(nil, relatedIds: [appointment.id])
            } else if let updated = result.response.payment {
                commitPayment(
                    updated.isSettled ? updated : nil,
                    relatedIds: [appointment.id]
                )
                errorMessage = result.response.message
            } else {
                errorMessage = result.response.message ?? "Could not undo this settlement."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func flushPendingPaymentApply() {
        guard !pendingPatches.isEmpty else { return }
        let patches = pendingPatches
        pendingPatches = []
        for (updated, ids) in patches {
            commitPayment(updated, relatedIds: ids)
        }
    }

    private func commitPayment(_ updated: AppointmentPaymentSummary?, relatedIds: [String]) {
        if relatedIds.contains(appointment.id) {
            payment = updated
        }
        onPaymentChanged(updated, relatedIds)
    }
}

extension AppointmentSettlementMethod: Identifiable {
    var id: String { rawValue }
}
