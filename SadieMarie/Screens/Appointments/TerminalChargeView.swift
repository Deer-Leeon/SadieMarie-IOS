import SwiftUI

/// Server-driven S710 flow. The phone never connects to the reader directly;
/// it starts/reconciles actions through the authenticated admin API.
struct TerminalChargeView: View {
    let appointment: Appointment
    let initialPayment: AppointmentPaymentSummary?
    var knownAppointments: [Appointment] = []
    var chargeAppointmentId: String? = nil
    var includedVisitIds: [String] = []
    var chargeLines: [ChargeLine] = []
    var onPaymentChanged: (AppointmentPaymentSummary?, [String]) -> Void
    var onClose: () -> Void

    @State private var payment: AppointmentPaymentSummary?
    @State private var reader: TerminalReaderSummary?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showAttemptResult = false
    @State private var amountMode: TerminalAmountMode = .discount(percent: 0)
    @State private var customDollars: String
    @State private var siblings: [SameDayUnsettledVisit] = []
    @State private var selectedExtraIds: Set<String> = []
    @FocusState private var customAmountFocused: Bool

    init(
        appointment: Appointment,
        initialPayment: AppointmentPaymentSummary?,
        knownAppointments: [Appointment] = [],
        chargeAppointmentId: String? = nil,
        includedVisitIds: [String] = [],
        chargeLines: [ChargeLine] = [],
        onPaymentChanged: @escaping (AppointmentPaymentSummary?, [String]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.appointment = appointment
        self.initialPayment = initialPayment
        self.knownAppointments = knownAppointments
        self.chargeAppointmentId = chargeAppointmentId
        self.includedVisitIds = includedVisitIds
        self.chargeLines = chargeLines
        self.onPaymentChanged = onPaymentChanged
        self.onClose = onClose
        _payment = State(initialValue: initialPayment)
        let visitQuoted = chargeLines.isEmpty
            ? TerminalDiscount.quotedCents(fromServicePrice: appointment.servicePrice)
            : chargeLines.reduce(0) { $0 + $1.cents }
        _customDollars = State(
            initialValue: TerminalDiscount.formatCentsAsDollarInput(visitQuoted)
        )
    }

    private var chargeId: String { chargeAppointmentId ?? appointment.id }

    private var otherVisits: [SameDayUnsettledVisit] {
        let locked = Set(chargeLines.map(\.id) + includedVisitIds)
        return siblings.filter { !locked.contains($0.id) }
    }

    private var chargeSubtitle: String {
        let name = BookingDisplay.clientDisplayName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
        if !selectedExtraIds.isEmpty {
            let count = selectedExtraIds.count
            return "This visit + \(count) other \(count == 1 ? "appointment" : "appointments") for \(name)"
        }
        if chargeLines.count > 1 {
            return "This visit for \(name)"
        }
        return "\(BookingDisplay.appointmentServiceLabel(appointment)) for \(name)"
    }

    private var extraIds: [String] {
        Array(Set(includedVisitIds + otherVisits.filter { selectedExtraIds.contains($0.id) }.map(\.id)))
    }

    private var relatedIds: [String] {
        [chargeId] + extraIds
    }

    private var showsVisitBreakdown: Bool {
        chargeLines.count > 1
            || !appointment.unpaidExtras.isEmpty
            || !otherVisits.isEmpty
    }

    private var thisVisitQuotedCents: Int {
        if !chargeLines.isEmpty {
            return chargeLines.reduce(0) { $0 + $1.cents }
        }
        return TerminalDiscount.quotedCents(fromServicePrice: appointment.servicePrice)
    }

    private var quotedCents: Int {
        let extras = otherVisits
            .filter { selectedExtraIds.contains($0.id) }
            .reduce(0) { $0 + $1.quotedCents }
        return thisVisitQuotedCents + extras
    }

    private var customCents: Int? {
        TerminalDiscount.parseDollarsToCents(customDollars)
    }

    private var chargeCents: Int {
        switch amountMode {
        case .custom:
            return customCents ?? 0
        case .discount(let percent):
            return TerminalDiscount.apply(quotedCents: quotedCents, percent: percent)
        }
    }

    private var canSend: Bool {
        switch amountMode {
        case .custom:
            return customCents.map(TerminalDiscount.isValidCustomAmountCents) ?? false
        case .discount:
            return chargeCents >= TerminalDiscount.minimumChargeCents
        }
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
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .task {
            await loadSiblings()
        }
        .task(id: isActive) {
            guard isActive else { return }
            await pollWhileActive()
        }
        .onChange(of: quotedCents) { _, newValue in
            if amountMode != .custom {
                customDollars = TerminalDiscount.formatCentsAsDollarInput(newValue)
            }
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
                Text("In-person payment")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)

                Text(BookingDisplay.formattedCents(chargeCents))
                    .font(AdminTheme.fontAdminSerif(size: 36))
                    .foregroundStyle(AdminTheme.stone900)

                amountSubtitle

                Text(chargeSubtitle)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
                .multilineTextAlignment(.center)
            }

            if showsVisitBreakdown {
                ChargeBreakdownView(
                    lines: chargeLines.isEmpty
                        ? [
                            ChargeLine(
                                id: appointment.id,
                                label: BookingDisplay.appointmentServiceLabel(appointment),
                                cents: thisVisitQuotedCents,
                                detail: "Scheduled service"
                            )
                        ]
                        : chargeLines,
                    totalCents: thisVisitQuotedCents,
                    heading: "This visit"
                )
            }

            SameDayVisitChecklist(
                siblings: otherVisits,
                selectedExtraIds: selectedExtraIds,
                disabled: isSubmitting
            ) { id in
                if selectedExtraIds.contains(id) {
                    selectedExtraIds.remove(id)
                } else {
                    selectedExtraIds.insert(id)
                }
            }

            if !selectedExtraIds.isEmpty {
                HStack {
                    Text("Charge")
                    Spacer()
                    Text(BookingDisplay.formattedCents(quotedCents))
                }
                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AdminTheme.stone50)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }

