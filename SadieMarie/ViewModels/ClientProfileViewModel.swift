import Foundation
import Observation

@MainActor
@Observable
final class ClientProfileViewModel {
    let entry: ClientProfileEntry

    private(set) var client: Client?
    private(set) var history: [Appointment] = []
    private(set) var crmStats = ClientHistoryCrmStats()
    private(set) var notes: String = ""
    private(set) var savedNotes: String = ""
    private(set) var photos: [ClientPhoto] = []

    private(set) var isBootstrapping = false
    private(set) var isLoadingDossier = false
    private(set) var isLoadingPhotos = false
    private(set) var isUploadingPhoto = false
    private(set) var isSavingNotes = false
    private(set) var isSavingIdentity = false

    private(set) var bootstrapError: String?
    private(set) var dossierError: String?
    private(set) var notesError: String?
    private(set) var photosError: String?
    private(set) var identityError: String?

    /// Legacy flag — email is optional; kept false so bootstrap no longer blocks on email.
    private(set) var awaitingBootstrapEmail = false
    var bootstrapEmailDraft = ""
    var bootstrapEmailTouched = false

    var notesDirty: Bool { notes != savedNotes }

    var bootstrapEmailInvalid: Bool {
        bootstrapEmailTouched && !ClientEmail.isValidOptional(bootstrapEmailDraft)
    }

    var canSubmitBootstrapEmail: Bool {
        ClientEmail.isValidOptional(bootstrapEmailDraft)
    }

    var displayName: String {
        client?.displayName ?? "Client"
    }

    init(entry: ClientProfileEntry) {
        self.entry = entry
        if case .directory(let seed) = entry {
            client = seed
        }
    }

    func load() async {
        switch entry {
        case .directory:
            await loadDossier()
        case .fromAppointment(let appointment):
            let email = ClientEmail.validatedOptional(appointment.clientEmail ?? "")
            await bootstrapClient(from: appointment, email: email)
            if client != nil {
                await loadDossier()
            }
        }
    }

    func reloadDossier() async {
        await loadDossier()
    }

    func loadPhotosIfNeeded() async {
        guard photos.isEmpty, !isLoadingPhotos else { return }
        await reloadPhotos()
    }

