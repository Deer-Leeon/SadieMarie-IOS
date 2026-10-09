import SwiftUI
import ClerkKit
import UIKit

/// Application entry point. Configures the Clerk SDK *first* — before
/// any SwiftUI state property reads `Clerk.shared` — and acts as the
/// bouncer for the rest of the UI:
///
/// - While Clerk hydrates (and, if signed in, Bookings first-loads) → brand splash.
/// - When `clerk.user == nil` → `LoginView` (signed-out shell).
/// - When `clerk.user != nil` → `RootTabView` (the 5 admin tabs).
@main
struct SadieMarieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Publishable key from Clerk Dashboard → Production → API Keys.
    /// Must match the same Production instance as `www.sadiemarie.co`
    /// (`CLERK_SECRET_KEY` on Vercel). Publishable keys are non-secret
    /// by design. The admin API base URL is production, so this app
    /// always uses `pk_live_…` (including TestFlight) — a `pk_test_…`
    /// session JWT will 401 against the live backend.
    private static let clerkPublishableKey = "pk_live_Y2xlcmsuc2FkaWVtYXJpZS5jbyQ"

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

        // Decode the splash mark during process launch so SwiftUI inherits
        // the same pixels the launch storyboard is already showing.
        _ = UIImage(named: "BrandLogo")
    }

    var body: some Scene {
        WindowGroup {
            AppRootContent()
                .preferredColorScheme(.light)
                .background(BrandSplashLayout.background.ignoresSafeArea())
                .environment(appState)
                .environment(PushRegistration.shared)
                .environment(clerk)
        }
    }
}

/// Top-level routing host. Brand splash stays mounted as an overlay until
/// Clerk is loaded and — when signed in — the Bookings calendar has painted.
private struct AppRootContent: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.scenePhase) private var scenePhase

    @State private var bookingsViewModel = BookingsViewModel()
    @State private var showSplash = true
    @State private var splashStartedAt = Date()
    @State private var didScheduleDismiss = false
    @State private var splashDeadlineReached = false

    private static let minimumSplashDuration: TimeInterval = 0.7
    /// Signed-in logo hold after Clerk is ready; covers a sleeping backend.
    private static let signedInSplashDeadline: TimeInterval = 8
    private static let revealAnimation = Animation.spring(response: 0.72, dampingFraction: 0.86)
    /// Grow the mark in place (image-view center = screen center).
    private static let dismissLogoScale: CGFloat = 1.18

    private var isSignedIn: Bool {
        clerk.user != nil && clerk.session != nil
    }

    private var signedInSplashTaskID: String {
        "\(clerk.isLoaded)-\(isSignedIn)"
    }

    private var isLaunchReady: Bool {
        guard clerk.isLoaded else { return false }
        if isSignedIn {
            return bookingsViewModel.hasLoaded || splashDeadlineReached
        }
        return true
    }

    var body: some View {
        ZStack {
            BrandSplashLayout.background.ignoresSafeArea()

            Group {
                if clerk.isLoaded {
                    if isSignedIn {
                        RootTabView(bookingsViewModel: bookingsViewModel)
                    } else {
                        LoginView()
                    }
                }
            }
            .allowsHitTesting(!showSplash)

            BrandSplashView(
                logoScale: showSplash ? 1 : Self.dismissLogoScale,
                opacity: showSplash ? 1 : 0
            )
            .ignoresSafeArea()
            .zIndex(1)
        }
        .background(LaunchWindowBackground())
        .onAppear { considerDismissingSplash() }
        .onChange(of: isLaunchReady) { _, _ in
            considerDismissingSplash()
        }
        .onChange(of: bookingsViewModel.hasLoaded) { _, _ in
            considerDismissingSplash()
        }
        .onChange(of: clerk.session?.id) { _, newId in
            guard newId != nil else { return }
            Task { await SessionKeepAlive.run() }
        }
        .onChange(of: isSignedIn) { _, signedIn in
            guard signedIn, !showSplash, !bookingsViewModel.hasLoaded else { return }
            showSplash = true
            didScheduleDismiss = false
            splashDeadlineReached = false
            splashStartedAt = Date().addingTimeInterval(-Self.minimumSplashDuration)
            considerDismissingSplash()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                SessionKeepAlive.scheduleBackgroundRefresh()
            }
            guard phase == .active else { return }
            Task {
                await SessionKeepAlive.run()
            if clerk.user != nil {
                PushRegistration.shared.requestLiveDataRefresh()
            }
            }
        }
        .task {
            await SessionKeepAlive.run()
        }
        .task(id: signedInSplashTaskID) {
            guard clerk.isLoaded, isSignedIn, showSplash else { return }
            splashDeadlineReached = false
            try? await Task.sleep(for: .seconds(Self.signedInSplashDeadline))
            guard !Task.isCancelled, showSplash else { return }
            splashDeadlineReached = true
            considerDismissingSplash()
        }
    }

    private func considerDismissingSplash() {
        guard showSplash, isLaunchReady, !didScheduleDismiss else { return }
        didScheduleDismiss = true
        let remaining = max(0, Self.minimumSplashDuration - Date().timeIntervalSince(splashStartedAt))
        Task {
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            await MainActor.run {
                withAnimation(Self.revealAnimation) {
                    showSplash = false
                }
            }
        }
    }
}

/// Paints the UIWindow the same cream as the launch storyboard. The system
/// window defaults to white, which showed around the logo for one frame.
private struct LaunchWindowBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let cream = BrandSplashLayout.uiBackground
        uiView.window?.backgroundColor = cream
        uiView.superview?.backgroundColor = cream
    }
}
