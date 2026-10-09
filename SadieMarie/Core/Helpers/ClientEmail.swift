import Foundation

enum ClientEmail {
    static let validationMessage = "Enter a valid email address."

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when empty (optional) or a real, non-placeholder email.
    static func isValidOptional(_ raw: String) -> Bool {
        let email = normalized(raw)
        if email.isEmpty { return true }
        return isValidNonEmpty(email)
    }

    /// True only for a real, non-placeholder email (empty is invalid).
    static func isValid(_ raw: String) -> Bool {
        isValidNonEmpty(normalized(raw))
    }

    /// Normalized email when present and valid; `nil` when empty or invalid.
    static func validatedOptional(_ raw: String) -> String? {
        let email = normalized(raw)
        if email.isEmpty { return nil }
        return isValidNonEmpty(email) ? email : nil
    }

    /// Returns normalized email when valid and non-empty; otherwise `nil`.
    static func validated(_ raw: String) -> String? {
        validatedOptional(raw)
    }

    /// Display-safe email — blanks placeholders and invalid values.
    static func usableDisplay(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return validatedOptional(raw)
    }

    private static func isValidNonEmpty(_ email: String) -> Bool {
        guard !email.isEmpty, email.count <= 254 else { return false }
        if email.hasPrefix("bookings+") { return false }
        if email.hasSuffix("@placeholder.sadiemarie.co") { return false }
        if email.hasSuffix("@sms.cal.com") { return false }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

enum AdminAPIResponseParser {
    static func message(from body: String?, fallback: String) -> String {
        guard let body else { return fallback }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        if looksLikeHTML(trimmed) { return fallback }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return shorten(trimmed, fallback: fallback)
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return shorten(message, fallback: fallback)
        }
        return fallback
    }

    static func userFacingServerMessage(status _: Int, body: String?) -> String {
        message(
            from: body,
            fallback: "Couldn't load this right now. Please try again."
        )
    }

    static func clientEmailErrorMessage(from error: AdminAPIError) -> String {
        switch error {
        case .server(let status, let body) where status == 400:
            return message(from: body, fallback: ClientEmail.validationMessage)
        default:
            return (error as LocalizedError).errorDescription ?? error.localizedDescription
        }
    }

    static func userFacingMessage(from error: Error, fallback: String) -> String {
        if let api = error as? AdminAPIError {
            switch api {
            case .server(_, let body):
                return message(from: body, fallback: fallback)
            default:
                return api.localizedDescription
            }
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func looksLikeHTML(_ value: String) -> Bool {
        let head = String(value.prefix(200)).lowercased()
        return head.hasPrefix("<!")
            || head.hasPrefix("<html")
            || head.contains("<!doctype")
            || head.contains("<html")
            || head.contains("__next_error__")
    }

    private static func shorten(_ value: String, fallback: String) -> String {
        if looksLikeHTML(value) { return fallback }
        if value.count > 180 { return fallback }
        return value
    }
}
