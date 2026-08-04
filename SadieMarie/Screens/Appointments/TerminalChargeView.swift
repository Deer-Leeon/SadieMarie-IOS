import SwiftUI

/// Server-driven S710 flow. The phone never connects to the reader directly;
/// it starts/reconciles actions through the authenticated admin API.
struct TerminalChargeView: View {
    let appointment: Appointment
    let initialPayment: AppointmentPaymentSummary?
    var onPaymentChanged: (AppointmentPaymentSummary?) -> Void
    var onClose: () -> Void

    @State private var payment: AppointmentPaymentSummary?
    @State private var reader: TerminalReaderSummary?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showAttemptResult = false

    init(
        appointment: Appointment,
        initialPayment: AppointmentPaymentSummary?,
        onPaymentChanged: @escaping (AppointmentPaymentSummary?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.appointment = appointment
        self.initialPayment = initialPayment
        self.onPaymentChanged = onPaymentChanged
        self.onClose = onClose
        _payment = State(initialValue: initialPayment)
    }

    private var isSucceeded: Bool {
        payment?.status == .succeeded
    }

    private var isActive: Bool {
        payment?.paymentKind == .servicePayment
            && (payment?.status == .pending || payment?.status == .processing)
    }

    private var showsFailure: Bool {
        showAttemptResult
            && (payment?.status == .failed || payment?.status == .canceled)
    }

    private var readerIsOffline: Bool {
        reader?.status?.lowercased() == "offline"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    readerIllustration

                    if isSucceeded {
                        receiptCard
                    } else if isActive {
                        waitingContent
                    } else if showsFailure {
                        failureContent
                    } else {
                        readyContent
                    }

                    if let errorMessage, !showsFailure {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.vertical, 24)
            }
            .background(AdminTheme.cream)
            .navigationTitle("Charge client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .disabled(isSubmitting)
                }
            }
            .toolbarBackground(AdminTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .task {
            await startAutomaticallyIfNeeded()
        }
        .task(id: isActive) {
            guard isActive else { return }
            await pollWhileActive()
        }
    }

    private var readerIllustration: some View {
        ZStack {
            Circle()
                .fill(isSucceeded ? Color.green.opacity(0.12) : AdminTheme.stone100)
                .frame(width: 92, height: 92)
            Image(systemName: isSucceeded ? "checkmark.circle.fill" : "creditcard.and.123")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(isSucceeded ? Color.green : AdminTheme.stone700)
        }
        .padding(.top, 8)
    }

    private var readyContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Ready for the S710")
                    .font(AdminTheme.fontAdminSerif(size: 24))
                    .foregroundStyle(AdminTheme.stone900)
                Text("Send the exact service price to the reader. Your client can choose a tip and tap or insert their card.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
                    .multilineTextAlignment(.center)
            }

            amountCard

