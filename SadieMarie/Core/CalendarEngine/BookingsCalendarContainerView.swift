import SwiftUI

/// Native admin calendar shell — 3-day / week use `BookingsTimeGridView`; month scrolls infinitely.
struct BookingsCalendarContainerView: View {
    let mode: BookingsView.CalendarMode
    /// Confirmed bookings for 3-day / week grids (no pending, no canceled).
    let gridAppointments: [Appointment]
    /// List + single-day modal + month (includes pending and no-show).
    let modalAppointments: [Appointment]
    var onDayClick: ((Date) -> Void)?
    var onSelectAppointment: ((Appointment) -> Void)?

    @State private var rangeStart = Calendar.current.startOfDay(for: Date())
    @State private var store = AppointmentCalendarStore()
    @State private var monthScrollToTodayToken = 0

    private let calendar = Calendar.current

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

    private var showsDateNavigation: Bool {
        mode == .threeDay || mode == .week
    }

    private var fillsHeight: Bool {
        mode != .list
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDateNavigation {
                BookingsCalendarHeader(
                    title: headerTitle,
                    onPrevious: { navigate(by: -1) },
                    onToday: { jumpToToday() },
                    onNext: { navigate(by: 1) }
                )
                .animation(.easeInOut(duration: 0.22), value: rangeStart)

                Divider()
                    .overlay(AdminTheme.stone200)
            }

            calendarBody
                .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
                .animation(.easeInOut(duration: 0.22), value: mode)
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
        .background(AdminTheme.cream)
        .preferredColorScheme(.light)
        .onAppear {
            syncStore()
            alignRangeStartForMode()
            if mode == .month {
                monthScrollToTodayToken += 1
            }
        }
        .onChange(of: gridAppointments) { _, _ in syncStore() }
        .onChange(of: modalAppointments) { _, _ in syncStore() }
        .onChange(of: mode) { _, newMode in
            syncStore()
            alignRangeStartForMode()
            if newMode == .month {
                monthScrollToTodayToken += 1
            }
        }
    }

    @ViewBuilder
    private var calendarBody: some View {
        Group {
            switch mode {
            case .threeDay, .week:
                swipeableTimeGrid
            case .month:
                BookingsMonthCalendarView(
                    appointments: modalAppointments,
                    onDayClick: onDayClick
                )
            case .list:
                EmptyView()
            }
        }
        .id(mode)
    }

    private func syncStore() {
        guard mode != .month else { return }
        store.replace(appointments: gridAppointments)
    }

    private var navigationStepDays: Int {
        BookingDisplay.CalendarFormatting.navigationStride(mode: mode)
    }

    private var swipeableTimeGrid: some View {
        BookingsCalendarRangePager(
            rangeStart: rangeStart,
            stepDays: navigationStepDays,
            calendar: calendar,
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
                onSelectAppointment: onSelectAppointment
            )
        }
    }

    // MARK: - Navigation (3-day / week only)

    private func navigate(by direction: Int) {
        let stride = navigationStepDays
        guard stride > 0, direction != 0 else { return }
        guard let next = calendar.date(byAdding: .day, value: stride * direction, to: rangeStart) else { return }
        rangeStart = calendar.startOfDay(for: next)
    }

    private func jumpToToday() {
        let today = calendar.startOfDay(for: Date())
        switch mode {
        case .week:
            rangeStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        case .threeDay:
            rangeStart = today
        case .month, .list:
            break
        }
    }

    private func alignRangeStartForMode() {
        guard mode == .threeDay || mode == .week else { return }
        jumpToToday()
    }
}

#Preview("3 Day grid") {
    BookingsCalendarContainerView(
        mode: .threeDay,
        gridAppointments: Appointment.mockList.calendarAppointments,
        modalAppointments: Appointment.mockList.visibleAppointments
    )
}
