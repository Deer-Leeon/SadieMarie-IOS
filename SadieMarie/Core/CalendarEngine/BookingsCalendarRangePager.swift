import SwiftUI

/// Swipeable horizontal pager for 3-day / week calendar grids.
///
/// Renders previous · current · next ranges side by side and follows the finger
/// during a horizontal drag. Commits to the adjacent range when the swipe passes
/// a distance or velocity threshold (same step as the header chevrons).
struct BookingsCalendarRangePager<Content: View>: View {
    let rangeStart: Date
    let stepDays: Int
    let calendar: Calendar
    let daysForRangeStart: (Date) -> [Date]
    let onCommitNavigation: (Int) -> Void
    @ViewBuilder let content: ([Date]) -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var suppressChildTaps = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let previousStart = shiftedRangeStart(by: -1)
            let nextStart = shiftedRangeStart(by: 1)

            HStack(spacing: 0) {
                pageView(for: daysForRangeStart(previousStart), pageWidth: width)
                pageView(for: daysForRangeStart(rangeStart), pageWidth: width)
                pageView(for: daysForRangeStart(nextStart), pageWidth: width)
            }
            .offset(x: -width + dragOffset)
            .frame(width: width * 3, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .highPriorityGesture(horizontalSwipeGesture(pageWidth: width))
        }
        .environment(\.calendarPagerIsDragging, isDragging || suppressChildTaps)
        .clipped()
        .onChange(of: rangeStart) { _, _ in
            dragOffset = 0
            isDragging = false
        }
    }

    private func pageView(for days: [Date], pageWidth: CGFloat) -> some View {
        content(days)
            .frame(width: pageWidth)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    private func shiftedRangeStart(by direction: Int) -> Date {
        guard stepDays > 0, direction != 0 else { return rangeStart }
        guard let date = calendar.date(byAdding: .day, value: stepDays * direction, to: rangeStart) else {
            return rangeStart
        }
        return calendar.startOfDay(for: date)
    }

    private func horizontalSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if abs(horizontal) > 6, abs(horizontal) > abs(vertical) * 1.1 {
                    isDragging = true
                }

                guard isDragging else { return }
                dragOffset = rubberBandedOffset(horizontal, pageWidth: pageWidth)
            }
            .onEnded { value in
                let wasPagingDrag = isDragging

                defer {
                    isDragging = false
                    if suppressChildTaps || wasPagingDrag {
                        suppressChildTaps = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            suppressChildTaps = false
                        }
                    }
                }

                guard wasPagingDrag else { return }

                let horizontal = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let threshold = pageWidth * 0.22
                let flickThreshold: CGFloat = 420

                if horizontal < -threshold || predicted < -flickThreshold {
                    commitSwipe(direction: 1, pageWidth: pageWidth)
                } else if horizontal > threshold || predicted > flickThreshold {
                    commitSwipe(direction: -1, pageWidth: pageWidth)
                } else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                }
            }
    }

    /// Soft resistance when pulling past the first/last rendered page.
    private func rubberBandedOffset(_ offset: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let limit = pageWidth * 0.92
        if offset > limit {
            return limit + (offset - limit) * 0.22
        }
        if offset < -limit {
            return -limit + (offset + limit) * 0.22
        }
        return offset
    }

    private func commitSwipe(direction: Int, pageWidth: CGFloat) {
        let targetOffset = direction > 0 ? -pageWidth : pageWidth

        withAnimation(.easeOut(duration: 0.24)) {
            dragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                onCommitNavigation(direction)
                dragOffset = 0
            }
        }
    }
}
