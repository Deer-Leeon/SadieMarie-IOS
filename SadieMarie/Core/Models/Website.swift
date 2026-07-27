import Foundation

// MARK: - Slot identity

/// Known CMS image slots on the public site (7 total).
enum WebsiteSlotId: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case homeHero = "home_hero"
    case aboutProfile = "about_profile"
    case portfolio1 = "portfolio_1"
    case portfolio2 = "portfolio_2"
    case portfolio3 = "portfolio_3"
    case portfolio4 = "portfolio_4"
    case portfolio5 = "portfolio_5"

    var id: String { rawValue }
}

// MARK: - API models

/// One image slot from `GET /api/admin/website/settings` (or upload response).
struct SiteImageSlot: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let imageURL: String?
    let caption: String?

    nonisolated init(id: String, imageURL: String? = nil, caption: String? = nil) {
        self.id = id
        self.imageURL = imageURL
        self.caption = caption
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Site image slot missing `id`."
                )
            )
        }
        // Settings API: `image_url` (snake_case decoder → `imageUrl`). Upload API: `url`.
        imageURL =
            try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? container.decodeIfPresent(String.self, forKey: .imageURLSnake)
            ?? container.decodeIfPresent(String.self, forKey: .uploadURL)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(caption, forKey: .caption)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "imageUrl"
        case imageURLSnake = "image_url"
        case uploadURL = "url"
        case caption
    }

    /// HTML default labels for portfolio tiles on the public site.
    static let portfolioDefaults: [String: String] = [
        WebsiteSlotId.portfolio1.rawValue: "Classic Lashes",
        WebsiteSlotId.portfolio2.rawValue: "Glow Facial",
        WebsiteSlotId.portfolio3.rawValue: "Brow Lamination",
        WebsiteSlotId.portfolio4.rawValue: "Volume Set",
        WebsiteSlotId.portfolio5.rawValue: "Skin Treatment",
    ]

    /// Caption to show on a portfolio tile.
    /// - `caption == nil` → fall back to `defaults[id]` (HTML default).
    /// - `caption == ""` → explicitly hidden (`nil` return).
    /// - otherwise → the stored caption string.
    func displayCaption(defaults: [String: String] = SiteImageSlot.portfolioDefaults) -> String? {
        guard let caption else {
            return defaults[id]
        }
        if caption.isEmpty {
            return nil
        }
        return caption
    }
}

// MARK: - PATCH caption

struct PatchWebsiteSlotRequest: Sendable {
    let id: String
    let caption: String
}

extension PatchWebsiteSlotRequest: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(caption, forKey: .caption)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case caption
    }
}

struct PatchWebsiteSlotResponse: Decodable, Sendable {
    let slot: SiteImageSlot

    nonisolated init(slot: SiteImageSlot) {
        self.slot = slot
    }

    nonisolated init(from decoder: Decoder) throws {
        if let decoded = try? SiteImageSlot(from: decoder) {
            slot = decoded
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decoded = try container.decodeIfPresent(SiteImageSlot.self, forKey: .slot) {
            slot = decoded
            return
        }
        throw DecodingError.keyNotFound(
            CodingKeys.slot,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "PATCH website slot response missing `slot`."
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case slot
    }
}

struct WebsiteSettingsResponse: Decodable, Hashable, Sendable {
    let slots: [SiteImageSlot]

    nonisolated init(slots: [SiteImageSlot]) {
        self.slots = slots
    }

    nonisolated init(from decoder: Decoder) throws {
        if let array = try? [SiteImageSlot](from: decoder) {
            slots = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try container.decodeIfPresent([SiteImageSlot].self, forKey: .slots) {
            slots = list
            return
        }
        if let list = try container.decodeIfPresent([SiteImageSlot].self, forKey: .images) {
            slots = list
            return
        }
        if let list = try container.decodeIfPresent([SiteImageSlot].self, forKey: .data) {
            slots = list
            return
        }
        if let settings = try container.decodeIfPresent(WebsiteSettingsPayload.self, forKey: .settings) {
            slots = settings.slots
            return
        }

        slots = []
    }

    private enum CodingKeys: String, CodingKey {
        case slots
        case images
        case data
        case settings
    }

    private struct WebsiteSettingsPayload: Codable, Sendable {
        let slots: [SiteImageSlot]
    }
}

/// Upload response from `POST /api/upload`.
struct SiteImageUploadResponse: Decodable, Sendable {
    let slot: SiteImageSlot?
    let imageURL: String?
    let url: String?
    let slotId: String?
    let caption: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slot = try container.decodeIfPresent(SiteImageSlot.self, forKey: .slot)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        url =
            try container.decodeIfPresent(String.self, forKey: .url)
            ?? imageURL
            ?? slot?.imageURL
        slotId = try container.decodeIfPresent(String.self, forKey: .slotId)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
    }

    private enum CodingKeys: String, CodingKey {
        case slot
        case imageURL = "imageUrl"
        case url
        case slotId = "id"
        case caption
    }

    nonisolated var resolvedImageURL: String? {
        slot?.imageURL ?? imageURL ?? url
    }
}

// MARK: - Local metadata

enum WebsiteSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case corePages = "Core Pages"
    case portfolio = "Portfolio & Gallery Collage"

    var id: String { rawValue }
}

enum WebsiteSlotVariant: Hashable, Sendable {
    case heroCard
    case portfolioTile
}

/// Hardcoded slot layout (mirrors web admin `WebsiteSlotMeta`).
struct WebsiteSlotMeta: Hashable, Sendable {
    let id: WebsiteSlotId
    let section: WebsiteSection
    let label: String
    /// Width ÷ height (matches web `ImageUploader` aspect classes).
    let aspectRatio: CGFloat
    let variant: WebsiteSlotVariant

