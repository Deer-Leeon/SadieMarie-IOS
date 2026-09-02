import Foundation
import UIKit
import UserNotifications
import ClerkKit
import Observation

/// Always-on APNs registration for new-booking alerts.
/// Requests permission and upserts the device token whenever a Clerk
/// session is active. Unregisters only on explicit Log Out.
@MainActor
@Observable
final class PushRegistration {
    static let shared = PushRegistration()

    private static let tokenDefaultsKey = "adminPushDeviceToken"

    /// True when iOS notification authorization is anything other than
    /// `.authorized` — Bookings shows a persistent Open Settings banner.
    private(set) var needsSystemSettings: Bool = false

    /// Appointment to open after a notification tap. Bookings consumes this.
    var pendingOpenAppointmentId: String?

    /// Bumped when Bookings / Clients should refetch (new-booking push, app
    /// foreground). Views observe this instead of waiting for a tab switch.
    private(set) var liveDataRevision: Int = 0

    private init() {}

    func consumePendingOpenAppointmentId() -> String? {
        let id = pendingOpenAppointmentId
        pendingOpenAppointmentId = nil
        return id
    }

    func requestLiveDataRefresh() {
        liveDataRevision += 1
    }

    /// Banner arrived while the app is open — refresh the calendar immediately.
    /// Does not open the appointment sheet.
    func handleIncomingBookingPush(userInfo: [AnyHashable: Any]) {
        guard AdminPushPayload.isConfirmedBookingPush(userInfo) else { return }
        requestLiveDataRefresh()
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        pendingOpenAppointmentId = AdminPushPayload.appointmentId(from: userInfo)
        if AdminPushPayload.isConfirmedBookingPush(userInfo) {
            requestLiveDataRefresh()
        }
    }

    func didReceiveDeviceToken(_ deviceToken: Data) async {
        let hex = AdminPushPayload.hexDeviceToken(deviceToken)
        guard hex.count >= 64 else { return }
        UserDefaults.standard.set(hex, forKey: Self.tokenDefaultsKey)
        await postToken(hex)
    }

    func didFailToRegister(error: Error) {
        AppLogger.syncError("APNs registration failed: \(error.localizedDescription)")
    }

    /// Request permission, register with Apple, and upsert the token.
    /// Safe to call on every foreground while signed in.
    func syncIfSignedIn() async {
        guard Clerk.shared.session != nil else { return }

        await refreshAuthorizationBanner()

        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLogger.syncError("Notification permission request failed: \(error.localizedDescription)")
        }

        await refreshAuthorizationBanner()

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            return
        }

        UIApplication.shared.registerForRemoteNotifications()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)

        if let stored = storedToken() {
            await postToken(stored)
        }
    }

    /// DELETE the token while the Clerk session is still valid, then
    /// unregister with Apple. Call this *before* `clerk.auth.signOut()`.
    func unregisterOnLogout() async {
        if let stored = storedToken() {
            do {
                try await AdminAPIClient.shared.unregisterPushDevice(deviceToken: stored)
            } catch {
                AppLogger.syncError("Push token unregister failed: \(error.localizedDescription)")
            }
        }
        UIApplication.shared.unregisterForRemoteNotifications()
        UserDefaults.standard.removeObject(forKey: Self.tokenDefaultsKey)
        needsSystemSettings = false
        pendingOpenAppointmentId = nil
        liveDataRevision = 0
    }

    private func refreshAuthorizationBanner() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        needsSystemSettings = settings.authorizationStatus != .authorized
    }

    private func storedToken() -> String? {
        let value = UserDefaults.standard.string(forKey: Self.tokenDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.count >= 64 ? value.lowercased() : nil
    }

    private func postToken(_ hex: String) async {
        guard Clerk.shared.session != nil else { return }
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return }
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif

        var delayNanos: UInt64 = 400_000_000
        for attempt in 1...4 {
            do {
                try await AdminAPIClient.shared.registerPushDevice(
                    deviceToken: hex.lowercased(),
                    bundleId: bundleId,
                    environment: environment
                )
                return
            } catch let error as AdminAPIError where error.isNonRetryableAuthFailure {
                AppLogger.syncError("Push token register rejected: \(error.localizedDescription)")
                return
            } catch {
                AppLogger.syncError(
                    "Push token register failed (attempt \(attempt)/4): \(error.localizedDescription)"
                )
                guard attempt < 4 else { return }
                try? await Task.sleep(nanoseconds: delayNanos)
                delayNanos *= 2
            }
        }
    }
}
