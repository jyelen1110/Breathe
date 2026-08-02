import Foundation
import HealthKit
import CoreMotion
import Combine
import WatchKit

/// Runs the continuous monitoring session ("Work Mode"): an HKWorkoutSession that
/// streams heart rate every few seconds, combined with pedometer context, feeding
/// the shared DetectionEngine. Detection runs entirely on-watch so alerts are instant.
final class WorkModeManager: NSObject, ObservableObject {

    enum Status: Equatable {
        case idle
        case starting
        case running
        case ended(reason: String?)
    }

    @Published var status: Status = .idle
    @Published var currentHR: Double = 0
    @Published var baselineHR: Double = 72
    @Published var verdictDescription: String = "—"
    @Published var lastAlert: StressEpisode?
    @Published var recentSteps: Int = 0
    /// nil = unknown, true = Health data flowing, false = access missing or no data.
    @Published var healthConnected: Bool?
    /// Heart-rate readings received in the current session — live proof the sensor works.
    @Published var sampleCount = 0
    @Published var lastSampleAt: Date?
    /// Calibration-week counters shown on the watch home screen.
    @Published var feltToday = 0
    @Published var probesToday = 0

    private var sessionStartedAt: Date?
    private var hrHistory: [(date: Date, bpm: Double)] = []
    private var stepsHistory: [(date: Date, steps: Int)] = []
    private var lastProbeAt: Date?
    private var flushTimer: Timer?
    private var transferTimer: Timer?
    /// Set when a stress alert fires; the root view observes this to offer breathing.
    @Published var pendingBreathingInvite: Bool = false

    /// Injected by the App on launch.
    weak var episodeStore: EpisodeStore?
    weak var phoneLink: PhoneLink?

    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private var engine = DetectionEngine(settings: DetectionSettings.load())
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var stepTimer: Timer?
    private var autoStopTimer: Timer?

