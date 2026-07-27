import Foundation
import Observation

/// Central state for the 3-step manual booking wizard (mirrors web `ManualBookingModal`).
///
/// Flow: service pick → client form → Cal slots → `create` + `complete` admin API calls.
/// Shadow Cal event-type routing stays on the server; iOS only sends the real `eventTypeId`.
@MainActor
@Observable
final class ManualBookingViewModel {

    enum Step: Int, CaseIterable {
        case service = 1
        case client = 2
        case schedule = 3
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

    private(set) var isLoadingServices = false
    private(set) var isCompleting = false
    private(set) var errorMessage: String?

    // MARK: - Slot picker state

    private(set) var viewYear: Int
    private(set) var viewMonth: Int
    var selectedDate: String?
    var selectedSlot: String?
    private(set) var monthSlots: [String: [String]] = [:]
    private(set) var availableDates: [String] = []
    private(set) var studioDayDates: Set<String> = []
    private(set) var scheduleAvailability: [ScheduleAvailabilityBlock] = []
    private(set) var scheduleOverrides: [ScheduleOverride] = []
    private(set) var monthLoading = false
    private(set) var monthError: String?

    private let initialDateISO: String?
    private let studioToday: String
    private var mayAdvanceFromEmptyStartMonth = true
    private var slotsLoadGeneration = 0

    enum ClientEntryMode: Hashable {
        case existing
        case new
    }

    /// When set, client fields are locked to this CRM client (book-from-profile).
    private(set) var lockedClient: Client?
    private(set) var directoryClients: [Client] = []
    private(set) var selectedDirectoryClient: Client?
    private(set) var isLoadingDirectoryClients = false
    private(set) var directoryLoadError: String?
    var clientEntryMode: ClientEntryMode = .existing
    var clientSearchQuery = ""

