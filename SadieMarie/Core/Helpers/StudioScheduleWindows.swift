import CoreGraphics
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

    struct MinuteBand: Hashable, Sendable {
        let startMins: Int
        let endMins: Int
    }

    static let gridStartMins = 9 * 60
    static let gridEndMins = 21 * 60

    /// Closed (unavailable) bands inside the visible 9 AM–9 PM grid.
    /// Official windows are light; `holes` (booked appointments) punch cream gaps.
    static func closedBands(
        forYMD ymd: String,
        availability: [ScheduleAvailabilityBlock],
        overrides: [ScheduleOverride],
        holes: [MinuteBand] = [],
        visibleStartMins: Int = gridStartMins,
        visibleEndMins: Int = gridEndMins
    ) -> [MinuteBand] {
        let openWindows = windows(forYMD: ymd, availability: availability, overrides: overrides)
        var open: [MinuteBand] = []
        for window in openWindows {
            guard let start = hhmmToMinutes(window.startTime),
                  let end = hhmmToMinutes(window.endTime),
                  end > start,
                  let clipped = clip(
                    MinuteBand(startMins: start, endMins: end),
                    gridStart: visibleStartMins,
                    gridEnd: visibleEndMins
                  ) else { continue }
            open.append(clipped)
        }
        let closed = invert(open, gridStart: visibleStartMins, gridEnd: visibleEndMins)
        let clippedHoles = holes.compactMap {
            clip($0, gridStart: visibleStartMins, gridEnd: visibleEndMins)
        }
        return subtract(closed, holes: clippedHoles)
    }

    static func minuteBand(from appointment: Appointment) -> MinuteBand? {
        guard let startISO = appointment.bookingTime,
              let start = BookingDisplay.iso8601Date(from: startISO) else {
            return nil
        }
        let end = appointment.endTime.flatMap { BookingDisplay.iso8601Date(from: $0) }
            ?? start.addingTimeInterval(3600)
        let calendar = StudioTime.calendar
        let startMins =
            calendar.component(.hour, from: start) * 60
            + calendar.component(.minute, from: start)
        var endMins =
            calendar.component(.hour, from: end) * 60
            + calendar.component(.minute, from: end)
        if endMins <= startMins {
            endMins = gridEndMins
        }
        return MinuteBand(startMins: startMins, endMins: endMins)
    }

    static func yOffset(forStartMins startMins: Int, hourHeight: CGFloat) -> CGFloat {
        let hoursFromGrid = CGFloat(startMins - gridStartMins) / 60
        return max(0, hoursFromGrid * hourHeight)
    }

    static func bandHeight(startMins: Int, endMins: Int, hourHeight: CGFloat) -> CGFloat {
        let hours = CGFloat(max(endMins - startMins, 0)) / 60
        return hours * hourHeight
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

    private static func clip(
        _ band: MinuteBand,
        gridStart: Int,
        gridEnd: Int
    ) -> MinuteBand? {
        let start = max(band.startMins, gridStart)
        let end = min(band.endMins, gridEnd)
        guard end > start else { return nil }
        return MinuteBand(startMins: start, endMins: end)
    }

    private static func merge(_ bands: [MinuteBand]) -> [MinuteBand] {
        let sorted = bands
            .filter { $0.endMins > $0.startMins }
            .sorted { lhs, rhs in
                if lhs.startMins != rhs.startMins { return lhs.startMins < rhs.startMins }
                return lhs.endMins < rhs.endMins
            }
        var out: [MinuteBand] = []
        for band in sorted {
            guard let last = out.last else {
                out.append(band)
                continue
            }
            if band.startMins > last.endMins {
                out.append(band)
            } else {
                out[out.count - 1] = MinuteBand(
                    startMins: last.startMins,
                    endMins: max(last.endMins, band.endMins)
                )
            }
        }
        return out
    }

    private static func invert(
        _ open: [MinuteBand],
        gridStart: Int,
        gridEnd: Int
    ) -> [MinuteBand] {
        let merged = merge(open)
        var closed: [MinuteBand] = []
        var cursor = gridStart
        for window in merged {
            if window.startMins > cursor {
                closed.append(MinuteBand(startMins: cursor, endMins: window.startMins))
            }
            cursor = max(cursor, window.endMins)
        }
        if cursor < gridEnd {
            closed.append(MinuteBand(startMins: cursor, endMins: gridEnd))
        }
        return closed
    }

    private static func subtract(
        _ closed: [MinuteBand],
        holes: [MinuteBand]
    ) -> [MinuteBand] {
        if holes.isEmpty { return closed }
        let mergedHoles = merge(holes)
        var out: [MinuteBand] = []
        for band in closed {
            var cursor = band.startMins
            for hole in mergedHoles {
                if hole.endMins <= cursor { continue }
                if hole.startMins >= band.endMins { break }
                let cutStart = max(hole.startMins, cursor)
                let cutEnd = min(hole.endMins, band.endMins)
                if cutStart > cursor {
                    out.append(MinuteBand(startMins: cursor, endMins: cutStart))
                }
                cursor = max(cursor, cutEnd)
            }
            if cursor < band.endMins {
                out.append(MinuteBand(startMins: cursor, endMins: band.endMins))
            }
        }
        return out
    }
}
