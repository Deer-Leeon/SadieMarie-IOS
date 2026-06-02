import SwiftUI

// MARK: - Header

struct DayColumnHeader: View {
    let date: Date
    var onTap: ((Date) -> Void)?

    private let calendar = Calendar.current

    var body: some View {
        Button {
            onTap?(date)
        } label: {
            VStack(spacing: 4) {
                Text(BookingDisplay.CalendarFormatting.shortWeekday(for: date))
                    .font(AdminTheme.fontAdminSerif(size: 14))
                    .foregroundStyle(AdminTheme.stone900)

                dayNumber
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    @ViewBuilder
    private var dayNumber: some View {
        let number = BookingDisplay.CalendarFormatting.dayNumber(for: date, calendar: calendar)
        if BookingDisplay.CalendarFormatting.isToday(date, calendar: calendar) {
            Text("\(number)")
                .font(AdminTheme.fontAdminSerif(size: 14))
                .foregroundStyle(AdminTheme.cardFill)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AdminTheme.stone900))
        } else {
            Text("\(number)")
                .font(AdminTheme.fontAdminSerif(size: 20))
                .foregroundStyle(AdminTheme.stone900)
        }
    }
}

// MARK: - Body

/// 9 AM – 9 PM column. Grid lines are inert; only pills accept taps.
struct DayColumnBody: View {
    let items: [PositionedAppointment]
    var onAppointmentTap: ((Appointment) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                hourGrid(size: geometry.size)
                pills(size: geometry.size)
            }
        }
    }

    private func hourGrid(size: CGSize) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<TimelineEngine.hours, id: \.self) { _ in
                Rectangle()
                    .fill(AdminTheme.stone200)
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func pills(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(items) { positioned in
                let pill = TimelinePillView(
                    positioned: positioned,
                    columnWidth: size.width,
                    columnHeight: size.height,
                    onTap: onAppointmentTap
                )
                pill
                    .padding(.leading, pill.leadingInset)
                    .padding(.top, pill.topInset)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Full column with header + body (used in `SingleDayModal`).
struct DayColumnView: View {
    let date: Date
    let items: [PositionedAppointment]
    var showsHeader: Bool = true
    var onDayHeaderTap: ((Date) -> Void)?
    var onAppointmentTap: ((Appointment) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                DayColumnHeader(date: date, onTap: onDayHeaderTap)
            }
            DayColumnBody(items: items, onAppointmentTap: onAppointmentTap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
