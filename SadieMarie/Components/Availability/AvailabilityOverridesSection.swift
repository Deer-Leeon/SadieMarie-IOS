import SwiftUI

struct AvailabilityOverridesSection: View {
    @Bindable var viewModel: AvailabilityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                AdminSectionHeader(title: "Date overrides")
                Spacer(minLength: 8)
                Button(action: { viewModel.addOverride() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add")
                            .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AdminTheme.stone900)
                }
                .buttonStyle(.plain)
            }

            if viewModel.overrides.isEmpty {
                AdminAvailabilityCard {
                    Text("No overrides yet. Add a date to block the day or set custom hours.")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.overrides) { row in
                        AvailabilityOverrideCard(
                            row: row,
                            onRemove: { viewModel.removeOverride(id: row.id) },
                            onDateChange: { viewModel.setOverrideDate(id: row.id, date: $0) },
                            onModeChange: { viewModel.setOverrideMode(id: row.id, mode: $0) },
                            onStartChange: { viewModel.setOverrideTime(id: row.id, start: $0, end: nil) },
                            onEndChange: { viewModel.setOverrideTime(id: row.id, start: nil, end: $0) }
                        )
                    }
                }
            }
        }
    }
}

private struct AvailabilityOverrideCard: View {
    let row: OverrideRow
    let onRemove: () -> Void
    let onDateChange: (Date) -> Void
    let onModeChange: (OverrideHoursMode) -> Void
    let onStartChange: (Date) -> Void
    let onEndChange: (Date) -> Void

    @State private var date: Date
    @State private var mode: OverrideHoursMode
    @State private var start: Date
    @State private var end: Date

    init(
        row: OverrideRow,
        onRemove: @escaping () -> Void,
        onDateChange: @escaping (Date) -> Void,
        onModeChange: @escaping (OverrideHoursMode) -> Void,
        onStartChange: @escaping (Date) -> Void,
        onEndChange: @escaping (Date) -> Void
    ) {
        self.row = row
        self.onRemove = onRemove
        self.onDateChange = onDateChange
        self.onModeChange = onModeChange
        self.onStartChange = onStartChange
        self.onEndChange = onEndChange
        _date = State(initialValue: row.date)
        _mode = State(initialValue: row.mode)
        _start = State(initialValue: row.start)
        _end = State(initialValue: row.end)
    }

    var body: some View {
        AdminAvailabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    AdminCompactDateField(date: $date, onChange: onDateChange)

                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AdminTheme.stone500)
                            .frame(width: 36, height: 36)
                            .background(AdminTheme.stone100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AdminTheme.stone200, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Picker("Hours", selection: $mode) {
                    ForEach(OverrideHoursMode.allCases) { option in
                        Text(option.segmentTitle).tag(option)
                    }
                }
                .adminLightSegmentedPicker()
                .onChange(of: mode) { _, newValue in
                    onModeChange(newValue)
                }

                if mode == .customHours {
                    HStack(alignment: .center, spacing: 8) {
                        AdminCompactTimeField(label: nil, time: $start, onChange: onStartChange)

                        Text("–")
                            .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                            .foregroundStyle(AdminTheme.stone500)

                        AdminCompactTimeField(label: nil, time: $end, onChange: onEndChange)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .onChange(of: row.date) { _, newValue in date = newValue }
        .onChange(of: row.mode) { _, newValue in mode = newValue }
        .onChange(of: row.start) { _, newValue in start = newValue }
        .onChange(of: row.end) { _, newValue in end = newValue }
    }
}

private extension OverrideHoursMode {
    var segmentTitle: String {
        switch self {
        case .unavailableAllDay: return "All day off"
        case .customHours: return "Custom"
        }
    }
}
