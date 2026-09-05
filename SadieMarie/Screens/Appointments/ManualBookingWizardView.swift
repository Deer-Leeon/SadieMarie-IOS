import SwiftUI

/// Full-screen manual booking flow — dedicated screen, not a floating sheet.
struct ManualBookingWizardView: View {
    let bookingDate: Date
    var prefilledClient: Client?
    var seedHour: Int?
    var modeSwitch: AnyView?
    var onClose: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: ManualBookingViewModel
    @State private var expandedGroupIDs: Set<Int> = []
    @FocusState private var focusedClientField: ManualBookingClientField?
    @FocusState private var notesFieldFocused: Bool

    init(
        bookingDate: Date,
        prefilledClient: Client? = nil,
        seedHour: Int? = nil,
        modeSwitch: AnyView? = nil,
        onClose: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.bookingDate = bookingDate
        self.prefilledClient = prefilledClient
        self.seedHour = seedHour
        self.modeSwitch = modeSwitch
        self.onClose = onClose
        self.onSuccess = onSuccess
        _viewModel = State(
            initialValue: ManualBookingViewModel(
                initialDate: bookingDate,
                seedHour: seedHour,
                prefilledClient: prefilledClient
            )
        )
    }

    private enum Layout {
        static let contentPadding: CGFloat = 20
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.didCompleteBooking {
                    successContent
                } else {
                    VStack(spacing: 0) {
                        header
                        bodyContent
                        footer
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if showsKeyboardAccessory {
                            keyboardAccessoryBar
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AdminTheme.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: viewModel.selectedSlot) { _, _ in
                dismissKeyboard()
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                dismissKeyboard()
            }
            .onChange(of: viewModel.selectedDirectoryClient?.id) { _, _ in
                dismissKeyboard()
            }
        }
        .preferredColorScheme(.light)
        .task {
            await viewModel.loadServicesIfNeeded()
        }
    }

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.green)
            }

            VStack(spacing: 8) {
                Text(successTitle)
                    .font(AdminTheme.fontAdminSerif(size: 28))
                    .foregroundStyle(AdminTheme.stone900)
                Text(successSubtitle)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone700)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    viewModel.resetForNextBooking()
                    expandedGroupIDs = []
                } label: {
                    Text("Book another")
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AdminTheme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AdminTheme.stone900)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Done", action: onClose)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AdminTheme.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AdminTheme.stone200, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, Layout.contentPadding)
        .padding(.vertical, 24)
    }

    private var isScheduleStep: Bool {
        viewModel.step == .schedule
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Manual booking")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)

                Text(viewModel.headerTitle)
                    .font(AdminTheme.fontAdminSerif(size: isScheduleStep ? 22 : 24))
                    .foregroundStyle(AdminTheme.stone900)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text(viewModel.headerSubtitle)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone600)
                    .lineLimit(2)

                if let modeSwitch, viewModel.showsModeSwitch {
                    modeSwitch
                        .padding(.top, 6)
                }
            }

            Spacer(minLength: 8)

            Button {
                if !viewModel.isCompleting {
                    dismissKeyboard()
                    onClose()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)
        }
        .padding(.horizontal, Layout.contentPadding)
        .padding(.top, isScheduleStep ? 4 : 8)
        .padding(.bottom, isScheduleStep ? 6 : 12)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if viewModel.isCompleting {
            completingOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Layout.contentPadding)
        } else if isScheduleStep {
            VStack(alignment: .leading, spacing: 10) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ManualBookingSlotPickerView(
                        viewModel: viewModel,
                        layout: .compact
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    bookingNotesField
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    switch viewModel.step {
                    case .service:
                        serviceStep
                    case .client:
                        ManualBookingClientFormView(
                            viewModel: viewModel,
                            focusedField: $focusedClientField
                        )
                    case .schedule:
                        EmptyView()
                    case .summary:
                        summaryStep
                    }
                }
                .padding(.horizontal, Layout.contentPadding)
                .padding(.top, 4)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(viewModel.step == .client ? .never : .interactively)
        }
    }

    private var bookingNotesField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Booking notes")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone500)
                Text("Optional")
                    .font(AdminTheme.fontAdminSans(size: 10))
                    .foregroundStyle(AdminTheme.stone300)
            }
            TextField(
                "Anything to remember for this visit",
                text: $viewModel.bookingNotes,
                axis: .vertical
            )
            .lineLimit(2...3)
            .font(AdminTheme.fontAdminSans(size: 14))
            .focused($notesFieldFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .layoutPriority(1)
        }
    }

    private var showsKeyboardAccessory: Bool {
        notesFieldFocused || focusedClientField != nil
    }

    private var keyboardAccessoryBar: some View {
        HStack(spacing: 12) {
            if focusedClientField == .phone {
                Button("Next") {
                    viewModel.phoneTouched = true
                    viewModel.formatPhoneField()
                    focusedClientField = .email
                }
                .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
            }
            Spacer()
            Button("Done") {
                dismissKeyboard()
            }
            .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
            .foregroundStyle(AdminTheme.stone900)
        }
        .padding(.horizontal, Layout.contentPadding)
        .padding(.vertical, 8)
        .background(AdminTheme.cream)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
    }

    private func dismissKeyboard() {
        focusedClientField = nil
        notesFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)

            HStack(spacing: 12) {
                if showsFooterBack {
                    Button {
                        dismissKeyboard()
                        viewModel.goBackOrCancel(onCancel: onClose)
                    } label: {
                        Text(footerBackTitle)
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(AdminTheme.stone700)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AdminTheme.cardFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AdminTheme.stone200, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isCompleting)
                }

                if viewModel.step == .summary {
                    Button {
                        dismissKeyboard()
                        Task { await viewModel.book(onSuccess: onSuccess) }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isCompleting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AdminTheme.cream)
                            }
                            Text(viewModel.bookButtonTitle)
                                .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                                .tracking(1.2)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(viewModel.canBook ? AdminTheme.cream : AdminTheme.stone500)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.canBook ? AdminTheme.stone900 : AdminTheme.stone200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canBook)
                } else {
                    Button {
                        dismissKeyboard()
                        viewModel.advanceStep()
                    } label: {
                        Text("Continue")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(canContinue ? AdminTheme.cream : AdminTheme.stone500)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canContinue ? AdminTheme.stone900 : AdminTheme.stone200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue || viewModel.isCompleting)
                }
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(AdminTheme.cream)
    }

    private var canContinue: Bool {
        switch viewModel.step {
        case .service:
            return viewModel.canAdvanceFromService
        case .client:
            return viewModel.canAdvanceFromClient
        case .schedule:
            return viewModel.canContinueFromSchedule
        case .summary:
            return false
        }
    }

    private var showsFooterBack: Bool {
        !(viewModel.step == .summary && viewModel.pendingVisits.count > 1)
    }

    private var footerBackTitle: String {
        if viewModel.step == .service, viewModel.pendingVisits.isEmpty {
            return "Cancel"
        }
        return "Back"
    }

    private var successTitle: String {
        viewModel.lastBookedCount > 1
            ? "\(viewModel.lastBookedCount) appointments booked"
            : "Appointment booked"
    }

    private var successSubtitle: String {
        viewModel.lastBookedCount > 1
            ? "The appointments are in Cal.com and the studio calendar."
            : "The appointment is in Cal.com and the studio calendar."
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.clientDisplayName.isEmpty {
                Text("Visits for \(viewModel.clientDisplayName)")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone600)
            }

            VStack(spacing: 10) {
                ForEach(viewModel.pendingVisits) { visit in
                    summaryVisitRow(visit)
                }
            }

            Button {
                viewModel.beginAddVisit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
                .foregroundStyle(AdminTheme.stone700)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)
        }
    }

    private func summaryVisitRow(_ visit: PendingManualVisit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                viewModel.beginEditVisit(visit)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.service.title)
                        .font(AdminTheme.fontAdminSerif(size: 17))
                        .foregroundStyle(AdminTheme.stone900)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(visit.dateLabel) · \(visit.timeRangeLabel)")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let notes = visit.notes, !notes.isEmpty {
                        Text(notes)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(AdminTheme.stone500)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.removeVisit(visit.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(width: 36, height: 36)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove visit")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var serviceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.isLoadingServices {
                ManualBookingLoadingPanel(
                    title: "Loading services",
                    subtitle: "Fetching your bookable menu"
                )
                .frame(maxWidth: .infinity)
            } else if !viewModel.hasBookableServices {
                Text("No bookable services found. Add services in the Services tab first.")
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .foregroundStyle(AdminTheme.stone500)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.serviceSections) { section in
                        serviceSection(section)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func serviceSection(_ section: ManualBookingServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !section.category.isEmpty {
                Text(section.category)
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                    .padding(.top, 4)
            }

            VStack(spacing: 10) {
                ForEach(section.rows) { row in
                    switch row {
                    case .group(let group):
                        bookingGroupRow(group)
                    case .service(let service):
                        serviceRow(service, indented: false)
                    }
                }
            }

            ForEach(section.comingSoonFooters, id: \.self) { category in
                comingSoonFooter(category)
            }
        }
    }

    private func bookingGroupRow(_ group: ManualBookingGroupRow) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        let hasChildren = !group.children.isEmpty

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                guard hasChildren else { return }
                if isExpanded {
                    expandedGroupIDs.remove(group.id)
                } else {
                    expandedGroupIDs.insert(group.id)
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title)
                            .font(AdminTheme.fontAdminSerif(size: 17))
                            .foregroundStyle(AdminTheme.stone900)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(ServiceFormat.price(group.price, prefixFrom: true))
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                            .foregroundStyle(AdminTheme.stone600)
                    }

                    Spacer(minLength: 8)

                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AdminTheme.stone500)
                            .frame(width: 28, height: 28)
                            .background(AdminTheme.stone100)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)

            if isExpanded, hasChildren {
                VStack(spacing: 8) {
                    ForEach(group.children) { child in
                        serviceRow(child, indented: true)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 8)
            }
        }
    }

    private func serviceRow(_ service: ManualBookingServiceOption, indented: Bool) -> some View {
        let active = viewModel.selectedService?.slug == service.slug
        return Button {
            viewModel.selectService(service)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AdminTheme.cream)
                        .padding(.top, 2)
                } else {
                    selectionIndicator(active: false)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.title)
                        .font(AdminTheme.fontAdminSerif(size: indented ? 16 : 17))
                        .foregroundStyle(active ? AdminTheme.cream : AdminTheme.stone900)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !service.detailMetaLine.isEmpty {
                        Text(service.detailMetaLine)
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                            .tracking(0.5)
                            .foregroundStyle(active ? AdminTheme.stone300 : AdminTheme.stone500)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? AdminTheme.stone900 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: 1)
            )
            .shadow(color: active ? AdminTheme.stone900.opacity(0.18) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .animation(.easeInOut(duration: 0.18), value: active)
    }

    private func selectionIndicator(active: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(active ? AdminTheme.stone900 : AdminTheme.stone300, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if active {
                Circle()
                    .fill(AdminTheme.stone900)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }

    private func comingSoonFooter(_ category: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category)
                .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)

            Text("Coming soon.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
                .italic()
        }
        .padding(.top, 4)
    }

    private var completingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            if let progress = viewModel.bookingProgress, progress.total > 1 {
                Text("Booking \(progress.current) of \(progress.total)…")
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)
            } else {
                Text("Saving appointment…")
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)
            }
            Text("Updating Cal.com and your calendar")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Identifiable wrapper for presenting `ManualBookingWizardView`.
struct ManualBookingFocus: Identifiable {
    let date: Date

    var id: TimeInterval {
        date.timeIntervalSince1970
    }

    init(date: Date) {
        self.date = StudioTime.startOfStudioDay(for: date)
    }
}
