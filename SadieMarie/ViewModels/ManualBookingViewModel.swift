import Foundation
import Observation

/// Central state for the multi-visit manual booking wizard (mirrors web `ManualBookingModal`).
///
/// Flow: service → client → date/time → review cart → `create` + `complete` per visit.
/// Shadow Cal event-type routing stays on the server; iOS only sends the real `eventTypeId`.
@MainActor
@Observable
final class ManualBookingViewModel {

    enum Step: Int, CaseIterable {
        case service = 1
        case client = 2
        case schedule = 3
        case summary = 4
    }

    // MARK: - Wizard state

    private(set) var step: Step = .service
    private(set) var serviceSections: [ManualBookingServiceSection] = []
    var selectedService: ManualBookingServiceOption?
    var clientFirstName = ""
    var clientLastName = ""
    var clientEmail = ""
    var clientPhone = ""
    var phoneTouched = false
    var emailTouched = false
    var bookingNotes = ""

    private(set) var pendingVisits: [PendingManualVisit] = []
    private(set) var editingVisitId: UUID?
    private(set) var isLoadingServices = false
    private(set) var isCompleting = false
    private(set) var didCompleteBooking = false
    private(set) var lastBookedCount = 0
    private(set) var bookingProgress: (current: Int, total: Int)?
    private(set) var errorMessage: String?

    // MARK: - Slot picker state

    private(set) var viewYear: Int
    private(set) var viewMonth: Int
    var selectedDate: String?
    var selectedSlot: String?
    private(set) var monthSlots: [String: [String]] = [:]
    private(set) var occupiedStartMs: Set<Int64> = []
    private(set) var availableDates: [String] = []
    private(set) var studioDayDates: Set<String> = []
    private(set) var scheduleAvailability: [ScheduleAvailabilityBlock] = []
    private(set) var scheduleOverrides: [ScheduleOverride] = []
    private(set) var monthLoading = false
    private(set) var monthError: String?

    private let initialDateISO: String?
    private let seedHour: Int?
    private var seededSlotApplied = false
    /// When entering the slot picker to edit a cart row, keep this start selected after month load.
    private var restoreSlotIsoUtc: String?
    private let studioToday: String
    private var mayAdvanceFromEmptyStartMonth = true
    private var slotsLoadGeneration = 0
    private var monthCache: [MonthCacheKey: MonthCacheEntry] = [:]
    private var monthInflight: [MonthCacheKey: Task<MonthCacheEntry, Error>] = [:]

    private struct MonthCacheKey: Hashable {
        let eventTypeId: Int
        let year: Int
        let month: Int
    }

    private struct MonthCacheEntry {
        var monthSlots: [String: [String]]
        var occupiedStartMs: Set<Int64>
        var availableDates: [String]
        var studioDayDates: Set<String>
        var scheduleAvailability: [ScheduleAvailabilityBlock]
        var scheduleOverrides: [ScheduleOverride]
        var error: String?
    }

    enum ClientEntryMode: Hashable {
        case existing
        case new
    }

    /// When set, client fields are locked to this CRM client (book-from-profile).
    private(set) var lockedClient: Client?
    /// After the first visit is assembled, later visits (and an emptied cart) keep this person.
    private(set) var sessionClientLocked = false
    private(set) var directoryClients: [Client] = []
    private(set) var selectedDirectoryClient: Client?
    private(set) var isLoadingDirectoryClients = false
    private(set) var directoryLoadError: String?
    var clientEntryMode: ClientEntryMode = .existing
    var clientSearchQuery = ""

    init(initialDate: Date, seedHour: Int? = nil, prefilledClient: Client? = nil) {
        studioToday = StudioTime.todayInStudio()
        let iso = StudioTime.yyyyMMdd(from: initialDate)
        initialDateISO = iso >= studioToday ? iso : nil
        if let seedHour, (0...23).contains(seedHour) {
            self.seedHour = seedHour
        } else {
            self.seedHour = nil
        }
        mayAdvanceFromEmptyStartMonth = initialDateISO == nil

        let components = StudioTime.calendar.dateComponents([.year, .month], from: initialDate)
        viewYear = components.year ?? StudioTime.calendar.component(.year, from: Date())
        viewMonth = components.month ?? StudioTime.calendar.component(.month, from: Date())

        if let prefilledClient {
            applyClient(prefilledClient, lock: true)
        }
    }

