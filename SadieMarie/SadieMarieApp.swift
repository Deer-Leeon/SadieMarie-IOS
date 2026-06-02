import SwiftUI
import ClerkKit

/// Application entry point. Configures the Clerk SDK *first* — before
/// any SwiftUI state property reads `Clerk.shared` — and acts as the
/// bouncer for the rest of the UI:
///
/// - While Clerk is still loading from cache / network → splash screen.
/// - When `clerk.user == nil` → `LoginView` (signed-out shell).
/// - When `clerk.user != nil` → `RootTabView` (the 5 admin tabs).
@main
struct SadieMarieApp: App {

    /// ⚠️ Replace `YOUR_KEY_HERE` with your real publishable key from
    /// the Clerk Dashboard (Configure → API Keys → Publishable key).
    /// Publishable keys are non-secret by design — they're meant to
    /// ship with client apps — so hardcoding is acceptable. Use a
    /// `pk_test_…` key for development/TestFlight and a `pk_live_…`
    /// key for App Store builds.
    private static let clerkPublishableKey = "pk_test_cmVsYXRlZC1saXphcmQtMTguY2xlcmsuYWNjb3VudHMuZGV2JA"

    // No default values on these — see `init()`. Default values would
    // run during the synthesized property-storage init *before* our
    // explicit `init()` body, which would access `Clerk.shared`
    // before `Clerk.configure(...)` has had a chance to run.
    @State private var appState: AppState
    @State private var clerk: Clerk

    init() {
        // 1. Configure Clerk synchronously. This MUST happen before
        //    any property — `@State`, `@Environment`, etc. — touches
        //    `Clerk.shared`, otherwise the SDK trips an
        //    `assertionFailure` in debug builds.
        Clerk.configure(publishableKey: Self.clerkPublishableKey)

        let keyPrefix = String(Self.clerkPublishableKey.prefix(12))
        let isPlaceholder = Self.clerkPublishableKey == "YOUR_KEY_HERE"
            || Self.clerkPublishableKey.contains("REPLACE_ME")
        print("🔑 [SadieMarieApp] Clerk configured. key prefix=\(keyPrefix)… placeholder=\(isPlaceholder)")
        AppLogger.authInfo("Clerk configured. key prefix=\(keyPrefix)…")
        #if DEBUG
        AdminFont.logRegistrationStatus()
        #endif

        // 2. Now that the shared instance exists, capture it into
        //    SwiftUI state and inject it into the environment below.
        //    Underscore-prefixed `_clerk` writes to the State storage
        //    directly — the only legal way to assign a `@State`
        //    property from inside `init()`.
        _clerk = State(initialValue: Clerk.shared)
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            AppRootContent()
                .preferredColorScheme(.dark)
                .environment(appState)
                .environment(clerk)
        }
    }
}

/// Top-level routing host. Strict gate on Clerk session state — no
/// transitions, no fallbacks. Either you have a Clerk session, or you
/// see `LoginView`.
private struct AppRootContent: View {
    @Environment(Clerk.self) private var clerk

    var body: some View {
        Group {
            if !clerk.isLoaded {
                SplashView()
            } else if clerk.user != nil, clerk.session != nil {
                RootTabView()
            } else {
                LoginView()
            }
        }
    }
}

/// Brief splash shown while Clerk hydrates its cached client and
/// environment on cold launch. Without this, signed-in users would
/// see `LoginView` flash for a frame before being kicked into the
/// app — an avoidable UX papercut.
private struct SplashView: View {
    var body: some View {
        ZStack {
            AdminTheme.cream.ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(AdminTheme.stone900)
        }
        .preferredColorScheme(.light)
    }
}
