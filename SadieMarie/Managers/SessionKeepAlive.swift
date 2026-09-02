import Foundation
import UIKit
import BackgroundTasks
import ClerkKit

/// Keeps the Clerk session warm and the APNs token registered so booking
/// alerts survive days of not opening the app. Token is removed only on
/// explicit Log Out — never on a failed refresh or a backgrounded app.
enum SessionKeepAlive {
    static let refreshTaskId = "co.sadiemarie.admin.session-refresh"

    /// Register Apple's background-refresh slot. Call once at launch.
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskId,
            using: nil
        ) { task in
            handleAppRefresh(task as! BGAppRefreshTask)
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.syncError("Background refresh schedule failed: \(error.localizedDescription)")
        }
    }

    /// Touch the Clerk session (resets inactivity), refresh the JWT, and
    /// upsert the APNs token. Safe to call from launch, foreground, and
    /// background fetch. Never signs the user out on a network blip.
    @MainActor
    static func run() async {
        UIApplication.shared.registerForRemoteNotifications()

        guard let session = Clerk.shared.session else { return }

        do {
            try await Clerk.shared.auth.setActive(sessionId: session.id)
        } catch {
            AppLogger.authError("Session touch failed: \(error.localizedDescription)")
        }

        do {
            _ = try await session.getToken()
        } catch {
            AppLogger.authError("Session token refresh failed: \(error.localizedDescription)")
        }

        await PushRegistration.shared.syncIfSignedIn()
    }

    private static func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor in
            await run()
        }
        task.expirationHandler = { work.cancel() }
        Task {
            _ = await work.result
            task.setTaskCompleted(success: !work.isCancelled)
        }
    }
}
