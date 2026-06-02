import SwiftUI

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

    private var slots: [Date] {
        AvailabilityTimeFormat.quarterHourSlots(on: time)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let label {
                Text(label)
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
            }

            Menu {
                ForEach(slots, id: \.self) { slot in
                    Button(AvailabilityTimeFormat.displayTime(slot)) {
                        time = slot
                        onChange(slot)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(AvailabilityTimeFormat.displayTime(time))
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .adminFormFieldChrome()
            }
        }
    }
}

struct AdminCompactDateField: View {
    @Binding var date: Date
    let onChange: (Date) -> Void

    var body: some View {
        Menu {
            DatePicker(
                "",
                selection: Binding(
                    get: { date },
                    set: { newValue in
                        date = newValue
                        onChange(newValue)
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AdminTheme.stone900)
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
        .tint(AdminTheme.stone900)
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
