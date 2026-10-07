import XCTest
@testable import SadieMarie

/// Sanity tests for the Sadie Marie admin iOS app.
@MainActor
final class SadieMarieTests: XCTestCase {

    func testProjectCompiles() {
        XCTAssertTrue(true)
    }

    func testBuildAvailabilityPayloadBucketsMatchingHours() {
        let reference = Date()
        var weekly = (0..<7).map { index in
            WeeklyDayRow(
                index: index,
                enabled: index >= 1 && index <= 5,
                start: AvailabilityTimeFormat.time(hour: 9, minute: 0, on: reference),
                end: AvailabilityTimeFormat.time(hour: 17, minute: 0, on: reference)
            )
        }
        weekly[6].enabled = true
        weekly[6].start = AvailabilityTimeFormat.time(hour: 10, minute: 0, on: reference)
        weekly[6].end = AvailabilityTimeFormat.time(hour: 14, minute: 0, on: reference)

        let blocks = AvailabilityViewModel.buildAvailabilityPayload(from: weekly)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].days, [1, 2, 3, 4, 5]) // internal Sunday=0 indices
        XCTAssertEqual(blocks[0].startTime, "09:00")
        XCTAssertEqual(blocks[0].endTime, "17:00")
        XCTAssertEqual(blocks[1].days, [6])
        XCTAssertEqual(blocks[1].startTime, "10:00")
        XCTAssertEqual(blocks[1].endTime, "14:00")
    }

    func testDayNameShortTitle() {
        XCTAssertEqual(DayName.monday.shortTitle, "Mon")
        XCTAssertEqual(DayName.thursday.shortTitle, "Thu")
    }

    func testAvailabilitySnapshotStoreRoundTrip() {
        let key = "admin.availability.lastResponse.v1"
        let previous = UserDefaults.standard.data(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        AvailabilitySnapshotStore.save(Data(AvailabilityResponse.previewJSON.utf8))
        let loaded = AvailabilitySnapshotStore.load()
        XCTAssertEqual(loaded?.resolvedScheduleId, 1)
        XCTAssertEqual(loaded?.schedule.availability.count, 2)
    }

    func testOverrideHoursSummaryAndCompactDate() {
        var closed = OverrideRow.make(
            date: AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-09-14") ?? Date(),
            unavailable: true
        )
        XCTAssertEqual(closed.hoursSummary, "Closed")

        let customDay = Date(timeIntervalSince1970: 1_790_704_800) // 2026-09-29 18:00 UTC
        closed = OverrideRow.make(
            date: customDay,
            unavailable: false,
            start: AvailabilityTimeFormat.time(hour: 11, minute: 0, on: customDay),
            end: AvailabilityTimeFormat.time(hour: 20, minute: 0, on: customDay)
        )
        XCTAssertTrue(closed.hoursSummary.contains("11"))
        XCTAssertTrue(closed.hoursSummary.contains("8"))
        XCTAssertEqual(
            AvailabilityTimeFormat.displayOverrideWeekday(customDay),
            "TUE"
        )
        XCTAssertEqual(
            AvailabilityTimeFormat.displayOverrideMonthDay(customDay),
            "Sep 29"
        )
    }

    func testQuarterHourSlotsRunEarliestToLatest() {
        let reference = Date()
        let slots = AvailabilityTimeFormat.quarterHourSlots(on: reference)
        XCTAssertEqual(slots.count, 72)
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: slots[0]), "05:00")
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: slots[slots.count - 1]), "22:45")
        for index in 1..<slots.count {
            XCTAssertLessThan(
                slots[index - 1],
                slots[index],
                "Time menu must list later times below earlier ones"
            )
        }
    }

    func testDecodeFlatAvailabilityResponseWithScheduleId() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(
            AvailabilityResponse.self,
            from: Data(AvailabilityResponse.previewJSON.utf8)
        )
        XCTAssertEqual(response.schedule.id, 1)
    }

    func testAvailabilityUpdateRequestEncodesScheduleId() throws {
        let request = AvailabilityUpdateRequest(
            scheduleId: 42,
            availability: [ScheduleAvailabilityBlock(days: [1], startTime: "09:00", endTime: "17:00")],
            overrides: []
        )
        let data = try request.encodedJSON()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["scheduleId"] as? Int, 42)
        XCTAssertNil(json?["schedule_id"])
        let block = (json?["availability"] as? [[String: Any]])?.first
        XCTAssertEqual(block?["startTime"] as? String, "09:00")
        XCTAssertEqual(block?["endTime"] as? String, "17:00")
        XCTAssertNil(block?["start_time"])
        XCTAssertEqual(block?["days"] as? [String], ["Monday"])
    }

    func testBuildAvailabilityPayloadEncodesWeekdayNames() {
        let reference = Date()
        let weekly = [
            WeeklyDayRow(
                index: 3,
                enabled: true,
                start: AvailabilityTimeFormat.time(hour: 9, minute: 0, on: reference),
                end: AvailabilityTimeFormat.time(hour: 12, minute: 45, on: reference)
            ),
        ]
        let blocks = AvailabilityViewModel.buildAvailabilityPayload(from: weekly)
        XCTAssertEqual(blocks[0].days, [3])

        let data = try? AvailabilityUpdateRequest(
            scheduleId: 1,
            availability: blocks,
            overrides: []
        ).encodedJSON()
        let json = try? JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any]
        let block = (json?["availability"] as? [[String: Any]])?.first
        XCTAssertEqual(block?["days"] as? [String], ["Wednesday"])
        XCTAssertEqual(block?["startTime"] as? String, "09:00")
        XCTAssertEqual(block?["endTime"] as? String, "12:45")
    }

    func testParseScheduleIdFromNestedJSON() {
        let json = """
        {"schedule":{"availability":[]},"scheduleId":99,"overrides":[]}
        """.data(using: .utf8)!
        XCTAssertEqual(AvailabilityJSON.parseScheduleId(from: json), 99)
    }

    func testDecodeFlatAvailabilityResponse() throws {
        let json = """
        {
          "id": 42,
          "name": "Default",
          "time_zone": "America/Denver",
          "availability": [
            { "days": [1, 2, 3, 4, 5], "start_time": "09:00", "end_time": "17:00" }
          ],
          "overrides": [
            { "date": "2026-05-30", "start_time": null, "end_time": null }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(AvailabilityResponse.self, from: json)

        XCTAssertEqual(response.schedule.timeZone, "America/Denver")
        XCTAssertEqual(response.schedule.availability.count, 1)
        XCTAssertEqual(response.schedule.availability[0].days, [1, 2, 3, 4, 5])
        XCTAssertEqual(response.overrides.count, 1)
        XCTAssertEqual(response.overrides[0].date, "2026-05-30")
    }

    func testDecodeAvailabilityResponseWithStringDays() throws {
        let json = """
        {
          "timezone": "America/Denver",
          "availability": [
            { "days": ["Monday", "Tuesday"], "startTime": "10:00", "endTime": "16:00" }
          ],
          "overrides": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(AvailabilityResponse.self, from: json)

        XCTAssertEqual(response.schedule.availability[0].days, [1, 2])
        XCTAssertEqual(response.schedule.availability[0].startTime, "10:00")
    }

    func testBuildAvailabilityPayloadOmitsDisabledDays() {
        let reference = Date()
        let weekly = (0..<7).map { index in
            WeeklyDayRow(
                index: index,
                enabled: index == 3,
                start: AvailabilityTimeFormat.defaultStart(on: reference),
                end: AvailabilityTimeFormat.defaultEnd(on: reference)
            )
        }

        let blocks = AvailabilityViewModel.buildAvailabilityPayload(from: weekly)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].days, [3])
    }

    func testBuildOverridesPayloadEncodesUnavailableAsMidnightPair() {
        let day = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-25")!
        let row = OverrideRow.make(date: day, unavailable: true)
        let payload = AvailabilityViewModel.buildOverridesPayload(from: [row])

        XCTAssertEqual(payload.count, 1)
        XCTAssertEqual(payload[0].date, "2026-05-25")
        XCTAssertEqual(payload[0].startTime, "00:00")
        XCTAssertEqual(payload[0].endTime, "00:00")
    }

    func testBuildOverridesPayloadEncodesCustomHours() {
        let day = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-26")!
        let row = OverrideRow.make(
            date: day,
            unavailable: false,
            start: AvailabilityTimeFormat.time(hour: 10, minute: 0, on: day),
            end: AvailabilityTimeFormat.time(hour: 14, minute: 30, on: day)
        )
        let payload = AvailabilityViewModel.buildOverridesPayload(from: [row])

        XCTAssertEqual(payload[0].startTime, "10:00")
        XCTAssertEqual(payload[0].endTime, "14:30")
    }

    func testBuildInitialOverridesTreatsEqualTimesAsUnavailableWithDefaults() {
        let api = [
            ScheduleOverride(date: "2026-05-30", startTime: "00:00", endTime: "00:00"),
            ScheduleOverride(date: "2026-06-01", startTime: "10:00", endTime: "14:00"),
        ]
        let rows = AvailabilityViewModel.buildInitialOverrides(from: api)

        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[0].unavailable)
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: rows[0].start), "09:00")
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: rows[0].end), "17:00")
        XCTAssertFalse(rows[1].unavailable)
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: rows[1].start), "10:00")
        XCTAssertEqual(AvailabilityTimeFormat.hhmm(from: rows[1].end), "14:00")
    }

    func testSortedOverridesOrdersByDateThenId() {
        let dayA = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-20")!
        let dayB = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-10")!
        let rows = [
            OverrideRow.make(id: "z", date: dayA, unavailable: true),
            OverrideRow.make(id: "b", date: dayB, unavailable: true),
            OverrideRow.make(id: "a", date: dayB, unavailable: false),
        ]
        let sorted = AvailabilityViewModel.sortedOverrides(rows)
        XCTAssertEqual(sorted.map(\.id), ["a", "b", "z"])
        XCTAssertEqual(
            sorted.map { AvailabilityTimeFormat.yyyyMMdd(from: $0.date) },
            ["2026-05-10", "2026-05-10", "2026-05-20"]
        )
    }

    func testOverrideRowRejectsInvalidCustomHours() {
        let day = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-25")!
        let invalid = OverrideRow.make(
            date: day,
            unavailable: false,
            start: AvailabilityTimeFormat.time(hour: 15, minute: 0, on: day),
            end: AvailabilityTimeFormat.time(hour: 10, minute: 0, on: day)
        )
        XCTAssertFalse(invalid.hasValidCustomHours)

        let valid = OverrideRow.make(
            date: day,
            unavailable: false,
            start: AvailabilityTimeFormat.time(hour: 10, minute: 0, on: day),
            end: AvailabilityTimeFormat.time(hour: 15, minute: 0, on: day)
        )
        XCTAssertTrue(valid.hasValidCustomHours)
        XCTAssertTrue(OverrideRow.make(date: day, unavailable: true).hasValidCustomHours)
    }

    func testScheduleOverrideEncodesTimesAlways() throws {
        let override = ScheduleOverride(date: "2026-05-30", startTime: "00:00", endTime: "00:00")
        let encoder = JSONEncoder()
        let data = try encoder.encode(override)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["date"] as? String, "2026-05-30")
        XCTAssertEqual(json?["startTime"] as? String, "00:00")
        XCTAssertEqual(json?["endTime"] as? String, "00:00")
    }

    func testAvailabilityDayOpenTreatsMidnightPairAsClosed() {
        let response = AvailabilityResponse(
            schedule: AvailabilitySchedule(
                id: 1,
                timeZone: "America/Denver",
                availability: [
                    ScheduleAvailabilityBlock(days: [1], startTime: "09:00", endTime: "17:00"),
                ]
            ),
            overrides: [
                ScheduleOverride(date: "2026-05-25", startTime: "00:00", endTime: "00:00"),
            ]
        )
        let day = AvailabilityTimeFormat.date(fromYYYYMMDD: "2026-05-25")!
        XCTAssertFalse(AvailabilityDayOpen.isOpenWorkingDay(response: response, on: day))
    }

    func testClientFormattedPhoneTenDigits() {
        let client = Client(id: "1", phone: "8015551234")
        XCTAssertEqual(client.formattedPhone, "(801) 555-1234")
    }

    func testClientFormattedPhoneElevenDigits() {
        let client = Client(id: "1", phone: "18015551234")
        XCTAssertEqual(client.formattedPhone, "+1 (801) 555-1234")
    }

    func testClientFormattedPhoneInvalidReturnsOriginal() {
        let client = Client(id: "1", phone: "12")
        XCTAssertEqual(client.formattedPhone, "12")
    }

    func testClientFormattedPhoneEmpty() {
        let client = Client(id: "1", phone: "")
        XCTAssertEqual(client.formattedPhone, "")
    }

    func testPhoneFormatAsYouType() {
        XCTAssertEqual(ClientPhone.formatAsYouType("8"), "(8")
        XCTAssertEqual(ClientPhone.formatAsYouType("801"), "(801)")
        XCTAssertEqual(ClientPhone.formatAsYouType("801555"), "(801) 555")
        XCTAssertEqual(ClientPhone.formatAsYouType("8015551234"), "(801) 555-1234")
        XCTAssertEqual(ClientPhone.formatAsYouType("18015551234"), "(801) 555-1234")
    }

    func testSlotMatchesStudioHour() {
        // 16:00 UTC is 10:00 AM America/Denver during MDT.
        XCTAssertTrue(
            StudioTime.slotMatchesStudioHour(isoUtc: "2026-09-03T16:00:00.000Z", hour: 10)
        )
        XCTAssertFalse(
            StudioTime.slotMatchesStudioHour(isoUtc: "2026-09-03T16:00:00.000Z", hour: 9)
        )
        XCTAssertFalse(
            StudioTime.slotMatchesStudioHour(isoUtc: "not-a-date", hour: 10)
        )
    }

    func testClientDecodesTechnicianReview() throws {
        let json = """
        {
          "id": "b83f3a4c-30df-45e6-8f22-17fb19d6ffc4",
          "first_name": "Leon",
          "has_consented": true,
          "consent_form_url": "https://blob.vercel-storage.com/consent.pdf",
          "consent_technician_reviewed_at": "2026-08-29T18:00:00.000Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = try decoder.decode(Client.self, from: Data(json.utf8))
        XCTAssertEqual(client.hasConsented, true)
        XCTAssertNotNil(client.stampedConsentPdfURL)
        XCTAssertNotNil(client.technicianReviewedDate)
        XCTAssertEqual(
            client.consentDocumentURL?.absoluteString,
            "https://www.sadiemarie.co/consent/b83f3a4c-30df-45e6-8f22-17fb19d6ffc4/document"
        )
    }

    func testSiteImageSlotDecodesUploadResponseURL() throws {
        let json = """
        {"id":"home_hero","url":"https://blob.vercel-storage.com/hero-abc.jpg"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let slot = try decoder.decode(SiteImageSlot.self, from: Data(json.utf8))
        XCTAssertEqual(slot.id, "home_hero")
        XCTAssertEqual(slot.imageURL, "https://blob.vercel-storage.com/hero-abc.jpg")
    }

    func testSiteImageUploadResponseDecodesURL() throws {
        let json = """
        {"id":"home_hero","url":"https://blob.vercel-storage.com/hero-abc.jpg"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SiteImageUploadResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.resolvedImageURL, "https://blob.vercel-storage.com/hero-abc.jpg")
        XCTAssertEqual(response.slotId, "home_hero")
    }

    func testSiteImageSlotDecodesImageURLWithSnakeCaseDecoder() throws {
        let json = """
        {"id":"home_hero","image_url":"https://cdn.example.com/hero.jpg","caption":null}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let slot = try decoder.decode(SiteImageSlot.self, from: Data(json.utf8))
        XCTAssertEqual(slot.imageURL, "https://cdn.example.com/hero.jpg")
    }

    func testWebsiteSettingsResponseDecodesSlots() throws {
        let json = """
        {"slots":[{"id":"about_profile","image_url":"https://cdn.example.com/about.jpg","caption":"Hi"}]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(WebsiteSettingsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.slots.count, 1)
        XCTAssertEqual(response.slots[0].imageURL, "https://cdn.example.com/about.jpg")
    }

    func testWebsiteSlotMergeAlwaysReturnsSevenSlots() {
        let merged = WebsiteSlotItem.merged(from: [
            SiteImageSlot(id: "home_hero", imageURL: "https://example.com/h.jpg", caption: nil),
        ])
        XCTAssertEqual(merged.count, 7)
        XCTAssertEqual(merged.first?.id, WebsiteSlotId.homeHero.rawValue)
        XCTAssertEqual(merged.first?.slot.imageURL, "https://example.com/h.jpg")
        XCTAssertEqual(merged.first?.imageURL?.absoluteString, "https://example.com/h.jpg")
        XCTAssertTrue(merged.contains { $0.id == WebsiteSlotId.portfolio5.rawValue })
    }

    func testWebsiteSlotItemNormalizesSchemelessBlobURL() {
        let blobHost = "cdn.example.com/site-images/home_hero/upload.jpg"
        let url = WebsiteSlotItem.normalizedImageURL(from: blobHost)
        XCTAssertEqual(url?.absoluteString, "https://\(blobHost)")
    }

    func testWebsiteSlotItemNormalizesProtocolRelativeURL() {
        let url = WebsiteSlotItem.normalizedImageURL(from: "//cdn.example.com/hero.jpg")
        XCTAssertEqual(url?.absoluteString, "https://cdn.example.com/hero.jpg")
    }

    func testServiceGroupingNestsChildrenUnderGroups() {
        let grouped = ServiceCatalog.groupedCategories(from: [
            .previewGroup,
            .previewChild,
            .previewStandalone,
        ])
        XCTAssertEqual(grouped.count, 2)
        let lash = grouped.first { $0.category == "Lash Services" }
        XCTAssertEqual(lash?.groups.count, 1)
        XCTAssertEqual(lash?.groups.first?.children.count, 1)
        XCTAssertEqual(lash?.standalones.count, 0)
        let brow = grouped.first { $0.category == "Brow Services" }
        XCTAssertEqual(brow?.standalones.count, 1)
    }

    func testServiceFormatPriceHidesWholeNumberDecimals() {
        let formatted = ServiceFormat.price(120)
        XCTAssertFalse(formatted.contains(".00"))
    }

    func testVisibleAppointmentsExcludesCanceledKeepsPending() {
        let pending = Appointment(
            id: "p1",
            clientFirstName: "A",
            clientLastName: "B",
            bookingTime: "2026-05-25T15:00:00.000Z",
            serviceName: "Lashes",
            status: AppointmentStatus.pending.rawValue
        )
        let canceled = Appointment(
            id: "c1",
            clientFirstName: "A",
            clientLastName: "B",
            bookingTime: "2026-05-25T16:00:00.000Z",
            serviceName: "Lashes",
            status: AppointmentStatus.canceledByClient.rawValue
        )
        let visible = [pending, canceled].visibleAppointments
        XCTAssertEqual(visible.map(\.id), ["p1"])
    }

    func testCalendarAppointmentsExcludesPending() {
        let pending = Appointment(
            id: "p1",
            clientFirstName: "A",
            clientLastName: "B",
            bookingTime: "2026-05-25T15:00:00.000Z",
            serviceName: "Lashes",
            status: AppointmentStatus.pending.rawValue
        )
        let confirmed = Appointment(
            id: "ok",
            clientFirstName: "A",
            clientLastName: "B",
            bookingTime: "2026-05-25T16:00:00.000Z",
            serviceName: "Lashes",
            status: AppointmentStatus.confirmed.rawValue
        )
        let grid = [pending, confirmed].calendarAppointments
        XCTAssertEqual(grid.map(\.id), ["ok"])
    }

    func testVisibleAppointmentsExcludesAttachedExtras() {
        let parent = Appointment(
            id: "parent",
            bookingTime: "2026-05-25T16:00:00.000Z",
            serviceName: "Lashes",
            status: AppointmentStatus.confirmed.rawValue,
            extraCount: 1
        )
        let extra = Appointment(
            id: "extra",
            bookingTime: "2026-05-25T16:00:00.000Z",
            serviceName: "Brow wax",
            status: AppointmentStatus.confirmed.rawValue,
            attachedToAppointmentId: "parent"
        )
        XCTAssertEqual([parent, extra].visibleAppointments.map(\.id), ["parent"])
        XCTAssertEqual([parent, extra].calendarAppointments.map(\.id), ["parent"])
        XCTAssertEqual([parent, extra].visibleForBookingsList().map(\.id), ["parent"])
    }

    func testAppointmentDecodesNestedExtrasAndChargePlan() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json = """
        {
          "id": "parent",
          "status": "confirmed",
          "service_name": "Hybrid Full Set",
          "service_price": 185,
          "extra_count": 1,
          "extras": [
            {
              "id": "extra",
              "status": "confirmed",
              "service_name": "Brow wax",
              "service_price": 20,
              "attached_to_appointment_id": "parent"
            }
          ]
        }
        """.data(using: .utf8)!
        let appointment = try decoder.decode(Appointment.self, from: json)
        XCTAssertEqual(appointment.extraCount, 1)
        XCTAssertEqual(appointment.extras.map(\.id), ["extra"])
        XCTAssertTrue(appointment.extras[0].isAttachedExtra)
        XCTAssertEqual(AppointmentChargePlan.chargeTargetId(for: appointment), "parent")
        XCTAssertEqual(AppointmentChargePlan.forcedAdditionalIds(for: appointment), ["extra"])
        XCTAssertEqual(AppointmentChargePlan.lines(for: appointment).map(\.id), ["parent", "extra"])

        let paidParent = appointment.withTerminalPayment(
            AppointmentPaymentSummary(
                id: "pay-1",
                appointmentId: "parent",
                paymentKind: .cash,
                paymentIntentId: nil,
                readerId: nil,
                status: .succeeded,
                currency: "usd",
                baseAmountCents: 18500,
                tipAmountCents: 0,
                totalAmountCents: 18500,
                failureCode: nil,
                failureMessage: nil,
                note: nil,
                settledByEmail: nil,
                paidAt: nil
            )
        )
        XCTAssertEqual(AppointmentChargePlan.chargeTargetId(for: paidParent), "extra")
        XCTAssertEqual(AppointmentChargePlan.forcedAdditionalIds(for: paidParent), [])
        XCTAssertEqual(AppointmentChargePlan.lines(for: paidParent).map(\.id), ["extra"])
    }

    func testDayCollectedTotalAddsSettledVisitsAndExtras() {
        func payment(cents: Int, status: TerminalPaymentStatus = .succeeded, kind: AppointmentPaymentKind = .cash) -> AppointmentPaymentSummary {
            AppointmentPaymentSummary(
                id: UUID().uuidString,
                appointmentId: nil,
                paymentKind: kind,
                paymentIntentId: nil,
                readerId: nil,
                status: status,
                currency: "usd",
                baseAmountCents: cents,
                tipAmountCents: 0,
                totalAmountCents: cents,
                failureCode: nil,
                failureMessage: nil,
                note: nil,
                settledByEmail: nil,
                paidAt: nil
            )
        }

        let extra = Appointment(
            id: "extra",
            serviceName: "Brow Add On",
            terminalPayment: payment(cents: 2500, kind: .servicePayment)
        )
        let paid = Appointment(
            id: "paid",
            serviceName: "2 Week Fill",
            terminalPayment: payment(cents: 14200),
            extras: [extra]
        )
        let unpaid = Appointment(id: "unpaid", serviceName: "Touch Up", servicePrice: 40)
        let comped = Appointment(
            id: "comp",
            terminalPayment: payment(cents: 0, kind: .complimentary)
        )
        let failed = Appointment(
            id: "failed",
            terminalPayment: payment(cents: 9000, status: .failed, kind: .servicePayment)
        )

        XCTAssertEqual(
            BookingDisplay.collectedCents(for: [paid, unpaid, comped, failed]),
            16700
        )
        XCTAssertEqual(BookingDisplay.formattedCents(16700), "$167")
    }

    func testAppointmentServiceLabelUsesCatalogueDurationNotChairSpan() {
        let classicFill = Appointment(
            id: "fill",
            bookingTime: "2026-05-26T14:00:00.000Z",
            endTime: "2026-05-26T16:15:00.000Z",
            serviceName: "Classic",
            status: AppointmentStatus.confirmed.rawValue,
            chairDurationMins: 135,
            catalogueDurationMins: 120
        )
        XCTAssertEqual(BookingDisplay.appointmentServiceLabel(classicFill), "Classic 2 Week Fill")

        let classicFull = Appointment(
            id: "full",
            bookingTime: "2026-05-26T14:00:00.000Z",
            endTime: "2026-05-26T17:00:00.000Z",
            serviceName: "Classic Full Set",
            status: AppointmentStatus.confirmed.rawValue,
            catalogueDurationMins: 180
        )
        XCTAssertEqual(BookingDisplay.appointmentServiceLabel(classicFull), "Classic Full Set")
    }

    func testAppointmentDecodesChairAndCatalogueDuration() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json = """
        {
          "id": "parent",
          "status": "confirmed",
          "service_name": "Classic",
          "chair_duration_mins": 135,
          "catalogue_duration_mins": 120
        }
        """.data(using: .utf8)!
        let appointment = try decoder.decode(Appointment.self, from: json)
        XCTAssertEqual(appointment.chairDurationMins, 135)
        XCTAssertEqual(appointment.catalogueDurationMins, 120)
        XCTAssertEqual(ChairDuration.displayedMinutes(for: appointment), 135)
        XCTAssertEqual(ChairDuration.formatLabel(105), "1 hr 45 min")
        XCTAssertEqual(ChairDuration.snap(137), 135)
    }

    func testVisitBlockPaintUsesGradientWhenExtraColorDiffers() {
        let extra = Appointment(
            id: "extra",
            status: AppointmentStatus.confirmed.rawValue,
            serviceColor: "#6B4E5A",
            attachedToAppointmentId: "parent",
            catalogueDurationMins: 45
        )
        let parent = Appointment(
            id: "parent",
            status: AppointmentStatus.confirmed.rawValue,
            serviceColor: "#FEDCEA",
            extras: [extra],
            extraCount: 1,
            catalogueDurationMins: 90
        )
        switch BookingDisplay.visitBlockPaint(for: parent) {
        case .gradient:
            break
        default:
            XCTFail("Expected a vertical gradient when extra colour differs")
        }

        let sameColorExtra = Appointment(
            id: "extra-same",
            status: AppointmentStatus.confirmed.rawValue,
            serviceColor: "#FEDCEA",
            attachedToAppointmentId: "parent",
            catalogueDurationMins: 30
        )
        let same = parent.withExtras([sameColorExtra])
        switch BookingDisplay.visitBlockPaint(for: same) {
        case .solid:
            break
        default:
            XCTFail("Expected a solid fill when extra colour matches parent")
        }
    }

    func testTimelinePositionClipsToNineToNineWindow() {
        let calendar = StudioTime.calendar
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = 8
        components.minute = 30
        let early = calendar.date(from: components)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let apt = Appointment(
            id: "early",
            clientFirstName: "A",
            clientLastName: "B",
            bookingTime: formatter.string(from: early),
            endTime: formatter.string(from: early.addingTimeInterval(3600)),
            serviceName: "Lashes",
            status: AppointmentStatus.confirmed.rawValue
        )
        XCTAssertNotNil(TimelineEngine.position(for: apt))
        if let position = TimelineEngine.position(for: apt) {
            XCTAssertEqual(position.topPct, 0, accuracy: 0.01)
        }
    }

    func testTimelineLanePackingAssignsColumns() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = StudioTime.calendar.date(from: DateComponents(year: 2026, month: 5, day: 25))!

        func apt(id: String, hour: Int, minute: Int, durationMinutes: Int) -> Appointment {
            let calendar = StudioTime.calendar
            var start = DateComponents()
            start.year = 2026
            start.month = 5
            start.day = 25
            start.hour = hour
            start.minute = minute
            let startDate = calendar.date(from: start)!
            let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
            return Appointment(
                id: id,
                clientFirstName: "A",
                clientLastName: "B",
                bookingTime: formatter.string(from: startDate),
                endTime: formatter.string(from: endDate),
                serviceName: "Lashes",
                status: AppointmentStatus.confirmed.rawValue
            )
        }

        let overlapping = [
            apt(id: "a", hour: 10, minute: 0, durationMinutes: 60),
            apt(id: "b", hour: 10, minute: 30, durationMinutes: 60),
        ]
        let laidOut = TimelineEngine.layoutForDay(date: day, appointments: overlapping)
        XCTAssertEqual(laidOut.count, 2)
        XCTAssertEqual(Set(laidOut.map(\.col)), [0, 1])
        XCTAssertEqual(laidOut.first?.totalCols, 2)
    }

    func testTimelineBackToBackBookingsStayFullWidth() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = StudioTime.calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))!

        func apt(id: String, hour: Int, minute: Int, durationMinutes: Int, endJitterMs: Double = 0) -> Appointment {
            let calendar = StudioTime.calendar
            var start = DateComponents()
            start.year = 2026
            start.month = 9
            start.day = 12
            start.hour = hour
            start.minute = minute
            let startDate = calendar.date(from: start)!
            let endDate = startDate
                .addingTimeInterval(TimeInterval(durationMinutes * 60) + endJitterMs / 1000)
            return Appointment(
                id: id,
                clientFirstName: "Abby",
                clientLastName: "Nash",
                bookingTime: formatter.string(from: startDate),
                endTime: formatter.string(from: endDate),
                serviceName: "Brow Shape",
                status: AppointmentStatus.confirmed.rawValue
            )
        }

        let sequential = [
            apt(id: "a", hour: 14, minute: 30, durationMinutes: 30, endJitterMs: 400),
            apt(id: "b", hour: 15, minute: 0, durationMinutes: 30),
            apt(id: "c", hour: 15, minute: 30, durationMinutes: 30),
        ]
        let laidOut = TimelineEngine.layoutForDay(date: day, appointments: sequential)
        XCTAssertEqual(laidOut.count, 3)
        XCTAssertEqual(Set(laidOut.map(\.col)), [0])
        XCTAssertEqual(Set(laidOut.map(\.totalCols)), [1])
    }

    func testColumnLaneFrameSplitsWidthEvenly() {
        let left = TimelineEngine.columnLaneFrame(
            col: 0, totalCols: 2, columnWidth: 200, outer: 2, gap: 2
        )
        let right = TimelineEngine.columnLaneFrame(
            col: 1, totalCols: 2, columnWidth: 200, outer: 2, gap: 2
        )
        XCTAssertEqual(left.width, right.width, accuracy: 0.01)
        XCTAssertEqual(left.leading, 2, accuracy: 0.01)
        XCTAssertEqual(right.leading, left.leading + left.width + 2, accuracy: 0.01)
        XCTAssertEqual(left.leading + left.width * 2 + 2 + 2, 200, accuracy: 0.01)

        let solo = TimelineEngine.columnLaneFrame(
            col: 0, totalCols: 1, columnWidth: 200, outer: 8, gap: 0
        )
        XCTAssertEqual(solo.leading, 8, accuracy: 0.01)
        XCTAssertEqual(solo.width, 184, accuracy: 0.01)
    }

    func testDailyGridFitsAvailableHeightWithNinePmCaption() {
        let available: CGFloat = 580
        let hourHeight = BookingsCalendarLayout.hourHeight(inAvailableHeight: available)
        XCTAssertEqual(
            BookingsCalendarLayout.gridBodyHeight(hourHeight: hourHeight),
            available,
            accuracy: 0.01
        )
        XCTAssertGreaterThan(hourHeight, 8)
    }

    func testDailyModalTopGutterLeavesRoomForNineAmLabel() {
        let total: CGFloat = 580
        let topGutter = BookingsCalendarLayout.dayModalTopGutter
        let hourHeight = BookingsCalendarLayout.hourHeight(
            inAvailableHeight: total - topGutter
        )
        XCTAssertGreaterThanOrEqual(topGutter, 16)
        XCTAssertEqual(
            topGutter + BookingsCalendarLayout.gridBodyHeight(hourHeight: hourHeight),
            total,
            accuracy: 0.01
        )
    }

    func testManualBookingSlotsParserReadsOccupiedStarts() {
        let iso = "2026-09-03T15:00:00.000Z"
        let json = """
        {"slots":{"2026-09-03":["\(iso)"]},"occupied":["\(iso)"]}
        """
        let occupied = ManualBookingSlotsParser.occupiedStartMs(from: Data(json.utf8))
        XCTAssertEqual(occupied, [ManualBookingSlotsParser.epochMs(isoUtc: iso)!])
        XCTAssertTrue(
            ManualBookingSlotsParser.occupiedStartMs(from: Data("{\"slots\":{}}".utf8)).isEmpty
        )
    }

    func testDecodeTimeBlocksResponse() throws {
        let json = """
        {
          "blocks": [
            {
              "id": "blk-1",
              "start_time": "2026-08-10T15:00:00.000Z",
              "end_time": "2026-08-10T16:00:00.000Z",
              "note": "Lunch",
              "cal_booking_uid": "uid-1",
              "cal_booking_uids": ["uid-1"]
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(TimeBlocksResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.blocks.count, 1)
        XCTAssertEqual(response.blocks[0].id, "blk-1")
        XCTAssertEqual(response.blocks[0].note, "Lunch")
        XCTAssertEqual(response.blocks[0].calBookingUid, "uid-1")
    }

    func testLayoutBlocksForDayPositionsWithinWindow() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!

        let calendar = StudioTime.calendar
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!

        var start = DateComponents()
        start.year = 2026
        start.month = 8
        start.day = 10
        start.hour = 12
        start.minute = 0
        let startDate = calendar.date(from: start)!
        let endDate = startDate.addingTimeInterval(3600)

        let block = TimeBlock(
            id: "blk-1",
            startTime: formatter.string(from: startDate),
            endTime: formatter.string(from: endDate),
            note: "Lunch"
        )

        let laidOut = TimelineEngine.layoutBlocksForDay(date: day, blocks: [block])
        XCTAssertEqual(laidOut.count, 1)
        XCTAssertEqual(laidOut[0].topPct, 25, accuracy: 0.5)
        XCTAssertEqual(laidOut[0].heightPct, 100.0 / 12.0, accuracy: 0.5)
    }

    func testServiceColorPastelUsesBlackText() {
        let pastel = Appointment(
            id: "1",
            status: "confirmed",
            serviceColor: "#FEDCEA"
        )
        let pastelColors = BookingDisplay.serviceColor(for: pastel)!
        XCTAssertEqual(pastelColors.text, .black)

        let dark = Appointment(
            id: "2",
            status: "confirmed",
            serviceColor: "#6B4E5A"
        )
        let darkColors = BookingDisplay.serviceColor(for: dark)!
        XCTAssertEqual(darkColors.text, AdminTheme.onServiceColorText)

        let rowColors = BookingDisplay.rowTextColors(for: pastel)
        XCTAssertEqual(rowColors.primary, .black)
    }

    func testSiteImageSlotDisplayCaptionDefaultsAndHidden() {
        let defaults = SiteImageSlot.portfolioDefaults
        let defaultSlot = SiteImageSlot(id: WebsiteSlotId.portfolio1.rawValue, imageURL: nil, caption: nil)
        XCTAssertEqual(defaultSlot.displayCaption(defaults: defaults), "Classic Lashes")

        let hidden = SiteImageSlot(id: WebsiteSlotId.portfolio1.rawValue, imageURL: nil, caption: "")
        XCTAssertNil(hidden.displayCaption(defaults: defaults))

        let custom = SiteImageSlot(id: WebsiteSlotId.portfolio1.rawValue, imageURL: nil, caption: "Custom")
        XCTAssertEqual(custom.displayCaption(defaults: defaults), "Custom")
    }

    func testMultipartFormDataIncludesEmptyCaptionWhenProvided() {
        var form = MultipartFormDataBuilder(boundary: "TestBoundary")
        form.appendField(name: "id", value: "portfolio_1")
        form.appendFile(
            name: "file",
            filename: "upload.jpg",
            mimeType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )
        form.appendField(name: "caption", value: "")
        let text = String(decoding: form.finalize(), as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"caption\""))
        XCTAssertTrue(text.contains("\r\n\r\n\r\n"))
    }

    func testMultipartFormDataIncludesBoundaryAndFields() {
        var form = MultipartFormDataBuilder(boundary: "TestBoundary")
        form.appendField(name: "id", value: "home_hero")
        form.appendFile(
            name: "file",
            filename: "upload.jpg",
            mimeType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )
        form.appendField(name: "caption", value: "Classic")
        let body = form.finalize()
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("TestBoundary"))
        XCTAssertTrue(text.contains("name=\"id\""))
        XCTAssertTrue(text.contains("home_hero"))
        XCTAssertTrue(text.contains("filename=\"upload.jpg\""))
        XCTAssertTrue(text.contains("image/jpeg"))
        XCTAssertTrue(text.contains("name=\"caption\""))
        XCTAssertTrue(text.hasSuffix("--TestBoundary--\r\n"))
    }

    func testClientEmailNormalizesAndValidates() {
        XCTAssertEqual(ClientEmail.normalized("  Jane@Example.COM "), "jane@example.com")
        XCTAssertTrue(ClientEmail.isValid("jane@example.com"))
        XCTAssertFalse(ClientEmail.isValid(""))
        XCTAssertFalse(ClientEmail.isValid("not-an-email"))
        XCTAssertFalse(ClientEmail.isValid("bookings+18015551234@example.com"))
        XCTAssertFalse(ClientEmail.isValid("user@placeholder.sadiemarie.co"))
    }

    func testManualBookingCreatePayloadAlwaysIncludesClientEmail() throws {
        let payload = ManualBookingCreatePayload(
            eventTypeId: 123,
            start: "2026-06-01T15:00:00",
            clientFirstName: "Jane",
            clientLastName: "Doe",
            clientName: "Jane Doe",
            clientEmail: "jane@example.com",
            clientPhone: "18015551234",
            bookingNotes: nil
        )
        let json = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["clientEmail"] as? String, "jane@example.com")
        XCTAssertNil(json?["bookingNotes"])
    }

    func testManualBookingCreatePayloadIncludesBookingNotes() throws {
        let payload = ManualBookingCreatePayload(
            eventTypeId: 123,
            start: "2026-06-01T15:00:00",
            clientFirstName: "Jane",
            clientLastName: "Doe",
            clientName: "Jane Doe",
            clientEmail: "jane@example.com",
            clientPhone: "18015551234",
            bookingNotes: "First time, extra gentle"
        )
        let json = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["bookingNotes"] as? String, "First time, extra gentle")
    }

    func testBootstrapClientBodyAlwaysIncludesEmail() throws {
        let body = BootstrapClientBody(
            phone: "18015551234",
            firstName: "Jane",
            lastName: "Doe",
            email: "jane@example.com"
        )
        let json = try JSONSerialization.jsonObject(with: body.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["email"] as? String, "jane@example.com")
    }

    func testClientIdentityPayloadAlwaysIncludesEmail() throws {
        let payload = ClientIdentityPayload(
            firstName: "Jane",
            lastName: "Doe",
            email: "jane@example.com"
        )
        let json = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["email"] as? String, "jane@example.com")
    }

    func testDecodeTerminalPaymentWithTipAndReader() throws {
        let json = """
        {
          "payment": {
            "id": "pay-1",
            "payment_kind": "service_payment",
            "payment_intent_id": "pi_123",
            "reader_id": "tmr_123",
            "status": "succeeded",
            "currency": "usd",
            "base_amount_cents": 15000,
            "tip_amount_cents": 3000,
            "total_amount_cents": 18000,
            "failure_code": null,
            "failure_message": null,
            "note": null,
            "settled_by_email": null,
            "paid_at": "2026-08-04T18:00:00.000Z"
          },
          "reader": {
            "id": "tmr_123",
            "label": "Front desk",
            "status": "online",
            "action_status": null
          }
        }
        """
        let response = try AdminAPIClient.defaultDecoder().decode(
            TerminalPaymentAPIResponse.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(response.payment?.paymentKind, .servicePayment)
        XCTAssertEqual(response.payment?.tipAmountCents, 3000)
        XCTAssertEqual(response.payment?.totalAmountCents, 18000)
        XCTAssertTrue(response.payment?.isSettled == true)
        XCTAssertFalse(response.payment?.canUndo == true)
        XCTAssertEqual(response.reader?.status, "online")
    }

    func testManualSettlementUndoEligibilityAndOptionalNote() throws {
        let json = """
        {
          "payment": {
            "id": "pay-cash",
            "payment_kind": "cash",
            "payment_intent_id": null,
            "reader_id": null,
            "status": "succeeded",
            "currency": "usd",
            "base_amount_cents": 12500,
            "tip_amount_cents": 0,
            "total_amount_cents": 12500,
            "failure_code": null,
            "failure_message": null,
            "note": "Paid at checkout",
            "settled_by_email": "admin@example.com",
            "paid_at": "2026-08-04T18:00:00.000Z"
          }
        }
        """
        let response = try AdminAPIClient.defaultDecoder().decode(
            SettlementAPIResponse.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(response.payment?.paymentKind, .cash)
        XCTAssertEqual(response.payment?.note, "Paid at checkout")
        XCTAssertTrue(response.payment?.canUndo == true)

        let payload = SettlementRequest(method: .complimentary, note: nil)
        let encoded = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(encoded?["method"] as? String, "complimentary")
        XCTAssertNil(encoded?["note"])
    }

    func testFailedTerminalPaymentIsRetryable() throws {
        let json = """
        {
          "payment": {
            "id": "pay-failed",
            "payment_kind": "service_payment",
            "payment_intent_id": "pi_123",
            "reader_id": "tmr_123",
            "status": "failed",
            "currency": "usd",
            "base_amount_cents": 9000,
            "tip_amount_cents": 0,
            "total_amount_cents": 9000,
            "failure_code": "card_declined",
            "failure_message": "Card declined",
            "note": null,
            "settled_by_email": null,
            "paid_at": null
          },
          "error": "retry_required",
          "message": "Try again"
        }
        """
        let response = try AdminAPIClient.defaultDecoder().decode(
            TerminalPaymentAPIResponse.self,
            from: Data(json.utf8)
        )
        XCTAssertTrue(response.payment?.isRetryableTerminalPayment == true)
        XCTAssertEqual(response.payment?.failureMessage, "Card declined")
        XCTAssertFalse(response.payment?.isSettled == true)
    }

    func testTerminalDiscountAndCustomAmountHelpers() throws {
        XCTAssertEqual(TerminalDiscount.apply(quotedCents: 7000, percent: 0), 7000)
        XCTAssertEqual(TerminalDiscount.apply(quotedCents: 7000, percent: 10), 6300)
        XCTAssertEqual(TerminalDiscount.apply(quotedCents: 7000, percent: 20), 5600)
        XCTAssertEqual(TerminalDiscount.apply(quotedCents: 7000, percent: 50), 3500)
        XCTAssertEqual(TerminalDiscount.parseDollarsToCents("70"), 7000)
        XCTAssertEqual(TerminalDiscount.parseDollarsToCents("$70.50"), 7050)
        XCTAssertNil(TerminalDiscount.parseDollarsToCents("abc"))
        XCTAssertTrue(TerminalDiscount.isValidCustomAmountCents(50))
        XCTAssertFalse(TerminalDiscount.isValidCustomAmountCents(49))

        let discountBody = try JSONSerialization.jsonObject(
            with: TerminalStartRequest.discount(20).encodedJSON()
        ) as? [String: Any]
        XCTAssertEqual(discountBody?["discount_percent"] as? Int, 20)
        XCTAssertNil(discountBody?["custom_amount_cents"])
        XCTAssertNil(discountBody?["additional_appointment_ids"])

        let customBody = try JSONSerialization.jsonObject(
            with: TerminalStartRequest.custom(cents: 4500).encodedJSON()
        ) as? [String: Any]
        XCTAssertEqual(customBody?["custom_amount_cents"] as? Int, 4500)
        XCTAssertNil(customBody?["discount_percent"])

        let groupedBody = try JSONSerialization.jsonObject(
            with: TerminalStartRequest.discount(
                0,
                additionalAppointmentIds: ["apt-2", "apt-3"]
            ).encodedJSON()
        ) as? [String: Any]
        XCTAssertEqual(groupedBody?["discount_percent"] as? Int, 0)
        XCTAssertEqual(
            groupedBody?["additional_appointment_ids"] as? [String],
            ["apt-2", "apt-3"]
        )
    }

    func testTimeBlockPatchPayloadIncludesWindowAndOptionalNote() throws {
        let payload = TimeBlockUpdateRequest(
            start: "2026-08-10T18:00:00.000Z",
            end: "2026-08-10T19:30:00.000Z",
            note: "Lunch"
        )
        let json = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["start"] as? String, "2026-08-10T18:00:00.000Z")
        XCTAssertEqual(json?["end"] as? String, "2026-08-10T19:30:00.000Z")
        XCTAssertEqual(json?["note"] as? String, "Lunch")
    }

    @MainActor
    func testBookAnotherResetPreservesLockedClient() {
        let client = Client(
            id: "client-1",
            firstName: "Jane",
            lastName: "Doe",
            email: "jane@example.com",
            phone: "18015551234"
        )
        let viewModel = ManualBookingViewModel(initialDate: Date(), prefilledClient: client)
        viewModel.clientSearchQuery = "temporary"
        viewModel.selectedDate = "2026-08-10"
        viewModel.selectedSlot = "2026-08-10T18:00:00.000Z"

        viewModel.resetForNextBooking()

        XCTAssertEqual(viewModel.lockedClient?.id, "client-1")
        XCTAssertEqual(viewModel.clientFirstName, "Jane")
        XCTAssertEqual(viewModel.clientLastName, "Doe")
        XCTAssertNil(viewModel.selectedDate)
        XCTAssertNil(viewModel.selectedSlot)
        XCTAssertTrue(viewModel.pendingVisits.isEmpty)
        XCTAssertEqual(viewModel.step, .service)
    }

    @MainActor
    func testCommitScheduleAppendsVisitAndOpensSummary() {
        let viewModel = ManualBookingViewModel(
            initialDate: Date(),
            prefilledClient: Client(
                id: "client-1",
                firstName: "Jane",
                lastName: "Doe",
                email: "jane@example.com",
                phone: "18015551234"
            )
        )
        viewModel.selectedService = Self.sampleManualService
        viewModel.selectedSlot = "2026-08-10T18:00:00.000Z"
        viewModel.bookingNotes = "Allergic to latex"

        XCTAssertTrue(viewModel.commitScheduleToCart())
        XCTAssertEqual(viewModel.step, .summary)
        XCTAssertEqual(viewModel.pendingVisits.count, 1)
        XCTAssertEqual(viewModel.pendingVisits[0].service.slug, "classic-set")
        XCTAssertEqual(viewModel.pendingVisits[0].slotIsoUtc, "2026-08-10T18:00:00.000Z")
        XCTAssertEqual(viewModel.pendingVisits[0].notes, "Allergic to latex")
        XCTAssertNil(viewModel.selectedService)
        XCTAssertNil(viewModel.selectedSlot)
        XCTAssertTrue(viewModel.bookingNotes.isEmpty)
    }

    @MainActor
    func testAddEditRemoveCartAndOccupiedSlots() {
        let viewModel = ManualBookingViewModel(
            initialDate: Date(),
            prefilledClient: Client(
                id: "client-1",
                firstName: "Jane",
                lastName: "Doe",
                email: "jane@example.com",
                phone: "18015551234"
            )
        )
        let firstSlot = "2026-08-10T18:00:00.000Z"
        let secondSlot = "2026-08-11T18:00:00.000Z"
        viewModel.selectedService = Self.sampleManualService
        viewModel.selectedSlot = firstSlot
        XCTAssertTrue(viewModel.commitScheduleToCart())

        viewModel.beginAddVisit()
        XCTAssertEqual(viewModel.step, .service)
        XCTAssertTrue(viewModel.slotIsOccupied(firstSlot))
        XCTAssertFalse(viewModel.slotIsOccupied(secondSlot))

        viewModel.selectedService = Self.sampleManualService
        viewModel.selectedSlot = secondSlot
        XCTAssertTrue(viewModel.commitScheduleToCart())
        XCTAssertEqual(viewModel.pendingVisits.count, 2)

        let first = viewModel.pendingVisits[0]
        viewModel.beginEditVisit(first)
        XCTAssertEqual(viewModel.editingVisitId, first.id)
        XCTAssertEqual(viewModel.step, .service)
        XCTAssertFalse(viewModel.slotIsOccupied(firstSlot))
        XCTAssertTrue(viewModel.slotIsOccupied(secondSlot))

        viewModel.removeVisit(viewModel.pendingVisits[1].id)
        XCTAssertEqual(viewModel.pendingVisits.count, 1)
        viewModel.removeVisit(viewModel.pendingVisits[0].id)
        XCTAssertTrue(viewModel.pendingVisits.isEmpty)
        XCTAssertEqual(viewModel.step, .service)
    }

    private static let sampleManualService = ManualBookingServiceOption(
        slug: "classic-set",
        title: "Classic Set",
        description: "",
        category: "Lash Sets",
        price: 155,
        eventTypeId: 42,
        durationMins: 150
    )

    func testAdminPushPayloadParsesAppointmentId() {
        XCTAssertEqual(
            AdminPushPayload.appointmentId(from: ["appointmentId": "appt-42"]),
            "appt-42"
        )
        XCTAssertEqual(
            AdminPushPayload.appointmentId(from: ["appointmentId": NSNumber(value: 7)]),
            "7"
        )
        XCTAssertNil(AdminPushPayload.appointmentId(from: ["bookingUid": "abc"]))
        XCTAssertNil(AdminPushPayload.appointmentId(from: ["appointmentId": "  "]))
    }

    func testAdminPushPayloadRecognizesConfirmedBookingPush() {
        XCTAssertTrue(
            AdminPushPayload.isConfirmedBookingPush(["appointmentId": "appt-1"])
        )
        XCTAssertTrue(
            AdminPushPayload.isConfirmedBookingPush(["bookingUid": "cal_uid"])
        )
        XCTAssertFalse(
            AdminPushPayload.isConfirmedBookingPush(["aps": ["alert": "hi"]])
        )
    }

    func testIncomingBookingPushRefreshesCalendarWithoutOpeningSheet() {
        let push = PushRegistration.shared
        push.pendingOpenAppointmentId = nil
        let before = push.liveDataRevision

        push.handleIncomingBookingPush(userInfo: ["appointmentId": "appt-live"])

        XCTAssertEqual(push.liveDataRevision, before + 1)
        XCTAssertNil(push.pendingOpenAppointmentId)
    }

    func testNotificationTapOpensAppointmentAndRefreshesCalendar() {
        let push = PushRegistration.shared
        push.pendingOpenAppointmentId = nil
        let before = push.liveDataRevision

        push.handleNotificationTap(userInfo: ["appointmentId": "appt-tap"])

        XCTAssertEqual(push.pendingOpenAppointmentId, "appt-tap")
        XCTAssertEqual(push.liveDataRevision, before + 1)
        _ = push.consumePendingOpenAppointmentId()
    }

    func testAdminPushPayloadHexEncodesDeviceToken() {
        let token = Data([0x0A, 0xFF, 0x00, 0x1B])
        XCTAssertEqual(AdminPushPayload.hexDeviceToken(token), "0aff001b")
    }

    func testForbiddenPushRegisterIsNotRetried() {
        XCTAssertTrue(AdminAPIError.forbidden.isNonRetryableAuthFailure)
        XCTAssertFalse(AdminAPIError.unauthorized.isNonRetryableAuthFailure)
        XCTAssertFalse(AdminAPIError.noActiveSession.isNonRetryableAuthFailure)
    }

    func testTransientAuthFailureDetectsClerkSettlingErrors() {
        XCTAssertTrue(AdminAPIError.isTransientAuthFailure(AdminAPIError.unauthorized))
        XCTAssertTrue(AdminAPIError.isTransientAuthFailure(AdminAPIError.noActiveSession))
        XCTAssertFalse(AdminAPIError.isTransientAuthFailure(AdminAPIError.forbidden))
        XCTAssertTrue(
            AdminAPIError.isTransientAuthFailure(
                AdminAPIError.unknown(
                    NSError(
                        domain: "ClerkAPIError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to authenticate"]
                    )
                )
            )
        )
        let clerkStyle = NSError(
            domain: "Clerk",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Invalid authentication"]
        )
        XCTAssertTrue(AdminAPIError.isTransientAuthFailure(clerkStyle))
        XCTAssertFalse(
            AdminAPIError.isTransientAuthFailure(
                AdminAPIError.transport(URLError(.timedOut))
            )
        )
    }

    func testCurrentRangeStartForThreeDayIsToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 18))!
        let start = BookingDisplay.CalendarFormatting.currentRangeStart(
            mode: .threeDay,
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(calendar.isDate(start, inSameDayAs: now))
    }

    func testCurrentRangeStartForWeekIsWeekContainingToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 18))!
        let start = BookingDisplay.CalendarFormatting.currentRangeStart(
            mode: .week,
            now: now,
            calendar: calendar
        )
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        XCTAssertEqual(start, week?.start)
        XCTAssertTrue(
            BookingDisplay.CalendarFormatting.rangeContainsToday(
                mode: .week,
                rangeStart: start,
                now: now,
                calendar: calendar
            )
        )
    }

    func testThreeDayRangeContainsTodayOnlyForCurrentWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29))!
        XCTAssertTrue(
            BookingDisplay.CalendarFormatting.rangeContainsToday(
                mode: .threeDay,
                rangeStart: today,
                now: today,
                calendar: calendar
            )
        )
        let earlier = calendar.date(byAdding: .day, value: -3, to: today)!
        XCTAssertFalse(
            BookingDisplay.CalendarFormatting.rangeContainsToday(
                mode: .threeDay,
                rangeStart: earlier,
                now: today,
                calendar: calendar
            )
        )
    }

    func testGridBlockHeightLandsOnHourLine() {
        let calendar = StudioTime.calendar
        let start = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 15, minute: 30)
        )!
        let end = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 17, minute: 0)
        )!
        let hourHeight: CGFloat = 44
        let y = BookingDisplay.CalendarFormatting.yOffset(
            for: start,
            hourHeight: hourHeight,
            calendar: calendar
        )
        let height = BookingDisplay.CalendarFormatting.blockHeight(
            start: start,
            end: end,
            hourHeight: hourHeight
        )
        // 3:30 PM is 6.5 hours after 9 AM; 5:00 PM is 8 hours after 9 AM.
        XCTAssertEqual(y, 6.5 * hourHeight, accuracy: 0.01)
        XCTAssertEqual(height, 1.5 * hourHeight, accuracy: 0.01)
        XCTAssertEqual(y + height, 8 * hourHeight, accuracy: 0.01)
    }

    func testUpcomingAppointmentUsesEndTime() {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let inProgress = Appointment(
            id: "now",
            bookingTime: formatter.string(from: now.addingTimeInterval(-30 * 60)),
            endTime: formatter.string(from: now.addingTimeInterval(30 * 60))
        )
        let justEnded = Appointment(
            id: "past",
            bookingTime: formatter.string(from: now.addingTimeInterval(-90 * 60)),
            endTime: formatter.string(from: now.addingTimeInterval(-1))
        )
        let laterToday = Appointment(
            id: "next",
            bookingTime: formatter.string(from: now.addingTimeInterval(60 * 60)),
            endTime: formatter.string(from: now.addingTimeInterval(150 * 60))
        )

        XCTAssertTrue(BookingDisplay.isUpcoming(inProgress, now: now))
        XCTAssertFalse(BookingDisplay.isUpcoming(justEnded, now: now))
        XCTAssertTrue(BookingDisplay.isUpcoming(laterToday, now: now))
    }
}
