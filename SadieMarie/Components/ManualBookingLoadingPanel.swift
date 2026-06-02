import SwiftUI

/// Loading state for Cal.com availability — always full-width (never inside a grid cell).
struct ManualBookingLoadingPanel: View {
    let title: String
    let subtitle: String
    var minHeight: CGFloat = 120

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProgressView()
                .controlSize(.regular)
                .tint(AdminTheme.stone700)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AdminTheme.stone50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Placeholder day circles while the month grid loads.
struct ManualBookingCalendarSkeleton: View {
    var rowCount: Int = 5
    var cellSize: CGFloat = 30

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<rowCount, id: \.self) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle()
                            .fill(AdminTheme.stone200.opacity(0.55))
                            .frame(width: cellSize, height: cellSize)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityLabel("Loading calendar")
    }
}
