import SwiftUI
import UIKit

/// Swipeable horizontal pager for 3-day / week calendar grids.
///
/// Hour labels stay pinned on the leading edge. Only day headers and
/// appointment columns follow the finger. UIKit paging owns the gesture;
/// each new swipe commits any in-flight page first so consecutive flicks
/// advance instead of snapping back.
struct BookingsCalendarRangePager<Leading: View, Backdrop: View, Content: View>: View {
    let rangeStart: Date
    let stepDays: Int
    let calendar: Calendar
    var pinnedLeadingWidth: CGFloat = 0
    @ViewBuilder var pinnedLeading: () -> Leading
    @ViewBuilder var pinnedBackdrop: () -> Backdrop
    let daysForRangeStart: (Date) -> [Date]
    let onCommitNavigation: (Int) -> Void
    @ViewBuilder let content: ([Date]) -> Content

    @State private var isDragging = false
    @State private var suppressChildTaps = false

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let leadingWidth = min(max(pinnedLeadingWidth, 0), totalWidth)
            let pageWidth = max(totalWidth - leadingWidth, 1)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: leadingWidth)
                    pinnedBackdrop()
                        .frame(width: pageWidth, height: geometry.size.height)
                }
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    pinnedLeading()
                        .frame(width: leadingWidth)
                        .frame(maxHeight: .infinity)

                    CalendarRangePagingHost(
                        rangeStart: rangeStart,
                        stepDays: stepDays,
                        calendar: calendar,
                        daysForRangeStart: daysForRangeStart,
                        onCommitNavigation: onCommitNavigation,
                        onDraggingChanged: setDragging
                    ) { days in
                        content(days)
                    }
                    .frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .frame(width: totalWidth, height: geometry.size.height, alignment: .topLeading)
        }
        .environment(\.calendarPagerIsDragging, isDragging || suppressChildTaps)
        .clipped()
        .scrollDisabled(true)
    }

    private func setDragging(_ dragging: Bool) {
        if isDragging != dragging {
            isDragging = dragging
        }
        if !dragging {
            suppressChildTaps = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                suppressChildTaps = false
            }
        }
    }
}

// MARK: - UIKit paging host

private struct CalendarRangePagingHost<Page: View>: UIViewControllerRepresentable {
    var rangeStart: Date
    var stepDays: Int
    var calendar: Calendar
    var daysForRangeStart: (Date) -> [Date]
    var onCommitNavigation: (Int) -> Void
    var onDraggingChanged: (Bool) -> Void
    @ViewBuilder var pageContent: ([Date]) -> Page

    func makeUIViewController(context: Context) -> CalendarRangePagingController<Page> {
        CalendarRangePagingController(
            rangeStart: rangeStart,
            stepDays: stepDays,
            calendar: calendar,
            daysForRangeStart: daysForRangeStart,
            pageContent: pageContent,
            onCommitNavigation: onCommitNavigation,
            onDraggingChanged: onDraggingChanged
        )
    }

    func updateUIViewController(
        _ controller: CalendarRangePagingController<Page>,
        context: Context
    ) {
        controller.update(
            rangeStart: rangeStart,
            stepDays: stepDays,
            calendar: calendar,
            daysForRangeStart: daysForRangeStart,
            pageContent: pageContent,
            onCommitNavigation: onCommitNavigation,
            onDraggingChanged: onDraggingChanged
        )
    }
}

