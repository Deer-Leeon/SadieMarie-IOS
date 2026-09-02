import SwiftUI

/// Native admin calendar shell — 3-day / week use `BookingsTimeGridView`; month scrolls infinitely.
struct BookingsCalendarContainerView: View {
    let mode: BookingsView.CalendarMode
    /// Confirmed bookings for 3-day / week grids (no pending, no canceled).
    let gridAppointments: [Appointment]
    /// List + single-day modal + month (includes pending and no-show).
    let modalAppointments: [Appointment]
    let timeBlocks: [TimeBlock]
    var scheduleAvailability: [ScheduleAvailabilityBlock] = []
    var scheduleOverrides: [ScheduleOverride] = []
    var hasSchedule: Bool = false
    var jumpToTodayID: Int = 0
    var onDayClick: ((Date) -> Void)?
    var onSelectAppointment: ((Appointment) -> Void)?
    var onHourClick: ((Date, Int) -> Void)?
    var onBlockClick: ((TimeBlock) -> Void)?
    @Binding var rangeTitle: String

    @State private var rangeStart = Calendar.current.startOfDay(for: Date())
    @State private var store: AppointmentCalendarStore
    @State private var monthStore: AppointmentCalendarStore
    @State private var monthScrollToTodayToken = 0

    private let calendar = Calendar.current

    init(
        mode: BookingsView.CalendarMode,
        gridAppointments: [Appointment],
        modalAppointments: [Appointment],
        timeBlocks: [TimeBlock],
        scheduleAvailability: [ScheduleAvailabilityBlock] = [],
        scheduleOverrides: [ScheduleOverride] = [],
        hasSchedule: Bool = false,
        jumpToTodayID: Int = 0,
        onDayClick: ((Date) -> Void)? = nil,
        onSelectAppointment: ((Appointment) -> Void)? = nil,
        onHourClick: ((Date, Int) -> Void)? = nil,
        onBlockClick: ((TimeBlock) -> Void)? = nil,
        rangeTitle: Binding<String>
    ) {
        self.mode = mode
        self.gridAppointments = gridAppointments
        self.modalAppointments = modalAppointments
        self.timeBlocks = timeBlocks
        self.scheduleAvailability = scheduleAvailability
        self.scheduleOverrides = scheduleOverrides
        self.hasSchedule = hasSchedule
        self.jumpToTodayID = jumpToTodayID
        self.onDayClick = onDayClick
        self.onSelectAppointment = onSelectAppointment
        self.onHourClick = onHourClick
        self.onBlockClick = onBlockClick
        _rangeTitle = rangeTitle
        _store = State(
            initialValue: AppointmentCalendarStore(
                appointments: gridAppointments,
                timeBlocks: timeBlocks
            )
        )
        _monthStore = State(
            initialValue: AppointmentCalendarStore(
                appointments: modalAppointments,
                timeBlocks: timeBlocks
            )
        )
    }

    private var visibleDays: [Date] {
        BookingDisplay.CalendarFormatting.visibleDays(
            mode: mode,
            rangeStart: rangeStart,
            calendar: calendar
        )
    }

    private var headerTitle: String {
        BookingDisplay.CalendarFormatting.visibleRangeTitle(
            days: visibleDays,
            calendar: calendar
        )
    }

    private var fillsHeight: Bool {
        mode != .list
    }

    var body: some View {
        calendarBody
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
            .background(AdminTheme.cream)
            .preferredColorScheme(.light)
            .onAppear {
                syncStore()
                alignRangeStartForMode()
                publishRangeTitle()
            }
            .onChange(of: rangeStart) { _, _ in publishRangeTitle() }
            .onChange(of: gridAppointments) { _, _ in syncStore() }
            .onChange(of: modalAppointments) { _, _ in syncStore() }
            .onChange(of: timeBlocks) { _, _ in syncStore() }
            .onChange(of: mode) { _, _ in
                syncStore()
                alignRangeStartForMode()
                publishRangeTitle()
            }
            .onChange(of: jumpToTodayID) { oldValue, newValue in
                guard newValue != oldValue else { return }
                jumpToTodayFromTabReselect()
            }
    }

    @ViewBuilder
    private var calendarBody: some View {
        switch mode {
        case .threeDay, .week:
            swipeableTimeGrid
        case .month:
            BookingsMonthCalendarView(
                store: monthStore,
                scrollToTodayID: monthScrollToTodayToken,
                onDayClick: onDayClick
            )
        case .list:
            EmptyView()
        }
    }

