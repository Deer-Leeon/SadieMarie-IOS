import SwiftUI
import UIKit

// MARK: - Section chrome

struct AdminSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
            .tracking(AdminTheme.Typography.dayHeaderTracking)
            .foregroundStyle(AdminTheme.stone700)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Eyebrow + serif title used inside availability section cards.
struct AdminAvailabilitySectionHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                    .tracking(AdminTheme.Typography.dayHeaderTracking)
                    .foregroundStyle(AdminTheme.stone500)

                Text(title)
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(AdminTheme.stone900)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
    }
}

extension AdminAvailabilitySectionHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

/// One white panel: header, hairline, then body. Keeps weekly hours and
/// date overrides as two distinct blocks instead of a stack of equal cards.
struct AdminAvailabilitySectionCard<Header: View, Content: View>: View {
    var header: Header
    var content: Content

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()
                .overlay(AdminTheme.stone200)

            content
        }
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .shadow(color: AdminTheme.cardShadow, radius: 8, x: 0, y: 2)
    }
}

struct AdminAvailabilityCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
    }
}

// MARK: - Form field chrome

extension View {
    /// Compact bordered field — matches service / client form inputs.
    func adminFormFieldChrome() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AdminTheme.stone100)
            .foregroundStyle(AdminTheme.stone900)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
    }
}

// MARK: - Pill toggle

