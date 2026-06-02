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
    private(set) var isSavingNotes = false
    private(set) var isSavingIdentity = false

    private(set) var bootstrapError: String?
    private(set) var dossierError: String?
    private(set) var notesError: String?
    private(set) var photosError: String?
    private(set) var identityError: String?

    var notesDirty: Bool { notes != savedNotes }

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
        case .fromAppointment:
            await bootstrapIfNeeded()
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

    func saveIdentity(firstName: String?, lastName: String?, email: String?) async -> Bool {
        guard let clientId = client?.id else { return false }

        isSavingIdentity = true
        identityError = nil
        defer { isSavingIdentity = false }

        do {
            let updated = try await AdminAPIClient.shared.updateClientIdentity(
                id: clientId,
                payload: ClientIdentityPayload(
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                )
            )
            client = mergeClient(updated)
            return true
        } catch {
            identityError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    // MARK: - Private

    private func bootstrapIfNeeded() async {
        guard client == nil else { return }
        guard case .fromAppointment(let appointment) = entry else { return }

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
                email: appointment.clientEmail
            )
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
            )
        )
    }
}