    func reloadPhotos() async {
        guard let clientId = client?.id else { return }

        isLoadingPhotos = true
        photosError = nil
        defer { isLoadingPhotos = false }

        do {
            photos = try await AdminAPIClient.shared.fetchClientPhotos(id: clientId)
        } catch {
            photosError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func uploadPhoto(data: Data, filename: String, mimeType: String) async -> Bool {
        guard let clientId = client?.id else { return false }

        isUploadingPhoto = true
        photosError = nil
        defer { isUploadingPhoto = false }

        do {
            let photo = try await AdminAPIClient.shared.uploadClientPhoto(
                id: clientId,
                imageData: data,
                filename: filename,
                mimeType: mimeType
            )
            photos.insert(photo, at: 0)
            return true
        } catch {
            photosError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func deletePhoto(_ photo: ClientPhoto) async -> Bool {
        guard let clientId = client?.id else { return false }

        photosError = nil
        do {
            try await AdminAPIClient.shared.deleteClientPhoto(
                id: clientId,
                photoId: photo.id,
                blobUrl: photo.blobUrl
            )
            photos.removeAll { $0.id == photo.id }
            return true
        } catch {
            photosError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func saveNotes() async -> Bool {
        guard let clientId = client?.id else { return false }
        guard notesDirty else { return true }

        isSavingNotes = true
        notesError = nil
        defer { isSavingNotes = false }

        do {
            try await AdminAPIClient.shared.updateClientNotes(id: clientId, notes: notes)
            savedNotes = notes
            return true
        } catch {
            notesError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func updateNotesDraft(_ text: String) {
        notes = text
    }

    func submitBootstrapEmail() async -> Bool {
        bootstrapEmailTouched = true
        guard ClientEmail.isValidOptional(bootstrapEmailDraft) else {
            bootstrapError = ClientEmail.validationMessage
            return false
        }
        guard case .fromAppointment(let appointment) = entry else { return false }

        await bootstrapClient(
            from: appointment,
            email: ClientEmail.validatedOptional(bootstrapEmailDraft)
        )
        guard client != nil else { return false }

        awaitingBootstrapEmail = false
        await loadDossier()
        return true
    }

    func saveIdentity(firstName: String?, lastName: String?, email: String?) async -> Bool {
        guard let clientId = client?.id else { return false }

        if let email, !ClientEmail.isValidOptional(email) {
            identityError = ClientEmail.validationMessage
            return false
        }
        let validatedEmail = email.flatMap { ClientEmail.validatedOptional($0) }

        isSavingIdentity = true
        identityError = nil
        defer { isSavingIdentity = false }

        do {
            let updated = try await AdminAPIClient.shared.updateClientIdentity(
                id: clientId,
                payload: ClientIdentityPayload(
                    firstName: firstName,
                    lastName: lastName,
                    email: validatedEmail
                )
            )
            client = mergeClient(updated)
            return true
        } catch let error as AdminAPIError {
            identityError = AdminAPIResponseParser.clientEmailErrorMessage(from: error)
            return false
        } catch {
            identityError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private(set) var isClearingNoShowFlag = false
    private(set) var noShowFlagError: String?

    var showsNoShowFlag: Bool {
        crmStats.noShowFlag || client?.noShowFlag == true
    }

    func clearNoShowFlag() async -> Bool {
        guard let clientId = client?.id else { return false }

        isClearingNoShowFlag = true
        noShowFlagError = nil
        defer { isClearingNoShowFlag = false }

        do {
            let updated = try await AdminAPIClient.shared.clearClientNoShowFlag(id: clientId)
            client = mergeClient(updated)
            crmStats = ClientHistoryCrmStats(
                totalBookings: crmStats.totalBookings,
                lifetimeValue: crmStats.lifetimeValue,
                hasVaultedCard: crmStats.hasVaultedCard,
                riskFlag: crmStats.riskFlag,
                lastBookedAt: crmStats.lastBookedAt,
                strikeCount: crmStats.strikeCount,
                noShowCount: updated.noShowCount ?? crmStats.noShowCount,
                noShowFlag: false
            )
            return true
        } catch {
            noShowFlagError =
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    // MARK: - Private

    private func bootstrapClient(from appointment: Appointment, email: String?) async {
        guard client == nil else { return }

        let phone = appointment.clientPhone?.filter(\.isNumber) ?? ""
        guard !phone.isEmpty else {
            bootstrapError = "This booking has no phone number, so a client profile cannot be opened."
            return
        }

        isBootstrapping = true
        bootstrapError = nil
        defer { isBootstrapping = false }

        do {
            client = try await AdminAPIClient.shared.bootstrapClient(
                phone: phone,
                firstName: appointment.clientFirstName,
                lastName: appointment.clientLastName,
                email: email
            )
        } catch let error as AdminAPIError {
            bootstrapError = AdminAPIResponseParser.clientEmailErrorMessage(from: error)
        } catch {
            bootstrapError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadDossier() async {
        guard let clientId = client?.id else { return }

        isLoadingDossier = true
        dossierError = nil
        defer { isLoadingDossier = false }

        async let historyTask = AdminAPIClient.shared.fetchClientHistory(id: clientId)
        async let notesTask = AdminAPIClient.shared.fetchClientNotes(id: clientId)

        do {
            let historyResponse = try await historyTask
            history = historyResponse.appointments
            crmStats = historyResponse.crmStats
            if let existing = client {
                client = Client(
                    id: existing.id,
                    firstName: existing.firstName,
                    lastName: existing.lastName,
                    email: existing.email,
                    phone: existing.phone,
                    riskFlag: historyResponse.crmStats.riskFlag || existing.riskFlag,
                    hasVaultedCard: historyResponse.crmStats.hasVaultedCard || existing.hasVaultedCard,
                    lastBookingAt: existing.lastBookingAt,
                    stats: ClientCrmStats(
                        bookingCount: historyResponse.crmStats.totalBookings,
                        ltv: historyResponse.crmStats.lifetimeValue
                    ),
                    strikeCount: existing.strikeCount,
                    noShowCount: historyResponse.crmStats.noShowCount,
                    noShowFlag: historyResponse.crmStats.noShowFlag,
                    hasConsented: existing.hasConsented,
                    consentFormUrl: existing.consentFormUrl
                )
            }
        } catch {
            dossierError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        do {
            let loadedNotes = try await notesTask
            notes = loadedNotes
            savedNotes = loadedNotes
        } catch {
            if notesError == nil {
                notesError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func mergeClient(_ updated: Client) -> Client {
        Client(
            id: updated.id,
            firstName: updated.firstName,
            lastName: updated.lastName,
            email: updated.email,
            phone: updated.phone,
            riskFlag: crmStats.riskFlag || updated.riskFlag,
            hasVaultedCard: crmStats.hasVaultedCard || updated.hasVaultedCard,
            lastBookingAt: updated.lastBookingAt ?? client?.lastBookingAt,
            stats: ClientCrmStats(
                bookingCount: crmStats.totalBookings,
                ltv: crmStats.lifetimeValue
            ),
            strikeCount: updated.strikeCount ?? client?.strikeCount,
            noShowCount: updated.noShowCount ?? client?.noShowCount,
            noShowFlag: updated.noShowFlag ?? client?.noShowFlag,
            hasConsented: updated.hasConsented ?? client?.hasConsented,
            consentFormUrl: updated.consentFormUrl ?? client?.consentFormUrl
        )
    }
}
