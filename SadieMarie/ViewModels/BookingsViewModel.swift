import Foundation
import Observation

/// Loads and holds the admin appointments list for the Bookings tab.
@MainActor
@Observable
final class BookingsViewModel {

    private(set) var appointments: [Appointment] = []
    private(set) var isLoading = false
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
            let response = try await AdminAPIClient.shared.fetchBookings()
            appointments = response.appointments
            AppLogger.syncInfo("Loaded \(appointments.count) appointments.")
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchBookings failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
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
