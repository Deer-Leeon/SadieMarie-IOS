import SwiftUI

struct AvailabilityOverridesSection: View {
    @Bindable var viewModel: AvailabilityViewModel
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                AdminSectionHeader(title: "Date overrides")
                Spacer(minLength: 8)
                Button(action: { presentAddPopup() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add")
                            .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AdminTheme.stone900)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add date override")
            }

            if viewModel.overrides.isEmpty {
                AdminAvailabilityCard {
                    Text("No upcoming date overrides. Add a date to block the day or set custom hours.")
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
                            isHighlighted: viewModel.highlightedOverrideId == row.id,
                            onRemove: { viewModel.removeOverride(id: row.id) },
                            onDateChange: { viewModel.setOverrideDate(id: row.id, date: $0) },
                            onModeChange: { viewModel.setOverrideMode(id: row.id, mode: $0) },
                            onStartChange: { viewModel.setOverrideTime(id: row.id, start: $0, end: nil) },
                            onEndChange: { viewModel.setOverrideTime(id: row.id, start: nil, end: $0) }
                        )
                        .id(row.id)
                    }
                }
            }

            if !viewModel.archivedOverrides.isEmpty {
                archivedSection
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            AvailabilityAddOverridePopup(
                onDismiss: { dismissAddPopup() },
                onConfirm: { date, unavailable, start, end in
                    viewModel.confirmAddOverride(
                        date: date,
                        unavailable: unavailable,
                        start: start,
                        end: end
                    ) != nil
                }
            )
            .presentationBackground(.clear)
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.archiveExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.archiveExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                    Text("ARCHIVED")
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .tracking(2.0)
                        .foregroundStyle(AdminTheme.stone500)
                    Text("\(viewModel.archivedOverrides.count)")
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AdminTheme.stone100)
                        .clipShape(Capsule())
                    Spacer()
                    Text("Past dates · Dismiss to delete")
                        .font(AdminTheme.fontAdminSans(size: 11))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
            .buttonStyle(.plain)

            if viewModel.archiveExpanded {
                VStack(spacing: 8) {
                    ForEach(viewModel.archivedOverrides) { row in
                        archivedCard(row)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func archivedCard(_ row: OverrideRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.formatArchivedDate(row.date))
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
                Text(
                    row.unavailable
                        ? "Unavailable all day"
                        : "\(AvailabilityTimeFormat.hhmm(from: row.start)) – \(AvailabilityTimeFormat.hhmm(from: row.end))"
                )
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)
            }
            Spacer(minLength: 8)
            Button {
                viewModel.removeArchivedOverride(id: row.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                    Text("Dismiss")
                        .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                }
                .foregroundStyle(AdminTheme.stone500)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AdminTheme.cardFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss archived override")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AdminTheme.stone50)
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private static func formatArchivedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "America/Denver")
        return formatter.string(from: date)
    }

    /// Presents/dismisses the popup without the system cover's bottom-slide,
    /// so the dialog's own scale/opacity animation is what the user sees.
    private func presentAddPopup() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { showAddSheet = true }
    }

    private func dismissAddPopup() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { showAddSheet = false }
    }
}

private struct AvailabilityOverrideCard: View {
    let row: OverrideRow
    let isHighlighted: Bool
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
        isHighlighted: Bool,
        onRemove: @escaping () -> Void,
        onDateChange: @escaping (Date) -> Void,
        onModeChange: @escaping (OverrideHoursMode) -> Void,
        onStartChange: @escaping (Date) -> Void,
        onEndChange: @escaping (Date) -> Void
    ) {
        self.row = row
        self.isHighlighted = isHighlighted
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

    private var showsInvalidHours: Bool {
        mode == .customHours && !row.hasValidCustomHours
    }

    private var modeSelection: Binding<OverrideHoursMode> {
        Binding(
            get: { mode },
            set: { newValue in
                withAnimation(.smooth(duration: 0.32, extraBounce: 0)) {
                    mode = newValue
                    onModeChange(newValue)
                }
            }
        )
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
                    .accessibilityLabel("Remove override")
                }

                Picker("Hours", selection: modeSelection) {
                    ForEach(OverrideHoursMode.allCases) { option in
                        Text(option.segmentTitle).tag(option)
                    }
                }
                .adminLightSegmentedPicker()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        AdminCompactTimeField(label: nil, time: $start, onChange: onStartChange)

                        Text("–")
                            .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                            .foregroundStyle(AdminTheme.stone500)

                        AdminCompactTimeField(label: nil, time: $end, onChange: onEndChange)
                    }

                    if showsInvalidHours {
                        Text("End time must be after start time.")
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(Color.semanticRed)
                    }
                }
                .frame(maxHeight: mode == .customHours ? 80 : 0, alignment: .top)
                .opacity(mode == .customHours ? 1 : 0)
                .clipped()
                .allowsHitTesting(mode == .customHours)
                .accessibilityHidden(mode != .customHours)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(isHighlighted ? AdminTheme.stone900 : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
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
