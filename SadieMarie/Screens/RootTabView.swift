import SwiftUI

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
    }

    @State private var selection: Tab = .bookings
    @State private var bookingsTabVisitID = 0

    var body: some View {
        TabView(selection: $selection) {
            BookingsView(tabVisitID: bookingsTabVisitID)
                .tabItem {
                    Label("Bookings", systemImage: "calendar")
                }
                .tag(Tab.bookings)

            AvailabilityView()
                .tabItem {
                    Label("Availability", systemImage: "clock")
                }
                .tag(Tab.availability)

            ClientsView()
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }
                .tag(Tab.clients)

            WebsiteView()
                .tabItem {
                    Label("Website", systemImage: "globe")
                }
                .tag(Tab.website)

            ServicesView()
                .tabItem {
                    Label("Services", systemImage: "sparkles")
                }
                .tag(Tab.services)
        }
        .tint(Color.accent)
        .onChange(of: selection) { previous, current in
            if current == .bookings, previous != .bookings {
                bookingsTabVisitID += 1
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppState())
}
