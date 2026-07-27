# iOS app parity — implementation plan

**App:** `/Users/leonbuchmiller/Documents/Projects/Sadie Marie McKenna/SadieMarie`  
**Backend:** same admin APIs as `SadieMarie App` (`https://www.sadiemarie.co/api/admin`)  
**Goal:** Match web admin behavior for everything that belongs in the iOS admin app.

Awaiting your approval before any code changes.

---

## Scope

### In scope (this plan)

| # | Item | Priority |
|---|------|----------|
| 1 | Fix no-show charge (`charge_no_show: true`) | P0 |
| 2 | No-show “No charge” option | P0 |
| 3 | Manual booking: pick existing CRM client | P1 |
| 4 | Book from client profile | P1 |
| 5 | Email optional (manual booking + edit) | P1 |
| 6 | Reject `@sms.cal.com` in email validation | P1 |
| 7 | In-app reschedule + `POST …/reschedule` sync | P1 |
| 8 | Availability: archive past date overrides | P1 |
| 9 | Service color contrast on calendar pills | P1 |
| 10 | Strike count + consent status on profile | P2 |
| 11 | Surface `cal_cancel_error` on cancel | P2 |
| 12 | Show booking notes on appointment detail | P2 |
| 13 | Use `GET /api/admin/manual-booking/services` | P2 |
| 14 | Wire Settings into navigation | P2 |
| 15 | **Client photo upload (+ delete)** | P1 |

### Out of scope (unless you ask later)

- Public checkout / holds / Stripe Terminal  
- Re-implementing Twilio SMS in the app (server already sends)  
- Push notifications / widgets  
- Consent PDF template settings  
- Website marketing site changes  

**Dependency note:** Lifecycle SMS (admin cancel / no-show / reschedule / late fee) lives on the **website** server. Once that web work is committed/deployed, iOS gets those texts automatically by calling the same endpoints. Item 1 must be fixed or “Charge 50%” still won’t charge.

---

## Phase 0 — Prep (½ day)

1. Confirm iOS project builds (Debug + Clerk) against production/preview API.  
2. Skim current touchpoints (no new architecture):
   - `AppointmentDetailSheet.swift` — cancel / no-show  
   - `ClientDetails.swift` / `AdminAPIClient+Details.swift` — status PATCH body  
   - `ManualBookingWizardView.swift` / `ManualBookingClientFormView.swift`  
   - `ClientProfileView.swift` / `ClientGalleryView.swift`  
   - `ClientEmail.swift`, `AvailabilityView.swift`, `BookingDisplay.swift`  
3. Deploy / confirm web lifecycle SMS if not already on production (so cancel/no-show texts work end-to-end while testing iOS).

---

## Phase 1 — P0: No-show parity (½–1 day)

### 1–2. Charge vs no-charge no-show

**Problem:** UI says “Charge 50%” but PATCH body only sends `{ status: "no-show" }` → server treats as **no charge** + strike.

**Plan:**

1. Extend `AppointmentStatusPatchBody` with optional `charge_no_show: Bool`.  
2. Replace single no-show action with two:
   - **Charge 50% & mark no-show** → `{ status: "no-show", charge_no_show: true }`  
   - **Mark no-show (no charge)** → `{ status: "no-show", charge_no_show: false }`  
3. Keep “Charge” disabled when no vaulted card (same as today / web).  
4. On charge failure (402/400), show server `message`, leave appointment unchanged.  
5. On success, refresh booking list / detail.

**Files:** `AppointmentDetailSheet.swift`, status patch model, `AdminAPIClient+Details.swift`.

**Test:** Appointment with card → charge succeeds; without card → charge disabled; no-charge always works.

---

## Phase 2 — P1: Client identity & booking (1.5–2 days)

### 5–6. Email optional + `@sms.cal.com`

1. Update `ClientEmail` validation to reject `@sms.cal.com` (and keep existing `bookings+` / `@placeholder.sadiemarie.co` rules).  
2. Manual booking client form: email field optional; phone still required.  
3. Edit client sheet: allow empty email (PATCH `email: null`).  
4. Profile bootstrap: don’t require email when creating/locking a client by phone.

**Files:** `ClientEmail.swift`, `ManualBookingClientFormView.swift`, `EditClientSheet.swift`, related VMs.

### 3. Pick existing CRM client in manual booking

1. Add a “Select existing client” mode on the client step (search `GET /api/admin/clients/list` or reuse in-memory list if already loaded).  
2. On select: prefill name / phone / email; lock phone as identity (match web).  
3. Keep “Enter new client” path for walk-ins.

**Files:** `ManualBookingClientFormView.swift`, `ManualBookingViewModel.swift`, possibly new `ManualBookingClientPickerView.swift`.

### 4. Book from client profile

1. Add **Book appointment** on `ClientProfileView`.  
2. Present `ManualBookingWizardView` with `prefilledClient`.  
3. Skip / lock client step; go service → slots → create/complete.

**Files:** `ClientProfileView.swift`, `ManualBookingWizardView.swift`, `ManualBookingViewModel.swift`.

### 15. Client photo upload (+ delete)

