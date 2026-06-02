import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps behind the main content.
    ///
    /// Uses a **background** layer (not a full-screen overlay) so text fields and
    /// buttons in front continue to receive touches.
    func dismissKeyboardOnBackgroundTap(isEnabled: Bool, onDismiss: @escaping () -> Void) -> some View {
        background {
            if isEnabled {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
            }
        }
    }
}
