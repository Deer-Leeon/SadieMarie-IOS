import Foundation

extension AdminAPIClient {

    /// `GET /api/admin/time-blocks` — studio holds (optional `from` / `to` ISO bounds).
    func fetchTimeBlocks(from: String? = nil, to: String? = nil) async throws -> [TimeBlock] {
        var queryItems: [URLQueryItem] = []
        if let from { queryItems.append(URLQueryItem(name: "from", value: from)) }
        if let to { queryItems.append(URLQueryItem(name: "to", value: to)) }
        let data = try await fetchData(
            "time-blocks",
            queryItems: queryItems,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        let response = try Self.decodeJSON(TimeBlocksResponse.self, from: data)
        return response.blocks
    }

    /// `POST /api/admin/time-blocks` — block studio time on Cal.com + local mirror.
    func createTimeBlock(_ payload: TimeBlockCreateRequest) async throws -> TimeBlockCreateResponse {
        let body = try payload.encodedJSON()
        return try await fetch(
            "time-blocks",
            as: TimeBlockCreateResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `PATCH /api/admin/time-blocks/{id}` — update the interval and note.
    func updateTimeBlock(
        id: String,
        payload: TimeBlockUpdateRequest
    ) async throws -> TimeBlockCreateResponse {
        let body = try payload.encodedJSON()
        return try await fetch(
            "time-blocks/\(id)",
            as: TimeBlockCreateResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `DELETE /api/admin/time-blocks/{id}` — remove a block locally + on Cal.com.
    func deleteTimeBlock(id: String) async throws {
        _ = try await fetchData(
            "time-blocks/\(id)",
            method: .delete,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }
}
