import Foundation

/// Builds `multipart/form-data` bodies with a unique boundary.
struct MultipartFormDataBuilder: Sendable {
    let boundary: String
    private var body = Data()

    nonisolated init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    nonisolated mutating func appendField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    nonisolated mutating func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data
    ) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    nonisolated mutating func finalize() -> Data {
        append("--\(boundary)--\r\n")
        return body
    }

    nonisolated var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Builds a site-image upload body off the main actor (for `AdminAPIClient` actor methods).
    nonisolated static func makeSiteImageUpload(
        id: String,
        imageData: Data,
        caption: String?,
        format: WebsiteUploadFileFormat
    ) -> (body: Data, contentType: String) {
        var form = MultipartFormDataBuilder()
        form.appendField(name: "id", value: id)
        form.appendFile(
            name: "file",
            filename: format.filename,
            mimeType: format.mimeType,
            data: imageData
        )
        if let caption {
            form.appendField(name: "caption", value: caption)
        }
        return (form.finalize(), form.contentType)
    }

    /// Caption-only update — `id` + `caption` fields (no file) for `POST /api/upload`.
    nonisolated static func makeSiteImageCaptionOnly(
        id: String,
        caption: String
    ) -> (body: Data, contentType: String) {
        var form = MultipartFormDataBuilder()
        form.appendField(name: "id", value: id)
        form.appendField(name: "caption", value: caption)
        return (form.finalize(), form.contentType)
    }

    private nonisolated mutating func append(_ string: String) {
        append(string, to: &body)
    }

    private nonisolated func append(_ string: String, to data: inout Data) {
        guard let encoded = string.data(using: .utf8) else { return }
        data.append(encoded)
    }
}

enum WebsiteUploadFileFormat: Sendable {
    case jpeg
    case png

    nonisolated var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        }
    }

    nonisolated var filename: String {
        switch self {
        case .jpeg: return "upload.jpg"
        case .png: return "upload.png"
        }
    }

    nonisolated static func detect(from data: Data) -> WebsiteUploadFileFormat {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return .png }
        return .jpeg
    }
}
