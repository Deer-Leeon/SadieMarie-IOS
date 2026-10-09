import Foundation
import UIKit
import BackgroundTasks
import ClerkKit

/// Keeps the Clerk session warm and the APNs token registered so booking
/// alerts survive days of not opening the app. Token is removed only on
/// explicit Log Out — never on a failed refresh or a backgrounded app.
enum SessionKeepAlive {
    static let refreshTaskId = "co.sadiemarie.admin.session-refresh"

    @MainActor
    private static var inFlight: Task<Void, Never>?

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
    /// Concurrent callers share one in-flight run so sign-in doesn't race
    /// `setActive` against the first calendar fetch.
    @MainActor
    static func run() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { @MainActor in
            await performRun()
        }
        inFlight = task
        await task.value
        if inFlight == task {
            inFlight = nil
        }
    }

    /// Finish session touch + JWT before the first admin API calls after login.
    @MainActor
    static func waitUntilReadyForAPI() async {
        await run()
        _ = try? await AdminAPIClient.clerkSessionToken()
    }

    /// How long to wait for Clerk to put the session back after a resume.
    private static let sessionAppearTimeout: TimeInterval = 3

    @MainActor
    private static func performRun() async {
        UIApplication.shared.registerForRemoteNotifications()
        await waitForReappearingSession()

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

    /// A resume can observe a nil session for a moment while Clerk is still
    /// signed in. Wait briefly instead of failing the first request. A real
    /// sign-out (`isLoaded` and no user) does not wait.
    @MainActor
    private static func waitForReappearingSession() async {
        guard Clerk.shared.session == nil else { return }
        let stillSignedIn = !Clerk.shared.isLoaded || Clerk.shared.user != nil
        guard stillSignedIn else { return }
        let deadline = Date().addingTimeInterval(sessionAppearTimeout)
        while Clerk.shared.session == nil, Date() < deadline, !Task.isCancelled {
            if Clerk.shared.isLoaded, Clerk.shared.user == nil { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
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
