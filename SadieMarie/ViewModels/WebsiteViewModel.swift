import Foundation
import Observation

@MainActor
@Observable
final class WebsiteViewModel {

    private(set) var slots: [WebsiteSlotItem] = WebsiteSlotItem.merged(from: [])
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isUploading = false
    private(set) var uploadingSlotID: String?
    private(set) var errorMessage: String?
    private(set) var refreshNotice: RefreshNotice?
    private(set) var saveSuccessMessage: String?
    private(set) var photoServices: [PhotoServiceOption] = []
    private let refresh = RefreshCoordinator()

    func load(showLoading: Bool = true, reason: RefreshReason = .initial) async {
        let blockUI = showLoading && !hasLoaded
        if blockUI {
            isLoading = true
            errorMessage = nil
        }

        let outcome = await refresh.load(reason: reason, applyNotice: { [weak self] notice in
            self?.refreshNotice = notice
        }) { [weak self] in
            guard let self else { return .cancelled }
            return await self.performLoad()
        }
        isLoading = false
        switch outcome {
        case .success, .failed:
            hasLoaded = true
        case .skipped, .cancelled:
            break
        }
    }

    private func performLoad() async -> RefreshAttemptOutcome {
        do {
            let apiSlots = try await AdminAPIClient.shared.fetchWebsiteSettings()
            slots = WebsiteSlotItem.merged(from: apiSlots)
            photoServices = await loadPhotoServices()
            errorMessage = nil
            AppLogger.syncInfo("Loaded \(slots.count) website image slots.")
            return .success
        } catch is CancellationError {
            return .cancelled
        } catch {
            AppLogger.syncError("fetchWebsiteSettings failed: \(error.localizedDescription)")
            return .failed(error)
        }
    }

    /// Bookable services for the photo picker. A menu failure still leaves Portrait / studio available.
    private func loadPhotoServices() async -> [PhotoServiceOption] {
        do {
            let services = try await AdminAPIClient.shared.fetchServices()
            return PhotoServiceOption.bookable(from: services)
        } catch {
            AppLogger.syncError("fetchServices for photo editor failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Saves a slot. A new image is uploaded. Caption, alt text, and file name can be saved on their own.
    func saveSlot(
        id: String,
        newImage: Data?,
        newCaption: String?,
        photo: SiteImagePhotoFields? = nil
    ) async {
        guard let item = slots.first(where: { $0.id == id }) else { return }

        let storedCaption = item.slot.caption
        let needsImageUpload = newImage != nil
        let needsCaptionPatch = !needsImageUpload && shouldPatchCaption(stored: storedCaption, draft: newCaption)
        let needsPhotoPatch = !needsImageUpload && shouldPatchPhoto(stored: item.slot, draft: photo)

        guard needsImageUpload || needsCaptionPatch || needsPhotoPatch else { return }

        isUploading = true
        uploadingSlotID = id
        errorMessage = nil
        saveSuccessMessage = nil

        defer {
            isUploading = false
            uploadingSlotID = nil
        }

        do {
            let updated: SiteImageSlot
            if let newImage {
                updated = try await AdminAPIClient.shared.uploadSiteImage(
                    id: id,
                    imageData: newImage,
                    caption: newCaption,
                    photo: photo
                )
            } else {
                updated = try await updateMetadata(
                    id: id,
                    caption: needsCaptionPatch ? newCaption : nil,
                    photo: needsPhotoPatch ? photo : nil,
                    existingImageURL: item.imageURL
                )
            }

            applyUpdatedSlot(updated)
            await reloadSlotsPreservingErrors()
            saveSuccessMessage = "Saved"
            AppLogger.syncInfo("Saved website slot \(id).")

            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if saveSuccessMessage == "Saved" {
                    saveSuccessMessage = nil
                }
            }
        } catch let error as AdminAPIError {
            AppLogger.syncError("saveSlot failed: \(error.localizedDescription)")
            if isSlotNotFound(error) {
                errorMessage = "Please upload an image first."
            } else {
                errorMessage = message(for: error)
            }
        } catch {
            AppLogger.syncError("saveSlot failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func upload(
        slotID: String,
        imageData: Data,
        caption: String?,
        photo: SiteImagePhotoFields? = nil
    ) async {
        await saveSlot(id: slotID, newImage: imageData, newCaption: caption, photo: photo)
    }

    func clearSuccessBanner() {
        saveSuccessMessage = nil
    }

    func slots(in section: WebsiteSection) -> [WebsiteSlotItem] {
        slots.filter { $0.meta.section == section }
    }

    /// Text-only save. Updates the existing photo record. If the server rejects the update
    /// method, the current image is uploaded again with the new words.
    private func updateMetadata(
        id: String,
        caption: String?,
        photo: SiteImagePhotoFields?,
        existingImageURL: URL?
    ) async throws -> SiteImageSlot {
        var request = PatchWebsiteSlotRequest(id: id)
        if let caption {
            request.includesCaption = true
            request.caption = caption
        }
        if let photo {
            request.includesAltText = true
            request.altText = photo.altText
            request.includesFileName = true
            request.fileName = photo.fileName
            request.includesPhotoSubject = true
            request.photoSubject = photo.photoSubject
        }

        do {
            return try await AdminAPIClient.shared.updateWebsiteSlot(request)
        } catch let error as AdminAPIError where AdminAPIClient.isMethodNotAllowed(error) {
            guard let existingImageURL else { throw error }
            let imageData = try await downloadImageData(from: existingImageURL)
            return try await AdminAPIClient.shared.uploadSiteImage(
                id: id,
                imageData: imageData,
                caption: caption,
                photo: photo
            )
        }
    }

    private func downloadImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AdminAPIError.invalidResponse
        }
        return data
    }

    private func shouldPatchCaption(stored: String?, draft: String?) -> Bool {
        guard let draft else { return false }
        switch stored {
        case nil:
            return !draft.isEmpty
        case let stored?:
            return stored != draft
        }
    }

    private func shouldPatchPhoto(stored: SiteImageSlot, draft: SiteImagePhotoFields?) -> Bool {
        guard let draft else { return false }
        return draft != SiteImagePhotoFields.stored(from: stored)
    }

    private func isSlotNotFound(_ error: AdminAPIError) -> Bool {
        switch error {
        case .notFound:
            return true
        case .server(let status, let body):
            if status == 404 { return true }
            if let body, body.localizedCaseInsensitiveContains("slot_not_found") {
                return true
            }
            return false
        default:
            return false
        }
    }

    private func applyUpdatedSlot(_ updated: SiteImageSlot) {
        slots = slots.map { item in
            guard item.id == updated.id else { return item }
            return WebsiteSlotItem(meta: item.meta, slot: updated)
        }
    }

    /// Re-fetch settings after upload so thumbnails match the server (new blob URLs).
    private func reloadSlotsPreservingErrors() async {
        do {
            let apiSlots = try await AdminAPIClient.shared.fetchWebsiteSettings()
            slots = WebsiteSlotItem.merged(from: apiSlots)
        } catch {
            AppLogger.syncError("reload after upload failed: \(error.localizedDescription)")
        }
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return "Please sign in again."
        case .forbidden:
            return "You’re signed in but don’t have admin access."
        case .decoding:
            return "Couldn’t read website settings. Please try again."
        case .transport:
            return "Couldn’t reach the server. Check your connection and try again."
        case .notFound:
            return "Website API returned not found. Confirm `/api/admin/website/settings` is deployed."
        case .server(let status, let body):
            if let body, !body.isEmpty {
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status)). Please try again."
        case .invalidEndpoint, .invalidResponse, .unknown:
            return error.localizedDescription
        }
    }
}
