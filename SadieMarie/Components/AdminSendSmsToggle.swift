import SwiftUI

/// Default-on “Text the client” charcoal checkbox for admin cancel / reschedule.
struct AdminSendSmsToggle: View {
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Text the client")
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Text("Uncheck to cancel/move this booking without a studio text.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(AdminSendSmsCheckboxStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .accessibilityHint("When off, the calendar still updates but the studio will not text the client.")
    }
}

/// Matches the website charcoal checkbox (`AdminSendSmsCheckbox`).
private struct AdminSendSmsCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(configuration.isOn ? AdminTheme.stone900 : Color.white)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(
                            configuration.isOn ? AdminTheme.stone900 : AdminTheme.stone300,
                            lineWidth: 1
                        )
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
        .animation(.easeInOut(duration: 0.12), value: configuration.isOn)
    }
}
