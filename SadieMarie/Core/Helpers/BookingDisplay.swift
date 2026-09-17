import Foundation
import SwiftUI

/// Display helpers ported from `app/admin/helpers.ts` and `serviceColors.ts`.
enum BookingDisplay {

    // MARK: - Naming

    static func clientDisplayName(first: String?, last: String?) -> String {
        let name = [first, last]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unknown client" : name
    }

    static func cleanServiceName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "Appointment" }

        if let range = name.range(
            of: #"\s+between\s+"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let cleaned = String(name[name.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? "Appointment" : cleaned
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Appointment" : trimmed
    }

    /// Mirrors `appointmentServiceLabel` — duration disambiguates Classic/Hybrid/Volume fills.
    static func appointmentServiceLabel(_ apt: Appointment) -> String {
        let base = cleanServiceName(apt.serviceName)
        let baseLower = base.lowercased()
        let isBare = ["classic", "hybrid", "volume"].contains(baseLower)

        guard isBare else { return base }

        let mins: Int?
        if let catalogue = apt.catalogueDurationMins, catalogue > 0 {
            mins = catalogue
        } else if let startISO = apt.bookingTime,
                  let endISO = apt.endTime,
                  let start = iso8601Date(from: startISO),
                  let end = iso8601Date(from: endISO) {
            mins = Int(round(end.timeIntervalSince(start) / 60))
        } else {
            mins = nil
        }

        guard let mins else { return base }
        switch mins {
        case 120: return "\(base) 2 Week Fill"
        case 150: return "\(base) 3 Week Fill"
        case 180: return "\(base) 4 Week Fill"
        default: return base
        }
    }

    // MARK: - Service color

    struct ServiceColor: Hashable {
        let accent: Color
        let text: Color
        let textMuted: Color
    }

    /// Parent + extra colours as a vertical fade (web `visitBlockBackground`).
    enum VisitBlockPaint {
        case solid(Color)
        case gradient(LinearGradient)

        var shapeStyle: AnyShapeStyle {
            switch self {
            case .solid(let color): AnyShapeStyle(color)
            case .gradient(let gradient): AnyShapeStyle(gradient)
            }
        }
    }

    static func visitBlockPaint(for apt: Appointment) -> VisitBlockPaint? {
        guard let parent = serviceColor(for: apt) else { return nil }
        let extras = apt.extras
        if extras.isEmpty {
            return .solid(parent.accent)
        }

        struct Segment {
            let color: Color
            let hex: String
            let weight: Double
        }

        func catalogueWeight(_ mins: Int?) -> Double {
            if let mins, mins > 0 { return Double(mins) }
            return 60
        }

        var segments: [Segment] = [
            Segment(
                color: parent.accent,
                hex: (apt.serviceColor ?? "").uppercased(),
                weight: catalogueWeight(apt.catalogueDurationMins)
            )
        ]
        for extra in extras {
            let color = serviceColor(for: extra)
            segments.append(
                Segment(
                    color: color?.accent ?? parent.accent,
                    hex: (extra.serviceColor ?? apt.serviceColor ?? "").uppercased(),
                    weight: catalogueWeight(extra.catalogueDurationMins)
                )
            )
        }

        let unique = Set(segments.map(\.hex).filter { !$0.isEmpty })
        if unique.count <= 1 {
            return .solid(segments[0].color)
        }

        let totalWeight = segments.reduce(0) { $0 + $1.weight }
        let blendPct = min(8, max(3, (6 / max(totalWeight, 1)) * 100))
        var stops: [Gradient.Stop] = []
        var cursor = 0.0
        for index in segments.indices {
            let seg = segments[index]
            let start = (cursor / totalWeight) * 100
            let end = ((cursor + seg.weight) / totalWeight) * 100
            if index + 1 >= segments.count {
                stops.append(Gradient.Stop(color: seg.color, location: start / 100))
                stops.append(Gradient.Stop(color: seg.color, location: 1))
            } else {
                let next = segments[index + 1]
                let half = min(blendPct, (end - start) / 2, (next.weight / totalWeight) * 100 / 2)
                stops.append(Gradient.Stop(color: seg.color, location: start / 100))
                stops.append(Gradient.Stop(color: seg.color, location: max(start, end - half) / 100))
                stops.append(Gradient.Stop(color: next.color, location: min(100, end + half) / 100))
            }
            cursor += seg.weight
        }

        let clamped = stops
            .map { Gradient.Stop(color: $0.color, location: min(1, max(0, $0.location))) }
            .sorted { $0.location < $1.location }

        return .gradient(
            LinearGradient(stops: clamped, startPoint: .top, endPoint: .bottom)
        )
    }

    static func serviceColor(for apt: Appointment) -> ServiceColor? {
        guard let hex = apt.serviceColor,
              hex.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil,
              let accent = Color(adminHex: hex)
        else {
            return nil
        }

        let blackText = ServiceColorContrast.usesBlackText(hex: hex)
        return ServiceColor(
            accent: accent,
            text: blackText ? .black : AdminTheme.onServiceColorText,
            textMuted: blackText
                ? Color.black.opacity(0.72)
                : AdminTheme.onServiceColorTextMuted
        )
    }

    /// Primary + secondary text for list rows and calendar blocks.
    ///
    /// Service-colored rows flip black/white from YIQ luminance
    /// (see `ServiceColorContrast`). Status chips use semantic
    /// colored pills. Neutral / no-show / pending rows use dark stone text.
    static func rowTextColors(for appointment: Appointment) -> (primary: Color, secondary: Color) {
        if usesServiceColorBackground(appointment),
           let colors = serviceColor(for: appointment) {
            return (colors.text, colors.textMuted)
        }
        if isPending(appointment) {
            return (AdminTheme.awaitingPaymentText, AdminTheme.stone700)
        }
        return (AdminTheme.stone900, AdminTheme.stone700)
    }

    // MARK: - Status presentation

    /// Lowercased status string for comparisons (matches web).
    static func normalizedStatus(_ apt: Appointment) -> String {
        (apt.status ?? "").lowercased()
    }

    static func isNoShow(_ apt: Appointment) -> Bool {
        normalizedStatus(apt) == AppointmentStatus.noShow.rawValue
    }

    static func isPending(_ apt: Appointment) -> Bool {
        normalizedStatus(apt) == AppointmentStatus.pending.rawValue
    }

    static func isConfirmed(_ apt: Appointment) -> Bool {
        normalizedStatus(apt) == AppointmentStatus.confirmed.rawValue
    }

    static func isCanceled(_ apt: Appointment) -> Bool {
        switch normalizedStatus(apt) {
        case AppointmentStatus.canceledByAdmin.rawValue,
             AppointmentStatus.canceledByClient.rawValue,
             AppointmentStatus.canceledByClientLate.rawValue,
             AppointmentStatus.canceledBySystem.rawValue,
             "cancelled":
            return true
        default:
            return false
        }
    }

    /// Client "Additional notes" only. Hides catalogue copy that Cal
    /// previously stored as booking notes.
    static func clientBookingNotes(for appointment: Appointment) -> String? {
        let notes = appointment.bookingNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !notes.isEmpty else { return nil }
        let description = appointment.serviceDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !description.isEmpty else { return notes }
        let compactNotes = notes.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        let compactDescription = description.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        if compactNotes.caseInsensitiveCompare(compactDescription) == .orderedSame {
            return nil
        }
        return notes
    }

    /// Closed bookings that should not be rescheduled or status-patched again
    /// (matches web `isAppointmentReadOnly`).
    static func isReadOnly(_ apt: Appointment) -> Bool {
        isNoShow(apt) || isCanceled(apt)
    }

    /// Confirmed rows with a valid CMS hex use full-row service coloring.
    static func usesServiceColorBackground(_ apt: Appointment) -> Bool {
        isConfirmed(apt) && serviceColor(for: apt) != nil
    }

    // MARK: - ISO 8601

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func iso8601Date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = iso8601WithFractional.date(from: trimmed)
            ?? iso8601Standard.date(from: trimmed) {
            return date
        }
        return postgresTimestampDate(from: trimmed)
    }

    /// Postgres `timestamptz::text` is often `2026-09-03 15:15:00+00`.
    private static func postgresTimestampDate(from string: String) -> Date? {
        var normalized = string
        if let space = normalized.firstIndex(of: " "), !normalized.contains("T") {
            normalized.replaceSubrange(space...space, with: "T")
        }
        if normalized.hasSuffix("+00") || normalized.hasSuffix("-00") {
            normalized = String(normalized.dropLast(3)) + "Z"
        } else if let match = normalized.range(
            of: #"[+-]\d{2}$"#,
            options: .regularExpression
        ) {
            let offset = String(normalized[match])
            normalized = String(normalized[..<match.lowerBound]) + offset + ":00"
        }
        return iso8601WithFractional.date(from: normalized)
            ?? iso8601Standard.date(from: normalized)
    }

    // MARK: - Formatted strings (list UI)

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static func formattedTime(for apt: Appointment) -> String {
        guard let iso = apt.bookingTime,
              let date = iso8601Date(from: iso) else {
            return "—"
        }
        return timeFormatter.string(from: date)
    }

    static func formattedDayHeader(for date: Date) -> String {
        dayHeaderFormatter.string(from: date)
    }

    // MARK: - Detail sheet formatting

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()

    private static let detailTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// `Weekday, Month d, yyyy` for the appointment detail time card.
    static func formattedDetailDate(for apt: Appointment) -> String {
        guard let iso = apt.bookingTime,
              let date = iso8601Date(from: iso) else {
            return "—"
        }
        return detailDateFormatter.string(from: date)
    }

    /// `h:mm a – h:mm a` for the appointment detail time card.
    static func formattedDetailTimeRange(for apt: Appointment) -> String {
        guard let startISO = apt.bookingTime,
              let start = iso8601Date(from: startISO) else {
            return "—"
        }
        let startText = detailTimeFormatter.string(from: start)
        guard let endISO = apt.endTime,
              let end = iso8601Date(from: endISO) else {
            return startText
        }
        return "\(startText) – \(detailTimeFormatter.string(from: end))"
    }

    static func formattedPrice(_ price: Double?) -> String? {
        guard let price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = price.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: price))
    }

    /// Formats Stripe-style integer cents as USD (e.g. 18500 → "$185").
    static func formattedCents(_ cents: Int, currency: String? = "USD") -> String {
        let dollars = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = (currency?.isEmpty == false) ? currency!.uppercased() : "USD"
        formatter.maximumFractionDigits = cents % 100 == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(dollars)"
    }

    static func settlementLabel(for payment: AppointmentPaymentSummary?) -> String? {
        guard let payment, payment.isSettled else { return nil }
        switch payment.paymentKind {
        case .servicePayment: return "Paid"
        case .cash: return "Cash"
        case .complimentary: return "Comped"
        }
    }

    static func settlementSystemImage(for payment: AppointmentPaymentSummary?) -> String {
        guard let payment else { return "checkmark" }
        switch payment.paymentKind {
        case .servicePayment: return "checkmark"
        case .cash: return "dollarsign"
        // Outline heart matches web Lucide `Heart` on calendar markers.
        case .complimentary: return "heart"
        }
    }

    /// Modal banner eyebrow (web `settlementLabel`) — rendered uppercase in UI.
    static func settlementBannerEyebrow(for payment: AppointmentPaymentSummary) -> String {
        switch payment.paymentKind {
        case .complimentary: return "Complimentary"
        case .cash: return "Paid cash"
        case .servicePayment: return "Paid in person"
        }
    }

    /// Modal banner supporting line under the eyebrow.
    static func settlementBannerSubtitle(for payment: AppointmentPaymentSummary) -> String {
        switch payment.paymentKind {
        case .complimentary:
            return "No charge · settled without payment"
        case .cash:
            let service = formattedCents(payment.baseAmountCents, currency: payment.currency)
            if payment.tipAmountCents > 0 {
                let tip = formattedCents(payment.tipAmountCents, currency: payment.currency)
                return "Service \(service) + \(tip) tip"
            }
            return "Service \(service) · Cash"
        case .servicePayment:
            let service = formattedCents(payment.baseAmountCents, currency: payment.currency)
            if payment.tipAmountCents > 0 {
                let tip = formattedCents(payment.tipAmountCents, currency: payment.currency)
                return "Service \(service) + \(tip) tip"
            }
            return "Service \(service) · No tip"
        }
    }

    /// Right-side amount in the settlement banner ("Comp" or "$70").
    static func settlementBannerAmount(for payment: AppointmentPaymentSummary) -> String {
        if payment.paymentKind == .complimentary {
            return "Comp"
        }
        return formattedCents(payment.totalAmountCents, currency: payment.currency)
    }

    /// Footer settled pill label (COMPED / CASH / PAID).
    static func settlementFooterPaidLabel(for payment: AppointmentPaymentSummary) -> String {
        switch payment.paymentKind {
        case .complimentary: return "Comped"
        case .cash: return "Cash"
        case .servicePayment: return "Paid"
        }
    }

    static func terminalFailureMessage(
        payment: AppointmentPaymentSummary?,
        fallback: String?
    ) -> String {
        payment?.failureMessage
            ?? fallback
            ?? "The payment could not be completed. Please try the reader again."
    }

    static func canRetryTerminalPayment(_ payment: AppointmentPaymentSummary?) -> Bool {
        payment?.isRetryableTerminalPayment == true
    }

    static func canUndoSettlement(_ payment: AppointmentPaymentSummary?) -> Bool {
        payment?.canUndo == true
    }

    /// 100% no-show fee in cents from a dollar service price (matches web `penaltyAmountCents`).
    static func noShowPenaltyCents(servicePriceDollars: Double) -> Int {
        guard servicePriceDollars > 0, servicePriceDollars.isFinite else { return 0 }
        return Int((servicePriceDollars * 100).rounded())
    }

    static func appointmentDurationMinutes(_ apt: Appointment) -> Int? {
        guard let startISO = apt.bookingTime,
              let endISO = apt.endTime,
              let start = iso8601Date(from: startISO),
              let end = iso8601Date(from: endISO) else {
            return nil
        }
        let mins = Int(round(end.timeIntervalSince(start) / 60))
        return mins > 0 ? mins : nil
    }

    struct DetailHeaderStatus {
        let label: String
        let color: Color
    }

    /// Modal header eyebrow — mirrors web `describeHeaderStatus`.
    static func detailHeaderStatus(for apt: Appointment) -> DetailHeaderStatus {
        switch normalizedStatus(apt) {
        case AppointmentStatus.canceledByAdmin.rawValue:
            return DetailHeaderStatus(label: "Cancelled by you", color: AdminTheme.rose600)
        case AppointmentStatus.canceledByClient.rawValue:
            return DetailHeaderStatus(label: "Cancelled by client", color: AdminTheme.awaitingPaymentText)
        case AppointmentStatus.canceledByClientLate.rawValue:
            return DetailHeaderStatus(label: "Late cancel (fee charged)", color: AdminTheme.awaitingPaymentText)
        case AppointmentStatus.noShow.rawValue:
            return DetailHeaderStatus(label: "No-show", color: AdminTheme.stone500)
        case AppointmentStatus.confirmed.rawValue:
            return DetailHeaderStatus(label: "Booking", color: AdminTheme.stone500)
        case AppointmentStatus.pending.rawValue:
            return DetailHeaderStatus(label: "Awaiting payment", color: AdminTheme.awaitingPaymentText)
        default:
            return DetailHeaderStatus(label: "Booking", color: AdminTheme.stone500)
        }
    }

    static func formatLifetimeSpend(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.0f", value)
    }

    static func bookingDate(for apt: Appointment) -> Date? {
        guard let iso = apt.bookingTime else { return nil }
        return iso8601Date(from: iso)
    }

    /// End of the visit; falls back to one hour after start when `endTime` is missing.
    static func appointmentEndDate(for apt: Appointment) -> Date? {
        if let endISO = apt.endTime, let end = iso8601Date(from: endISO) {
            return end
        }
        return bookingDate(for: apt)?.addingTimeInterval(3600)
    }

    /// Still in the chair, or not started yet.
    static func isUpcoming(_ apt: Appointment, now: Date = Date()) -> Bool {
        guard let end = appointmentEndDate(for: apt) else { return false }
        return end >= now
    }

    /// Groups visible appointments by calendar day (start of day), sorted ascending.
    static func groupedByDay(_ appointments: [Appointment]) -> [(day: Date, appointments: [Appointment])] {
        let calendar = Calendar.current
        var buckets: [Date: [Appointment]] = [:]

        for apt in appointments {
            guard let bookingDate = bookingDate(for: apt) else { continue }
            let day = calendar.startOfDay(for: bookingDate)
            buckets[day, default: []].append(apt)
        }

        return buckets
            .map { day, items in
                (
                    day: day,
                    appointments: items.sorted {
                        let d0 = bookingDate(for: $0) ?? .distantPast
                        let d1 = bookingDate(for: $1) ?? .distantPast
                        return d0 < d1
                    }
                )
            }
            .sorted { $0.day < $1.day }
    }
}
