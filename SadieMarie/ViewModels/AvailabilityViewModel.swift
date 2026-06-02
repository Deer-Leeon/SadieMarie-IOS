import Foundation
import Observation

@MainActor
@Observable
final class AvailabilityViewModel {

    // MARK: - Published UI state

    private(set) var weekly: [WeeklyDayRow] = WeeklyDayRow.defaultWeek()
    private(set) var overrides: [OverrideRow] = []
    private(set) var timeZone: String = "America/Denver"
    private var scheduleId: Int?

    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var saveSuccessMessage: String?

    var hasUnsavedChanges: Bool {
        Self.weeklySnapshot(weekly) != initialWeeklySnapshot
            || Self.overridesSnapshot(overrides) != initialOverridesSnapshot
    }

    var timeZoneEyebrow: String {
        "Timezone · \(AvailabilityTimeFormat.displayTimeZone(timeZone))"
    }

    // MARK: - Snapshots (dirty detection)

    private var initialWeeklySnapshot: [DaySnapshot] = []
    private var initialOverridesSnapshot: [OverrideSnapshot] = []

    private struct DaySnapshot: Equatable {
        let enabled: Bool
        let startHHMM: String
        let endHHMM: String
    }

    private struct OverrideSnapshot: Equatable {
        let date: String
        let mode: OverrideHoursMode
        let startHHMM: String?
        let endHHMM: String?
    }

    // MARK: - Load / save

