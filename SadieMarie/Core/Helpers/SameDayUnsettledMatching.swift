import Foundation

/// Same-day unpaid visits for one client, derived from appointments already
/// loaded in the calendar / client history. Used so Charge / Cash / Comp can
/// list siblings even when the sibling API is unreachable.
enum SameDayUnsettledMatching {
    static func visits(
        of appointment: Appointment,
        among appointments: [Appointment]
    ) -> [SameDayUnsettledVisit] {
        appointments.compactMap { candidate -> SameDayUnsettledVisit? in
            guard candidate.id != appointment.id else { return nil }
            guard BookingDisplay.isConfirmed(candidate) else { return nil }
            guard candidate.terminalPayment?.isSettled != true else { return nil }
            guard candidate.terminalPayment?.isActiveTerminalPayment != true else {
                return nil
            }
            guard isSameStudioDay(appointment, candidate) else { return nil }
            guard isSameClient(appointment, candidate) else { return nil }
            return SameDayUnsettledVisit(appointment: candidate)
        }
        .sorted { lhs, rhs in
            (lhs.bookingTime ?? "") < (rhs.bookingTime ?? "")
        }
    }

    static func preferRemote(
        _ remote: [SameDayUnsettledVisit],
        local: [SameDayUnsettledVisit]
    ) -> [SameDayUnsettledVisit] {
        guard !remote.isEmpty else { return local }
        let localById = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        return remote.map { visit in
            guard let fallback = localById[visit.id] else { return visit }
            return visit.replacingUnparseableTimes(from: fallback)
        }
    }

    private static func isSameStudioDay(_ a: Appointment, _ b: Appointment) -> Bool {
        guard
            let aISO = a.bookingTime,
            let bISO = b.bookingTime,
            let aDate = BookingDisplay.iso8601Date(from: aISO),
            let bDate = BookingDisplay.iso8601Date(from: bISO)
        else { return false }
        return StudioTime.yyyyMMdd(from: aDate) == StudioTime.yyyyMMdd(from: bDate)
    }

    private static func isSameClient(_ a: Appointment, _ b: Appointment) -> Bool {
        if a.belongsToClient(phone: b.clientPhone, email: b.clientEmail) {
            return true
        }
        let aName = displayName(a)
        let bName = displayName(b)
        return !aName.isEmpty && aName == bName
    }

    private static func displayName(_ appointment: Appointment) -> String {
        let first = (appointment.clientFirstName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let last = (appointment.clientLastName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }
}

extension SameDayUnsettledVisit {
    init(appointment: Appointment) {
        self.init(
            id: appointment.id,
            bookingTime: appointment.bookingTime,
            endTime: appointment.endTime,
            serviceName: appointment.serviceName,
            quotedServicePriceCents: nil,
            servicePrice: appointment.servicePrice
        )
    }

    func replacingUnparseableTimes(from other: SameDayUnsettledVisit) -> SameDayUnsettledVisit {
        SameDayUnsettledVisit(
            id: id,
            bookingTime: parseableTime(bookingTime) ? bookingTime : other.bookingTime,
            endTime: parseableTime(endTime) ? endTime : other.endTime,
            serviceName: serviceName,
            quotedServicePriceCents: quotedServicePriceCents,
            servicePrice: servicePrice
        )
    }

    private func parseableTime(_ raw: String?) -> Bool {
        guard let raw, let _ = BookingDisplay.iso8601Date(from: raw) else {
            return false
        }
        return true
    }
}
