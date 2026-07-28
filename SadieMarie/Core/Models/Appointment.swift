import Foundation

/// Mirrors `app/admin/types.ts` → `Appointment`.
/// JSON keys are snake_case; decoding uses `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.
/// Use `typealias Booking = Appointment` in feature code if you prefer the name "Booking".
typealias Booking = Appointment

// MARK: - Appointment

/// A single booking row from the admin appointments API.
struct Appointment: Identifiable, Hashable, Sendable {
    let id: String
    let calUid: String?
    let clientFirstName: String?
    let clientLastName: String?
    /// ISO 8601, e.g. `"2026-05-25T18:30:00.000Z"`.
    let bookingTime: String?
    let endTime: String?
    let serviceName: String?
    let status: String?
    let clientPhone: String?
    let clientEmail: String?
    let servicePrice: Double?
    let serviceDescription: String?
    let serviceSlug: String?
    /// Editor hex from CMS, e.g. `"#C4A484"`. `nil` → neutral row chrome.
    let serviceColor: String?
    let stripeCustomerId: String?
    /// Client-entered notes from Cal booking form ("Additional notes").
    let bookingNotes: String?
    /// True when the linked CRM client has an active no-show attention flag.
    let clientNoShowFlag: Bool

    nonisolated init(
        id: String,
        calUid: String? = nil,
        clientFirstName: String? = nil,
        clientLastName: String? = nil,
        bookingTime: String? = nil,
        endTime: String? = nil,
        serviceName: String? = nil,
        status: String? = nil,
        clientPhone: String? = nil,
        clientEmail: String? = nil,
        servicePrice: Double? = nil,
        serviceDescription: String? = nil,
        serviceSlug: String? = nil,
        serviceColor: String? = nil,
        stripeCustomerId: String? = nil,
        bookingNotes: String? = nil,
        clientNoShowFlag: Bool = false
    ) {
        self.id = id
        self.calUid = calUid
        self.clientFirstName = clientFirstName
        self.clientLastName = clientLastName
        self.bookingTime = bookingTime
        self.endTime = endTime
        self.serviceName = serviceName
        self.status = status
        self.clientPhone = clientPhone
        self.clientEmail = clientEmail
        self.servicePrice = servicePrice
        self.serviceDescription = serviceDescription
        self.serviceSlug = serviceSlug
        self.serviceColor = serviceColor
        self.stripeCustomerId = stripeCustomerId
        self.bookingNotes = bookingNotes
        self.clientNoShowFlag = clientNoShowFlag
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case calUid
        case clientFirstName
        case clientLastName
        case bookingTime
        case endTime
        case serviceName
        case status
        case clientPhone
        case clientEmail
        case servicePrice
        case serviceDescription
        case serviceSlug
        case serviceColor
        case stripeCustomerId
        case bookingNotes
        case clientNoShowFlag
    }
}

extension Appointment: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            calUid: try container.decodeIfPresent(String.self, forKey: .calUid),
            clientFirstName: try container.decodeIfPresent(String.self, forKey: .clientFirstName),
            clientLastName: try container.decodeIfPresent(String.self, forKey: .clientLastName),
            bookingTime: try container.decodeIfPresent(String.self, forKey: .bookingTime),
            endTime: try container.decodeIfPresent(String.self, forKey: .endTime),
            serviceName: try container.decodeIfPresent(String.self, forKey: .serviceName),
            status: try container.decodeIfPresent(String.self, forKey: .status),
            clientPhone: try container.decodeIfPresent(String.self, forKey: .clientPhone),
            clientEmail: try container.decodeIfPresent(String.self, forKey: .clientEmail),
            servicePrice: try container.decodeIfPresent(Double.self, forKey: .servicePrice),
            serviceDescription: try container.decodeIfPresent(String.self, forKey: .serviceDescription),
            serviceSlug: try container.decodeIfPresent(String.self, forKey: .serviceSlug),
            serviceColor: try container.decodeIfPresent(String.self, forKey: .serviceColor),
            stripeCustomerId: try container.decodeIfPresent(String.self, forKey: .stripeCustomerId),
            bookingNotes: try container.decodeIfPresent(String.self, forKey: .bookingNotes),
            clientNoShowFlag: try container.decodeIfPresent(Bool.self, forKey: .clientNoShowFlag) ?? false
        )
    }
}

extension Appointment: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(calUid, forKey: .calUid)
        try container.encodeIfPresent(clientFirstName, forKey: .clientFirstName)
        try container.encodeIfPresent(clientLastName, forKey: .clientLastName)
        try container.encodeIfPresent(bookingTime, forKey: .bookingTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(serviceName, forKey: .serviceName)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(clientPhone, forKey: .clientPhone)
        try container.encodeIfPresent(clientEmail, forKey: .clientEmail)
        try container.encodeIfPresent(servicePrice, forKey: .servicePrice)
        try container.encodeIfPresent(serviceDescription, forKey: .serviceDescription)
        try container.encodeIfPresent(serviceSlug, forKey: .serviceSlug)
        try container.encodeIfPresent(serviceColor, forKey: .serviceColor)
        try container.encodeIfPresent(stripeCustomerId, forKey: .stripeCustomerId)
        try container.encodeIfPresent(bookingNotes, forKey: .bookingNotes)
        try container.encode(clientNoShowFlag, forKey: .clientNoShowFlag)
    }
}

