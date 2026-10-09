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
                        .foregroundStyle(isOpen ? AdminTheme.stone900 : AdminTheme.stone500)
                }
                .adminFormFieldChrome()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOpen ? AdminTheme.stone900.opacity(0.35) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label ?? "Time")
            .accessibilityValue(AvailabilityTimeFormat.displayTime(time))
            .accessibilityHint("Shows times from earliest to latest")
            .overlay {
                AdminTimeMenuAnchor(
                    isPresented: $isOpen,
                    slots: slots,
                    selectedHHMM: selectedHHMM,
                    onSelect: { slot in
                        time = slot
                        onChange(slot)
                        isOpen = false
                    }
                )
            }
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
