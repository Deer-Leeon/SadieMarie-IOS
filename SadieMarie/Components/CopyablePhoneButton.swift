import SwiftUI
import UIKit

/// Displayed client phone number. A tap copies it to the clipboard.
struct CopyablePhoneButton: View {
    let phone: String
    var font: Font = AdminTheme.fontAdminSans(size: 13)
    var color: Color = AdminTheme.stone700
    var icon: String? = "phone"
    var iconPointSize: CGFloat = 11
    var spacing: CGFloat = 6

    @State private var didCopy = false
    @State private var copyGeneration = 0

    private var display: String {
        let formatted = Client(id: "clipboard", phone: phone).formattedPhone
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: spacing) {
            if let icon {
                Image(systemName: didCopy ? "checkmark" : icon)
                    .font(.system(size: iconPointSize, weight: .medium))
                    .foregroundStyle(didCopy ? AdminTheme.confirmedText : AdminTheme.stone500)
                    .frame(width: max(14, iconPointSize + 3))
            }
            Text(didCopy ? "Copied" : display)
                .font(font)
                .foregroundStyle(didCopy ? AdminTheme.confirmedText : color)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(TapGesture().onEnded { copy() })
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(didCopy ? "Copied phone number" : "Copy phone number \(display)")
        .accessibilityHint("Copies the phone number")
        .accessibilityAction(.default, copy)
    }

    private func copy() {
        guard !display.isEmpty else { return }
        UIPasteboard.general.string = display
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        copyGeneration += 1
        let generation = copyGeneration
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            if generation == copyGeneration {
                didCopy = false
            }
        }
    }
}