            primaryButton(title: isSubmitting ? "Sending…" : "Send to terminal") {
                Task { await startPayment() }
            }
            .disabled(isSubmitting)
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)

            Text(payment?.status == .processing ? "Authorizing payment…" : "Waiting for client…")
                .font(AdminTheme.fontAdminSerif(size: 22))
                .foregroundStyle(AdminTheme.stone900)

            Text(readerStatusText)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(readerIsOffline ? Color.semanticRed : AdminTheme.stone700)
                .multilineTextAlignment(.center)

            amountCard

            Button(role: .destructive) {
                Task { await cancelPayment() }
            } label: {
                Text(isSubmitting ? "Canceling…" : "Cancel reader")
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
            .disabled(isSubmitting || payment?.status == .processing)
        }
    }

    private var failureContent: some View {
        VStack(spacing: 16) {
            Text(payment?.status == .canceled ? "Payment canceled" : "Reader needs another try")
                .font(AdminTheme.fontAdminSerif(size: 22))
                .foregroundStyle(AdminTheme.stone900)

            Text(BookingDisplay.terminalFailureMessage(payment: payment, fallback: errorMessage))
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
                .multilineTextAlignment(.center)

            primaryButton(title: isSubmitting ? "Sending…" : "Try reader again") {
                Task { await retryPayment() }
            }
            .disabled(isSubmitting)
        }
    }

    private var amountCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(BookingDisplay.appointmentServiceLabel(appointment))
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Text("Tip is selected on the reader")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }
            Spacer()
            Text(servicePriceLabel)
                .font(AdminTheme.fontAdminSerif(size: 20))
                .foregroundStyle(AdminTheme.stone900)
        }
        .padding(16)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var receiptCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                Text("Payment complete")
                    .font(AdminTheme.fontAdminSerif(size: 24))
                    .foregroundStyle(AdminTheme.stone900)
                Text("The appointment is now marked paid.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
            }

            if let payment {
                VStack(spacing: 11) {
                    receiptRow("Service", cents: payment.baseAmountCents)
                    receiptRow("Tip", cents: payment.tipAmountCents)
                    Divider().overlay(AdminTheme.stone200)
                    receiptRow("Total", cents: payment.totalAmountCents, emphasized: true)
                }
                .padding(16)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }

            primaryButton(title: "Done", action: onClose)
        }
    }

    private func receiptRow(_ title: String, cents: Int, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 14, weight: emphasized ? .semibold : .regular))
            Spacer()
            Text(BookingDisplay.formattedCents(cents, currency: payment?.currency))
                .font(AdminTheme.fontAdminSans(size: 14, weight: emphasized ? .semibold : .regular))
        }
        .foregroundStyle(AdminTheme.stone900)
    }

    private var servicePriceLabel: String {
        BookingDisplay.formattedPrice(appointment.servicePrice) ?? "Price unavailable"
    }

    private var readerStatusText: String {
        if readerIsOffline {
            return "The reader is offline. Reconnect it to Wi-Fi while status keeps checking."
        }
        if let label = reader?.label, !label.isEmpty {
            return "\(label) is ready for the client."
        }
        return "Keep this screen open while the reader collects payment."
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AdminTheme.stone900)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }

    private func startPayment() async {
        await performOperation(automaticallyRetryFailedAttempt: true) {
            try await AdminAPIClient.shared.startTerminalPayment(appointmentId: appointment.id)
        }
    }

    private func startAutomaticallyIfNeeded() async {
        guard !isSucceeded, !isActive else { return }
        showAttemptResult = false
        await startPayment()
    }

    private func retryPayment() async {
        if payment?.status == .canceled {
            await startPayment()
            return
        }
        await performOperation {
            try await AdminAPIClient.shared.retryTerminalPayment(appointmentId: appointment.id)
        }
    }

    private func cancelPayment() async {
        await performOperation(showResult: true) {
            try await AdminAPIClient.shared.cancelTerminalPayment(appointmentId: appointment.id)
        }
    }

    private func performOperation(
        showResult: Bool = true,
        automaticallyRetryFailedAttempt: Bool = false,
        operation: () async throws -> PaymentOperationResult
    ) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var result = try await operation()
            apply(result.response)

            if automaticallyRetryFailedAttempt,
               result.response.error == "retry_required",
               result.response.payment?.isRetryableTerminalPayment == true {
                result = try await AdminAPIClient.shared.retryTerminalPayment(
                    appointmentId: appointment.id
                )
                apply(result.response)
            }

            if let message = result.response.message, !result.succeeded {
                errorMessage = message
            }
            showAttemptResult = showResult
        } catch {
            errorMessage = error.localizedDescription
            showAttemptResult = payment?.status == .failed || payment?.status == .canceled
        }
    }

    private func apply(_ response: TerminalPaymentAPIResponse) {
        reader = response.reader ?? reader
        if let updated = response.payment {
            payment = updated
            onPaymentChanged(updated)
        }
    }

    private func pollWhileActive() async {
        while !Task.isCancelled && isActive {
            do {
                try await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                let result = try await AdminAPIClient.shared.fetchTerminalPayment(
                    appointmentId: appointment.id
                )
                apply(result.response)
                if let message = result.response.message, !result.succeeded {
                    errorMessage = message
                }
                if payment?.status == .failed || payment?.status == .canceled {
                    showAttemptResult = true
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
