import SwiftUI

/// 3-day and week — full-width columns; hourly grid fills all space above the tab bar.
struct BookingsTimeGridView: View {
    let days: [Date]
    @Bindable var store: AppointmentCalendarStore
    var onDayClick: ((Date) -> Void)?
    var onSelectAppointment: ((Appointment) -> Void)?
    /// Empty hour-band tap (behind pills).
    var onHourClick: ((Date, Int) -> Void)?
    /// Blocked-time pill tap.
    var onBlockClick: ((TimeBlock) -> Void)?
    /// When false, the parent pins hour labels / hour lines and this view
    /// only draws the swiping day headers + appointments.
    var showsPinnedChrome: Bool = true
    var scheduleAvailability: [ScheduleAvailabilityBlock] = []
    var scheduleOverrides: [ScheduleOverride] = []
    var hasSchedule: Bool = false

    private let calendar = Calendar.current
    private var isWeekStyle: Bool { days.count >= 7 }
    private var timeColumnWidth: CGFloat { BookingsCalendarLayout.timeColumnWidth(isWeek: isWeekStyle) }

    var body: some View {
        let _ = store.revision

        return GeometryReader { geometry in
            let headerHeight = BookingsCalendarLayout.dayColumnHeaderHeight
            let topGutter = BookingsCalendarLayout.gridTopGutter
            let available = geometry.size.height - headerHeight - topGutter
            let resolvedHourHeight = BookingsCalendarLayout.resolvedHourHeight(
                inAvailableHeight: available
            )

            if let hourHeight = resolvedHourHeight {
                let gridBodyHeight = BookingsCalendarLayout.gridBodyHeight(hourHeight: hourHeight)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if showsPinnedChrome {
                            Color.clear
                                .frame(width: timeColumnWidth, height: headerHeight)
                        }
                        dayHeadersRow
                    }

                    Color.clear
                        .frame(height: topGutter)

                    HStack(alignment: .top, spacing: 0) {
                        if showsPinnedChrome {
                            BookingsTimeLabelsColumn(hourHeight: hourHeight, isWeekStyle: isWeekStyle)
                                .frame(width: timeColumnWidth)
                        }

                        ZStack(alignment: .topLeading) {
                            if showsPinnedChrome {
                                BookingsHourlyGridBackground(hourHeight: hourHeight)
                            }
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                                    dayGridColumn(
                                        for: day,
                                        hourHeight: hourHeight
                                    )
                                }
                            }

                            // Above the cards so touching same-colour appointments
                            // in neighbouring columns stay visually separate.
                            dayColumnDividers(hourHeight: hourHeight)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: gridBodyHeight, alignment: .top)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .padding(.horizontal, showsPinnedChrome ? BookingsCalendarLayout.horizontalPadding(isWeek: isWeekStyle) : 0)
            } else {
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(showsPinnedChrome ? AdminTheme.cream : Color.clear)
        .scrollDisabled(true)
    }

    // MARK: - Headers

