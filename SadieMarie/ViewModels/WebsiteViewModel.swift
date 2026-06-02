import Foundation
import Observation

@MainActor
@Observable
final class WebsiteViewModel {

    private(set) var slots: [WebsiteSlotItem] = WebsiteSlotItem.merged(from: [])
    private(set) var isLoading = false
    private(set) var isUploading = false
    private(set) var uploadingSlotID: String?
    private(set) var errorMessage: String?
    private(set) var saveSuccessMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let apiSlots = try await AdminAPIClient.shared.fetchWebsiteSettings()
            slots = WebsiteSlotItem.merged(from: apiSlots)
            AppLogger.syncInfo("Loaded \(slots.count) website image slots.")
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchWebsiteSettings failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchWebsiteSettings failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Saves a portfolio (or any) slot — POST when `newImage` is set, PATCH caption-only otherwise.
    func saveSlot(id: String, newImage: Data?, newCaption: String?) async {
        guard let item = slots.first(where: { $0.id == id }) else { return }

        let storedCaption = item.slot.caption
        let needsImageUpload = newImage != nil
        let needsCaptionPatch = !needsImageUpload && shouldPatchCaption(stored: storedCaption, draft: newCaption)

        guard needsImageUpload || needsCaptionPatch else { return }

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
                    caption: newCaption
                )
            } else if let newCaption {
                updated = try await updateCaption(
                    id: id,
                    caption: newCaption,
                    existingImageURL: item.imageURL
                )
            } else {
                return
            }

            applyUpdatedSlot(updated)
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
        caption: String?
    ) async {
        await saveSlot(id: slotID, newImage: imageData, newCaption: caption)
    }

    func clearSuccessBanner() {
        saveSuccessMessage = nil
    }

    func slots(in section: WebsiteSection) -> [WebsiteSlotItem] {
        slots.filter { $0.meta.section == section }
    }

    /// Caption-only save. Slots that already have an image use `POST /api/upload` (production
    /// does not expose `PATCH` on `/api/admin/website/settings` yet).
    private func updateCaption(
        id: String,
        caption: String,
        existingImageURL: URL?
    ) async throws -> SiteImageSlot {
        if let existingImageURL {
            let imageData = try await downloadImageData(from: existingImageURL)
            return try await AdminAPIClient.shared.uploadSiteImage(
                id: id,
                imageData: imageData,
                caption: caption
            )
        }
        return try await AdminAPIClient.shared.updateWebsiteSlotCaption(id: id, caption: caption)
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
            return error.localizedDescription
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
