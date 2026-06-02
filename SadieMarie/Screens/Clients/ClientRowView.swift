import SwiftUI

/// Single row in the clients CRM list — tap opens the full client profile.
struct ClientRowView: View {
    let client: Client
    var onRowTapped: (() -> Void)?
    let onSelect: () -> Void

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        Button(action: onSelect) {
            rowContent
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens client profile")
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(client.displayName)
                        .font(AdminTheme.fontAdminSerif(size: 16))
                        .foregroundStyle(AdminTheme.stone900)

                    metadataSection
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    badgeColumn

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }

            statsRow
        }
        .padding(.horizontal, AdminTheme.Spacing.rowHorizontal)
        .padding(.vertical, AdminTheme.Spacing.rowVertical)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AdminTheme.stone100)
                .frame(width: 40, height: 40)

            Image(systemName: "person.fill")
                .font(.system(size: 18))
                .foregroundStyle(AdminTheme.stone500)
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        if let email = client.email, !email.isEmpty {
            metadataLine(icon: "envelope", text: email)
        }

        if let phone = client.phone, !phone.isEmpty {
            metadataLine(icon: "phone", text: client.formattedPhone)
        }
    }

    private func metadataLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)
                .frame(width: 14)

            Text(text)
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone700)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var badgeColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if client.riskFlag {
                Text("Risk")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(AdminTheme.Typography.statusPillTracking)
                    .foregroundStyle(AdminTheme.awaitingPaymentText)
                    .padding(.horizontal, AdminTheme.Spacing.pillHorizontal)
                    .padding(.vertical, AdminTheme.Spacing.pillVertical)
                    .background(AdminTheme.awaitingPaymentBackground)
                    .overlay(
                        Capsule()
                            .stroke(AdminTheme.awaitingPaymentBorder, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }

            if client.hasVaultedCard {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.confirmedText)
                    .accessibilityLabel("Vaulted card on file")
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            Text("Bookings: \(client.stats.bookingCount)")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)
                .monospacedDigit()

            Text("LTV: \(formattedLTV)")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)
                .monospacedDigit()
        }
        .padding(.leading, 52)
    }

    private var formattedLTV: String {
        Self.currencyFormatter.string(from: NSNumber(value: client.stats.ltv))
            ?? String(format: "$%.0f", client.stats.ltv)
    }
}

#Preview {
    ClientRowView(client: .previewVaulted) {}
        .padding()
        .background(AdminTheme.cream)
}
