import SwiftUI

/// Web-style range title + prev / Today / next controls.
struct BookingsCalendarHeader: View {
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
                navButton(systemName: "chevron.left", action: onPrevious)
                todayButton
                navButton(systemName: "chevron.right", action: onNext)
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

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
                .frame(width: 36, height: 36)
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
