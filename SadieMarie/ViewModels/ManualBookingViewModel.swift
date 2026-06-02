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
    private(set) var monthLoading = false
    private(set) var monthError: String?

    private let initialDateISO: String?
    private let studioToday: String
    private var mayAdvanceFromEmptyStartMonth = true
    private var slotsLoadGeneration = 0

    init(initialDate: Date) {
        studioToday = StudioTime.todayInStudio()
        let iso = StudioTime.yyyyMMdd(from: initialDate)
        initialDateISO = iso >= studioToday ? iso : nil

        let components = StudioTime.calendar.dateComponents([.year, .month], from: initialDate)
        viewYear = components.year ?? StudioTime.calendar.component(.year, from: Date())
        viewMonth = components.month ?? StudioTime.calendar.component(.month, from: Date())
    }

    // MARK: - Derived

    var parsedClientPhone: ParsedClientPhone? {
        ClientPhone.parse(clientPhone)
    }

    var phoneInvalid: Bool {
        phoneTouched && !clientPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedClientPhone == nil
    }

    var canAdvanceFromService: Bool {
        selectedService != nil
    }

    var canAdvanceFromClient: Bool {
        !clientFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedClientPhone != nil
            && isEmailValidForAdvance
    }

    var canBook: Bool {
        selectedSlot != nil && !isCompleting
    }

    var headerTitle: String {
        if (step == .schedule || step == .client), let selectedService {
            return selectedService.title
        }
        return "New appointment"
    }

    var headerSubtitle: String {
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
            async let adminServices = AdminAPIClient.shared.fetchServices()
            let catalog = try? await ServiceCatalogRepository.shared.fetchCatalog()
            let fetched = try await adminServices

            if let catalog {
                serviceSections = ManualBookingServiceCatalog.buildSections(
                    publicServices: catalog.services,
                    adminServices: fetched,
                    layout: catalog.layout
                )
            } else {
                serviceSections = ManualBookingServiceCatalog.buildSections(from: fetched)
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

        if step == .client {
            phoneTouched = true
            formatPhoneField()
            guard parsedClientPhone != nil else { return }
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
        let trimmedEmail = optionalEmailForAPI(clientEmail)
        if !clientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, trimmedEmail == nil {
            errorMessage = "Enter a valid email address or leave email blank."
            return
        }

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
                clientEmail: trimmedEmail,
                clientPhoneDigits: parsedPhone.digits
            )
            onSuccess()
        } catch let error as ManualBookingExecutionError {
            errorMessage = error.localizedDescription
        } catch let error as AdminAPIError {
            errorMessage = manualBookingMessage(for: error)
        } catch {
            errorMessage = "Booking failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private var isEmailValidForAdvance: Bool {
        let trimmed = clientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return optionalEmailForAPI(trimmed) != nil
    }

    private func optionalEmailForAPI(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed
    }

    private func loadMonth(year: Int, month: Int) async {
        guard let service = selectedService else { return }

        slotsLoadGeneration += 1
        let generation = slotsLoadGeneration

        monthLoading = true
        monthError = nil
        monthSlots = [:]
        availableDates = []
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
            let data = try await AdminAPIClient.shared.fetchManualBookingSlots(
                eventTypeId: service.eventTypeId,
                date: queryStart,
                end: rangeEnd
            )

            guard generation == slotsLoadGeneration else { return }

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
        case .server(let status, let body):
            let parsed = ManualBookingAPIErrorParser.message(
                from: body?.data(using: .utf8),
                fallback: "HTTP \(status)"
            )
            return "Booking failed: \(parsed)"
        default:
            return message(for: error)
        }
    }
}
