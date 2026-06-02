import Foundation
import Observation

@MainActor
@Observable
final class ServiceCatalogViewModel {
    var sections: [PublicServiceCategorySection] = []
    var calUsername = ""
    var isLoading = false
    var errorMessage: String?

    private let repository: ServiceCatalogRepository

    init(repository: ServiceCatalogRepository = .shared) {
        self.repository = repository
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await repository.fetchCatalog()
            calUsername = response.calUsername
            sections = PublicServiceCatalogEngine.buildSections(
                services: response.services,
                layout: response.layout
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
