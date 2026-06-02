import SwiftUI

/// Single day in the month grid — flush cell in a continuous SUN–SAT grid.
struct MonthDayCellView: View {
    let date: Date
    let appointments: [Appointment]
    let isToday: Bool
    var onDayClick: ((Date) -> Void)?

    private var sortedAppointments: [Appointment] {
        appointments.sorted { lhs, rhs in
            let left = lhs.bookingTime ?? ""
            let right = rhs.bookingTime ?? ""
            return left < right
        }
    }

    var body: some View {
        Group {
            if let onDayClick {
                Button {
                    onDayClick(date)
                } label: {
                    cellContent
                }
                .buttonStyle(.plain)
            } else {
                cellContent
            }
        }
    }

    private var cellContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            dayNumber

            if let first = sortedAppointments.first {
                MonthAppointmentChip(appointment: first)
                    .allowsHitTesting(false)

                let remaining = sortedAppointments.count - 1
                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(5)
        .frame(
            maxWidth: .infinity,
            minHeight: BookingsCalendarLayout.monthCellHeight,
            maxHeight: BookingsCalendarLayout.monthCellHeight,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
        .clipped()
        .background(AdminTheme.cardFill)
        .monthGridCellBorder()
    }

    @ViewBuilder
    private var dayNumber: some View {
        let number = BookingDisplay.CalendarFormatting.dayNumber(for: date)
        if isToday {
            Text("\(number)")
                .font(AdminTheme.fontAdminSerif(size: 12))
                .foregroundStyle(AdminTheme.cardFill)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AdminTheme.stone900))
        } else {
            Text("\(number)")
                .font(AdminTheme.fontAdminSerif(size: 12))
                .foregroundStyle(AdminTheme.stone900)
        }
    }
}

/// Padding cell before/after days in the month grid (still part of the grid).
struct MonthGridPaddingCell: View {
    var body: some View {
        Color(AdminTheme.cardFill)
            .frame(
                maxWidth: .infinity,
                minHeight: BookingsCalendarLayout.monthCellHeight,
                maxHeight: BookingsCalendarLayout.monthCellHeight
            )
            .monthGridCellBorder()
    }
}

// MARK: - Grid lines

extension View {
    /// Right + bottom edge per cell.
    func monthGridCellBorder() -> some View {
        overlay(alignment: .trailing) {
            Rectangle()
                .fill(AdminTheme.stone200.opacity(0.65))
                .frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200.opacity(0.65))
                .frame(height: 0.5)
        }
    }

    /// Top + left edge for the full month grid block.
    func monthGridOuterBorder() -> some View {
        overlay(alignment: .top) {
            Rectangle()
                .fill(AdminTheme.stone200.opacity(0.65))
                .frame(height: 0.5)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AdminTheme.stone200.opacity(0.65))
                .frame(width: 0.5)
        }
    }
}
