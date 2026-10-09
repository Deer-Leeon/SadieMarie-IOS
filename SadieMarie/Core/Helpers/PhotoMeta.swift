import Foundation

/// A bookable service the photo editor can use to suggest alt text and a file name.
struct PhotoServiceOption: Identifiable, Hashable, Sendable {
    let slug: String
    let title: String
    let category: String

    var id: String { slug }

    /// Same bookable set the website photo editor uses.
    static func bookable(from services: [Service]) -> [PhotoServiceOption] {
        services.compactMap { service in
            guard service.isActive,
                  !service.isGroup,
                  let slug = service.slug?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !slug.isEmpty,
                  service.calEventId != nil,
                  let duration = service.durationMins,
                  duration > 0
            else { return nil }
            return PhotoServiceOption(
                slug: slug,
                title: service.title,
                category: service.category
            )
        }
    }
}

/// Alt text and file name sent with a website image upload or a text-only save.
struct SiteImagePhotoFields: Sendable, Equatable {
    var altText: String
    var fileName: String
    var photoSubject: String

    static func stored(from slot: SiteImageSlot) -> SiteImagePhotoFields {
        SiteImagePhotoFields(
            altText: slot.altText ?? "",
            fileName: slot.fileName ?? "",
            photoSubject: slot.photoSubject ?? ""
        )
    }
}

/// Suggested alt text and file name. Matches `lib/photo-meta.ts` on the website.
enum PhotoMeta {
    static let portraitSubject = "portrait"
    static let fileNameMaxLength = 80
    static let altMaxLength = 300

    struct Copy: Equatable, Sendable {
        var alt: String
        var fileName: String
    }

    static func suggest(subject: String, services: [PhotoServiceOption]) -> Copy {
        if subject == portraitSubject {
            return Copy(
                alt: "Sadie Marie, lash and brow studio in Lehi, Utah",
                fileName: "sadie-marie-lehi-utah"
            )
        }

        guard let service = services.first(where: { $0.slug == subject }) else {
            return Copy(alt: "", fileName: "")
        }

        let fileName = fileName(from: service.title)
        let category = service.category.lowercased()
        if category.contains("lash") {
            return Copy(
                alt: "\(service.title) by Sadie Marie at Serenity Studios in Lehi, Utah",
                fileName: fileName
            )
        }
        if category.contains("brow") {
            return Copy(
                alt: "\(service.title) by Sadie Marie in Lehi, Utah",
                fileName: fileName
            )
        }
        return Copy(
            alt: "\(service.title) at Sadie Marie in Lehi, Utah",
            fileName: fileName
        )
    }

    static func fileName(from title: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = slug.isEmpty ? "sadie-marie" : slug
        return clipFileName("\(base)-lehi-utah")
    }

    static func clipFileName(_ raw: String) -> String {
        String(raw.prefix(fileNameMaxLength))
            .replacingOccurrences(of: "-+$", with: "", options: .regularExpression)
    }
}
