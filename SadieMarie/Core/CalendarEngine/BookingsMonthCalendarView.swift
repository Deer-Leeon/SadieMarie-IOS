import SwiftUI

/// Scrollable month calendar (SUN–SAT grid). Scroll vertically to move through months.
struct BookingsMonthCalendarView: View {
    /// Source of truth from the parent — avoids stale shared-store timing when switching modes.
    let appointments: [Appointment]
    var onDayClick: ((Date) -> Void)?

    @State private var store = AppointmentCalendarStore()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private let minMonthOffset = -48
    private let maxMonthOffset = 48

    private var anchorMonthStart: Date {
        calendar.dateInterval(of: .month, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
    }

    private var monthStarts: [Date] {
        (minMonthOffset...maxMonthOffset).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: anchorMonthStart)
        }
    }

    private var todayWeekAnchor: MonthWeekScrollAnchor {
        BookingDisplay.CalendarFormatting.todayWeekScrollAnchor(calendar: calendar)
    }

    private var currentMonthAnchor: MonthSectionAnchor {
        MonthSectionAnchor(date: anchorMonthStart, calendar: calendar)
    }

    private var appointmentsSignature: String {
        let prefix = appointments.prefix(5).map(\.id).joined(separator: "|")
        return "\(appointments.count)|\(prefix)"
    }

    var body: some View {
        let _ = store.revision

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    weekdayHeaderRow

                    ForEach(monthStarts, id: \.self) { month in
                        monthSection(month)
                            .id(MonthSectionAnchor(date: month, calendar: calendar))
                    }
                }
                .padding(.bottom, 32)
            }
            .background(AdminTheme.cream)
            .task(id: appointmentsSignature) {
                refreshStore()
                await scrollToToday(using: proxy)
            }
        }
        .onAppear {
            refreshStore()
        }
        .onChange(of: appointmentsSignature) { _, _ in
            refreshStore()
        }
    }

    private func refreshStore() {
        store.replace(appointments: appointments, force: true)
    }

    @MainActor
    private func scrollToToday(using proxy: ScrollViewProxy) async {
        try? await Task.sleep(for: .milliseconds(100))

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(currentMonthAnchor, anchor: .top)
        }

        try? await Task.sleep(for: .milliseconds(50))

        withTransaction(transaction) {
            proxy.scrollTo(todayWeekAnchor, anchor: .center)
        }
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BookingDisplay.CalendarFormatting.monthYearTitle(for: month))
                .font(AdminTheme.fontAdminSerif(size: 26))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)

            let days = BookingDisplay.CalendarFormatting.daysInMonthGrid(month: month, calendar: calendar)
            let weeks = BookingDisplay.CalendarFormatting.weekRows(from: days)

            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                    weekRow(week, weekIndex: weekIndex, month: month)
                }
            }
            .monthGridOuterBorder()
        }
    }

    @ViewBuilder
    private func weekRow(_ week: [Date?], weekIndex: Int, month: Date) -> some View {
        let row = HStack(spacing: 0) {
            ForEach(0..<week.count, id: \.self) { index in
                if let day = week[index] {
                    MonthDayCellView(
                        date: day,
                        appointments: store.appointments(on: day),
                        isToday: BookingDisplay.CalendarFormatting.isToday(day, calendar: calendar),
                        onDayClick: onDayClick
                    )
                } else {
                    MonthGridPaddingCell()
                }
            }
        }

        if let anchor = BookingDisplay.CalendarFormatting.weekScrollAnchor(for: week, calendar: calendar) {
            row.id(anchor)
        } else {
            row.id("month-padding-\(month.timeIntervalSince1970)-\(weekIndex)")
        }
    }
}
