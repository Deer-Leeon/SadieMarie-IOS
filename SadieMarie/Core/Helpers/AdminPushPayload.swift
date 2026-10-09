import Foundation

/// Parses custom keys from an APNs `userInfo` dictionary.
enum AdminPushPayload {
    static func appointmentId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("appointmentId", from: userInfo)
    }

    static func bookingUid(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("bookingUid", from: userInfo)
    }

    static func clientId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("clientId", from: userInfo)
    }

    static func kind(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("kind", from: userInfo)
    }

    /// True for the admin “new booking confirmed” payload (not a pending hold).
    static func isConfirmedBookingPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        if isConsentSignedPush(userInfo) { return false }
        return appointmentId(from: userInfo) != nil || bookingUid(from: userInfo) != nil
    }

    /// Signed intake form. The banner is the APNs alert; this flag is for the tap.
    static func isConsentSignedPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        kind(from: userInfo) == "consent_signed"
    }

    static func hexDeviceToken(_ deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    private static func stringValue(_ key: String, from userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = userInfo[key] as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}