    func load() async {
        isLoading = true
        errorMessage = nil
        saveSuccessMessage = nil

        defer { isLoading = false }

        do {
            let response = try await AdminAPIClient.shared.fetchAvailability()
            scheduleId = response.resolvedScheduleId
            timeZone = response.schedule.timeZone
            weekly = Self.buildInitialWeekly(from: response.schedule.availability)
            overrides = Self.buildInitialOverrides(from: response.overrides)
            captureSnapshots()
            AppLogger.syncInfo(
                "Loaded availability (scheduleId=\(scheduleId.map(String.init) ?? "nil"), \(response.schedule.availability.count) blocks, \(response.overrides.count) overrides)."
            )
        } catch let error as AdminAPIError {
            AppLogger.syncError("fetchAvailability failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("fetchAvailability failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard hasUnsavedChanges else { return }

        isSaving = true
        errorMessage = nil
        saveSuccessMessage = nil

        defer { isSaving = false }

        guard let scheduleId, scheduleId > 0 else {
            errorMessage = "Couldn’t determine which schedule to update. Pull to refresh and try again."
            return
        }

        let payload = AvailabilityUpdateRequest(
            scheduleId: scheduleId,
            availability: Self.buildAvailabilityPayload(from: weekly),
            overrides: Self.buildOverridesPayload(from: overrides)
        )

        do {
            let response = try await AdminAPIClient.shared.saveAvailability(payload)
            self.scheduleId = response.resolvedScheduleId ?? scheduleId
            timeZone = response.schedule.timeZone
            weekly = Self.buildInitialWeekly(from: response.schedule.availability)
            overrides = Self.buildInitialOverrides(from: response.overrides)
            captureSnapshots()
            saveSuccessMessage = "Schedule saved."
            AppLogger.syncInfo("Saved availability (\(payload.availability.count) blocks).")
        } catch let error as AdminAPIError {
            AppLogger.syncError("saveAvailability failed: \(error.localizedDescription)")
            errorMessage = message(for: error)
        } catch {
            AppLogger.syncError("saveAvailability failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Weekly mutators

    func setDayEnabled(_ index: Int, enabled: Bool) {
        guard weekly.indices.contains(index) else { return }
        weekly[index].enabled = enabled
    }

    func setDayTime(_ index: Int, start: Date?, end: Date?) {
        guard weekly.indices.contains(index) else { return }
        if let start {
            weekly[index].start = AvailabilityTimeFormat.roundToStride(start)
        }
        if let end {
            weekly[index].end = AvailabilityTimeFormat.roundToStride(end)
        }
        if weekly[index].end <= weekly[index].start {
            weekly[index].end = AvailabilityTimeFormat.time(
                hour: min(AvailabilityTimeFormat.calendar.component(.hour, from: weekly[index].start) + 1, 23),
                minute: AvailabilityTimeFormat.calendar.component(.minute, from: weekly[index].start),
                on: weekly[index].start
            )
        }
    }

    // MARK: - Override mutators

    func addOverride() {
        let today = Calendar.current.startOfDay(for: Date())
        overrides.append(
            OverrideRow(
                id: UUID(),
                date: today,
                mode: .unavailableAllDay,
                start: AvailabilityTimeFormat.defaultStart(on: today),
                end: AvailabilityTimeFormat.defaultEnd(on: today)
            )
        )
        overrides.sort { $0.date < $1.date }
    }

    func removeOverride(id: UUID) {
        overrides.removeAll { $0.id == id }
    }

    func setOverrideDate(id: UUID, date: Date) {
        patchOverride(id: id) { row in
            row.date = Calendar.current.startOfDay(for: date)
            row.start = AvailabilityTimeFormat.time(
                hour: AvailabilityTimeFormat.calendar.component(.hour, from: row.start),
                minute: AvailabilityTimeFormat.calendar.component(.minute, from: row.start),
                on: row.date
            )
            row.end = AvailabilityTimeFormat.time(
                hour: AvailabilityTimeFormat.calendar.component(.hour, from: row.end),
                minute: AvailabilityTimeFormat.calendar.component(.minute, from: row.end),
                on: row.date
            )
        }
    }

    func setOverrideMode(id: UUID, mode: OverrideHoursMode) {
        patchOverride(id: id) { $0.mode = mode }
    }

    func setOverrideTime(id: UUID, start: Date?, end: Date?) {
        patchOverride(id: id) { row in
            if let start {
                row.start = AvailabilityTimeFormat.roundToStride(start)
            }
            if let end {
                row.end = AvailabilityTimeFormat.roundToStride(end)
            }
            if row.mode == .customHours, row.end <= row.start {
                row.end = AvailabilityTimeFormat.time(
                    hour: min(AvailabilityTimeFormat.calendar.component(.hour, from: row.start) + 1, 23),
                    minute: AvailabilityTimeFormat.calendar.component(.minute, from: row.start),
                    on: row.date
                )
            }
        }
    }

    private func patchOverride(id: UUID, update: (inout OverrideRow) -> Void) {
        guard let index = overrides.firstIndex(where: { $0.id == id }) else { return }
        update(&overrides[index])
        overrides.sort { $0.date < $1.date }
    }

    // MARK: - Builders (web parity)

    static func buildInitialWeekly(from blocks: [ScheduleAvailabilityBlock]) -> [WeeklyDayRow] {
        let reference = Date()
        var rows = WeeklyDayRow.defaultWeek(reference: reference)

        for block in blocks {
            let start = AvailabilityTimeFormat.date(fromHHMM: block.startTime, on: reference)
                ?? AvailabilityTimeFormat.defaultStart(on: reference)
            let end = AvailabilityTimeFormat.date(fromHHMM: block.endTime, on: reference)
                ?? AvailabilityTimeFormat.defaultEnd(on: reference)

            for dayIndex in block.days where rows.indices.contains(dayIndex) {
                rows[dayIndex].enabled = true
                rows[dayIndex].start = start
                rows[dayIndex].end = end
            }
        }

        return rows
    }

    static func buildInitialOverrides(from apiOverrides: [ScheduleOverride]) -> [OverrideRow] {
        apiOverrides.compactMap { override in
            guard let date = AvailabilityTimeFormat.date(fromYYYYMMDD: override.date) else { return nil }

            let unavailable = override.startTime == nil && override.endTime == nil
            let start = override.startTime.flatMap { AvailabilityTimeFormat.date(fromHHMM: $0, on: date) }
                ?? AvailabilityTimeFormat.defaultStart(on: date)
            let end = override.endTime.flatMap { AvailabilityTimeFormat.date(fromHHMM: $0, on: date) }
                ?? AvailabilityTimeFormat.defaultEnd(on: date)

            return OverrideRow(
                id: UUID(),
                date: date,
                mode: unavailable ? .unavailableAllDay : .customHours,
                start: start,
                end: end
            )
        }
        .sorted { $0.date < $1.date }
    }

    /// Buckets enabled days with identical hours into one block (disabled days omitted).
    static func buildAvailabilityPayload(from weekly: [WeeklyDayRow]) -> [ScheduleAvailabilityBlock] {
        struct Key: Hashable {
            let start: String
            let end: String
        }

        var buckets: [Key: [Int]] = [:]

        for row in weekly where row.enabled {
            let key = Key(
                start: AvailabilityTimeFormat.hhmm(from: row.start),
                end: AvailabilityTimeFormat.hhmm(from: row.end)
            )
            buckets[key, default: []].append(row.index)
        }

        return buckets.map { key, days in
            ScheduleAvailabilityBlock(
                days: days.sorted(),
                startTime: key.start,
                endTime: key.end
            )
        }
        .sorted { lhs, rhs in
            (lhs.days.min() ?? 0) < (rhs.days.min() ?? 0)
        }
    }

    static func buildOverridesPayload(from rows: [OverrideRow]) -> [ScheduleOverride] {
        rows.map { row in
            if row.mode == .unavailableAllDay {
                return ScheduleOverride(
                    date: AvailabilityTimeFormat.yyyyMMdd(from: row.date),
                    startTime: nil,
                    endTime: nil
                )
            }
            return ScheduleOverride(
                date: AvailabilityTimeFormat.yyyyMMdd(from: row.date),
                startTime: AvailabilityTimeFormat.hhmm(from: row.start),
                endTime: AvailabilityTimeFormat.hhmm(from: row.end)
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Private

    private func captureSnapshots() {
        initialWeeklySnapshot = Self.weeklySnapshot(weekly)
        initialOverridesSnapshot = Self.overridesSnapshot(overrides)
    }

    private static func weeklySnapshot(_ rows: [WeeklyDayRow]) -> [DaySnapshot] {
        rows.map {
            DaySnapshot(
                enabled: $0.enabled,
                startHHMM: AvailabilityTimeFormat.hhmm(from: $0.start),
                endHHMM: AvailabilityTimeFormat.hhmm(from: $0.end)
            )
        }
    }

    private static func overridesSnapshot(_ rows: [OverrideRow]) -> [OverrideSnapshot] {
        rows.map {
            OverrideSnapshot(
                date: AvailabilityTimeFormat.yyyyMMdd(from: $0.date),
                mode: $0.mode,
                startHHMM: $0.mode == .customHours ? AvailabilityTimeFormat.hhmm(from: $0.start) : nil,
                endHHMM: $0.mode == .customHours ? AvailabilityTimeFormat.hhmm(from: $0.end) : nil
            )
        }
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return error.localizedDescription
        case .forbidden:
            return "You’re signed in but don’t have admin access."
        case .decoding:
            return "Couldn’t read the availability response. The API shape may have changed."
        case .transport:
            return "Couldn’t reach the server. Check your connection and try again."
        case .notFound:
            return "Availability API not found. Confirm `/api/admin/availability` is deployed."
        case .server(let status, let body):
            if let body, !body.isEmpty {
                if let data = body.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    return message
                }
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status)). Please try again."
        case .invalidEndpoint, .invalidResponse, .unknown:
            return error.localizedDescription
        }
    }
}

