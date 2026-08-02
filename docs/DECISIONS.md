# Decision & Lessons Log

Chronological record of choices made and failures survived. Read before re-deriving anything.

## Product decisions

| Date | Decision | Why |
|---|---|---|
| 2026-07-30 | Native watchOS app over Health-export webhook pipeline | User wants near-real-time; export pipelines have 5–15+ min latency. No Mac is NOT a blocker (CI builds). |
| 2026-07-30 | Public repo | Unlimited free macOS CI minutes; no secrets in code. |
| 2026-07-30 | TestFlight app record named **Breathe2Relieve** | "Breathe" taken on the App Store (ITMS-90129 also rejects it as CFBundleDisplayName — display name now matches). |
| 2026-07-31 | Thresholds personalized from his Health export | Generic defaults assumed resting ~65; his is ~52. (Note: that tuning targeted the now-abandoned sedentary model.) |
| 2026-07-31 | Schedule = reminder + one-tap start + automatic stop | watchOS forbids silently starting sensor sessions from background; one tap is the floor. Auto-stop needs no interaction. |
| 2026-08-01 | Breathing = haptic-paced (per-second taps, distinct pattern per phase) | Eyes-free use during work. watchOS has ~9 fixed haptic types; no custom waveforms. |
| 2026-08-02 | **Pivot: adrenaline-surge detection, calibration week first** | Sedentary-elevation model produced false alarms at calm moments; user is always moving; surge frequency/onset unknown → collect labeled data before building detector v2. |

## CI / signing lessons (each cost a failed run — do not retry these)

1. **App Manager API key fails cloud signing** ("Cloud signing permission error"). Use an
   **Admin** App Store Connect API key.
2. **Apple mandates iOS 26 SDK** for App Store Connect uploads (since ~April 2026) → build on
   `macos-26` runners (Xcode 26). `macos-15`/Xcode 16 uploads are rejected.
3. **App icons must have no alpha channel** — generate 24-bit RGB PNGs (System.Drawing:
   `Format24bppRgb`).
4. **Cloud signing mints a throwaway "Created via API" development cert every CI run** (the
   private key dies with the ephemeral runner). The account hits Apple's cert cap after ~a
   dozen runs. Fix: `ci/prune_dev_certs.py` revokes DEVELOPMENT certs named "Created via API"
   before each archive. Distribution/Expo certs untouched.
5. **Unsigned archives (`CODE_SIGNING_ALLOWED=NO`) fail export validation** — the watch app's
   `workout-processing` background mode requires the HealthKit entitlement *signed into* the
   bundle at archive time.
6. **Forcing `CODE_SIGN_IDENTITY="Apple Distribution"` with automatic signing fails**
   ("conflicting provisioning settings"). Working combo: automatic signing at archive (dev
   cert, pruned next run) + `app-store-connect`/`destination: upload` export.
7. **Runner Python is PEP-668 externally managed** — `pip3 install` fails; use a venv.
8. GitHub CLI OAuth tokens need the **workflow scope** to push `.github/workflows/` files
   (`gh auth refresh -s workflow`, device-code flow works from this machine).
9. XcodeGen handles the iOS-app-embeds-watch-app layout correctly from `project.yml`; the
   `.xcodeproj` is never committed.

## App/platform lessons

- **Health "Workouts" write permission off → workout session silently collects nothing**
  ("--" HR, nothing in Fitness/Health). Read permissions are NOT queryable (privacy), but
  share/write IS: `authorizationStatus(for: workoutType)`. App now refuses loudly and shows
  it in Diagnostics.
- **`updateApplicationContext` doesn't wake a closed SwiftUI watch app** — read
  `session.receivedApplicationContext` at activation to catch up, or phone-edited schedules
  never reach the watch's notification queue.
- HealthKit auth "isAuthorized" must be re-derived every launch (the original code only set
  it after tapping Connect → blank dashboard after every update).
- Apple Watch has **no EDA/glucose sensors**; SE 2 also lacks ECG/SpO2/wrist-temp. Glucose
  only via a CGM writing into HealthKit (delayed, needs the user to wear one).
