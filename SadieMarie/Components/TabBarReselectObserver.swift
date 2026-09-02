import SwiftUI
import UIKit

/// SwiftUI `TabView` does not change `selection` when the already-selected tab
/// is tapped. This watches the underlying tab bar so a Bookings re-tap can
/// jump the calendar back to today.
struct TabBarReselectObserver: UIViewRepresentable {
    var onReselectIndex: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselectIndex: onReselectIndex)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onReselectIndex = onReselectIndex
        context.coordinator.attach(from: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onReselectIndex: (Int) -> Void
        private weak var installedTabBar: UITabBar?
        private var gesture: TabReselectGesture?

        init(onReselectIndex: @escaping (Int) -> Void) {
            self.onReselectIndex = onReselectIndex
        }

        func attach(from view: UIView) {
            if installedTabBar != nil, gesture?.view === installedTabBar { return }
            attemptInstall(from: view, remaining: 20)
        }

        private func attemptInstall(from view: UIView, remaining: Int) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.install(from: view) { return }
                guard remaining > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attemptInstall(from: view, remaining: remaining - 1)
                }
            }
        }

        @discardableResult
        private func install(from view: UIView) -> Bool {
            guard let tabBar = Self.findTabBar(from: view) else { return false }
            if installedTabBar === tabBar, gesture?.view === tabBar { return true }

            if let gesture {
                installedTabBar?.removeGestureRecognizer(gesture)
            }

            let recognizer = TabReselectGesture(target: self, action: #selector(handleReselect(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            tabBar.addGestureRecognizer(recognizer)
            gesture = recognizer
            installedTabBar = tabBar
            return true
        }

        @objc private func handleReselect(_ recognizer: TabReselectGesture) {
            guard recognizer.state == .ended else { return }
            onReselectIndex(recognizer.recognizedIndex)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private static func findTabBar(from view: UIView) -> UITabBar? {
            if let tabBar = findTabBarController(from: view)?.tabBar {
                return tabBar
            }
            if let tabBar = view.window?.findSubview(ofType: UITabBar.self) {
                return tabBar
            }
            if let tabBar = nearestViewController(from: view)?.view.window?.findSubview(ofType: UITabBar.self) {
                return tabBar
            }
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    if let tabBar = window.findSubview(ofType: UITabBar.self) {
                        return tabBar
                    }
                }
            }
            return nil
        }

        private static func findTabBarController(from view: UIView) -> UITabBarController? {
            if let controller = nearestViewController(from: view)?.tabBarControllerInHierarchy() {
                return controller
            }

            var responder: UIResponder? = view
            while let current = responder {
                if let tab = current as? UITabBarController { return tab }
                if let viewController = current as? UIViewController {
                    if let tab = viewController.tabBarControllerInHierarchy() { return tab }
                }
                responder = current.next
            }
            return nil
        }

        private static func nearestViewController(from view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let viewController = current as? UIViewController { return viewController }
                responder = current.next
            }
            return nil
        }
    }
}

private extension UIView {
    func findSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for child in subviews {
            if let match = child.findSubview(ofType: type) { return match }
        }
        return nil
    }
}

private extension UIViewController {
    func tabBarControllerInHierarchy() -> UITabBarController? {
        if let tab = self as? UITabBarController { return tab }
        if let tab = tabBarController { return tab }
        for child in children {
            if let found = child.tabBarControllerInHierarchy() { return found }
        }
        return presentedViewController?.tabBarControllerInHierarchy()
    }
}

/// Recognizes a tap on the already-selected tab item (captured at touch-down,
/// before UIKit updates `selectedItem`).
private final class TabReselectGesture: UIGestureRecognizer {
    private(set) var recognizedIndex = 0
    private var indexAtTouchDown: Int?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let tabBar = view as? UITabBar,
              let touch = touches.first,
              let items = tabBar.items,
              let selected = tabBar.selectedItem,
              let selectedIndex = items.firstIndex(of: selected)
        else {
            state = .failed
            return
        }

        let location = touch.location(in: tabBar)
        guard let tappedIndex = Self.itemIndex(at: location, in: tabBar),
              tappedIndex == selectedIndex
        else {
            state = .failed
            return
        }

        indexAtTouchDown = selectedIndex
        state = .possible
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard state == .possible,
              let tabBar = view as? UITabBar,
              let touch = touches.first,
              let downIndex = indexAtTouchDown,
              let endedIndex = Self.itemIndex(at: touch.location(in: tabBar), in: tabBar),
              endedIndex == downIndex
        else {
            state = .failed
            return
        }

        recognizedIndex = downIndex
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        indexAtTouchDown = nil
        state = .failed
    }

    override func reset() {
        super.reset()
        indexAtTouchDown = nil
        recognizedIndex = 0
    }

    static func itemIndex(at point: CGPoint, in tabBar: UITabBar) -> Int? {
        let buttons = tabBar.subviews
            .filter { $0 is UIControl }
            .sorted { $0.frame.minX < $1.frame.minX }
        if let index = buttons.firstIndex(where: { $0.frame.contains(point) }) {
            return index
        }

        guard let count = tabBar.items?.count, count > 0, tabBar.bounds.width > 0 else { return nil }
        let index = Int(point.x / (tabBar.bounds.width / CGFloat(count)))
        return (0..<count).contains(index) ? index : nil
    }
}
