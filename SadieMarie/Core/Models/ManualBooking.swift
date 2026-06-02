import Foundation

// MARK: - Service selection

/// Bookable row for manual booking step 1 (mirrors web `ManualBookingServiceOption`).
struct ManualBookingServiceOption: Identifiable, Hashable, Sendable {
    let slug: String
    let title: String
    let description: String
    let category: String
    let price: Double
    let eventTypeId: Int
    let durationMins: Int?

    var id: String { slug }

    var durationLabel: String? {
        guard let durationMins else { return nil }
        return "\(durationMins) min"
    }

    var priceLabel: String {
        ServiceFormat.price(price)
    }

    /// Duration and price only (category is shown on the section header).
    var detailMetaLine: String {
        [durationLabel, priceLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// One website category column in the manual booking picker.
struct ManualBookingServiceSection: Identifiable, Hashable, Sendable {
    let category: String
    let rows: [ManualBookingCatalogRow]
    let comingSoonFooters: [String]

    var id: String { category.isEmpty ? "menu" : category }

    var hasSelectableService: Bool {
        rows.contains { row in
            switch row {
            case .service: return true
            case .group(let group): return !group.children.isEmpty
            }
        }
    }
}

enum ManualBookingCatalogRow: Identifiable, Hashable, Sendable {
    case group(ManualBookingGroupRow)
    case service(ManualBookingServiceOption)

    var id: String {
        switch self {
        case .group(let group):
            return "group-\(group.id)"
        case .service(let service):
            return service.id
        }
    }
}

/// Accordion header (`is_group`) with nested bookable children.
struct ManualBookingGroupRow: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let children: [ManualBookingServiceOption]
}

enum ManualBookingServiceCatalog {
    /// Builds grouped sections matching the public website menu layout.
    static func buildSections(
        publicServices: [PublicCatalogService],
        adminServices: [Service],
        layout: MenuLayoutMeta
    ) -> [ManualBookingServiceSection] {
        let adminById = Dictionary(uniqueKeysWithValues: adminServices.map { ($0.id, $0) })
        let publicSections = PublicServiceCatalogEngine.buildSections(
            services: publicServices,
            layout: layout
        )

        return publicSections.map { section in
            ManualBookingServiceSection(
                category: section.category,
                rows: mapRows(section.rows, adminById: adminById),
                comingSoonFooters: section.comingSoonFooters
            )
        }
        .filter { $0.hasSelectableService || !$0.comingSoonFooters.isEmpty }
    }

    /// Fallback when the public catalogue endpoint is unavailable.
    static func buildSections(from adminServices: [Service]) -> [ManualBookingServiceSection] {
        let sorted = adminServices.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return $0.id < $1.id
        }
        let publicRows = sorted.map(PublicCatalogService.init(admin:))
        return buildSections(
            publicServices: publicRows,
            adminServices: adminServices,
            layout: .websiteDefault
        )
    }

    private static func mapRows(
        _ rows: [PublicCatalogRow],
        adminById: [Int: Service]
    ) -> [ManualBookingCatalogRow] {
        rows.compactMap { row in
            switch row {
            case .service(let publicRow):
                guard let option = option(publicRow: publicRow, admin: adminById[publicRow.id]) else {
                    return nil
                }
                return .service(option)

            case .group(let group):
                let children = group.children.compactMap {
                    option(publicRow: $0, admin: adminById[$0.id])
                }
                let header = adminById[group.header.id]
                return .group(
                    ManualBookingGroupRow(
                        id: group.id,
                        title: header?.title ?? group.header.title,
                        description: (header?.description ?? group.header.description)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        price: header?.price ?? group.header.price,
                        children: children
                    )
                )
            }
        }
    }

    private static func option(publicRow: PublicCatalogService, admin: Service?) -> ManualBookingServiceOption? {
        guard let admin,
              admin.isActive,
              !admin.isGroup,
              let eventTypeId = admin.calEventId else {
            return nil
        }

        let slug = admin.slug ?? publicRow.slug ?? "service-\(admin.id)"
        return ManualBookingServiceOption(
            slug: slug,
            title: admin.title,
            description: admin.description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: admin.category,
            price: admin.price,
            eventTypeId: eventTypeId,
            durationMins: admin.durationMins
        )
    }
}

// MARK: - Slots payload

enum ManualBookingSlotsParser {
    /// Dates (`YYYY-MM-DD`) that have at least one open slot.
    static func datesWithOpenSlots(
        from data: Data,
        notBefore: String? = nil
    ) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let slots = root["slots"] as? [String: Any] else {
            return []
        }

        let minDate = notBefore ?? ""
        return slots.keys
            .filter { date in
                if !minDate.isEmpty, date < minDate { return false }
                return !slotTimes(from: data, date: date).isEmpty
            }
            .sorted()
    }

    /// UTC ISO slot strings for a given studio calendar day.
    static func slotTimes(from data: Data, date: String) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let slots = root["slots"] as? [String: Any],
              let daySlots = slots[date] else {
            return []
        }

        if let times = daySlots as? [String] {
            return times
        }

        if let object = daySlots as? [String: Any], let times = object["time"] as? [String] {
            return times
        }

        return []
    }

    static func slotsByDay(from data: Data, openDates: [String]) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: openDates.map { ($0, slotTimes(from: data, date: $0)) })
    }
}

// MARK: - Cal create response

