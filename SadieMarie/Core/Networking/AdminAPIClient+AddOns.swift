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
    ) async throws -> AddOnMutateResponse {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let body = try AddOnCreatePayload(eventTypeId: eventTypeId).encodedJSON()
        return try await fetch(
            "appointments/\(encodedId)/add-ons",
            as: AddOnMutateResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `DELETE /api/admin/appointments/{id}/add-ons/{addonId}` — drop an unpaid extra.
    func deleteAppointmentExtra(appointmentId: String, extraId: String) async throws -> AddOnMutateResponse {
        let encodedParent = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let encodedExtra = extraId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? extraId
        return try await fetch(
            "appointments/\(encodedParent)/add-ons/\(encodedExtra)",
            as: AddOnMutateResponse.self,
            method: .delete,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `PATCH /api/admin/appointments/{id}/duration` — set total chair minutes.
    func patchAppointmentDuration(appointmentId: String, durationMins: Int) async throws -> Appointment {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let body = try DurationPatchPayload(durationMins: durationMins).encodedJSON()
        let response = try await fetch(
            "appointments/\(encodedId)/duration",
            as: DurationPatchResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.appointment
    }
}

struct AddOnMutateResponse: Decodable, Sendable {
    let extra: Appointment?
    let appointment: Appointment?
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

private struct DurationPatchPayload: Encodable, Sendable {
    let durationMins: Int

    private enum CodingKeys: String, CodingKey {
        case durationMins
    }

    func encodedJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

private struct DurationPatchResponse: Decodable, Sendable {
    let appointment: Appointment
}
