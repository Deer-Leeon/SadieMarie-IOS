import Foundation

/// Shared geometry + overlap packing for 3-day / week grids and `SingleDayModal`.
/// Port of `app/admin/timeline.ts`.
enum TimelineEngine {
    static let startHour = 9
    static let endHour = 21
    static let hours = endHour - startHour
    static let minPillHeight: CGFloat = 22
    static let hourLabelColumnWidth: CGFloat = 60

    private static let totalVisibleMinutes: Double = Double(hours * 60)
}

// MARK: - Positioned model

struct PositionedAppointment: Identifiable, Hashable, Sendable {
    var id: String { appointment.id }
    let appointment: Appointment
    let topPct: Double
    let heightPct: Double
    let col: Int
    let totalCols: Int
}

// MARK: - Appointment filters

extension Array where Element == Appointment {
    /// List + single-day modal — excludes canceled; keeps pending and no-show.
    var visibleAppointments: [Appointment] {
        filter { appointment in
            let status = (appointment.status ?? "").lowercased()
            return status != AppointmentStatus.canceledByAdmin.rawValue
                && status != AppointmentStatus.canceledByClient.rawValue
                && status != AppointmentStatus.canceledByClientLate.rawValue
                && status != AppointmentStatus.canceledBySystem.rawValue
        }
    }

    /// 3-day / week grids — excludes pending and all canceled statuses.
    var calendarAppointments: [Appointment] {
        visibleAppointments.filter { appointment in
            (appointment.status ?? "").lowercased() != AppointmentStatus.pending.rawValue
        }
    }
}

// MARK: - Layout

extension TimelineEngine {
    static func safeParseISO(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return BookingDisplay.iso8601Date(from: iso)
    }

    /// Percentage top/height within the 9 AM – 9 PM window; `nil` if outside or invalid.
    static func position(for appointment: Appointment) -> (topPct: Double, heightPct: Double)? {
        guard let start = safeParseISO(appointment.bookingTime) else { return nil }

        let end = safeParseISO(appointment.endTime)
            ?? start.addingTimeInterval(60 * 60)

        let calendar = StudioTime.calendar
        let dayStart = calendar.startOfDay(for: start)
        guard
            let visibleStart = calendar.date(byAdding: .hour, value: startHour, to: dayStart),
            let visibleEnd = calendar.date(byAdding: .hour, value: endHour, to: dayStart)
        else {
            return nil
        }

        let startMs = max(start.timeIntervalSince1970, visibleStart.timeIntervalSince1970)
        let endMs = min(end.timeIntervalSince1970, visibleEnd.timeIntervalSince1970)
        guard endMs > startMs else { return nil }

        let minutesFromVisibleStart = (startMs - visibleStart.timeIntervalSince1970) / 60
        let durationMinutes = (endMs - startMs) / 60

        let topPct = (minutesFromVisibleStart / totalVisibleMinutes) * 100
        let heightPct = (durationMinutes / totalVisibleMinutes) * 100
        return (topPct, heightPct)
    }

    /// Percentage top/height for an arbitrary interval within the visible day window.
    static func positionInterval(
        start: Date,
        end: Date,
        on day: Date,
        calendar: Calendar = .current
    ) -> (topPct: Double, heightPct: Double)? {
        let dayStart = calendar.startOfDay(for: day)
        guard
            let visibleStart = calendar.date(byAdding: .hour, value: startHour, to: dayStart),
            let visibleEnd = calendar.date(byAdding: .hour, value: endHour, to: dayStart)
        else {
            return nil
        }

        let startMs = max(start.timeIntervalSince1970, visibleStart.timeIntervalSince1970)
        let endMs = min(end.timeIntervalSince1970, visibleEnd.timeIntervalSince1970)
        guard endMs > startMs else { return nil }

        let minutesFromVisibleStart = (startMs - visibleStart.timeIntervalSince1970) / 60
        let durationMinutes = (endMs - startMs) / 60

        let topPct = (minutesFromVisibleStart / totalVisibleMinutes) * 100
        let heightPct = (durationMinutes / totalVisibleMinutes) * 100
        return (topPct, heightPct)
    }

    static func layoutBlocksForDay(date: Date, blocks: [TimeBlock]) -> [PositionedTimeBlock] {
        let calendar = StudioTime.calendar
        let day = calendar.startOfDay(for: date)

        return blocks.compactMap { block in
            guard
                let start = safeParseISO(block.startTime),
                calendar.isDate(start, inSameDayAs: day),
                let end = safeParseISO(block.endTime),
                let position = positionInterval(start: start, end: end, on: day, calendar: calendar)
            else {
                return nil
            }
            return PositionedTimeBlock(
                block: block,
                topPct: position.topPct,
                heightPct: position.heightPct
            )
        }
    }

    static func layoutForDay(date: Date, appointments: [Appointment]) -> [PositionedAppointment] {
        let calendar = StudioTime.calendar
        let day = calendar.startOfDay(for: date)

        var raw: [(appointment: Appointment, topPct: Double, heightPct: Double)] = []
        for appointment in appointments {
            guard
                let start = safeParseISO(appointment.bookingTime),
                calendar.isDate(start, inSameDayAs: day),
                let position = position(for: appointment)
            else {
                continue
            }
            raw.append((appointment, position.topPct, position.heightPct))
        }
        return packLanes(raw)
    }

  private static func packLanes(
        _ raw: [(appointment: Appointment, topPct: Double, heightPct: Double)]
    ) -> [PositionedAppointment] {
        let sorted = raw.sorted { $0.topPct < $1.topPct }
        var lanes: [Double] = []
        var colByIndex: [Int] = []

        for item in sorted {
            let start = item.topPct
            let end = item.topPct + item.heightPct
            var placed = false
            for index in lanes.indices {
                if lanes[index] <= start {
                    lanes[index] = end
                    colByIndex.append(index)
                    placed = true
                    break
                }
            }
            if !placed {
                lanes.append(end)
                colByIndex.append(lanes.count - 1)
            }
        }

        let totalCols = max(lanes.count, 1)
        return sorted.enumerated().map { index, item in
            PositionedAppointment(
                appointment: item.appointment,
                topPct: item.topPct,
                heightPct: item.heightPct,
                col: colByIndex[index],
                totalCols: totalCols
            )
        }
    }

    static func visibleDays(currentDate: Date, daysToShow: Int, calendar: Calendar = .current) -> [Date] {
        let anchor: Date
        if daysToShow >= 7 {
            anchor = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? calendar.startOfDay(for: currentDate)
        } else {
            anchor = calendar.startOfDay(for: currentDate)
        }
        return (0..<daysToShow).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: anchor)
        }
    }
}
