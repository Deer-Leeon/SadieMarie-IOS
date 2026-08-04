import Foundation
import Observation

/// Loads and holds the admin appointments list for the Bookings tab.
@MainActor
@Observable
final class BookingsViewModel {

    private(set) var appointments: [Appointment] = []
    private(set) var timeBlocks: [TimeBlock] = []
    private(set) var isLoading = false
    private(set) var isCreatingBlock = false
    private(set) var isUpdatingBlock = false
    private(set) var removingBlockId: String?
    private(set) var errorMessage: String?

    /// List + single-day modal — excludes canceled; keeps pending and no-show.
    var visibleAppointments: [Appointment] {
        appointments.visibleAppointments
    }

    /// 3-day / week grids — excludes pending and canceled.
    var calendarAppointments: [Appointment] {
        appointments.calendarAppointments
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            async let bookingsResponse = AdminAPIClient.shared.fetchBookings()
            async let blocksResponse = AdminAPIClient.shared.fetchTimeBlocks()
            let response = try await bookingsResponse
            let blocks = try await blocksResponse
            appointments = response.appointments
            timeBlocks = blocks
            AppLogger.syncInfo("Loaded \(appointments.count) appointments, \(blocks.count) time blocks.")
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
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
        appointments = appointments.map { appointment in
            appointment.id == appointmentId
                ? appointment.withTerminalPayment(payment)
                : appointment
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
