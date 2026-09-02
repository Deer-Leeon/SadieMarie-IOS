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

    static func timeColumnWidth(isWeek: Bool) -> CGFloat {
        isWeek ? 40 : 44
    }

    static func horizontalPadding(isWeek: Bool) -> CGFloat {
        isWeek ? 0 : 4
    }

    /// Space between the day-number row and the 9 AM rule.
    static let gridTopGutter: CGFloat = 12
    /// Room above the 9 AM rule in the single-day sheet so the hour label
    /// (which sits 5pt above its line) does not collide with the hint bar.
    static let dayModalTopGutter: CGFloat = 16
    /// 9 PM sits on this strip below the last equal hour, not inside it.
    static let endCaptionHeight: CGFloat = 14
    /// Gap between hour labels and the day columns.
    static let timeLabelTrailingInset: CGFloat = 5
    /// Keeps the 9 PM caption just above the floating tab bar.
    static let timeGridBottomGutter: CGFloat = 4

    static func hourHeight(inAvailableHeight height: CGFloat) -> CGFloat {
        let usable = height - endCaptionHeight
        return max(usable, CGFloat(hourCount) * 8) / CGFloat(hourCount)
    }

    /// Nil until the container has a real height so the grid never paints a stub then jumps.
    static func resolvedHourHeight(inAvailableHeight height: CGFloat) -> CGFloat? {
        guard height > 80 else { return nil }
        return hourHeight(inAvailableHeight: height)
    }

    static func hourBandHeight(hourHeight: CGFloat) -> CGFloat {
        hourHeight * CGFloat(hourCount)
    }

    static func gridBodyHeight(hourHeight: CGFloat) -> CGFloat {
        hourBandHeight(hourHeight: hourHeight) + endCaptionHeight
    }

    /// Visual height of a 30-minute block (matches `blockHeight` for a half-hour slot).
    static func halfHourBandHeight(hourHeight: CGFloat) -> CGFloat {
        hourHeight * 0.5
    }
}
