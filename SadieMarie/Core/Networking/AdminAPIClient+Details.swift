import Foundation

extension AdminAPIClient {

    // MARK: - Appointments

    /// `PATCH /api/admin/appointments/{id}/status` — no-show, admin cancel, etc.
    func updateAppointmentStatus(id: String, status: String) async throws {
        let body = try AppointmentStatusPatchBody(status: status).encodedJSON()
        _ = try await fetch(
            "appointments/\(id)/status",
            as: EmptyJSON.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `POST /api/admin/appointments/{id}/reschedule` — sync local row after Cal reschedule.
    func rescheduleAppointment(id: String, payload: ReschedulePayload) async throws {
        let body = try payload.encodedJSON()
        _ = try await fetch(
            "appointments/\(id)/reschedule",
            as: EmptyJSON.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    // MARK: - Clients

    /// `POST /api/admin/clients` — first-touch upsert keyed by phone.
    func bootstrapClient(
        phone: String,
        firstName: String?,
        lastName: String?,
        email: String?
    ) async throws -> Client {
        let body = try BootstrapClientBody(
            phone: phone,
            firstName: firstName,
            lastName: lastName,
            email: email
        ).encodedJSON()
        let response = try await fetch(
            "clients",
            as: ClientMutationResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }

    /// `GET /api/admin/clients/{id}/appointments` — booking history + CRM stats.
    func fetchClientHistory(id: String) async throws -> ClientHistoryResponse {
        try await fetch(
            "clients/\(id)/appointments",
            as: ClientHistoryResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `GET /api/admin/clients/{id}/notes` — latest private note text (append-only history on server).
    func fetchClientNotes(id: String) async throws -> String {
        let response = try await fetch(
            "clients/\(id)/notes",
            as: ClientNotesListResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.notes.latestNoteText()
    }

    /// `POST /api/admin/clients/{id}/notes` — append a new note row.
    func updateClientNotes(id: String, notes: String) async throws {
        let body = try ClientNotesPatchBody(notes: notes).encodedJSON()
        _ = try await fetch(
            "clients/\(id)/notes",
            as: ClientNoteCreateResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `GET /api/admin/clients/{id}/photos` — gallery items.
    func fetchClientPhotos(id: String) async throws -> [ClientPhoto] {
        let response = try await fetch(
            "clients/\(id)/photos",
            as: ClientPhotosResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.photos
    }

    /// `PATCH /api/admin/clients/{id}` — update name / email.
    func updateClientIdentity(id: String, payload: ClientIdentityPayload) async throws -> Client {
        let body = try payload.encodedJSON()
        let response = try await fetch(
            "clients/\(id)",
            as: ClientMutationResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }
}

/// Decodes `{}` or any empty success body from admin PATCH/POST routes.
private struct EmptyJSON: Decodable, Sendable {
    nonisolated init(from decoder: Decoder) throws {}
}
