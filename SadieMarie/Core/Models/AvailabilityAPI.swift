import Foundation

// MARK: - Day index (Sunday = 0)

/// Weekday labels aligned with Cal.com / web admin (`0` = Sunday).
enum DayName: String, CaseIterable, Identifiable, Hashable, Sendable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: String { rawValue }

    /// Cal.com-style index: Sunday `0` … Saturday `6`.
    var index: Int {
        switch self {
        case .sunday: return 0
        case .monday: return 1
        case .tuesday: return 2
        case .wednesday: return 3
        case .thursday: return 4
        case .friday: return 5
        case .saturday: return 6
        }
    }

    var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var apiDayName: String { title }

    static func from(index: Int) -> DayName {
        let clamped = max(0, min(6, index))
        return allCases[clamped]
    }
}

extension DayName: Codable {}

// MARK: - API models

/// Recurring weekly block — multiple days can share the same hours.
struct ScheduleAvailabilityBlock: Hashable, Equatable, Sendable {
    let days: [Int]
    let startTime: String
    let endTime: String

    nonisolated init(days: [Int], startTime: String, endTime: String) {
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case days
        case startTime
        case startTimeSnake = "start_time"
        case endTime
        case endTimeSnake = "end_time"
        case from
        case to
    }
}

extension ScheduleAvailabilityBlock: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try decodeAvailabilityBlockDays(from: container, key: .days)
        startTime = try decodeAvailabilityBlockTime(
            from: container,
            keys: [.startTime, .startTimeSnake, .from]
        )
        endTime = try decodeAvailabilityBlockTime(
            from: container,
            keys: [.endTime, .endTimeSnake, .to]
        )
    }
}

extension ScheduleAvailabilityBlock: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let apiDays = days.sorted().map { apiDayTitle(forIndex: $0) }
        try container.encode(apiDays, forKey: .days)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
    }
}

/// Date-specific exception. `nil` / omitted times = unavailable all day.
struct ScheduleOverride: Hashable, Equatable, Sendable {
    let date: String
    let startTime: String?
    let endTime: String?

    nonisolated init(date: String, startTime: String?, endTime: String?) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case date
        case startTime
        case startTimeSnake = "start_time"
        case endTime
        case endTimeSnake = "end_time"
        case unavailable
    }
}

extension ScheduleOverride: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)

        if try container.decodeIfPresent(Bool.self, forKey: .unavailable) == true {
            startTime = nil
            endTime = nil
            return
        }

        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
            ?? container.decodeIfPresent(String.self, forKey: .startTimeSnake)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
            ?? container.decodeIfPresent(String.self, forKey: .endTimeSnake)
    }
}

extension ScheduleOverride: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
    }
}

/// Schedule metadata + weekly blocks from `GET /api/admin/availability`.
struct AvailabilitySchedule: Hashable, Equatable, Sendable {
    let id: Int?
    let name: String?
    let timeZone: String
    let availability: [ScheduleAvailabilityBlock]

    nonisolated init(
        id: Int? = nil,
        name: String? = nil,
        timeZone: String,
        availability: [ScheduleAvailabilityBlock]
    ) {
        self.id = id
        self.name = name
        self.timeZone = timeZone
        self.availability = availability
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case scheduleId
        case name
        case timeZone
        case timezone
        case availability
    }
}

extension AvailabilitySchedule: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = decodeAvailabilityScheduleId(from: container)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        timeZone =
            try container.decodeIfPresent(String.self, forKey: .timeZone)
            ?? container.decodeIfPresent(String.self, forKey: .timezone)
            ?? "America/Denver"
        availability =
            try container.decodeIfPresent([ScheduleAvailabilityBlock].self, forKey: .availability)
            ?? []
    }
}

extension AvailabilitySchedule: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encode(availability, forKey: .availability)
    }
}

/// Normalized `GET /api/admin/availability` payload for the ViewModel.
struct AvailabilityResponse: Hashable, Equatable, Sendable {
    let schedule: AvailabilitySchedule
    let overrides: [ScheduleOverride]

    nonisolated init(schedule: AvailabilitySchedule, overrides: [ScheduleOverride]) {
        self.schedule = schedule
        self.overrides = overrides
    }

    nonisolated var resolvedScheduleId: Int? {
        guard let id = schedule.id, id > 0 else { return nil }
        return id
    }

