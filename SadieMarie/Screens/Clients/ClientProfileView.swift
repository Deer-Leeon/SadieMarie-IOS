import SwiftUI

/// CRM client dossier — directory or appointment entry (mirrors web `ClientProfileModal`).
struct ClientProfileView: View {
    let entry: ClientProfileEntry
    let backLabel: String
    var onBack: () -> Void
    var onClose: () -> Void
    var onMutated: () -> Void
    /// Soft CRM patches (e.g. clearing the no-show flag) that should not
    /// dismiss parent sheets — calendar / directory update in place.
    var onClientUpdated: ((Client) -> Void)? = nil
    /// False when this view is already pushed on a `NavigationStack` (Clients tab).
    var embedInNavigationStack: Bool = true

    @Environment(AppState.self) private var appState
    @State private var viewModel: ClientProfileViewModel
    @State private var showEditSheet = false
    @State private var selectedAppointment: Appointment?
    @State private var historyMutated = false
    @State private var showManualBooking = false
    @State private var showClearNoShowFlagConfirm = false
    @State private var showPastAppointments = false
    @State private var showSmsHistory = false
    @State private var sendSmsKind: ManualClientSmsKind?
    @State private var grantWaiveKind: GrantClientFeeWaivePayload.Kind?
    @State private var confirmConsentReview = false
    @State private var showGoogleReviewEditor = false
    @State private var draftReviewPending = false
    @State private var draftGoogleReviewStars: Int? = nil

