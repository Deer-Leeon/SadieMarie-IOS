import SwiftUI

// MARK: - Pager drag state

private struct CalendarPagerIsDraggingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while the 3-day / week pager is actively handling a horizontal swipe.
    var calendarPagerIsDragging: Bool {
        get { self[CalendarPagerIsDraggingKey.self] }
        set { self[CalendarPagerIsDraggingKey.self] = newValue }
    }
}

// MARK: - Tap without blocking parent swipe gestures

/// Fires `action` on a quick tap. Ignored while the range pager is dragging or
/// immediately after a swipe so swipes starting on appointments still page.
struct CalendarGridTapAction: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.calendarPagerIsDragging) private var pagerIsDragging

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                // Let horizontal swipes pass through to the range pager while dragging.
                .allowsHitTesting(!pagerIsDragging)
                .onTapGesture {
                    guard !pagerIsDragging else { return }
                    action()
                }
        } else {
            content
        }
    }
}

extension View {
    func calendarGridTapAction(isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(CalendarGridTapAction(isEnabled: isEnabled, action: action))
    }
}
