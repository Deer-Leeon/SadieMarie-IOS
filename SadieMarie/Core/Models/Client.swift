import Foundation

// MARK: - CRM stats

/// Booking count and lifetime value for a client row.
struct ClientCrmStats: Hashable, Equatable, Sendable {
    let bookingCount: Int
    let ltv: Double

    init(bookingCount: Int = 0, ltv: Double = 0) {
        self.bookingCount = bookingCount
        self.ltv = ltv
    }
}

extension ClientCrmStats: Decodable {
    private enum CodingKeys: String, CodingKey {
        case bookingCount
        case ltv
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookingCount = try container.decodeIfPresent(Int.self, forKey: .bookingCount) ?? 0
        ltv = try container.decodeIfPresent(Double.self, forKey: .ltv) ?? 0
    }
}

extension ClientCrmStats: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookingCount, forKey: .bookingCount)
        try container.encode(ltv, forKey: .ltv)
    }
}

// MARK: - Client

/// Admin CRM client row from `GET /api/admin/clients/list`.
struct Client: Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let riskFlag: Bool
    let hasVaultedCard: Bool
    /// ISO 8601 — used for “Most recent” sort.
    let lastBookingAt: String?
    let stats: ClientCrmStats
    let strikeCount: Int?
    let noShowCount: Int?
    let noShowAdminCount: Int?
    let noShowAutoCancelCount: Int?
    let noShowAutoRescheduleCount: Int?
    let lateChangeCount: Int?
    let lateChangeCancelCount: Int?
    let lateChangeRescheduleCount: Int?
    let noShowFlag: Bool?
    let noShowWaiveNext: Bool?
    let lateChangeWaiveNext: Bool?
    let hasConsented: Bool?
    let consentFormUrl: String?

    init(
        id: String,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        riskFlag: Bool = false,
        hasVaultedCard: Bool = false,
        lastBookingAt: String? = nil,
        stats: ClientCrmStats = ClientCrmStats(),
        strikeCount: Int? = nil,
        noShowCount: Int? = nil,
        noShowAdminCount: Int? = nil,
        noShowAutoCancelCount: Int? = nil,
        noShowAutoRescheduleCount: Int? = nil,
        lateChangeCount: Int? = nil,
        lateChangeCancelCount: Int? = nil,
        lateChangeRescheduleCount: Int? = nil,
        noShowFlag: Bool? = nil,
        noShowWaiveNext: Bool? = nil,
        lateChangeWaiveNext: Bool? = nil,
        hasConsented: Bool? = nil,
        consentFormUrl: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.riskFlag = riskFlag
        self.hasVaultedCard = hasVaultedCard
        self.lastBookingAt = lastBookingAt
        self.stats = stats
        self.strikeCount = strikeCount
        self.noShowCount = noShowCount ?? strikeCount
        self.noShowAdminCount = noShowAdminCount
        self.noShowAutoCancelCount = noShowAutoCancelCount
        self.noShowAutoRescheduleCount = noShowAutoRescheduleCount
        self.lateChangeCount = lateChangeCount
        self.lateChangeCancelCount = lateChangeCancelCount
        self.lateChangeRescheduleCount = lateChangeRescheduleCount
        self.noShowFlag = noShowFlag
        self.noShowWaiveNext = noShowWaiveNext
        self.lateChangeWaiveNext = lateChangeWaiveNext
        self.hasConsented = hasConsented
        self.consentFormUrl = consentFormUrl
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case email
        case phone
        case riskFlag
        case hasVaultedCard
        case lastBookingAt
        case lastBookedAt
        case stats
        case bookingCount
        case ltv
        case totalBookings
        case lifetimeValue
        case strikeCount
        case noShowCount
        case noShowAdminCount
        case noShowAutoCancelCount
        case noShowAutoRescheduleCount
        case lateChangeCount
        case lateChangeCancelCount
        case lateChangeRescheduleCount
        case noShowFlag
        case noShowWaiveNext
        case lateChangeWaiveNext
        case hasConsented
        case consentFormUrl
    }

    var displayName: String {
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return email ?? phone ?? "Unknown client"
        }
        return parts.joined(separator: " ")
    }

    /// `(801) 555-1234` for 10 digits; `+1 (801) 555-1234` for 11 digits with leading `1`.
    var formattedPhone: String {
        guard let phone, !phone.isEmpty else { return phone ?? "" }
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return phone }

        switch digits.count {
        case 10:
            return Self.formatUS10(digits)
        case 11 where digits.first == "1":
            return "+1 \(Self.formatUS10(String(digits.dropFirst())))"
        default:
            return phone
        }
    }

    var telURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var lastBookingDate: Date? {
        guard let lastBookingAt else { return nil }
        return Client.iso8601.date(from: lastBookingAt)
            ?? Client.iso8601NoFraction.date(from: lastBookingAt)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func formatUS10(_ digits: String) -> String {
        let start = digits.startIndex
        let areaEnd = digits.index(start, offsetBy: 3)
        let midEnd = digits.index(areaEnd, offsetBy: 3)
        let area = digits[start..<areaEnd]
        let mid = digits[areaEnd..<midEnd]
        let last = digits[midEnd...]
        return "(\(area)) \(mid)-\(last)"
    }
}

