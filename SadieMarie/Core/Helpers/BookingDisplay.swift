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

        guard isBare,
              let startISO = apt.bookingTime,
              let endISO = apt.endTime,
              let start = iso8601Date(from: startISO),
              let end = iso8601Date(from: endISO)
        else {
            return base
        }

        let mins = Int(round(end.timeIntervalSince(start) / 60))
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
        iso8601WithFractional.date(from: string) ?? iso8601Standard.date(from: string)
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
