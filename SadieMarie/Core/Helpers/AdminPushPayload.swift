import Foundation

/// Parses custom keys from an APNs `userInfo` dictionary.
enum AdminPushPayload {
    static func appointmentId(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("appointmentId", from: userInfo)
    }

    static func bookingUid(from userInfo: [AnyHashable: Any]) -> String? {
        stringValue("bookingUid", from: userInfo)
    }

    /// True for the admin “new booking confirmed” payload (not a pending hold).
    static func isConfirmedBookingPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        appointmentId(from: userInfo) != nil || bookingUid(from: userInfo) != nil
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
