import Foundation

// MARK: - UI row state (ViewModel-owned)

/// One row in the weekly card (index `0` = Sunday).
struct WeeklyDayRow: Identifiable, Hashable, Equatable {
    let index: Int
    var enabled: Bool
    var start: Date
    var end: Date

    var id: Int { index }

    var dayName: DayName { DayName.from(index: index) }

    /// Seven disabled rows (Sunday index `0`) with default 9:00–17:00 times.
    static func defaultWeek(reference: Date = Date()) -> [WeeklyDayRow] {
        (0..<7).map { index in
            WeeklyDayRow(
                index: index,
                enabled: false,
                start: AvailabilityTimeFormat.defaultStart(on: reference),
                end: AvailabilityTimeFormat.defaultEnd(on: reference)
            )
        }
    }
}

enum OverrideHoursMode: String, CaseIterable, Identifiable, Hashable {
    case unavailableAllDay = "Unavailable all day"
    case customHours = "Custom hours"

    var id: String { rawValue }
}

/// Editable date-override draft row (client-only `id`; never sent to Cal).
struct OverrideRow: Identifiable, Hashable, Equatable {
    let id: String
    var date: Date
    /// `true` = closed all day; `false` = custom hours (`start`/`end`).
    var unavailable: Bool
    /// UI times (also kept when unavailable so toggling to custom isn’t empty).
    var start: Date
    var end: Date

    var mode: OverrideHoursMode {
        get { unavailable ? .unavailableAllDay : .customHours }
        set { unavailable = (newValue == .unavailableAllDay) }
    }

    /// Custom-hours rows must have start before end (`HH:mm` lexicographic).
    var hasValidCustomHours: Bool {
        guard !unavailable else { return true }
        return AvailabilityTimeFormat.hhmm(from: start) < AvailabilityTimeFormat.hhmm(from: end)
    }

    static func make(
        id: String = UUID().uuidString,
        date: Date = Calendar.current.startOfDay(for: Date()),
        unavailable: Bool = true,
        start: Date? = nil,
        end: Date? = nil
    ) -> OverrideRow {
        let day = Calendar.current.startOfDay(for: date)
        return OverrideRow(
            id: id,
            date: day,
            unavailable: unavailable,
            start: start ?? AvailabilityTimeFormat.defaultStart(on: day),
            end: end ?? AvailabilityTimeFormat.defaultEnd(on: day)
        )
    }
}

// MARK: - Time helpers

enum AvailabilityTimeFormat {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    static let defaultStartHour = 9
    static let defaultEndHour = 17
    static let minuteStride = 15

    static func defaultStart(on reference: Date = Date()) -> Date {
        time(hour: defaultStartHour, minute: 0, on: reference)
    }

    static func defaultEnd(on reference: Date = Date()) -> Date {
        time(hour: defaultEndHour, minute: 0, on: reference)
    }

    static func time(hour: Int, minute: Int, on reference: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? reference
    }

    /// `"HH:mm"` for API payloads.
    static func hhmm(from date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    /// Parse `"HH:mm"` into a time on `reference` day.
    static func date(fromHHMM string: String, on reference: Date = Date()) -> Date? {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return time(hour: hour, minute: minute, on: reference)
    }

    /// `"YYYY-MM-DD"`.
    static func yyyyMMdd(from date: Date) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func date(fromYYYYMMDD string: String) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        return calendar.date(from: components)
    }

    static func roundToStride(_ date: Date) -> Date {
        let minute = calendar.component(.minute, from: date)
        let rounded = (minute + minuteStride / 2) / minuteStride * minuteStride
        let hour = calendar.component(.hour, from: date) + (rounded >= 60 ? 1 : 0)
        let finalMinute = rounded % 60
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = min(hour, 23)
        components.minute = finalMinute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    /// Display label for the timezone eyebrow (`America/Denver` → `America Denver`).
    static func displayTimeZone(_ iana: String) -> String {
        iana.replacingOccurrences(of: "_", with: " ")
    }

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func displayTime(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    static func displayDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    /// Quarter-hour slots from 5:00 AM through 10:45 PM on `reference` day.
    static func quarterHourSlots(on reference: Date) -> [Date] {
        var slots: [Date] = []
        for hour in 5...22 {
            for minute in stride(from: 0, through: 45, by: minuteStride) {
                slots.append(time(hour: hour, minute: minute, on: reference))
            }
        }
        return slots
    }
}
