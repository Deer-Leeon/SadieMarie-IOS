import SwiftUI
import ClerkKit
import UIKit

/// Bookings tab — calendar / appointment workspace. View mode is a compact
/// menu in the header (List / 3 Day / Week / Month). List mode loads live
/// appointments from the admin API.
struct BookingsView: View {
    @Bindable var viewModel: BookingsViewModel
    /// Incremented by `RootTabView` each time the user switches to the Bookings tab.
    var tabVisitID: Int = 0
    /// Incremented when Bookings is tapped while it is already the selected tab.
    var jumpToTodayID: Int = 0
    /// True while this tab is selected. Live-polls only while visible.
    var isSelected: Bool = true

    private static let livePollInterval: Duration = .seconds(10)

    enum CalendarMode: String, CaseIterable, Identifiable, Hashable {
        case list = "List"
        case threeDay = "3 Day"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .list: "list.bullet"
            case .threeDay: "rectangle.split.3x1"
            case .week: "calendar"
            case .month: "square.grid.3x3"
            }
        }
    }

    @Environment(Clerk.self) private var clerk
    @Environment(AppState.self) private var appState
    @Environment(PushRegistration.self) private var pushRegistration

    @State private var mode: CalendarMode = .week
    @State private var selectedAppointment: Appointment?
    @State private var dayFocus: DayFocus?
    @State private var manualBookingFocus: ManualBookingFocus?
    @State private var slotAction: CalendarSlotActionFocus?
    @State private var selectedBlock: TimeBlock?
    @State private var blockPendingEdit: TimeBlock?
    @State private var showSettings = false
    @State private var appliedNoShowFlagRevision = 0
    @State private var rangeTitle = ""

    var body: some View {
        NavigationStack {
            ZStack {
                contentBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 10) {
                            Text("Bookings")
                                .font(AdminTheme.fontAdminSerif(size: 28))
                                .foregroundStyle(AdminTheme.stone900)

                            Spacer(minLength: 8)

                            calendarModeMenu

                            headerCircleButton(
                                systemImage: "gearshape",
                                label: "Settings"
                            ) {
                                showSettings = true
                            }

                            headerCircleButton(
                                systemImage: "plus",
                                label: "New booking"
                            ) {
                                manualBookingFocus = ManualBookingFocus(date: Date())
                            }
                        }

                        Text(showsRangeCaption && !rangeTitle.isEmpty ? rangeTitle : " ")
                            .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                            .foregroundStyle(AdminTheme.stone500)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .opacity(showsRangeCaption && !rangeTitle.isEmpty ? 1 : 0)
                            .accessibilityHidden(!showsRangeCaption || rangeTitle.isEmpty)
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    if pushRegistration.needsSystemSettings {
                        notificationsDeniedBanner
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }

                    modeContent
                        .id(mode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(
                            .container,
                            edges: mode == .month ? .bottom : []
                        )
                        .transaction { $0.disablesAnimations = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .task(id: clerk.session?.id) {
                guard clerk.session != nil else { return }
                if !viewModel.hasLoaded {
                    await SessionKeepAlive.waitUntilReadyForAPI()
                    await viewModel.load()
                }
                await openPendingPushAppointmentIfNeeded()
            }
            .task(id: isSelected) {
                await pollWhileVisible()
            }
            .onChange(of: pushRegistration.pendingOpenAppointmentId) { _, appointmentId in
                guard appointmentId != nil else { return }
                Task { await openPendingPushAppointmentIfNeeded() }
            }
            .onChange(of: pushRegistration.liveDataRevision) { _, _ in
                Task { await reloadCalendar(showLoading: false) }
            }
            .onChange(of: tabVisitID) { _, _ in
                mode = .week
                Task {
                    await reloadCalendar(showLoading: false)
                }
            }
            .onChange(of: appState.lastNoShowFlagPatch?.revision) { _, revision in
                guard let patch = appState.lastNoShowFlagPatch,
                      let revision,
                      revision != appliedNoShowFlagRevision
                else { return }
                appliedNoShowFlagRevision = revision
                viewModel.applyClientNoShowFlag(
                    phone: patch.phone,
                    email: patch.email,
                    flag: patch.flag
                )
                if let selected = selectedAppointment,
                   selected.belongsToClient(phone: patch.phone, email: patch.email)
                {
                    selectedAppointment = selected.withClientNoShowFlag(patch.flag)
                }
            }
            .sheet(item: $selectedAppointment) { appointment in
                AppointmentDetailSheet(
                    appointment: appointment,
                    knownAppointments: viewModel.appointments,
                    onDismiss: { selectedAppointment = nil },
                    onMutated: {
                        selectedAppointment = nil
                        Task { await viewModel.load() }
                    },
                    onPaymentMutated: { payment, ids in
                        viewModel.applyPayment(
                            appointmentIds: ids.isEmpty ? [appointment.id] : ids,
                            payment: payment
                        )
                    },
                    onVisitUpdated: { visit in
                        viewModel.replaceAppointment(visit)
                    }
                )
            }
            .overlay {
                ZStack {
                    if let focus = dayFocus {
                        SingleDayModal(
                            viewModel: viewModel,
                            initialDate: focus.date,
                            onClose: { dayFocus = nil },
                            onAppointmentClick: { selectedAppointment = $0 },
                            onHourClick: { date, hour in
                                slotAction = CalendarSlotActionFocus(date: date, hour: hour)
                            }
                        )
                        .transition(.opacity)
                        .zIndex(50)
                    }

                    if let block = blockPendingEdit {
                        BlockTimePopup(
                            activeDate: BookingDisplay.iso8601Date(from: block.startTime) ?? Date(),
                            initialHour: StudioTime.calendar.component(
                                .hour,
                                from: BookingDisplay.iso8601Date(from: block.startTime) ?? Date()
                            ),
                            editingBlock: block,
                            isSubmitting: viewModel.isUpdatingBlock,
                            submissionError: viewModel.errorMessage,
                            onCancel: { blockPendingEdit = nil },
                            onSubmit: { request in
                                Task {
                                    if await viewModel.updateTimeBlock(block, request: request) {
                                        blockPendingEdit = nil
                                    }
                                }
                            }
                        )
                        .zIndex(60)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: dayFocus != nil)
            .confirmationDialog(
                "Blocked time",
                isPresented: Binding(
                    get: { selectedBlock != nil },
                    set: { if !$0 { selectedBlock = nil } }
                ),
                titleVisibility: .visible,
                presenting: selectedBlock
            ) { block in
                Button("Edit block") {
                    selectedBlock = nil
                    blockPendingEdit = block
                }
                Button("Remove block", role: .destructive) {
                    let blockToRemove = block
                    selectedBlock = nil
                    Task { await viewModel.deleteTimeBlock(blockToRemove) }
                }
                Button("Cancel", role: .cancel) {
                    selectedBlock = nil
                }
            } message: { block in
                if let note = block.note, !note.isEmpty {
                    Text(note)
                } else {
                    Text("This will reopen the interval for online booking.")
                }
            }
            .fullScreenCover(item: $manualBookingFocus) { focus in
                ManualBookingWizardView(
                    bookingDate: focus.date,
                    onClose: { manualBookingFocus = nil },
                    onSuccess: {
                        Task { await viewModel.load() }
                    }
                )
                .presentationBackground(AdminTheme.cream)
            }
            .fullScreenCover(item: $slotAction) { action in
                CalendarSlotActionView(
                    date: action.date,
                    hour: action.hour,
                    bookingsViewModel: viewModel,
                    onClose: { slotAction = nil },
                    onBooked: {
                        Task { await viewModel.load() }
                    },
                    onBlocked: {
                        slotAction = nil
                    }
                )
                .presentationBackground(AdminTheme.cream)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(appState)
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .list:
            BookingsListView(
                appointments: viewModel.visibleAppointments,
                showsEmptyState: viewModel.errorMessage == nil,
                onSelectAppointment: { selectedAppointment = $0 }
            )
            .refreshable { await reloadCalendar(showLoading: false) }
        case .threeDay, .week:
            bookingsCalendar
                .scrollDisabled(true)
                .scrollBounceBehavior(.basedOnSize)
        case .month:
            bookingsCalendar
                .refreshable { await reloadCalendar(showLoading: false) }
        }
    }

    private var bookingsCalendar: BookingsCalendarContainerView {
        BookingsCalendarContainerView(
            mode: mode,
            gridAppointments: viewModel.calendarAppointments,
            modalAppointments: viewModel.visibleAppointments,
            timeBlocks: viewModel.timeBlocks,
            scheduleAvailability: viewModel.scheduleAvailability,
            scheduleOverrides: viewModel.scheduleOverrides,
            hasSchedule: viewModel.hasSchedule,
            jumpToTodayID: jumpToTodayID,
            onDayClick: { dayFocus = DayFocus(date: $0) },
            onSelectAppointment: { selectedAppointment = $0 },
            onHourClick: { date, hour in
                slotAction = CalendarSlotActionFocus(date: date, hour: hour)
            },
            onBlockClick: { selectedBlock = $0 },
            rangeTitle: $rangeTitle
        )
    }

    private var showsRangeCaption: Bool {
        mode == .threeDay || mode == .week
    }

    private var calendarModeMenu: some View {
        Menu {
            Picker("Calendar mode", selection: $mode) {
                ForEach(CalendarMode.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(mode.rawValue)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(AdminTheme.stone700)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AdminTheme.cardFill)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
        }
        .accessibilityLabel("Calendar view")
        .accessibilityValue(mode.rawValue)
    }

    private func headerCircleButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)
                .frame(width: 36, height: 36)
                .background(AdminTheme.cardFill)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var contentBackground: Color {
        AdminTheme.cream
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AppFont.body())
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.vertical, 10)
            .background(Color.semanticRed.opacity(0.12))
    }

    private var notificationsDeniedBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Turn on alerts in iPhone Settings")
                .font(AppFont.body())
                .foregroundStyle(AdminTheme.stone900)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
            .foregroundStyle(AdminTheme.stone700)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 10)
        .background(AdminTheme.awaitingPaymentBackground)
    }

    @MainActor
    private func reloadCalendar(showLoading: Bool) async {
        guard clerk.session != nil else { return }
        await viewModel.load(showLoading: showLoading)
        await openPendingPushAppointmentIfNeeded()
    }

    @MainActor
    private func pollWhileVisible() async {
        guard isSelected else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: Self.livePollInterval)
            } catch {
                return
            }
            guard !Task.isCancelled, clerk.session != nil, isSelected else { return }
            await viewModel.load(showLoading: false)
        }
    }

    @MainActor
    private func openPendingPushAppointmentIfNeeded() async {
        guard let appointmentId = pushRegistration.pendingOpenAppointmentId else { return }
        if let existing = viewModel.appointments.first(where: { $0.id == appointmentId }) {
            selectedAppointment = existing
            _ = pushRegistration.consumePendingOpenAppointmentId()
            return
        }
        await viewModel.load()
        if let found = viewModel.appointments.first(where: { $0.id == appointmentId }) {
            selectedAppointment = found
        }
        _ = pushRegistration.consumePendingOpenAppointmentId()
    }
}

#Preview {
    BookingsView(viewModel: BookingsViewModel())
        .environment(AppState())
        .environment(PushRegistration.shared)
}
