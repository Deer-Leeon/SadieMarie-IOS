import Foundation

// MARK: - API response (`GET /api/services`)

/// Top-level JSON from the public services endpoint.
struct PublicServicesResponse: Decodable, Sendable {
    let calUsername: String
    let layout: MenuLayoutMeta
    let services: [PublicCatalogService]

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calUsername = try container.decode(String.self, forKey: .calUsername)
        layout = try container.decode(MenuLayoutMeta.self, forKey: .layout)
        services = try container.decode([PublicCatalogService].self, forKey: .services)
    }

    private enum CodingKeys: String, CodingKey {
        case calUsername
        case layout
        case services
    }
}

/// Layout metadata for grouping and “coming soon” placeholders.
struct MenuLayoutMeta: Decodable, Sendable {
    let categoryColumnRank: [String: Int]
    let comingSoonCategories: [String]
    /// Maps a coming-soon category name → host category column name.
    let comingSoonHostCategory: [String: String]

    nonisolated init(
        categoryColumnRank: [String: Int],
        comingSoonCategories: [String],
        comingSoonHostCategory: [String: String]
    ) {
        self.categoryColumnRank = categoryColumnRank
        self.comingSoonCategories = comingSoonCategories
        self.comingSoonHostCategory = comingSoonHostCategory
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryColumnRank = try container.decode([String: Int].self, forKey: .categoryColumnRank)
        comingSoonCategories = try container.decode([String].self, forKey: .comingSoonCategories)
        comingSoonHostCategory = try container.decode(
            [String: String].self,
            forKey: .comingSoonHostCategory
        )
    }

    private enum CodingKeys: String, CodingKey {
        case categoryColumnRank
        case comingSoonCategories
        case comingSoonHostCategory
    }
}

/// One active row from `site_services` (public catalogue).
/// Blueprint name: `Service` — renamed here to avoid the admin `Service` model.
struct PublicCatalogService: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let category: String
    let title: String
    let description: String
    let price: Double
    let durationMins: Int?
    let slug: String?
    let isGroup: Bool
    let parentId: Int?
    let displayOrder: Int

    nonisolated init(
        id: Int,
        category: String,
        title: String,
        description: String,
        price: Double,
        durationMins: Int?,
        slug: String?,
        isGroup: Bool,
        parentId: Int?,
        displayOrder: Int
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.price = price
        self.durationMins = durationMins
        self.slug = slug
        self.isGroup = isGroup
        self.parentId = parentId
        self.displayOrder = displayOrder
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        durationMins = try container.decodeIfPresent(Int.self, forKey: .durationMins)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        isGroup = try container.decode(Bool.self, forKey: .isGroup)
        parentId = try container.decodeIfPresent(Int.self, forKey: .parentId)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(durationMins, forKey: .durationMins)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(displayOrder, forKey: .displayOrder)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case description
        case price
        case durationMins = "duration_mins"
        case slug
        case isGroup = "is_group"
        case parentId = "parent_id"
        case displayOrder = "display_order"
    }
}

extension PublicCatalogService {
    nonisolated init(admin service: Service) {
        self.init(
            id: service.id,
            category: service.category,
            title: service.title,
            description: service.description,
            price: service.price,
            durationMins: service.durationMins,
            slug: service.slug,
            isGroup: service.isGroup,
            parentId: service.parentId,
            displayOrder: service.displayOrder
        )
    }
}

extension MenuLayoutMeta {
    /// Keep in sync with `GET /api/services` layout in `app/api/services/route.ts`.
    static let websiteDefault = MenuLayoutMeta(
        categoryColumnRank: [
            "Lash Services": 0,
            "Brow Services": 1,
            "Teeth Whitening": 2,
        ],
        comingSoonCategories: ["Teeth Whitening"],
        comingSoonHostCategory: ["Teeth Whitening": "Brow Services"]
    )
}

// MARK: - Grouping (mirrors `groupByCategory` + `renderServicesHtml` in app/route.ts)

/// A category column with top-level rows and optional “coming soon” footers.
struct PublicServiceCategorySection: Identifiable, Hashable, Sendable {
    let category: String
    let rows: [PublicCatalogRow]
    /// Category titles rendered as “Coming soon.” under this section’s host column.
    let comingSoonFooters: [String]

    var id: String { category }
}

enum PublicCatalogRow: Identifiable, Hashable, Sendable {
    case group(PublicCatalogGroup)
    case service(PublicCatalogService)

    var id: String {
        switch self {
        case .group(let group):
            return "group-\(group.id)"
        case .service(let service):
            return "service-\(service.id)"
        }
    }
}