private final class CalendarRangePagingController<Page: View>: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private var hosts: [UIHostingController<AnyView>] = []

    private var displayedStart: Date
    private var stepDays: Int
    private var calendar: Calendar
    private var daysForRangeStart: (Date) -> [Date]
    private var pageContent: ([Date]) -> Page
    private var onCommitNavigation: (Int) -> Void
    private var onDraggingChanged: (Bool) -> Void

    private var isRecycling = false
    private var lastLaidOutSize: CGSize = .zero
    /// Parent `rangeStart` still on the pre-swipe window until `onCommit` lands.
    private var staleParentStart: Date?
    /// Page index (0/1/2) the current deceleration is heading toward.
    private var pendingTargetPage: Int?
    private var hasCompletedInitialLayout = false

    init(
        rangeStart: Date,
        stepDays: Int,
        calendar: Calendar,
        daysForRangeStart: @escaping (Date) -> [Date],
        pageContent: @escaping ([Date]) -> Page,
        onCommitNavigation: @escaping (Int) -> Void,
        onDraggingChanged: @escaping (Bool) -> Void
    ) {
        self.displayedStart = calendar.startOfDay(for: rangeStart)
        self.stepDays = stepDays
        self.calendar = calendar
        self.daysForRangeStart = daysForRangeStart
        self.pageContent = pageContent
        self.onCommitNavigation = onCommitNavigation
        self.onDraggingChanged = onDraggingChanged
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .clear
        root.clipsToBounds = true

        scrollView.backgroundColor = .clear
        // Custom snap in `scrollViewWillEndDragging` — system paging uses a
        // 50% threshold, so a second flick mid-animation snaps back home.
        scrollView.isPagingEnabled = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.bounces = true
        scrollView.decelerationRate = .fast
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.clipsToBounds = true
        scrollView.alpha = 0
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for _ in 0..<3 {
            let host = UIHostingController(rootView: AnyView(EmptyView()))
            host.view.backgroundColor = .clear
            host.safeAreaRegions = []
            host.sizingOptions = []
            host.view.insetsLayoutMarginsFromSafeArea = false
            addChild(host)
            scrollView.addSubview(host.view)
            host.didMove(toParent: self)
            hosts.append(host)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayoutIfNeeded(resetToCenter: !scrollView.isTracking && !scrollView.isDecelerating)
    }

    func update(
        rangeStart: Date,
        stepDays: Int,
        calendar: Calendar,
        daysForRangeStart: @escaping (Date) -> [Date],
        pageContent: @escaping ([Date]) -> Page,
        onCommitNavigation: @escaping (Int) -> Void,
        onDraggingChanged: @escaping (Bool) -> Void
    ) {
        let incoming = calendar.startOfDay(for: rangeStart)
        let previousStepDays = self.stepDays
        self.stepDays = stepDays
        self.calendar = calendar
        self.daysForRangeStart = daysForRangeStart
        self.pageContent = pageContent
        self.onCommitNavigation = onCommitNavigation
        self.onDraggingChanged = onDraggingChanged

        let interacting = scrollView.isTracking || scrollView.isDecelerating
        let stepChanged = previousStepDays != stepDays

        if calendar.isDate(incoming, inSameDayAs: displayedStart) {
            staleParentStart = nil
        } else if let stale = staleParentStart, calendar.isDate(incoming, inSameDayAs: stale) {
            // Commit hasn't reached SwiftUI yet; keep the recycled pages.
            return
        }

        // Never rewrite pages while a swipe is in flight — that was the SwiftUI
        // desync (headers from one range, columns from another).
        guard !interacting else { return }
        guard hasCompletedInitialLayout else {
            displayedStart = incoming
            return
        }

        let rangeChanged = !calendar.isDate(incoming, inSameDayAs: displayedStart)
        guard rangeChanged || stepChanged else { return }

        staleParentStart = nil
        displayedStart = incoming
        reloadAllPages(disableAnimations: true)
        snapToCenterPage(animated: false)
    }

    // MARK: UIScrollViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onDraggingChanged(true)
        // A new swipe must finish the in-flight page first. Otherwise the
        // second flick starts from halfway and snaps back to the old range.
        commitInFlightPageIfNeeded()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isRecycling else { return }
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
        recycleAtEdgesWhileTracking()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let width = pageWidth
        guard width > 1 else { return }
        let page = targetPage(
            forOffset: scrollView.contentOffset.x,
            velocity: velocity.x,
            width: width
        )
        pendingTargetPage = page
        targetContentOffset.pointee = CGPoint(x: CGFloat(page) * width, y: 0)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            settleIfNeeded()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settleIfNeeded()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settleIfNeeded()
    }

    // MARK: - Paging

    private var pageWidth: CGFloat { scrollView.bounds.width }

    /// Light consecutive flicks should page. System paging waits for ~50%.
    private func targetPage(forOffset x: CGFloat, velocity: CGFloat, width: CGFloat) -> Int {
        let center = width
        let delta = x - center
        let distanceThreshold = min(width * 0.08, 28)
        let velocityThreshold: CGFloat = 180

        var direction = 0
        if velocity < -velocityThreshold || delta > distanceThreshold {
            direction = 1
        } else if velocity > velocityThreshold || delta < -distanceThreshold {
            direction = -1
        } else if let pending = pendingTargetPage, pending != 1 {
            let pendingDirection = pending - 1
            let reversed =
                (pendingDirection == 1 && velocity > velocityThreshold)
                || (pendingDirection == -1 && velocity < -velocityThreshold)
            if !reversed {
                direction = pendingDirection
            }
        }

        return min(max(1 + direction, 0), 2)
    }

    /// Finish a page that was already in motion so the new gesture has a full
    /// next/previous window to travel through.
    private func commitInFlightPageIfNeeded() {
        let width = pageWidth
        guard width > 1, !isRecycling else { return }

        var direction = 0
        if let pending = pendingTargetPage {
            direction = pending - 1
        }
        if direction == 0 {
            let delta = scrollView.contentOffset.x - width
            let threshold = min(width * 0.08, 28)
            if delta > threshold {
                direction = 1
            } else if delta < -threshold {
                direction = -1
            } else {
                direction = Int(round(scrollView.contentOffset.x / width)) - 1
            }
        }

        pendingTargetPage = nil
        guard direction != 0 else { return }
        recycle(direction: direction)
        onCommitNavigation(direction)
    }

    /// Finger still down at the last page: loop so another swipe can continue.
    private func recycleAtEdgesWhileTracking() {
        guard scrollView.isTracking, !isRecycling else { return }
        let width = pageWidth
        guard width > 1 else { return }
        let x = scrollView.contentOffset.x
        if x >= width * 2 - 1 {
            recycle(direction: 1, offsetAdjust: -width)
            onCommitNavigation(1)
        } else if x <= 1 {
            recycle(direction: -1, offsetAdjust: width)
            onCommitNavigation(-1)
        }
    }

    private func settleIfNeeded() {
        if scrollView.isTracking { return }
        let width = pageWidth
        pendingTargetPage = nil
        guard width > 1, !isRecycling else {
            onDraggingChanged(false)
            return
        }

        let page = min(max(Int(round(scrollView.contentOffset.x / width)), 0), 2)
        let direction = page - 1
        guard direction != 0 else {
            snapToCenterPage(animated: false)
            onDraggingChanged(false)
            return
        }

        recycle(direction: direction)
        onDraggingChanged(false)
        onCommitNavigation(direction)
    }

    /// Shift the three page windows so the just-landed range is the center
    /// page. `offsetAdjust` keeps the pixels on screen when looping mid-drag;
    /// otherwise snap to the center slot.
    private func recycle(direction: Int, offsetAdjust: CGFloat? = nil) {
        staleParentStart = displayedStart
        displayedStart = shiftedStart(by: direction)
        let previouslyVisibleIndex = 1 + direction
        let otherIndex = 2 - previouslyVisibleIndex

        isRecycling = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            applyPage(at: 1, start: displayedStart)
            applyPage(
                at: otherIndex,
                start: shiftedStart(by: otherIndex == 0 ? -1 : 1)
            )
            if let offsetAdjust {
                scrollView.contentOffset.x += offsetAdjust
            } else {
                snapToCenterPage(animated: false)
            }
            applyPage(
                at: previouslyVisibleIndex,
                start: shiftedStart(by: previouslyVisibleIndex == 0 ? -1 : 1)
            )
        }
        CATransaction.commit()
        isRecycling = false
    }

    private func reloadAllPages(disableAnimations: Bool) {
        let apply = {
            self.applyPage(at: 0, start: self.shiftedStart(by: -1))
            self.applyPage(at: 1, start: self.displayedStart)
            self.applyPage(at: 2, start: self.shiftedStart(by: 1))
        }
        if disableAnimations {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, apply)
        } else {
            apply()
        }
    }

    private func applyPage(at index: Int, start: Date) {
        guard hosts.indices.contains(index) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hosts[index].rootView = AnyView(
                pageContent(daysForRangeStart(start))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
    }

    private func applyLayoutIfNeeded(resetToCenter: Bool) {
        let size = scrollView.bounds.size
        guard size.width > 1, size.height > 1 else { return }
        let sizeChanged = abs(size.width - lastLaidOutSize.width) > 0.5
            || abs(size.height - lastLaidOutSize.height) > 0.5
        guard sizeChanged || scrollView.contentSize.width < size.width * 2 else { return }

        let firstLayout = lastLaidOutSize == .zero
        lastLaidOutSize = size
        scrollView.contentSize = CGSize(width: size.width * 3, height: size.height)
        for (index, host) in hosts.enumerated() {
            host.view.frame = CGRect(
                x: size.width * CGFloat(index),
                y: 0,
                width: size.width,
                height: size.height
            )
        }
        if firstLayout || resetToCenter {
            snapToCenterPage(animated: false)
        }
        if !hasCompletedInitialLayout {
            hasCompletedInitialLayout = true
            reloadAllPages(disableAnimations: true)
            scrollView.alpha = 1
        }
    }

    private func snapToCenterPage(animated: Bool) {
        let width = scrollView.bounds.width
        guard width > 1 else { return }
        let target = CGPoint(x: width, y: 0)
        if animated {
            scrollView.setContentOffset(target, animated: true)
        } else {
            scrollView.contentOffset = target
        }
    }

    private func shiftedStart(by direction: Int) -> Date {
        guard stepDays > 0, direction != 0 else { return displayedStart }
        guard let date = calendar.date(byAdding: .day, value: stepDays * direction, to: displayedStart) else {
            return displayedStart
        }
        return calendar.startOfDay(for: date)
    }

    deinit {
        for host in hosts {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }
    }
}
