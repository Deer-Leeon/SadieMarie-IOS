import Foundation
import Observation

@MainActor
@Observable
final class AvailabilityViewModel {

    // MARK: - Published UI state

    private(set) var weekly: [WeeklyDayRow] = WeeklyDayRow.defaultWeek()
    private(set) var overrides: [OverrideRow] = []
    private(set) var archivedOverrides: [OverrideRow] = []
    var archiveExpanded = false
    private(set) var timeZone: String = "America/Denver"
    private var scheduleId: Int?

    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var saveSuccessMessage: String?

    /// Briefly set after confirming an add so the list can scroll/highlight.
    private(set) var highlightedOverrideId: String?

    var hasUnsavedChanges: Bool {
        Self.weeklySnapshot(weekly) != initialWeeklySnapshot
            || Self.overridesSnapshot(overrides) != initialOverridesSnapshot
            || Self.overridesSnapshot(archivedOverrides) != initialArchivedSnapshot
    }

    /// Custom-hours rows with end ≤ start block save.
    var hasInvalidOverrides: Bool {
        overrides.contains { !$0.hasValidCustomHours }
    }

    var canSave: Bool {
        hasUnsavedChanges && !hasInvalidOverrides && !isSaving
    }

    var timeZoneEyebrow: String {
        "Timezone · \(AvailabilityTimeFormat.displayTimeZone(timeZone))"
    }

    // MARK: - Snapshots (dirty detection)

    private var initialWeeklySnapshot: [DaySnapshot] = []
    private var initialOverridesSnapshot: [OverrideSnapshot] = []
    private var initialArchivedSnapshot: [OverrideSnapshot] = []

    private struct DaySnapshot: Equatable {
        let enabled: Bool
        let startHHMM: String
        let endHHMM: String
    }

    private struct OverrideSnapshot: Equatable {
        let date: String
        let unavailable: Bool
        let startHHMM: String?
        let endHHMM: String?
    }

    // MARK: - Load / save

