import Foundation

extension AdminAPIClient {

    /// `GET /api/admin/website/settings` — site image slots for the marketing site.
    func fetchWebsiteSettings() async throws -> [SiteImageSlot] {
        let response = try await fetch(
            "website/settings",
            as: WebsiteSettingsResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.slots
    }

    /// `POST /api/upload` — replace a site image (multipart: `id`, `file`, optional `caption`).
    @discardableResult
    func uploadSiteImage(
        id: String,
        imageData: Data,
        caption: String?
    ) async throws -> SiteImageSlot {
        let format = WebsiteUploadFileFormat.detect(from: imageData)
        let formPayload = MultipartFormDataBuilder.makeSiteImageUpload(
            id: id,
            imageData: imageData,
            caption: caption,
            format: format
        )
        return try await performSiteImageUpload(formPayload: formPayload, id: id, caption: caption)
    }

    /// `PATCH /api/admin/website/settings` — caption-only JSON update (slots without an image yet).
    ///
    /// When a slot already has an image, `WebsiteViewModel` saves the caption via `uploadSiteImage`
    /// instead — production currently returns 405 for JSON updates on `website/settings`.
    func updateWebsiteSlotCaption(id: String, caption: String) async throws -> SiteImageSlot {
        let body = try Self.encodePatchWebsiteSlotBody(id: id, caption: caption)

        do {
            return try await fetchWebsiteSlotCaptionResponse(body: body, method: .patch)
        } catch let error as AdminAPIError where Self.isMethodNotAllowed(error) {
            return try await uploadSiteImageCaptionOnly(id: id, caption: caption)
        }
    }

    // MARK: - Private

    nonisolated private static func encodePatchWebsiteSlotBody(id: String, caption: String) throws -> Data {
        try JSONEncoder().encode(PatchWebsiteSlotRequest(id: id, caption: caption))
    }

    private func fetchWebsiteSlotCaptionResponse(
        body: Data,
        method: HTTPMethod
    ) async throws -> SiteImageSlot {
        let response = try await fetch(
            "website/settings",
            as: PatchWebsiteSlotResponse.self,
            method: method,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.slot
    }

    /// Caption-only multipart upload when JSON routes do not accept updates yet.
    private func uploadSiteImageCaptionOnly(id: String, caption: String) async throws -> SiteImageSlot {
        let formPayload = MultipartFormDataBuilder.makeSiteImageCaptionOnly(id: id, caption: caption)
        return try await performSiteImageUpload(formPayload: formPayload, id: id, caption: caption)
    }

    private func performSiteImageUpload(
        formPayload: (body: Data, contentType: String),
        id: String,
        caption: String?
    ) async throws -> SiteImageSlot {
        let uploadURL = siteAPIBaseURL.appendingPathComponent("upload")

        let data = try await performAuthenticatedDataRequest(
            url: uploadURL,
            method: .post,
            body: formPayload.body,
            additionalHeaders: ["Content-Type": formPayload.contentType],
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        if let decoded = try? AdminAPIClient.decodeJSON(SiteImageUploadResponse.self, from: data) {
            if let slot = decoded.slot {
                return slot
            }
            if let url = decoded.resolvedImageURL {
                let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
                return SiteImageSlot(
                    id: decoded.slotId ?? id,
                    imageURL: url,
                    caption: decoded.caption ?? (trimmedCaption?.isEmpty == false ? trimmedCaption : caption)
                )
            }
        }

        if let slot = try? AdminAPIClient.decodeJSON(SiteImageSlot.self, from: data) {
            return slot
        }

        return SiteImageSlot(id: id, imageURL: nil, caption: caption)
    }

    nonisolated static func isMethodNotAllowed(_ error: AdminAPIError) -> Bool {
        if case .server(let status, _) = error, status == 405 {
            return true
        }
        return false
    }
}
