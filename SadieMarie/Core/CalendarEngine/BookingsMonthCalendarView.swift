import SwiftUI

/// Scrollable month calendar (SUN–SAT grid). Opens on the current month;
/// months before and after are in the same list so you can scroll either way.
struct BookingsMonthCalendarView: View {
    @Bindable var store: AppointmentCalendarStore
    var scrollToTodayID: Int = 0
    var onDayClick: ((Date) -> Void)?

    private let calendar = Calendar.current
    private let weekdaySymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let adjacentMonthCount = 36

    @State private var hasSettledInitialScroll = false

    private var anchorMonthStart: Date {
        calendar.dateInterval(of: .month, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
    }

    private var currentMonthAnchor: MonthSectionAnchor {
        MonthSectionAnchor(date: anchorMonthStart, calendar: calendar)
    }

    private var months: [Date] {
        ((-adjacentMonthCount)...adjacentMonthCount).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: anchorMonthStart)
        }
    }

    var body: some View {
        let _ = store.revision

        VStack(spacing: 0) {
            weekdayHeaderRow

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(months, id: \.self) { month in
                            monthSection(month)
                                .id(MonthSectionAnchor(date: month, calendar: calendar))
                        }
                    }
                    .padding(.bottom, 96)
                }
                .opacity(hasSettledInitialScroll ? 1 : 0)
                .onAppear {
                    settleOnCurrentMonth(using: proxy)
                }
                .onChange(of: scrollToTodayID) { _, newValue in
                    guard newValue > 0 else { return }
                    scrollCurrentMonthToTop(using: proxy)
                }
            }
        }
        .background(AdminTheme.cream)
    }

    private func settleOnCurrentMonth(using proxy: ScrollViewProxy) {
        scrollCurrentMonthToTop(using: proxy)
        DispatchQueue.main.async {
            scrollCurrentMonthToTop(using: proxy)
            hasSettledInitialScroll = true
        }
    }

    private func scrollCurrentMonthToTop(using proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(currentMonthAnchor, anchor: .top)
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
        .background(AdminTheme.cream)
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
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week)
                }
            }
            .monthGridOuterBorder()
        }
    }

    private func weekRow(_ week: [Date?]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<week.count, id: \.self) { index in
                if let day = week[index] {
                    MonthDayCellView(
                        date: day,
                        appointments: store.appointments(on: day),
                        timeBlocks: store.timeBlocks(on: day),
                        isToday: BookingDisplay.CalendarFormatting.isToday(day, calendar: calendar),
                        onDayClick: onDayClick
                    )
                } else {
                    MonthGridPaddingCell()
                }
            }
        }
    }
}