struct ManualBookingCalBooking: Sendable {
    let uid: String
    let startTime: String?
    let endTime: String?

    static func extract(from data: Data) -> ManualBookingCalBooking? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let booking: [String: Any]
        if let nested = root["data"] as? [String: Any] {
            booking = nested
        } else if let nested = root["booking"] as? [String: Any] {
            booking = nested
        } else {
            booking = root
        }

        guard let uid = booking["uid"] as? String, !uid.isEmpty else { return nil }

        let startTime = (booking["startTime"] as? String) ?? (booking["start"] as? String)
        let endTime = (booking["endTime"] as? String) ?? (booking["end"] as? String)
        return ManualBookingCalBooking(uid: uid, startTime: startTime, endTime: endTime)
    }
}

// MARK: - API bodies

struct ManualBookingCreatePayload: Encodable, Sendable {
    let eventTypeId: Int
    let start: String
    let clientFirstName: String
    let clientLastName: String
    let clientName: String
    let clientEmail: String?
    let clientPhone: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventTypeId, forKey: .eventTypeId)
        try container.encode(start, forKey: .start)
        try container.encode(clientFirstName, forKey: .clientFirstName)
        try container.encode(clientLastName, forKey: .clientLastName)
        try container.encode(clientName, forKey: .clientName)
        try container.encodeIfPresent(clientEmail, forKey: .clientEmail)
        try container.encode(clientPhone, forKey: .clientPhone)
    }

    nonisolated func encodedJSON() throws -> Data {
        try ManualBookingPayloadEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case eventTypeId
        case start
        case clientFirstName
        case clientLastName
        case clientName
        case clientEmail
        case clientPhone
    }
}

struct ManualBookingCompletePayload: Encodable, Sendable {
    let calBookingUid: String
    let clientName: String
    let clientEmail: String?
    let clientPhone: String
    let serviceName: String
    let bookingTime: String?
    let endTime: String?
    let durationMins: Int?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(calBookingUid, forKey: .calBookingUid)
        try container.encode(clientName, forKey: .clientName)
        try container.encodeIfPresent(clientEmail, forKey: .clientEmail)
        try container.encode(clientPhone, forKey: .clientPhone)
        try container.encode(serviceName, forKey: .serviceName)
        try container.encodeIfPresent(bookingTime, forKey: .bookingTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(durationMins, forKey: .durationMins)
    }

    nonisolated func encodedJSON() throws -> Data {
        try ManualBookingPayloadEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case calBookingUid
        case clientName
        case clientEmail
        case clientPhone
        case serviceName
        case bookingTime
        case endTime
        case durationMins
    }
}

// MARK: - Booking pipeline (mirrors `ManualBookingModal.handleBook`)

enum ManualBookingExecution {
    /// `POST /api/admin/manual-booking/create` then `…/complete` with web-identical JSON.
    static func submit(
        service: ManualBookingServiceOption,
        slotIsoUtc: String,
        clientFirstName: String,
        clientLastName: String,
        clientEmail: String?,
        clientPhoneDigits: String,
        api: AdminAPIClient = .shared
    ) async throws {
        let start = try StudioTime.slotToStudioLocalStart(isoUtc: slotIsoUtc)
        let clientName = [clientFirstName, clientLastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let createData = try await api.createManualBooking(
            ManualBookingCreatePayload(
                eventTypeId: service.eventTypeId,
                start: start,
                clientFirstName: clientFirstName,
                clientLastName: clientLastName,
                clientName: clientName,
                clientEmail: clientEmail,
                clientPhone: clientPhoneDigits
            )
        )

        guard let booking = ManualBookingCalBooking.extract(from: createData) else {
            throw ManualBookingExecutionError.missingCalBookingReference
        }

        let bookingTime = booking.startTime ?? slotIsoUtc
        let endTime = StudioTime.bookingEndFromDuration(
            startIso: bookingTime,
            durationMins: service.durationMins
        ) ?? booking.endTime

        do {
            try await api.completeManualBooking(
                ManualBookingCompletePayload(
                    calBookingUid: booking.uid,
                    clientName: clientName,
                    clientEmail: clientEmail,
                    clientPhone: clientPhoneDigits,
                    serviceName: service.title,
                    bookingTime: bookingTime,
                    endTime: endTime,
                    durationMins: service.durationMins
                )
            )
        } catch {
            throw ManualBookingExecutionError.calBookedButSyncFailed(
                calBookingUid: booking.uid,
                underlying: error
            )
        }
    }
}

enum ManualBookingExecutionError: LocalizedError {
    case missingCalBookingReference
    case calBookedButSyncFailed(calBookingUid: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingCalBookingReference:
            return "Cal.com did not return a booking reference. Try another time or reload."
        case .calBookedButSyncFailed(let uid, let underlying):
            let detail = (underlying as? LocalizedError)?.errorDescription ?? underlying.localizedDescription
            return "Booked on Cal.com (\(uid)) but dashboard sync failed: \(detail)"
        }
    }
}

private enum ManualBookingPayloadEncoder {
    /// Manual-booking routes read camelCase bodies (`eventTypeId`, `clientFirstName`, …)
    /// — same as the web admin `JSON.stringify` payloads.
    nonisolated static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }
}

// MARK: - API errors

enum ManualBookingAPIErrorParser {
    static func message(from data: Data?, fallback: String) -> String {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? String,
              !message.isEmpty else {
            return fallback
        }
        return message
    }
}
