import SwiftUI

/// Focused single-day timeline overlay (web `SingleDayModal`, z-50).
struct SingleDayModal: View {
    @Bindable var viewModel: BookingsViewModel
    let initialDate: Date
    var onClose: () -> Void
    var onAppointmentClick: ((Appointment) -> Void)?
    var onHourClick: ((Date, Int) -> Void)?

    @State private var activeDate: Date
    @State private var selectedBlock: TimeBlock?
    @State private var blockPendingEdit: TimeBlock?

    private let calendar = Calendar.current

    init(
        viewModel: BookingsViewModel,
        initialDate: Date,
        onClose: @escaping () -> Void,
        onAppointmentClick: ((Appointment) -> Void)? = nil,
        onHourClick: ((Date, Int) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.initialDate = initialDate
        self.onClose = onClose
        self.onAppointmentClick = onAppointmentClick
        self.onHourClick = onHourClick
        _activeDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var positioned: [PositionedAppointment] {
        TimelineEngine.layoutForDay(date: activeDate, appointments: viewModel.visibleAppointments)
    }

    private var positionedBlocks: [PositionedTimeBlock] {
        TimelineEngine.layoutBlocksForDay(date: activeDate, blocks: viewModel.timeBlocks)
    }

    private var closedHatchBands: [StudioScheduleWindows.MinuteBand] {
        guard viewModel.hasSchedule else { return [] }
        let holes = positioned.compactMap { StudioScheduleWindows.minuteBand(from: $0.appointment) }
        return StudioScheduleWindows.closedBands(
            forYMD: StudioTime.yyyyMMdd(from: activeDate),
            availability: viewModel.scheduleAvailability,
            overrides: viewModel.scheduleOverrides,
            holes: holes
        )
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.35))
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                modalHeader

                Text("Tap an hour to book or block · tap a block to edit")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(AdminTheme.cream.opacity(0.98))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AdminTheme.stone200)
                            .frame(height: 0.5)
                    }

                SingleDayTimelineView(
                    items: positioned,
                    timeBlocks: positionedBlocks,
                    removingBlockId: viewModel.removingBlockId,
                    onHourTap: { hour in
                        onHourClick?(activeDate, hour)
                    },
                    onAppointmentTap: onAppointmentClick,
                    onBlockTap: { selectedBlock = $0 },
                    hatchBands: closedHatchBands
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: 520)
            .frame(height: UIScreen.main.bounds.height * 0.82)
            .background(AdminTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, 16)
            .onTapGesture { }

            if let block = blockPendingEdit {
                BlockTimePopup(
                    activeDate: activeDate,
                    initialHour: StudioTime.calendar.component(
                        .hour,
                        from: BookingDisplay.iso8601Date(from: block.startTime) ?? activeDate
                    ),
                    editingBlock: block,
                    isSubmitting: viewModel.isUpdatingBlock,
                    submissionError: viewModel.errorMessage,
                    onCancel: { blockPendingEdit = nil },
                    onSubmit: { submitBlockEdit(block, request: $0) }
                )
                .zIndex(60)
            }
        }
        .preferredColorScheme(.light)
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
        .onChange(of: initialDate) { _, newValue in
            activeDate = calendar.startOfDay(for: newValue)
        }
    }

    private var modalHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(weekdayTitle)
                    .font(AdminTheme.fontAdminSerif(size: 20))
                    .foregroundStyle(AdminTheme.stone900)
                Text(monthDayTitle)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
            }
            .frame(maxWidth: .infinity)

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AdminTheme.cream.opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
    }

    private var weekdayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: activeDate)
    }

    private var monthDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: activeDate)
    }

    private func shiftDay(by offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: activeDate) else { return }
        activeDate = calendar.startOfDay(for: next)
        blockPendingEdit = nil
    }

    private func submitBlockEdit(_ block: TimeBlock, request: BlockTimeRequest) {
        Task {
            if await viewModel.updateTimeBlock(block, request: request) {
                blockPendingEdit = nil
            }
        }
    }
}

/// Identifiable wrapper for presenting `SingleDayModal`.
struct DayFocus: Identifiable, Hashable {
    let date: Date

    var id: TimeInterval {
        Calendar.current.startOfDay(for: date).timeIntervalSince1970
    }

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
