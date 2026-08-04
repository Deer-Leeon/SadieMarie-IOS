import SwiftUI

/// Create or edit a studio time block (web `BlockTimeDialog`).
struct BlockTimePopup: View {
    let activeDate: Date
    let initialHour: Int
    let editingBlock: TimeBlock?
    var isSubmitting: Bool
    var submissionError: String?
    var onCancel: () -> Void
    var onSubmit: (BlockTimeRequest) -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var note = ""
    @State private var validationMessage: String?
    @State private var appeared = false

    private var contentAnimation: Animation { .smooth(duration: 0.3, extraBounce: 0) }

    init(
        activeDate: Date,
        initialHour: Int,
        editingBlock: TimeBlock? = nil,
        isSubmitting: Bool,
        submissionError: String? = nil,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (BlockTimeRequest) -> Void
    ) {
        self.activeDate = activeDate
        self.initialHour = initialHour
        self.editingBlock = editingBlock
        self.isSubmitting = isSubmitting
        self.submissionError = submissionError
        self.onCancel = onCancel
        self.onSubmit = onSubmit

        let day = StudioTime.startOfStudioDay(for: activeDate)
        let existingStart = editingBlock.flatMap { BookingDisplay.iso8601Date(from: $0.startTime) }
        let defaultStart = existingStart ?? StudioTime.date(on: day, hour: initialHour) ?? day
        var defaultEnd = StudioTime.calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart
        if let existingEnd = editingBlock.flatMap({ BookingDisplay.iso8601Date(from: $0.endTime) }) {
            defaultEnd = existingEnd
        }
        if let endHour = StudioTime.calendar.component(.hour, from: defaultEnd) as Int?,
           endHour > TimelineEngine.endHour
           || (endHour == TimelineEngine.endHour && StudioTime.calendar.component(.minute, from: defaultEnd) > 0) {
            defaultEnd = StudioTime.date(on: day, hour: TimelineEngine.endHour) ?? defaultEnd
        }
        _start = State(initialValue: defaultStart)
        _end = State(initialValue: defaultEnd)
        _note = State(initialValue: editingBlock?.note ?? "")
    }

    private var canSubmit: Bool {
        hhmm(from: start) < hhmm(from: end)
    }

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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(editingBlock == nil ? "Block time" : "Edit blocked time")
                        .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                        .foregroundStyle(AdminTheme.stone500)
                        .textCase(.uppercase)
                    Text(StudioTime.displayWeekdayMonthDay(isoDate: StudioTime.yyyyMMdd(from: activeDate)))
                        .font(AdminTheme.fontAdminSerif(size: 20))
                        .foregroundStyle(AdminTheme.stone900)
                    Text("Clients won't be able to book this interval on the website. Minimum 30 minutes.")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                }
                Spacer(minLength: 8)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .buttonStyle(.plain)
            }

            if let formError = validationMessage ?? submissionError {
                Text(formError)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.semanticRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                timeField(label: "Start", time: $start)
                timeField(label: "End", time: $end)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Note (optional)")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                TextField("e.g. Lunch, personal errand", text: $note)
                    .font(AdminTheme.fontAdminSans(size: 14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AdminTheme.stone100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AdminTheme.stone200, lineWidth: 1)
                    )
            }

            HStack {
                Spacer()
                Button("Cancel", action: close)
                    .font(AdminTheme.fontAdminSans(size: 15))
                    .foregroundStyle(AdminTheme.stone700)
                    .disabled(isSubmitting)

                Button(action: submit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(AdminTheme.cardFill)
                        } else {
                            Text(editingBlock == nil ? "Block time" : "Save changes")
                                .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(canSubmit ? AdminTheme.cardFill : AdminTheme.stone600)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canSubmit ? AdminTheme.stone900 : AdminTheme.stone200)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .padding(20)
        .background(AdminTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    private func timeField(label: String, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)
            AdminCompactTimeField(label: nil, time: time) { time.wrappedValue = $0 }
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() {
        validationMessage = nil
        guard validateTimes() else { return }
        onSubmit(
            BlockTimeRequest(
                start: start,
                end: end,
                note: note
            )
        )
    }

    private func validateTimes() -> Bool {
        let startHour = StudioTime.calendar.component(.hour, from: start)
        let endHour = StudioTime.calendar.component(.hour, from: end)
        let endMinute = StudioTime.calendar.component(.minute, from: end)

        if startHour < TimelineEngine.startHour
            || endHour > TimelineEngine.endHour
            || (endHour == TimelineEngine.endHour && endMinute > 0) {
            validationMessage = "Blocks must stay within 9:00 AM – 9:00 PM."
            return false
        }
        if hhmm(from: start) >= hhmm(from: end) {
            validationMessage = "End time must be after start time."
            return false
        }
        let durationMinutes = Int(end.timeIntervalSince(start) / 60)
        if durationMinutes < 30 {
            validationMessage = "Blocks must be at least 30 minutes."
            return false
        }
        return true
    }

    private func hhmm(from date: Date) -> String {
        AvailabilityTimeFormat.hhmm(from: date)
    }

    private func close() {
        guard !isSubmitting else { return }
        withAnimation(.smooth(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onCancel() }
    }
}
