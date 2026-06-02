import SwiftUI

/// Full-screen manual booking wizard (mirrors web `ManualBookingModal`).
struct ManualBookingWizardView: View {
    let bookingDate: Date
    var onClose: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: ManualBookingViewModel
    @State private var expandedGroupIDs: Set<Int> = []
    @FocusState private var focusedClientField: ManualBookingClientField?

    init(
        bookingDate: Date,
        onClose: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.bookingDate = bookingDate
        self.onClose = onClose
        self.onSuccess = onSuccess
        _viewModel = State(initialValue: ManualBookingViewModel(initialDate: bookingDate))
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.35))
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isCompleting { onClose() }
                }

            VStack(spacing: 0) {
                header
                bodyContent
                footer
            }
            .frame(maxWidth: 520)
            .frame(maxHeight: modalMaxHeight)
            .background(AdminTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, isScheduleStep ? 10 : 16)
            .onTapGesture { }
        }
        .preferredColorScheme(.light)
        .task {
            await viewModel.loadServicesIfNeeded()
        }
    }

    private var isScheduleStep: Bool {
        viewModel.step == .schedule
    }

    private var modalMaxHeight: CGFloat {
        if isScheduleStep {
            return min(UIScreen.main.bounds.height * 0.88, 680)
        }
        return min(UIScreen.main.bounds.height * 0.92, 680)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: isScheduleStep ? 2 : 4) {
                Text("Manual booking")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)

                Text(viewModel.headerTitle)
                    .font(AdminTheme.fontAdminSerif(size: isScheduleStep ? 18 : 20))
                    .foregroundStyle(AdminTheme.stone900)
                    .lineLimit(1)

                Text(viewModel.headerSubtitle)
                    .font(AdminTheme.fontAdminSans(size: isScheduleStep ? 11 : 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                if !viewModel.isCompleting { onClose() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)
        }
        .padding(.horizontal, isScheduleStep ? 16 : 20)
        .padding(.vertical, isScheduleStep ? 12 : 16)
        .background(AdminTheme.cream)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
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
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(viewModel.step == .client ? .never : .interactively)
        }
    }

    private func dismissClientKeyboard() {
        focusedClientField = nil
    }

    private var footer: some View {
        HStack {
            Button {
                viewModel.goBackOrCancel(onCancel: onClose)
            } label: {
                Text(viewModel.step == .service ? "Cancel" : "Back")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(AdminTheme.stone600)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AdminTheme.cardFill)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AdminTheme.stone200, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)

            Spacer()

            if viewModel.step != .schedule {
                Button {
                    dismissClientKeyboard()
                    viewModel.advanceStep()
                } label: {
                    Text("Continue")
                        .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                        .tracking(1.8)
                        .foregroundStyle(AdminTheme.cream)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AdminTheme.stone700)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canContinue || viewModel.isCompleting)
                .opacity(canContinue && !viewModel.isCompleting ? 1 : 0.5)
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
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                            .tracking(1.8)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(AdminTheme.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AdminTheme.stone700)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canBook)
                .opacity(viewModel.canBook ? 1 : 0.5)
            }
        }
        .padding(.horizontal, isScheduleStep ? 16 : 20)
        .padding(.vertical, isScheduleStep ? 10 : 12)
        .background(AdminTheme.cream)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a service")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone600)

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
        VStack(alignment: .leading, spacing: 8) {
            if !section.category.isEmpty {
                Text(section.category)
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
            }

            VStack(spacing: 8) {
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
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(AdminTheme.fontAdminSerif(size: 16))
                            .foregroundStyle(AdminTheme.stone900)
                            .multilineTextAlignment(.leading)

                        if !group.description.isEmpty {
                            Text(group.description)
                                .font(AdminTheme.fontAdminSans(size: 13))
                                .foregroundStyle(AdminTheme.stone600)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ServiceFormat.price(group.price, prefixFrom: true))
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                            .foregroundStyle(AdminTheme.stone700)

                        if hasChildren {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AdminTheme.stone500)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(service.title)
                    .font(AdminTheme.fontAdminSerif(size: indented ? 15 : 16))
                    .foregroundStyle(AdminTheme.stone900)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !service.detailMetaLine.isEmpty {
                    Text(service.detailMetaLine)
                        .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(AdminTheme.stone500)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !service.description.isEmpty {
                    Text(service.description)
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(active ? AdminTheme.stone50 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? AdminTheme.stone300 : AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
