import SwiftUI
import UIKit

/// Bookings list — next visit at the top. Scroll up a little for
/// “Show Past Appointments”; tapping it only unlocks rows already above.
struct BookingsListView: View {
    let appointments: [Appointment]
    /// When `false`, an empty API result does not show the “no bookings” copy (e.g. while an error banner is visible).
    var showsEmptyState: Bool = true
    var onSelectAppointment: ((Appointment) -> Void)? = nil

    @State private var showPast = false
    @State private var isHidingPast = false
    @State private var scrollController = BookingsListScrollController()

    private var pastAppointments: [Appointment] {
        appointments.filter { !BookingDisplay.isUpcoming($0) }
    }

    private var upcomingAppointments: [Appointment] {
        appointments.filter { BookingDisplay.isUpcoming($0) }
    }

    private var hasPast: Bool { !pastAppointments.isEmpty }
    private var pastIsRevealed: Bool { showPast || isHidingPast }

    var body: some View {
        Group {
            if appointments.isEmpty, showsEmptyState {
                emptyState
            } else if appointments.isEmpty {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AdminTheme.cream)
            } else {
                appointmentsList
            }
        }
    }

    private var appointmentsList: some View {
        GeometryReader { geometry in
            let tailFloor = hasPast
                ? max(0, geometry.size.height - AdminTheme.Spacing.listVertical)
                : 0

            ScrollView {
                VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
                    if hasPast {
                        VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
                            BookingsDaySectionRows(
                                appointments: pastAppointments,
                                onSelectAppointment: showPast && !isHidingPast ? onSelectAppointment : nil,
                                usesSection: false
                            )
                        }
                        .opacity(pastIsRevealed ? 1 : 0)
                        .frame(height: pastIsRevealed ? nil : 0, alignment: .bottom)
                        .clipped()
                        .accessibilityHidden(!pastIsRevealed)
                        .allowsHitTesting(showPast && !isHidingPast)

                        pastAppointmentsToggle {
                            handlePastToggle()
                        }
                    }

                    VStack(alignment: .leading, spacing: AdminTheme.Spacing.cardStack) {
                        upcomingBlock
                    }
                    .frame(minHeight: tailFloor, alignment: .top)
                    .background(alignment: .top) {
                        if hasPast {
                            BookingsListScrollGate(controller: scrollController)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.bottom, AdminTheme.Spacing.listVertical)
                .frame(maxWidth: AdminTheme.Spacing.listMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.always)
        }
        .background(AdminTheme.cream)
    }

    private func handlePastToggle() {
        if isHidingPast { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if showPast {
                isHidingPast = true
                scrollController.scrollUpcomingToTopAnimated {
                    var finish = Transaction()
                    finish.disablesAnimations = true
                    withTransaction(finish) {
                        scrollController.prepareForCollapse()
                        showPast = false
                        isHidingPast = false
                    }
                }
            } else {
                scrollController.prepareForExpand()
                showPast = true
            }
        }
    }

    @ViewBuilder
    private var upcomingBlock: some View {
        if upcomingAppointments.isEmpty {
            noUpcomingHint
        } else {
            BookingsDaySectionRows(
                appointments: upcomingAppointments,
                onSelectAppointment: onSelectAppointment,
                usesSection: false
            )
        }
    }

    private func pastAppointmentsToggle(action: @escaping () -> Void) -> some View {
        ShowPastAppointmentsButton(
            title: pastIsRevealed ? "Hide Past Appointments" : "Show Past Appointments",
            chevronUp: !pastIsRevealed,
            action: action
        )
    }

    private var noUpcomingHint: some View {
        Text("No upcoming bookings")
            .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No upcoming bookings")
                .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
            Text("Appointments will appear here when scheduled.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone700)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminTheme.cream)
    }
}

/// Captures scroll metrics before past rows expand or collapse so the
/// viewport can stay put, and animates Hide back to the next visit.
private final class BookingsListScrollController {
    weak var scrollView: UIScrollView?
    weak var marker: UIView?
    var pendingExpand = false
    var pendingCollapse = false
    var didCollapseShrink = false
    var isAnimatingHide = false
    var needsInitialPin = true
    var offsetBefore: CGFloat = 0
    var heightBefore: CGFloat = 0

    func prepareForExpand() {
        guard let scrollView else { return }
        offsetBefore = scrollView.contentOffset.y
        heightBefore = scrollView.contentSize.height
        pendingExpand = true
        needsInitialPin = false
    }

    func prepareForCollapse() {
        guard let scrollView else { return }
        offsetBefore = scrollView.contentOffset.y
        heightBefore = scrollView.contentSize.height
        didCollapseShrink = false
        pendingCollapse = true
        needsInitialPin = false
    }

    func scrollUpcomingToTopAnimated(completion: @escaping () -> Void) {
        guard let scrollView, let marker else {
            completion()
            return
        }

        // Current offset plus how far the upcoming header sits below the
        // fold — not the on-screen gap used as an absolute offset.
        let target = Self.offsetToPlaceMarkerAtTop(in: scrollView, marker: marker)
        let x = scrollView.contentOffset.x
        if abs(scrollView.contentOffset.y - target) < 2 {
            completion()
            return
        }

        isAnimatingHide = true
        scrollView.isScrollEnabled = false
        let distance = abs(scrollView.contentOffset.y - target)
        let duration = min(1.0, max(0.45, Double(distance / 700)))

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            scrollView.contentOffset = CGPoint(x: x, y: target)
        } completion: { _ in
            scrollView.setContentOffset(CGPoint(x: x, y: target), animated: false)
            scrollView.isScrollEnabled = true
            self.isAnimatingHide = false
            completion()
        }
    }

    /// Scroll offset that parks `marker` at the top of the visible list.
    /// Uses window-space distance so Hide cannot mistake an on-screen gap
    /// for a document offset (that overshoots into later appointments).
    static func offsetToPlaceMarkerAtTop(in scrollView: UIScrollView, marker: UIView) -> CGFloat {
        let markerInWindow = marker.convert(CGPoint.zero, to: nil)
        let visibleTopInContent = CGPoint(
            x: 0,
            y: scrollView.bounds.minY + scrollView.adjustedContentInset.top
        )
        let visibleTopInWindow = scrollView.convert(visibleTopInContent, to: nil)
        guard markerInWindow.y.isFinite, visibleTopInWindow.y.isFinite else {
            return max(0, scrollView.contentOffset.y)
        }
        let gap = markerInWindow.y - visibleTopInWindow.y
        return max(0, scrollView.contentOffset.y + gap)
    }
}