            amountPicker

            Text("Choose full price, a discount, or a custom amount. The reader will still offer tip options.")
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
                .multilineTextAlignment(.center)

            primaryButton(title: isSubmitting ? "Sending…" : "Send to terminal") {
                Task { await startPayment() }
            }
            .disabled(isSubmitting || !canSend)
            .opacity(canSend ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private var amountSubtitle: some View {
        switch amountMode {
        case .custom:
            if quotedCents > 0 {
                Text("Custom amount · quoted \(BookingDisplay.formattedCents(quotedCents))")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
            } else {
                Text("Custom amount")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
            }
        case .discount(let percent) where percent > 0:
            HStack(spacing: 6) {
                Text(BookingDisplay.formattedCents(quotedCents))
                    .strikethrough()
                Text("·")
                Text("\(percent)% off")
            }
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(AdminTheme.stone500)
        default:
            EmptyView()
        }
    }

    private var amountPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amount")
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                ForEach(TerminalDiscount.percents, id: \.self) { percent in
                    amountPill(
                        title: percent == 0 ? "Full" : "\(percent)%",
                        selected: amountMode == .discount(percent: percent)
                    ) {
                        amountMode = .discount(percent: percent)
                        customAmountFocused = false
                    }
                }
                amountPill(title: "Custom", selected: amountMode == .custom) {
                    amountMode = .custom
                    if customDollars.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        customDollars = TerminalDiscount.formatCentsAsDollarInput(quotedCents)
                    }
                    customAmountFocused = true
                }
            }

            if amountMode == .custom {
                customAmountField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountPill(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color.white : AdminTheme.stone700)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? AdminTheme.stone900 : AdminTheme.cardFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selected ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private var customAmountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Charge amount (USD)")
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)

            HStack(spacing: 4) {
                Text("$")
                    .font(AdminTheme.fontAdminSans(size: 16))
                    .foregroundStyle(AdminTheme.stone500)
                TextField("0.00", text: $customDollars)
                    .keyboardType(.decimalPad)
                    .font(AdminTheme.fontAdminSans(size: 16))
                    .foregroundStyle(AdminTheme.stone900)
                    .focused($customAmountFocused)
                    .disabled(isSubmitting)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )

            if !customDollars.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !canSend {
                Text("Enter an amount between $0.50 and $10,000.00")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
            }
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

            amountCard(cents: payment?.baseAmountCents ?? chargeCents)

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

            amountCard(cents: payment?.baseAmountCents ?? chargeCents)

            Text("Retry sends the same amount to the reader again. Cancel first if you need a different amount.")
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
                .multilineTextAlignment(.center)

            primaryButton(title: isSubmitting ? "Sending…" : "Try reader again") {
                Task { await retryPayment() }
            }
            .disabled(isSubmitting)

            Button {
                Task { await cancelThenResetToReady() }
            } label: {
                Text(isSubmitting ? "Canceling…" : "Change amount")
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
            }
            .disabled(isSubmitting)
        }
    }

    private func amountCard(cents: Int) -> some View {
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
            Text(BookingDisplay.formattedCents(cents, currency: payment?.currency))
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

    private func startRequest() throws -> TerminalStartRequest {
        switch amountMode {
        case .custom:
            guard let cents = customCents,
                  TerminalDiscount.isValidCustomAmountCents(cents) else {
                throw TerminalAmountError.invalidCustomAmount
            }
            return .custom(cents: cents, additionalAppointmentIds: extraIds)
        case .discount(let percent):
            return .discount(percent, additionalAppointmentIds: extraIds)
        }
    }

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

    private func startPayment() async {
        let request: TerminalStartRequest
        do {
            request = try startRequest()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await performOperation(automaticallyRetryFailedAttempt: true) {
            try await AdminAPIClient.shared.startTerminalPayment(
                appointmentId: chargeId,
                request: request
            )
        }
    }

    private func retryPayment() async {
        if payment?.status == .canceled {
            await startPayment()
            return
        }
        await performOperation {
            try await AdminAPIClient.shared.retryTerminalPayment(appointmentId: chargeId)
        }
    }

    private func cancelPayment() async {
        await performOperation(showResult: true) {
            try await AdminAPIClient.shared.cancelTerminalPayment(appointmentId: chargeId)
        }
    }

    /// Abandon the failed/canceled attempt so staff can pick a new amount and send again.
    private func cancelThenResetToReady() async {
        if payment?.status == .failed || payment?.status == .pending || payment?.status == .processing {
            await performOperation(showResult: false) {
                try await AdminAPIClient.shared.cancelTerminalPayment(appointmentId: chargeId)
            }
        }
        showAttemptResult = false
        errorMessage = nil
    }

    private func performOperation(
        showResult: Bool = true,
        automaticallyRetryFailedAttempt: Bool = false,
        operation: () async throws -> PaymentOperationResult
    ) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        if !showResult || automaticallyRetryFailedAttempt {
            showAttemptResult = false
        }
        defer { isSubmitting = false }

        do {
            var result = try await operation()
            apply(result.response)

            if automaticallyRetryFailedAttempt,
               result.response.error == "retry_required",
               result.response.payment?.isRetryableTerminalPayment == true {
                result = try await AdminAPIClient.shared.retryTerminalPayment(
                    appointmentId: chargeId
                )
                apply(result.response)
            }

            if let message = result.response.message, !result.succeeded {
                let staleRetry = result.response.error == "retry_required"
                if !staleRetry {
                    errorMessage = message
                }
            }
            if showResult {
                showAttemptResult = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showAttemptResult = payment?.status == .failed || payment?.status == .canceled
        }
    }

    private func apply(_ response: TerminalPaymentAPIResponse) {
        reader = response.reader ?? reader
        if let updated = response.payment {
            payment = updated
            let ids = updated.status == .succeeded ? relatedIds : [chargeId]
            onPaymentChanged(updated, ids)
        }
    }

    private func pollWhileActive() async {
        while !Task.isCancelled && isActive {
            do {
                try await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                let result = try await AdminAPIClient.shared.fetchTerminalPayment(
                    appointmentId: chargeId
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

private enum TerminalAmountError: LocalizedError {
    case invalidCustomAmount

    var errorDescription: String? {
        switch self {
        case .invalidCustomAmount:
            return "Enter an amount between $0.50 and $10,000.00"
        }
    }
}
