import HorizonCalendar
import SwiftUI

/// SwiftUI host for HorizonCalendar’s `CalendarViewRepresentable`.
/// Maps `[Appointment]` into day cells via `CalendarDayBookingsContent` + `BookingCardView`.
struct BookingsHorizonCalendarView: View {

    let mode: BookingsView.CalendarMode
    let appointments: [Appointment]

    @State private var store = AppointmentCalendarStore(calendar: .current)
    @StateObject private var calendarProxy = CalendarViewProxy()

    private var calendar: Calendar { .current }

    private var renderDependency: CalendarRenderDependency {
        CalendarRenderDependency(
            revision: store.revision,
            mode: mode,
            appointmentIDs: appointments.map(\.id)
        )
    }

    var body: some View {
        CalendarViewRepresentable(
            calendar: calendar,
            visibleDateRange: mode.visibleDateRange(calendar: calendar),
            monthsLayout: mode.monthsLayout,
            dataDependency: renderDependency,
            proxy: calendarProxy
        )
        .days { [store, mode, calendar] day in
            let dayDate = calendar.date(from: day.components) ?? Date()
            CalendarDayBookingsContent(
                day: day,
                appointments: store.appointments(on: dayDate),
                isCompact: mode.isCompactCalendar
            )
        }
        .dayAspectRatio(mode.dayAspectRatio)
        .interMonthSpacing(12)
        .verticalDayMargin(4)
        .horizontalDayMargin(4)
        .background { AdminTheme.cream }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            store.replace(appointments: appointments)
            scrollToToday(animated: false)
        }
        .onChange(of: appointments) { _, newValue in
            store.replace(appointments: newValue)
        }
        .onChange(of: mode) { _, _ in
            store.replace(appointments: appointments)
            scrollToToday(animated: false)
        }
    }

    private func scrollToToday(animated: Bool) {
        calendarProxy.scrollToDay(
            containing: Date(),
            scrollPosition: .firstFullyVisiblePosition(padding: 0),
            animated: animated
        )
    }
}

// MARK: - HorizonCalendar refresh token

private struct CalendarRenderDependency: Equatable {
    let revision: UInt
    let mode: BookingsView.CalendarMode
    let appointmentIDs: [String]
}

// MARK: - BookingsView.CalendarMode + HorizonCalendar

extension BookingsView.CalendarMode {

    fileprivate var isCompactCalendar: Bool {
        self == .month
    }

    fileprivate func visibleDateRange(calendar: Calendar, anchor: Date = Date()) -> ClosedRange<Date> {
        let startOfAnchor = calendar.startOfDay(for: anchor)

        switch self {
        case .list:
            return startOfAnchor ... startOfAnchor
        case .threeDay:
            let end = calendar.date(byAdding: .day, value: 2, to: startOfAnchor) ?? startOfAnchor
            return startOfAnchor ... end
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: startOfAnchor)?.start ?? startOfAnchor
            let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return weekStart ... end
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: startOfAnchor)?.start ?? startOfAnchor
            let rangeStart = calendar.date(byAdding: .month, value: -6, to: monthStart) ?? monthStart
            let rangeEndMonth = calendar.date(byAdding: .month, value: 7, to: monthStart) ?? monthStart
            let rangeEnd = calendar.date(byAdding: .day, value: -1, to: rangeEndMonth) ?? rangeEndMonth
            return rangeStart ... rangeEnd
        }
    }

    fileprivate var monthsLayout: MonthsLayout {
        switch self {
        case .list:
            return .vertical(options: VerticalMonthsLayoutOptions())
        case .threeDay, .week:
            return .horizontal(options: HorizontalMonthsLayoutOptions())
        case .month:
            return .vertical(options: VerticalMonthsLayoutOptions(pinDaysOfWeekToTop: true))
        }
    }

    /// Width ÷ height for each day cell. HorizonCalendar only allows 0.5…3.0
    /// (lower = taller cells — better for stacked `BookingCardView`s).
    fileprivate var dayAspectRatio: CGFloat {
        switch self {
        case .list: 1
        case .threeDay: 0.5
        case .week: 0.55
        case .month: 0.65
        }
    }
}

#Preview("Month") {
    BookingsHorizonCalendarView(
        mode: .month,
        appointments: Appointment.mockList.visibleForBookingsList()
    )
}
