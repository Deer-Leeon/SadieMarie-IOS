import SwiftUI
import Foundation
import Observation

/// Global, observable application state. Inject through the SwiftUI
/// environment (`.environment(appState)`) and read with
/// `@Environment(AppState.self) private var appState`.
///
/// Keep this type lean and session-scoped. Anything that should not
/// survive a sign-out belongs here so `resetForSignOut()` can clear
/// it in one place. Auth itself is owned by Clerk — observe
/// `clerk.user` directly in views rather than mirroring it here.
/// Live CRM no-show-flag patch so Bookings can update calendar pills
/// immediately when the flag is cleared (or re-set) from Clients or
/// an appointment profile sheet.
struct ClientNoShowFlagPatch: Equatable, Sendable {
    let phone: String?
    let email: String?
    let flag: Bool
    let revision: Int
}

@MainActor
@Observable
final class AppState {
    /// The reference "today" most screens treat as `Date()`. Held on
    /// `AppState` so debug builds (or feature flags) can pin it to a
    /// specific date for reproducible UI screenshots.
    var currentDate: Date = Date()

    /// Latest no-show-flag change observed in this session. Bookings
    /// watches `revision` and patches matching appointments in-memory.
    private(set) var lastNoShowFlagPatch: ClientNoShowFlagPatch?
    private var noShowFlagRevision = 0

    init() {}

    func noteClientNoShowFlag(phone: String?, email: String?, flag: Bool) {
        noShowFlagRevision += 1
        lastNoShowFlagPatch = ClientNoShowFlagPatch(
            phone: phone,
            email: email,
            flag: flag,
            revision: noShowFlagRevision
        )
    }

    /// Wipes all per-account in-memory state so the next signed-in
    /// account starts from a clean slate. Hook this to Clerk's
    /// `auth.events` (`.sessionChanged` with `newValue == nil`) when
    /// you start adding per-account caches that need to clear.
    func resetForSignOut() {
        currentDate = Date()
        lastNoShowFlagPatch = nil
        noShowFlagRevision = 0
    }
}
