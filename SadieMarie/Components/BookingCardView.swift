import SwiftUI

/// Single booking row — 3-column grid: time · name/service · status pill.
struct BookingCardView: View {
    let appointment: Appointment

    private var isNoShow: Bool { BookingDisplay.isNoShow(appointment) }
    private var textColors: (primary: Color, secondary: Color) {
        BookingDisplay.rowTextColors(for: appointment)
    }
    private var serviceColors: BookingDisplay.ServiceColor? {
        BookingDisplay.serviceColor(for: appointment)
    }

    private var usesServiceBackground: Bool {
        BookingDisplay.usesServiceColorBackground(appointment)
    }

    private var cardBackground: Color {
        if usesServiceBackground, let serviceColors {
            return serviceColors.accent
        }
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBackground
        }
        return AdminTheme.cardFill
    }

    private var cardBorder: Color {
        if BookingDisplay.isPending(appointment) {
            return AdminTheme.pendingBorder
        }
        return AdminTheme.stone200
    }

    var body: some View {
        HStack(alignment: .center, spacing: AdminTheme.Spacing.rowGridGap) {
            timeColumn
            nameServiceColumn
            Spacer(minLength: 0)
            BookingStatusPill(status: appointment.status)
        }
        .padding(.horizontal, AdminTheme.Spacing.rowHorizontal)
        .padding(.vertical, AdminTheme.Spacing.rowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .opacity(isNoShow ? AdminTheme.Layout.noShowOpacity : 1)
    }

    // MARK: - Columns

    private var timeColumn: some View {
        Text(BookingDisplay.formattedTime(for: appointment))
            .font(AdminTheme.fontAdminSerif(size: AdminTheme.Typography.timeSize))
            .foregroundStyle(textColors.primary)
            .strikethrough(isNoShow, color: textColors.secondary)
            .frame(width: AdminTheme.Spacing.timeColumnWidth, alignment: .leading)
    }

    private var nameServiceColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(BookingDisplay.clientDisplayName(
                first: appointment.clientFirstName,
                last: appointment.clientLastName
            ))
            .font(AdminTheme.fontAdminSans(
                size: AdminTheme.Typography.clientNameSize,
                weight: .medium
            ))
            .foregroundStyle(textColors.primary)
            .strikethrough(isNoShow, color: textColors.secondary)
            .lineLimit(1)

            Text(BookingDisplay.appointmentServiceLabel(appointment))
                .font(AdminTheme.fontAdminSans(size: AdminTheme.Typography.serviceSubtitleSize))
                .foregroundStyle(textColors.secondary)
                .strikethrough(isNoShow, color: textColors.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Booking cards") {
    ScrollView {
        VStack(spacing: AdminTheme.Spacing.cardStack) {
            BookingCardView(appointment: .mockConfirmed)
            BookingCardView(appointment: .mockPending)
            BookingCardView(appointment: .mockNoShow)
            BookingCardView(appointment: .mockConfirmedNeutral)
        }
        .padding()
    }
    .background(AdminTheme.cream)
}