    init(
        entry: ClientProfileEntry,
        backLabel: String,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onMutated: @escaping () -> Void,
        onClientUpdated: ((Client) -> Void)? = nil,
        embedInNavigationStack: Bool = true
    ) {
        self.entry = entry
        self.backLabel = backLabel
        self.onBack = onBack
        self.onClose = onClose
        self.onMutated = onMutated
        self.onClientUpdated = onClientUpdated
        self.embedInNavigationStack = embedInNavigationStack
        _viewModel = State(initialValue: ClientProfileViewModel(entry: entry))
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    profileChrome
                }
            } else {
                profileChrome
            }
        }
        .navigationBarBackButtonHidden(true)
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .overlay {
            ZStack {
                if showPastAppointments {
                    PastAppointmentsPopup(
                        appointments: pastHistory,
                        onSelectAppointment: { selectedAppointment = $0 },
                        onClose: { showPastAppointments = false }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
                if showSmsHistory, let client = viewModel.client {
                    ClientSmsHistoryPopup(
                        clientId: client.id,
                        clientName: viewModel.displayName,
                        clientPhone: client.formattedPhone,
                        onClose: { showSmsHistory = false }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
                if let sendSmsKind, let client = viewModel.client {
                    ClientSendSmsConfirmPopup(
                        kind: sendSmsKind,
                        clientId: client.id,
                        clientName: viewModel.displayName,
                        clientPhone: client.formattedPhone,
                        onClose: { self.sendSmsKind = nil },
                        onSent: { kind in
                            if kind == .reviewRequest {
                                draftReviewPending = false
                                viewModel.noteManualReviewSmsSent(onUpdated: onClientUpdated)
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPastAppointments)
        .animation(.easeInOut(duration: 0.2), value: showSmsHistory)
        .animation(.easeInOut(duration: 0.2), value: sendSmsKind != nil)
    }

    private var profileChrome: some View {
        ZStack {
                AdminTheme.cream.ignoresSafeArea()

                if viewModel.isBootstrapping {
                    loadingState("Loading client…")
                } else if viewModel.awaitingBootstrapEmail {
                    bootstrapEmailForm
                } else if let bootstrapError = viewModel.bootstrapError {
                    errorState(bootstrapError)
                } else if viewModel.client != nil {
                    overviewScroll
                } else {
                    errorState("Client profile unavailable.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if historyMutated {
                            onMutated()
                        }
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text(backLabel)
                                .font(AdminTheme.fontAdminSans(size: 15))
                        }
                        .foregroundStyle(AdminTheme.stone700)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                }
            }
            .toolbarBackground(AdminTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $showEditSheet) {
                if let client = viewModel.client {
                    EditClientSheet(
                        client: client,
                        isSaving: viewModel.isSavingIdentity,
                        errorMessage: viewModel.identityError,
                        onCancel: { showEditSheet = false },
                        onSave: { first, last, validatedEmail in
                            Task {
                                let ok = await viewModel.saveIdentity(
                                    firstName: first,
                                    lastName: last,
                                    email: validatedEmail
                                )
                                if ok {
                                    showEditSheet = false
                                    onMutated()
                                    await viewModel.reloadDossier()
                                }
                            }
                        }
                    )
                }
            }
            .sheet(item: $selectedAppointment) { appointment in
                AppointmentDetailSheet(
                    appointment: appointment,
                    knownAppointments: viewModel.history,
                    onDismiss: { selectedAppointment = nil },
                    onMutated: {
                        historyMutated = true
                        selectedAppointment = nil
                        Task { await viewModel.reloadDossier() }
                    },
                    onPaymentMutated: { payment, ids, payments in
                        historyMutated = true
                        viewModel.applyPayment(
                            appointmentIds: ids.isEmpty ? [appointment.id] : ids,
                            payment: payment,
                            payments: payments
                        )
                    },
                    onVisitUpdated: { visit in
                        historyMutated = true
                        viewModel.replaceAppointment(visit)
                    }
                )
            }
            .sheet(isPresented: $showGoogleReviewEditor) {
                googleReviewEditorSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AdminTheme.cream)
                    .onAppear {
                        syncGoogleReviewDrafts()
                    }
                    .onChange(of: viewModel.reviewFlagsError) { _, error in
                        if error != nil {
                            syncGoogleReviewDrafts()
                        }
                    }
            }
    }

    // MARK: - Overview

    private var overviewScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.displayName)
                    .font(AdminTheme.fontAdminSerif(size: 28))
                    .foregroundStyle(AdminTheme.stone900)

                identityCard
                bookAppointmentButton
                crmBar
                feeWaivePassesBar
                googleReviewBar
                if viewModel.showsNoShowFlag {
                    noShowFlagBanner
                }
                consentCard
                galleryCard
                notesCard
                historySection
                smsHistoryButton
            }
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
        .fullScreenCover(isPresented: $showManualBooking) {
            if let client = viewModel.client {
                ManualBookingWizardView(
                    bookingDate: Date(),
                    prefilledClient: client,
                    onClose: { showManualBooking = false },
                    onSuccess: {
                        historyMutated = true
                        Task { await viewModel.reloadDossier() }
                    }
                )
            }
        }
    }

    private var bookAppointmentButton: some View {
        Button {
            showManualBooking = true
        } label: {
            Text("BOOK APPOINTMENT")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(AdminTheme.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AdminTheme.stone900)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.client == nil)
    }

    private var identityCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Contact")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                    Spacer()
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                }

                if let client = viewModel.client {
                    if let phone = client.phone, !phone.isEmpty {
                        CopyablePhoneButton(
                            phone: phone,
                            font: AdminTheme.fontAdminSans(size: 14),
                            iconPointSize: 12,
                            spacing: 8
                        )
                    }
                    if let email = client.email, !email.isEmpty {
                        identityLine(icon: "envelope", text: email)
                    }
                    if (client.phone ?? "").isEmpty && (client.email ?? "").isEmpty {
                        Text("No contact details on file")
                            .font(AdminTheme.fontAdminSans(size: 14))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                }
            }
        }
    }

    private func identityLine(icon: String, text: String) -> some View {
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

    private var crmBar: some View {
        AdminDetailCard {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    crmColumn(
                        title: "Lifetime spend",
                        value: BookingDisplay.formatLifetimeSpend(viewModel.crmStats.lifetimeValue)
                    )
                    Divider()
                        .frame(height: 44)
                        .overlay(AdminTheme.stone200)
                    crmColumn(
                        title: "Bookings",
                        value: "\(viewModel.crmStats.totalBookings)"
                    )
                    Divider()
                        .frame(height: 44)
                        .overlay(AdminTheme.stone200)
                    crmColumn(
                        title: "Card vault",
                        value: viewModel.crmStats.hasVaultedCard ? "On file" : "None",
                        valueColor: viewModel.crmStats.hasVaultedCard
                            ? AdminTheme.confirmedText
                            : AdminTheme.stone500
                    )
                }
                Divider()
                    .overlay(AdminTheme.stone200)
                HStack(alignment: .top, spacing: 0) {
                    crmBreakdownColumn(
                        title: "No-shows",
                        total: viewModel.crmStats.noShowCount,
                        emphasize: viewModel.crmStats.noShowCount > 0,
                        rows: [
                            ("Admin-marked", viewModel.crmStats.noShowAdminCount),
                            ("Under-2h cancels", viewModel.crmStats.noShowAutoCancelCount),
                            ("Under-2h reschedules", viewModel.crmStats.noShowAutoRescheduleCount),
                        ]
                    )
                    Divider()
                        .frame(minHeight: 72)
                        .overlay(AdminTheme.stone200)
                    crmBreakdownColumn(
                        title: "Late-Change",
                        total: viewModel.crmStats.lateChangeCount,
                        emphasize: viewModel.crmStats.lateChangeCount > 0,
                        rows: [
                            ("Late cancel", viewModel.crmStats.lateChangeCancelCount),
                            ("Late reschedule", viewModel.crmStats.lateChangeRescheduleCount),
                        ]
                    )
                }
            }
        }
    }

    private func crmColumn(
        title: String,
        value: String,
        valueColor: Color = AdminTheme.stone900
    ) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(AdminTheme.stone500)
                .multilineTextAlignment(.center)

            Text(value)
                .font(AdminTheme.fontAdminSerif(size: 17))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    /// Totals plus always-visible sub-counts (web `CrmStatBreakdownTile` parity).
    private func crmBreakdownColumn(
        title: String,
        total: Int,
        emphasize: Bool,
        rows: [(String, Int)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity)

                Text("\(total)")
                    .font(AdminTheme.fontAdminSerif(size: 17))
                    .foregroundStyle(emphasize ? AdminTheme.rose600 : AdminTheme.stone900)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(row.0)
                            .font(AdminTheme.fontAdminSans(size: 11))
                            .foregroundStyle(AdminTheme.stone500)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.1)")
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                            .foregroundStyle(AdminTheme.stone700)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(total). \(rows.map { "\($0.0) \($0.1)" }.joined(separator: ". "))")
    }

    private var feeWaivePassesBar: some View {
        VStack(spacing: 10) {
            feeWaivePassCard(
                title: "No-show fee",
                freeNext: viewModel.crmStats.noShowWaiveNext,
                kind: .noShow
            )
            feeWaivePassCard(
                title: "Late-Change fee",
                freeNext: viewModel.crmStats.lateChangeWaiveNext,
                kind: .lateChange
            )
            if let error = viewModel.feeWaiveError {
                Text(error)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.rose600)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .confirmationDialog(
            grantConfirmTitle,
            isPresented: Binding(
                get: { grantWaiveKind != nil },
                set: { if !$0 { grantWaiveKind = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Yes, grant free pass") {
                guard let kind = grantWaiveKind else { return }
                Task {
                    let ok = await viewModel.grantFeeWaive(kind: kind)
                    if ok, let client = viewModel.client {
                        onClientUpdated?(client)
                    }
                    grantWaiveKind = nil
                }
            }
            Button("Cancel", role: .cancel) {
                grantWaiveKind = nil
            }
        } message: {
            Text(grantConfirmMessage)
        }
    }

    private var googleReviewBar: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showGoogleReviewEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("GOOGLE REVIEWS")
                                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                                .tracking(1.6)
                                .foregroundStyle(AdminTheme.stone500)
                            GoogleReviewStarsView(
                                rating: viewModel.client?.googleReviewStars,
                                size: 13
                            )
                            Spacer(minLength: 8)
                            Text("Edit")
                                .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                                .foregroundStyle(AdminTheme.stone900)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AdminTheme.stone500)
                        }

                        googleReviewStatusRow(
                            title: "Ask after next visit",
                            isOn: viewModel.client?.reviewRequestPending ?? false
                        )

                        if let error = viewModel.reviewFlagsError {
                            Text(error)
                                .font(AdminTheme.fontAdminSans(size: 12))
                                .foregroundStyle(AdminTheme.rose600)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Google review settings")

                if recordedGoogleReviewStars == nil {
                    sendSmsRow(title: "Send review text") {
                        sendSmsKind = .reviewRequest
                    }
                }
            }
        }
    }

    private func googleReviewStatusRow(title: String, isOn: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            googleReviewStatusPill(isOn: isOn)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isOn ? "on" : "off")")
    }

    private func googleReviewStatusPill(isOn: Bool) -> some View {
        Text(isOn ? "ON" : "OFF")
            .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(isOn ? AdminTheme.confirmedText : AdminTheme.stone600)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isOn ? AdminTheme.confirmedBackground : AdminTheme.stone100)
            .overlay(
                Capsule()
                    .stroke(isOn ? AdminTheme.confirmedBorder : AdminTheme.stone300, lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    private var googleReviewEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Changes save as soon as you tap.")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone600)

                Toggle(isOn: reviewRequestPendingBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask for a Google review after their next visit")
                            .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                            .foregroundStyle(AdminTheme.stone900)
                        Text("Turns off automatically after the text is sent.")
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(AdminTheme.stone700)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(AdminSwitchToggleStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Google rating")
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Text("Tap how many stars they left. Tap the same star again to clear.")
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone700)
                        .fixedSize(horizontal: false, vertical: true)
                    GoogleReviewStarsView(
                        rating: draftGoogleReviewStars,
                        size: 28,
                        interactive: true,
                        onSelect: applyGoogleReviewStars
                    )
                    .padding(.top, 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = viewModel.reviewFlagsError {
                    Text(error)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.rose600)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AdminTheme.cream)
            .navigationTitle("Google reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showGoogleReviewEditor = false
                    }
                    .font(AdminTheme.fontAdminSans(size: 16, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var reviewRequestPendingBinding: Binding<Bool> {
        Binding(
            get: { draftReviewPending },
            set: { newValue in
                draftReviewPending = newValue
                viewModel.applyReviewFlagChange(
                    reviewRequestPending: newValue,
                    onUpdated: onClientUpdated
                )
            }
        )
    }

    private func applyGoogleReviewStars(_ next: Int?) {
        draftGoogleReviewStars = next
        if next != nil {
            draftReviewPending = false
        }
        viewModel.applyReviewFlagChange(
            googleReviewStars: next,
            clearStars: next == nil,
            onUpdated: onClientUpdated
        )
    }

    private func syncGoogleReviewDrafts() {
        draftReviewPending = viewModel.client?.reviewRequestPending ?? false
        draftGoogleReviewStars = viewModel.client?.googleReviewStars
    }

    private var grantConfirmTitle: String {
        switch grantWaiveKind {
        case .lateChange:
            return "Grant a one-time Late-Change free pass?"
        case .noShow, .none:
            return "Grant a one-time no-show free pass?"
        }
    }

    private var grantConfirmMessage: String {
        switch grantWaiveKind {
        case .lateChange:
            return "Their next late cancel or reschedule will not be charged. An SMS will tell them. After that event, they will be charged again unless you grant another pass."
        case .noShow, .none:
            return "Their next no-show will not be charged. An SMS will tell them. After that event, they will be charged again unless you grant another pass."
        }
    }

    private func feeWaivePassCard(
        title: String,
        freeNext: Bool,
        kind: GrantClientFeeWaivePayload.Kind
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(AdminTheme.stone500)

            Text(freeNext ? "Next free" : "Will be charged next")
                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)

            Text(
                freeNext
                    ? "One-time free pass is active. The next event skips the fee, then they are charged."
                    : "No free pass. The next event will charge the fee unless you grant another pass."
            )
            .font(AdminTheme.fontAdminSans(size: 12))
            .foregroundStyle(AdminTheme.stone700)
            .fixedSize(horizontal: false, vertical: true)

            if !freeNext {
                Button {
                    grantWaiveKind = kind
                } label: {
                    Text(viewModel.isGrantingFeeWaive ? "Granting…" : "Grant free pass")
                        .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(AdminTheme.stone900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AdminTheme.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AdminTheme.pendingBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGrantingFeeWaive)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            freeNext
                ? AdminTheme.confirmedBackground.opacity(0.55)
                : AdminTheme.awaitingPaymentBackground.opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    freeNext ? AdminTheme.confirmedBorder : AdminTheme.pendingBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var noShowFlagBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AdminTheme.awaitingPaymentText)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("No-show flag active")
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                Text("Set when a no-show was marked without charging. Clear it when you’ve reviewed — the lifetime no-show count stays.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone700)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = viewModel.noShowFlagError {
                    Text(error)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.rose600)
                }
            }

            Spacer(minLength: 0)

            Button {
                showClearNoShowFlagConfirm = true
            } label: {
                Text(viewModel.isClearingNoShowFlag ? "Clearing…" : "Clear flag")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AdminTheme.stone900)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AdminTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AdminTheme.pendingBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isClearingNoShowFlag)
        }
        .padding(12)
        .background(AdminTheme.awaitingPaymentBackground.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AdminTheme.pendingBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .confirmationDialog(
            "Clear this flag?",
            isPresented: $showClearNoShowFlagConfirm,
            titleVisibility: .visible
        ) {
            Button("Yes, clear flag", role: .destructive) {
                Task {
                    let ok = await viewModel.clearNoShowFlag()
                    if ok, let client = viewModel.client {
                        appState.noteClientNoShowFlag(
                            phone: client.phone,
                            email: client.email,
                            flag: false
                        )
                        onClientUpdated?(client)
                    }
                }
            }
            Button("Keep flag", role: .cancel) {}
        } message: {
            Text("They’ll no longer show as flagged on the calendar or profile. Their no-show count will not change. A future uncharged no-show will flag them again.")
        }
    }

    private var consentCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consent form")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                            .foregroundStyle(AdminTheme.stone700)
                        Text(consentStatusLabel)
                            .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                            .foregroundStyle(consentStatusColor)
                    }
                    Spacer()
                    if let url = stampedConsentURL {
                        Link(destination: url) {
                            Text(viewModel.client?.stampedConsentPdfURL != nil ? "View signed PDF" : "View")
                                .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                                .foregroundStyle(AdminTheme.stone900)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AdminTheme.stone100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if viewModel.client?.hasConsented == true,
                   viewModel.client?.stampedConsentPdfURL != nil {
                    Divider().overlay(AdminTheme.stone200)
                    technicianReviewSection
                }

                if let documentURL = viewModel.client?.consentDocumentURL {
                    Divider().overlay(AdminTheme.stone200)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Permanent client link")
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                            .foregroundStyle(AdminTheme.stone500)
                            .textCase(.uppercase)
                            .tracking(1.4)
                        Text("Clients can reopen their signed form anytime at this URL.")
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(AdminTheme.stone600)
                        Link(destination: documentURL) {
                            Text(documentURL.absoluteString)
                                .font(AdminTheme.fontAdminSans(size: 12))
                                .foregroundStyle(AdminTheme.stone900)
                                .underline()
                                .lineLimit(2)
                        }
                    }
                }

                if viewModel.client?.hasConsented != true {
                    sendSmsRow(title: "Send consent text") {
                        sendSmsKind = .consentRequest
                    }
                }
            }
        }
    }

    private var recordedGoogleReviewStars: Int? {
        let stars = draftGoogleReviewStars ?? viewModel.client?.googleReviewStars
        guard let stars, stars >= 1 else { return nil }
        return stars
    }

    private func sendSmsRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AdminTheme.stone100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var technicianReviewSection: some View {
        if let reviewedAt = viewModel.client?.technicianReviewedDate {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdminTheme.confirmedText)
                    Text("Reviewed by technician · \(Self.reviewedDateFormatter.string(from: reviewedAt))")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                }

                Button {
                    Task { await stampConsentReview() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isMarkingConsentReviewed {
                            ProgressView().controlSize(.mini)
                        }
                        Text(viewModel.isMarkingConsentReviewed ? "Updating PDF…" : "Re-apply check on PDF")
                    }
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isMarkingConsentReviewed)

                if let error = viewModel.consentReviewError {
                    Text(error)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }
            }
        } else if confirmConsentReview {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mark this consent PDF as reviewed by the technician? This checks the box on the PDF and saves a new copy to the client profile.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)

                if let error = viewModel.consentReviewError {
                    Text(error)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        confirmConsentReview = false
                        viewModel.clearConsentReviewError()
                    }
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
                    .disabled(viewModel.isMarkingConsentReviewed)

                    Button {
                        Task { await stampConsentReview() }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isMarkingConsentReviewed {
                                ProgressView().controlSize(.mini)
                            }
                            Text(viewModel.isMarkingConsentReviewed ? "Saving…" : "Confirm review")
                        }
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AdminTheme.stone900)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isMarkingConsentReviewed)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    confirmConsentReview = true
                    viewModel.clearConsentReviewError()
                } label: {
                    Text("Mark reviewed by technician")
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AdminTheme.stone100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AdminTheme.stone200, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                if let error = viewModel.consentReviewError {
                    Text(error)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }
            }
        }
    }

    private var stampedConsentURL: URL? {
        guard let client = viewModel.client else { return nil }
        if let pdf = client.stampedConsentPdfURL {
            var components = URLComponents(url: pdf, resolvingAgainstBaseURL: false)
            var items = components?.queryItems ?? []
            let cache = client.consentTechnicianReviewedAt.flatMap { Client.parseISO8601($0)?.timeIntervalSince1970 }
            items.append(URLQueryItem(name: "v", value: cache.map { String(Int($0 * 1000)) } ?? "signed"))
            components?.queryItems = items
            return components?.url ?? pdf
        }
        return client.consentDocumentURL
    }

    private var consentStatusLabel: String {
        if viewModel.client?.hasConsented == true {
            return "Signed"
        }
        return "Not on file"
    }

    private var consentStatusColor: Color {
        viewModel.client?.hasConsented == true
            ? AdminTheme.confirmedText
            : AdminTheme.stone500
    }

    private static let reviewedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Denver")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    @MainActor
    private func stampConsentReview() async {
        let ok = await viewModel.markConsentTechnicianReviewed()
        if ok {
            confirmConsentReview = false
            if let client = viewModel.client {
                onClientUpdated?(client)
            }
        }
    }

    private var galleryCard: some View {
        NavigationLink {
            ClientGalleryView(
                photos: viewModel.photos,
                isLoading: viewModel.isLoadingPhotos,
                isUploading: viewModel.isUploadingPhoto,
                errorMessage: viewModel.photosError,
                onUpload: { data, filename, mime in
                    await viewModel.uploadPhoto(data: data, filename: filename, mimeType: mime)
                },
                onDelete: { photo in
                    await viewModel.deletePhoto(photo)
                }
            )
            .task {
                await viewModel.loadPhotosIfNeeded()
            }
        } label: {
            AdminDetailCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photo gallery")
                            .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                            .foregroundStyle(AdminTheme.stone900)
                        Text("Lash, brow, and colour reference shots")
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var notesCard: some View {
        AdminDetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Private notes")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                    Spacer()
                    Button {
                        Task {
                            if await viewModel.saveNotes() {
                                onMutated()
                            }
                        }
                    } label: {
                        if viewModel.isSavingNotes {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                                .foregroundStyle(
                                    viewModel.notesDirty ? AdminTheme.stone900 : AdminTheme.stone500
                                )
                        }
                    }
                    .disabled(!viewModel.notesDirty || viewModel.isSavingNotes)
                }

                if let notesError = viewModel.notesError {
                    Text(notesError)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }

                TextEditor(text: Binding(
                    get: { viewModel.notes },
                    set: { viewModel.updateNotesDraft($0) }
                ))
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone900)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(AdminTheme.stone100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Booking history")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            if viewModel.isLoadingDossier {
                ProgressView()
                    .controlSize(.regular)
                    .tint(AdminTheme.stone900)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let dossierError = viewModel.dossierError {
                Text(dossierError)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
            } else if viewModel.history.isEmpty {
                Text("No appointments on file yet.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
                    .padding(.vertical, 8)
            } else {
                if upcomingHistory.isEmpty {
                    Text("No upcoming bookings")
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    BookingsDayGroupedList(
                        appointments: upcomingHistory,
                        onSelectAppointment: { selectedAppointment = $0 }
                    )
                }

                if !pastHistory.isEmpty {
                    ShowPastAppointmentsButton(chevronUp: false) {
                        showPastAppointments = true
                    }
                }
            }
        }
    }

    private var smsHistoryButton: some View {
        Button {
            showSmsHistory = true
        } label: {
            AdminDetailCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text history")
                            .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                            .foregroundStyle(AdminTheme.stone900)
                        Text("Every text sent to this client, and the number it went to")
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(AdminTheme.stone700)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open text history")
        .disabled(viewModel.client == nil)
    }

    private var upcomingHistory: [Appointment] {
        viewModel.history.filter { BookingDisplay.isUpcoming($0) }
    }

    private var pastHistory: [Appointment] {
        viewModel.history.filter { !BookingDisplay.isUpcoming($0) }
    }

    // MARK: - Bootstrap email

    private var bootstrapEmailForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Client email required")
                    .font(AdminTheme.fontAdminSerif(size: 24))
                    .foregroundStyle(AdminTheme.stone900)

                Text("This booking does not have a valid email on file. Add one to open the client profile.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)

                    TextField(
                        "Email",
                        text: $viewModel.bootstrapEmailDraft,
                        prompt: Text(verbatim: "jane@example.com")
                            .foregroundStyle(Color(uiColor: .placeholderText))
                    )
                        .font(AdminTheme.fontAdminSans(size: 15))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AdminTheme.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    viewModel.bootstrapEmailInvalid
                                        ? Color.semanticRed.opacity(0.5)
                                        : AdminTheme.stone200,
                                    lineWidth: 1
                                )
                        )
                        .onChange(of: viewModel.bootstrapEmailDraft) { _, _ in
                            viewModel.bootstrapEmailTouched = true
                        }
                }

                if viewModel.bootstrapEmailInvalid {
                    Text(ClientEmail.validationMessage)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(Color.semanticRed)
                }

                if let bootstrapError = viewModel.bootstrapError {
                    Text(bootstrapError)
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(Color.semanticRed)
                }

                Button {
                    Task {
                        _ = await viewModel.submitBootstrapEmail()
                    }
                } label: {
                    Text("Continue")
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.canSubmitBootstrapEmail
                                ? AdminTheme.stone900
                                : AdminTheme.stone500
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!viewModel.canSubmitBootstrapEmail || viewModel.isBootstrapping)
            }
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.vertical, 24)
        }
    }

    // MARK: - States

    private func loadingState(_ label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)
            Text(label)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(Color.semanticRed)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Back", action: onBack)
                .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
        }
    }
}

