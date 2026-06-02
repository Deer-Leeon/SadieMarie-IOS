import XCTest
@testable import SadieMarie

/// Sanity tests for the Sadie Marie admin iOS app.
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
            bookingTime: "2026-05-25T15:00:00.000Z",
            endTime: nil,
            status: AppointmentStatus.pending.rawValue,
            clientFirstName: "A",
            clientLastName: "B",
            serviceName: "Lashes",
            serviceSlug: nil,
            calUid: nil
        )
        let canceled = Appointment(
            id: "c1",
            bookingTime: "2026-05-25T16:00:00.000Z",
            endTime: nil,
            status: AppointmentStatus.canceledByClient.rawValue,
            clientFirstName: "A",
            clientLastName: "B",
            serviceName: "Lashes",
            serviceSlug: nil,
            calUid: nil
        )
        let visible = [pending, canceled].visibleAppointments
        XCTAssertEqual(visible.map(\.id), ["p1"])
    }

    func testCalendarAppointmentsExcludesPending() {
        let pending = Appointment(
            id: "p1",
            bookingTime: "2026-05-25T15:00:00.000Z",
            endTime: nil,
            status: AppointmentStatus.pending.rawValue,
            clientFirstName: "A",
            clientLastName: "B",
            serviceName: "Lashes",
            serviceSlug: nil,
            calUid: nil
        )
        let confirmed = Appointment(
            id: "ok",
            bookingTime: "2026-05-25T16:00:00.000Z",
            endTime: nil,
            status: AppointmentStatus.confirmed.rawValue,
            clientFirstName: "A",
            clientLastName: "B",
            serviceName: "Lashes",
            serviceSlug: nil,
            calUid: nil
        )
        let grid = [pending, confirmed].calendarAppointments
        XCTAssertEqual(grid.map(\.id), ["ok"])
    }

    func testTimelinePositionClipsToNineToNineWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = 8
        components.minute = 0
        let early = calendar.date(from: components)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let apt = Appointment(
            id: "early",
            bookingTime: formatter.string(from: early),
            endTime: formatter.string(from: early.addingTimeInterval(3600)),
            status: AppointmentStatus.confirmed.rawValue,
            clientFirstName: "A",
            clientLastName: "B",
            serviceName: "Lashes",
            serviceSlug: nil,
            calUid: nil
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
        let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 25))!

        func apt(id: String, hour: Int, minute: Int, durationMinutes: Int) -> Appointment {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
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
                bookingTime: formatter.string(from: startDate),
                endTime: formatter.string(from: endDate),
                status: AppointmentStatus.confirmed.rawValue,
                clientFirstName: "A",
                clientLastName: "B",
                serviceName: "Lashes",
                serviceSlug: nil,
                calUid: nil
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

    func testServiceColorKeepsWhiteAppointmentText() {
        let apt = Appointment(
            id: "1",
            status: "confirmed",
            serviceColor: "#B8E6B8"
        )
        let colors = BookingDisplay.serviceColor(for: apt)!
        XCTAssertEqual(colors.text, AdminTheme.onServiceColorText)

        let rowColors = BookingDisplay.rowTextColors(for: apt)
        XCTAssertEqual(rowColors.primary, AdminTheme.onServiceColorText)
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
}
