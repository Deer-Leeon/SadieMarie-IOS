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
    var compactOverlap: Bool = false
    var isOverlapping: Bool = false
    var overlapCol: Int = 0
    /// Daily view side-by-side lanes: tighter padding, full name still shown.
    var denseColumns: Bool = false

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var hasNoShowFlag: Bool { appointment.clientNoShowFlag }
    private var textColors: (primary: Color, secondary: Color) {
        BookingDisplay.rowTextColors(for: appointment)
    }
    private var usesServiceBackground: Bool {
        BookingDisplay.usesServiceColorBackground(appointment)
    }

    private var fillStyle: AnyShapeStyle {
        if !isNoShow, let paint = BookingDisplay.visitBlockPaint(for: appointment) {
            return paint.shapeStyle
        }
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return AnyShapeStyle(colors.accent)
        }
        if BookingDisplay.isPending(appointment) {
            return AnyShapeStyle(AdminTheme.pendingBackground)
        }
        return AnyShapeStyle(AdminTheme.cardFill)
    }

    /// Soft edge only for uncolored / pending rows. Service fills are solid like web.
    private var border: Color? {
        if hasNoShowFlag && !isNoShow {
            return AdminTheme.awaitingPaymentText.opacity(0.55)
        }
        if usesServiceBackground { return nil }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBorder
        }
        return AdminTheme.stone200
    }

    private var cornerRadius: CGFloat { isWeekStyle ? 2 : 4 }

    private var peekingUnder: Bool { compactOverlap && overlapCol == 0 }

    /// Enough vertical room for name + a second detail line.
    private var canStackTwoLines: Bool {
        if compactOverlap || peekingUnder { return false }
        if denseColumns { return blockHeight >= 32 }
        if durationMinutes < 40 { return false }
        return blockHeight >= 36
    }

    /// Tall enough (or 3-day width) to include the service name in details.
    private var includeService: Bool {
        if compactOverlap { return false }
        if denseColumns {
            return canStackTwoLines && (durationMinutes >= 45 || blockHeight >= 48)
        }
        if !canStackTwoLines {
            // Inline layout — 3-day has width; week truncates as needed.
            return !isWeekStyle || blockHeight >= 28
        }
        return durationMinutes >= 90 || blockHeight >= 56
    }

    private var clientName: String {
        if compactOverlap {
            let first = appointment.clientFirstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !first.isEmpty { return first }
        }
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
        if compactOverlap || isWeekStyle {
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
                .fill(fillStyle)
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
            .padding(.horizontal, peekingUnder ? 4 : (denseColumns ? 4 : (isWeekStyle ? 3 : 5)))
            .padding(.vertical, peekingUnder ? 2 : (denseColumns ? 3 : (isWeekStyle ? 2 : 4)))
            .padding(
                .trailing,
                peekingUnder
                    ? 0
                    : (appointment.terminalPayment?.isSettled == true
                        || hasNoShowFlag
                        || appointment.extraCount > 0
                        ? (isWeekStyle ? 16 : (denseColumns ? 14 : 20))
                        : 0)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Top-trailing cluster matches web TimeGrid pills: settlement
            // marker first, then optional no-show flag.
            if !peekingUnder {
            HStack(spacing: 2) {
                SettlementCheckMarker(
                    payment: appointment.terminalPayment,
                    size: isWeekStyle || denseColumns ? .sm : .md
                )
                ExtraCountBadge(
                    count: appointment.extraCount,
                    size: isWeekStyle || denseColumns ? .sm : .md
                )
                if hasNoShowFlag {
                    Image(systemName: "flag.fill")
                        .font(.system(size: isWeekStyle ? 7 : 8, weight: .bold))
                        .foregroundStyle(AdminTheme.awaitingPaymentText)
                        .padding(2)
                        .background(AdminTheme.awaitingPaymentBackground.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .accessibilityLabel("No-show flag")
                }
            }
            .padding(isWeekStyle ? 2 : 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: blockHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            if isOverlapping {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(overlapCol > 0 ? 0.78 : 0.45), lineWidth: 1)
            }
        }
        .shadow(
            color: Color.black.opacity(isOverlapping && overlapCol > 0 ? 0.16 : 0),
            radius: isOverlapping && overlapCol > 0 ? 6 : 0,
            x: 0,
            y: isOverlapping && overlapCol > 0 ? 2 : 0
        )
        .opacity(isNoShow ? AdminTheme.Layout.noShowOpacity : 1)
    }

    // MARK: - Layouts

    /// Name on line 1; time · service on line 2 when height allows.
    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: isWeekStyle ? 1 : 2) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(
                    size: isWeekStyle ? 9 : (denseColumns ? 12 : 11),
                    weight: .semibold
                ))
                .foregroundStyle(textColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(denseColumns ? 0.65 : 0.75)
                .strikethrough(isNoShow, color: textColors.secondary)

            if !detailBits.isEmpty {
                Text(detailBits)
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 8 : (denseColumns ? 10 : 9)))
                    .foregroundStyle(textColors.secondary)
                    .lineLimit(isWeekStyle ? 1 : 2)
                    .minimumScaleFactor(denseColumns ? 0.65 : 0.7)
                    .strikethrough(isNoShow, color: textColors.secondary)
            }
        }
    }

    /// Short blocks: put details on the same line as the name (esp. 3-day).
    private var inlineContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(
                    size: isWeekStyle ? 8 : (denseColumns ? 11 : 10),
                    weight: .semibold
                ))
                .foregroundStyle(textColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(denseColumns ? 0.6 : 0.7)
                .strikethrough(isNoShow, color: textColors.secondary)
                .layoutPriority(1)

            if !detailBits.isEmpty {
                Text(" · \(detailBits)")
                    .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 7.5 : (denseColumns ? 9 : 9)))
                    .foregroundStyle(textColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .strikethrough(isNoShow, color: textColors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
