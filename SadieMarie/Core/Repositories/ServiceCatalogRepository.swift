import Foundation

enum ServiceCatalogError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The service menu could not be loaded."
        case .httpStatus(let code):
            return "The service menu request failed (HTTP \(code))."
        }
    }
}

/// Fetches the public service catalogue from `GET /api/services` (no auth).
actor ServiceCatalogRepository {
    static let shared = ServiceCatalogRepository()

    private let servicesURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseAPIURL: URL = URL(string: "https://www.sadiemarie.co/api")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.servicesURL = baseAPIURL.appendingPathComponent("services")
        self.session = session
        self.decoder = decoder
    }

    func fetchCatalog() async throws -> PublicServicesResponse {
        var request = URLRequest(url: servicesURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceCatalogError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ServiceCatalogError.httpStatus(http.statusCode)
        }
        return try Self.decodeCatalog(from: data, decoder: decoder)
    }

    /// Decodes off the repository actor without main-actor-isolated `Decodable` witnesses.
    nonisolated static func decodeCatalog(
        from data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> PublicServicesResponse {
        try decoder.decode(PublicServicesResponse.self, from: data)
    }
}
