# Sadie Marie — iOS Admin

Native iOS admin app for [Sadie Marie](https://www.sadiemarie.co): bookings, clients, availability, services, and website content.

This repository is **only** the iOS app. It was split out of a mixed workspace that also contained the Period Tracker app and marketing site.

## Requirements

- Xcode 16+ (iOS 17 deployment target)
- Apple Developer team configured for signing
- Clerk publishable key (see `SadieMarie/SadieMarieApp.swift` or `SadieMarie/Config/Secrets.xcconfig.template`)

## Open & run

1. Open `SadieMarie.xcodeproj`
2. Select the **SadieMarie** scheme
3. Build and run on a device or simulator

## Project layout

| Path | Purpose |
|------|---------|
| `SadieMarie/` | App source, fonts, assets |
| `SadieMarieTests/` | Unit tests |
| `SadieMarie.xcodeproj/` | Xcode project (Clerk + HorizonCalendar via SPM) |

**Not included** (legacy Period Tracker): `PartnerWidgets`, `NotificationService`, cycle-tracking UI, and the old `PeriodTracker` module name.

## API

The app talks to `https://www.sadiemarie.co/api/admin/*` using Clerk session tokens via `AdminAPIClient`.

## Scripts

- `scripts/clean_xcode_project.py` — utility used when generating this repo (removes widget extension targets)
- `scripts/quality_gates.sh` — CI-style build + test (if configured for this project path)
