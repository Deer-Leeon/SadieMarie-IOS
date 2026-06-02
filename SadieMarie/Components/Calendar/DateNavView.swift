import SwiftUI

/// Prev / Today / Next navigation with a date-range label (web `DateNav`).
struct DateNavView: View {
    let title: String
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(AdminTheme.fontAdminSerif(size: 21))
                .foregroundStyle(AdminTheme.stone900)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                textNavButton("Prev", action: onPrevious)
                todayButton
                textNavButton("Next", action: onNext)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AdminTheme.cream)
    }

    private var todayButton: some View {
        Button(action: onToday) {
            Text("Today")
                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AdminTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private func textNavButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 14, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AdminTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
