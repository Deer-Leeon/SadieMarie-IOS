import SwiftUI

/// Empty calendar-hour tap: book (default) or block, matching web
/// `CalendarSlotActionDialog`.
struct CalendarSlotActionFocus: Identifiable, Hashable {
    let date: Date
    let hour: Int

    var id: String {
        "\(date.timeIntervalSince1970)-\(hour)"
    }
}

enum SlotActionMode: String, CaseIterable {
    case book
    case block
}

struct SlotActionModeToggle: View {
    @Binding var mode: SlotActionMode

    var body: some View {
        HStack(spacing: 0) {
            modeButton(.book, title: "Book")
            modeButton(.block, title: "Block time")
        }
        .padding(3)
        .background(AdminTheme.cardFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Book or block time")
    }

    private func modeButton(_ value: SlotActionMode, title: String) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(mode == value ? AdminTheme.cardFill : AdminTheme.stone600)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(mode == value ? AdminTheme.stone900 : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

struct CalendarSlotActionView: View {
    let date: Date
    let hour: Int
    @Bindable var bookingsViewModel: BookingsViewModel
    var onClose: () -> Void
    var onBooked: () -> Void
    var onBlocked: () -> Void

    @State private var mode: SlotActionMode = .book

    var body: some View {
        Group {
            if mode == .book {
                ManualBookingWizardView(
                    bookingDate: date,
                    seedHour: hour,
                    modeSwitch: AnyView(SlotActionModeToggle(mode: $mode)),
                    onClose: onClose,
                    onSuccess: onBooked
                )
            } else {
                ZStack {
                    AdminTheme.cream.ignoresSafeArea()
                    BlockTimePopup(
                        activeDate: date,
                        initialHour: hour,
                        isSubmitting: bookingsViewModel.isCreatingBlock,
                        submissionError: bookingsViewModel.errorMessage,
                        modeSwitch: AnyView(SlotActionModeToggle(mode: $mode)),
                        onCancel: onClose,
                        onSubmit: submitBlock
                    )
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func submitBlock(_ request: BlockTimeRequest) {
        Task {
            if await bookingsViewModel.createTimeBlock(request) {
                onBlocked()
            }
        }
    }
}
