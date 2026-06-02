# Config

## Local secrets setup

1. Copy `Secrets.xcconfig.template` to `Secrets.xcconfig`.
2. (Currently no per-environment values to fill in.)
3. Keep `Secrets.xcconfig` local only (it is gitignored).

## Clerk publishable key

The Clerk publishable key lives directly in `SadieMarieApp.swift` as a
private static constant (`clerkPublishableKey`). Publishable keys are
non-secret by design — Clerk publishes them to web/mobile clients and
authentication relies on short-lived session JWTs, not the key itself —
so hardcoding is appropriate.

If you ever need to switch keys per environment (dev vs. App Store),
turn `clerkPublishableKey` into a value derived from a `#if DEBUG` /
xcconfig-injected build setting.

## Admin API (no extra iOS secrets)

The app calls `https://www.sadiemarie.co/api/admin/…` with
`Authorization: Bearer <Clerk session JWT>`. You do **not** put a
separate “admin API key” in the iOS app.

What must be true on the **Next.js / Vercel** side:

1. Route `app/api/admin/appointments/route.ts` is deployed.
2. It verifies the Clerk JWT (same Clerk instance as the app’s
   `pk_test_…` / `pk_live_…` key).
3. Your signed-in user has admin access (e.g. `publicMetadata.role === "admin"`).

If bookings fail with **401**, sign in again or fix Clerk/admin metadata.
If they fail with **404**, the URL or route is wrong (not a missing API key).