    var requiresCaption: Bool {
        variant == .portfolioTile
    }

    static let catalog: [WebsiteSlotMeta] = [
        WebsiteSlotMeta(
            id: .homeHero,
            section: .corePages,
            label: "Homepage Hero Image",
            aspectRatio: 4 / 5,
            variant: .heroCard
        ),
        WebsiteSlotMeta(
            id: .aboutProfile,
            section: .corePages,
            label: "About Section Portrait",
            aspectRatio: 3 / 4,
            variant: .heroCard
        ),
        WebsiteSlotMeta(
            id: .portfolio1,
            section: .portfolio,
            label: "Classic Lashes",
            aspectRatio: 16 / 9,
            variant: .portfolioTile
        ),
        WebsiteSlotMeta(
            id: .portfolio2,
            section: .portfolio,
            label: "Glow Facial",
            aspectRatio: 16 / 9,
            variant: .portfolioTile
        ),
        WebsiteSlotMeta(
            id: .portfolio3,
            section: .portfolio,
            label: "Brow Lamination",
            aspectRatio: 16 / 9,
            variant: .portfolioTile
        ),
        WebsiteSlotMeta(
            id: .portfolio4,
            section: .portfolio,
            label: "Volume Set",
            aspectRatio: 16 / 9,
            variant: .portfolioTile
        ),
        WebsiteSlotMeta(
            id: .portfolio5,
            section: .portfolio,
            label: "Skin Treatment",
            aspectRatio: 16 / 9,
            variant: .portfolioTile
        ),
    ]

    static func meta(for id: WebsiteSlotId) -> WebsiteSlotMeta {
        catalog.first { $0.id == id } ?? catalog[0]
    }
}

/// API slot merged with local meta for the Website tab UI.
struct WebsiteSlotItem: Identifiable, Hashable, Sendable {
    let meta: WebsiteSlotMeta
    var slot: SiteImageSlot

    var id: String { meta.id.rawValue }

    var imageURL: URL? {
        guard let raw = slot.imageURL else { return nil }
        return Self.normalizedImageURL(from: raw)
    }

    /// Resolves CMS image strings to absolute HTTPS URLs (blob CDN, protocol-relative, site-relative).
    static func normalizedImageURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("//") {
            return URL(string: "https:\(trimmed)")
        }

        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                return url
            }
        }

        if !trimmed.contains("://"), trimmed.contains(".") {
            return URL(string: "https://\(trimmed)")
        }

        let path = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        return URL(string: "https://www.sadiemarie.co\(path)")
    }

    var isEmpty: Bool { imageURL == nil }

    static func merged(from apiSlots: [SiteImageSlot]) -> [WebsiteSlotItem] {
        let byID = Dictionary(uniqueKeysWithValues: apiSlots.map { ($0.id, $0) })
        return WebsiteSlotMeta.catalog.map { meta in
            let api = byID[meta.id.rawValue]
                ?? SiteImageSlot(id: meta.id.rawValue, imageURL: nil, caption: nil)
            return WebsiteSlotItem(meta: meta, slot: api)
        }
    }
}

// MARK: - Previews

extension SiteImageSlot {
    static let previewHero = SiteImageSlot(
        id: WebsiteSlotId.homeHero.rawValue,
        imageURL: "https://www.sadiemarie.co/images/hero.jpg",
        caption: nil
    )

    static let previewPortfolio = SiteImageSlot(
        id: WebsiteSlotId.portfolio1.rawValue,
        imageURL: nil,
        caption: "Classic Lashes"
    )
}
