import Foundation

// MARK: - Service

/// Row from `site_services` (`GET /api/admin/services`).
struct Service: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let calEventId: Int?
    let category: String
    let title: String
    let description: String
    let price: Double
    let durationMins: Int?
    let isActive: Bool
    let slug: String?
    let isGroup: Bool
    let parentId: Int?
    let color: String?
    let displayOrder: Int

    nonisolated init(
        id: Int,
        calEventId: Int? = nil,
        category: String,
        title: String,
        description: String = "",
        price: Double,
        durationMins: Int? = nil,
        isActive: Bool = true,
        slug: String? = nil,
        isGroup: Bool = false,
        parentId: Int? = nil,
        color: String? = nil,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.calEventId = calEventId
        self.category = category
        self.title = title
        self.description = description
        self.price = price
        self.durationMins = durationMins
        self.isActive = isActive
        self.slug = slug
        self.isGroup = isGroup
        self.parentId = parentId
        self.color = color
        self.displayOrder = displayOrder
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        calEventId = try container.decodeIfPresent(Int.self, forKey: .calEventId)
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        price = try Service.decodePrice(from: container)
        durationMins = try container.decodeIfPresent(Int.self, forKey: .durationMins)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
        parentId = try container.decodeIfPresent(Int.self, forKey: .parentId)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(calEventId, forKey: .calEventId)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(durationMins, forKey: .durationMins)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encode(displayOrder, forKey: .displayOrder)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case calEventId
        case category
        case title
        case description
        case price
        case durationMins
        case isActive
        case slug
        case isGroup
        case parentId
        case color
        case displayOrder
    }

    private nonisolated static func decodePrice(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Double {
        if let value = try container.decodeIfPresent(Double.self, forKey: .price) {
            return value
        }
        if let string = try container.decodeIfPresent(String.self, forKey: .price),
           let value = Double(string) {
            return value
        }
        return 0
    }
}

// MARK: - API wrappers

struct ServicesListResponse: Decodable, Sendable {
    let services: [Service]

    nonisolated init(services: [Service]) {
        self.services = services
    }

    nonisolated init(from decoder: Decoder) throws {
        if let array = try? [Service](from: decoder) {
            services = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode([Service].self, forKey: .services)
    }

    private enum CodingKeys: String, CodingKey {
        case services
    }
}

struct ServiceMutationResponse: Decodable, Sendable {
    let service: Service

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        service = try container.decode(Service.self, forKey: .service)
    }

    private enum CodingKeys: String, CodingKey {
        case service
    }
}

// MARK: - Mutations

/// `POST /api/admin/services` body (`length` is minutes; null for groups).
struct CreateServicePayload: Encodable, Sendable {
    let title: String
    let description: String
    let length: Int?
    let price: Double
    let category: String
    let isGroup: Bool
    let parentId: Int?
    let color: String?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encode(price, forKey: .price)
        try container.encode(category, forKey: .category)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(color, forKey: .color)
    }

    nonisolated func encodedJSON() throws -> Data {
        try ServicePayloadEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case title, description, length, price, category, isGroup, parentId, color
    }
}

/// `PATCH /api/admin/services` body.
struct UpdateServicePayload: Encodable, Sendable {
    let dbId: Int
    let calEventId: Int?
    let title: String
    let description: String
    let length: Int?
    let price: Double
    let category: String
    let isGroup: Bool
    let parentId: Int?
    let color: String?

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dbId, forKey: .dbId)
        try container.encodeIfPresent(calEventId, forKey: .calEventId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encode(price, forKey: .price)
        try container.encode(category, forKey: .category)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(color, forKey: .color)
    }

    nonisolated func encodedJSON() throws -> Data {
        try ServicePayloadEncoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case dbId
        case calEventId
        case title, description, length, price, category, isGroup, parentId, color
    }
}

private enum ServicePayloadEncoder {
    nonisolated static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
}

// MARK: - Grouping (client-side)

/// One category section with groups + standalones (mirrors web `ServiceManager` grouping).
struct ServiceCategorySection: Identifiable, Hashable, Sendable {
    let category: String
    let groups: [ServiceGroupSection]
    let standalones: [Service]

    var id: String { category }

    var serviceCount: Int {
        groups.reduce(0) { $0 + 1 + $1.children.count } + standalones.count
    }
}

struct ServiceGroupSection: Identifiable, Hashable, Sendable {
    let group: Service
    let children: [Service]

    var id: Int { group.id }
}

enum ServiceCatalog {
    static let categories = [
        "Lash Services",
        "Brow Services",
        "Teeth Whitening",
    ]

    /// Groups services by category A–Z; nests children under group headers.
    static func groupedCategories(from services: [Service]) -> [ServiceCategorySection] {
        var byCategory: [String: [Service]] = [:]
        for service in services {
            byCategory[service.category, default: []].append(service)
        }

        return byCategory.keys.sorted().map { category in
            let items = byCategory[category] ?? []
            let groupIDs = Set(items.filter(\.isGroup).map(\.id))

            var childrenByParent: [Int: [Service]] = [:]
            for service in items {
                if let parentId = service.parentId, groupIDs.contains(parentId) {
                    childrenByParent[parentId, default: []].append(service)
                }
            }
            for key in childrenByParent.keys {
                childrenByParent[key]?.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }

            let groupRows = items
                .filter(\.isGroup)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                .map { group in
                    ServiceGroupSection(
                        group: group,
                        children: childrenByParent[group.id] ?? []
                    )
                }

            let standalones = items
                .filter { !$0.isGroup && ($0.parentId == nil || !groupIDs.contains($0.parentId!)) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            return ServiceCategorySection(
                category: category,
                groups: groupRows,
                standalones: standalones
            )
        }
    }
}

// MARK: - Formatting

enum ServiceFormat {
    static func price(_ value: Double, prefixFrom: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        if value.rounded(.towardZero) == value {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return prefixFrom ? "From \(formatted)" : formatted
    }
}

// MARK: - Previews

extension Service {
    static let previewGroup = Service(
        id: 1,
        category: "Lash Services",
        title: "Classic Lashes",
        description: "Our signature lash menu.",
        price: 120,
        isGroup: true
    )

    static let previewChild = Service(
        id: 2,
        calEventId: 99,
        category: "Lash Services",
        title: "Classic Full Set",
        description: "Natural mapping, 90 minutes.",
        price: 150,
        durationMins: 90,
        slug: "classic-full-set-abc123",
        parentId: 1
    )

    static let previewStandalone = Service(
        id: 3,
        calEventId: 100,
        category: "Brow Services",
        title: "Brow Lamination",
        description: "Lift and tint.",
        price: 85,
        durationMins: 45,
        slug: "brow-lamination-xyz"
    )
}

