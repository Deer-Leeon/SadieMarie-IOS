import SwiftUI

/// White bordered card used in appointment / client detail sheets.
struct AdminDetailCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
    }
}
