import SwiftUI
import UIKit

/// Makes `Picker(.segmented)` readable on cream admin screens (dark labels, white selected pill).
enum AdminSegmentedControlAppearance {
    static func applyForLightAdminScreens() {
        let control = UISegmentedControl.appearance()
        control.selectedSegmentTintColor = UIColor(AdminTheme.cardFill)
        control.backgroundColor = UIColor(AdminTheme.stone200)
        control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor(AdminTheme.stone700),
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            ],
            for: .normal
        )
        control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor(AdminTheme.stone900),
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            ],
            for: .selected
        )
    }
}

private struct AdminLightSegmentedPickerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .tint(AdminTheme.stone900)
            .colorScheme(.light)
            .onAppear {
                AdminSegmentedControlAppearance.applyForLightAdminScreens()
            }
    }
}

extension View {
    func adminLightSegmentedPicker() -> some View {
        modifier(AdminLightSegmentedPickerModifier())
    }
}
