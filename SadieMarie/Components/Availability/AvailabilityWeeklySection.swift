import SwiftUI

struct AvailabilityWeeklySection: View {
    @Bindable var viewModel: AvailabilityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdminSectionHeader(title: "Weekly hours")

            AdminAvailabilityCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.weekly.enumerated()), id: \.element.id) { offset, row in
                        AvailabilityWeeklyDayRow(
                            row: row,
                            onEnabledChange: { viewModel.setDayEnabled(offset, enabled: $0) },
                            onStartChange: { viewModel.setDayTime(offset, start: $0, end: nil) },
                            onEndChange: { viewModel.setDayTime(offset, start: nil, end: $0) }
                        )

                        if offset < viewModel.weekly.count - 1 {
                            Divider()
                                .overlay(AdminTheme.stone200)
                        }
                    }
                }
            }
        }
    }
}

private struct AvailabilityWeeklyDayRow: View {
    let row: WeeklyDayRow
    let onEnabledChange: (Bool) -> Void
    let onStartChange: (Date) -> Void
    let onEndChange: (Date) -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var enabled: Bool

    init(
        row: WeeklyDayRow,
        onEnabledChange: @escaping (Bool) -> Void,
        onStartChange: @escaping (Date) -> Void,
        onEndChange: @escaping (Date) -> Void
    ) {
        self.row = row
        self.onEnabledChange = onEnabledChange
        self.onStartChange = onStartChange
        self.onEndChange = onEndChange
        _start = State(initialValue: row.start)
        _end = State(initialValue: row.end)
        _enabled = State(initialValue: row.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(row.dayName.title)
                    .font(AdminTheme.fontAdminSerif(size: 15))
                    .foregroundStyle(enabled ? AdminTheme.stone900 : AdminTheme.stone600)

                Spacer(minLength: 8)

                Toggle("", isOn: $enabled)
                    .toggleStyle(AdminPillToggleStyle())
                    .onChange(of: enabled) { _, newValue in
                        onEnabledChange(newValue)
                    }
            }

            if enabled {
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
        .padding(.vertical, enabled ? 10 : 8)
        .onChange(of: row.enabled) { _, newValue in enabled = newValue }
        .onChange(of: row.start) { _, newValue in start = newValue }
        .onChange(of: row.end) { _, newValue in end = newValue }
    }
}
