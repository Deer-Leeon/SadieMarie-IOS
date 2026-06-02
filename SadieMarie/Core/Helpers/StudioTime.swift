import Foundation

/// Mountain Time helpers for Cal.com manual bookings (studio is in Lehi, UT).
/// All user-facing slot labels use this zone regardless of device locale.
enum StudioTime {
    static let timeZoneIdentifier = "America/Denver"

    static var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// `YYYY-MM-DD` for "today" in the studio zone.
    static func todayInStudio() -> String {
        yyyyMMdd(from: Date())
    }

    static func yyyyMMdd(from date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func startOfStudioDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Display time for a UTC slot ISO string (e.g. `3:00 PM`).
    static func formatSlotInStudioTime(isoUtc: String) -> String {
        guard let date = parseISO8601(isoUtc) else { return isoUtc }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Studio-local wall time for the create API (`YYYY-MM-DDTHH:mm:ss`, no offset).
    static func slotToStudioLocalStart(isoUtc: String) throws -> String {
        guard let date = parseISO8601(isoUtc) else {
            throw StudioTimeError.invalidSlot
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }

    static func monthLabel(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 15
        guard let date = calendar.date(from: components) else { return "\(month)/\(year)" }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func displayWeekdayMonthDay(isoDate: String) -> String {
        guard let date = date(fromYYYYMMDD: isoDate) else { return isoDate }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    static func date(fromYYYYMMDD string: String) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        return calendar.component(.day, from: calendar.date(from: components) ?? Date())
    }

    private static let iso8601WithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseISO8601(_ string: String) -> Date? {
        iso8601WithFraction.date(from: string) ?? iso8601.date(from: string)
    }

    /// UTC ISO end time from a start ISO + service length (mirrors web `bookingEndFromDurationMins`).
    static func bookingEndFromDuration(startIso: String, durationMins: Int?) -> String? {
        guard let durationMins, durationMins > 0,
              let start = parseISO8601(startIso) else {
            return nil
        }
        let end = start.addingTimeInterval(TimeInterval(durationMins * 60))
        return iso8601.string(from: end)
    }
}

enum StudioTimeError: Error {
    case invalidSlot
}
