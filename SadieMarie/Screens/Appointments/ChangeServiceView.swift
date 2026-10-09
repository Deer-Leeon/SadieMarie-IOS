import SwiftUI

/// Swap the catalogue service on an unpaid upcoming visit.
/// The start time stays; confirm shows the new name, length, and price.
struct ChangeServiceView: View {
    let appointment: Appointment
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: ChangeServiceViewModel
    @State private var expandedGroupIDs: Set<Int> = []
    @State private var sendSms = true

    init(
        appointment: Appointment,
        onBack: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.appointment = appointment
        self.onBack = onBack
        self.onSuccess = onSuccess
        _viewModel = State(initialValue: ChangeServiceViewModel(appointment: appointment))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AdminTheme.stone200)

            if viewModel.isCompleting {
                completingOverlay
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        if viewModel.isBootstrapping {
                            ManualBookingLoadingPanel(
                                title: "Loading services",
                                subtitle: "Fetching your bookable menu"
                            )
                        } else {
                            switch viewModel.step {
                            case .service:
                                serviceStep
                            case .confirm:
                                confirmStep
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }

            footer
        }
        .background(AdminTheme.cream.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task {
            await viewModel.bootstrap()
            if let groupID = viewModel.groupIDContainingCurrentService() {
                expandedGroupIDs.insert(groupID)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                if viewModel.step == .confirm {
                    viewModel.goBackToService()
                } else {
                    onBack()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.step == .confirm ? "Service" : "Back")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                }
                .foregroundStyle(AdminTheme.stone600)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCompleting)

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text("Change service")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(2.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                Text(viewModel.headerTitle)
                    .font(AdminTheme.fontAdminSerif(size: 18))
                    .foregroundStyle(AdminTheme.stone900)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Color.clear.frame(width: 72, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var completingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(AdminTheme.stone900)
            Text("Updating the service…")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
            Text("The time stays the same.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream)
    }

    private var serviceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the new service. The start time stays the same.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone600)

            if viewModel.booking.isLoadingServices {
                ManualBookingLoadingPanel(
                    title: "Loading services",
                    subtitle: "Fetching your bookable menu"
                )
            } else {
                ForEach(viewModel.booking.serviceSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.category.uppercased())
                            .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                            .tracking(2.0)
                            .foregroundStyle(AdminTheme.stone500)
                        ForEach(section.rows) { row in
                            switch row {
                            case .service(let service):
                                serviceRow(service)
                            case .group(let group):
                                groupRow(group)
                            }
                        }
                    }
                }
            }

            if viewModel.isCurrentSelection {
                Text("This visit is already booked as that service.")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The start time stays the same.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone600)

            if let service = viewModel.booking.selectedService {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.title)
                        .font(AdminTheme.fontAdminSerif(size: 22))
                        .foregroundStyle(AdminTheme.stone900)
                    Text(service.detailMetaLine)
                        .font(AdminTheme.fontAdminSans(size: 14))
                        .foregroundStyle(AdminTheme.stone600)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
        }
    }

    private func serviceRow(_ service: ManualBookingServiceOption) -> some View {
        let selected = viewModel.booking.selectedService?.id == service.id
        let isCurrent = service.slug == appointment.serviceSlug
        return Button {
            viewModel.selectService(service)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(service.title)
                            .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                            .foregroundStyle(selected ? AdminTheme.cream : AdminTheme.stone900)
                        if isCurrent {
                            Text("CURRENT")
                                .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                                .tracking(1.2)
                                .foregroundStyle(selected ? AdminTheme.stone300 : AdminTheme.stone500)
                        }
                    }
                    Text(service.detailMetaLine)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(selected ? AdminTheme.stone300 : AdminTheme.stone500)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AdminTheme.cream)
                }
            }
            .padding(12)
            .background(selected ? AdminTheme.stone900 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func groupRow(_ group: ManualBookingGroupRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if expandedGroupIDs.contains(group.id) {
                    expandedGroupIDs.remove(group.id)
                } else {
                    expandedGroupIDs.insert(group.id)
                }
            } label: {
                HStack {
                    Text(group.title)
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Spacer()
                    Image(systemName: expandedGroupIDs.contains(group.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expandedGroupIDs.contains(group.id) {
                ForEach(group.children) { service in
                    serviceRow(service)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(AdminTheme.stone200)
            if viewModel.step == .confirm && !viewModel.isBootstrapping {
                AdminSendSmsToggle(
                    isOn: $sendSms,
                    disabled: viewModel.isCompleting
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            HStack(spacing: 12) {
                Button {
                    if viewModel.step == .confirm {
                        viewModel.goBackToService()
                    } else {
                        onBack()
                    }
                } label: {
                    Text(viewModel.step == .service || viewModel.isBootstrapping ? "Cancel" : "Back")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AdminTheme.stone700)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AdminTheme.cardFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AdminTheme.stone200, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isCompleting)

                if viewModel.step == .service || viewModel.isBootstrapping {
                    Button {
                        viewModel.advanceToConfirm()
                    } label: {
                        Text(viewModel.isBootstrapping ? "Loading…" : "Continue")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(viewModel.canAdvance ? AdminTheme.cream : AdminTheme.stone500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.canAdvance ? AdminTheme.stone900 : AdminTheme.stone200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canAdvance || viewModel.isCompleting || viewModel.isBootstrapping)
                } else {
                    Button {
                        Task {
                            let ok = await viewModel.confirm(sendSms: sendSms)
                            if ok { onSuccess() }
                        }
                    } label: {
                        Text(viewModel.isCompleting ? "Saving…" : "Confirm")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(viewModel.canConfirm ? AdminTheme.cream : AdminTheme.stone500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.canConfirm ? AdminTheme.stone900 : AdminTheme.stone200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canConfirm || viewModel.isCompleting)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AdminTheme.cream)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(Color.semanticRed)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
@Observable
final class ChangeServiceViewModel {
    enum Step {
        case service
        case confirm
    }

    let appointment: Appointment
    private(set) var booking: ManualBookingViewModel
    private(set) var step: Step = .service
    private(set) var isBootstrapping = true
    private(set) var isCompleting = false
    private(set) var errorMessage: String?

    init(appointment: Appointment) {
        self.appointment = appointment
        self.booking = ManualBookingViewModel(initialDate: Date())
    }

    var headerTitle: String {
        if step == .confirm, let service = booking.selectedService {
            return service.title
        }
        return "Change service"
    }

    var isCurrentSelection: Bool {
        guard let slug = appointment.serviceSlug, !slug.isEmpty else { return false }
        return booking.selectedService?.slug == slug
    }

    var canAdvance: Bool {
        booking.selectedService != nil && !isCurrentSelection && !isBootstrapping
    }

    var canConfirm: Bool {
        canAdvance && !isCompleting
    }

    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        await booking.loadServicesIfNeeded()
    }

    func selectService(_ service: ManualBookingServiceOption) {
        booking.selectService(service)
        errorMessage = nil
    }

    func advanceToConfirm() {
        guard canAdvance else { return }
        errorMessage = nil
        step = .confirm
    }

    func goBackToService() {
        step = .service
        errorMessage = nil
    }

    func groupIDContainingCurrentService() -> Int? {
        guard let slug = appointment.serviceSlug, !slug.isEmpty else { return nil }
        for section in booking.serviceSections {
            for row in section.rows {
                if case .group(let group) = row,
                   group.children.contains(where: { $0.slug == slug }) {
                    return group.id
                }
            }
        }
        return nil
    }

    func confirm(sendSms: Bool = true) async -> Bool {
        guard let service = booking.selectedService, canAdvance else { return false }

        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }

        do {
            _ = try await AdminAPIClient.shared.changeAppointmentService(
                id: appointment.id,
                eventTypeId: service.eventTypeId,
                sendSms: sendSms
            )
            return true
        } catch let error as AdminAPIError {
            if case .server(_, let body) = error {
                errorMessage = AdminAPIResponseParser.message(
                    from: body,
                    fallback: error.localizedDescription
                )
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
