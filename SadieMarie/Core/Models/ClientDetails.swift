import Foundation

// MARK: - Client history

/// CRM stats returned with `GET /api/admin/clients/{id}/appointments`.
struct ClientHistoryCrmStats: Hashable, Sendable {
    let totalBookings: Int
    let lifetimeValue: Double
    let hasVaultedCard: Bool
    let riskFlag: Bool
    let lastBookedAt: String?
    let strikeCount: Int

    nonisolated init(
        totalBookings: Int = 0,
        lifetimeValue: Double = 0,
        hasVaultedCard: Bool = false,
        riskFlag: Bool = false,
        lastBookedAt: String? = nil,
        strikeCount: Int = 0
    ) {
        self.totalBookings = totalBookings
        self.lifetimeValue = lifetimeValue
        self.hasVaultedCard = hasVaultedCard
        self.riskFlag = riskFlag
        self.lastBookedAt = lastBookedAt
        self.strikeCount = strikeCount
    }

    private enum CodingKeys: String, CodingKey {
        case totalBookings
        case lifetimeValue
        case hasVaultedCard
        case riskFlag
        case lastBookedAt
        case strikeCount
    }
}

extension ClientHistoryCrmStats: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalBookings: try container.decodeIfPresent(Int.self, forKey: .totalBookings) ?? 0,
            lifetimeValue: try container.decodeIfPresent(Double.self, forKey: .lifetimeValue) ?? 0,
            hasVaultedCard: try container.decodeIfPresent(Bool.self, forKey: .hasVaultedCard) ?? false,
            riskFlag: try container.decodeIfPresent(Bool.self, forKey: .riskFlag) ?? false,
            lastBookedAt: try container.decodeIfPresent(String.self, forKey: .lastBookedAt),
            strikeCount: try container.decodeIfPresent(Int.self, forKey: .strikeCount) ?? 0
        )
    }
}

struct ClientHistoryResponse: Hashable, Sendable {
    let appointments: [Appointment]
    let crmStats: ClientHistoryCrmStats

    nonisolated init(appointments: [Appointment], crmStats: ClientHistoryCrmStats) {
        self.appointments = appointments
        self.crmStats = crmStats
    }

    private enum CodingKeys: String, CodingKey {
        case appointments
        case crmStats
    }
}

extension ClientHistoryResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            appointments: try container.decode([Appointment].self, forKey: .appointments),
            crmStats: try container.decodeIfPresent(ClientHistoryCrmStats.self, forKey: .crmStats)
                ?? ClientHistoryCrmStats()
        )
    }
}

// MARK: - Photos

struct ClientPhoto: Identifiable, Hashable, Sendable {
    let id: Int
    let blobUrl: String
    let uploadedAt: String

    nonisolated init(id: Int, blobUrl: String, uploadedAt: String) {
        self.id = id
        self.blobUrl = blobUrl
        self.uploadedAt = uploadedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case blobUrl
        case uploadedAt
    }
}

extension ClientPhoto: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            blobUrl: try container.decode(String.self, forKey: .blobUrl),
            uploadedAt: try container.decode(String.self, forKey: .uploadedAt)
        )
    }
}

extension ClientPhoto: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(blobUrl, forKey: .blobUrl)
        try container.encode(uploadedAt, forKey: .uploadedAt)
    }
}

struct ClientPhotosResponse: Hashable, Sendable {
    let photos: [ClientPhoto]

    nonisolated init(photos: [ClientPhoto]) {
        self.photos = photos
    }

    private enum CodingKeys: String, CodingKey {
        case photos
    }
}

extension ClientPhotosResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        if let array = try? [ClientPhoto](from: decoder) {
            self.init(photos: array)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(photos: try container.decodeIfPresent([ClientPhoto].self, forKey: .photos) ?? [])
    }
}

// MARK: - Notes

/// Single row from `client_notes` (`GET /api/admin/clients/{id}/notes`).
struct ClientNote: Identifiable, Hashable, Sendable {
    let id: Int
    let clientId: String
    let notes: String
    let isPinned: Bool
    let createdAt: String

    nonisolated init(
        id: Int,
        clientId: String,
        notes: String,
        isPinned: Bool = false,
        createdAt: String
    ) {
        self.id = id
        self.clientId = clientId
        self.notes = notes
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

extension ClientNote: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case clientId
        case notes
        case isPinned
        case createdAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            clientId: try container.decode(String.self, forKey: .clientId),
            notes: try container.decode(String.self, forKey: .notes),
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false,
            createdAt: try container.decode(String.self, forKey: .createdAt)
        )
    }
}

/// `GET /api/admin/clients/{id}/notes` → `{ "notes": [ClientNote, ...] }`.
struct ClientNotesListResponse: Sendable {
    let notes: [ClientNote]

