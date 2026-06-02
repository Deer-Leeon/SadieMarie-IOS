import SwiftUI

/// Google Calendar-style 3-day or week grid (web `TimeGrid`).
struct TimeGridView: View {
    let appointments: [Appointment]
    let currentDate: Date
    let daysToShow: Int
    var onDayClick: ((Date) -> Void)?
    var onAppointmentClick: ((Appointment) -> Void)?

    private let calendar = Calendar.current

    private var days: [Date] {
        TimelineEngine.visibleDays(currentDate: currentDate, daysToShow: daysToShow, calendar: calendar)
    }

    private var columns: [(date: Date, items: [PositionedAppointment])] {
        days.map { date in
            (date, TimelineEngine.layoutForDay(date: date, appointments: appointments))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            HStack(alignment: .top, spacing: 0) {
                hourLabelColumn

                ForEach(columns, id: \.date) { column in
                    DayColumnBody(items: column.items, onAppointmentTap: onAppointmentClick)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .leading) {
                            if column.date != days.first {
                                Rectangle()
                                    .fill(AdminTheme.stone200)
                                    .frame(width: 0.5)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AdminTheme.cream)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: TimelineEngine.hourLabelColumnWidth)

            ForEach(days, id: \.self) { day in
                DayColumnHeader(date: day, onTap: onDayClick)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if day != days.first {
                            Rectangle()
                                .fill(AdminTheme.stone200)
                                .frame(width: 0.5)
                        }
                    }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
    }

    private var hourLabelColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<TimelineEngine.hours, id: \.self) { index in
                let hour = TimelineEngine.startHour + index
                Text(hourLabel(for: hour))
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.gray400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 6)
                    .padding(.top, 2)
            }
        }
        .frame(width: TimelineEngine.hourLabelColumnWidth)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(width: 0.5)
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
}
