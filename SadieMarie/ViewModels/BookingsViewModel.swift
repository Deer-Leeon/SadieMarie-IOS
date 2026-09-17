import Foundation
import Observation

/// Loads and holds the admin appointments list for the Bookings tab.
@MainActor
@Observable
final class BookingsViewModel {

    private(set) var appointments: [Appointment] = []
    private(set) var timeBlocks: [TimeBlock] = []
    private(set) var scheduleAvailability: [ScheduleAvailabilityBlock] = []
    private(set) var scheduleOverrides: [ScheduleOverride] = []
    /// False until a snapshot or live GET paints official hours (avoids all-gray flash).
    private(set) var hasSchedule = false
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isCreatingBlock = false
    private(set) var isUpdatingBlock = false
    private(set) var removingBlockId: String?
    private(set) var errorMessage: String?
    private let inFlightLoad = InFlightLoad()

    /// Keep the launch logo up while a sleeping backend wakes.
    private static let firstLoadRetryBudget: TimeInterval = 8
    private static let firstLoadBackoff: [TimeInterval] = [0.4, 0.8, 1.2, 1.6, 2.0]

    init() {
        seedScheduleFromSnapshotIfNeeded()
    }

    /// List + single-day modal — excludes canceled; keeps pending and no-show.
    var visibleAppointments: [Appointment] {
        appointments.visibleAppointments
    }

    /// 3-day / week grids — excludes pending and canceled.
    var calendarAppointments: [Appointment] {
        appointments.calendarAppointments
    }

    /// - Parameter showLoading: Full-screen overlay. Live sync (push / poll /
    ///   foreground) passes `false` so the calendar does not flash empty.
    func load(showLoading: Bool = true) async {
        let isInitial = !hasLoaded
        if isInitial {
            await SessionKeepAlive.waitUntilReadyForAPI()
        }
        let blockUI = showLoading && isInitial
        if blockUI {
            isLoading = true
            errorMessage = nil
        }

        await inFlightLoad.run { [weak self] in
            await self?.runLoad(isInitial: isInitial)
        }
        isLoading = false
    }

    private func runLoad(isInitial: Bool) async {
        if !isInitial || hasLoaded {
            _ = await performLoad(publishError: true)
            return
        }

        let deadline = Date().addingTimeInterval(Self.firstLoadRetryBudget)
        var backoffIndex = 0
        var lastError: Error?

        while !Task.isCancelled {
            let outcome = await performLoad(publishError: false)
            switch outcome {
            case .success:
                errorMessage = nil
                hasLoaded = true
                return
            case .cancelled:
                return
            case .failed(let error):
                lastError = error
                let retryable = Self.isRetryableColdStart(error)
                let remaining = deadline.timeIntervalSinceNow
                if !retryable || remaining <= 0 {
                    publishInitialLoadFailure(error)
                    hasLoaded = true
                    return
                }
                let delay = Self.firstLoadBackoff[min(backoffIndex, Self.firstLoadBackoff.count - 1)]
                backoffIndex += 1
                let sleepFor = min(delay, remaining)
                AppLogger.syncInfo(
                    "Initial bookings load retrying in \(String(format: "%.1f", sleepFor))s (\(error.localizedDescription))."
                )
                try? await Task.sleep(for: .seconds(sleepFor))
            }
        }

        if let lastError {
            publishInitialLoadFailure(lastError)
            hasLoaded = true
        }
    }

    private enum LoadOutcome {
        case success
        case cancelled
        case failed(Error)
    }

    private func performLoad(publishError: Bool) async -> LoadOutcome {
        seedScheduleFromSnapshotIfNeeded()
        async let scheduleResponse = fetchAvailabilityIgnoringErrors()

        do {
            async let bookingsResponse = AdminAPIClient.shared.fetchBookings()
            async let blocksResponse = AdminAPIClient.shared.fetchTimeBlocks()
            let response = try await bookingsResponse
            let blocks = try await blocksResponse
            if response.appointments != appointments {
                appointments = response.appointments
            }
            if blocks != timeBlocks {
                timeBlocks = blocks
            }
            errorMessage = nil
            AppLogger.syncInfo("Loaded \(appointments.count) appointments, \(blocks.count) time blocks.")
            applySchedule(await scheduleResponse)
            return .success
        } catch is CancellationError {
            return .cancelled
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            if publishError, appointments.isEmpty {
                errorMessage = message(for: error)
            }
            applySchedule(await scheduleResponse)
            return .failed(error)
        } catch {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            if publishError, appointments.isEmpty {
                errorMessage = error.localizedDescription
            }
            applySchedule(await scheduleResponse)
            return .failed(error)
        }
    }

    private func publishInitialLoadFailure(_ error: Error) {
        guard appointments.isEmpty else {
            errorMessage = nil
            return
        }
        if let apiError = error as? AdminAPIError {
            errorMessage = message(for: apiError)
        } else {
            errorMessage = error.localizedDescription
        }
    }

    private static func isRetryableColdStart(_ error: Error) -> Bool {
        if let apiError = error as? AdminAPIError {
            return apiError.isRetryableColdStart
        }
        return true
    }

