import SwiftUI

// MARK: - Grid label typography

private enum GridAppointmentLabelStyle {
    static let threeDayTimeSize: CGFloat = 9
    static let threeDayNameSize: CGFloat = 9
    static let threeDayServiceSize: CGFloat = 8
    static let weekTimeSize: CGFloat = 8
    static let weekNameSize: CGFloat = 8
    static let horizontalPadding: CGFloat = 4
    static let verticalPadding: CGFloat = 2
    /// Natural height of the 3-day label band at scale 1.
    static let threeDayDesignBandHeight: CGFloat = 26
}

// MARK: - Card

/// Appointment block inside a day column (3-day, week, and single-day modal).
struct DayColumnBookingCard: View {
    let appointment: Appointment
    let isWeekStyle: Bool
    let blockHeight: CGFloat
    let hourHeight: CGFloat
    let durationMinutes: Int

    private var thirtyMinuteBlockHeight: CGFloat {
        BookingDisplay.CalendarFormatting.blockHeight(
            start: Date(),
            end: Date().addingTimeInterval(30 * 60),
            hourHeight: hourHeight
        )
    }

    /// 3-day: labels only in a half-hour band. Week: uses full block height.
    private var labelAreaHeight: CGFloat {
        if isWeekStyle {
            return blockHeight
        }
        return min(blockHeight, thirtyMinuteBlockHeight)
    }

    private var threeDayContentScale: CGFloat {
        guard !isWeekStyle, GridAppointmentLabelStyle.threeDayDesignBandHeight > 0 else { return 1 }
        return min(1, labelAreaHeight / GridAppointmentLabelStyle.threeDayDesignBandHeight)
    }

    private var cornerRadius: CGFloat { isWeekStyle ? 0 : 4 }

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var textColors: (primary: Color, secondary: Color) {
        BookingDisplay.rowTextColors(for: appointment)
    }
    private var usesServiceBackground: Bool { BookingDisplay.usesServiceColorBackground(appointment) }

    private var background: Color {
        if usesServiceBackground, let colors = BookingDisplay.serviceColor(for: appointment) {
            return colors.accent
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBackground
        }
        return AdminTheme.cardFill
    }

    private var border: Color {
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBorder
        }
        return AdminTheme.stone200
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border, lineWidth: isWeekStyle ? 0.5 : 0.75)
                )

            if isWeekStyle {
                weekSlotContent
                    .padding(.horizontal, 3)
                    .padding(.vertical, GridAppointmentLabelStyle.verticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: labelAreaHeight, alignment: .topLeading)
            } else {
                threeDaySlotContent
                    .padding(.horizontal, GridAppointmentLabelStyle.horizontalPadding)
                    .padding(.vertical, GridAppointmentLabelStyle.verticalPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: GridAppointmentLabelStyle.threeDayDesignBandHeight, alignment: .top)
                    .scaleEffect(threeDayContentScale, anchor: .topLeading)
                    .frame(height: labelAreaHeight, alignment: .top)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: blockHeight, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(isNoShow ? AdminTheme.Layout.noShowOpacity : 1)
    }

    // MARK: - 3-day layout

    /// Left: time + name on one line. Right: status on top, service directly under it.
    private var threeDaySlotContent: some View {
        HStack(alignment: .top, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment))
                    .font(AdminTheme.fontAdminSerif(size: GridAppointmentLabelStyle.threeDayTimeSize))
                    .foregroundStyle(textColors.primary)
                    .fixedSize(horizontal: true, vertical: true)

                Text(threeDayClientLabel)
                    .font(AdminTheme.fontAdminSans(size: GridAppointmentLabelStyle.threeDayNameSize, weight: .medium))
                    .foregroundStyle(textColors.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                GridStatusLabel(status: appointment.status)

                Text(BookingDisplay.CalendarFormatting.gridShortServiceLabel(appointment))
                    .font(AdminTheme.fontAdminSans(size: GridAppointmentLabelStyle.threeDayServiceSize))
                    .foregroundStyle(textColors.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .layoutPriority(1)
        }
    }

    private var threeDayClientLabel: String {
        BookingDisplay.clientDisplayName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
    }

    // MARK: - Week layout

    private var weekSlotContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: 2) {
                Text(BookingDisplay.CalendarFormatting.formattedChipTime(for: appointment))
                    .font(AdminTheme.fontAdminSerif(size: GridAppointmentLabelStyle.weekTimeSize))
                    .foregroundStyle(textColors.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)

                Spacer(minLength: 0)

                GridStatusLabel(status: appointment.status)
            }

            Text(weekClientLabel)
                .font(AdminTheme.fontAdminSans(size: GridAppointmentLabelStyle.weekNameSize, weight: .medium))
                .foregroundStyle(textColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var weekClientLabel: String {
        BookingDisplay.CalendarFormatting.gridShortClientName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
    }
}

// MARK: - Status chip

/// Small status tag for grid blocks — semantic fill, white text.
struct GridStatusLabel: View {
    let status: String?

    private var normalized: String {
        (status ?? "").lowercased()
    }

    private var label: String {
        switch normalized {
        case "confirmed": return "Confirmed"
        case "pending": return "Pending"
        case "no-show": return "No-show"
        case "canceled_by_admin": return "Cancelled"
        case "canceled_by_client_late": return "Late cancel"
        case "canceled_by_client", "cancelled": return "Cancelled"
        case "canceled_by_system": return "Cancelled"
        default: return "Status"
        }
    }

    private var pillColors: (fill: Color, border: Color) {
        switch normalized {
        case "confirmed":
            return (
                Color(red: 4 / 255, green: 120 / 255, blue: 87 / 255),
                AdminTheme.confirmedBorder.opacity(0.85)
            )
        case "pending":
            return (
                Color(red: 180 / 255, green: 83 / 255, blue: 9 / 255),
                AdminTheme.awaitingPaymentBorder.opacity(0.85)
            )
        case "no-show":
            return (
                Color(red: 87 / 255, green: 83 / 255, blue: 78 / 255),
                AdminTheme.noShowBorder.opacity(0.9)
            )
        case "canceled_by_client_late":
            return (
                Color(red: 194 / 255, green: 65 / 255, blue: 12 / 255),
                AdminTheme.awaitingPaymentBorder.opacity(0.85)
            )
        case "canceled_by_admin", "canceled_by_client", "cancelled", "canceled_by_system":
            return (
                AdminTheme.rose600,
                Color(red: 254 / 255, green: 205 / 255, blue: 211 / 255).opacity(0.75)
            )
        default:
            return (
                Color(red: 68 / 255, green: 64 / 255, blue: 60 / 255),
                AdminTheme.stone200.opacity(0.8)
            )
        }
    }

    var body: some View {
        Text(label)
            .font(AdminTheme.fontAdminSans(size: 7.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.96))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(pillColors.fill)
            .overlay(
                Capsule()
                    .stroke(pillColors.border, lineWidth: 0.5)
            )
            .clipShape(Capsule())
    }
}
