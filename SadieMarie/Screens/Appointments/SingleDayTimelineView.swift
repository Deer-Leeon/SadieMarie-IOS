import SwiftUI

/// Single-day timeline — hour grid with tappable rows for blocking time.
/// Fits 9 AM–9 PM in the available height (no scroll), matching 3-day / week.
struct SingleDayTimelineView: View {
    let items: [PositionedAppointment]
    let timeBlocks: [PositionedTimeBlock]
    var removingBlockId: String?
    var onHourTap: ((Int) -> Void)?
    var onAppointmentTap: ((Appointment) -> Void)?
    var onBlockTap: ((TimeBlock) -> Void)?
    var hatchBands: [StudioScheduleWindows.MinuteBand] = []

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 56

    private var isEmpty: Bool {
        items.isEmpty && timeBlocks.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let topGutter = BookingsCalendarLayout.dayModalTopGutter
            let resolvedHourHeight = BookingsCalendarLayout.resolvedHourHeight(
                inAvailableHeight: geometry.size.height - topGutter
            )

            if let hourHeight = resolvedHourHeight {
                let gridBodyHeight = BookingsCalendarLayout.gridBodyHeight(hourHeight: hourHeight)
                let hourBandHeight = BookingsCalendarLayout.hourBandHeight(hourHeight: hourHeight)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topGutter)

                    HStack(alignment: .top, spacing: 0) {
                        BookingsTimeLabelsColumn(hourHeight: hourHeight, isWeekStyle: false)
                            .frame(width: timeColumnWidth)

                        ZStack(alignment: .topLeading) {
                            ClosedHoursHatchBands(
                                bands: hatchBands,
                                hourHeight: hourHeight
                            )
                            .frame(height: hourBandHeight)
                            .zIndex(0)
                            BookingsHourlyGridBackground(hourHeight: hourHeight)
                                .zIndex(1)
                            hourTapRows(hourHeight: hourHeight)
                                .frame(height: hourBandHeight)
                                .zIndex(1)
                            if isEmpty {
                                emptyHint
                                    .frame(height: hourBandHeight)
                            }
                            timeBlockPills(hourHeight: hourHeight)
                                .frame(height: hourBandHeight)
                                .zIndex(2)
                            appointmentCards(hourHeight: hourHeight)
                                .frame(height: hourBandHeight)
                                .zIndex(3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: gridBodyHeight, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Hour taps

    private func hourTapRows(hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Button {
                    onHourTap?(hour)
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: hourHeight)
                .accessibilityLabel(
                    "Book or block time starting at \(BookingsTimeLabelsColumn.label(for: hour))"
                )
            }
        }
    }

    private var emptyHint: some View {
        Text("No bookings — tap an hour to book or block")
            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .textCase(.uppercase)
            .tracking(1.2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    // MARK: - Blocks

    private func timeBlockPills(hourHeight: CGFloat) -> some View {
        GeometryReader { geometry in
            let hourBandHeight = BookingsCalendarLayout.hourBandHeight(hourHeight: hourHeight)
            ForEach(timeBlocks) { positioned in
                let top = hourBandHeight * CGFloat(positioned.topPct / 100)
                let height = max(
                    hourBandHeight * CGFloat(positioned.heightPct / 100),
                    TimelineEngine.minPillHeight
                )

                TimeBlockPill(
                    block: positioned.block,
                    isRemoving: removingBlockId == positioned.block.id,
                    onTap: onBlockTap.map { handler in { handler(positioned.block) } }
                )
                .frame(width: geometry.size.width - 4, height: height)
                .offset(x: 2, y: top)
            }
        }
    }

    // MARK: - Appointments

    private func appointmentCards(hourHeight: CGFloat) -> some View {
        GeometryReader { geometry in
            ForEach(items) { positioned in
                positionedCard(
                    positioned,
                    columnWidth: geometry.size.width,
                    hourHeight: hourHeight
                )
            }
        }
    }

    @ViewBuilder
    private func positionedCard(
        _ positioned: PositionedAppointment,
        columnWidth: CGFloat,
        hourHeight: CGFloat
    ) -> some View {
        let appointment = positioned.appointment
        if
            let startISO = appointment.bookingTime,
            let start = BookingDisplay.iso8601Date(from: startISO)
        {
            let end = appointment.endTime.flatMap { BookingDisplay.iso8601Date(from: $0) }
                ?? calendar.date(byAdding: .hour, value: 1, to: start)
                ?? start.addingTimeInterval(3600)

            let hourBandHeight = BookingsCalendarLayout.hourBandHeight(hourHeight: hourHeight)
            let topInset = columnWidth > 0
                ? CGFloat(positioned.topPct / 100) * hourBandHeight
                : 0
            let cardHeight = max(
                CGFloat(positioned.heightPct / 100) * hourBandHeight,
                TimelineEngine.minPillHeight
            )
            let durationMinutes = BookingDisplay.CalendarFormatting.durationMinutes(
                start: start,
                end: end
            )

            let lane = TimelineEngine.columnLaneFrame(
                col: positioned.col,
                totalCols: positioned.totalCols,
                columnWidth: columnWidth,
                outer: 2,
                gap: 2
            )
            let overlapping = positioned.totalCols > 1

            calendarAppointmentButton(
                appointment: appointment,
                cardWidth: lane.width,
                cardHeight: cardHeight,
                durationMinutes: durationMinutes,
                isOverlapping: false,
                overlapCol: positioned.col,
                denseColumns: overlapping,
                hourHeight: hourHeight
            )
            .padding(.leading, lane.leading)
            .padding(.top, topInset)
            .zIndex(lane.zIndex)
        }
    }

    @ViewBuilder
    private func calendarAppointmentButton(
        appointment: Appointment,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        durationMinutes: Int,
        isOverlapping: Bool,
        overlapCol: Int,
        denseColumns: Bool,
        hourHeight: CGFloat
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4)

        Group {
            if let onAppointmentTap {
                Button {
                    onAppointmentTap(appointment)
                } label: {
                    cardContent(
                        appointment: appointment,
                        cardHeight: cardHeight,
                        durationMinutes: durationMinutes,
                        isOverlapping: isOverlapping,
                        overlapCol: overlapCol,
                        denseColumns: denseColumns,
                        hourHeight: hourHeight
                    )
                    .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(true)
            } else {
                cardContent(
                    appointment: appointment,
                    cardHeight: cardHeight,
                    durationMinutes: durationMinutes,
                    isOverlapping: isOverlapping,
                    overlapCol: overlapCol,
                    denseColumns: denseColumns,
                    hourHeight: hourHeight
                )
                .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                .allowsHitTesting(false)
            }
        }
    }

    private func cardContent(
        appointment: Appointment,
        cardHeight: CGFloat,
        durationMinutes: Int,
        isOverlapping: Bool,
        overlapCol: Int,
        denseColumns: Bool,
        hourHeight: CGFloat
    ) -> some View {
        DayColumnBookingCard(
            appointment: appointment,
            isWeekStyle: false,
            blockHeight: cardHeight,
            hourHeight: hourHeight,
            durationMinutes: durationMinutes,
            isOverlapping: isOverlapping,
            overlapCol: overlapCol,
            denseColumns: denseColumns
        )
    }
}