struct PublicCatalogGroup: Identifiable, Hashable, Sendable {
    let header: PublicCatalogService
    let children: [PublicCatalogService]

    var id: Int { header.id }
}

enum PublicServiceCatalogEngine {
    private static let defaultCategoryRank = 50

    /// Full public menu: category sections, group rows, and coming-soon footers.
    static func buildSections(
        services: [PublicCatalogService],
        layout: MenuLayoutMeta
    ) -> [PublicServiceCategorySection] {
        if services.isEmpty, !layout.comingSoonCategories.isEmpty {
            return [
                PublicServiceCategorySection(
                    category: "",
                    rows: [],
                    comingSoonFooters: layout.comingSoonCategories
                ),
            ]
        }

        let comingSoonSet = Set(layout.comingSoonCategories)

        var sections = groupByCategory(services, categoryColumnRank: layout.categoryColumnRank)
            .filter { !comingSoonSet.contains($0.category) }
            .map { category, items in
                PublicServiceCategorySection(
                    category: category,
                    rows: buildCategoryRows(items),
                    comingSoonFooters: []
                )
            }

        var extrasByHost: [String: [String]] = [:]
        for (comingSoon, host) in layout.comingSoonHostCategory {
            guard comingSoonSet.contains(comingSoon) else { continue }
            extrasByHost[host, default: []].append(comingSoon)
        }

        var renderedHosts = Set<String>()
        for index in sections.indices {
            let host = sections[index].category
            if let footers = extrasByHost[host], !footers.isEmpty {
                sections[index] = PublicServiceCategorySection(
                    category: host,
                    rows: sections[index].rows,
                    comingSoonFooters: footers
                )
                renderedHosts.insert(host)
            }
        }

        let orphanFooters = extrasByHost
            .filter { !renderedHosts.contains($0.key) }
            .flatMap(\.value)

        if !orphanFooters.isEmpty, let lastIndex = sections.indices.last {
            let last = sections[lastIndex]
            sections[lastIndex] = PublicServiceCategorySection(
                category: last.category,
                rows: last.rows,
                comingSoonFooters: last.comingSoonFooters + orphanFooters
            )
        }

        return sections
    }

    /// Groups the flat API list by category, preserves row order within each bucket,
    /// then sorts category buckets by `categoryColumnRank` (default 50).
    static func groupByCategory(
        _ services: [PublicCatalogService],
        categoryColumnRank: [String: Int] = [:]
    ) -> [(category: String, services: [PublicCatalogService])] {
        var map: [String: [PublicCatalogService]] = [:]
        var categoryOrder: [String] = []

        for service in services {
            if map[service.category] == nil {
                categoryOrder.append(service.category)
                map[service.category] = []
            }
            map[service.category, default: []].append(service)
        }

        return categoryOrder.compactMap { category in
            guard let items = map[category] else { return nil }
            return (category, items)
        }
        .sorted { lhs, rhs in
            let rankA = categoryColumnRank[lhs.category] ?? defaultCategoryRank
            let rankB = categoryColumnRank[rhs.category] ?? defaultCategoryRank
            if rankA != rankB { return rankA < rankB }
            return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
        }
    }

    private static func buildCategoryRows(
        _ services: [PublicCatalogService]
    ) -> [PublicCatalogRow] {
        let groupIds = Set(services.filter(\.isGroup).map(\.id))

        var childrenByParent: [Int: [PublicCatalogService]] = [:]
        for service in services {
            if let parentId = service.parentId, groupIds.contains(parentId) {
                childrenByParent[parentId, default: []].append(service)
            }
        }

        let topLevel = services.filter { service in
            service.isGroup
                || service.parentId == nil
                || !groupIds.contains(service.parentId!)
        }

        return topLevel.map { row in
            if row.isGroup {
                return .group(
                    PublicCatalogGroup(
                        header: row,
                        children: childrenByParent[row.id] ?? []
                    )
                )
            }
            return .service(row)
        }
    }
}

// MARK: - Formatting (mirrors web `formatPrice` / duration labels)

enum PublicCatalogFormat {
    static func price(_ value: Double) -> String {
        ServiceFormat.price(value, prefixFrom: false)
    }

    static func groupPrice(_ value: Double) -> String {
        ServiceFormat.price(value, prefixFrom: true)
    }

    static func duration(_ minutes: Int) -> String {
        "\(minutes) min"
    }

    static func calBookingURL(slug: String, username: String) -> URL? {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !trimmedSlug.isEmpty else { return nil }
        return URL(string: "https://cal.com/\(trimmedUser)/\(trimmedSlug)")
    }
}
