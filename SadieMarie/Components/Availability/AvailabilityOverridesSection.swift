import SwiftUI

struct AvailabilityOverridesSection: View {
    @Bindable var viewModel: AvailabilityViewModel
    @State private var showAddSheet = false

    var body: some View {
        AdminAvailabilitySectionCard {
            AdminAvailabilitySectionHeader(
                eyebrow: "One-off",
                title: "Date overrides",
                subtitle: viewModel.overrides.isEmpty
                    ? "Close a date or set different hours."
                    : "\(viewModel.overrides.count) upcoming \(viewModel.overrides.count == 1 ? "date" : "dates")."
            ) {
                Button(action: { presentAddPopup() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Add")
                            .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(AdminTheme.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AdminTheme.stone900)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add date override")
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.overrides.isEmpty {
                    Text("No upcoming date overrides. Add a date to block the day or set custom hours.")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .italic()
                        .foregroundStyle(AdminTheme.stone500)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.overrides.enumerated()), id: \.element.id) { offset, row in
                            AvailabilityOverrideRow(
                                row: row,
                                isHighlighted: viewModel.highlightedOverrideId == row.id,
                                onRemove: { viewModel.removeOverride(id: row.id) },
                                onDateChange: { viewModel.setOverrideDate(id: row.id, date: $0) },
                                onModeChange: { viewModel.setOverrideMode(id: row.id, mode: $0) },
                                onStartChange: { viewModel.setOverrideTime(id: row.id, start: $0, end: nil) },
                                onEndChange: { viewModel.setOverrideTime(id: row.id, start: nil, end: $0) }
                            )
                            .id(row.id)

                            if offset < viewModel.overrides.count - 1 {
                                Divider()
                                    .overlay(AdminTheme.stone100)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }

                if !viewModel.archivedOverrides.isEmpty {
                    archivedSection
                }
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
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(AdminTheme.stone200)

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
                    Text("Past dates")
                        .font(AdminTheme.fontAdminSans(size: 11))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, viewModel.archiveExpanded ? 10 : 14)

            if viewModel.archiveExpanded {
                VStack(spacing: 0) {
                    ForEach(viewModel.archivedOverrides) { row in
                        archivedCard(row)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func archivedCard(_ row: OverrideRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AvailabilityTimeFormat.displayOverrideWeekday(row.date))
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(AdminTheme.stone500)
                Text(AvailabilityTimeFormat.displayOverrideMonthDay(row.date))
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
            }
            Spacer(minLength: 8)
            Text(row.hoursSummary)
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
            Button {
                viewModel.removeArchivedOverride(id: row.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss archived override")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

private struct AvailabilityOverrideRow: View {
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
    @State private var isExpanded: Bool

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
        _isExpanded = State(initialValue: isHighlighted)
    }

    private var showsInvalidHours: Bool {
        mode == .customHours && !row.hasValidCustomHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow

            if isExpanded {
                editor
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isExpanded ? 14 : 12)
        .background(isHighlighted ? AdminTheme.stone50 : Color.clear)
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
        .animation(.smooth(duration: 0.28, extraBounce: 0), value: isExpanded)
        .onChange(of: row.date) { _, newValue in date = newValue }
        .onChange(of: row.mode) { _, newValue in mode = newValue }
        .onChange(of: row.start) { _, newValue in start = newValue }
        .onChange(of: row.end) { _, newValue in end = newValue }
        .onChange(of: isHighlighted) { _, highlighted in
            if highlighted {
                isExpanded = true
            }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AvailabilityTimeFormat.displayOverrideWeekday(date))
                            .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(AdminTheme.stone500)
                        Text(AvailabilityTimeFormat.displayOverrideMonthDay(date))
                            .font(AdminTheme.fontAdminSerif(size: 18))
                            .foregroundStyle(AdminTheme.stone900)
                    }

                    Spacer(minLength: 8)

                    hoursLabel

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(AvailabilityTimeFormat.displayOverrideMonthDay(date)), \(row.hoursSummary)"
            )
            .accessibilityHint(isExpanded ? "Collapse override" : "Edit override")
            .accessibilityAddTraits(.isButton)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove override")
        }
    }

    @ViewBuilder
    private var hoursLabel: some View {
        if row.unavailable {
            Text("Closed")
                .font(AdminTheme.fontAdminSans(size: 11, weight: .semibold))
                .foregroundStyle(AdminTheme.stone600)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AdminTheme.stone100)
                .clipShape(Capsule())
        } else {
            HStack(spacing: 6) {
                if showsInvalidHours {
                    Circle()
                        .fill(Color.semanticRed)
                        .frame(width: 6, height: 6)
                }
                Text(row.hoursSummary)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(showsInvalidHours ? Color.semanticRed : AdminTheme.stone700)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminCompactDateField(date: $date, onChange: onDateChange)

            HStack(spacing: 8) {
                modeChip(
                    "Closed",
                    selected: mode == .unavailableAllDay
                ) {
                    mode = .unavailableAllDay
                    onModeChange(.unavailableAllDay)
                }
                modeChip(
                    "Hours",
                    selected: mode == .customHours
                ) {
                    mode = .customHours
                    onModeChange(.customHours)
                }
                Spacer(minLength: 0)
            }

            if mode == .customHours {
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
        }
    }

    private func modeChip(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                .foregroundStyle(selected ? AdminTheme.cardFill : AdminTheme.stone700)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AdminTheme.stone900 : AdminTheme.stone100)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