    func applyClient(_ client: Client, lock: Bool) {
        lockedClient = lock ? client : nil
        selectedDirectoryClient = lock ? nil : client
        clientFirstName = client.firstName ?? ""
        clientLastName = client.lastName ?? ""
        clientEmail = ClientEmail.usableDisplay(client.email) ?? ""
        clientPhone = client.formattedPhone.isEmpty ? (client.phone ?? "") : client.formattedPhone
        phoneTouched = false
        emailTouched = false
        clientSearchQuery = ""
        if !lock {
            clientEntryMode = .existing
        }
    }

    func setClientEntryMode(_ mode: ClientEntryMode) {
        guard lockedClient == nil else { return }
        clientEntryMode = mode
        if mode == .new {
            clearSelectedDirectoryClient()
        }
    }

    func selectDirectoryClient(_ client: Client) {
        if selectedDirectoryClient?.id == client.id {
            clearSelectedDirectoryClient()
            return
        }
        applyClient(client, lock: false)
        selectedDirectoryClient = client
        clientEntryMode = .existing
    }

    func clearSelectedDirectoryClient() {
        selectedDirectoryClient = nil
        if lockedClient == nil {
            clientFirstName = ""
            clientLastName = ""
            clientEmail = ""
            clientPhone = ""
            phoneTouched = false
            emailTouched = false
        }
    }

    func clearLockedClient() {
        lockedClient = nil
        selectedDirectoryClient = nil
        clientFirstName = ""
        clientLastName = ""
        clientEmail = ""
        clientPhone = ""
    }

    var filteredDirectoryClients: [Client] {
        let q = clientSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digits = q.filter(\.isNumber)
        guard !q.isEmpty else { return Array(directoryClients.prefix(40)) }
        return directoryClients.filter { client in
            if client.displayName.lowercased().contains(q) { return true }
            if let email = client.email?.lowercased(), email.contains(q) { return true }
            if client.formattedPhone.lowercased().contains(q) { return true }
            if digits.count >= 3, let phone = client.phone {
                let phoneDigits = phone.filter(\.isNumber)
                if phoneDigits.contains(digits) { return true }
            }
            return false
        }
        .prefix(40)
        .map { $0 }
    }

