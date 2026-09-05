import Foundation

extension AdminAPIClient {
    /// `GET /api/admin/appointments/{id}/add-ons` — catalogue for attaching extras.
    func fetchAppointmentAddOnCatalog(appointmentId: String) async throws -> ManualBookingServicesMaps {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        return try await fetch(
            "appointments/\(encodedId)/add-ons",
            as: ManualBookingServicesMaps.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `POST /api/admin/appointments/{id}/add-ons` — attach a catalogue extra.
    func addAppointmentExtra(
        appointmentId: String,
        eventTypeId: Int
    ) async throws -> Appointment {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let body = try AddOnCreatePayload(eventTypeId: eventTypeId).encodedJSON()
        let response = try await fetch(
            "appointments/\(encodedId)/add-ons",
            as: AddOnCreateResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.extra
    }

    /// `DELETE /api/admin/appointments/{id}/add-ons/{addonId}` — drop an unpaid extra.
    func deleteAppointmentExtra(appointmentId: String, extraId: String) async throws {
        let encodedParent = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let encodedExtra = extraId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? extraId
        _ = try await fetchData(
            "appointments/\(encodedParent)/add-ons/\(encodedExtra)",
            method: .delete,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }
}

private struct AddOnCreatePayload: Encodable, Sendable {
    let eventTypeId: Int

    private enum CodingKeys: String, CodingKey {
        case eventTypeId
    }

    func encodedJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

private struct AddOnCreateResponse: Decodable, Sendable {
    let extra: Appointment
}