    nonisolated func withResolvedScheduleId(_ scheduleId: Int?) -> AvailabilityResponse {
        guard let scheduleId, scheduleId > 0, schedule.id != scheduleId else { return self }
        return AvailabilityResponse(
            schedule: AvailabilitySchedule(
                id: scheduleId,
                name: schedule.name,
                timeZone: schedule.timeZone,
                availability: schedule.availability
            ),
            overrides: overrides
        )
    }
}

extension AvailabilityResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AvailabilityResponseCodingKeys.self)

        if container.contains(.schedule) {
            var inner = try container.decode(AvailabilitySchedule.self, forKey: .schedule)
            if inner.id == nil, let sid = decodeAvailabilityResponseScheduleId(from: container) {
                inner = AvailabilitySchedule(
                    id: sid,
                    name: inner.name,
                    timeZone: inner.timeZone,
                    availability: inner.availability
                )
            }
            schedule = inner
            overrides = try decodeAvailabilityOverrides(from: container)
            return
        }

        if container.contains(.data) {
            let dataDecoder = try container.superDecoder(forKey: .data)
            let dataContainer = try dataDecoder.container(keyedBy: AvailabilityResponseCodingKeys.self)
            if dataContainer.contains(.schedule) {
                var inner = try dataContainer.decode(AvailabilitySchedule.self, forKey: .schedule)
                if inner.id == nil, let sid = decodeAvailabilityResponseScheduleId(from: dataContainer) {
                    inner = AvailabilitySchedule(
                        id: sid,
                        name: inner.name,
                        timeZone: inner.timeZone,
                        availability: inner.availability
                    )
                }
                schedule = inner
            } else {
                var inner = try AvailabilitySchedule(from: dataDecoder)
                if inner.id == nil, let sid = decodeAvailabilityResponseScheduleId(from: dataContainer) {
                    inner = AvailabilitySchedule(
                        id: sid,
                        name: inner.name,
                        timeZone: inner.timeZone,
                        availability: inner.availability
                    )
                }
                schedule = inner
            }
            overrides = try decodeAvailabilityOverrides(from: dataContainer)
            return
        }

        var loadedSchedule = try AvailabilitySchedule(from: decoder)
        if loadedSchedule.id == nil, let sid = decodeAvailabilityResponseScheduleId(from: container) {
            loadedSchedule = AvailabilitySchedule(
                id: sid,
                name: loadedSchedule.name,
                timeZone: loadedSchedule.timeZone,
                availability: loadedSchedule.availability
            )
        }
        schedule = loadedSchedule
        overrides = try decodeAvailabilityOverrides(from: container)
    }
}

/// Body for `PATCH /api/admin/availability`.
struct AvailabilityUpdateRequest: Equatable, Sendable {
    let scheduleId: Int
    let availability: [ScheduleAvailabilityBlock]
    let overrides: [ScheduleOverride]

    func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }
}

extension AvailabilityUpdateRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case scheduleId
        case availability
        case overrides
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(availability, forKey: .availability)
        try container.encode(overrides, forKey: .overrides)
    }
}

// MARK: - JSON helpers

enum AvailabilityJSON {
    static func parseScheduleId(from data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return parseScheduleId(from: object)
    }

    static func parseScheduleId(from object: Any) -> Int? {
        availabilityParseScheduleId(from: object)
    }
}

private func availabilityParseScheduleId(from object: Any) -> Int? {
    guard let dict = object as? [String: Any] else { return nil }

    if let id = positiveJSONInt(dict["scheduleId"]) ?? positiveJSONInt(dict["schedule_id"]) {
        return id
    }

    if let schedule = dict["schedule"] {
        return availabilityParseScheduleId(from: schedule)
    }

    if let data = dict["data"] {
        return availabilityParseScheduleId(from: data)
    }

    return nil
}

// MARK: - Decoding helpers (module-level — safe with default MainActor isolation)

private enum AvailabilityResponseCodingKeys: String, CodingKey {
    case schedule
    case scheduleId
    case data
    case overrides
    case dateOverrides
}

nonisolated private func decodeAvailabilityResponseScheduleId(
    from container: KeyedDecodingContainer<AvailabilityResponseCodingKeys>
) -> Int? {
    if let value = try? container.decode(Int.self, forKey: .scheduleId), value > 0 {
        return value
    }
    if let text = try? container.decode(String.self, forKey: .scheduleId),
       let value = Int(text), value > 0 {
        return value
    }
    return nil
}