struct AdminPillToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Text(configuration.isOn ? "On" : "Off")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                .foregroundStyle(configuration.isOn ? AdminTheme.cardFill : AdminTheme.stone700)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(configuration.isOn ? AdminTheme.stone900 : AdminTheme.stone100)
                .overlay(
                    Capsule()
                        .stroke(configuration.isOn ? AdminTheme.stone900 : AdminTheme.stone200, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

// MARK: - Compact pickers

struct AdminCompactTimeField: View {
    let label: String?
    @Binding var time: Date
    let onChange: (Date) -> Void

    @State private var isOpen = false

    private var slots: [Date] {
        AvailabilityTimeFormat.quarterHourSlots(on: time)
    }

    private var selectedHHMM: String {
        AvailabilityTimeFormat.hhmm(from: AvailabilityTimeFormat.roundToStride(time))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let label {
                Text(label)
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
            }

            Button {
                isOpen = true
            } label: {
                HStack(spacing: 6) {
                    Text(AvailabilityTimeFormat.displayTime(time))
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(AdminTheme.stone900)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .adminFormFieldChrome()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label ?? "Time")
            .accessibilityValue(AvailabilityTimeFormat.displayTime(time))
            .accessibilityHint("Shows times from earliest to latest")
            .background {
                AdminTimeMenuAnchor(
                    isPresented: $isOpen,
                    menu: AdminQuarterHourTimeMenu(
                        slots: slots,
                        selectedHHMM: selectedHHMM,
                        onSelect: { slot in
                            time = slot
                            onChange(slot)
                            isOpen = false
                        }
                    )
                )
            }
        }
    }
}

/// Compact list of quarter-hour times, always earliest at the top.
/// System `Menu` reverses that order when it opens upward (add-override
/// sheet) and stretches to a wide empty panel — this popover does neither.
private struct AdminQuarterHourTimeMenu: View {
    let slots: [Date]
    let selectedHHMM: String
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(slots, id: \.self) { slot in
                        let hhmm = AvailabilityTimeFormat.hhmm(from: slot)
                        let selected = hhmm == selectedHHMM
                        Button {
                            onSelect(slot)
                        } label: {
                            HStack(spacing: 8) {
                                Text(AvailabilityTimeFormat.displayTime(slot))
                                    .font(
                                        AdminTheme.fontAdminSans(
                                            size: 15,
                                            weight: selected ? .semibold : .regular
                                        )
                                    )
                                    .monospacedDigit()
                                    .foregroundStyle(AdminTheme.stone900)
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AdminTheme.stone700)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: AdminTimeMenuMetrics.rowHeight)
                            .background(selected ? AdminTheme.stone100 : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .id(hhmm)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(
                width: AdminTimeMenuMetrics.width,
                height: AdminTimeMenuMetrics.height
            )
            .onAppear {
                proxy.scrollTo(selectedHHMM, anchor: .center)
            }
        }
    }
}

private enum AdminTimeMenuMetrics {
    static let rowHeight: CGFloat = 32
    static let visibleRows = 7
    static let width: CGFloat = 128
    static var height: CGFloat { rowHeight * CGFloat(visibleRows) }
}

/// Presents `AdminQuarterHourTimeMenu` as a true popover on iPhone
/// (`adaptivePresentationStyle = .none`) so it stays compact inside
/// full-screen covers and never reverses the time order.
private struct AdminTimeMenuAnchor: UIViewRepresentable {
    @Binding var isPresented: Bool
    var menu: AdminQuarterHourTimeMenu

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
            menu: menu,
            sourceView: uiView,
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
    final class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
        private var host: UIHostingController<AdminQuarterHourTimeMenu>?
        private var onPresentedChange: ((Bool) -> Void)?
        private var pendingPresent = false

        func sync(
            isPresented: Bool,
            menu: AdminQuarterHourTimeMenu,
            sourceView: UIView,
            onPresentedChange: @escaping (Bool) -> Void
        ) {
            self.onPresentedChange = onPresentedChange
            if let host {
                host.rootView = menu
                if let popover = host.popoverPresentationController {
                    popover.sourceView = sourceView
                    popover.sourceRect = sourceView.bounds
                }
            }
            if isPresented {
                present(from: sourceView, menu: menu)
            } else {
                dismiss(animated: true)
            }
        }

        func present(from sourceView: UIView, menu: AdminQuarterHourTimeMenu) {
            if host != nil || pendingPresent { return }
            pendingPresent = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingPresent = false
                guard self.host == nil, sourceView.window != nil else { return }
                guard let presenter = Self.presentingController(from: sourceView) else { return }

                let host = UIHostingController(rootView: menu)
                host.safeAreaRegions = []
                host.sizingOptions = []
                host.view.backgroundColor = .white
                host.preferredContentSize = CGSize(
                    width: AdminTimeMenuMetrics.width,
                    height: AdminTimeMenuMetrics.height
                )
                host.modalPresentationStyle = .popover
                if let popover = host.popoverPresentationController {
                    popover.delegate = self
                    popover.sourceView = sourceView
                    popover.sourceRect = sourceView.bounds
                    popover.permittedArrowDirections = [.up, .down]
                    popover.backgroundColor = .white
                }
                presenter.present(host, animated: true)
                self.host = host
            }
        }

        func dismiss(animated: Bool) {
            pendingPresent = false
            guard let host else { return }
            self.host = nil
            host.dismiss(animated: animated)
        }

        func adaptivePresentationStyle(
            for controller: UIPresentationController
        ) -> UIModalPresentationStyle {
            .none
        }

        func presentationControllerDidDismiss(
            _ presentationController: UIPresentationController
        ) {
            host = nil
            DispatchQueue.main.async { [weak self] in
                self?.onPresentedChange?(false)
            }
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

struct AdminCompactDateField: View {
    @Binding var date: Date
    let onChange: (Date) -> Void
    /// When set, expansion is controlled by the parent (e.g. sheet height).
    var isExpanded: Binding<Bool>? = nil

    @State private var internalExpanded = false

    /// Upper bound for the collapse animation; the calendar uses its natural
    /// height at rest (via `fixedSize`) so no days are clipped.
    static let calendarMaxHeight: CGFloat = 460
    static let expandAnimation: Animation = .smooth(duration: 0.32, extraBounce: 0)

    private var expandedBinding: Binding<Bool> {
        isExpanded ?? $internalExpanded
    }

    private var expanded: Bool { expandedBinding.wrappedValue }

    private var selection: Binding<Date> {
        Binding(
            get: { date },
            set: { newValue in
                date = newValue
                onChange(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedBinding.wrappedValue.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(AvailabilityTimeFormat.displayDate(date))
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Spacer(minLength: 0)
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .adminFormFieldChrome()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Date")
            .accessibilityValue(AvailabilityTimeFormat.displayDate(date))
            .accessibilityHint(expanded ? "Collapse calendar" : "Show calendar")

            DatePicker(
                "",
                selection: selection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AdminTheme.stone900)
            .fixedSize(horizontal: false, vertical: true)
            .padding(4)
            .background(AdminTheme.stone100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .padding(.top, 8)
            .frame(maxHeight: expanded ? Self.calendarMaxHeight : 0, alignment: .top)
            .opacity(expanded ? 1 : 0)
            .clipped()
            .allowsHitTesting(expanded)
            .accessibilityHidden(!expanded)
        }
        .animation(Self.expandAnimation, value: expanded)
    }
}

/// Labeled date field for override cards.
struct AdminDatePickerField: View {
    let label: String
    @Binding var date: Date
    let onChange: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)

            AdminCompactDateField(date: $date, onChange: onChange)
        }
    }
}

typealias AdminQuarterHourTimePicker = AdminCompactTimeField
