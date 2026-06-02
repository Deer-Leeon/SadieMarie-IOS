import SwiftUI
import ClerkKit

/// Account settings screen. Currently surfaces the signed-in admin's
/// email/name and a Clerk-backed sign-out button. Add new sections
/// (notification preferences, theme, business profile, etc.) by
/// extending the outer `List`.
///
/// Note: this view isn't wired into `RootTabView` yet — the five
/// admin tabs are Bookings / Availability / Clients / Website /
/// Services. Surface it as a toolbar button or a sheet on whichever
/// admin screen feels right.
struct SettingsView: View {
    @Environment(Clerk.self) private var clerk

    @State private var isSigningOut = false
    @State private var showingSignOutConfirmation = false
    @State private var signOutErrorMessage: String?

    private var emailLabel: String {
        clerk.user?.primaryEmailAddress?.emailAddress ?? "—"
    }

    private var nameLabel: String? {
        let first = clerk.user?.firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        let last = clerk.user?.lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        let combined = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Email", value: emailLabel)
                    if let nameLabel {
                        LabeledContent("Name", value: nameLabel)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isSigningOut {
                                ProgressView().controlSize(.small)
                            }
                            Text("Log Out").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Are you sure you want to log out?",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) { performSignOut() }
                Button("Cancel", role: .cancel) { }
            }
            .alert(
                "Couldn’t sign out",
                isPresented: Binding(
                    get: { signOutErrorMessage != nil },
                    set: { if !$0 { signOutErrorMessage = nil } }
                ),
                presenting: signOutErrorMessage
            ) { _ in
                Button("OK") { signOutErrorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private func performSignOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task { @MainActor in
            defer { isSigningOut = false }
            do {
                try await clerk.auth.signOut()
            } catch {
                AppLogger.authError("Clerk sign-out failed: \(error.localizedDescription)")
                signOutErrorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
}
