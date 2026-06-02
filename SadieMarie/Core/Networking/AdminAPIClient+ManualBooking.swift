import Foundation

extension AdminAPIClient {

    /// `GET /api/admin/manual-booking/slots` — Cal.com availability proxy.
    func fetchManualBookingSlots(
        eventTypeId: Int,
        date: String,
        end: String? = nil
    ) async throws -> Data {
        var queryItems = [
            URLQueryItem(name: "eventTypeId", value: String(eventTypeId)),
            URLQueryItem(name: "date", value: date),
        ]
        if let end, end != date {
            queryItems.append(URLQueryItem(name: "end", value: end))
        }
        return try await fetchData(
            "manual-booking/slots",
            queryItems: queryItems,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `POST /api/admin/manual-booking/create` — Cal.com booking (step 1 of 2).
    func createManualBooking(_ payload: ManualBookingCreatePayload) async throws -> Data {
        try await fetchData(
            "manual-booking/create",
            method: .post,
            body: try payload.encodedJSON(),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `POST /api/admin/manual-booking/complete` — local DB sync + SMS (step 2 of 2).
    func completeManualBooking(_ payload: ManualBookingCompletePayload) async throws {
        _ = try await fetchData(
            "manual-booking/complete",
            method: .post,
            body: try payload.encodedJSON(),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }
}