// MARK: - Status

/// Known appointment status values from the API (`status` is still decoded as `String?` on `Appointment`).
enum AppointmentStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case confirmed
    case noShow = "no-show"
    case canceledByAdmin = "canceled_by_admin"
    case canceledByClient = "canceled_by_client"
    case canceledByClientLate = "canceled_by_client_late"
    case canceledBySystem = "canceled_by_system"
}

extension Appointment {
    /// Parsed status when the raw string matches a known `AppointmentStatus` case.
    var appointmentStatus: AppointmentStatus? {
        guard let status else { return nil }
        return AppointmentStatus(rawValue: status.lowercased())
    }
}

// MARK: - API envelope

struct AppointmentsResponse: Sendable {
    let appointments: [Appointment]

    nonisolated init(appointments: [Appointment]) {
        self.appointments = appointments
    }
}

extension AppointmentsResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case appointments
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(appointments: try container.decode([Appointment].self, forKey: .appointments))
    }
}

// MARK: - List filtering

// MARK: - Previews & fixtures

extension Appointment {
    static let mockConfirmed = Appointment(
        id: "apt-confirmed-1",
        calUid: "cal_mock_1",
        clientFirstName: "Leon",
        clientLastName: "Buchmiller",
        bookingTime: "2026-05-26T14:00:00.000Z",
        endTime: "2026-05-26T16:00:00.000Z",
        serviceName: "Hybrid Full Set between Sadie Marie and Leon",
        status: "confirmed",
        clientPhone: "15551234567",
        clientEmail: "client@example.com",
        servicePrice: 185,
        serviceDescription: "Full hybrid lash set",
        serviceSlug: "hybrid-full-set",
        serviceColor: "#8B6F5E",
        stripeCustomerId: "cus_mock_1"
    )

    static let mockPending = Appointment(
        id: "apt-pending-1",
        calUid: "cal_mock_2",
        clientFirstName: "Jamie",
        clientLastName: "Rivera",
        bookingTime: "2026-05-26T18:30:00.000Z",
        endTime: "2026-05-26T20:30:00.000Z",
        serviceName: "Classic between Sadie Marie and Jamie",
        status: "pending",
        clientPhone: nil,
        clientEmail: "jamie@example.com",
        servicePrice: 120,
        serviceDescription: nil,
        serviceSlug: "classic",
        serviceColor: "#C4A484",
        stripeCustomerId: nil
    )

    static let mockNoShow = Appointment(
        id: "apt-noshow-1",
        calUid: "cal_mock_3",
        clientFirstName: "Alex",
        clientLastName: "Kim",
        bookingTime: "2026-05-27T10:00:00.000Z",
        endTime: "2026-05-27T12:00:00.000Z",
        serviceName: "Volume",
        status: "no-show",
        clientPhone: nil,
        clientEmail: nil,
        servicePrice: 165,
        serviceDescription: nil,
        serviceSlug: "volume",
        serviceColor: "#6D5C52",
        stripeCustomerId: nil
    )

    static let mockConfirmedNeutral = Appointment(
        id: "apt-confirmed-2",
        calUid: "cal_mock_4",
        clientFirstName: "Sam",
        clientLastName: "Lee",
        bookingTime: "2026-05-27T14:00:00.000Z",
        endTime: "2026-05-27T16:00:00.000Z",
        serviceName: "Lash Lift & Tint",
        status: "confirmed",
        clientPhone: nil,
        clientEmail: "sam@example.com",
        servicePrice: 95,
        serviceDescription: nil,
        serviceSlug: "lash-lift",
        serviceColor: nil,
        stripeCustomerId: nil
    )

    /// Sample set for list / preview canvas (multiple days and statuses).
    static let mockList: [Appointment] = [
        mockConfirmed,
        mockPending,
        mockNoShow,
        mockConfirmedNeutral
    ]

    /// Default single-row preview fixture.
    static let mock: Appointment = mockConfirmed
}

extension Array where Element == Appointment {
    /// `visibleAppointments` in `DashboardUI` — used for the List view.
    ///
    /// Canceled rows never appear in the list on web. `pending` and `no-show` do appear.
    func visibleForBookingsList() -> [Appointment] {
        filter { apt in
            let s = (apt.status ?? "").lowercased()
            return s != AppointmentStatus.canceledByAdmin.rawValue
                && s != AppointmentStatus.canceledByClient.rawValue
                && s != AppointmentStatus.canceledByClientLate.rawValue
                && s != AppointmentStatus.canceledBySystem.rawValue
        }
    }
}
