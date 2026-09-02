import UIKit
import UserNotifications
import BackgroundTasks

/// UIKit bridge for APNs token callbacks and notification presentation.
/// Wired via `UIApplicationDelegateAdaptor` on `SadieMarieApp`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        SessionKeepAlive.registerBackgroundTask()
        Self.applyLightTabBarAppearance()
        Self.applyLaunchWindowBackground()
        // Ask Apple for a token on every launch so rotations are never missed,
        // even before Clerk finishes hydrating the cached session.
        application.registerForRemoteNotifications()
        return true
    }

    /// Launch screens cannot read asset-catalog colors (they fall back to
    /// white). Paint every window with the logo cream so the handoff matches.
    private static func applyLaunchWindowBackground() {
        let cream = UIColor(red: 244 / 255, green: 243 / 255, blue: 239 / 255, alpha: 1)
        UIWindow.appearance().backgroundColor = cream
    }

    /// Keep the floating tab bar in light mode without a reserved
    /// opaque strip under the pill (that gap made every tab look truncated).
    private static func applyLightTabBarAppearance() {
        let stone900 = UIColor(red: 28 / 255, green: 25 / 255, blue: 23 / 255, alpha: 1)
        let stone500 = UIColor(red: 120 / 255, green: 113 / 255, blue: 108 / 255, alpha: 1)

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]
        for item in itemAppearances {
            item.normal.iconColor = stone500
            item.normal.titleTextAttributes = [.foregroundColor: stone500]
            item.selected.iconColor = stone900
            item.selected.titleTextAttributes = [.foregroundColor: stone900]
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.overrideUserInterfaceStyle = .light
        tabBar.isTranslucent = true
        tabBar.tintColor = stone900
        tabBar.unselectedItemTintColor = stone500
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushRegistration.shared.didReceiveDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushRegistration.shared.didFailToRegister(error: error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        await MainActor.run {
            PushRegistration.shared.handleIncomingBookingPush(userInfo: userInfo)
        }
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            PushRegistration.shared.handleNotificationTap(userInfo: userInfo)
        }
    }

    /// `content-available` wake so the calendar can refetch while the app
    /// is backgrounded. Also refreshes the Clerk session + APNs token.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await SessionKeepAlive.run()
            if AdminPushPayload.isConfirmedBookingPush(userInfo) {
                PushRegistration.shared.handleIncomingBookingPush(userInfo: userInfo)
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }
    }
}
