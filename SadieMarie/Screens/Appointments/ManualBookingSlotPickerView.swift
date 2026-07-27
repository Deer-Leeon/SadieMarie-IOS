import SwiftUI

/// Step 3 calendar + slot grid (mirrors web `ManualBookingSlotPicker`).
struct ManualBookingSlotPickerView: View {
    enum Layout {
        case regular
        case compact
    }

    @Bindable var viewModel: ManualBookingViewModel
    var layout: Layout = .regular

    private let weekdaysCompact = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private let weekdaysFull = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let studioToday = StudioTime.todayInStudio()

    private var isCompact: Bool { layout == .compact }
    private var weekdayLabels: [String] { isCompact ? weekdaysCompact : weekdaysFull }

    var body: some View {
        if isCompact {
            compactAvailabilityCard
        } else {
            regularLayout
        }
    }

    // MARK: - Compact (phone — single card, no wasted space)

    private var compactAvailabilityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            clientSummary
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                monthNavigation

                if viewModel.monthLoading {
                    monthLoadingContent
                } else {
                    calendarGrid
                }

                if let monthError = viewModel.monthError, !viewModel.monthLoading {
                    Text(monthError)
                        .font(AdminTheme.fontAdminSans(size: 11))
                        .foregroundStyle(AdminTheme.stone500)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            timesSection
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var monthLoadingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ManualBookingLoadingPanel(
                title: "Checking availability",
                subtitle: "Loading open days from Cal.com"
            )

            ManualBookingCalendarSkeleton(rowCount: 5, cellSize: 28)
                .opacity(0.7)
        }
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDayLabel)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Spacer(minLength: 6)
                Text("Mountain")
                    .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
            }

            if viewModel.monthLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AdminTheme.stone600)
                    Text("Times load after open days")
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else if !viewModel.slotsForSelectedDay.isEmpty {
                scrollableSlotsGrid(compact: true)
                Text("Green = fits studio hours · Black = outside or overruns")
                    .font(AdminTheme.fontAdminSans(size: 9, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            } else {
                Text(viewModel.availableDates.isEmpty
                    ? "No open days this month — try another month."
                    : "Tap a highlighted day to see times.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }

    /// When there are many slots, cap height and scroll so nothing is clipped.
    @ViewBuilder
    private func scrollableSlotsGrid(compact: Bool) -> some View {
        let slotCount = viewModel.slotsForSelectedDay.count
        let columnsPerRow = compact ? 3 : 3
        let rowCount = max(1, (slotCount + columnsPerRow - 1) / columnsPerRow)
        let rowHeight: CGFloat = compact ? 40 : 44
        let naturalHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * 8
        let maxVisibleHeight: CGFloat = compact ? 168 : 220
        let needsScroll = naturalHeight > maxVisibleHeight || slotCount > 9

        let grid = Group {
            if compact {
                compactSlotsGrid
            } else {
                regularSlotsGrid
            }
        }

        if needsScroll {
            ScrollView(.vertical, showsIndicators: true) {
                grid
                    .padding(.bottom, 4)
            }
            .frame(maxHeight: maxVisibleHeight)
        } else {
            grid
        }
    }

    private var compactSlotsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72, maximum: 110), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(viewModel.slotsForSelectedDay, id: \.self) { slot in
                slotButton(slot, compact: true)
            }
        }
    }

    private var regularSlotsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 8
        ) {
            ForEach(viewModel.slotsForSelectedDay, id: \.self) { slot in
                slotButton(slot, compact: false)
            }
        }
    }

    // MARK: - Regular (fallback / wider layouts)

    private var regularLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            clientSummary
            monthCalendarCard
            slotsCard
        }
    }

    private var clientSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 14))
                .foregroundStyle(AdminTheme.stone500)
            Text(viewModel.clientDisplayName)
                .font(AdminTheme.fontAdminSans(size: isCompact ? 13 : 14, weight: .medium))
                .foregroundStyle(AdminTheme.stone900)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isCompact {
                Text("Saved")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.confirmedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AdminTheme.confirmedBackground)
                    .clipShape(Capsule())
            } else {
                Text("details saved")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }
        }
    }

    private var monthNavigation: some View {
        HStack {
            monthNavButton(systemName: "chevron.left") {
                viewModel.shiftMonth(by: -1)
            }
            Spacer()
            Text(StudioTime.monthLabel(year: viewModel.viewYear, month: viewModel.viewMonth))
                .font(AdminTheme.fontAdminSerif(size: 16))
                .foregroundStyle(AdminTheme.stone900)
            Spacer()
            monthNavButton(systemName: "chevron.right") {
                viewModel.shiftMonth(by: 1)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 4
        ) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                if let cell {
                    dayButton(cell, compact: isCompact)
                } else {
                    Color.clear
                        .frame(height: isCompact ? 30 : 36)
                }
            }
        }
    }

    private var monthCalendarCard: some View {
        VStack(spacing: 10) {
            monthNavigation

            if viewModel.monthLoading {
                monthLoadingContent
            } else {
                calendarGrid
            }

            if let monthError = viewModel.monthError, !viewModel.monthLoading {
                Text(monthError)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var slotsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDayLabel)
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Spacer()
                Text("Mountain time")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
            }

            if viewModel.monthLoading {
                ManualBookingLoadingPanel(
                    title: "Loading times",
                    subtitle: "Available after open days load"
                )
            } else if !viewModel.slotsForSelectedDay.isEmpty {
                scrollableSlotsGrid(compact: false)
                Text("Green = fits studio hours · Black = outside or overruns")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
            } else {
                Text(viewModel.availableDates.isEmpty
                    ? "No open days this month — try the next month."
                    : "Choose an open day above to see times.")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(12)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    // MARK: - Shared

    private var selectedDayLabel: String {
        guard let date = viewModel.selectedDate,
              viewModel.availableDates.contains(date) else {
            return "Pick a day"
        }
        return StudioTime.displayWeekdayMonthDay(isoDate: date)
    }

    private var monthCells: [MonthCell?] {
        let year = viewModel.viewYear
        let month = viewModel.viewMonth
        let firstDow = firstWeekdayOfMonth(year: year, month: month)
        let daysInMonth = StudioTime.lastDayOfMonth(year: year, month: month)
        var cells: [MonthCell?] = Array(repeating: nil, count: firstDow)
        for day in 1...daysInMonth {
            let iso = String(format: "%04d-%02d-%02d", year, month, day)
            cells.append(MonthCell(date: iso, day: day))
        }
        return cells
    }

    private func monthNavButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AdminTheme.stone700)
                .frame(width: 30, height: 30)
                .background(AdminTheme.stone50)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.monthLoading)
    }

    private func dayButton(_ cell: MonthCell, compact: Bool) -> some View {
        let isPast = cell.date < studioToday
        let hasSlots = viewModel.availableDates.contains(cell.date)
        let isStudio = viewModel.isStudioDay(cell.date)
        let isSelectable = hasSlots && !isPast
        let isSelected = viewModel.selectedDate == cell.date && isSelectable
        let size: CGFloat = compact ? 30 : 36

        return Button {
            viewModel.pickDate(cell.date)
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(AdminTheme.stone900)
                } else if isSelectable {
                    Circle()
                        .stroke(isStudio ? AdminTheme.stone900 : AdminTheme.stone300, lineWidth: 1)
                        .background(Circle().fill(AdminTheme.stone50))
                } else if isStudio && !isPast {
                    Circle()
                        .stroke(AdminTheme.stone900.opacity(0.4), lineWidth: 1)
                }

                Text("\(cell.day)")
                    .font(AdminTheme.fontAdminSans(
                        size: compact ? 12 : 14,
                        weight: isSelected ? .semibold : .regular
                    ))
                    .foregroundStyle(
                        isSelected
                            ? AdminTheme.cream
                            : (isSelectable ? AdminTheme.stone900 : AdminTheme.stone300)
                    )
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    private func slotButton(_ slot: String, compact: Bool) -> some View {
        let active = viewModel.selectedSlot == slot
        let inStudio = viewModel.slotFitsStudioHours(slot)
        return Button {
            viewModel.selectSlot(slot)
        } label: {
            HStack(spacing: compact ? 5 : 6) {
                Circle()
                    .fill(inStudio
                          ? (active ? AdminTheme.confirmedText.opacity(0.85) : AdminTheme.confirmedText)
                          : (active ? AdminTheme.stone700 : AdminTheme.stone900))
                    .frame(width: 6, height: 6)
                Text(StudioTime.formatSlotInStudioTime(isoUtc: slot))
                    .font(AdminTheme.fontAdminSans(size: compact ? 13 : 14, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? AdminTheme.stone900 : AdminTheme.stone700)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 9 : 10)
            .padding(.horizontal, 6)
            .background(active ? AdminTheme.stone50 : AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? AdminTheme.stone300 : AdminTheme.stone200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func firstWeekdayOfMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = StudioTime.calendar.date(from: components) else { return 0 }
        return StudioTime.calendar.component(.weekday, from: date) - 1
    }

    private struct MonthCell {
        let date: String
        let day: Int
    }
}