    private func seedScheduleFromSnapshotIfNeeded() {
        guard !hasSchedule, let snapshot = AvailabilitySnapshotStore.load() else { return }
        applySchedule(snapshot)
    }

    private func applySchedule(_ response: AvailabilityResponse?) {
        guard let response else { return }
        if scheduleAvailability != response.schedule.availability {
            scheduleAvailability = response.schedule.availability
        }
        if scheduleOverrides != response.overrides {
            scheduleOverrides = response.overrides
        }
        hasSchedule = true
    }

    private func fetchAvailabilityIgnoringErrors() async -> AvailabilityResponse? {
        do {
            return try await AdminAPIClient.shared.fetchAvailability()
        } catch is CancellationError {
            return nil
        } catch {
            AppLogger.syncError("fetchAvailability failed: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func createTimeBlock(_ request: BlockTimeRequest) async -> Bool {
        isCreatingBlock = true
        errorMessage = nil
        defer { isCreatingBlock = false }

        let payload = TimeBlockCreateRequest(
            start: StudioTime.iso8601UTC(from: request.start),
            end: StudioTime.iso8601UTC(from: request.end),
            note: request.trimmedNote
        )

        do {
            let response = try await AdminAPIClient.shared.createTimeBlock(payload)
            timeBlocks.append(response.block)
            timeBlocks.sort { $0.startTime < $1.startTime }
            AppLogger.syncInfo("Created time block \(response.block.id).")
            return true
        } catch let error as AdminAPIError {
            AppLogger.syncError("createTimeBlock failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
            return false
        } catch {
            AppLogger.syncError("createTimeBlock failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateTimeBlock(_ block: TimeBlock, request: BlockTimeRequest) async -> Bool {
        isUpdatingBlock = true
        errorMessage = nil
        defer { isUpdatingBlock = false }

        let payload = TimeBlockUpdateRequest(
            start: StudioTime.iso8601UTC(from: request.start),
            end: StudioTime.iso8601UTC(from: request.end),
            note: request.trimmedNote
        )

        do {
            let response = try await AdminAPIClient.shared.updateTimeBlock(
                id: block.id,
                payload: payload
            )
            if let index = timeBlocks.firstIndex(where: { $0.id == block.id }) {
                timeBlocks[index] = response.block
            } else {
                timeBlocks.append(response.block)
            }
            timeBlocks.sort { $0.startTime < $1.startTime }
            AppLogger.syncInfo("Updated time block \(block.id).")
            return true
        } catch let error as AdminAPIError {
            AppLogger.syncError("updateTimeBlock failed: \(error.localizedDescription)")
            errorMessage = Self.serverMessage(from: error) ?? message(for: error)
            return false
        } catch {
            AppLogger.syncError("updateTimeBlock failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTimeBlock(_ block: TimeBlock) async {
        removingBlockId = block.id
        defer { removingBlockId = nil }

        do {
            try await AdminAPIClient.shared.deleteTimeBlock(id: block.id)
            timeBlocks.removeAll { $0.id == block.id }
            AppLogger.syncInfo("Deleted time block \(block.id).")
        } catch let error as AdminAPIError {
            AppLogger.syncError("deleteTimeBlock failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("deleteTimeBlock failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Optimistically update calendar pill flags when a CRM client’s
    /// no-show attention flag changes (clear or re-activate).
    func applyClientNoShowFlag(phone: String?, email: String?, flag: Bool) {
        appointments = appointments.map { apt in
            apt.belongsToClient(phone: phone, email: email)
                ? apt.withClientNoShowFlag(flag)
                : apt
        }
    }

    func applyPayment(appointmentId: String, payment: AppointmentPaymentSummary?) {
        applyPayment(appointmentIds: [appointmentId], payment: payment)
    }

    func applyPayment(appointmentIds: [String], payment: AppointmentPaymentSummary?) {
        guard !appointmentIds.isEmpty else { return }
        let ids = Set(appointmentIds)
        appointments = appointments.map { appointment in
            appointment.withPatchedPayments(ids: Array(ids), payment: payment)
        }
    }

    /// Patch a visit after extras / chair-length edits so the grid grows immediately.
    func replaceAppointment(_ visit: Appointment) {
        appointments = appointments.map { appointment in
            appointment.id == visit.id ? appointment.mergingVisit(visit) : appointment
        }
    }

    private static func serverMessage(from error: AdminAPIError) -> String? {
        guard case .server(_, let body) = error,
              let body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["message"] as? String
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return error.localizedDescription
        case .forbidden:
            return "You’re signed in but don’t have admin access. Ask for the admin role in Clerk (publicMetadata.role = admin)."
        case .decoding:
            return "Couldn't read the server's response. Please try again."
        case .transport:
            return "Couldn't reach the server. Check your connection and try again."
        case .notFound:
            return "Bookings API returned not found. Confirm `/api/admin/appointments` is deployed on www.sadiemarie.co."
        case .server(let status, let body):
            if let body, !body.isEmpty {
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status)). Please try again."
        case .invalidEndpoint, .invalidResponse, .unknown:
            return error.localizedDescription
        }
    }
}
