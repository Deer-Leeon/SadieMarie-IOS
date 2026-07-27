import SwiftUI

// MARK: - Card

/// Appointment block inside a day column (3-day, week, and single-day modal).
/// No status pills — the grid only shows confirmed bookings.
struct DayColumnBookingCard: View {
    let appointment: Appointment
    let isWeekStyle: Bool
    let blockHeight: CGFloat
    let hourHeight: CGFloat
    let durationMinutes: Int

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var textColors: (primary: Color, secondary: Color) {
        BookingDisplay.rowTextColors(for: appointment)
    }
    private var usesServiceBackground: Bool {
        BookingDisplay.usesServiceColorBackground(appointment)
    }

    private var background: Color {
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.accent
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBackground
        }
        return AdminTheme.cardFill
    }

    /// Soft edge only for uncolored / pending rows. Service fills are solid like web.
    private var border: Color? {
        if usesServiceBackground { return nil }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBorder
        }
        return AdminTheme.stone200
    }

    private var cornerRadius: CGFloat { isWeekStyle ? 2 : 4 }

    /// Enough vertical room for name + a second detail line.
    private var canStackTwoLines: Bool {
        if durationMinutes < 40 { return false }
        return blockHeight >= 36
    }

    /// Tall enough (or 3-day width) to include the service name in details.
    private var includeService: Bool {
        if !canStackTwoLines {
            // Inline layout — 3-day has width; week truncates as needed.
            return !isWeekStyle || blockHeight >= 28
        }
        return durationMinutes >= 90 || blockHeight >= 56
    }

    private var clientName: String {
        if isWeekStyle && !canStackTwoLines {
            return BookingDisplay.CalendarFormatting.gridShortClientName(
                first: appointment.clientFirstName,
                last: appointment.clientLastName
            )
        }
        return BookingDisplay.clientDisplayName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
    }

    private var timeLabel: String {
        if isWeekStyle {
            return BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment)
        }
        return BookingDisplay.CalendarFormatting.formattedTimeRange(for: appointment)
    }

    private var serviceLabel: String {
        BookingDisplay.CalendarFormatting.gridShortServiceLabel(appointment)
    }

    private var detailBits: String {
        var parts: [String] = []
        if !timeLabel.isEmpty && timeLabel != "—" {
            parts.append(timeLabel)
        }
        if includeService, !serviceLabel.isEmpty {
            parts.append(serviceLabel)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(background)
                .overlay {
                    if let border {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(border, lineWidth: isWeekStyle ? 0.5 : 0.75)
                    }
                }

            Group {
                if canStackTwoLines {
                    stackedContent
                } else {
                    inlineContent
                }
            }
            .padding(.horizontal, isWeekStyle ? 3 : 5)
            .padding(.vertical, isWeekStyle ? 2 : 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: blockHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(isNoShow ? AdminTheme.Layout.noShowOpacity : 1)
    }

    // MARK: - Layouts

    /// Name on line 1; time · service on line 2 when height allows.
    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: isWeekStyle ? 1 : 2) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(
                    size: isWeekStyle ? 9 : 11,
                    weight: .semibold
                ))
                .foregroundStyle(textColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .strikethrough(isNoShow, color: textColors.secondary)

            if !detailBits.isEmpty {
                Text(detailBits)
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 8 : 9))
                    .foregroundStyle(textColors.secondary)
                    .lineLimit(isWeekStyle ? 1 : 2)
                    .minimumScaleFactor(0.7)
                    .strikethrough(isNoShow, color: textColors.secondary)
            }
        }
    }

    /// Short blocks: put details on the same line as the name (esp. 3-day).
    private var inlineContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(
                    size: isWeekStyle ? 8 : 10,
                    weight: .semibold
                ))
                .foregroundStyle(textColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .strikethrough(isNoShow, color: textColors.secondary)
                .layoutPriority(1)

            if !detailBits.isEmpty {
                Text(" · \(detailBits)")
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 7.5 : 9))
                    .foregroundStyle(textColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .strikethrough(isNoShow, color: textColors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