/// Marker at the top of the upcoming block. Parks the list there on open,
/// keeps Show from moving the viewport, and collapses past rows only after
/// Hide has scrolled them off-screen.
private struct BookingsListScrollGate: UIViewRepresentable {
    var controller: BookingsListScrollController

    final class Coordinator {
        var controller: BookingsListScrollController?
        private var isAdjusting = false
        private var observations: [NSKeyValueObservation] = []
        private weak var observedScrollView: UIScrollView?

        func layoutChanged(from marker: UIView) {
            guard !isAdjusting,
                  let scrollView = marker.enclosingScrollView()
            else { return }

            attach(scrollView)
            controller?.scrollView = scrollView
            controller?.marker = marker
            scrollView.alwaysBounceVertical = true
            scrollView.bounces = true

            if applyPendingExpand(on: scrollView) { return }
            if applyPendingCollapse(on: scrollView) { return }
            if controller?.isAnimatingHide == true { return }

            pinInitiallyIfNeeded(on: scrollView, marker: marker)
        }

        @discardableResult
        private func applyPendingExpand(on scrollView: UIScrollView) -> Bool {
            guard let controller, controller.pendingExpand else { return false }
            let growth = scrollView.contentSize.height - controller.heightBefore
            guard growth > 1 else { return true }
            controller.pendingExpand = false
            isAdjusting = true
            scrollView.setContentOffset(
                CGPoint(
                    x: scrollView.contentOffset.x,
                    y: controller.offsetBefore + growth
                ),
                animated: false
            )
            isAdjusting = false
            return true
        }

        @discardableResult
        private func applyPendingCollapse(on scrollView: UIScrollView) -> Bool {
            guard let controller, controller.pendingCollapse else { return false }

            let newHeight = scrollView.contentSize.height
            let drop = controller.heightBefore - newHeight
            if drop > 0.5 {
                // Past rows left the document. Pull the offset up by the same
                // amount so the upcoming header stays where the animation put it.
                isAdjusting = true
                scrollView.setContentOffset(
                    CGPoint(
                        x: scrollView.contentOffset.x,
                        y: max(0, scrollView.contentOffset.y - drop)
                    ),
                    animated: false
                )
                isAdjusting = false
                controller.heightBefore = newHeight
                controller.didCollapseShrink = true
                return true
            }

            if controller.didCollapseShrink {
                controller.pendingCollapse = false
                controller.didCollapseShrink = false
            }
            return true
        }

        private func pinInitiallyIfNeeded(on scrollView: UIScrollView, marker: UIView) {
            guard let controller, controller.needsInitialPin else { return }
            let target = BookingsListScrollController.offsetToPlaceMarkerAtTop(
                in: scrollView,
                marker: marker
            )
            guard target > 1 else { return }
            if abs(scrollView.contentOffset.y - target) < 1 {
                controller.needsInitialPin = false
                return
            }
            isAdjusting = true
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: target),
                animated: false
            )
            isAdjusting = false
            if abs(scrollView.contentOffset.y - target) < 1 {
                controller.needsInitialPin = false
            }
        }

        private func attach(_ scrollView: UIScrollView) {
            guard observedScrollView !== scrollView else { return }
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            observedScrollView = scrollView

            observations.append(
                scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                    guard let self, let marker = self.controller?.marker else { return }
                    self.layoutChanged(from: marker)
                }
            )
        }

        deinit {
            observations.forEach { $0.invalidate() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BookingsListMarkerView {
        let view = BookingsListMarkerView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: BookingsListMarkerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.controller = controller
        uiView.onLayout = { [weak coordinator] in
            coordinator?.layoutChanged(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: BookingsListMarkerView, coordinator: Coordinator) {
        uiView.onLayout = nil
        coordinator.controller?.scrollView = nil
        coordinator.controller?.marker = nil
    }
}

private final class BookingsListMarkerView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onLayout?()
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var view: UIView? = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            view = current.superview
        }
        return nil
    }
}

#Preview("Bookings list") {
    BookingsListView(appointments: Appointment.mockList.visibleForBookingsList())
}
