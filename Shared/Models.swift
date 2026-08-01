import Foundation

/// A detected stress episode, created on the Watch and mirrored to the iPhone.
struct StressEpisode: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var detectedAt: Date
    var averageHR: Double
    var baselineHR: Double
    var stepsLastFiveMinutes: Int
    /// How the episode ended, if the user responded to it.
    var resolution: Resolution?

    enum Resolution: String, Codable {
        case breathingCompleted
        case dismissed
        case falseAlarm
    }

    var elevationPercent: Int {
        guard baselineHR > 0 else { return 0 }
        return Int(((averageHR / baselineHR) - 1) * 100)
    }

    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "detectedAt": detectedAt.timeIntervalSince1970,
            "averageHR": averageHR,
            "baselineHR": baselineHR,
            "steps": stepsLastFiveMinutes,
        ]
        if let resolution { dict["resolution"] = resolution.rawValue }
        return dict
    }

    static func from(dictionary dict: [String: Any]) -> StressEpisode? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let started = dict["startedAt"] as? TimeInterval,
              let detected = dict["detectedAt"] as? TimeInterval,
              let avg = dict["averageHR"] as? Double,
              let baseline = dict["baselineHR"] as? Double
        else { return nil }
        return StressEpisode(
            id: id,
            startedAt: Date(timeIntervalSince1970: started),
            detectedAt: Date(timeIntervalSince1970: detected),
            averageHR: avg,
            baselineHR: baseline,
            stepsLastFiveMinutes: dict["steps"] as? Int ?? 0,
            resolution: (dict["resolution"] as? String).flatMap(Resolution.init(rawValue:))
        )
    }
}

/// One completed Work Mode session, recorded on the Watch and mirrored to the
/// iPhone so the app can show proof of what it monitored.
struct MonitoringSummary: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var sampleCount: Int

    var dictionaryRepresentation: [String: Any] {
        [
            "id": id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "samples": sampleCount,
        ]
    }

    static func from(dictionary dict: [String: Any]) -> MonitoringSummary? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let started = dict["startedAt"] as? TimeInterval,
              let ended = dict["endedAt"] as? TimeInterval
        else { return nil }
        return MonitoringSummary(
            id: id,
            startedAt: Date(timeIntervalSince1970: started),
            endedAt: Date(timeIntervalSince1970: ended),
            sampleCount: dict["samples"] as? Int ?? 0
        )
    }
}

/// User-configured monitoring window, shared between iPhone (editing UI) and
/// Watch (reminder notifications + auto-stop). Synced via WatchConnectivity
/// application context; each device also persists its own copy.
struct MonitoringSchedule: Codable, Equatable {
    var enabled = false
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday. Default Tue–Sun
    /// (the user's working days).
    var weekdays: Set<Int> = [1, 3, 4, 5, 6, 7]
    /// Window bounds in minutes since midnight, 15-minute granularity.
    var startMinutes = 11 * 60 + 30
    var endMinutes = 15 * 60 + 45

    var startTimeText: String { Self.timeText(startMinutes) }
    var endTimeText: String { Self.timeText(endMinutes) }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static let storageKey = "monitoringSchedule.v1"

    static func load(from defaults: UserDefaults = .standard) -> MonitoringSchedule {
        guard let data = defaults.data(forKey: storageKey),
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return MonitoringSchedule() }
        return schedule
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    func endDate(onSameDayAs date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: date)
    }
}

/// User-tunable detection settings, persisted in UserDefaults on each device.
struct DetectionSettings: Codable, Equatable {
    /// Alert when heart rate sits this fraction above baseline (0.16 = 16%).
    /// Tuned from the user's Health export: sedentary median 68 bpm, p95 80 bpm
    /// in the monitored window, so threshold ≈ 79 bpm.
    var elevationFraction: Double = 0.16
    /// Elevation must be sustained this long before alerting.
    var sustainSeconds: TimeInterval = 180
    /// Step count above this in the last 5 minutes counts as "moving", which suppresses alerts.
    var sedentaryStepLimit: Int = 40
    /// Minimum quiet period between alerts.
    var cooldownSeconds: TimeInterval = 1200
    /// Added to your resting heart rate to form the baseline when no learned data exists.
    /// Tuned so resting (~52 bpm) + margin lands on the user's sedentary median (~68 bpm).
    var baselineMarginBPM: Double = 16

    static let storageKey = "detectionSettings.v1"

    static func load(from defaults: UserDefaults = .standard) -> DetectionSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(DetectionSettings.self, from: data)
        else { return DetectionSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
