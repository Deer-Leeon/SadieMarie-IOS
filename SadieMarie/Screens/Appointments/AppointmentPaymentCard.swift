import SwiftUI

struct AppointmentPaymentCard: View {
    let appointment: Appointment
    var onPaymentChanged: (AppointmentPaymentSummary?) -> Void

    @State private var payment: AppointmentPaymentSummary?
    @State private var showTerminal = false
    @State private var settlementMethod: AppointmentSettlementMethod?
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showUndoConfirmation = false

    init(
        appointment: Appointment,
        onPaymentChanged: @escaping (AppointmentPaymentSummary?) -> Void
    ) {
        self.appointment = appointment
        self.onPaymentChanged = onPaymentChanged
        _payment = State(initialValue: appointment.terminalPayment)
    }

    private var succeededPayment: AppointmentPaymentSummary? {
        guard payment?.isSettled == true else { return nil }
        return payment
    }

    private var isConfirmed: Bool {
        BookingDisplay.isConfirmed(appointment)
    }

    var body: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Payment")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                    Spacer()
                    if let succeededPayment,
                       let label = BookingDisplay.settlementLabel(for: succeededPayment) {
                        settlementBadge(label, payment: succeededPayment)
                    }
                }

                if let succeededPayment {
                    settledContent(succeededPayment)
                } else {
                    unsettledContent
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .fullScreenCover(isPresented: $showTerminal) {
            TerminalChargeView(
                appointment: appointment.withTerminalPayment(payment),
                initialPayment: payment,
                onPaymentChanged: applyPayment,
                onClose: { showTerminal = false }
            )
        }
        .sheet(item: $settlementMethod) { method in
            settlementSheet(method)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AdminTheme.cream)
        }
        .confirmationDialog(
            "Undo settlement?",
            isPresented: $showUndoConfirmation,
            titleVisibility: .visible
        ) {
            Button("Undo \(BookingDisplay.settlementLabel(for: payment) ?? "settlement")", role: .destructive) {
                Task { await undoSettlement() }
            }
            Button("Keep settlement", role: .cancel) {}
        } message: {
            Text("The appointment will return to unpaid. Card payments can only be refunded in Stripe.")
        }
    }

    private func settlementBadge(
        _ label: String,
        payment: AppointmentPaymentSummary
    ) -> some View {
        Label(label, systemImage: BookingDisplay.settlementSystemImage(for: payment))
            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
            .foregroundStyle(Color.green)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.11))
            .clipShape(Capsule())
    }

    private func settledContent(_ payment: AppointmentPaymentSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(settlementTitle(payment))
                        .font(AdminTheme.fontAdminSerif(size: 19))
                        .foregroundStyle(AdminTheme.stone900)
                    if let note = payment.note, !note.isEmpty {
                        Text(note)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                }
                Spacer()
                Text(BookingDisplay.formattedCents(
                    payment.totalAmountCents,
                    currency: payment.currency
                ))
                .font(AdminTheme.fontAdminSerif(size: 19))
                .foregroundStyle(AdminTheme.stone900)
            }

            if payment.paymentKind == .servicePayment, payment.tipAmountCents > 0 {
                Text("Includes \(BookingDisplay.formattedCents(payment.tipAmountCents, currency: payment.currency)) tip")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }

            if BookingDisplay.canUndoSettlement(payment) {
                Button("Undo settlement") {
                    showUndoConfirmation = true
                }
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(Color.semanticRed)
                .disabled(isSubmitting)
            }
        }
    }

    private var unsettledContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isConfirmed ? "Choose how this appointment was settled." : "Only confirmed appointments can be settled.")
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

    private func settlementSheet(_ method: AppointmentSettlementMethod) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(method == .cash ? "Mark paid cash" : "Mark complimentary")
                        .font(AdminTheme.fontAdminSerif(size: 23))
                        .foregroundStyle(AdminTheme.stone900)
                    Text(settlementExplanation(method))
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone700)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Note (optional)")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                    TextField("Add context for your records", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

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

    private var hasChargeablePrice: Bool {
        guard let price = appointment.servicePrice else { return false }
        return price >= 0.5
    }

    private func settlementTitle(_ payment: AppointmentPaymentSummary) -> String {
        switch payment.paymentKind {
        case .servicePayment: return "Paid by card"
        case .cash: return "Paid in cash"
        case .complimentary: return "Complimentary service"
        }
    }

    private func settlementExplanation(_ method: AppointmentSettlementMethod) -> String {
        switch method {
        case .cash:
            return "Record \(BookingDisplay.formattedPrice(appointment.servicePrice) ?? "the service price") as paid outside Stripe."
        case .complimentary:
            return "Record this service as settled with no payment collected."
        }
    }

    private func confirmationTitle(_ method: AppointmentSettlementMethod) -> String {
        method == .cash ? "Mark paid cash" : "Mark complimentary"
    }

    private func prepareSettlement(_ method: AppointmentSettlementMethod) {
        errorMessage = nil
        note = ""
        settlementMethod = method
    }

    private func settle(_ method: AppointmentSettlementMethod) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let result = try await AdminAPIClient.shared.settleAppointment(
                appointmentId: appointment.id,
                method: method,
                note: note
            )
            if let updated = result.response.payment,
               result.succeeded || updated.isSettled {
                applyPayment(updated)
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
                applyPayment(nil)
            } else if let updated = result.response.payment {
                applyPayment(updated)
                errorMessage = result.response.message
            } else {
                errorMessage = result.response.message ?? "Could not undo this settlement."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPayment(_ updated: AppointmentPaymentSummary?) {
        payment = updated
        onPaymentChanged(updated)
    }
}

extension AppointmentSettlementMethod: Identifiable {
    var id: String { rawValue }
}
