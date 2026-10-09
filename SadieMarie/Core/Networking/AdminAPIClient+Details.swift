import Foundation

extension AdminAPIClient {

    // MARK: - Appointments

    /// `PATCH /api/admin/appointments/{id}/status` — no-show, admin cancel, etc.
    @discardableResult
    func updateAppointmentStatus(
        id: String,
        status: String,
        chargeNoShow: Bool? = nil,
        sendSms: Bool? = nil
    ) async throws -> AppointmentStatusUpdateResponse {
        let body = try AppointmentStatusPatchBody(
            status: status,
            chargeNoShow: chargeNoShow,
            sendSms: sendSms
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
        eventTypeId: Int,
        sendSms: Bool = true
    ) async throws -> AdminRescheduleResponse {
        let body = try AdminReschedulePayload(
            start: start,
            eventTypeId: eventTypeId,
            sendSms: sendSms
        ).encodedJSON()
        return try await fetch(
            "appointments/\(id)/admin-reschedule",
            as: AdminRescheduleResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `POST /api/admin/appointments/{id}/change-service` — same start, new service.
    func changeAppointmentService(
        id: String,
        eventTypeId: Int,
        sendSms: Bool = true
    ) async throws {
        let body = try ChangeServicePayload(
            eventTypeId: eventTypeId,
            sendSms: sendSms
        ).encodedJSON()
        _ = try await fetch(
            "appointments/\(id)/change-service",
            as: EmptyJSON.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    // MARK: - Push devices

    /// `POST /api/admin/push-devices` — upsert this device's APNs token.
    func registerPushDevice(
        deviceToken: String,
        bundleId: String,
        environment: String
    ) async throws {
        let body = try RegisterPushDeviceBody(
            deviceToken: deviceToken,
            bundleId: bundleId,
            environment: environment
        ).encodedJSON()
        _ = try await fetch(
            "push-devices",
            as: EmptyJSON.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `DELETE /api/admin/push-devices` — remove token on Log Out.
    func unregisterPushDevice(deviceToken: String) async throws {
        let body = try UnregisterPushDeviceBody(deviceToken: deviceToken).encodedJSON()
        _ = try await fetch(
            "push-devices",
            as: EmptyJSON.self,
            method: .delete,
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

    /// `GET /api/admin/clients/{id}/sms-messages` — outbound texts for this client.
    func fetchClientSmsMessages(id: String, before: String? = nil) async throws -> ClientSmsMessagesResponse {
        var query: [URLQueryItem] = []
        if let before, !before.isEmpty {
            query.append(URLQueryItem(name: "before", value: before))
        }
        let data = try await fetchData(
            "clients/\(id)/sms-messages",
            queryItems: query,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return try Self.decodeJSON(ClientSmsMessagesResponse.self, from: data)
    }

    /// `POST /api/admin/clients/{id}/sms-messages` — consent or Google-review text.
    func sendManualClientSms(id: String, kind: ManualClientSmsKind) async throws -> ManualClientSmsResponse {
        let body = try ManualClientSmsRequest(kind: kind).encodedJSON()
        return try await fetch(
            "clients/\(id)/sms-messages",
            as: ManualClientSmsResponse.self,
            method: .post,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
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

    /// `PATCH /api/admin/clients/{id}` — clear the dismissible no-show attention flag.
    func clearClientNoShowFlag(id: String) async throws -> Client {
        let body = try ClearClientNoShowFlagPayload().encodedJSON()
        let response = try await fetch(
            "clients/\(id)",
            as: ClientMutationResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }

    /// `POST /api/admin/clients/{id}/consent-review` — stamp Reviewed by Technician.
    func markConsentTechnicianReviewed(id: String) async throws -> Client {
        let response = try await fetch(
            "clients/\(id)/consent-review",
            as: ClientMutationResponse.self,
            method: .post,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }

    /// `PATCH /api/admin/clients/{id}` — grant a one-time fee free pass (sends SMS).
    func grantClientFeeWaive(id: String, kind: GrantClientFeeWaivePayload.Kind) async throws -> Client {
        let body = try GrantClientFeeWaivePayload(kind: kind).encodedJSON()
        let response = try await fetch(
            "clients/\(id)",
            as: ClientMutationResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }

    /// `PATCH /api/admin/clients/{id}` — post-visit review toggle + star rating.
    func patchClientReviewFlags(
        id: String,
        reviewRequestPending: Bool? = nil,
        googleReviewStars: Int? = nil,
        clearGoogleReviewStars: Bool = false
    ) async throws -> Client {
        let body = try PatchClientReviewFlagsPayload(
            reviewRequestPending: reviewRequestPending,
            googleReviewStars: googleReviewStars,
            encodeStarsNull: clearGoogleReviewStars
        ).encodedJSON()
        let response = try await fetch(
            "clients/\(id)",
            as: ClientMutationResponse.self,
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.client
    }

    // MARK: - Appointment payments

    func fetchSameDayUnsettled(appointmentId: String) async throws -> [SameDayUnsettledVisit] {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        let response = try await fetch(
            "appointments/\(encodedId)/same-day-unsettled",
            as: SameDayUnsettledResponse.self,
            method: .get,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.appointments
    }

    func startTerminalPayment(
        appointmentId: String,
        request: TerminalStartRequest
    ) async throws -> PaymentOperationResult {
        try await terminalPaymentRequest(
            appointmentId: appointmentId,
            suffix: nil,
            method: .post,
            body: try request.encodedJSON()
        )
    }

    func fetchTerminalPayment(appointmentId: String) async throws -> PaymentOperationResult {
        try await terminalPaymentRequest(appointmentId: appointmentId, suffix: nil, method: .get)
    }

    func retryTerminalPayment(appointmentId: String) async throws -> PaymentOperationResult {
        try await terminalPaymentRequest(appointmentId: appointmentId, suffix: "retry", method: .post)
    }

    func cancelTerminalPayment(appointmentId: String) async throws -> PaymentOperationResult {
        try await terminalPaymentRequest(appointmentId: appointmentId, suffix: "cancel", method: .post)
    }

    func settleAppointment(
        appointmentId: String,
        method: AppointmentSettlementMethod,
        note: String?,
        additionalAppointmentIds: [String]? = nil
    ) async throws -> SettlementOperationResult {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = SettlementRequest(
            method: method,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil,
            additionalAppointmentIds: additionalAppointmentIds?.isEmpty == false
                ? additionalAppointmentIds
                : nil
        )
        return try await settlementRequest(
            appointmentId: appointmentId,
            suffix: nil,
            body: payload.encodedJSON()
        )
    }

    func undoAppointmentSettlement(appointmentId: String) async throws -> SettlementOperationResult {
        try await settlementRequest(appointmentId: appointmentId, suffix: "undo", body: nil)
    }

    private func terminalPaymentRequest(
        appointmentId: String,
        suffix: String?,
        method: HTTPMethod,
        body: Data? = nil
    ) async throws -> PaymentOperationResult {
        let endpoint = paymentEndpoint(
            appointmentId: appointmentId,
            resource: "terminal-payment",
            suffix: suffix
        )
        let raw = try await fetchDataWithStatus(endpoint, method: method, body: body)
        do {
            let response = try Self.decodeJSON(TerminalPaymentAPIResponse.self, from: raw.data)
            return PaymentOperationResult(response: response, statusCode: raw.statusCode)
        } catch let error as DecodingError {
            throw AdminAPIError.decoding(error)
        }
    }

    private func settlementRequest(
        appointmentId: String,
        suffix: String?,
        body: Data?
    ) async throws -> SettlementOperationResult {
        let endpoint = paymentEndpoint(
            appointmentId: appointmentId,
            resource: "settlement",
            suffix: suffix
        )
        let raw = try await fetchDataWithStatus(endpoint, method: .post, body: body)
        do {
            let response = try Self.decodeJSON(SettlementAPIResponse.self, from: raw.data)
            return SettlementOperationResult(response: response, statusCode: raw.statusCode)
        } catch let error as DecodingError {
            throw AdminAPIError.decoding(error)
        }
    }

    private func paymentEndpoint(
        appointmentId: String,
        resource: String,
        suffix: String?
    ) -> String {
        let encodedId = appointmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? appointmentId
        return ["appointments", encodedId, resource, suffix]
            .compactMap { $0 }
            .joined(separator: "/")
    }
}

struct ClientPhotoUploadResponse: Decodable, Sendable {
    let photo: ClientPhoto
}

/// Decodes `{}` or any empty success body from admin PATCH/POST routes.
private struct EmptyJSON: Decodable, Sendable {
    nonisolated init(from decoder: Decoder) throws {}
}

private struct ChangeServicePayload: Encodable, Sendable {
    let eventTypeId: Int
    let sendSms: Bool

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventTypeId, forKey: .eventTypeId)
        try container.encode(sendSms, forKey: .sendSms)
    }

    nonisolated func encodedJSON() throws -> Data {
        try JSONEncoder().encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case eventTypeId
        case sendSms = "send_sms"
    }
}

private struct RegisterPushDeviceBody: Encodable, Sendable {
    let deviceToken: String
    let bundleId: String
    let environment: String

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }
}

private struct UnregisterPushDeviceBody: Encodable, Sendable {
    let deviceToken: String

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }
}
