import SwiftUI

/// Admin god-mode reschedule — same slot picker as New booking
/// (any day + green/black open-hours dots), not Cal’s public embed.
struct RescheduleBookingView: View {
    let appointment: Appointment
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: RescheduleViewModel
    @State private var expandedGroupIDs: Set<Int> = []

    init(
        appointment: Appointment,
        onBack: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        self.appointment = appointment
        self.onBack = onBack
        self.onSuccess = onSuccess
        _viewModel = State(initialValue: RescheduleViewModel(appointment: appointment))
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
                                title: "Loading times",
                                subtitle: "Preparing open slots for this appointment"
                            )
                        } else {
                            switch viewModel.step {
                            case .service:
                                serviceStep
                            case .schedule:
                                ManualBookingSlotPickerView(
                                    viewModel: viewModel.booking,
                                    layout: .compact
                                )
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
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                if viewModel.step == .schedule, viewModel.needsServicePick {
                    viewModel.goBackToService()
                } else {
                    onBack()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.step == .schedule && viewModel.needsServicePick ? "Service" : "Back")
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
                Text("Reschedule")
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
            Text("Moving appointment…")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream)
    }

    private var serviceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the service for the new time")
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
        }
    }

    private func serviceRow(_ service: ManualBookingServiceOption) -> some View {
        let selected = viewModel.booking.selectedService?.id == service.id
        return Button {
            viewModel.selectService(service)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.title)
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Text(service.detailMetaLine)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AdminTheme.stone900)
                }
            }
            .padding(12)
            .background(selected ? AdminTheme.stone50 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                ForEach(group.children) { child in
                    serviceRow(child)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(AdminTheme.stone200)
            HStack(spacing: 12) {
                Button {
                    if viewModel.step == .schedule, viewModel.needsServicePick {
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

                if viewModel.isBootstrapping {
                    Button {} label: {
                        Text("Loading…")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(AdminTheme.stone500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AdminTheme.stone200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                } else if viewModel.step == .service {
                    Button {
                        Task { await viewModel.advanceToSchedule() }
                    } label: {
                        Text("Continue")
                            .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(viewModel.canAdvanceFromService ? AdminTheme.cream : AdminTheme.stone500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.canAdvanceFromService ? AdminTheme.stone900 : AdminTheme.stone200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canAdvanceFromService || viewModel.isCompleting)
                } else {
                    Button {
                        Task {
                            let ok = await viewModel.confirm()
                            if ok { onSuccess() }
                        }
                    } label: {
                        Text(viewModel.isCompleting ? "Saving…" : "Confirm new time")
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

// MARK: - View model

@MainActor
@Observable
final class RescheduleViewModel {
    enum Step {
        case service
        case schedule
    }

    let appointment: Appointment
    private(set) var booking: ManualBookingViewModel
    private(set) var step: Step = .schedule
    private(set) var isBootstrapping = true
    private(set) var isCompleting = false
    private(set) var errorMessage: String?
    /// When the appointment already has a matching service slug, skip the picker.
    private(set) var needsServicePick = false

    init(appointment: Appointment) {
        self.appointment = appointment
        let seedDate = appointment.bookingTime
            .flatMap(BookingDisplay.iso8601Date(from:))
            ?? Date()
        self.booking = ManualBookingViewModel(initialDate: seedDate)
    }

    var headerTitle: String {
        if isBootstrapping {
            let name = appointment.serviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Move appointment" : name
        }
        if step == .schedule, let service = booking.selectedService {
            return service.title
        }
        return "Move appointment"
    }

    var canAdvanceFromService: Bool {
        booking.selectedService != nil
    }

    var canConfirm: Bool {
        booking.selectedSlot != nil && booking.selectedService != nil && !isCompleting
    }

    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        booking.clientFirstName = appointment.clientFirstName ?? ""
        booking.clientLastName = appointment.clientLastName ?? ""
        booking.clientPhone = appointment.clientPhone ?? ""
        booking.clientEmail = ClientEmail.usableDisplay(appointment.clientEmail) ?? ""

        await booking.loadServicesIfNeeded()
        if let slug = appointment.serviceSlug,
           let match = findService(slug: slug) {
            needsServicePick = false
            step = .schedule
            await booking.prepareSchedule(for: match)
        } else {
            needsServicePick = true
            step = .service
        }
    }

    func selectService(_ service: ManualBookingServiceOption) {
        booking.selectService(service)
        errorMessage = nil
    }

    func advanceToSchedule() async {
        guard let service = booking.selectedService else { return }
        await booking.prepareSchedule(for: service)
        step = .schedule
    }

    func goBackToService() {
        step = .service
        errorMessage = nil
    }

    func confirm() async -> Bool {
        guard let service = booking.selectedService,
              let slot = booking.selectedSlot else { return false }

        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }

        do {
            let start = try StudioTime.slotToStudioLocalStart(isoUtc: slot)
            _ = try await AdminAPIClient.shared.adminRescheduleAppointment(
                id: appointment.id,
                start: start,
                eventTypeId: service.eventTypeId
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

    private func findService(slug: String) -> ManualBookingServiceOption? {
        for section in booking.serviceSections {
            for row in section.rows {
                switch row {
                case .service(let service) where service.slug == slug:
                    return service
                case .group(let group):
                    if let child = group.children.first(where: { $0.slug == slug }) {
                        return child
                    }
                default:
                    continue
                }
            }
        }
        return nil
    }
}