nonisolated private func decodeAvailabilityOverrides(
    from container: KeyedDecodingContainer<AvailabilityResponseCodingKeys>
) throws -> [ScheduleOverride] {
    if let overrides = try container.decodeIfPresent([ScheduleOverride].self, forKey: .overrides) {
        return overrides
    }
    if let overrides = try container.decodeIfPresent([ScheduleOverride].self, forKey: .dateOverrides) {
        return overrides
    }
    return []
}

nonisolated private func weekdayIndex(fromAPIValue value: String) -> Int? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let number = Int(normalized), (0...6).contains(number) {
        return number
    }

    switch normalized {
    case "sunday", "sun": return 0
    case "monday", "mon": return 1
    case "tuesday", "tue", "tues": return 2
    case "wednesday", "wed": return 3
    case "thursday", "thu", "thur", "thurs": return 4
    case "friday", "fri": return 5
    case "saturday", "sat": return 6
    default:
        return DayName(rawValue: normalized).map { dayIndex(for: $0) }
    }
}

nonisolated private func dayIndex(for day: DayName) -> Int {
    switch day {
    case .sunday: return 0
    case .monday: return 1
    case .tuesday: return 2
    case .wednesday: return 3
    case .thursday: return 4
    case .friday: return 5
    case .saturday: return 6
    }
}

nonisolated private func apiDayTitle(forIndex index: Int) -> String {
    switch max(0, min(6, index)) {
    case 0: return "Sunday"
    case 1: return "Monday"
    case 2: return "Tuesday"
    case 3: return "Wednesday"
    case 4: return "Thursday"
    case 5: return "Friday"
    default: return "Saturday"
    }
}

nonisolated private func decodeAvailabilityBlockDays<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    key: Key
) throws -> [Int] {
    if let indices = try? container.decode([Int].self, forKey: key) {
        return indices
    }

    if let names = try? container.decode([String].self, forKey: key) {
        return names.compactMap { weekdayIndex(fromAPIValue: $0) }
    }

    throw DecodingError.dataCorrupted(
        DecodingError.Context(
            codingPath: container.codingPath,
            debugDescription: "Expected `days` as [Int] or weekday strings."
        )
    )
}

nonisolated private func decodeAvailabilityBlockTime<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    keys: [Key]
) throws -> String {
    for key in keys {
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
    }
    throw DecodingError.dataCorrupted(
        DecodingError.Context(
            codingPath: container.codingPath,
            debugDescription: "Missing start/end time on availability block."
        )
    )
}

nonisolated private func decodeAvailabilityScheduleId<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>
) -> Int? {
    if let scheduleId = Key(stringValue: "scheduleId") {
        if let value = try? container.decode(Int.self, forKey: scheduleId) { return value }
        if let text = try? container.decode(String.self, forKey: scheduleId), let value = Int(text) {
            return value
        }
    }
    if let id = Key(stringValue: "id") {
        if let value = try? container.decode(Int.self, forKey: id) { return value }
        if let text = try? container.decode(String.self, forKey: id), let value = Int(text) {
            return value
        }
    }
    return nil
}

private func positiveJSONInt(_ value: Any?) -> Int? {
    switch value {
    case let number as Int where number > 0:
        return number
    case let number as Double where number > 0:
        return Int(number)
    case let text as String:
        guard let number = Int(text), number > 0 else { return nil }
        return number
    case let number as NSNumber where number.intValue > 0:
        return number.intValue
    default:
        return nil
    }
}

// MARK: - Fixtures

extension AvailabilityResponse {
    static let previewJSON = """
    {
      "schedule_id": 1,
      "time_zone": "America/Denver",
      "availability": [
        { "days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], "start_time": "09:00", "end_time": "17:00" },
        { "days": ["Saturday"], "start_time": "10:00", "end_time": "14:00" }
      ],
      "overrides": [
        { "date": "2026-05-30", "start_time": null, "end_time": null },
        { "date": "2026-06-01", "start_time": "10:00", "end_time": "14:00" }
      ]
    }
    """

    static let preview = AvailabilityResponse(
        schedule: AvailabilitySchedule(
            id: 1,
            name: "Default",
            timeZone: "America/Denver",
            availability: [
                ScheduleAvailabilityBlock(days: [1, 2, 3, 4, 5], startTime: "09:00", endTime: "17:00"),
                ScheduleAvailabilityBlock(days: [6], startTime: "10:00", endTime: "14:00"),
            ]
        ),
        overrides: [
            ScheduleOverride(date: "2026-05-30", startTime: nil, endTime: nil),
            ScheduleOverride(date: "2026-06-01", startTime: "10:00", endTime: "14:00"),
        ]
    )
}