    private var dayHeadersRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dayColumnHeader(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: BookingsCalendarLayout.dayColumnHeaderHeight)
    }

    // MARK: - Time labels / hour lines live in pinned parent views

    // MARK: - Day column guides (hairlines only — no boxed columns)

    @ViewBuilder
    private func dayColumnDividers(hourHeight: CGFloat) -> some View {
        if days.count > 1 {
            let height = BookingsCalendarLayout.hourBandHeight(hourHeight: hourHeight)
            GeometryReader { geo in
                let columnWidth = geo.size.width / CGFloat(days.count)
                ForEach(1..<days.count, id: \.self) { index in
                    Rectangle()
                        .fill(AdminTheme.stone300)
                        .frame(width: 0.75, height: height, alignment: .top)
                        .offset(x: columnWidth * CGFloat(index) - 0.375)
                }
            }
            .frame(height: height, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Day column

    private func dayGridColumn(
        for day: Date,
        hourHeight: CGFloat
    ) -> some View {
        let items = store.appointments(on: day)
        let blocks = store.timeBlocks(on: day)
        let hatchBands = closedBands(for: day, appointments: items)

        return ZStack(alignment: .topLeading) {
            ClosedHoursHatchBands(bands: hatchBands, hourHeight: hourHeight)
            BookingsHourlyGridBackground(hourHeight: hourHeight)
            hourTapRows(for: day, hourHeight: hourHeight)

            ForEach(blocks) { block in
                positionedTimeBlock(block, hourHeight: hourHeight)
            }

            GeometryReader { geo in
                let laidOut = TimelineEngine.layoutForDay(date: day, appointments: items)
                ForEach(laidOut) { positioned in
                    positionedCard(
                        positioned,
                        hourHeight: hourHeight,
                        columnWidth: geo.size.width
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func positionedTimeBlock(_ block: TimeBlock, hourHeight: CGFloat) -> some View {
        if let start = BookingDisplay.iso8601Date(from: block.startTime),
           let end = BookingDisplay.iso8601Date(from: block.endTime) {
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

            TimeGridTimeBlockSummary(block: block, isWeekStyle: isWeekStyle)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: max(height, isWeekStyle ? 16 : 20), alignment: .top)
                .padding(.horizontal, isWeekStyle ? 1 : 2)
                .padding(.top, y)
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .calendarGridTapAction(isEnabled: onBlockClick != nil) {
                    onBlockClick?(block)
                }
        }
    }

    @ViewBuilder
    private func positionedCard(
        _ positioned: PositionedAppointment,
        hourHeight: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        let appointment = positioned.appointment
        if
            let startISO = appointment.bookingTime,
            let start = BookingDisplay.iso8601Date(from: startISO)
        {
            let end = appointment.endTime.flatMap { BookingDisplay.iso8601Date(from: $0) }
                ?? calendar.date(byAdding: .hour, value: 1, to: start)
                ?? start.addingTimeInterval(3600)

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
            let durationMinutes = BookingDisplay.CalendarFormatting.durationMinutes(
                start: start,
                end: end
            )
            let cardHeight = isWeekStyle ? max(height, 18) : height
            let lane = TimelineEngine.cascadeLaneFrame(
                col: positioned.col,
                totalCols: positioned.totalCols,
                columnWidth: columnWidth
            )

            calendarAppointmentButton(
                appointment: appointment,
                cardWidth: lane.width,
                cardHeight: cardHeight,
                topInset: y,
                leadingInset: lane.leading,
                zIndex: lane.zIndex,
                content: {
                    DayColumnBookingCard(
                        appointment: appointment,
                        isWeekStyle: isWeekStyle,
                        blockHeight: cardHeight,
                        hourHeight: hourHeight,
                        durationMinutes: durationMinutes,
                        compactOverlap: positioned.totalCols > 1,
                        isOverlapping: positioned.totalCols > 1,
                        overlapCol: positioned.col
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func calendarAppointmentButton<Content: View>(
        appointment: Appointment,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        topInset: CGFloat,
        leadingInset: CGFloat,
        zIndex: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: isWeekStyle ? 0 : 4)

        Group {
            content()
                .frame(width: cardWidth, alignment: .topLeading)
                .frame(height: cardHeight, alignment: .top)
                .contentShape(shape)
                .calendarGridTapAction(isEnabled: onSelectAppointment != nil) {
                    onSelectAppointment?(appointment)
                }
        }
        .padding(.leading, leadingInset)
        .padding(.top, topInset)
        .zIndex(zIndex)
    }

    private func hourTapRows(for day: Date, hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity)
                    .frame(height: hourHeight)
                    .calendarGridTapAction(isEnabled: onHourClick != nil) {
                        onHourClick?(day, hour)
                    }
                    .accessibilityLabel(
                        "Book or block time starting at \(BookingsTimeLabelsColumn.label(for: hour))"
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(onHourClick != nil)
    }

    private func dayColumnHeader(for day: Date) -> some View {
        let isToday = BookingDisplay.CalendarFormatting.isToday(day, calendar: calendar)
        let weekday = BookingDisplay.CalendarFormatting.shortWeekday(for: day)
        let number = BookingDisplay.CalendarFormatting.dayNumber(for: day, calendar: calendar)

        let label = VStack(spacing: 2) {
            Text(weekday)
                .font(AdminTheme.fontAdminSerif(size: isWeekStyle ? 10 : 12))
                .foregroundStyle(AdminTheme.stone700)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if isToday {
                Text("\(number)")
                    .font(AdminTheme.fontAdminSerif(size: isWeekStyle ? 12 : 15))
                    .foregroundStyle(AdminTheme.cardFill)
                    .frame(width: isWeekStyle ? 22 : 26, height: isWeekStyle ? 22 : 26)
                    .background(Circle().fill(AdminTheme.stone900))
            } else {
                Text("\(number)")
                    .font(AdminTheme.fontAdminSerif(size: isWeekStyle ? 12 : 15))
                    .foregroundStyle(AdminTheme.stone900)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())

        return label
            .calendarGridTapAction(isEnabled: onDayClick != nil) {
                onDayClick?(day)
            }
    }

    private func closedBands(
        for day: Date,
        appointments: [Appointment]
    ) -> [StudioScheduleWindows.MinuteBand] {
        guard hasSchedule else { return [] }
        let ymd = StudioTime.yyyyMMdd(from: day)
        let holes = appointments.compactMap { StudioScheduleWindows.minuteBand(from: $0) }
        return StudioScheduleWindows.closedBands(
            forYMD: ymd,
            availability: scheduleAvailability,
            overrides: scheduleOverrides,
            holes: holes
        )
    }
}

/// Hour labels pinned outside the swipe pager so they never slide with the days.
struct BookingsTimeLabelsColumn: View {
    let hourHeight: CGFloat
    var isWeekStyle: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Text(Self.label(for: hour))
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 9 : 10, weight: .medium))
                    .foregroundStyle(AdminTheme.gray400)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .padding(.trailing, BookingsCalendarLayout.timeLabelTrailingInset)
                    .offset(y: -5)
                    .frame(height: hourHeight, alignment: .top)
            }

            Text(Self.label(for: BookingsCalendarLayout.hourEnd))
                .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 9 : 10, weight: .medium))
                .foregroundStyle(AdminTheme.gray400)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, BookingsCalendarLayout.timeLabelTrailingInset)
                .offset(y: -5)
                .frame(height: BookingsCalendarLayout.endCaptionHeight, alignment: .top)
        }
        .allowsHitTesting(false)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    static func label(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

/// Horizontal hour rules pinned behind the swipe pager.
struct BookingsHourlyGridBackground: View {
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { _ in
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: hourHeight, alignment: .top)
            }

            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: BookingsCalendarLayout.endCaptionHeight, alignment: .top)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .allowsHitTesting(false)
    }
}
