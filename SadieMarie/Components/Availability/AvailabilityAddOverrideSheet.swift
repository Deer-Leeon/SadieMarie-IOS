import SwiftUI

/// Centered "Add date override" popup — an independent dialog (not a bottom sheet).
/// Sizes to its content and shows the full calendar so every day is visible.
struct AvailabilityAddOverridePopup: View {
    /// Dismisses the popup (parent sets its presentation flag false).
    var onDismiss: () -> Void
    /// Adds the override to the draft; returns `true` on success.
    var onConfirm: (_ date: Date, _ unavailable: Bool, _ start: Date, _ end: Date) -> Bool

    @State private var date: Date = Calendar.current.startOfDay(for: Date())
    @State private var mode: OverrideHoursMode = .unavailableAllDay
    @State private var start: Date = AvailabilityTimeFormat.defaultStart()
    @State private var end: Date = AvailabilityTimeFormat.defaultEnd()
    @State private var validationMessage: String?
    @State private var appeared = false

    private var unavailable: Bool { mode == .unavailableAllDay }
    private var showsCustomHours: Bool { mode == .customHours }

    private var canConfirmCustomHours: Bool {
        AvailabilityTimeFormat.hhmm(from: start) < AvailabilityTimeFormat.hhmm(from: end)
    }

    private var contentAnimation: Animation { .smooth(duration: 0.3, extraBounce: 0) }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }

            card
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.smooth(duration: 0.26)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AdminTheme.stone200)
            formBody
        }
        .background(AdminTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button("Cancel") { close() }
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone700)

            Spacer(minLength: 8)

            Text("Add date override")
                .font(AdminTheme.fontAdminSans(size: 16, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)

            Spacer(minLength: 8)

            Button("Add") { submit() }
                .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                .foregroundStyle(canConfirm ? AdminTheme.stone900 : AdminTheme.stone300)
                .disabled(!canConfirm)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let validationMessage {
                Text(validationMessage)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.semanticRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Date")
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(AdminTheme.stone900)
                    .padding(6)
                    .background(AdminTheme.stone100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AdminTheme.stone200, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Hours")
                Picker("Hours", selection: modeSelection) {
                    ForEach(OverrideHoursMode.allCases) { option in
                        Text(option.sheetSegmentTitle).tag(option)
                    }
                }
                .adminLightSegmentedPicker()
            }

            customHoursSection
                .frame(maxHeight: showsCustomHours ? 92 : 0, alignment: .top)
                .opacity(showsCustomHours ? 1 : 0)
                .clipped()
                .allowsHitTesting(showsCustomHours)
                .accessibilityHidden(!showsCustomHours)
        }
        .padding(16)
        .animation(contentAnimation, value: mode)
        .animation(contentAnimation, value: validationMessage)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
            .foregroundStyle(AdminTheme.stone500)
            .textCase(.uppercase)
    }

    private var customHoursSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Custom hours")
            HStack(alignment: .center, spacing: 8) {
                AdminCompactTimeField(label: "Start", time: $start, onChange: { start = $0 })
                Text("–")
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                    .padding(.top, 14)
                AdminCompactTimeField(label: "End", time: $end, onChange: { end = $0 })
            }

            if !canConfirmCustomHours {
                Text("End time must be after start time.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canConfirm: Bool {
        !showsCustomHours || canConfirmCustomHours
    }

    private var modeSelection: Binding<OverrideHoursMode> {
        Binding(
            get: { mode },
            set: { newValue in
                withAnimation(contentAnimation) { mode = newValue }
            }
        )
    }

    private func submit() {
        if showsCustomHours, !canConfirmCustomHours {
            validationMessage = "End time must be after start time."
            return
        }
        guard onConfirm(date, unavailable, start, end) else {
            validationMessage = "Couldn’t add this override. Check the date and hours."
            return
        }
        close()
    }

    private func close() {
        withAnimation(.smooth(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}

private extension OverrideHoursMode {
    var sheetSegmentTitle: String {
        switch self {
        case .unavailableAllDay: return "All day off"
        case .customHours: return "Custom"
        }
    }
}
