import Foundation

/// Studio calendar hold — mirrors `app/admin/types.ts` → `TimeBlock`.
struct TimeBlock: Identifiable, Hashable, Equatable, Sendable {
    let id: String
    /// ISO 8601 start (inclusive).
    let startTime: String
    /// ISO 8601 end.
    let endTime: String
    let note: String?
    let calBookingUid: String?
    let calBookingUids: [String]

    init(
        id: String,
        startTime: String,
        endTime: String,
        note: String? = nil,
        calBookingUid: String? = nil,
        calBookingUids: [String] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.calBookingUid = calBookingUid
        self.calBookingUids = calBookingUids
    }
}

extension TimeBlock: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case startTime
        case startTimeSnake = "start_time"
        case endTime
        case endTimeSnake = "end_time"
        case note
        case calBookingUid
        case calBookingUidSnake = "cal_booking_uid"
        case calBookingUids
        case calBookingUidsSnake = "cal_booking_uids"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startTime =
            try container.decodeIfPresent(String.self, forKey: .startTime)
            ?? container.decode(String.self, forKey: .startTimeSnake)
        endTime =
            try container.decodeIfPresent(String.self, forKey: .endTime)
            ?? container.decode(String.self, forKey: .endTimeSnake)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        calBookingUid =
            try container.decodeIfPresent(String.self, forKey: .calBookingUid)
            ?? container.decodeIfPresent(String.self, forKey: .calBookingUidSnake)
        calBookingUids =
            try container.decodeIfPresent([String].self, forKey: .calBookingUids)
            ?? container.decodeIfPresent([String].self, forKey: .calBookingUidsSnake)
            ?? []
    }
}

struct TimeBlocksResponse: Decodable, Sendable {
    let blocks: [TimeBlock]
}

struct TimeBlockCreateResponse: Decodable, Sendable {
    let block: TimeBlock
    let message: String?
    let roundedUpMinutes: Int?

    private enum CodingKeys: String, CodingKey {
        case block
        case message
        case roundedUpMinutes = "rounded_up_minutes"
    }
}

struct TimeBlockCreateRequest: Encodable, Sendable {
    let start: String
    let end: String
    let note: String?

    func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }
}

typealias TimeBlockUpdateRequest = TimeBlockCreateRequest

struct PositionedTimeBlock: Identifiable, Hashable, Sendable {
    var id: String { block.id }
    let block: TimeBlock
    let topPct: Double
    let heightPct: Double
}

/// Payload for creating a studio time block — single struct avoids async
/// multi-parameter closure corruption when crossing SwiftUI `Task` boundaries.
struct BlockTimeRequest: Sendable {
    let start: Date
    let end: Date
    let note: String

    var trimmedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
