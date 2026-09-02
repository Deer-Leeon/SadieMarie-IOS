import SwiftUI

/// Quiet control used on Bookings list and client history.
struct ShowPastAppointmentsButton: View {
    var title: String = "Show Past Appointments"
    var chevronUp: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: chevronUp ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                Text(title)
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(0.9)
                    .textCase(.uppercase)
            }
            .foregroundStyle(AdminTheme.gray400)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
