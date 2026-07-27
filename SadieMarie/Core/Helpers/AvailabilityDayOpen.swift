import Foundation

/// Whether a calendar day is a working day per weekly blocks + date overrides.
enum AvailabilityDayOpen {
    static func isOpenWorkingDay(response: AvailabilityResponse, on date: Date) -> Bool {
        let iso = AvailabilityTimeFormat.yyyyMMdd(from: date)

        if let override = response.overrides.first(where: { $0.date == iso }) {
            if override.isUnavailableAllDay {
                return false
            }
            return true
        }

        let weekdayIndex = AvailabilityTimeFormat.calendar.component(.weekday, from: date) - 1
        return response.schedule.availability.contains { block in
            block.days.contains(weekdayIndex)
        }
    }
}
