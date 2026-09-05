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

struct OverlapLaneFrame: Equatable {
    let leading: CGFloat
    let width: CGFloat
    let zIndex: Double
}

private struct RawPositioned {
    let appointment: Appointment
    let topPct: Double
    let heightPct: Double
    let startMin: Int
    let endMin: Int
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
                && !appointment.isAttachedExtra
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

        var raw: [RawPositioned] = []
        for appointment in appointments {
            guard
                let start = safeParseISO(appointment.bookingTime),
                calendar.isDate(start, inSameDayAs: day),
                let position = position(for: appointment)
            else {
                continue
            }
            let end = safeParseISO(appointment.endTime)
                ?? start.addingTimeInterval(60 * 60)
            let occupied = occupiedMinutes(start: start, end: end)
            raw.append(
                RawPositioned(
                    appointment: appointment,
                    topPct: position.topPct,
                    heightPct: position.heightPct,
                    startMin: occupied.startMin,
                    endMin: occupied.endMin
                )
            )
        }
        return packLanes(raw)
    }

    /// Occupied range as `[startMinute, endMinute)`. Flooring swallows
    /// sub-minute Cal/Postgres jitter so a 12:00:00.400 end does not
    /// collide with a 12:00:00.000 start.
    private static func occupiedMinutes(start: Date, end: Date) -> (startMin: Int, endMin: Int) {
        let startMin = Int(floor(start.timeIntervalSince1970 / 60))
        var endMin = Int(floor(end.timeIntervalSince1970 / 60))
        if endMin <= startMin {
            endMin = startMin + 1
        }
        return (startMin, endMin)
    }

    private static func minutesOverlap(_ a: RawPositioned, _ b: RawPositioned) -> Bool {
        a.startMin < b.endMin && b.startMin < a.endMin
    }

    /// Pack into horizontal lanes, scoped per overlap cluster.
    /// Touching bookings (2:30 / 2:30) do not overlap. Appointments that
    /// overlap nobody else stay full-width even inside a larger cluster.
    private static func packLanes(_ raw: [RawPositioned]) -> [PositionedAppointment] {
        guard !raw.isEmpty else { return [] }

        let sorted = raw.sorted { a, b in
            if a.startMin != b.startMin { return a.startMin < b.startMin }
            return a.endMin > b.endMin
        }

        var parent = Array(sorted.indices)
        func find(_ i: Int) -> Int {
            var root = i
            while parent[root] != root { root = parent[root] }
            var cur = i
            while parent[cur] != root {
                let next = parent[cur]
                parent[cur] = root
                cur = next
            }
            return root
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a)
            let rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in sorted.indices {
            var j = i + 1
            while j < sorted.count {
                if sorted[j].startMin >= sorted[i].endMin { break }
                if minutesOverlap(sorted[i], sorted[j]) {
                    union(i, j)
                }
                j += 1
            }
        }

        var clusters: [Int: [Int]] = [:]
        for i in sorted.indices {
            clusters[find(i), default: []].append(i)
        }

        var out = Array(repeating: Optional<PositionedAppointment>.none, count: sorted.count)

        for memberIdxs in clusters.values {
            let members = memberIdxs.sorted { a, b in
                if sorted[a].startMin != sorted[b].startMin {
                    return sorted[a].startMin < sorted[b].startMin
                }
                return sorted[a].endMin > sorted[b].endMin
            }

            var lanes: [Int] = []
            var colByMember: [Int] = []

            for idx in members {
                let item = sorted[idx]
                var placed = false
                for lane in lanes.indices {
                    if lanes[lane] <= item.startMin {
                        lanes[lane] = item.endMin
                        colByMember.append(lane)
                        placed = true
                        break
                    }
                }
                if !placed {
                    lanes.append(item.endMin)
                    colByMember.append(lanes.count - 1)
                }
            }

            let totalCols = max(lanes.count, 1)
            for (memberOrder, idx) in members.enumerated() {
                let item = sorted[idx]
                let overlapsAnyone = members.enumerated().contains { otherOrder, otherIdx in
                    otherOrder != memberOrder && minutesOverlap(item, sorted[otherIdx])
                }
                out[idx] = PositionedAppointment(
                    appointment: item.appointment,
                    topPct: item.topPct,
                    heightPct: item.heightPct,
                    col: overlapsAnyone ? colByMember[memberOrder] : 0,
                    totalCols: overlapsAnyone ? totalCols : 1
                )
            }
        }

        return out.compactMap { $0 }
    }

    /// Equal-width columns for daily view: overlapping pills sit next to
    /// each other with a hairline gap (Fresha 1-day). 3-day / week use cascade.
    static func columnLaneFrame(
        col: Int,
        totalCols: Int,
        columnWidth: CGFloat,
        outer: CGFloat? = nil,
        gap: CGFloat? = nil
    ) -> OverlapLaneFrame {
        let n = max(totalCols, 1)
        let i = min(max(col, 0), n - 1)
        let overlapping = n > 1
        let outerPx = outer ?? (overlapping ? 2 : 8)
        let gapPx = gap ?? (overlapping ? 2 : 0)
        let innerGaps = CGFloat(n - 1) * gapPx
        let laneWidth = max((columnWidth - outerPx * 2 - innerGaps) / CGFloat(n), 8)
        let leading = outerPx + CGFloat(i) * (laneWidth + gapPx)
        return OverlapLaneFrame(
            leading: leading,
            width: laneWidth,
            zIndex: 20
        )
    }

    /// Fresha-style cascade: later overlapping pills indent and sit on top,
    /// leaving a tappable strip of the booking underneath.
    static func cascadeLaneFrame(
        col: Int,
        totalCols: Int,
        columnWidth: CGFloat,
        indent: CGFloat = 14,
        outer: CGFloat? = nil
    ) -> OverlapLaneFrame {
        let n = max(totalCols, 1)
        let i = min(max(col, 0), n - 1)
        let overlapping = n > 1
        let outerPx = outer ?? (overlapping ? 1 : 2)
        if !overlapping {
            return OverlapLaneFrame(
                leading: outerPx,
                width: max(columnWidth - outerPx * 2, 8),
                zIndex: 20
            )
        }
        let leading = CGFloat(i) * indent + outerPx
        return OverlapLaneFrame(
            leading: leading,
            width: max(columnWidth - leading - outerPx, 8),
            zIndex: 20 + Double(i)
        )
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