private struct GoogleReviewStarsView: View {
    let rating: Int?
    var size: CGFloat = 14
    var interactive = false
    var onSelect: ((Int?) -> Void)? = nil

    private var count: Int { rating ?? 0 }
    private let starYellow = Color(red: 244 / 255, green: 180 / 255, blue: 0 / 255)

    var body: some View {
        HStack(spacing: size < 18 ? 2 : 6) {
            ForEach(1...5, id: \.self) { n in
                let filled = n <= count
                let star = Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(filled ? starYellow : AdminTheme.stone300)

                if interactive {
                    Button {
                        onSelect?(count == n ? nil : n)
                    } label: {
                        star
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
                    .accessibilityAddTraits(count == n ? .isSelected : [])
                } else {
                    star
                }
            }
        }
        .accessibilityElement(children: interactive ? .contain : .ignore)
        .accessibilityLabel(
            count > 0 ? "\(count) of 5 Google stars" : "No Google rating recorded"
        )
    }
}

/// High-contrast switch so off-state tracks stay visible on cream/white cards.
private struct AdminSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                configuration.isOn.toggle()
            } label: {
                Capsule()
                    .fill(configuration.isOn ? AdminTheme.stone900 : AdminTheme.stone300)
                    .frame(width: 51, height: 31)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                            .padding(.horizontal, 2)
                    }
                    .overlay(
                        Capsule()
                            .stroke(
                                configuration.isOn ? AdminTheme.stone900 : AdminTheme.stone500,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
    }
}

#Preview("From directory") {
    ClientProfileView(
        entry: .directory(.previewVaulted),
        backLabel: "Clients",
        onBack: {},
        onClose: {},
        onMutated: {}
    )
    .environment(AppState())
}
