import SwiftUI

/// Focused single-day timeline overlay (web `SingleDayModal`, z-50).
struct SingleDayModal: View {
    let appointments: [Appointment]
    let initialDate: Date
    var onClose: () -> Void
    var onAppointmentClick: ((Appointment) -> Void)?

    @State private var activeDate: Date

    private let calendar = Calendar.current

    init(
        appointments: [Appointment],
        initialDate: Date,
        onClose: @escaping () -> Void,
        onAppointmentClick: ((Appointment) -> Void)? = nil
    ) {
        self.appointments = appointments
        self.initialDate = initialDate
        self.onClose = onClose
        self.onAppointmentClick = onAppointmentClick
        _activeDate = State(initialValue: calendar.startOfDay(for: initialDate))
    }

    private var positioned: [PositionedAppointment] {
        TimelineEngine.layoutForDay(date: activeDate, appointments: appointments)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.35))
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                modalHeader

                if positioned.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SingleDayTimelineView(
                        items: positioned,
                        onAppointmentTap: onAppointmentClick
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: 520)
            .frame(height: UIScreen.main.bounds.height * 0.82)
            .background(AdminTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
            .padding(.horizontal, 16)
            .onTapGesture { }
        }
        .preferredColorScheme(.light)
        .onChange(of: initialDate) { _, newValue in
            activeDate = calendar.startOfDay(for: newValue)
        }
    }

    private var modalHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(weekdayTitle)
                    .font(AdminTheme.fontAdminSerif(size: 20))
                    .foregroundStyle(AdminTheme.stone900)
                Text(monthDayTitle)
                    .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
            }
            .frame(maxWidth: .infinity)

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AdminTheme.cream.opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AdminTheme.stone200)
                .frame(height: 0.5)
        }
    }

    private var emptyState: some View {
        Text("No bookings on this day")
            .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
            .foregroundStyle(AdminTheme.stone700)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
    }

    private var weekdayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: activeDate)
    }

    private var monthDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: activeDate)
    }

    private func shiftDay(by offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: activeDate) else { return }
        activeDate = calendar.startOfDay(for: next)
    }
}

/// Identifiable wrapper for presenting `SingleDayModal`.
struct DayFocus: Identifiable, Hashable {
    let date: Date

    var id: TimeInterval {
        Calendar.current.startOfDay(for: date).timeIntervalSince1970
    }

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