    /// Share/write status IS queryable (unlike read) — shown in Diagnostics.
    var workoutWriteDescription: String {
        switch healthStore.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingAuthorized: return "Allowed"
        case .sharingDenied: return "DENIED — enable in Health app"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    var settings: DetectionSettings {
        get { engine.settings }
        set {
            engine.settings = newValue
            newValue.save()
            refreshBaseline()
        }
    }

    // MARK: - Session lifecycle

    func start() {
        guard status == .idle || statusIsEnded else { return }
        status = .starting

        Task { @MainActor in
            do {
                try await HealthAccess.requestAuthorization(store: healthStore)
                // The continuous HR stream runs as a workout session, which requires
                // write access to Workouts. Without it, collection silently no-ops —
                // so refuse loudly instead.
                guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                    status = .ended(reason: "Turn on Workouts under 'write' for this app: iPhone Health app → profile → Apps & Services")
                    return
                }
                await refreshBaselineAsync()
                try startWorkoutSession()
                startStepPolling()
                scheduleAutoStopIfNeeded()
                sampleCount = 0
                lastSampleAt = nil
                sessionStartedAt = Date()
                status = .running
                CaptureLogger.shared.logEvent("session_start", bpm: 0, steps: recentSteps)
                flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    CaptureLogger.shared.flush()
                }
                transferTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
                    self?.phoneLink?.sendCaptureFiles()
                }
            } catch {
                status = .ended(reason: error.localizedDescription)
            }
        }
    }

    func stop() {
        CaptureLogger.shared.logEvent("session_stop", bpm: currentHR, steps: recentSteps)
        flushTimer?.invalidate()
        flushTimer = nil
        transferTimer?.invalidate()
        transferTimer = nil
        phoneLink?.sendCaptureFiles()
        if let started = sessionStartedAt {
            let summary = MonitoringSummary(
                id: UUID(),
                startedAt: started,
                endedAt: Date(),
                sampleCount: sampleCount
            )
            sessionStartedAt = nil
            phoneLink?.send(summary: summary)
        }
        session?.end()
        stepTimer?.invalidate()
        stepTimer = nil
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        engine.reset()
        status = .ended(reason: nil)
    }

    /// If a monitoring schedule is enabled and today is a scheduled day, end the
    /// session automatically at the window's end time. The workout session keeps
    /// the app alive in the background, so the timer fires reliably.
    private func scheduleAutoStopIfNeeded() {
        autoStopTimer?.invalidate()
        let schedule = MonitoringSchedule.load()
        guard schedule.enabled,
              schedule.isActiveDay(Date()),
              let end = schedule.endDate(onSameDayAs: Date()),
              end > Date()
        else { return }
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.stop() }
        }
    }

    private var statusIsEnded: Bool {
        if case .ended = status { return true }
        return false
    }

    private func startWorkoutSession() throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        session.delegate = self
        builder.delegate = self

        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                if !success {
                    self?.status = .ended(reason: error?.localizedDescription ?? "Sensor collection failed to start")
                }
            }
        }

        self.session = session
        self.builder = builder
    }

    // MARK: - Baseline

    func refreshBaseline() {
        Task { @MainActor in await refreshBaselineAsync() }
    }

    @MainActor
    private func refreshBaselineAsync() async {
        let status = await HealthAccess.authorizationRequestStatus(store: healthStore)
        guard status != .shouldRequest else {
            healthConnected = false
            return
        }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        if let resting = await HealthAccess.trailingAverage(
            store: healthStore, type: .restingHeartRate, unit: bpmUnit, days: 7
        ) {
            baselineHR = resting + engine.settings.baselineMarginBPM
            healthConnected = true
        } else {
            healthConnected = false
        }
    }

    // MARK: - Step context

    private func startStepPolling() {
        updateSteps()
        stepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateSteps()
        }
    }

    private func updateSteps() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        pedometer.queryPedometerData(from: fiveMinutesAgo, to: Date()) { [weak self] data, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let steps = data?.numberOfSteps.intValue ?? 0
                self.recentSteps = steps
                self.stepsHistory.append((Date(), steps))
                let cutoff = Date().addingTimeInterval(-1200)
                self.stepsHistory.removeAll { $0.date < cutoff }
                if self.status == .running {
                    CaptureLogger.shared.logSteps(steps)
                }
            }
        }
    }

    // MARK: - Detection

    // Calibration week: no stress alerts, no auto-breathing. Record everything,
    // and occasionally probe with a yes/no check-in when heart rate rises faster
    // than movement explains — the answers become labeled training data.
    private func handleHeartRate(bpm: Double) {
        DispatchQueue.main.async { [self] in
            currentHR = bpm
            sampleCount += 1
            lastSampleAt = Date()
            verdictDescription = "Recording"
            CaptureLogger.shared.logHR(bpm)
            hrHistory.append((Date(), bpm))
            let cutoff = Date().addingTimeInterval(-900)
            hrHistory.removeAll { $0.date < cutoff }
            evaluateProbe()
        }
    }

    private func evaluateProbe() {
        let now = Date()
        // Reference: median HR over the 1-10 minutes ago window (excludes the rise itself).
        let baselineSamples = hrHistory
            .filter { $0.date < now.addingTimeInterval(-60) && $0.date > now.addingTimeInterval(-600) }
            .map(\.bpm)
        guard baselineSamples.count >= 24 else { return }

        let recent = hrHistory.filter { $0.date >= now.addingTimeInterval(-30) }.map(\.bpm)
        guard !recent.isEmpty else { return }
        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let rise = recentMean - median(baselineSamples)

        // Movement excuse: if stepping picked up versus ~10 minutes ago, the rise
        // is probably physical, not adrenaline.
        guard let past = stepsHistory.last(where: { $0.date <= now.addingTimeInterval(-480) }) else { return }
        let movementIncrease = recentSteps - past.steps

        guard rise >= 12, movementIncrease <= 60 else { return }
        if let last = lastProbeAt, now.timeIntervalSince(last) < 1200 { return }
        guard probesToday < 12 else { return }

        lastProbeAt = now
        probesToday += 1
        CaptureLogger.shared.logEvent("probe_sent", bpm: recentMean, steps: recentSteps)
        AlertCenter.shared.sendProbe(bpm: Int(recentMean))
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// The user tapped "I feel it" — the strongest possible label.
    func recordFelt() {
        feltToday += 1
        CaptureLogger.shared.logEvent("felt", bpm: currentHR, steps: recentSteps)
        WKInterfaceDevice.current().play(.success)
    }

    /// The user answered a probe notification.
    func recordProbeAnswer(feltIt: Bool) {
        CaptureLogger.shared.logEvent(feltIt ? "probe_yes" : "probe_no", bpm: currentHR, steps: recentSteps)
    }

    func resolveLastAlert(_ resolution: StressEpisode.Resolution) {
        guard var episode = lastAlert else { return }
        episode.resolution = resolution
        lastAlert = episode
        episodeStore?.add(episode)
        phoneLink?.send(episode: episode)
        pendingBreathingInvite = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkModeManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        if toState == .ended {
            builder?.endCollection(withEnd: date) { [weak self] _, _ in
                self?.builder?.finishWorkout { _, _ in }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.status = .ended(reason: error.localizedDescription)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkModeManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity()
        else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        handleHeartRate(bpm: bpm)
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
