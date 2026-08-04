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
            clientPhone: "18015551234"
        )
        let json = try JSONSerialization.jsonObject(with: payload.encodedJSON()) as? [String: Any]
        XCTAssertEqual(json?["clientEmail"] as? String, "jane@example.com")
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
        XCTAssertEqual(viewModel.step, .service)
    }
}
