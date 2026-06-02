import Foundation

/// Parsed US phone for CRM + Cal.com manual booking.
struct ParsedClientPhone: Equatable, Sendable {
    /// Digits only, usually 11 chars for US (`1` + 10-digit number).
    let digits: String
    /// E.164 for Cal.com (`+18015551234`).
    let e164: String
}

/// Test-facing name aligned with unit tests.
enum ClientPhoneParsing {
    static func parse(_ raw: String) -> ParsedClientPhone? {
        ClientPhone.parse(raw)
    }
}

enum ClientPhone {
    static let hint =
        "US mobile: 10 digits — we save it as +1 automatically for Cal.com (e.g. 801 555 1234)."

    static func validationMessage() -> String {
        "Enter a valid US phone: 10 digits, or +1 followed by 10 digits (e.g. +18015551234)."
    }

    /// Strict US 10/11-digit sanitation (mirrors `lib/client-phone.js`).
    static func parse(_ raw: String) -> ParsedClientPhone? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        if hasPlus {
            let e164 = "+\(digits)"
            guard e164.range(of: #"^\+[1-9]\d{6,14}$"#, options: .regularExpression) != nil else {
                return nil
            }
            return ParsedClientPhone(digits: digits, e164: e164)
        }

        if digits.count == 10 {
            return ParsedClientPhone(digits: "1\(digits)", e164: "+1\(digits)")
        }

        if digits.count == 11, digits.first == "1" {
            return ParsedClientPhone(digits: digits, e164: "+\(digits)")
        }

        return nil
    }

    static func formatInputDisplay(_ raw: String) -> String {
        guard let parsed = parse(raw) else { return raw.trimmingCharacters(in: .whitespacesAndNewlines) }

        let national: String
        if parsed.digits.count == 11, parsed.digits.first == "1" {
            national = String(parsed.digits.dropFirst())
        } else {
            national = parsed.digits
        }

        guard national.count == 10 else { return parsed.e164 }

        let area = national.prefix(3)
        let mid = national.dropFirst(3).prefix(3)
        let last = national.suffix(4)
        return "(\(area)) \(mid)-\(last)"
    }
}