    private func syncStore() {
        store.replace(appointments: gridAppointments, timeBlocks: timeBlocks)
        monthStore.replace(appointments: modalAppointments, timeBlocks: timeBlocks)
    }

    private var navigationStepDays: Int {
        BookingDisplay.CalendarFormatting.navigationStride(mode: mode)
    }

    private var swipeableTimeGrid: some View {
        let isWeek = mode == .week
        let timeColumnWidth = BookingsCalendarLayout.timeColumnWidth(isWeek: isWeek)
        let headerHeight = BookingsCalendarLayout.dayColumnHeaderHeight
        let hPad = BookingsCalendarLayout.horizontalPadding(isWeek: isWeek)

        return BookingsCalendarRangePager(
            rangeStart: rangeStart,
            stepDays: navigationStepDays,
            calendar: calendar,
            pinnedLeadingWidth: timeColumnWidth,
            pinnedLeading: {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: timeColumnWidth, height: headerHeight)
                    Color.clear
                        .frame(height: BookingsCalendarLayout.gridTopGutter)
                    GeometryReader { rail in
                        if let hourHeight = BookingsCalendarLayout.resolvedHourHeight(
                            inAvailableHeight: rail.size.height
                        ) {
                            BookingsTimeLabelsColumn(
                                hourHeight: hourHeight,
                                isWeekStyle: isWeek
                            )
                        }
                    }
                }
            },
            pinnedBackdrop: {
                VStack(spacing: 0) {
                    Color.clear.frame(height: headerHeight)
                    Color.clear.frame(height: BookingsCalendarLayout.gridTopGutter)
                    GeometryReader { grid in
                        if let hourHeight = BookingsCalendarLayout.resolvedHourHeight(
                            inAvailableHeight: grid.size.height
                        ) {
                            BookingsHourlyGridBackground(hourHeight: hourHeight)
                        }
                    }
                }
            },
            daysForRangeStart: { start in
                BookingDisplay.CalendarFormatting.visibleDays(
                    mode: mode,
                    rangeStart: start,
                    calendar: calendar
                )
            },
            onCommitNavigation: { direction in
                navigate(by: direction)
            }
        ) { days in
            BookingsTimeGridView(
                days: days,
                store: store,
                onDayClick: onDayClick,
                onSelectAppointment: onSelectAppointment,
                onHourClick: onHourClick,
                onBlockClick: onBlockClick,
                showsPinnedChrome: false,
                scheduleAvailability: scheduleAvailability,
                scheduleOverrides: scheduleOverrides,
                hasSchedule: hasSchedule
            )
        }
        .padding(.horizontal, hPad)
        .padding(.bottom, BookingsCalendarLayout.timeGridBottomGutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .scrollDisabled(true)
    }

    // MARK: - Navigation (3-day / week only)

    private func navigate(by direction: Int) {
        let stride = navigationStepDays
        guard stride > 0, direction != 0 else { return }
        guard let next = calendar.date(byAdding: .day, value: stride * direction, to: rangeStart) else { return }
        rangeStart = calendar.startOfDay(for: next)
    }

    private func jumpToToday() {
        rangeStart = BookingDisplay.CalendarFormatting.currentRangeStart(
            mode: mode,
            calendar: calendar
        )
    }

    private func jumpToTodayFromTabReselect() {
        switch mode {
        case .threeDay, .week:
            if BookingDisplay.CalendarFormatting.rangeContainsToday(
                mode: mode,
                rangeStart: rangeStart,
                calendar: calendar
            ) {
                return
            }
            jumpToToday()
        case .month:
            monthScrollToTodayToken += 1
        case .list:
            break
        }
    }

    private func alignRangeStartForMode() {
        guard mode == .threeDay || mode == .week else { return }
        jumpToToday()
    }

    private func publishRangeTitle() {
        rangeTitle = (mode == .threeDay || mode == .week) ? headerTitle : ""
    }
}

#Preview("3 Day grid") {
    BookingsCalendarContainerView(
        mode: .threeDay,
        gridAppointments: Appointment.mockList.calendarAppointments,
        modalAppointments: Appointment.mockList.visibleAppointments,
        timeBlocks: [],
        rangeTitle: .constant("")
    )
}
