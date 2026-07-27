import SwiftUI
import ClerkKit

/// Bookings tab — calendar / appointment workspace. Mirrors the
/// segmented "List / 3 Day / Week / Month" control from the web admin
/// portal. List mode loads live appointments from the admin API.
struct BookingsView: View {
    /// Incremented by `RootTabView` each time the user switches to the Bookings tab.
    var tabVisitID: Int = 0

    enum CalendarMode: String, CaseIterable, Identifiable, Hashable {
        case list = "List"
        case threeDay = "3 Day"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }
    }

    @Environment(Clerk.self) private var clerk

    @State private var viewModel = BookingsViewModel()
    @State private var mode: CalendarMode = .threeDay
    @State private var selectedAppointment: Appointment?
    @State private var dayFocus: DayFocus?
    @State private var manualBookingFocus: ManualBookingFocus?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                contentBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Bookings")
                            .font(AdminTheme.fontAdminSerif(size: 28))
                            .foregroundStyle(AdminTheme.stone900)

                        Spacer(minLength: 12)

                        HStack(spacing: 10) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AdminTheme.stone700)
                                    .frame(width: 36, height: 36)
                                    .background(AdminTheme.cardFill)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AdminTheme.stone200, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Settings")

                            newBookingHeaderButton
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    Picker("Calendar mode", selection: $mode) {
                        ForEach(CalendarMode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .adminLightSegmentedPicker()
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.vertical, 8)

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }

                    modeContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.light)
            .task(id: clerk.session?.id) {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }
            .refreshable {
                guard clerk.session != nil else { return }
                await viewModel.load()
            }

            .onChange(of: tabVisitID) { _, _ in
                mode = .threeDay
            }
            .sheet(item: $selectedAppointment) { appointment in
                AppointmentDetailSheet(
                    appointment: appointment,
                    onDismiss: { selectedAppointment = nil },
                    onMutated: {
                        selectedAppointment = nil
                        Task { await viewModel.load() }
                    }
                )
            }
            .overlay {
                if let focus = dayFocus {
                    SingleDayModal(
                        appointments: viewModel.visibleAppointments,
                        initialDate: focus.date,
                        onClose: { dayFocus = nil },
                        onAppointmentClick: { selectedAppointment = $0 }
                    )
                    .transition(.opacity)
                    .zIndex(50)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: dayFocus != nil)
            .fullScreenCover(item: $manualBookingFocus) { focus in
                ManualBookingWizardView(
                    bookingDate: focus.date,
                    onClose: { manualBookingFocus = nil },
                    onSuccess: {
                        manualBookingFocus = nil
                        Task { await viewModel.load() }
                    }
                )
                .presentationBackground(AdminTheme.cream)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .list:
            BookingsListView(
                appointments: viewModel.visibleAppointments,
                showsEmptyState: viewModel.errorMessage == nil,
                onSelectAppointment: { selectedAppointment = $0 }
            )
        case .threeDay, .week, .month:
            BookingsCalendarContainerView(
                mode: mode,
                gridAppointments: viewModel.calendarAppointments,
                modalAppointments: viewModel.visibleAppointments,
                onDayClick: { dayFocus = DayFocus(date: $0) },
                onSelectAppointment: { selectedAppointment = $0 }
            )
        }
    }

    private var newBookingHeaderButton: some View {
        Button {
            manualBookingFocus = ManualBookingFocus(date: Date())
        } label: {
            Text("New\nBooking")
                .font(AdminTheme.fontAdminSans(size: 10, weight: .semibold))
                .tracking(1.2)
                .multilineTextAlignment(.center)
                .foregroundStyle(AdminTheme.stone700)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New booking")
    }

    private var contentBackground: Color {
        AdminTheme.cream
    }

    private var loadingOverlay: some View {
        ZStack {
            AdminTheme.cream
                .opacity(0.85)
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(AppFont.body())
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.vertical, 10)
            .background(Color.semanticRed.opacity(0.12))
    }
}

#Preview {
    BookingsView()
}
