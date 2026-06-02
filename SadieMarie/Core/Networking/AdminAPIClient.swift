import Foundation
import ClerkKit

// MARK: - HTTP method

/// Subset of HTTP verbs we use against the admin API. Keeps call
/// sites self-documenting and avoids stringly-typed mistakes.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Errors

/// Typed error surface for `AdminAPIClient`. Every failure path the
/// client can hit maps to exactly one case so call sites can branch
/// on intent (auth, transport, server, decoding) rather than
/// inspecting opaque `Error` values.
enum AdminAPIError: LocalizedError {
    case invalidEndpoint(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case server(status: Int, body: String?)
    case transport(URLError)
    case decoding(DecodingError)
    case noActiveSession
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "Invalid API endpoint: \(endpoint)"
        case .invalidResponse:
            return "The server returned a malformed response."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don’t have permission to perform that action."
        case .notFound:
            return "The requested resource was not found."
        case .server(let status, let body):
            if let body, !body.isEmpty {
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status))."
        case .transport(let urlError):
            return urlError.localizedDescription
        case .decoding:
            return "Couldn’t read the server’s response."
        case .noActiveSession:
            return "No active Clerk session. Please sign in."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Client

/// Thin async/await client for the Sadie Marie admin API. Pulls the
/// active Clerk session token automatically on every request and
/// injects it as `Authorization: Bearer <jwt>` — callers never have
/// to think about token plumbing.
///
/// Token freshness is owned by Clerk: `Session.getToken()` returns a
/// cached JWT when one is still valid (1-minute TTL), and refreshes
/// from the Clerk backend when it isn't. The token provider is
/// extracted into a closure so tests can inject a deterministic
/// stub without touching the SDK.
actor AdminAPIClient {

    // MARK: Configuration

    static let shared = AdminAPIClient()

    /// Fetches a fresh JWT for the current user. Defaults to Clerk;
    /// override in tests with `init(tokenProvider:)`.
    typealias TokenProvider = @Sendable () async throws -> String

    private let baseURL: URL
    private let session: URLSession
    let decoder: JSONDecoder
    private let tokenProvider: TokenProvider

    init(
        baseURL: URL = URL(string: "https://www.sadiemarie.co/api/admin")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = AdminAPIClient.defaultDecoder(),
        tokenProvider: @escaping TokenProvider = AdminAPIClient.defaultClerkTokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.tokenProvider = tokenProvider
    }

    static func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Decodes JSON off the main actor (safe for `actor AdminAPIClient` call sites under Swift 6).
    nonisolated static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try defaultDecoder().decode(type, from: data)
    }

    private static func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    /// Default token provider: hops to `MainActor` to read
    /// `Clerk.shared.session` (the SDK is `@MainActor`-isolated),
    /// then asks the session for its JWT. Throws
    /// `AdminAPIError.noActiveSession` if there's no session, or
    /// `AdminAPIError.unauthorized` if the SDK returns nil for an
    /// otherwise-present session (e.g. revoked).
    static let defaultClerkTokenProvider: TokenProvider = {
        try await clerkSessionToken()
    }

    // MARK: Public API

    /// Returns the active Clerk session JWT for `Authorization: Bearer` headers.
    static func clerkSessionToken() async throws -> String {
        let session = await MainActor.run { Clerk.shared.session }
        guard let session else {
            throw AdminAPIError.noActiveSession
        }
        guard let jwt = try await session.getToken() else {
            throw AdminAPIError.unauthorized
        }
        return jwt
    }

