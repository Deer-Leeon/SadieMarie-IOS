import SwiftUI

/// Full-screen manual booking flow — dedicated screen, not a floating sheet.
struct ManualBookingWizardView: View {
    let bookingDate: Date
    var prefilledClient: Client?
    var onClose: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: ManualBookingViewModel
    @State private var expandedGroupIDs: Set<Int> = []
    @FocusState private var focusedClientField: ManualBookingClientField?

    init(
        bookingDate: Date,
        prefilledClient: Client? = nil,
        onClose: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.bookingDate = bookingDate
        self.prefilledClient = prefilledClient
        self.onClose = onClose
        self.onSuccess = onSuccess
        _viewModel = State(
            initialValue: ManualBookingViewModel(
                initialDate: bookingDate,
                prefilledClient: prefilledClient
            )
        )
    }

    private enum Layout {
        static let contentPadding: CGFloat = 20
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stepProgressBar
            bodyContent
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task {
            await viewModel.loadServicesIfNeeded()
        }
    }

    private var isScheduleStep: Bool {
        viewModel.step == .schedule
    }

    private var stepProgressBar: some View {
        GeometryReader { bar in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AdminTheme.stone200)
                Capsule()
                    .fill(AdminTheme.stone900)
                    .frame(width: bar.size.width * stepProgressFraction)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, Layout.contentPadding)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.22), value: viewModel.step)
    }

    private var stepProgressFraction: CGFloat {
        if viewModel.lockedClient != nil {
            switch viewModel.step {
            case .service: return 0.5
            case .schedule: return 1.0
            case .client: return 0.5
            }
        }
        return CGFloat(viewModel.step.rawValue) / CGFloat(ManualBookingViewModel.Step.allCases.count)
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
            }

            Spacer(minLength: 8)

            Button {
                if !viewModel.isCompleting { onClose() }
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
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if isScheduleStep {
            VStack(alignment: .leading, spacing: 10) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                if viewModel.isCompleting {
                    completingOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ManualBookingSlotPickerView(viewModel: viewModel, layout: .compact)
                }
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

    private func dismissClientKeyboard() {
        focusedClientField = nil
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)

            HStack(spacing: 12) {
                Button {
                    viewModel.goBackOrCancel(onCancel: onClose)
                } label: {
                    Text(viewModel.step == .service ? "Cancel" : "Back")
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

                if viewModel.step != .schedule {
                    Button {
                        dismissClientKeyboard()
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
                } else {
                    Button {
                        Task { await viewModel.book(onSuccess: onSuccess) }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isCompleting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AdminTheme.cream)
                            }
                            Text(viewModel.isCompleting ? "Booking…" : "Book appointment")
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
            return false
        }
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
                selectionIndicator(active: active)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.title)
                        .font(AdminTheme.fontAdminSerif(size: indented ? 16 : 17))
                        .foregroundStyle(AdminTheme.stone900)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !service.detailMetaLine.isEmpty {
                        Text(service.detailMetaLine)
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                            .tracking(0.5)
                            .foregroundStyle(AdminTheme.stone500)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if active, !service.description.isEmpty {
                        Text(service.description)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(AdminTheme.stone600)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? AdminTheme.stone50 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: active ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
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
            Text("Saving appointment…")
                .font(AdminTheme.fontAdminSerif(size: 18))
                .foregroundStyle(AdminTheme.stone900)
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
