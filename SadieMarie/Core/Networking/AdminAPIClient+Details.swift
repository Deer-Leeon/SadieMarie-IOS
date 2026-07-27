import Foundation

extension AdminAPIClient {

    // MARK: - Appointments

    /// `PATCH /api/admin/appointments/{id}/status` — no-show, admin cancel, etc.
    @discardableResult
    func updateAppointmentStatus(
        id: String,
        status: String,
        chargeNoShow: Bool? = nil
    ) async throws -> AppointmentStatusUpdateResponse {
        let body = try AppointmentStatusPatchBody(
            status: status,
            chargeNoShow: chargeNoShow
        ).encodedJSON()
        return try await fetch(
            "appointments/\(id)/status",
            as: AppointmentStatusUpdateResponse.self,
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

    /// `POST /api/admin/appointments/{id}/admin-reschedule` — god-mode any-day move.
    @discardableResult
    func adminRescheduleAppointment(
        id: String,
        start: String,
        eventTypeId: Int
    ) async throws -> AdminRescheduleResponse {
        let body = try AdminReschedulePayload(
            start: start,
            eventTypeId: eventTypeId
        ).encodedJSON()
        return try await fetch(
            "appointments/\(id)/admin-reschedule",
            as: AdminRescheduleResponse.self,
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

    /// `POST /api/admin/clients/{id}/photos` — multipart gallery upload.
    func uploadClientPhoto(
        id: String,
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> ClientPhoto {
        var form = MultipartFormDataBuilder()
        form.appendFile(
            name: "file",
            filename: filename,
            mimeType: mimeType,
            data: imageData
        )
        let formPayload = (body: form.finalize(), contentType: form.contentType)
        let url = try resolveURL(for: "clients/\(id)/photos")
        let data = try await performAuthenticatedDataRequest(
            url: url,
            method: .post,
            body: formPayload.body,
            additionalHeaders: ["Content-Type": formPayload.contentType],
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        if let wrapped = try? AdminAPIClient.decodeJSON(ClientPhotoUploadResponse.self, from: data) {
            return wrapped.photo
        }
        return try AdminAPIClient.decodeJSON(ClientPhoto.self, from: data)
    }

    /// `DELETE /api/admin/clients/{id}/photos`
    func deleteClientPhoto(id: String, photoId: Int, blobUrl: String) async throws {
        struct Body: Encodable {
            let photoId: Int
            let blobUrl: String
        }
        let body = try AdminRequestEncoder.encode(Body(photoId: photoId, blobUrl: blobUrl))
        _ = try await fetch(
            "clients/\(id)/photos",
            as: EmptyJSON.self,
            method: .delete,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
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

struct ClientPhotoUploadResponse: Decodable, Sendable {
    let photo: ClientPhoto
}

/// Decodes `{}` or any empty success body from admin PATCH/POST routes.
private struct EmptyJSON: Decodable, Sendable {
    nonisolated init(from decoder: Decoder) throws {}
}
