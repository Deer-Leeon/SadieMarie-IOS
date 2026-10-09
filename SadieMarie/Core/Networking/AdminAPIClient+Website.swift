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

    /// `POST /api/upload` — replace a site image (multipart: `id`, `file`, optional caption and photo words).
    @discardableResult
    func uploadSiteImage(
        id: String,
        imageData: Data,
        caption: String?,
        photo: SiteImagePhotoFields? = nil
    ) async throws -> SiteImageSlot {
        let format = WebsiteUploadFileFormat.detect(from: imageData)
        let formPayload = MultipartFormDataBuilder.makeSiteImageUpload(
            id: id,
            imageData: imageData,
            caption: caption,
            photo: photo,
            format: format
        )
        return try await performSiteImageUpload(
            formPayload: formPayload,
            id: id,
            caption: caption,
            photo: photo
        )
    }

    /// `PATCH /api/admin/website/settings` — caption, alt text, file name, or subject, without a new image.
    func updateWebsiteSlot(_ request: PatchWebsiteSlotRequest) async throws -> SiteImageSlot {
        let body = try request.jsonData()
        return try await fetchWebsiteSlotCaptionResponse(body: body, method: .patch)
    }

    // MARK: - Private

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

    private func performSiteImageUpload(
        formPayload: (body: Data, contentType: String),
        id: String,
        caption: String?,
        photo: SiteImagePhotoFields?
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
                    caption: decoded.caption ?? (trimmedCaption?.isEmpty == false ? trimmedCaption : caption),
                    altText: decoded.altText ?? photo?.altText.nilIfEmpty,
                    fileName: decoded.fileName ?? photo?.fileName.nilIfEmpty,
                    photoSubject: decoded.photoSubject ?? photo?.photoSubject.nilIfEmpty
                )
            }
        }

        if let slot = try? AdminAPIClient.decodeJSON(SiteImageSlot.self, from: data) {
            return slot
        }

        return SiteImageSlot(
            id: id,
            imageURL: nil,
            caption: caption,
            altText: photo?.altText.nilIfEmpty,
            fileName: photo?.fileName.nilIfEmpty,
            photoSubject: photo?.photoSubject.nilIfEmpty
        )
    }

    nonisolated static func isMethodNotAllowed(_ error: AdminAPIError) -> Bool {
        if case .server(let status, _) = error, status == 405 {
            return true
        }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
