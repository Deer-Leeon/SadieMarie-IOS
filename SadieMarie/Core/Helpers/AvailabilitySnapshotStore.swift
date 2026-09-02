import Foundation

/// Last successful availability payload so the tab can paint hours
/// immediately on the next launch instead of waiting on Cal.com.
enum AvailabilitySnapshotStore {
    private static let defaultsKey = "admin.availability.lastResponse.v1"

    static func load() -> AvailabilityResponse? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }
        return try? AdminAPIClient.decodeJSON(AvailabilityResponse.self, from: data)
    }

    static func save(_ data: Data) {
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
