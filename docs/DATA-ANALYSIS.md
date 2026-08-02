# Calibration Data — Formats & Analysis Plan

The playbook for turning the calibration week's CSVs into surge detector v2.

## Getting the data

Jason exports from the iPhone app's **Data** tab → share sheet → OneDrive. Ask him for the
folder/paths. Expect per-day files (dates in AEST):

## File formats (CSV, no header rows)

| File | Columns | Cadence |
|---|---|---|
| `hr-YYYY-MM-DD.csv` | `unix_ts,bpm` | ~every 5s during Work Mode |
| `steps-YYYY-MM-DD.csv` | `unix_ts,steps_last_5min` | every 30s during Work Mode |
| `events-YYYY-MM-DD.csv` | `unix_ts,type,bpm_at_event,steps_at_event` | on occurrence |

Event types: `session_start`, `session_stop`, `felt` (user pressed "I feel it" — **ground
truth positive**), `probe_sent` (heuristic fired), `probe_yes` / `probe_no` (user's answer
to a probe). Timestamps are unix seconds; convert with AEST in mind for time-of-day plots.

Notes: whole files re-transfer and replace by name, so no dedup needed. `felt` taps may lag
the true onset by ~30–90s — search backwards for the actual rise.

## Analysis recipe

1. **Load & join**: per day, align HR and steps series; mark labeled windows: ±5 min around
   each `felt` and `probe_yes` (positives), ±5 min around `probe_no` (hard negatives), and
   everything else as unlabeled background.
2. **Characterize positives**: for each, find the HR rise onset before the label — max rise
   rate (bpm/min), total delta above the preceding 10-min median, time-to-peak, recovery
   time, and the concurrent step-rate change. This answers onset speed + magnitude.
3. **Characterize the probe heuristic**: current rule = 30s-mean HR ≥ 12 bpm above the
   1–10-min-ago median AND 5-min steps increased ≤ 60 vs ~10 min ago, 20-min cooldown,
   max 12/day. Compute its precision from probe_yes/(probe_yes+probe_no) and check which
   `felt` events it would have caught (recall).
4. **Movement conditioning**: fit the HR-vs-steps relationship from background data (e.g.,
   median HR per steps-per-5-min band). Recompute positives as *residuals* above
   movement-expected HR — this is the candidate detector feature.
5. **Design detector v2**: pick a residual-rise threshold + window that separates positives
   from hard negatives with acceptable alert budget (ask Jason: how many alerts/shift is
   right?). Onset speed decides the window (seconds-fast → 30–60s window; minutes-slow →
   2–3 min).
6. **Sanity checks**: false-positive rate across full shifts, time-of-day clustering,
   day-of-week effects, and whether `felt` count is so low that more calibration time is
   needed before automating.

Python is available on this PC (3.13). Precedent: `tools/analyze_health_export.py` (the
streaming Apple-Health-export analyzer used for the original baseline work).

## Prior baselines (from his Apple Health export, for reference)

Work window Tue–Sun 11:30–15:45, 2 months to 2026-07-31: resting HR mean 52.3; sedentary
HR median 68 / p90 76 / p95 80 (only 301 samples); ambulatory/unknown-context HR median 74 /
p90 85 / p95 90 (1390 samples); HRV SDNN mean 50.7 ms (range 23–88).

## When shipping detector v2

- Alerts must be **invitations** (notification + haptic, tap to open breathing) — never
  auto-launch BreathingView (explicit user feedback).
- Keep the capture logging running — it powers ongoing tuning and the eventual weekly
  pattern report.
- Wire `resolveLastAlert(.falseAlarm)` / episode resolutions back in for continuous
  ground truth after automation resumes.
