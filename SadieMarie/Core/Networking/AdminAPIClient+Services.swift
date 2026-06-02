import Foundation

extension AdminAPIClient {

    /// `GET /api/admin/services` — active service catalogue.
    func fetchServices() async throws -> [Service] {
        let response = try await fetch(
            "services",
            as: ServicesListResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.services
    }

    /// `POST /api/admin/services` — create a group or bookable service.
    func createService(_ payload: CreateServicePayload) async throws -> Service {
        let response = try await fetch(
            "services",
            as: ServiceMutationResponse.self,
            method: .post,
            body: try payload.encodedJSON(),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.service
    }

    /// `PATCH /api/admin/services` — update an existing service.
    func updateService(_ payload: UpdateServicePayload) async throws -> Service {
        let response = try await fetch(
            "services",
            as: ServiceMutationResponse.self,
            method: .patch,
            body: try payload.encodedJSON(),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.service
    }

    /// `DELETE /api/admin/services?db_id=` — soft-delete (archive).
    func deleteService(dbId: Int) async throws {
        try await delete(
            "services",
            queryItems: [URLQueryItem(name: "db_id", value: String(dbId))],
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }
}
