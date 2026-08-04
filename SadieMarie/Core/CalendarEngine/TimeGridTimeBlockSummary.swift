import SwiftUI

/// Quiet blocked-time treatment for 3-day and week grids. Appointment cards
/// remain visually dominant while unavailable time is still obvious.
struct TimeGridTimeBlockSummary: View {
    let block: TimeBlock
    let isWeekStyle: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: isWeekStyle ? 7 : 9, weight: .semibold))
            if !isWeekStyle || blockLabel.count <= 12 {
                Text(blockLabel)
                    .lineLimit(isWeekStyle ? 1 : 2)
            }
        }
        .font(AdminTheme.fontAdminSans(size: isWeekStyle ? 8 : 10, weight: .medium))
        .foregroundStyle(AdminTheme.stone600)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, isWeekStyle ? 2 : 5)
        .padding(.vertical, isWeekStyle ? 2 : 4)
        .background(AdminTheme.stone100.opacity(0.92))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    AdminTheme.stone500.opacity(0.45),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 2])
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("\(blockLabel), blocked time")
    }

    private var blockLabel: String {
        let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return note?.isEmpty == false ? note! : "Blocked"
    }
}
