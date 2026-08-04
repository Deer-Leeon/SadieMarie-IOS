import SwiftUI

/// Blocked-time pill on the single-day timeline (web `TimeBlockPill`).
struct TimeBlockPill: View {
    let block: TimeBlock
    var isRemoving = false
    var onTap: (() -> Void)?

    private var timeLabel: String {
        guard
            let start = BookingDisplay.iso8601Date(from: block.startTime),
            let end = BookingDisplay.iso8601Date(from: block.endTime)
        else {
            return "Blocked"
        }
        let formatter = DateFormatter()
        formatter.timeZone = StudioTime.timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        return "\(startText) – \(endText)"
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    pillBody
                }
                .buttonStyle(.plain)
            } else {
                pillBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .opacity(isRemoving ? 0.45 : 1)
    }

    private var pillBody: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AdminTheme.stone200.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            AdminTheme.stone300,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Blocked")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                Text(timeLabel)
                    .font(AdminTheme.fontAdminSans(size: 10))
                    .foregroundStyle(AdminTheme.stone700)
                    .lineLimit(1)
                if let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(AdminTheme.fontAdminSans(size: 10))
                        .foregroundStyle(AdminTheme.stone600)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
