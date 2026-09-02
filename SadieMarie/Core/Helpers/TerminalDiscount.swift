import Foundation

/// Staff-selected amount overrides before a Stripe Terminal charge.
/// Tips are still collected on the reader against the charged base.
enum TerminalDiscount {
    static let percents: [Int] = [0, 10, 20, 50]
    /// Soft ceiling to catch typos — $10,000.
    static let customAmountMaxCents = 1_000_000
    /// Stripe card_present minimum.
    static let minimumChargeCents = 50

    static func apply(quotedCents: Int, percent: Int) -> Int {
        guard quotedCents >= 0 else { return 0 }
        guard percents.contains(percent), percent != 0 else { return max(0, quotedCents) }
        return Int((Double(quotedCents) * Double(100 - percent) / 100.0).rounded())
    }

    static func isValidCustomAmountCents(_ cents: Int) -> Bool {
        cents >= minimumChargeCents && cents <= customAmountMaxCents
    }

    /// Parse dollars input like "70", "70.5", "$70.00" into cents.
    static func parseDollarsToCents(_ raw: String) -> Int? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty else { return nil }
        let pattern = #"^\d+(\.\d{0,2})?$"#
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else { return nil }
        guard let dollars = Double(cleaned), dollars >= 0, dollars.isFinite else { return nil }
        return Int((dollars * 100.0).rounded())
    }

    static func formatCentsAsDollarInput(_ cents: Int) -> String {
        guard cents >= 0 else { return "" }
        if cents % 100 == 0 {
            return String(cents / 100)
        }
        return String(format: "%.2f", Double(cents) / 100.0)
    }

    static func quotedCents(fromServicePrice dollars: Double?) -> Int {
        guard let dollars, dollars.isFinite, dollars > 0 else { return 0 }
        return Int((dollars * 100.0).rounded())
    }
}

enum TerminalAmountMode: Equatable, Hashable, Sendable {
    case discount(percent: Int)
    case custom
}

struct TerminalStartRequest: Encodable, Sendable {
    var discountPercent: Int?
    var customAmountCents: Int?
    var additionalAppointmentIds: [String]?

    func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    static func discount(_ percent: Int, additionalAppointmentIds: [String] = []) -> TerminalStartRequest {
        TerminalStartRequest(
            discountPercent: percent,
            customAmountCents: nil,
            additionalAppointmentIds: additionalAppointmentIds.isEmpty ? nil : additionalAppointmentIds
        )
    }

    static func custom(cents: Int, additionalAppointmentIds: [String] = []) -> TerminalStartRequest {
        TerminalStartRequest(
            discountPercent: nil,
            customAmountCents: cents,
            additionalAppointmentIds: additionalAppointmentIds.isEmpty ? nil : additionalAppointmentIds
        )
    }
}
