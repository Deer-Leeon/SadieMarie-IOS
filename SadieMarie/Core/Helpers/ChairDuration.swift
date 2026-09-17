import Foundation

/// Chair-block math matching web `lib/chair-duration.ts`.
enum ChairDuration {
    static let stepMinutes = 15
    static let minMinutes = 15
    static let maxMinutes = 720

    static func snap(_ raw: Int) -> Int {
        let stepped = Int((Double(raw) / Double(stepMinutes)).rounded()) * stepMinutes
        return min(maxMinutes, max(minMinutes, stepped))
    }

    /// "45 min" / "1 hr" / "1 hr 45 min"
    static func formatLabel(_ mins: Int) -> String {
        let safe = max(0, mins)
        let hours = safe / 60
        let rest = safe % 60
        if hours <= 0 { return "\(rest) min" }
        if rest == 0 { return hours == 1 ? "1 hr" : "\(hours) hr" }
        return "\(hours) hr \(rest) min"
    }

    static func displayedMinutes(for appointment: Appointment) -> Int {
        if let chair = appointment.chairDurationMins, chair > 0 {
            return snap(chair)
        }
        return BookingDisplay.CalendarFormatting.durationMinutes(for: appointment) ?? stepMinutes
    }
}