    nonisolated init(notes: [ClientNote] = []) {
        self.notes = notes
    }
}

extension ClientNotesListResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case notes
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rows = try? container.decode([ClientNote].self, forKey: .notes) {
            self.init(notes: rows)
            return
        }
        self.init(notes: [])
    }
}

/// `POST /api/admin/clients/{id}/notes` → `{ "note": ClientNote }`.
struct ClientNoteCreateResponse: Sendable {
    let note: ClientNote

    nonisolated init(note: ClientNote) {
        self.note = note
    }
}

extension ClientNoteCreateResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case note
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(note: try container.decode(ClientNote.self, forKey: .note))
    }
}

extension Array where Element == ClientNote {
    /// Matches web `latestNoteByCreatedAt` — text shown in the private-notes field.
    nonisolated func latestNoteText() -> String {
        guard !isEmpty else { return "" }
        return self.max(by: { $0.createdAt < $1.createdAt })?.notes ?? ""
    }
}

struct ClientNotesPatchBody: Encodable, Sendable {
    let notes: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notes, forKey: .notes)
    }

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case notes
    }
}

// MARK: - Bootstrap & identity

struct BootstrapClientBody: Encodable, Sendable {
    let phone: String
    let firstName: String?
    let lastName: String?
    let email: String?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phone, forKey: .phone)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(email, forKey: .email)
    }

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case phone
        case firstName
        case lastName
        case email
    }
}

struct ClientMutationResponse: Hashable, Sendable {
    let client: Client

    nonisolated init(client: Client) {
        self.client = client
    }

    private enum CodingKeys: String, CodingKey {
        case client
    }
}

extension ClientMutationResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(client: try container.decode(Client.self, forKey: .client))
    }
}

extension ClientMutationResponse: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(client, forKey: .client)
    }
}

struct ClientIdentityPayload: Encodable, Sendable {
    let firstName: String?
    let lastName: String?
    let email: String?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        // Explicit null clears email on the server when the admin empties the field.
        try container.encode(email, forKey: .email)
    }

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case email
    }
}

// MARK: - Appointments

struct AppointmentStatusPatchBody: Encodable, Sendable {
    let status: String
    /// When `status` is `no-show`, `true` charges 100% off-session; `false` marks no-show with a strike only.
    let chargeNoShow: Bool?

    init(status: String, chargeNoShow: Bool? = nil) {
        self.status = status
        self.chargeNoShow = chargeNoShow
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(chargeNoShow, forKey: .chargeNoShow)
    }

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case chargeNoShow
    }
}

/// Response from `PATCH /api/admin/appointments/{id}/status`.
struct AppointmentStatusUpdateResponse: Decodable, Sendable {
    let calCancelError: String?
    let noShowCharge: NoShowChargePayload?

    private enum CodingKeys: String, CodingKey {
        case calCancelError
        case noShowCharge
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calCancelError = try container.decodeIfPresent(String.self, forKey: .calCancelError)
        noShowCharge = try container.decodeIfPresent(NoShowChargePayload.self, forKey: .noShowCharge)
    }
}

struct NoShowChargePayload: Decodable, Sendable {
    let paymentIntentId: String?
    let amountCents: Int?
    let currency: String?
}

struct ReschedulePayload: Encodable, Sendable {
    let newCalUid: String
    let newBookingTime: String
    let newEndTime: String?
    let oldCalUid: String?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(newCalUid, forKey: .newCalUid)
        try container.encode(newBookingTime, forKey: .newBookingTime)
        try container.encodeIfPresent(newEndTime, forKey: .newEndTime)
        try container.encodeIfPresent(oldCalUid, forKey: .oldCalUid)
    }

    nonisolated func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case newCalUid
        case newBookingTime
        case newEndTime
        case oldCalUid
    }
}

struct AdminReschedulePayload: Encodable, Sendable {
    let start: String
    let eventTypeId: Int

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(eventTypeId, forKey: .eventTypeId)
    }

    nonisolated func encodedJSON() throws -> Data {
        // CamelCase — matches web/admin JSON.stringify payloads.
        try JSONEncoder().encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case start
        case eventTypeId
    }
}

struct AdminRescheduleResponse: Decodable, Sendable {
    let calCancelError: String?

    private enum CodingKeys: String, CodingKey {
        case calCancelError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calCancelError = try container.decodeIfPresent(String.self, forKey: .calCancelError)
    }
}

// MARK: - Profile entry

enum ClientProfileEntry: Identifiable, Hashable, Sendable {
    case directory(Client)
    case fromAppointment(Appointment)

    var id: String {
        switch self {
        case .directory(let client):
            return "client-\(client.id)"
        case .fromAppointment(let appointment):
            return "apt-\(appointment.id)"
        }
    }
}

// MARK: - JSON encoding

enum AdminRequestEncoder {
    nonisolated static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
}
