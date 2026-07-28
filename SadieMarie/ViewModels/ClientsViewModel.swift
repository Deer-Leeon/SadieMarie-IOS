import Foundation
import Observation

/// Loads and filters the admin clients CRM list.
@MainActor
@Observable
final class ClientsViewModel {

    private(set) var clients: [Client] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchQuery = ""
    var sortBy: ClientSortOption = .name

    var filteredClients: [Client] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = clients

        if !query.isEmpty {
            let needle = query.lowercased()
            result = result.filter { client in
                client.matchesSearch(needle)
            }
        }

        return Self.sorted(result, by: sortBy)
    }

    var totalCount: Int { clients.count }
    var filteredCount: Int { filteredClients.count }

    func load() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            clients = try await AdminAPIClient.shared.fetchClients()
            AppLogger.syncInfo("Loaded \(clients.count) clients.")
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchClients failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchClients failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Replace a client row in-place after a CRM patch (flag clear, edit, etc.).
    func upsert(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
        } else {
            clients.insert(client, at: 0)
        }
    }

    private static func sorted(_ clients: [Client], by option: ClientSortOption) -> [Client] {
        switch option {
        case .name:
            return clients.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .recent:
            return clients.sorted { lhs, rhs in
                let left = lhs.lastBookingDate ?? .distantPast
                let right = rhs.lastBookingDate ?? .distantPast
                return left > right
            }
        case .ltv:
            return clients.sorted { $0.stats.ltv > $1.stats.ltv }
        case .bookings:
            return clients.sorted { $0.stats.bookingCount > $1.stats.bookingCount }
        }
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return error.localizedDescription
        case .forbidden:
            return "You’re signed in but don’t have admin access."
        case .decoding:
            return "Couldn’t read the clients list. Please try again."
        case .transport:
            return "Couldn’t reach the server. Check your connection and try again."
        case .notFound:
            return "Clients API returned not found. Confirm `/api/admin/clients/list` is deployed."
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

private extension Client {
    func matchesSearch(_ needle: String) -> Bool {
        let fields: [String?] = [
            firstName,
            lastName,
            email,
            phone,
            formattedPhone,
            displayName,
        ]
        return fields.contains { field in
            guard let field else { return false }
            return field.lowercased().contains(needle)
        }
    }
}
