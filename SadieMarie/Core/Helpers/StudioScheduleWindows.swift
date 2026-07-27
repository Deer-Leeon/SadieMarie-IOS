import Foundation

/// Planned studio hours from Cal schedule (weekly + overrides).
/// Port of `lib/studio-schedule-windows.ts`.
enum StudioScheduleWindows {

    struct TimeWindow: Hashable, Sendable {
        let startTime: String // HH:MM
        let endTime: String
    }

    /// Planned studio windows for a single YYYY-MM-DD (Mountain calendar date).
    /// Empty = not a studio day.
    static func windows(
        forYMD ymd: String,
        availability: [ScheduleAvailabilityBlock],
        overrides: [ScheduleOverride]
    ) -> [TimeWindow] {
        let forDate = overrides.filter { $0.date == ymd }
        if !forDate.isEmpty {
            if forDate.contains(where: \.isUnavailableAllDay) { return [] }
            return forDate.compactMap { override -> TimeWindow? in
                guard let start = override.startTime,
                      let end = override.endTime,
                      !override.isUnavailableAllDay,
                      start < end else { return nil }
                return TimeWindow(startTime: start, endTime: end)
            }
        }

        guard let dayIndex = dayIndex(fromYMD: ymd) else { return [] }
        var windows: [TimeWindow] = []
        for block in availability {
            guard block.days.contains(dayIndex),
                  block.startTime < block.endTime else { continue }
            windows.append(TimeWindow(startTime: block.startTime, endTime: block.endTime))
        }
        return windows
    }

    static func isStudioDay(
        ymd: String,
        availability: [ScheduleAvailabilityBlock],
        overrides: [ScheduleOverride]
    ) -> Bool {
        !windows(forYMD: ymd, availability: availability, overrides: overrides).isEmpty
    }

    /// Studio days (YYYY-MM-DD) in an inclusive range.
    static func studioDays(
        rangeStart: String,
        rangeEnd: String,
        availability: [ScheduleAvailabilityBlock],
        overrides: [ScheduleOverride]
    ) -> Set<String> {
        var out = Set<String>()
        guard rangeEnd >= rangeStart,
              var cursor = StudioTime.date(fromYYYYMMDD: rangeStart),
              let end = StudioTime.date(fromYYYYMMDD: rangeEnd) else {
            return out
        }

        while cursor <= end {
            let ymd = StudioTime.yyyyMMdd(from: cursor)
            if isStudioDay(ymd: ymd, availability: availability, overrides: overrides) {
                out.insert(ymd)
            }
            guard let next = StudioTime.calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return out
    }

    /// True when the full appointment fits inside a planned studio window.
    static func isAppointmentWithinStudioWindows(
        slotLocalHhmm: String,
        durationMins: Int?,
        windows: [TimeWindow]
    ) -> Bool {
        guard let slotMins = hhmmToMinutes(slotLocalHhmm) else { return false }
        let endMins: Int? = {
            guard let durationMins, durationMins > 0 else { return nil }
            return slotMins + durationMins
        }()

        for window in windows {
            guard let start = hhmmToMinutes(window.startTime),
                  let end = hhmmToMinutes(window.endTime) else { continue }
            if slotMins < start || slotMins >= end { continue }
            if let endMins, endMins > end { continue }
            return true
        }
        return false
    }

    // MARK: - Private

    private static func dayIndex(fromYMD ymd: String) -> Int? {
        // Noon UTC avoids DST edge cases when deriving weekday from a calendar date.
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.component(.weekday, from: date) - 1 // Sunday = 0
    }

    private static func hhmmToMinutes(_ hhmm: String) -> Int? {
        let trimmed = hhmm.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
