# Breathe

An Apple Watch app that detects early signs of workday stress in near-real-time and nudges you to intervene before it builds.

> **Current phase (2026-08): calibration week.** Automatic stress alerts are disabled while
> the app records labeled data to build an adrenaline-surge detector suited to an
> on-your-feet workday. See [CLAUDE.md](CLAUDE.md), [docs/STATUS.md](docs/STATUS.md) and
> [docs/DATA-ANALYSIS.md](docs/DATA-ANALYSIS.md). The description below covers the general
> system; detection specifics are being redesigned from the calibration data.

## How it works

- **Work Mode** (on the Watch) runs a continuous sensor session that reads your heart rate every few seconds.
- Your **personal baseline** is your 7-day resting heart rate plus a configurable margin.
- If your smoothed heart rate stays above the baseline threshold for a sustained period **while you are sedentary** (step count filters out walking/stairs), the Watch fires an instant haptic alert with a one-tap **guided breathing exercise** (box breathing, haptic-paced).
- Episodes sync to the iPhone companion app so you can spot patterns — which hours and days stress you most.

All detection runs on-device. No servers, no accounts, and health data never leaves your devices.

## Project layout

| Path | Purpose |
|---|---|
| `Shared/` | Detection engine, models, episode store, HealthKit helpers (platform-neutral) |
| `BreatheWatch/` | watchOS app: sensor session, alerts, breathing UI, settings |
| `BreatheiOS/` | iPhone companion: dashboard, history, HealthKit onboarding |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec — the `.xcodeproj` is generated in CI, never committed |
| `.github/workflows/build.yml` | Compile check on every push (unsigned, simulator) |
| `.github/workflows/release.yml` | Manual trigger: archive, sign with cloud-managed signing, upload to TestFlight |
| `docs/SETUP.md` | One-time Apple/GitHub setup to enable TestFlight releases |

## Building without a Mac

This repo is designed to be developed entirely without local macOS: GitHub Actions macOS runners generate the Xcode project with XcodeGen, build it, sign it using an App Store Connect API key (cloud-managed signing), and upload straight to TestFlight. See [docs/SETUP.md](docs/SETUP.md).