    func load() async {
        isLoading = true
        errorMessage = nil
        saveSuccessMessage = nil
        highlightedOverrideId = nil

        defer { isLoading = false }

        do {
            let response = try await AdminAPIClient.shared.fetchAvailability()
            scheduleId = response.resolvedScheduleId
            timeZone = response.schedule.timeZone
            weekly = Self.buildInitialWeekly(from: response.schedule.availability)
            let partitioned = Self.partitionOverrides(
                Self.buildInitialOverrides(from: response.overrides)
            )
            overrides = partitioned.active
            archivedOverrides = partitioned.archived
            archiveExpanded = !partitioned.archived.isEmpty
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

        guard !hasInvalidOverrides else {
            errorMessage = "Custom override hours must end after they start."
            return
        }

        guard let scheduleId, scheduleId > 0 else {
            errorMessage = "Couldn’t determine which schedule to update. Pull to refresh and try again."
            return
        }

        let partitioned = Self.partitionOverrides(overrides + archivedOverrides)
        overrides = partitioned.active
        archivedOverrides = partitioned.archived
        if !partitioned.archived.isEmpty {
            archiveExpanded = true
        }

        let payload = AvailabilityUpdateRequest(
            scheduleId: scheduleId,
            availability: Self.buildAvailabilityPayload(from: weekly),
            overrides: Self.buildOverridesPayload(from: partitioned.active + partitioned.archived)
        )

        do {
            let response = try await AdminAPIClient.shared.saveAvailability(payload)
            self.scheduleId = response.resolvedScheduleId ?? scheduleId
            timeZone = response.schedule.timeZone
            weekly = Self.buildInitialWeekly(from: response.schedule.availability)
            let saved = Self.partitionOverrides(
                Self.buildInitialOverrides(from: response.overrides)
            )
            overrides = saved.active
            archivedOverrides = saved.archived
            archiveExpanded = !saved.archived.isEmpty
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

    /// Confirms the add-override sheet. Returns the new row id, or `nil` if validation failed.
    @discardableResult
    func confirmAddOverride(
        date: Date,
        unavailable: Bool,
        start: Date,
        end: Date
    ) -> String? {
        let day = Calendar.current.startOfDay(for: date)
        let dateString = AvailabilityTimeFormat.yyyyMMdd(from: day)
        guard dateString.count == 10,
              AvailabilityTimeFormat.date(fromYYYYMMDD: dateString) != nil else {
            errorMessage = "Pick a valid override date."
            return nil
        }

        let roundedStart = AvailabilityTimeFormat.roundToStride(start)
        let roundedEnd = AvailabilityTimeFormat.roundToStride(end)
        if !unavailable {
            let startHHMM = AvailabilityTimeFormat.hhmm(from: roundedStart)
            let endHHMM = AvailabilityTimeFormat.hhmm(from: roundedEnd)
            guard startHHMM < endHHMM else {
                errorMessage = "Custom override hours must end after they start."
                return nil
            }
        }

        let row = OverrideRow.make(
            date: day,
            unavailable: unavailable,
            start: AvailabilityTimeFormat.time(
                hour: AvailabilityTimeFormat.calendar.component(.hour, from: roundedStart),
                minute: AvailabilityTimeFormat.calendar.component(.minute, from: roundedStart),
                on: day
            ),
            end: AvailabilityTimeFormat.time(
                hour: AvailabilityTimeFormat.calendar.component(.hour, from: roundedEnd),
                minute: AvailabilityTimeFormat.calendar.component(.minute, from: roundedEnd),
                on: day
            )
        )

        let today = StudioTime.todayInStudio()
        if AvailabilityTimeFormat.yyyyMMdd(from: day) < today {
            archivedOverrides = Self.sortedArchivedOverrides(archivedOverrides + [row])
            archiveExpanded = true
        } else {
            overrides.append(row)
            sortOverridesInPlace()
            highlightOverride(id: row.id)
        }
        errorMessage = nil
        return row.id
    }

    func removeOverride(id: String) {
        overrides.removeAll { $0.id == id }
        if highlightedOverrideId == id {
            highlightedOverrideId = nil
        }
    }

    func removeArchivedOverride(id: String) {
        archivedOverrides.removeAll { $0.id == id }
    }

    func setOverrideDate(id: String, date: Date) {
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

    func setOverrideMode(id: String, mode: OverrideHoursMode) {
        patchOverride(id: id) { $0.unavailable = (mode == .unavailableAllDay) }
    }

    func setOverrideUnavailable(id: String, unavailable: Bool) {
        patchOverride(id: id) { $0.unavailable = unavailable }
    }

    func setOverrideTime(id: String, start: Date?, end: Date?) {
        patchOverride(id: id) { row in
            if let start {
                row.start = AvailabilityTimeFormat.roundToStride(start)
            }
            if let end {
                row.end = AvailabilityTimeFormat.roundToStride(end)
            }
            // Do not auto-correct invalid windows — save is blocked until fixed.
        }
    }

    private func patchOverride(id: String, update: (inout OverrideRow) -> Void) {
        guard let index = overrides.firstIndex(where: { $0.id == id }) else { return }
        update(&overrides[index])
        let partitioned = Self.partitionOverrides(overrides)
        overrides = partitioned.active
        if !partitioned.archived.isEmpty {
            archivedOverrides = Self.sortedArchivedOverrides(archivedOverrides + partitioned.archived)
            archiveExpanded = true
        }
    }

    private func sortOverridesInPlace() {
        overrides = Self.sortedOverrides(overrides)
    }

    private func highlightOverride(id: String) {
        highlightedOverrideId = id
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            if highlightedOverrideId == id {
                highlightedOverrideId = nil
            }
        }
    }

    // MARK: - Builders (web parity)

    static func partitionOverrides(_ rows: [OverrideRow]) -> (active: [OverrideRow], archived: [OverrideRow]) {
        let today = StudioTime.todayInStudio()
        var active: [OverrideRow] = []
        var archived: [OverrideRow] = []
        for row in rows {
            if AvailabilityTimeFormat.yyyyMMdd(from: row.date) < today {
                archived.append(row)
            } else {
                active.append(row)
            }
        }
        return (sortedOverrides(active), sortedArchivedOverrides(archived))
    }

    /// Most recent past date first in the archive.
    static func sortedArchivedOverrides(_ rows: [OverrideRow]) -> [OverrideRow] {
        rows.sorted { lhs, rhs in
            let leftDate = AvailabilityTimeFormat.yyyyMMdd(from: lhs.date)
            let rightDate = AvailabilityTimeFormat.yyyyMMdd(from: rhs.date)
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return lhs.id < rhs.id
        }
    }

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
        let rows: [OverrideRow] = apiOverrides.compactMap { override in
            guard let date = AvailabilityTimeFormat.date(fromYYYYMMDD: override.date) else { return nil }

            let unavailable = override.isUnavailableAllDay
            let start: Date
            let end: Date
            if unavailable {
                // Keep UI defaults so toggling to custom hours isn’t empty.
                start = AvailabilityTimeFormat.defaultStart(on: date)
                end = AvailabilityTimeFormat.defaultEnd(on: date)
            } else {
                start = override.startTime.flatMap { AvailabilityTimeFormat.date(fromHHMM: $0, on: date) }
                    ?? AvailabilityTimeFormat.defaultStart(on: date)
                end = override.endTime.flatMap { AvailabilityTimeFormat.date(fromHHMM: $0, on: date) }
                    ?? AvailabilityTimeFormat.defaultEnd(on: date)
            }

            return OverrideRow.make(
                date: date,
                unavailable: unavailable,
                start: start,
                end: end
            )
        }
        return sortedOverrides(rows)
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

    /// Full-replace wire payload. Unavailable days encode as `"00:00"`/`"00:00"`.
    static func buildOverridesPayload(from rows: [OverrideRow]) -> [ScheduleOverride] {
        sortedOverrides(rows).map { row in
            let date = AvailabilityTimeFormat.yyyyMMdd(from: row.date)
            if row.unavailable {
                return ScheduleOverride(date: date, startTime: "00:00", endTime: "00:00")
            }
            return ScheduleOverride(
                date: date,
                startTime: AvailabilityTimeFormat.hhmm(from: row.start),
                endTime: AvailabilityTimeFormat.hhmm(from: row.end)
            )
        }
    }

    /// Soonest-first: date ascending, then id ascending.
    static func sortedOverrides(_ rows: [OverrideRow]) -> [OverrideRow] {
        rows.sorted { lhs, rhs in
            let leftDate = AvailabilityTimeFormat.yyyyMMdd(from: lhs.date)
            let rightDate = AvailabilityTimeFormat.yyyyMMdd(from: rhs.date)
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return lhs.id < rhs.id
        }
    }

    // MARK: - Private

    private func captureSnapshots() {
        initialWeeklySnapshot = Self.weeklySnapshot(weekly)
        initialOverridesSnapshot = Self.overridesSnapshot(overrides)
        initialArchivedSnapshot = Self.overridesSnapshot(archivedOverrides)
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
                unavailable: $0.unavailable,
                startHHMM: $0.unavailable ? nil : AvailabilityTimeFormat.hhmm(from: $0.start),
                endHHMM: $0.unavailable ? nil : AvailabilityTimeFormat.hhmm(from: $0.end)
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
