import Foundation
import SwiftUI
import ClerkKit

/// Why a tab is fetching. A poll stays silent. Opening, resuming, and
/// pulling can leave a quiet note after retries run out.
enum RefreshReason: Equatable {
    case initial
    case resume
    case poll
    case user
}

/// What a failed refresh may say. The stale note fades. The empty-state
/// line stays until a load succeeds.
enum RefreshNotice: Equatable {
    case pullToTryAgain
    case couldntRefresh

    var message: String {
        switch self {
        case .pullToTryAgain:
            return "Pull to try again."
        case .couldntRefresh:
            return "Couldn’t refresh."
        }
    }
}

enum RefreshAttemptOutcome {
    case success
    case skipped
    case cancelled
    case failed(Error)
}

/// Retry budget and the notice shown after a tab refresh fails.
enum RefreshRecovery {
    static let retryBudget: TimeInterval = 8
    static let backoff: [TimeInterval] = [0.4, 0.8, 1.2, 1.6, 2.0]
    static let staleNoteDuration: Duration = .seconds(4)

    static func priority(_ reason: RefreshReason) -> Int {
        switch reason {
        case .poll: 0
        case .initial: 1
        case .resume: 2
        case .user: 3
        }
    }

    static func louder(_ current: RefreshReason, _ next: RefreshReason) -> RefreshReason {
        priority(next) >= priority(current) ? next : current
    }

    /// Missing session, expired token, a dropped connection, and a
    /// 408/429/5xx are worth another try. A deny, a missing route, and a
    /// bad payload are not.
    static func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        guard let api = error as? AdminAPIError else { return true }
        switch api {
        case .unauthorized, .noActiveSession, .transport, .unknown:
            return true
        case .server(let status, _):
            return status == 408 || status == 429 || (500...504).contains(status)
        case .forbidden, .notFound, .decoding, .invalidEndpoint, .invalidResponse:
            return false
        }
    }

    @MainActor
    static func isClerkSignedOut() -> Bool {
        Clerk.shared.isLoaded && Clerk.shared.user == nil
    }

    /// Polls stay quiet. A real sign-out leaves the screen and shows login.
    static func notice(
        hasSuccessfulLoad: Bool,
        reason: RefreshReason,
        isSignedOut: Bool
    ) -> RefreshNotice? {
        if isSignedOut || reason == .poll { return nil }
        return hasSuccessfulLoad ? .couldntRefresh : .pullToTryAgain
    }
}

/// Owns the fading stale note so a newer failure restarts the timer and a
/// pull-to-try-again line is not cleared by that timer.
@MainActor
final class RefreshNoticeController {
    private(set) var notice: RefreshNotice?
    private var generation = 0
    private var onChange: (@MainActor (RefreshNotice?) -> Void)?

    func bind(_ onChange: @escaping @MainActor (RefreshNotice?) -> Void) {
        self.onChange = onChange
    }

    func clear() {
        generation += 1
        set(.none)
    }

    func record(
        hasSuccessfulLoad: Bool,
        reason: RefreshReason,
        isSignedOut: Bool,
        fadeAfter: Duration = RefreshRecovery.staleNoteDuration
    ) {
        guard let next = RefreshRecovery.notice(
            hasSuccessfulLoad: hasSuccessfulLoad,
            reason: reason,
            isSignedOut: isSignedOut
        ) else { return }
        generation += 1
        set(next)
        guard next == .couldntRefresh else { return }
        let token = generation
        Task { @MainActor in
            try? await Task.sleep(for: fadeAfter)
            guard token == generation, notice == .couldntRefresh else { return }
            set(.none)
        }
    }

    private func set(_ notice: RefreshNotice?) {
        self.notice = notice
        onChange?(notice)
    }
}

/// One in-flight refresh per tab. A louder reason that arrives mid-poll
/// (opening the app while a one-minute poll is running) gets its own pass.
@MainActor
final class RefreshCoordinator {
    private let notices = RefreshNoticeController()
    private let inFlight = InFlightLoad()
    private var requestedReason: RefreshReason = .poll
    private var reasonRunning: RefreshReason = .poll
    private var lastOutcome: RefreshAttemptOutcome = .cancelled
    private(set) var hasSuccessfulLoad = false

    func noteExistingContent() {
        hasSuccessfulLoad = true
    }

    func load(
        reason: RefreshReason,
        applyNotice: @escaping @MainActor (RefreshNotice?) -> Void,
        perform: @escaping @MainActor () async -> RefreshAttemptOutcome
    ) async -> RefreshAttemptOutcome {
        notices.bind(applyNotice)
        if reason != .poll {
            await SessionKeepAlive.waitUntilReadyForAPI()
        }
        requestedReason = RefreshRecovery.louder(requestedReason, reason)
        await inFlight.run(againIf: { [weak self] in
            guard let self else { return false }
            return RefreshRecovery.priority(self.requestedReason)
                > RefreshRecovery.priority(self.reasonRunning)
        }) { [weak self] in
            await self?.run(perform: perform)
        }
        return lastOutcome
    }

    private func run(perform: () async -> RefreshAttemptOutcome) async {
        let reason = requestedReason
        reasonRunning = reason
        let outcome = await RefreshAttempt.run(reason: reason) {
            if RefreshRecovery.isClerkSignedOut() { return .cancelled }
            return await perform()
        }
        let louderWaiting = RefreshRecovery.priority(requestedReason) > RefreshRecovery.priority(reason)
        switch outcome {
        case .success:
            hasSuccessfulLoad = true
            notices.clear()
            lastOutcome = .success
        case .failed where !louderWaiting:
            notices.record(
                hasSuccessfulLoad: hasSuccessfulLoad,
                reason: reason,
                isSignedOut: RefreshRecovery.isClerkSignedOut()
            )
            lastOutcome = outcome
        case .cancelled, .skipped, .failed:
            if louderWaiting { return }
            lastOutcome = outcome
        }
        if RefreshRecovery.priority(requestedReason) > RefreshRecovery.priority(reason) {
            return
        }
        requestedReason = .poll
    }
}

@MainActor
enum RefreshAttempt {
    static func run(
        reason: RefreshReason,
        perform: () async -> RefreshAttemptOutcome
    ) async -> RefreshAttemptOutcome {
        if reason == .poll {
            return await perform()
        }
        let deadline = Date().addingTimeInterval(RefreshRecovery.retryBudget)
        var backoffIndex = 0
        var latest: RefreshAttemptOutcome = .cancelled
        while !Task.isCancelled {
            if RefreshRecovery.isClerkSignedOut() { return .cancelled }
            let outcome = await perform()
            switch outcome {
            case .success, .cancelled, .skipped:
                return outcome
            case .failed(let error):
                latest = outcome
                let remaining = deadline.timeIntervalSinceNow
                guard RefreshRecovery.isRetryable(error), remaining > 0 else {
                    return outcome
                }
                let delay = RefreshRecovery.backoff[min(backoffIndex, RefreshRecovery.backoff.count - 1)]
                backoffIndex += 1
                do {
                    try await Task.sleep(for: .seconds(min(delay, remaining)))
                } catch {
                    return .cancelled
                }
            }
        }
        return latest
    }
}

struct RefreshNoticeText: View {
    let notice: RefreshNotice

    var body: some View {
        Text(notice.message)
            .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