extension Client: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedId: String
        if let stringId = try? container.decode(String.self, forKey: .id) {
            decodedId = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            decodedId = String(intId)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Client missing `id`."
                )
            )
        }

        let decodedStats: ClientCrmStats
        if let nested = try container.decodeIfPresent(ClientCrmStats.self, forKey: .stats) {
            decodedStats = nested
        } else {
            let bookingCount =
                try container.decodeIfPresent(Int.self, forKey: .bookingCount)
                ?? container.decodeIfPresent(Int.self, forKey: .totalBookings)
                ?? 0
            let ltv =
                try container.decodeIfPresent(Double.self, forKey: .ltv)
                ?? container.decodeIfPresent(Double.self, forKey: .lifetimeValue)
                ?? 0
            decodedStats = ClientCrmStats(bookingCount: bookingCount, ltv: ltv)
        }

        let lastBooking =
            try container.decodeIfPresent(String.self, forKey: .lastBookingAt)
            ?? container.decodeIfPresent(String.self, forKey: .lastBookedAt)

        self.init(
            id: decodedId,
            firstName: try container.decodeIfPresent(String.self, forKey: .firstName),
            lastName: try container.decodeIfPresent(String.self, forKey: .lastName),
            email: try container.decodeIfPresent(String.self, forKey: .email),
            phone: try container.decodeIfPresent(String.self, forKey: .phone),
            riskFlag: try container.decodeIfPresent(Bool.self, forKey: .riskFlag) ?? false,
            hasVaultedCard: try container.decodeIfPresent(Bool.self, forKey: .hasVaultedCard) ?? false,
            lastBookingAt: lastBooking,
            stats: decodedStats,
            strikeCount: try container.decodeIfPresent(Int.self, forKey: .strikeCount),
            noShowCount: try container.decodeIfPresent(Int.self, forKey: .noShowCount),
            noShowAdminCount: try container.decodeIfPresent(Int.self, forKey: .noShowAdminCount),
            noShowAutoCancelCount: try container.decodeIfPresent(Int.self, forKey: .noShowAutoCancelCount),
            noShowAutoRescheduleCount: try container.decodeIfPresent(Int.self, forKey: .noShowAutoRescheduleCount),
            lateChangeCount: try container.decodeIfPresent(Int.self, forKey: .lateChangeCount),
            lateChangeCancelCount: try container.decodeIfPresent(Int.self, forKey: .lateChangeCancelCount),
            lateChangeRescheduleCount: try container.decodeIfPresent(Int.self, forKey: .lateChangeRescheduleCount),
            noShowFlag: try container.decodeIfPresent(Bool.self, forKey: .noShowFlag),
            noShowWaiveNext: try container.decodeIfPresent(Bool.self, forKey: .noShowWaiveNext),
            lateChangeWaiveNext: try container.decodeIfPresent(Bool.self, forKey: .lateChangeWaiveNext),
            hasConsented: try container.decodeIfPresent(Bool.self, forKey: .hasConsented),
            consentFormUrl: try container.decodeIfPresent(String.self, forKey: .consentFormUrl)
        )
    }
}

extension Client: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encode(riskFlag, forKey: .riskFlag)
        try container.encode(hasVaultedCard, forKey: .hasVaultedCard)
        try container.encodeIfPresent(lastBookingAt, forKey: .lastBookingAt)
        try container.encode(stats, forKey: .stats)
    }
}

// MARK: - API envelope

struct ClientsListResponse: Hashable, Equatable, Sendable {
    let clients: [Client]

    init(clients: [Client]) {
        self.clients = clients
    }

    private enum CodingKeys: String, CodingKey {
        case clients
        case data
    }
}

extension ClientsListResponse: Decodable {
    init(from decoder: Decoder) throws {
        if let array = try? [Client](from: decoder) {
            self.init(clients: array)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try container.decodeIfPresent([Client].self, forKey: .clients) {
            self.init(clients: list)
            return
        }
        if let list = try container.decodeIfPresent([Client].self, forKey: .data) {
            self.init(clients: list)
            return
        }

        self.init(clients: [])
    }
}

extension ClientsListResponse: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clients, forKey: .clients)
    }
}

// MARK: - Sorting

enum ClientSortOption: String, CaseIterable, Identifiable, Hashable {
    case name
    case recent
    case ltv
    case bookings

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .name: return "Name (A–Z)"
        case .recent: return "Most recent"
        case .ltv: return "Lifetime value"
        case .bookings: return "Booking count"
        }
    }
}

// MARK: - Previews

extension Client {
    static let previewVaulted = Client(
        id: "client-1",
        firstName: "Morgan",
        lastName: "Reed",
        email: "morgan@example.com",
        phone: "18015551234",
        riskFlag: false,
        hasVaultedCard: true,
        lastBookingAt: "2026-05-20T18:00:00.000Z",
        stats: ClientCrmStats(bookingCount: 12, ltv: 2480)
    )

    static let previewRisk = Client(
        id: "client-2",
        firstName: "Alex",
        lastName: "Kim",
        email: "alex@example.com",
        phone: "8015559876",
        riskFlag: true,
        hasVaultedCard: false,
        lastBookingAt: "2026-04-02T14:00:00.000Z",
        stats: ClientCrmStats(bookingCount: 2, ltv: 320)
    )

    static let previewList: [Client] = [previewVaulted, previewRisk]
}
