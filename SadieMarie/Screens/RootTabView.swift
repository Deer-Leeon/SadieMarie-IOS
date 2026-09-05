import SwiftUI
import ClerkKit

/// Root tab shell shown to signed-in admins. Mirrors the five
/// top-level destinations of the Sadie Marie web admin portal:
/// Bookings, Availability, Clients, Website, and Services. Keep the
/// count at ≤ 5 so iOS doesn't collapse them into a "More" button.
struct RootTabView: View {
    enum Tab: Hashable {
        case bookings
        case availability
        case clients
        case website
        case services

        /// Matches `TabView` order in `body`.
        var index: Int {
            switch self {
            case .bookings: 0
            case .availability: 1
            case .clients: 2
            case .website: 3
            case .services: 4
            }
        }
    }

    @Environment(Clerk.self) private var clerk
    @Environment(PushRegistration.self) private var pushRegistration

    @Bindable var bookingsViewModel: BookingsViewModel

    @State private var selection: Tab = .bookings
    @State private var bookingsTabVisitID = 0
    @State private var bookingsJumpToTodayID = 0
    @State private var availabilityViewModel = AvailabilityViewModel()
    @State private var clientsViewModel = ClientsViewModel()
    @State private var websiteViewModel = WebsiteViewModel()
    @State private var servicesViewModel = ServicesViewModel()

    var body: some View {
        TabView(selection: $selection) {
            BookingsView(
                viewModel: bookingsViewModel,
                tabVisitID: bookingsTabVisitID,
                jumpToTodayID: bookingsJumpToTodayID,
                isSelected: selection == .bookings
            )
                .tabItem {
                    Label("Bookings", systemImage: "calendar")
                }
                .tag(Tab.bookings)

            AvailabilityView(viewModel: availabilityViewModel)
                .tabItem {
                    Label("Availability", systemImage: "clock")
                }
                .tag(Tab.availability)

            ClientsView(viewModel: clientsViewModel)
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }
                .tag(Tab.clients)

            WebsiteView(viewModel: websiteViewModel)
                .tabItem {
                    Label("Website", systemImage: "globe")
                }
                .tag(Tab.website)

            ServicesView(viewModel: servicesViewModel)
                .tabItem {
                    Label("Services", systemImage: "sparkles")
                }
                .tag(Tab.services)
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .toolbarColorScheme(.light, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .animation(nil, value: selection)
        .background {
            TabBarReselectObserver { index in
                guard index == Tab.bookings.index, selection == .bookings else { return }
                bookingsJumpToTodayID += 1
            }
        }
        .onChange(of: selection) { previous, current in
            if current == .bookings, previous != .bookings {
                bookingsTabVisitID += 1
            }
        }
        .onChange(of: pushRegistration.pendingOpenAppointmentId) { _, appointmentId in
            guard appointmentId != nil else { return }
            selection = .bookings
        }
        .onAppear {
            if pushRegistration.pendingOpenAppointmentId != nil {
                selection = .bookings
            }
        }
        .task(id: clerk.session?.id) {
            guard clerk.session != nil else { return }
            await SessionKeepAlive.waitUntilReadyForAPI()
            await prefetchTabs()
        }
    }

    /// Start every tab's fetch as soon as the session is ready so tapping
    /// Availability / Clients / Website / Services doesn't wait on Cal.
    private func prefetchTabs() async {
        async let bookings: Void = bookingsViewModel.load(showLoading: !bookingsViewModel.hasLoaded)
        async let availability: Void = availabilityViewModel.load(showLoading: !availabilityViewModel.hasLoaded)
        async let clients: Void = clientsViewModel.load(showLoading: !clientsViewModel.hasLoaded)
        async let website: Void = websiteViewModel.load(showLoading: !websiteViewModel.hasLoaded)
        async let services: Void = servicesViewModel.load(showLoading: !servicesViewModel.hasLoaded)
        _ = await (bookings, availability, clients, website, services)
    }
}

#Preview {
    RootTabView(bookingsViewModel: BookingsViewModel())
        .environment(AppState())
        .environment(PushRegistration.shared)
}