    /// `GET /api/admin/clients/list` — CRM client directory.
    func fetchClients() async throws -> [Client] {
        let response = try await fetch(
            "clients/list",
            as: ClientsListResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        return response.clients
    }

    /// `GET /api/admin/appointments` — fresh data, no URL cache.
    func fetchBookings() async throws -> AppointmentsResponse {
        try await fetch(
            "appointments",
            as: AppointmentsResponse.self,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    /// `GET /api/admin/availability` — weekly blocks + date overrides.
    func fetchAvailability() async throws -> AvailabilityResponse {
        let data = try await fetchData(
            "availability",
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        let decoded = try Self.decodeJSON(AvailabilityResponse.self, from: data)
        let scheduleId = decoded.schedule.id ?? AvailabilityJSON.parseScheduleId(from: data)
        let response = decoded.withResolvedScheduleId(scheduleId)

        #if DEBUG
        if let id = response.resolvedScheduleId {
            print("✅ [AdminAPIClient] availability scheduleId=\(id)")
        } else {
            print("⚠️ [AdminAPIClient] availability missing scheduleId in response")
        }
        #endif

        return response
    }

    /// `PATCH /api/admin/availability` — update weekly blocks and overrides.
    func saveAvailability(_ payload: AvailabilityUpdateRequest) async throws -> AvailabilityResponse {
        let body = try payload.encodedJSON()

        #if DEBUG
        if let preview = String(data: body, encoding: .utf8) {
            print("🌐 [AdminAPIClient] PATCH availability body: \(preview)")
        }
        #endif

        let data = try await fetchData(
            "availability",
            method: .patch,
            body: body,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        let decoded = try Self.decodeJSON(AvailabilityResponse.self, from: data)
        let scheduleId = decoded.schedule.id ?? payload.scheduleId
        return decoded.withResolvedScheduleId(scheduleId)
    }

    /// Site API root (`…/api`) — used for routes outside `/api/admin` (e.g. upload).
    var siteAPIBaseURL: URL {
        baseURL.deletingLastPathComponent()
    }

    /// `DELETE` with query items appended to an admin endpoint path.
    func delete(
        _ endpoint: String,
        queryItems: [URLQueryItem],
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData
    ) async throws {
        var url = try resolveURL(for: endpoint)
        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let composed = components?.url else {
                throw AdminAPIError.invalidEndpoint(endpoint)
            }
            url = composed
        }
        _ = try await performAuthenticatedDataRequest(
            url: url,
            method: .delete,
            cachePolicy: cachePolicy
        )
    }

    /// Authenticated request to an absolute URL (e.g. `…/api/upload`).
    func performAuthenticatedDataRequest(
        url: URL,
        method: HTTPMethod = .get,
        body: Data? = nil,
        additionalHeaders: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> Data {
        let token = try await tokenProvider()
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (header, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        if let body {
            request.httpBody = body
        }

        print("🌐 [AdminAPIClient] \(method.rawValue) \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    /// Raw response bytes (validated HTTP status).
    func fetchData(
        _ endpoint: String,
        queryItems: [URLQueryItem] = [],
        method: HTTPMethod = .get,
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> Data {
        var url = try resolveURL(for: endpoint)
        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let composed = components?.url else {
                throw AdminAPIError.invalidEndpoint(endpoint)
            }
            url = composed
        }
        return try await performAuthenticatedDataRequest(
            url: url,
            method: method,
            body: body,
            cachePolicy: cachePolicy
        )
    }

    /// Fetch and decode a JSON response from the admin API. The
    /// active Clerk session token is fetched automatically and
    /// injected as `Authorization: Bearer <token>` — no `token`
    /// parameter required at the call site.
    ///
    /// - Parameters:
    ///   - endpoint: Path appended to `baseURL` (e.g. `"bookings"` or
    ///     `"clients/123"`). Leading slashes are tolerated.
    ///   - type: The `Decodable` type to decode the response into.
    ///     Defaults to `T.self` so call sites can rely on inference.
    ///   - method: HTTP method, defaults to `.get`.
    ///   - body: Optional pre-encoded JSON body (for POST/PATCH/etc).
    /// - Returns: The decoded value of type `T`.
    /// - Throws: `AdminAPIError` describing the failure category.
    func fetch<T: Decodable>(
        _ endpoint: String,
        as type: T.Type = T.self,
        method: HTTPMethod = .get,
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> T {
        do {
            let token = try await tokenProvider()
            let request = try makeRequest(
                endpoint: endpoint,
                token: token,
                method: method,
                body: body,
                cachePolicy: cachePolicy
            )

            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            do {
                return try Self.decodeJSON(T.self, from: data)
            } catch let error as DecodingError {
                print("❌ [AdminAPIClient] \(method.rawValue) \(endpoint) decoding failed: \(error)")
                #if DEBUG
                if endpoint.contains("availability"), let body = String(data: data, encoding: .utf8) {
                    print("❌ [AdminAPIClient] availability response preview: \(String(body.prefix(1200)))")
                }
                #endif
                throw AdminAPIError.decoding(error)
            }
        } catch let error as AdminAPIError {
            print("❌ [AdminAPIClient] \(method.rawValue) \(endpoint) failed: \(error.localizedDescription)")
            throw error
        } catch let error as DecodingError {
            throw AdminAPIError.decoding(error)
        } catch let error as URLError {
            print("❌ [AdminAPIClient] \(method.rawValue) \(endpoint) transport failed: \(error.code.rawValue) \(error.localizedDescription)")
            throw AdminAPIError.transport(error)
        } catch {
            print("❌ [AdminAPIClient] \(method.rawValue) \(endpoint) unknown failure: \(error)")
            throw AdminAPIError.unknown(error)
        }
    }

    // MARK: Private helpers

    private func makeRequest(
        endpoint: String,
        token: String,
        method: HTTPMethod,
        body: Data?,
        cachePolicy: URLRequest.CachePolicy
    ) throws -> URLRequest {
        let url = try resolveURL(for: endpoint)
        print("🌐 [AdminAPIClient] \(method.rawValue) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// Builds `…/api/admin/<endpoint>`. Uses `appendingPathComponent` so a
    /// relative segment like `"appointments"` does not replace the `admin`
    /// path segment (which `URL(string:relativeTo:)` would do).
    private func resolveURL(for endpoint: String) throws -> URL {
        let trimmed = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            throw AdminAPIError.invalidEndpoint(endpoint)
        }

        var url = baseURL
        for segment in trimmed.split(separator: "/") {
            url = url.appendingPathComponent(String(segment))
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AdminAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw AdminAPIError.unauthorized
        case 403:
            throw AdminAPIError.forbidden
        case 404:
            throw AdminAPIError.notFound
        default:
            let body = String(data: data, encoding: .utf8)
            throw AdminAPIError.server(status: http.statusCode, body: body)
        }
    }
}
