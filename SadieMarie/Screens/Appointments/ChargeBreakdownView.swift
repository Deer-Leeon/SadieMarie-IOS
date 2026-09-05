import SwiftUI

/// Line-item receipt for this visit’s service + extras.
struct ChargeBreakdownView: View {
    let lines: [ChargeLine]
    var totalCents: Int
    var heading: String? = nil

    private var showTotal: Bool { lines.count > 1 }

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let heading {
                    Text(heading)
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .tracking(1.8)
                        .foregroundStyle(AdminTheme.stone500)
                        .textCase(.uppercase)
                }

                VStack(spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        if index > 0 {
                            Divider()
                        }
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.label)
                                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                                    .foregroundStyle(AdminTheme.stone900)
                                if let detail = line.detail {
                                    Text(detail)
                                        .font(AdminTheme.fontAdminSans(size: 12))
                                        .foregroundStyle(AdminTheme.stone500)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(BookingDisplay.formattedCents(line.cents))
                                .font(AdminTheme.fontAdminSans(size: 14))
                                .foregroundStyle(AdminTheme.stone700)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }

                    if showTotal {
                        Divider()
                        HStack {
                            Text("Total")
                                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                            Spacer()
                            Text(BookingDisplay.formattedCents(totalCents))
                                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(AdminTheme.stone900)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AdminTheme.stone50)
                    }
                }
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
        }
    }
}
