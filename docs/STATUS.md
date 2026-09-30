# Status — as of 2026-09-30

## Where the project is

**Calibration is still running — and mostly recovered from two bugs.** Jason has kept
using Work Mode through late September (probes fired as recently as Sep 29), but the
exportable data stopped at Aug 22 because the watch→phone file transfer flooded its own
queue (resend-everything design). Fixed 2026-09-30 (PR #1, TestFlight build uploaded):
delivery-tracked transfers, flood recovery on activation, probe cap made per-session
(was accidentally per-app-lifetime, which silenced probes Aug 7–22), and Diagnostics
now shows files-on-watch / pending-transfer counts.

**Immediate next step:** after Jason updates and opens both apps, the ~6-week backlog
(late Aug–Sep, including his recent probe Yes/No answers) should drain to the phone's
Data tab → he re-exports → run the full analysis (see DATA-ANALYSIS.md).

**Findings from the Aug 4–22 data already analyzed** (10 shifts, ~4.2h & ~3k HR readings
each; export was at `H:\My Drive\Untitled folder`):
- Daily median working HR varies 72–87 bpm; peaks 97–124.
- Probe heuristic (+12 bpm unexplained rise) is too twitchy: 7/7 answered probes = "No",
  fired on sub-minute bumps to 85–99 bpm that self-settle.
- Only 2 "felt" taps: one looks like a button test; the Aug 11 one had a completely FLAT
  HR (66–72, below that day's median) — first evidence his felt surges may not show in
  heart rate. Jason reports recent probes (late Sep) DID coincide with feeling it — his
  recent Yes/No answers are the first real positives, trapped in the backlog until export.

## Original calibration design (2026-08-02 build)

## What works, verified end-to-end

- Full no-Mac pipeline: push → CI compile check; `gh workflow run release.yml` → signed
  TestFlight upload (self-healing cert pruning included).
- Work Mode: continuous HR every ~5s + steps every 30s (required the Health **Workouts
  write** permission — was off, now on, confirmed working).
- Scheduled reminder Tue–Sun 11:30 with one-tap start; auto-stop 15:45; two-way schedule
  editing (phone Schedule tab ↔ watch Settings).
- Haptic-paced box breathing (3-click start cue; per-second taps: rising=in, click=hold,
  falling=out; 6 cycles ≈ 96s).
- Health connection status dots (phone + watch), watch Diagnostics screen (notification
  permission, queued reminders, readings counter, workout-write status), session summaries
  on the phone Today tab ("Xh Ym monitored · N readings").

## The pivot (most important context)

The first detector alerted on *sustained HR elevation while sedentary* — a desk-stress
model. Two field facts broke it: (1) Jason wants to catch **adrenaline surges** (sharp,
fast events), and (2) he is **always moving** at work, so "sedentary + elevated" fired at
his calmest moments (lulls after walking) — false positives, zero true catches.

## Calibration week mechanics (current build)

During Work Mode:
- Everything logged to per-day CSVs on the watch, synced to the phone (Data tab).
- **"I feel it"** orange button on watch home = ground-truth surge label (the key data).
- **Probe check-ins**: when HR rises ≥12 bpm above its own 10-min median without a matching
  step increase → notification "are you feeling a surge? Yes/No" (max 12/day, 20-min cooldown).
  Both answers are recorded.

## Next session's job

1. Jason exports files from the phone's **Data** tab to OneDrive (after ~4–5 shifts).
2. Run the analysis in [DATA-ANALYSIS.md](DATA-ANALYSIS.md) on those CSVs.
3. Design the movement-conditioned surge detector from his labeled events; re-enable alerts
   (as invitations, never auto-launching breathing); ship.

## Open questions the data should answer

- How often do surges actually occur? (He doesn't know.)
- Onset speed: seconds or minutes?
- How well does the probe heuristic (+12 bpm unexplained) match his felt surges — too
  sensitive, too blunt, or usably close?
- Do surges differ from movement spikes clearly enough for HR-only detection? (No EDA
  sensor on Apple Watch — HR dynamics + movement context is the ceiling.)

## Watch-outs

- If he reports missing 11:30 reminders: watch Diagnostics → Reminders section shows queued
  count & notification permission.
- If HR shows "--" during Work Mode: Diagnostics → "Workout write" row (the app now also
  refuses to start with instructions if that permission is off).
- Battery report for full 11:30–15:45 sessions: not yet collected — ask.
