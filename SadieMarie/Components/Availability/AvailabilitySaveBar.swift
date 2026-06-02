import SwiftUI

struct AvailabilitySaveBar: View {
    let hasChanges: Bool
    let isSaving: Bool
    let action: () -> Void

    private var isActive: Bool { hasChanges && !isSaving }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(AdminTheme.stone200)

            Button(action: action) {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(AdminTheme.cardFill)
                    } else {
                        Text("Save changes")
                            .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(isActive ? AdminTheme.cardFill : AdminTheme.stone600)
                .background(isActive ? AdminTheme.stone900 : AdminTheme.stone200)
                .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
            }
            .disabled(!hasChanges || isSaving)
            .buttonStyle(.plain)
            .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(AdminTheme.cream.opacity(0.98))
    }
}