    func loadDirectoryClientsIfNeeded() async {
        guard directoryClients.isEmpty, !isLoadingDirectoryClients else { return }
        isLoadingDirectoryClients = true
        directoryLoadError = nil
        defer { isLoadingDirectoryClients = false }
        do {
            directoryClients = try await AdminAPIClient.shared.fetchClients()
        } catch {
            directoryLoadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Derived

    var parsedClientPhone: ParsedClientPhone? {
        ClientPhone.parse(clientPhone)
    }

    var phoneInvalid: Bool {
        phoneTouched && !clientPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedClientPhone == nil
    }

    var emailInvalid: Bool {
        emailTouched && !ClientEmail.isValidOptional(clientEmail)
    }

    var canAdvanceFromService: Bool {
        selectedService != nil
    }

    var canAdvanceFromClient: Bool {
        if lockedClient != nil {
            return !clientFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !clientLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && parsedClientPhone != nil
                && ClientEmail.isValidOptional(clientEmail)
        }
        if clientEntryMode == .existing {
            return selectedDirectoryClient != nil
                && parsedClientPhone != nil
                && ClientEmail.isValidOptional(clientEmail)
        }
        return !clientFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedClientPhone != nil
            && ClientEmail.isValidOptional(clientEmail)
    }

    /// Client step is skipped when booking from a profile or when the cart already has a person.
    var isClientStepSkipped: Bool {
        lockedClient != nil || sessionClientLocked || !pendingVisits.isEmpty
    }

    var canContinueFromSchedule: Bool {
        selectedSlot != nil && !isCompleting && canAdvanceFromClient
    }

    var canBook: Bool {
        !pendingVisits.isEmpty && !isCompleting && canAdvanceFromClient
    }

    var bookButtonTitle: String {
        if isCompleting {
            if let bookingProgress {
                return "Booking \(bookingProgress.current) of \(bookingProgress.total)…"
            }
            return "Booking…"
        }
        let count = pendingVisits.count
        if count <= 1 {
            return "Book appointment"
        }
        return "Book \(count) appointments"
    }

    var showsModeSwitch: Bool {
        selectedService == nil && step != .summary && !isClientStepSkipped
    }

    var headerTitle: String {
        if step == .summary {
            return clientDisplayName.isEmpty ? "Review visits" : clientDisplayName
        }
        if (step == .schedule || step == .client), let selectedService {
            return selectedService.title
        }
        if isClientStepSkipped {
            return clientDisplayName.isEmpty ? "Book appointment" : clientDisplayName
        }
        return "New appointment"
    }

    var headerSubtitle: String {
        if step == .summary {
            let count = pendingVisits.count
            if count == 1 {
                return "Review 1 visit · then book or add another"
            }
            return "Review \(count) visits · then book or add another"
        }
        if editingVisitId != nil {
            switch step {
            case .service:
                return "Change service · Edit visit"
            case .schedule:
                return "Change date & time · Edit visit"
            case .client, .summary:
                return "Edit visit"
            }
        }
        if !pendingVisits.isEmpty {
            let forClient = clientDisplayName.isEmpty ? "Add visit" : "Add visit for \(clientDisplayName)"
            switch step {
            case .service:
                return "Choose a service · \(forClient)"
            case .schedule:
                return "Pick an open date & time · Add visit"
            case .client, .summary:
                return forClient
            }
        }
        if lockedClient != nil || sessionClientLocked {
            switch step {
            case .service:
                return "Choose a service for \(clientDisplayName) · Step 1 of 3"
            case .schedule:
                return "Pick an open date & time · Step 2 of 3"
            case .summary:
                return "Review visits · Step 3 of 3"
            case .client:
                return "Client details"
            }
        }
        switch step {
        case .service:
            return "Choose a service · Step 1 of 4"
        case .client:
            return "Client details · Step 2 of 4"
        case .schedule:
            return "Pick an open date & time · Step 3 of 4"
        case .summary:
            return "Review visits · Step 4 of 4"
        }
    }

    /// Full name for slot picker summary and `clientName` on the API.
    var clientDisplayName: String {
        clientName
    }

    var clientName: String {
        [clientFirstName, clientLastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var slotsForSelectedDay: [String] {
        guard let selectedDate, availableDates.contains(selectedDate) else { return [] }
        return monthSlots[selectedDate] ?? []
    }

    /// True while the visible month is fetching and we don't yet have a selected day.
    var isTimesLoading: Bool {
        monthLoading && selectedDate == nil
    }

    /// Studio open-hours windows for the selected day (for green/black slot dots).
    var selectedDayWindows: [StudioScheduleWindows.TimeWindow] {
        guard let selectedDate else { return [] }
        return StudioScheduleWindows.windows(
            forYMD: selectedDate,
            availability: scheduleAvailability,
            overrides: scheduleOverrides
        )
    }

    func slotFitsStudioHours(_ slotIsoUtc: String) -> Bool {
        guard let hhmm = StudioTime.slotToStudioLocalHhmm(isoUtc: slotIsoUtc) else {
            return false
        }
        return StudioScheduleWindows.isAppointmentWithinStudioWindows(
            slotLocalHhmm: hhmm,
            durationMins: selectedService?.durationMins,
            windows: selectedDayWindows
        )
    }

    func slotIsOccupied(_ slotIsoUtc: String) -> Bool {
        guard let ms = ManualBookingSlotsParser.epochMs(isoUtc: slotIsoUtc) else {
            return false
        }
        if occupiedStartMs.contains(ms) {
            return true
        }
        return pendingVisits.contains { visit in
            if visit.id == editingVisitId { return false }
            return ManualBookingSlotsParser.epochMs(isoUtc: visit.slotIsoUtc) == ms
        }
    }

    func isStudioDay(_ ymd: String) -> Bool {
        studioDayDates.contains(ymd)
    }

    // MARK: - Lifecycle

    var hasBookableServices: Bool {
        serviceSections.contains(where: \.hasSelectableService)
    }

    func loadServicesIfNeeded() async {
        guard serviceSections.isEmpty, !isLoadingServices else { return }
        isLoadingServices = true
        errorMessage = nil
        defer { isLoadingServices = false }

        do {
            // Prefer the manual-booking endpoint (Cal event-type map), fall back to CMS services.
            let catalog = try? await ServiceCatalogRepository.shared.fetchCatalog()
            if let maps = try? await AdminAPIClient.shared.fetchManualBookingServices(),
               !maps.services.isEmpty {
                let adminFallback = (try? await AdminAPIClient.shared.fetchServices()) ?? []
                if let catalog {
                    serviceSections = ManualBookingServiceCatalog.buildSections(
                        publicServices: catalog.services,
                        adminServices: adminFallback,
                        layout: catalog.layout,
                        eventTypeBySlug: maps.eventTypeBySlug
                    )
                } else {
                    serviceSections = ManualBookingServiceCatalog.buildSections(
                        from: maps,
                        adminServices: adminFallback
                    )
                }
            } else {
                let fetched = try await AdminAPIClient.shared.fetchServices()
                if let catalog {
                    serviceSections = ManualBookingServiceCatalog.buildSections(
                        publicServices: catalog.services,
                        adminServices: fetched,
                        layout: catalog.layout
                    )
                } else {
                    serviceSections = ManualBookingServiceCatalog.buildSections(from: fetched)
                }
            }
        } catch let error as AdminAPIError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBackOrCancel(onCancel: () -> Void) {
        guard !isCompleting else { return }
        errorMessage = nil

        switch step {
        case .service:
            if !pendingVisits.isEmpty {
                discardDraft()
                step = .summary
                return
            }
            onCancel()
        case .client:
            step = .service
            selectedSlot = nil
        case .schedule:
            if isClientStepSkipped {
                step = .service
            } else {
                step = .client
            }
            if editingVisitId == nil {
                selectedSlot = nil
            }
        case .summary:
            if pendingVisits.count == 1, let visit = pendingVisits.first {
                beginEditVisit(visit, jumpToSchedule: true)
            }
        }
    }

    func advanceStep() {
        guard !isCompleting else { return }
        errorMessage = nil

        if step == .schedule {
            _ = commitScheduleToCart()
            return
        }

        if step == .service, isClientStepSkipped {
            guard canAdvanceFromService else { return }
            guard canAdvanceFromClient else {
                errorMessage = "This client needs a first name, last name, and phone before booking."
                return
            }
            enterSchedule(preserveDraftSlot: editingVisitId != nil)
            return
        }

        if step == .client {
            phoneTouched = true
            emailTouched = true
            formatPhoneField()
            guard canAdvanceFromClient else { return }
        }

        guard let next = Step(rawValue: step.rawValue + 1), next != .summary else { return }
        step = next
        if step == .schedule {
            enterSchedule(preserveDraftSlot: false)
        }
    }

    @discardableResult
    func commitScheduleToCart() -> Bool {
        guard let service = selectedService, let slot = selectedSlot, canAdvanceFromClient else {
            return false
        }
        let notes = Self.notesForApi(bookingNotes)
        if let editingVisitId, let index = pendingVisits.firstIndex(where: { $0.id == editingVisitId }) {
            pendingVisits[index] = PendingManualVisit(
                id: editingVisitId,
                service: service,
                slotIsoUtc: slot,
                notes: notes
            )
        } else {
            pendingVisits.append(
                PendingManualVisit(service: service, slotIsoUtc: slot, notes: notes)
            )
        }
        discardDraft()
        sessionClientLocked = true
        step = .summary
        return true
    }

    func beginAddVisit() {
        guard !isCompleting, !pendingVisits.isEmpty else { return }
        errorMessage = nil
        discardDraft()
        step = .service
    }

    func beginEditVisit(_ visit: PendingManualVisit, jumpToSchedule: Bool = false) {
        guard !isCompleting else { return }
        errorMessage = nil
        editingVisitId = visit.id
        selectedService = visit.service
        bookingNotes = visit.notes ?? ""
        selectedSlot = visit.slotIsoUtc
        if let ymd = StudioTime.yyyyMMdd(fromIsoUtc: visit.slotIsoUtc) {
            selectedDate = ymd
        }
        if jumpToSchedule {
            enterSchedule(preserveDraftSlot: true)
        } else {
            step = .service
        }
    }

    func removeVisit(_ id: UUID) {
        guard !isCompleting else { return }
        errorMessage = nil
        pendingVisits.removeAll { $0.id == id }
        if editingVisitId == id {
            discardDraft()
        }
        if pendingVisits.isEmpty {
            discardDraft()
            step = .service
        }
    }

    private func discardDraft() {
        editingVisitId = nil
        selectedService = nil
        selectedSlot = nil
        bookingNotes = ""
        restoreSlotIsoUtc = nil
    }

    private func enterSchedule(preserveDraftSlot: Bool) {
        step = .schedule
        if preserveDraftSlot, let selectedSlot {
            restoreSlotIsoUtc = selectedSlot
            if let ymd = StudioTime.yyyyMMdd(fromIsoUtc: selectedSlot),
               let date = StudioTime.date(fromYYYYMMDD: ymd) {
                let parts = StudioTime.calendar.dateComponents([.year, .month], from: date)
                if let year = parts.year { viewYear = year }
                if let month = parts.month { viewMonth = month }
            }
        } else {
            selectedSlot = nil
            restoreSlotIsoUtc = nil
        }
        Task { await loadMonth(year: viewYear, month: viewMonth) }
    }

    func selectService(_ service: ManualBookingServiceOption) {
        selectedService = service
        errorMessage = nil
    }

    /// Jump straight to the slot picker (admin reschedule / locked flows).
    func prepareSchedule(for service: ManualBookingServiceOption) async {
        selectedService = service
        errorMessage = nil
        selectedSlot = nil
        step = .schedule
        await loadMonth(year: viewYear, month: viewMonth)
    }

    func formatPhoneField() {
        let formatted = ClientPhone.formatInputDisplay(clientPhone)
        if formatted != clientPhone.trimmingCharacters(in: .whitespacesAndNewlines) {
            clientPhone = formatted
        }
    }

    func shiftMonth(by delta: Int) {
        var month = viewMonth + delta
        var year = viewYear
        if month < 1 {
            month = 12
            year -= 1
        } else if month > 12 {
            month = 1
            year += 1
        }
        viewYear = year
        viewMonth = month
        selectedSlot = nil
        monthError = nil

        if let cached = cachedMonth(year: year, month: month) {
            slotsLoadGeneration += 1
            applyMonthEntry(cached)
            monthLoading = false
            prefetchNextMonth(afterYear: year, month: month)
            return
        }

        selectedDate = nil
        Task { await loadMonth(year: year, month: month) }
    }

    func pickDate(_ date: String) {
        guard date >= studioToday, availableDates.contains(date) else { return }
        selectedDate = date
        selectedSlot = nil
    }

    func selectSlot(_ slot: String) {
        selectedSlot = slot
        errorMessage = nil
    }

    /// Starts a fresh booking while preserving a profile-locked client.
    func resetForNextBooking() {
        selectedService = nil
        selectedDate = nil
        selectedSlot = nil
        monthSlots = [:]
        occupiedStartMs = []
        availableDates = []
        studioDayDates = []
        monthError = nil
        errorMessage = nil
        didCompleteBooking = false
        lastBookedCount = 0
        bookingProgress = nil
        phoneTouched = false
        emailTouched = false
        bookingNotes = ""
        pendingVisits = []
        editingVisitId = nil
        restoreSlotIsoUtc = nil
        step = .service

        if lockedClient == nil && !sessionClientLocked {
            selectedDirectoryClient = nil
            clientFirstName = ""
            clientLastName = ""
            clientEmail = ""
            clientPhone = ""
            clientSearchQuery = ""
            clientEntryMode = .existing
        }
    }

    func book(onSuccess: @escaping () -> Void) async {
        guard canBook else { return }

        let trimmedFirst = clientFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = clientLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        emailTouched = true
        if !ClientEmail.isValidOptional(clientEmail) {
            errorMessage = ClientEmail.validationMessage
            return
        }
        let optionalEmail = ClientEmail.validatedOptional(clientEmail)

        guard let parsedPhone = parsedClientPhone else {
            phoneTouched = true
            errorMessage = ClientPhone.validationMessage()
            return
        }

        isCompleting = true
        errorMessage = nil
        bookingProgress = nil
        defer {
            isCompleting = false
            bookingProgress = nil
        }

        let total = pendingVisits.count
        var remaining = pendingVisits
        var bookedCount = 0

        for visit in pendingVisits {
            bookingProgress = (current: bookedCount + 1, total: total)
            do {
                try await ManualBookingExecution.submit(
                    service: visit.service,
                    slotIsoUtc: visit.slotIsoUtc,
                    clientFirstName: trimmedFirst,
                    clientLastName: trimmedLast,
                    clientEmail: optionalEmail,
                    clientPhoneDigits: parsedPhone.digits,
                    bookingNotes: visit.notes
                )
                remaining.removeAll { $0.id == visit.id }
                bookedCount += 1
            } catch let error as ManualBookingExecutionError {
                pendingVisits = remaining
                errorMessage = partialFailureMessage(
                    bookedCount: bookedCount,
                    total: total,
                    detail: error.localizedDescription
                )
                if bookedCount > 0 { onSuccess() }
                return
            } catch let error as ClientEmailValidationError {
                emailTouched = true
                pendingVisits = remaining
                errorMessage = error.localizedDescription
                if bookedCount > 0 { onSuccess() }
                return
            } catch let error as AdminAPIError {
                pendingVisits = remaining
                errorMessage = partialFailureMessage(
                    bookedCount: bookedCount,
                    total: total,
                    detail: manualBookingMessage(for: error)
                )
                if bookedCount > 0 { onSuccess() }
                return
            } catch {
                pendingVisits = remaining
                errorMessage = partialFailureMessage(
                    bookedCount: bookedCount,
                    total: total,
                    detail: error.localizedDescription
                )
                if bookedCount > 0 { onSuccess() }
                return
            }
        }

        pendingVisits = []
        lastBookedCount = bookedCount
        didCompleteBooking = true
        onSuccess()
    }

    private func partialFailureMessage(bookedCount: Int, total: Int, detail: String) -> String {
        if bookedCount == 0 {
            return "Booking failed: \(detail)"
        }
        return "Booked \(bookedCount) of \(total). Visit \(bookedCount + 1) failed: \(detail)"
    }

    private static func notesForApi(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count > 4000 {
            return String(trimmed.prefix(4000))
        }
        return trimmed
    }

    // MARK: - Private

    private func loadMonth(year: Int, month: Int) async {
        guard selectedService != nil else { return }

        slotsLoadGeneration += 1
        let generation = slotsLoadGeneration

        if let cached = cachedMonth(year: year, month: month) {
            if shouldAdvanceFromEmptyStart(entry: cached, year: year, month: month) {
                mayAdvanceFromEmptyStartMonth = false
                let next = nextYearMonth(year: year, month: month)
                viewYear = next.year
                viewMonth = next.month
                await loadMonth(year: next.year, month: next.month)
                return
            }
            applyMonthEntry(cached)
            monthLoading = false
            prefetchNextMonth(afterYear: year, month: month)
            return
        }

        monthLoading = true
        monthError = nil
        if restoreSlotIsoUtc == nil {
            selectedDate = nil
            selectedSlot = nil
        }

        defer {
            if generation == slotsLoadGeneration {
                monthLoading = false
            }
        }

        do {
            let entry = try await fetchAndCacheMonth(year: year, month: month)
            guard generation == slotsLoadGeneration else { return }

            if shouldAdvanceFromEmptyStart(entry: entry, year: year, month: month) {
                mayAdvanceFromEmptyStartMonth = false
                let next = nextYearMonth(year: year, month: month)
                viewYear = next.year
                viewMonth = next.month
                await loadMonth(year: next.year, month: next.month)
                return
            }

            mayAdvanceFromEmptyStartMonth = false
            applyMonthEntry(entry)
            prefetchNextMonth(afterYear: year, month: month)
        } catch let error as AdminAPIError {
            guard generation == slotsLoadGeneration else { return }
            monthError = message(for: error)
        } catch {
            guard generation == slotsLoadGeneration else { return }
            monthError = error.localizedDescription
        }
    }

    private func shouldAdvanceFromEmptyStart(entry: MonthCacheEntry, year: Int, month: Int) -> Bool {
        guard initialDateISO == nil else { return false }
        guard entry.availableDates.isEmpty, mayAdvanceFromEmptyStartMonth else { return false }
        guard entry.error != "No open days left this month." else { return false }
        let todayParts = StudioTime.calendar.dateComponents([.year, .month], from: Date())
        return year == (todayParts.year ?? 0) && month == (todayParts.month ?? 0)
    }

    private func nextYearMonth(year: Int, month: Int) -> (year: Int, month: Int) {
        var nextMonth = month + 1
        var nextYear = year
        if nextMonth > 12 {
            nextMonth = 1
            nextYear += 1
        }
        return (nextYear, nextMonth)
    }

    private func cacheKey(year: Int, month: Int) -> MonthCacheKey? {
        guard let eventTypeId = selectedService?.eventTypeId else { return nil }
        return MonthCacheKey(eventTypeId: eventTypeId, year: year, month: month)
    }

    private func cachedMonth(year: Int, month: Int) -> MonthCacheEntry? {
        guard let key = cacheKey(year: year, month: month) else { return nil }
        return monthCache[key]
    }

    private func applyMonthEntry(_ entry: MonthCacheEntry) {
        monthSlots = entry.monthSlots
        occupiedStartMs = entry.occupiedStartMs
        availableDates = entry.availableDates
        studioDayDates = entry.studioDayDates
        scheduleAvailability = entry.scheduleAvailability
        scheduleOverrides = entry.scheduleOverrides
        monthError = entry.error

        if let restore = restoreSlotIsoUtc {
            restoreSlotIsoUtc = nil
            if let ymd = StudioTime.yyyyMMdd(fromIsoUtc: restore) {
                selectedDate = ymd
            }
            selectedSlot = restore
            return
        }

        let keepSeededSlot = seededSlotApplied && selectedDate == initialDateISO
        if !keepSeededSlot {
            selectedSlot = nil
        }

        if entry.availableDates.isEmpty {
            if let initialDateISO, initialDateISO >= studioToday,
               isStudioDateInMonth(initialDateISO, year: viewYear, month: viewMonth) {
                selectedDate = initialDateISO
            } else {
                selectedDate = nil
            }
            applySeededSlotIfNeeded()
            return
        }

        if let initialDateISO,
           isStudioDateInMonth(initialDateISO, year: viewYear, month: viewMonth),
           entry.availableDates.contains(initialDateISO) || initialDateISO >= studioToday {
            selectedDate = initialDateISO
        } else {
            selectedDate = entry.availableDates.first
        }
        applySeededSlotIfNeeded()
    }

    private func isStudioDateInMonth(_ iso: String, year: Int, month: Int) -> Bool {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]) else {
            return false
        }
        return y == year && m == month
    }

    private func applySeededSlotIfNeeded() {
        guard !seededSlotApplied,
              let seedHour,
              let seedDate = initialDateISO,
              selectedDate == seedDate else {
            return
        }
        let times = monthSlots[seedDate] ?? []
        guard let match = times.first(where: {
            StudioTime.slotMatchesStudioHour(isoUtc: $0, hour: seedHour)
        }) else {
            return
        }
        seededSlotApplied = true
        selectedSlot = match
    }

    private func prefetchNextMonth(afterYear year: Int, month: Int) {
        guard selectedService != nil else { return }
        let next = nextYearMonth(year: year, month: month)
        Task {
            _ = try? await fetchAndCacheMonth(year: next.year, month: next.month)
        }
    }

    private func fetchAndCacheMonth(year: Int, month: Int) async throws -> MonthCacheEntry {
        guard let key = cacheKey(year: year, month: month) else {
            throw AdminAPIError.invalidResponse
        }
        if let cached = monthCache[key] { return cached }
        if let existing = monthInflight[key] {
            return try await existing.value
        }

        let task = Task { () throws -> MonthCacheEntry in
            try await self.performMonthFetch(year: year, month: month)
        }
        monthInflight[key] = task
        do {
            let entry = try await task.value
            monthCache[key] = entry
            monthInflight[key] = nil
            return entry
        } catch {
            monthInflight[key] = nil
            throw error
        }
    }

    private func performMonthFetch(year: Int, month: Int) async throws -> MonthCacheEntry {
        guard let service = selectedService else {
            throw AdminAPIError.invalidResponse
        }

        let rangeStart = studioDateString(year: year, month: month, day: 1)
        let rangeEnd = studioDateString(
            year: year,
            month: month,
            day: StudioTime.lastDayOfMonth(year: year, month: month)
        )
        let queryStart = rangeStart < studioToday ? studioToday : rangeStart

        if queryStart > rangeEnd {
            return MonthCacheEntry(
                monthSlots: [:],
                occupiedStartMs: [],
                availableDates: [],
                studioDayDates: [],
                scheduleAvailability: [],
                scheduleOverrides: [],
                error: "No open days left this month."
            )
        }

        async let slotsDataTask = AdminAPIClient.shared.fetchManualBookingSlots(
            eventTypeId: service.eventTypeId,
            date: queryStart,
            end: rangeEnd
        )
        async let scheduleTask = AdminAPIClient.shared.fetchAvailability()

        let data = try await slotsDataTask
        let schedule = try? await scheduleTask

        var availability: [ScheduleAvailabilityBlock] = []
        var overrides: [ScheduleOverride] = []
        var studioDays: Set<String> = []
        if let schedule {
            availability = schedule.schedule.availability
            overrides = schedule.overrides
            studioDays = StudioScheduleWindows.studioDays(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                availability: availability,
                overrides: overrides
            )
        }

        let openDates = ManualBookingSlotsParser.datesWithOpenSlots(
            from: data,
            notBefore: studioToday
        )
        let slots = ManualBookingSlotsParser.slotsByDay(from: data, openDates: openDates)
        let occupied = ManualBookingSlotsParser.occupiedStartMs(from: data)
        let emptyError = openDates.isEmpty
            ? "No open days in \(StudioTime.monthLabel(year: year, month: month)). Try another month."
            : nil

        return MonthCacheEntry(
            monthSlots: slots,
            occupiedStartMs: occupied,
            availableDates: openDates,
            studioDayDates: studioDays,
            scheduleAvailability: availability,
            scheduleOverrides: overrides,
            error: emptyError
        )
    }

    private func studioDateString(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func message(for error: AdminAPIError) -> String {
        switch error {
        case .unauthorized, .noActiveSession:
            return error.localizedDescription
        case .forbidden:
            return "You’re signed in but don’t have admin access."
        case .decoding:
            return "Couldn’t read the server’s response."
        case .transport:
            return "Couldn’t reach the server. Check your connection and try again."
        case .notFound:
            return "Manual booking API not found. Confirm routes are deployed."
        case .server(let status, let body):
            if let body, !body.isEmpty {
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status))."
        case .invalidEndpoint, .invalidResponse, .unknown:
            return error.localizedDescription
        }
    }

    private func manualBookingMessage(for error: AdminAPIError) -> String {
        switch error {
        case .server(let status, let body) where status == 400:
            let parsed = ManualBookingAPIErrorParser.message(
                from: body?.data(using: .utf8),
                fallback: ClientEmail.validationMessage
            )
            return "Booking failed: \(parsed)"
        default:
            return message(for: error)
        }
    }
}
