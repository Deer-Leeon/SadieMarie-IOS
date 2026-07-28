import SwiftUI

/// Absolutely positioned appointment block in a day column (web `AppointmentBlock`).
struct TimelinePillView: View {
    let positioned: PositionedAppointment
    let columnWidth: CGFloat
    let columnHeight: CGFloat
  var onTap: ((Appointment) -> Void)?

    private var appointment: Appointment { positioned.appointment }

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var hasNoShowFlag: Bool { appointment.clientNoShowFlag }

    private var serviceColors: BookingDisplay.ServiceColor? {
        isNoShow ? nil : BookingDisplay.serviceColor(for: appointment)
    }

    private var frameWidth: CGFloat {
        let widthPct = 100.0 / Double(positioned.totalCols)
        return max(columnWidth * CGFloat(widthPct / 100) - 4, 8)
    }

    private var frameHeight: CGFloat {
        max(columnHeight * CGFloat(positioned.heightPct / 100), TimelineEngine.minPillHeight)
    }

    private var xOffset: CGFloat {
        let widthPct = 100.0 / Double(positioned.totalCols)
        return columnWidth * CGFloat(Double(positioned.col) * widthPct / 100) + 2
    }

    private var yOffset: CGFloat {
        columnHeight * CGFloat(positioned.topPct / 100)
    }

    private var timeLabel: String {
        BookingDisplay.CalendarFormatting.formattedTimeRange(for: appointment)
    }

    private var clientName: String {
        BookingDisplay.clientDisplayName(
            first: appointment.clientFirstName,
            last: appointment.clientLastName
        )
    }

    private var serviceLabel: String {
        BookingDisplay.appointmentServiceLabel(appointment)
    }

    private var usesCompactLayout: Bool {
        frameHeight < 40
    }

    var body: some View {
        Button {
            onTap?(appointment)
        } label: {
            pillContent
                .frame(width: frameWidth, height: frameHeight, alignment: .topLeading)
                .background(backgroundColor)
                .overlay(pillBorder)
                .overlay(alignment: .topTrailing) {
                    if hasNoShowFlag {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AdminTheme.awaitingPaymentText)
                            .padding(3)
                            .background(AdminTheme.awaitingPaymentBackground.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(3)
                            .accessibilityLabel("No-show flag")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    /// Leading/top inset within the day column (padding preserves hit testing vs `.offset`).
    var leadingInset: CGFloat { xOffset }
    var topInset: CGFloat { yOffset }

    @ViewBuilder
    private var pillContent: some View {
        if usesCompactLayout {
            compactContent
        } else {
            standardContent
        }
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .strikethrough(isNoShow, color: secondaryText)

            Text(subtitleLine)
                .font(AdminTheme.fontAdminSans(size: 10))
                .foregroundStyle(secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .strikethrough(isNoShow, color: secondaryText)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(clientName)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .strikethrough(isNoShow, color: secondaryText)

            Spacer(minLength: 0)

            Text(serviceLabel)
                .font(AdminTheme.fontAdminSans(size: 8))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .strikethrough(isNoShow, color: secondaryText)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitleLine: String {
        if timeLabel.isEmpty { return serviceLabel }
        if serviceLabel.isEmpty { return timeLabel }
        return "\(timeLabel) · \(serviceLabel)"
    }

    private var primaryText: Color {
        if isNoShow { return AdminTheme.gray400 }
        if let colors = serviceColors { return colors.text }
        return AdminTheme.stone900
    }

    private var secondaryText: Color {
        if isNoShow { return AdminTheme.gray400 }
        if let colors = serviceColors { return colors.textMuted }
        return AdminTheme.stone500
    }

    private var backgroundColor: Color {
        if isNoShow { return AdminTheme.stone50 }
        if let colors = serviceColors { return colors.accent }
        if BookingDisplay.isPending(appointment) { return AdminTheme.pendingBackground }
        return AdminTheme.stone100
    }

    @ViewBuilder
    private var pillBorder: some View {
        if isNoShow {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AdminTheme.gray400, lineWidth: 1)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AdminTheme.gray400)
                        .frame(width: 3)
                }
        } else if hasNoShowFlag {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AdminTheme.awaitingPaymentText.opacity(0.55), lineWidth: 1)
                .overlay(alignment: .leading) {
                    if serviceColors == nil {
                        Rectangle()
                            .fill(AdminTheme.stone900)
                            .frame(width: 3)
                    }
                }
        } else if serviceColors == nil {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AdminTheme.stone900.opacity(0.85), lineWidth: 1)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AdminTheme.stone900)
                        .frame(width: 3)
                }
        } else {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.black.opacity(0.85), lineWidth: 1)
        }
    }
}
