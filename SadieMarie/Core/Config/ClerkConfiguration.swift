import Foundation

/// App environment label, sourced from `APP_ENV` (Info.plist or
/// process env). Currently informational — surfaces in logs and lets
/// you branch on environment if you ever need to (e.g. point Sentry
/// at a different DSN per environment).
enum AppEnvironment: String, CaseIterable {
    case development
    case staging
    case production
}

enum ClerkConfigurationError: LocalizedError {
    case missingPublishableKey
    case placeholderPublishableKey
    case invalidPublishableKey(String)

    var errorDescription: String? {
        switch self {
        case .missingPublishableKey:
            return "Missing CLERK_PUBLISHABLE_KEY in Info.plist."
        case .placeholderPublishableKey:
            return "CLERK_PUBLISHABLE_KEY is still set to the placeholder. Replace it with the value from your Clerk Dashboard."
        case .invalidPublishableKey(let value):
            return "CLERK_PUBLISHABLE_KEY is malformed: \(value). Expected a key starting with `pk_test_` or `pk_live_`."
        }
    }
}

/// Resolved configuration consumed by `Clerk.configure(...)` at app
/// launch. The publishable key is non-secret by design — Clerk
/// publishes it to web/mobile clients and authentication relies on
/// short-lived session tokens, not the key itself — so storing it in
/// `Info.plist` is appropriate.
struct ClerkConfiguration {
    let publishableKey: String
    let environment: AppEnvironment

    /// Sentinel left in `Info.plist` so a fresh checkout never starts
    /// with someone else's key by accident. The loader rejects it.
    static let placeholderKey = "pk_test_REPLACE_ME"

    static func load(
        bundle: Bundle = .main,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ClerkConfiguration {
        let rawKey = (processEnvironment["CLERK_PUBLISHABLE_KEY"]?.trimmedNonEmpty)
            ?? (bundle.object(forInfoDictionaryKey: "CLERK_PUBLISHABLE_KEY") as? String)?.trimmedNonEmpty

        guard let rawKey else {
            throw ClerkConfigurationError.missingPublishableKey
        }
        guard rawKey != Self.placeholderKey else {
            throw ClerkConfigurationError.placeholderPublishableKey
        }
        guard rawKey.hasPrefix("pk_test_") || rawKey.hasPrefix("pk_live_") else {
            throw ClerkConfigurationError.invalidPublishableKey(rawKey)
        }

        let envRaw = (processEnvironment["APP_ENV"]?.trimmedNonEmpty)
            ?? (bundle.object(forInfoDictionaryKey: "APP_ENV") as? String)?.trimmedNonEmpty
            ?? "production"
        let environment = AppEnvironment(rawValue: envRaw.lowercased()) ?? .production

        return ClerkConfiguration(
            publishableKey: rawKey,
            environment: environment
        )
    }
}

private extension String {
    /// Returns `nil` for empty / whitespace-only strings; otherwise the
    /// trimmed value. Lets the loader treat blank Info.plist entries
    /// the same as missing entries.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
