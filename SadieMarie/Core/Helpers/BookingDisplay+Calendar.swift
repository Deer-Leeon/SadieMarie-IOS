import Foundation

/// Identifies a week row in the month calendar for scroll positioning.
struct MonthWeekScrollAnchor: Hashable {
    let weekStart: TimeInterval
}

/// Identifies a month section for scroll positioning.
struct MonthSectionAnchor: Hashable {
    let year: Int
    let month: Int

    init(date: Date, calendar: Foundation.Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
    }
}

extension BookingDisplay {

    /// Calendar formatting helpers (named to avoid clashing with `Foundation.Calendar`).
    enum CalendarFormatting {

    static let layoutHourStart = 9
    static let layoutHourEnd = 21

    private static let shortTimeFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateStyle = .none
      f.timeStyle = .short
      return f
    }()

    private static let chipTimeFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "h:mm"
      return f
    }()

    private static let weekdayShortFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "EEE"
      return f
    }()

    private static let monthYearFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "MMMM yyyy"
      return f
    }()

    private static let monthDayFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "MMM d"
      return f
    }()

    private static let monthDayYearFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "MMM d, yyyy"
      return f
    }()

    static func formattedTimeRange(for appointment: Appointment) -> String {
      guard
        let startISO = appointment.bookingTime,
        let start = iso8601Date(from: startISO)
      else { return "—" }

      let startText = shortTimeFormatter.string(from: start)
      guard
        let endISO = appointment.endTime,
        let end = iso8601Date(from: endISO)
      else { return startText }

      return "\(startText) – \(shortTimeFormatter.string(from: end))"
    }

    static func formattedChipTime(for appointment: Appointment) -> String {
      guard
        let iso = appointment.bookingTime,
        let date = iso8601Date(from: iso)
      else { return "—" }
      return chipTimeFormatter.string(from: date)
    }

    static func shortWeekday(for date: Date) -> String {
      weekdayShortFormatter.string(from: date)
    }

    static func monthYearTitle(for date: Date) -> String {
      monthYearFormatter.string(from: date)
    }

    /// e.g. `May 25 – 27, 2026` or `May 24 – 30, 2026`
    static func visibleRangeTitle(days: [Date], calendar: Foundation.Calendar = .current) -> String {
      guard let first = days.first, let last = days.last else { return "" }

      let y1 = calendar.component(.year, from: first)
      let y2 = calendar.component(.year, from: last)

      if calendar.isDate(first, inSameDayAs: last) {
        return monthDayYearFormatter.string(from: first)
      }

      let m1 = calendar.component(.month, from: first)
      let m2 = calendar.component(.month, from: last)

      if m1 == m2, y1 == y2 {
        let month = monthDayFormatter.string(from: first).components(separatedBy: " ").first ?? ""
        let d1 = calendar.component(.day, from: first)
        let d2 = calendar.component(.day, from: last)
        return "\(month) \(d1) – \(d2), \(y1)"
      }

      return "\(monthDayFormatter.string(from: first)) – \(monthDayYearFormatter.string(from: last))"
    }

    static func dayNumber(for date: Date, calendar: Foundation.Calendar = .current) -> Int {
      calendar.component(.day, from: date)
    }

    static func isToday(_ date: Date, calendar: Foundation.Calendar = .current) -> Bool {
      calendar.isDateInToday(date)
    }

    static func visibleDays(
      mode: BookingsView.CalendarMode,
      rangeStart: Date,
      calendar: Foundation.Calendar = .current
    ) -> [Date] {
      let start = calendar.startOfDay(for: rangeStart)
      switch mode {
      case .list:
        return [start]
      case .threeDay:
        return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
      case .week:
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
      case .month:
        return []
      }
    }

    static func navigationStride(mode: BookingsView.CalendarMode) -> Int {
      switch mode {
      case .threeDay: 3
      case .week: 7
      default: 0
      }
    }

    /// Months to render in the month scroll (anchor month ± buffer).
    static func monthsToDisplay(
      around anchor: Date,
      calendar: Foundation.Calendar = .current
    ) -> [Date] {
      guard let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start else {
        return [anchor]
      }
      return (-1...2).compactMap { offset in
        calendar.date(byAdding: .month, value: offset, to: monthStart)
      }
    }

    static func daysInMonthGrid(
        month: Date,
        calendar: Foundation.Calendar = .current
    ) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var result: [Date?] = []
        let firstDay = interval.start

        var leading = calendar.component(.weekday, from: firstDay) - calendar.firstWeekday
        if leading < 0 { leading += 7 }
        for _ in 0..<leading { result.append(nil) }

        var cursor = firstDay
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    /// Chunks a month grid into SUN–SAT rows.
    static func weekRows(from days: [Date?]) -> [[Date?]] {
        guard !days.isEmpty else { return [] }
        return stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }

    /// Scroll target for a week row (`ScrollViewReader`).
    static func weekScrollAnchor(
        for week: [Date?],
        calendar: Foundation.Calendar = .current
    ) -> MonthWeekScrollAnchor? {
        guard let day = week.compactMap({ $0 }).first else { return nil }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        return MonthWeekScrollAnchor(
            weekStart: calendar.startOfDay(for: weekStart).timeIntervalSince1970
        )
    }

    static func todayWeekScrollAnchor(
        calendar: Foundation.Calendar = .current
    ) -> MonthWeekScrollAnchor {
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return MonthWeekScrollAnchor(
            weekStart: calendar.startOfDay(for: weekStart).timeIntervalSince1970
        )
    }

    static func yOffset(
      for date: Date,
      hourHeight: CGFloat,
      calendar: Foundation.Calendar = .current
    ) -> CGFloat {
      let hour = calendar.component(.hour, from: date)
      let minute = calendar.component(.minute, from: date)
      let start = CGFloat(hour - layoutHourStart) + CGFloat(minute) / 60
      return max(0, start * hourHeight)
    }

    static func blockHeight(
        start: Date,
        end: Date,
        hourHeight: CGFloat
    ) -> CGFloat {
        let durationHours = max(end.timeIntervalSince(start) / 3600, 1.0 / 60.0)
        return CGFloat(durationHours) * hourHeight - 2
    }

    static func durationMinutes(start: Date, end: Date) -> Int {
        max(Int(round(end.timeIntervalSince(start) / 60)), 1)
    }

    static func durationMinutes(for appointment: Appointment) -> Int? {
        guard
            let startISO = appointment.bookingTime,
            let start = BookingDisplay.iso8601Date(from: startISO)
        else { return nil }
        let end = appointment.endTime.flatMap { BookingDisplay.iso8601Date(from: $0) }
            ?? start.addingTimeInterval(3600)
        return durationMinutes(start: start, end: end)
    }

    /// First name + last initial — fits narrow grid columns.
    static func gridShortClientName(first: String?, last: String?) -> String {
        let firstName = first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName = last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstName.isEmpty, let initial = lastName.first {
            return "\(firstName) \(initial)."
        }
        return BookingDisplay.clientDisplayName(first: first, last: last)
    }

    static func gridShortServiceLabel(_ appointment: Appointment) -> String {
        let label = BookingDisplay.appointmentServiceLabel(appointment)
        if label.count <= 22 { return label }
        return String(label.prefix(21)) + "…"
    }

    /// Bottom-right service line in 3-day half-hour blocks.
    static func gridCornerServiceLabel(_ appointment: Appointment) -> String {
        let label = BookingDisplay.appointmentServiceLabel(appointment)
        if label.count <= 14 { return label }
        return String(label.prefix(13)) + "…"
    }
    }
}