    init(initialDate: Date, prefilledClient: Client? = nil) {
        studioToday = StudioTime.todayInStudio()
        let iso = StudioTime.yyyyMMdd(from: initialDate)
        initialDateISO = iso >= studioToday ? iso : nil

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

    var canBook: Bool {
        selectedSlot != nil && !isCompleting && canAdvanceFromClient
    }

    var headerTitle: String {
        if (step == .schedule || step == .client), let selectedService {
            return selectedService.title
        }
        if lockedClient != nil {
            return clientDisplayName.isEmpty ? "Book appointment" : clientDisplayName
        }
        return "New appointment"
    }

    var headerSubtitle: String {
        if lockedClient != nil {
            switch step {
            case .service:
                return "Choose a service for \(clientDisplayName) · Step 1 of 2"
            case .schedule:
                return "Pick an open date & time · Step 2 of 2"
            case .client:
                return "Client details"
            }
        }
        switch step {
        case .service:
            return "Choose a service · Step 1 of 3"
        case .client:
            return "Client details · Step 2 of 3"
        case .schedule:
            return "Pick an open date & time · Step 3 of 3"
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
        if step == .service {
            onCancel()
        } else if lockedClient != nil, step == .schedule {
            step = .service
            selectedSlot = nil
        } else {
            step = Step(rawValue: step.rawValue - 1) ?? .service
            if step != .schedule {
                selectedSlot = nil
            }
        }
    }

    func advanceStep() {
        guard !isCompleting else { return }
        errorMessage = nil

        if step == .service, lockedClient != nil {
            guard canAdvanceFromService else { return }
            guard canAdvanceFromClient else {
                errorMessage = "This client needs a first name, last name, and phone before booking."
                return
            }
            step = .schedule
            selectedSlot = nil
            Task { await loadMonth(year: viewYear, month: viewMonth) }
            return
        }

        if step == .client {
            phoneTouched = true
            emailTouched = true
            formatPhoneField()
            guard canAdvanceFromClient else { return }
        }

        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        if step == .schedule {
            selectedSlot = nil
            Task { await loadMonth(year: viewYear, month: viewMonth) }
        }
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
        guard !monthLoading else { return }
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

    func book(onSuccess: @escaping () -> Void) async {
        guard let service = selectedService, let slot = selectedSlot else { return }

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
        defer { isCompleting = false }

        do {
            try await ManualBookingExecution.submit(
                service: service,
                slotIsoUtc: slot,
                clientFirstName: trimmedFirst,
                clientLastName: trimmedLast,
                clientEmail: optionalEmail,
                clientPhoneDigits: parsedPhone.digits
            )
            onSuccess()
        } catch let error as ManualBookingExecutionError {
            errorMessage = error.localizedDescription
        } catch let error as ClientEmailValidationError {
            emailTouched = true
            errorMessage = error.localizedDescription
        } catch let error as AdminAPIError {
            errorMessage = manualBookingMessage(for: error)
        } catch {
            errorMessage = "Booking failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func loadMonth(year: Int, month: Int) async {
        guard let service = selectedService else { return }

        slotsLoadGeneration += 1
        let generation = slotsLoadGeneration

        monthLoading = true
        monthError = nil
        monthSlots = [:]
        availableDates = []
        studioDayDates = []
        selectedDate = nil
        selectedSlot = nil

        let rangeStart = studioDateString(year: year, month: month, day: 1)
        let rangeEnd = studioDateString(
            year: year,
            month: month,
            day: StudioTime.lastDayOfMonth(year: year, month: month)
        )
        let queryStart = rangeStart < studioToday ? studioToday : rangeStart

        defer {
            if generation == slotsLoadGeneration {
                monthLoading = false
            }
        }

        if queryStart > rangeEnd {
            monthError = "No open days left this month."
            return
        }

        do {
            async let slotsDataTask = AdminAPIClient.shared.fetchManualBookingSlots(
                eventTypeId: service.eventTypeId,
                date: queryStart,
                end: rangeEnd
            )
            async let scheduleTask = AdminAPIClient.shared.fetchAvailability()

            let data = try await slotsDataTask
            let schedule = try? await scheduleTask

            guard generation == slotsLoadGeneration else { return }

            if let schedule {
                scheduleAvailability = schedule.schedule.availability
                scheduleOverrides = schedule.overrides
                studioDayDates = StudioScheduleWindows.studioDays(
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    availability: scheduleAvailability,
                    overrides: scheduleOverrides
                )
            } else {
                scheduleAvailability = []
                scheduleOverrides = []
                studioDayDates = []
            }

            let openDates = ManualBookingSlotsParser.datesWithOpenSlots(
                from: data,
                notBefore: studioToday
            )
            monthSlots = ManualBookingSlotsParser.slotsByDay(from: data, openDates: openDates)
            availableDates = openDates

            if openDates.isEmpty {
                let todayParts = StudioTime.calendar.dateComponents([.year, .month], from: Date())
                if mayAdvanceFromEmptyStartMonth,
                   year == (todayParts.year ?? 0),
                   month == (todayParts.month ?? 0) {
                    mayAdvanceFromEmptyStartMonth = false
                    var nextMonth = month + 1
                    var nextYear = year
                    if nextMonth > 12 {
                        nextMonth = 1
                        nextYear += 1
                    }
                    viewYear = nextYear
                    viewMonth = nextMonth
                    await loadMonth(year: nextYear, month: nextMonth)
                    return
                }
                monthError = "No open days in \(StudioTime.monthLabel(year: year, month: month)). Try another month."
                return
            }

            mayAdvanceFromEmptyStartMonth = false

            if let initialDateISO, openDates.contains(initialDateISO) {
                selectedDate = initialDateISO
            } else {
                selectedDate = openDates.first
            }
        } catch let error as AdminAPIError {
            guard generation == slotsLoadGeneration else { return }
            monthError = message(for: error)
        } catch {
            guard generation == slotsLoadGeneration else { return }
            monthError = error.localizedDescription
        }
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
