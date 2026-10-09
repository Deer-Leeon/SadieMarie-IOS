import SwiftUI
import UIKit

private enum AdminTimeMenuMetrics {
    static let rowHeight: CGFloat = 40
    static let visibleRows = 6
    static let contentInset: CGFloat = 8
    static let minWidth: CGFloat = 152
    static let minHeight: CGFloat = 168
    static let gap: CGFloat = 8
    static let screenPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static var idealHeight: CGFloat {
        contentInset * 2 + rowHeight * CGFloat(visibleRows)
    }
}

/// Full-screen overlay: a card aligned to the field, earliest times at the
/// top. Avoids the system popover balloon, whose arrow clipped the last row.
struct AdminTimeMenuScreen: View {
    var slots: [Date]
    var selectedHHMM: String
    var sourceRect: CGRect
    var onSelect: (Date) -> Void
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let card = cardFrame(source: sourceRect, in: geo.size, safe: geo.safeAreaInsets)
            let placedBelow = card.midY >= sourceRect.midY
            let ready = sourceRect.width > 1 && sourceRect.height > 1
            ZStack(alignment: .topLeading) {
                Color.black.opacity(appeared ? 0.1 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                if ready {
                    menuList
                        .frame(width: card.width, height: card.height)
                        .background(AdminTheme.cardFill)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AdminTimeMenuMetrics.cornerRadius,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: AdminTimeMenuMetrics.cornerRadius,
                                style: .continuous
                            )
                            .stroke(AdminTheme.stone200, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.16), radius: 28, x: 0, y: 14)
                        .offset(x: card.minX, y: card.minY)
                        .scaleEffect(
                            appeared ? 1 : 0.96,
                            anchor: placedBelow ? .top : .bottom
                        )
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.smooth(duration: 0.26, extraBounce: 0)) {
                appeared = true
            }
        }
    }

    private var menuList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(slots, id: \.self) { slot in
                        let hhmm = AvailabilityTimeFormat.hhmm(from: slot)
                        let selected = hhmm == selectedHHMM
                        Button {
                            onSelect(slot)
                        } label: {
                            HStack(spacing: 10) {
                                Text(AvailabilityTimeFormat.displayTime(slot))
                                    .font(
                                        AdminTheme.fontAdminSans(
                                            size: 15,
                                            weight: selected ? .semibold : .medium
                                        )
                                    )
                                    .monospacedDigit()
                                    .foregroundStyle(AdminTheme.stone900)
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AdminTheme.stone700)
                                    .opacity(selected ? 1 : 0)
                                    .accessibilityHidden(!selected)
                            }
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: AdminTimeMenuMetrics.rowHeight)
                            .background {
                                if selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(AdminTheme.stone100)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .id(hhmm)
                    }
                }
            }
            .contentMargins(.vertical, AdminTimeMenuMetrics.contentInset, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedHHMM, anchor: .center)
                }
            }
        }
    }

    private func dismissAnimated() {
        withAnimation(.smooth(duration: 0.18, extraBounce: 0)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    private func cardFrame(source: CGRect, in size: CGSize, safe: EdgeInsets) -> CGRect {
        let pad = AdminTimeMenuMetrics.screenPadding
        let width = min(
            max(source.width, AdminTimeMenuMetrics.minWidth),
            size.width - safe.leading - safe.trailing - pad * 2
        )
        let maxBelow = size.height - safe.bottom - pad - source.maxY - AdminTimeMenuMetrics.gap
        let maxAbove = source.minY - safe.top - pad - AdminTimeMenuMetrics.gap
        let placeBelow = maxBelow >= AdminTimeMenuMetrics.minHeight
            || maxBelow >= maxAbove
        let available = max(placeBelow ? maxBelow : maxAbove, AdminTimeMenuMetrics.minHeight)
        let height = min(AdminTimeMenuMetrics.idealHeight, available)

        var x = source.minX
        let minX = safe.leading + pad
        let maxX = size.width - safe.trailing - pad - width
        x = min(max(x, minX), max(minX, maxX))

        let y = placeBelow
            ? source.maxY + AdminTimeMenuMetrics.gap
            : source.minY - AdminTimeMenuMetrics.gap - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Presents the time card over the current screen (including full-screen
/// covers) without using the system popover balloon.
struct AdminTimeMenuAnchor: UIViewRepresentable {
    @Binding var isPresented: Bool
    var slots: [Date]
    var selectedHHMM: String
    var onSelect: (Date) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.sync(
            isPresented: isPresented,
            slots: slots,
            selectedHHMM: selectedHHMM,
            sourceView: uiView,
            onSelect: onSelect,
            onPresentedChange: { presented in
                if isPresented != presented {
                    isPresented = presented
                }
            }
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.dismiss(animated: false)
    }

    @MainActor
    final class Coordinator {
        private var host: UIHostingController<AdminTimeMenuScreen>?
        private var onPresentedChange: ((Bool) -> Void)?
        private var pendingPresent = false

        func sync(
            isPresented: Bool,
            slots: [Date],
            selectedHHMM: String,
            sourceView: UIView,
            onSelect: @escaping (Date) -> Void,
            onPresentedChange: @escaping (Bool) -> Void
        ) {
            self.onPresentedChange = onPresentedChange
            if var screen = host?.rootView {
                screen.slots = slots
                screen.selectedHHMM = selectedHHMM
                screen.onSelect = onSelect
                host?.rootView = screen
            }
            if isPresented {
                present(
                    from: sourceView,
                    slots: slots,
                    selectedHHMM: selectedHHMM,
                    onSelect: onSelect
                )
            } else {
                dismiss(animated: false)
            }
        }

        func present(
            from sourceView: UIView,
            slots: [Date],
            selectedHHMM: String,
            onSelect: @escaping (Date) -> Void
        ) {
            if host != nil || pendingPresent { return }
            pendingPresent = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingPresent = false
                guard self.host == nil, sourceView.window != nil else { return }
                guard let presenter = Self.presentingController(from: sourceView) else { return }

                let screen = AdminTimeMenuScreen(
                    slots: slots,
                    selectedHHMM: selectedHHMM,
                    sourceRect: .zero,
                    onSelect: onSelect,
                    onDismiss: { [weak self] in
                        self?.dismiss(animated: false)
                        self?.onPresentedChange?(false)
                    }
                )
                let host = UIHostingController(rootView: screen)
                host.view.backgroundColor = .clear
                host.modalPresentationStyle = .overFullScreen
                host.modalTransitionStyle = .crossDissolve
                presenter.present(host, animated: false) {
                    let rect = sourceView.convert(sourceView.bounds, to: host.view)
                    var next = host.rootView
                    next.sourceRect = rect
                    host.rootView = next
                }
                self.host = host
            }
        }

        func dismiss(animated: Bool) {
            pendingPresent = false
            guard let host else { return }
            self.host = nil
            host.dismiss(animated: animated)
        }

        private static func presentingController(from view: UIView) -> UIViewController? {
            guard var current = view.window?.rootViewController else { return nil }
            while let presented = current.presentedViewController,
                  view.isDescendant(of: presented.view) {
                current = presented
            }
            return current
        }
    }
}
