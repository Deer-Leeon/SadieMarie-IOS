import SwiftUI

/// 3-day and week — full-width columns; hourly grid fills all space above the tab bar.
struct BookingsTimeGridView: View {
    let days: [Date]
    @Bindable var store: AppointmentCalendarStore
    var onDayClick: ((Date) -> Void)?
    var onSelectAppointment: ((Appointment) -> Void)?

    private let calendar = Calendar.current
    private var isWeekStyle: Bool { days.count >= 7 }
    private var timeColumnWidth: CGFloat { isWeekStyle ? 40 : 44 }

    var body: some View {
        let _ = store.revision

        return GeometryReader { geometry in
            let headerHeight = BookingsCalendarLayout.dayColumnHeaderHeight
            let gridHeight = max(geometry.size.height - headerHeight, 120)
            let hourHeight = gridHeight / CGFloat(BookingsCalendarLayout.hourCount)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: timeColumnWidth, height: BookingsCalendarLayout.dayColumnHeaderHeight)
                    dayHeadersRow
                }

                HStack(alignment: .top, spacing: 0) {
                    timeLabelsColumn(hourHeight: hourHeight)
                        .frame(width: timeColumnWidth)

                    ZStack(alignment: .topLeading) {
                        hourlyGridBackground(hourHeight: hourHeight)
                        if isWeekStyle {
                            weekColumnDividers
                        }

                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                                dayGridColumn(
                                    for: day,
                                    showLeadingDivider: !isWeekStyle && index > 0,
                                    hourHeight: hourHeight
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: gridHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .padding(.horizontal, isWeekStyle ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream)
    }

    // MARK: - Headers

    private var dayHeadersRow: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayColumnHeader(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: BookingsCalendarLayout.dayColumnHeaderHeight)
    }

    // MARK: - Time labels

    private func timeLabelsColumn(hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(BookingsCalendarLayout.hourStart..<BookingsCalendarLayout.hourEnd, id: \.self) { hour in
                Text(hourLabel(for: hour))
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 9 : 10, weight: .medium))
                    .foregroundStyle(AdminTheme.gray400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    .padding(.top, 2)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
        .allowsHitTesting(false)
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

    // MARK: - Week column guides (hairlines only — no boxed columns)

    private var weekColumnDividers: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / CGFloat(days.count)
            ForEach(1..<days.count, id: \.self) { index in
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(width: 0.5)
                    .offset(x: columnWidth * CGFloat(index) - 0.25)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Hour grid (lines only)

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
    }

    // MARK: - Day column

    private func dayGridColumn(
        for day: Date,
        showLeadingDivider: Bool,
        hourHeight: CGFloat
    ) -> some View {
        let items = store.appointments(on: day)

        return ZStack(alignment: .topLeading) {
            if showLeadingDivider {
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity, alignment: .leading)
            }

            ForEach(items) { appointment in
                positionedCard(appointment, hourHeight: hourHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func positionedCard(_ appointment: Appointment, hourHeight: CGFloat) -> some View {
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

            calendarAppointmentButton(
                appointment: appointment,
                cardHeight: cardHeight,
                topInset: y,
                content: {
                    DayColumnBookingCard(
                        appointment: appointment,
                        isWeekStyle: isWeekStyle,
                        blockHeight: cardHeight,
                        hourHeight: hourHeight,
                        durationMinutes: durationMinutes
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func calendarAppointmentButton<Content: View>(
        appointment: Appointment,
        cardHeight: CGFloat,
        topInset: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: isWeekStyle ? 0 : 4)

        Group {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: cardHeight, alignment: .top)
                .contentShape(shape)
                .calendarGridTapAction(isEnabled: onSelectAppointment != nil) {
                    onSelectAppointment?(appointment)
                }
        }
        .padding(.horizontal, isWeekStyle ? 0 : 2)
        .padding(.top, topInset)
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
}
