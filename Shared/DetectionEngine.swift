import Foundation

/// Pure detection logic: feed it heart-rate samples plus context, get a verdict back.
/// No HealthKit or UI dependencies so it is fully testable and shared across platforms.
final class DetectionEngine {

    enum Verdict: Equatable {
        /// Nothing notable.
        case calm
        /// Heart rate is elevated while sedentary, but not yet long enough to alert.
        case elevated(since: Date)
        /// Sustained sedentary elevation — fire the alert.
        case alert(StressSignal)
        /// Elevated but the user is moving, so it is treated as activity, not stress.
        case active
    }

    struct StressSignal: Equatable {
        let startedAt: Date
        let detectedAt: Date
        let averageHR: Double
        let baselineHR: Double
        let stepsLastFiveMinutes: Int
    }

    var settings: DetectionSettings

    private var recentSamples: [(date: Date, bpm: Double)] = []
    private var elevatedSince: Date?
    private var lastAlertAt: Date?

    /// Averaging window for smoothing raw sensor readings.
    private let smoothingWindow: TimeInterval = 60

    init(settings: DetectionSettings = DetectionSettings()) {
        self.settings = settings
    }

    func reset() {
        recentSamples.removeAll()
        elevatedSince = nil
    }

    func process(bpm: Double, at date: Date, baselineHR: Double, stepsLastFiveMinutes: Int) -> Verdict {
        recentSamples.append((date, bpm))
        recentSamples.removeAll { date.timeIntervalSince($0.date) > smoothingWindow }

        let smoothedHR = recentSamples.map(\.bpm).reduce(0, +) / Double(recentSamples.count)
        let threshold = baselineHR * (1 + settings.elevationFraction)

        guard smoothedHR >= threshold else {
            elevatedSince = nil
            return .calm
        }

        guard stepsLastFiveMinutes <= settings.sedentaryStepLimit else {
            // Elevated but moving: normal physical activity. Reset the clock so a
            // walk followed by a calm sit-down does not instantly alert.
            elevatedSince = nil
            return .active
        }

        let since = elevatedSince ?? date
        elevatedSince = since

        guard date.timeIntervalSince(since) >= settings.sustainSeconds else {
            return .elevated(since: since)
        }

        if let last = lastAlertAt, date.timeIntervalSince(last) < settings.cooldownSeconds {
            return .elevated(since: since)
        }

        lastAlertAt = date
        elevatedSince = nil
        return .alert(StressSignal(
            startedAt: since,
            detectedAt: date,
            averageHR: smoothedHR,
            baselineHR: baselineHR,
            stepsLastFiveMinutes: stepsLastFiveMinutes
        ))
    }
}
