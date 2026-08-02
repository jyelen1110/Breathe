# Breathe (Breathe2Relieve) — Project Context

Apple Watch app that catches **adrenaline surges** during the user's workday and guides
breathing recovery. Built and shipped entirely **without a Mac** via GitHub Actions +
TestFlight. Read [docs/STATUS.md](docs/STATUS.md) first for where things stand.

## The user & their context (critical — shapes all design decisions)

- Jason (GitHub `jyelen1110`, Apple Developer account holder). Windows PC, **no Mac**.
- Apple Watch **SE 2nd gen** (watchOS 26): no wrist-temp, no ECG, no SpO2, no EDA sensor.
- Works **on his feet, constantly moving**, Tue–Sun roughly **11:30–15:45 AEST**.
  Desk-worker assumptions (sedentary gating) are WRONG for him — already learned the hard way.
- Goal: catch **acute adrenaline surges** (not slow-burn stress) early enough to control
  breathing. He cannot say how often they occur or how fast they onset — that's what the
  current calibration week measures.
- Physiology (from his Apple Health export, 2 months, work window): resting HR ~52 (athletic),
  sedentary median 68, ambulatory median ~74 / p95 ~90, HRV SDNN mean ~51 ms.

## Current phase: CALIBRATION WEEK (started 2026-08-02)

Stress alerts are **disabled**. During Work Mode the watch records everything and collects
ground-truth labels. See [docs/DATA-ANALYSIS.md](docs/DATA-ANALYSIS.md) for the file formats
and the analysis to run when he exports the data.

## Architecture

| Path | What it is |
|---|---|
| `Shared/` | Platform-neutral: models (episodes, schedule, summaries), DetectionEngine (currently bypassed), stores, HealthKit helpers |
| `BreatheWatch/` | watchOS app: WorkModeManager (HKWorkoutSession sensor loop + probe logic), CaptureLogger (CSV recorder), AlertCenter (notifications/haptics), ScheduleManager (reminders), BreathingView (haptic-paced box breathing), DiagnosticsView |
| `BreatheiOS/` | iPhone companion: Today dashboard, History, Schedule editor (syncs to watch), Data tab (capture export), Guide |
| `project.yml` | XcodeGen spec — `.xcodeproj` is generated in CI, never committed |
| `ci/` | ExportOptions.plist + prune_dev_certs.py (revokes stale CI certs pre-build) |
| `tools/` | analyze_health_export.py — streaming analyzer for Apple Health export.xml |
| `docs/` | SETUP (Apple/GitHub one-time), STATUS (current state), DECISIONS (log), DATA-ANALYSIS (calibration plan) |

Key runtime facts:
- Continuous HR (~5s) comes from an `HKWorkoutSession` (.mindAndBody) — **requires Health
  "Workouts" WRITE permission** or it silently collects nothing (now guarded loudly).
- Watch↔iPhone sync: episodes/summaries via `transferUserInfo`, schedule via
  `updateApplicationContext` (+ catch-up read of `receivedApplicationContext` at activation),
  capture CSVs via `transferFile` (replace-by-name on phone).
- All schedule times are device-local (AEST for Jason). Detection settings persist in
  UserDefaults per device (`DetectionSettings` defaults were tuned for the OLD sedentary
  model — do not trust them for the surge detector).

## Build & release (no Mac anywhere)

- Repo: https://github.com/jyelen1110/Breathe (public). `gh` CLI on this PC is authenticated
  as jyelen1110 (repo + workflow scopes).
- Every push: `build.yml` compile-checks on `macos-26` (Xcode 26 — Apple mandates iOS 26 SDK).
- Ship to TestFlight: `gh workflow run release.yml` then `gh run watch <id>`. ~3 min to upload,
  then 10–30 min Apple processing. App Store Connect app record: **Breathe2Relieve**,
  bundle `com.jyelen.breathe` (+ `.watchkitapp`).
- Secrets (already set in repo): APPLE_TEAM_ID, APPSTORE_KEY_ID, APPSTORE_ISSUER_ID,
  APPSTORE_P8 (Admin-role App Store Connect API key — App Manager is NOT enough for cloud signing).
- Signing gotchas (all learned by failure — don't re-derive): see [docs/DECISIONS.md](docs/DECISIONS.md).
  Summary: automatic cloud signing mints a throwaway dev cert per run → `ci/prune_dev_certs.py`
  revokes "Created via API" DEVELOPMENT certs before each archive (runs in a venv; runner
  Python is PEP-668 managed). Unsigned archives fail validation (watch background mode needs
  the signed HealthKit entitlement). Forcing "Apple Distribution" at archive conflicts with
  automatic signing. App icons must have NO alpha channel.

## Working agreements

- User-facing changes ship straight to TestFlight (`release.yml`); he updates via TestFlight
  (Health permissions survive updates).
- CI is the only compiler — expect an occasional compile-error round-trip; keep changes tight.
- Never handle his credentials; secrets go into GitHub's UI by him.