**Backend already exists:**  
`POST /api/admin/clients/{id}/photos` (multipart file)  
`DELETE /api/admin/clients/{id}/photos` (JSON `{ photoId, blobUrl }`)  
`GET` already used by iOS.

**Plan:**

1. Add `AdminAPIClient.uploadClientPhoto(id:data:filename:mime:)` (multipart, same pattern as website image upload).  
2. Add `deleteClientPhoto(id:photoId:blobUrl:)`.  
3. Update `ClientGalleryView` / profile gallery section:
   - PhotosPicker (or camera + library)  
   - Upload progress / error  
   - Optional light compression before upload (reuse patterns from `WebsiteImageProcessing` if useful; server already does sRGB/resize)  
   - Delete with confirmation  
4. Refresh gallery after upload/delete.  
5. Replace “uploaded from the web admin” empty-state copy.

**Files:** `AdminAPIClient+Details.swift`, `ClientProfileViewModel.swift`, `ClientGalleryView.swift`, photo models.

**Test:** JPEG/HEIC from Photos; delete removes from UI; failures show clear errors.

---

## Phase 3 — P1: Reschedule, availability, calendar polish (1.5–2 days)

### 7. In-app reschedule + DB sync

1. Replace “open Cal in Safari only” with an in-app flow:
   - Prefer `SFSafariView` / WKWebView / Cal embed URL with `rescheduleUid` (mirror web where practical), **or** keep Safari but add a clear “I’ve finished rescheduling — Sync” that calls the API with the new UID/times if Cal deep-link returns them.  
   - Preferred: after Cal success, call existing unused `POST /api/admin/appointments/{id}/reschedule` with `newCalUid`, `newBookingTime`, `newEndTime`, `oldCalUid`.  
2. On success: dismiss, refresh bookings, show confirmation.  
3. Handle `same_slot` / `cal_uid_conflict` errors.

**Files:** `AppointmentDetailSheet.swift`, `AdminAPIClient+Details.swift`, possibly new `RescheduleBookingView.swift`.

**Note:** Exact Cal-on-iOS embed approach will be chosen after a quick spike (Safari callback vs embedded web). Plan assumes we sync via the existing admin reschedule API either way.

### 8. Archive past date overrides

1. Partition overrides: upcoming/active vs past (by date).  
2. Past section: collapsed/archived UI; dismiss/archive actions matching web behavior (call whatever availability PATCH shape web uses).  
3. Keep weekly hours editor unchanged.

**Files:** `AvailabilityView.swift`, `AvailabilityViewModel.swift`, `AvailabilityOverridesSection.swift`.

### 9. Service color contrast

1. Port web’s pastel → black text accents into `BookingDisplay` / `Color+Contrast` (wire existing unused helper).  
2. Apply on list cards + time-grid pills.

**Files:** `BookingDisplay.swift`, `Color+Contrast.swift`, card/grid views.

---

## Phase 4 — P2: Polish & parity (1 day)

| Item | Work |
|------|------|
| **10. Strikes + consent** | Decode `strike_count`, `has_consented`, `consent_form_url` if API returns them; show on CRM bar / profile. Link out to consent URL if present. |
| **11. `cal_cancel_error`** | Parse cancel response; toast/banner if Cal cancel failed but local status updated. |
| **12. Booking notes** | Show notes on appointment detail when API provides them. |
| **13. Manual-booking services** | Prefer `GET /api/admin/manual-booking/services` for Cal event-type mapping; fall back if needed. |
| **14. Settings** | Add Settings entry (profile menu or 6th tab / toolbar) using existing `SettingsView` (sign-out). |

---

## Suggested order of work

```
Phase 1  →  No-show charge / no-charge          (highest risk if wrong today)
Phase 2  →  Email + CRM picker + book-from-profile + photo upload
Phase 3  →  Reschedule sync + availability archive + contrast
Phase 4  →  Remaining P2 polish
```

Rough total: **~4–6 focused days** depending on how painful Cal reschedule-on-iOS is.

---

## Testing checklist (end-to-end)

- [ ] No-show charge hits Stripe; no-charge does not; UI matches result  
- [ ] Manual book with existing client + optional email  
- [ ] Book from profile skips client re-entry  
- [ ] Upload + delete client photo; gallery updates  
- [ ] Reschedule updates local calendar time/UID without waiting forever for webhook  
- [ ] Past overrides archived; calendar text readable on pastel services  
- [ ] Cancel / no-show / reschedule produce expected SMS when `sms_opt_in` is true (server-side)  
- [ ] Regression: list/calendar filters, cancel, services, website upload still work  

---

## What I need from you

1. **Approve this plan** (or cut/reorder items).  
2. Confirm photo upload should include **delete** (recommended: yes).  
3. Confirm email should be **fully optional** on iOS (matching web), including manual booking.  
4. Preference on reschedule UX if you have one:  
   - A) In-app browser + auto-sync when possible  
   - B) Keep Safari + explicit “Sync after reschedule”  
   - C) No preference — I’ll pick after a short spike  

Once you approve, I’ll start with **Phase 1 (no-show)**.
