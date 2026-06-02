import Foundation
import Observation

@MainActor
@Observable
final class ServicesViewModel {

    private(set) var services: [Service] = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var archivingId: Int?
    private(set) var errorMessage: String?

    var groupedCategories: [ServiceCategorySection] {
        ServiceCatalog.groupedCategories(from: services)
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            services = try await AdminAPIClient.shared.fetchServices()
            AppLogger.syncInfo("Loaded \(services.count) services.")
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchServices failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchServices failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func create(_ payload: CreateServicePayload) async throws {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await AdminAPIClient.shared.createService(payload)
            mergeService(created)
            AppLogger.syncInfo("Created service \(created.id).")
        } catch let error as AdminAPIError {
            errorMessage = message(for: error)
            throw error
        }
    }

    func update(_ payload: UpdateServicePayload) async throws {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let updated = try await AdminAPIClient.shared.updateService(payload)
            mergeService(updated)
            AppLogger.syncInfo("Updated service \(updated.id).")
        } catch let error as AdminAPIError {
            errorMessage = message(for: error)
            throw error
        }
    }

    func archive(id: Int) async {
        archivingId = id
        errorMessage = nil

        defer { archivingId = nil }

        do {
            try await AdminAPIClient.shared.deleteService(dbId: id)
            services.removeAll { $0.id == id }
            // Removing a group also drops orphaned children from the local list until refetch.
            services.removeAll { $0.parentId == id }
            AppLogger.syncInfo("Archived service \(id).")
            await load()
        } catch let error as AdminAPIError {
            AppLogger.syncError("deleteService failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("deleteService failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func candidateParents(for category: String, excluding serviceId: Int?) -> [Service] {
        services
            .filter { $0.isGroup && $0.category == category && $0.id != serviceId }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func mergeService(_ service: Service) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
        } else {
            services.append(service)
        }
        services.sort {
            if $0.category != $1.category {
                return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
            }
            if $0.isGroup != $1.isGroup { return $0.isGroup && !$1.isGroup }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return error.localizedDescription
        case .forbidden:
            return "You’re signed in but don’t have admin access."
        case .decoding:
            return "Couldn’t read the services list. Please try again."
        case .transport:
            return "Couldn’t reach the server. Check your connection and try again."
        case .notFound:
            return "That service was not found. Pull to refresh."
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
