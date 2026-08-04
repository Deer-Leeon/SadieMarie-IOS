import SwiftUI

/// Single-day timeline — hour grid with tappable rows for blocking time.
struct SingleDayTimelineView: View {
    let items: [PositionedAppointment]
    let timeBlocks: [PositionedTimeBlock]
    var removingBlockId: String?
    var onHourTap: ((Int) -> Void)?
    var onAppointmentTap: ((Appointment) -> Void)?
    var onBlockTap: ((TimeBlock) -> Void)?

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 56
    private let hourRowMinHeight: CGFloat = 56

    private var gridHeight: CGFloat {
        CGFloat(BookingsCalendarLayout.hourCount) * hourRowMinHeight
    }

    private var isEmpty: Bool {
        items.isEmpty && timeBlocks.isEmpty
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                timeLabelsColumn
                    .frame(width: timeColumnWidth)

                ZStack(alignment: .topLeading) {
                    hourGridLines
                    hourTapRows
                    if isEmpty {
                        emptyHint
                    }
                    timeBlockPills
                        .zIndex(2)
                    appointmentCards
                        .zIndex(3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: gridHeight)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Time axis

    private var timeLabelsColumn: some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Text(hourLabel(for: hour))
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.gray400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    .padding(.top, 6)
                    .frame(height: hourRowMinHeight, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }

    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { _ in
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: hourRowMinHeight, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }

    private var hourTapRows: some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Button {
                    onHourTap?(hour)
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: hourRowMinHeight)
                .accessibilityLabel("Block time starting at \(hourLabel(for: hour))")
            }
        }
    }

    private var emptyHint: some View {
        Text("No bookings — tap an hour to block")
            .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .textCase(.uppercase)
            .tracking(1.2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    // MARK: - Blocks

    private var timeBlockPills: some View {
        GeometryReader { geometry in
            ForEach(timeBlocks) { positioned in
                let top = geometry.size.height * CGFloat(positioned.topPct / 100)
                let height = max(
                    geometry.size.height * CGFloat(positioned.heightPct / 100),
                    TimelineEngine.minPillHeight
                )

                TimeBlockPill(
                    block: positioned.block,
                    isRemoving: removingBlockId == positioned.block.id,
                    onTap: onBlockTap.map { handler in { handler(positioned.block) } }
                )
                .frame(width: geometry.size.width - 8, height: height)
                .offset(x: 4, y: top)
            }
        }
    }

    // MARK: - Appointments

    private var appointmentCards: some View {
        GeometryReader { geometry in
            ForEach(items) { positioned in
                positionedCard(
                    positioned,
                    columnWidth: geometry.size.width
                )
            }
        }
    }

    @ViewBuilder
    private func positionedCard(
        _ positioned: PositionedAppointment,
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

            let topInset = columnWidth > 0
                ? CGFloat(positioned.topPct / 100) * (CGFloat(BookingsCalendarLayout.hourCount) * hourRowMinHeight)
                : 0
            let cardHeight = max(
                CGFloat(positioned.heightPct / 100) * (CGFloat(BookingsCalendarLayout.hourCount) * hourRowMinHeight),
                TimelineEngine.minPillHeight
            )
            let durationMinutes = BookingDisplay.CalendarFormatting.durationMinutes(
                start: start,
                end: end
            )

            let widthPct = 100.0 / Double(positioned.totalCols)
            let cardWidth = max(columnWidth * CGFloat(widthPct / 100) - 4, 8)
            let leading = columnWidth * CGFloat(Double(positioned.col) * widthPct / 100) + 2

            calendarAppointmentButton(
                appointment: appointment,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                durationMinutes: durationMinutes
            )
            .padding(.leading, leading)
            .padding(.top, topInset)
        }
    }

    @ViewBuilder
    private func calendarAppointmentButton(
        appointment: Appointment,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        durationMinutes: Int
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
                        durationMinutes: durationMinutes
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
                    durationMinutes: durationMinutes
                )
                .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 2)
    }

    private func cardContent(
        appointment: Appointment,
        cardHeight: CGFloat,
        durationMinutes: Int
    ) -> some View {
        DayColumnBookingCard(
            appointment: appointment,
            isWeekStyle: false,
            blockHeight: cardHeight,
            hourHeight: hourRowMinHeight,
            durationMinutes: durationMinutes
        )
    }

    private func hourLabel(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
