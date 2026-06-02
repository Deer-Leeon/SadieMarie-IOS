import SwiftUI

/// Single-day timeline — same sizing and cards as the 3-day grid column.
struct SingleDayTimelineView: View {
    let items: [PositionedAppointment]
    var onAppointmentTap: ((Appointment) -> Void)?

    private let calendar = Calendar.current
    private let timeColumnWidth: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let gridHeight = max(geometry.size.height, 120)
            let hourHeight = gridHeight / CGFloat(BookingsCalendarLayout.hourCount)
            let timelineWidth = max(geometry.size.width - timeColumnWidth, 0)

            HStack(alignment: .top, spacing: 0) {
                timeLabelsColumn(hourHeight: hourHeight)
                    .frame(width: timeColumnWidth)

                ZStack(alignment: .topLeading) {
                    hourlyGridBackground(hourHeight: hourHeight)
                    appointmentCards(
                        hourHeight: hourHeight,
                        columnWidth: timelineWidth
                    )
                }
                .frame(width: timelineWidth, height: gridHeight)
                .clipped()
            }
            .frame(width: geometry.size.width, height: gridHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Time axis

    private func timeLabelsColumn(hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Text(hourLabel(for: hour))
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.gray400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    .padding(.top, 2)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }

    private func hourlyGridBackground(hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { _ in
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Appointments

    private func appointmentCards(hourHeight: CGFloat, columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(items) { positioned in
                positionedCard(
                    positioned,
                    hourHeight: hourHeight,
                    columnWidth: columnWidth
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

            let topInset = BookingDisplay.CalendarFormatting.yOffset(
                for: start,
                hourHeight: hourHeight,
                calendar: calendar
            )
            let cardHeight = BookingDisplay.CalendarFormatting.blockHeight(
                start: start,
                end: end,
                hourHeight: hourHeight
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
                hourHeight: hourHeight,
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
        hourHeight: CGFloat,
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
                        hourHeight: hourHeight,
                        durationMinutes: durationMinutes
                    )
                        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
            } else {
                cardContent(
                    appointment: appointment,
                    cardHeight: cardHeight,
                    hourHeight: hourHeight,
                    durationMinutes: durationMinutes
                )
                    .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 2)
    }

    private func cardContent(
        appointment: Appointment,
        cardHeight: CGFloat,
        hourHeight: CGFloat,
        durationMinutes: Int
    ) -> some View {
        DayColumnBookingCard(
            appointment: appointment,
            isWeekStyle: false,
            blockHeight: cardHeight,
            hourHeight: hourHeight,
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
