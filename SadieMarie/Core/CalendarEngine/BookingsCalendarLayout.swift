import SwiftUI

/// Shared layout tokens for admin calendar views.
enum BookingsCalendarLayout {
    static let hourStart = BookingDisplay.CalendarFormatting.layoutHourStart
    static let hourEnd = BookingDisplay.CalendarFormatting.layoutHourEnd
    static let hourCount = hourEnd - hourStart

    /// Fixed height for every month grid cell (keeps rows uniform).
    static let monthCellHeight: CGFloat = 56
    static let weekdayHeaderHeight: CGFloat = 28
    static let dayColumnHeaderHeight: CGFloat = 40

    static func hourHeight(dayCount: Int) -> CGFloat {
        dayCount >= 7 ? 36 : 44
    }

    static func gridContentHeight(dayCount: Int) -> CGFloat {
        CGFloat(hourCount) * hourHeight(dayCount: dayCount)
    }

    /// Visual height of a 30-minute block (matches `blockHeight` for a half-hour slot).
    static func halfHourBandHeight(hourHeight: CGFloat) -> CGFloat {
        hourHeight * 0.5 - 2
    }
}
