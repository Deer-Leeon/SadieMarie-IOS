import Foundation

extension Appointment {
    /// True when this row is catalogue work nested under a calendar visit.
    var isAttachedExtra: Bool {
        guard let attachedToAppointmentId, !attachedToAppointmentId.isEmpty else {
            return false
        }
        return true
    }

    var quotedCents: Int {
        TerminalDiscount.quotedCents(fromServicePrice: servicePrice)
    }

    var unpaidExtras: [Appointment] {
        extras.filter { extra in
            BookingDisplay.isConfirmed(extra) && extra.terminalPayment?.isSettled != true
        }
    }

    static func extraDuringVisitLabel(count: Int) -> String {
        guard count > 0 else { return "" }
        return count == 1
            ? "1 extra during this visit."
            : "\(count) extras during this visit."
    }
}

struct ChargeLine: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let cents: Int
    let detail: String?
}

enum AppointmentChargePlan {
    static func unpaidItems(for appointment: Appointment) -> [Appointment] {
        let extras = appointment.unpaidExtras
        if appointment.terminalPayment?.isSettled == true {
            return extras
        }
        return [appointment] + extras
    }

    static func lines(for appointment: Appointment) -> [ChargeLine] {
        let items = unpaidItems(for: appointment)
        return items.map { item in
            let isExtra = item.isAttachedExtra
            let detail: String?
            if items.count == 1 && !isExtra {
                detail = nil
            } else if isExtra {
                detail = "Extra · during this visit"
            } else {
                detail = "Scheduled service"
            }
            return ChargeLine(
                id: item.id,
                label: BookingDisplay.appointmentServiceLabel(item),
                cents: item.quotedCents,
                detail: detail
            )
        }
    }

    static func chargeTargetId(for appointment: Appointment) -> String {
        if appointment.terminalPayment?.isSettled == true {
            return appointment.unpaidExtras.first?.id ?? appointment.id
        }
        return appointment.id
    }

    static func forcedAdditionalIds(for appointment: Appointment) -> [String] {
        let extras = appointment.unpaidExtras
        if appointment.terminalPayment?.isSettled == true {
            return Array(extras.dropFirst().map(\.id))
        }
        return extras.map(\.id)
    }
}
