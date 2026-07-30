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

/// User-tunable detection settings, persisted in UserDefaults on each device.
struct DetectionSettings: Codable, Equatable {
    /// Alert when heart rate sits this fraction above baseline (0.18 = 18%).
    var elevationFraction: Double = 0.18
    /// Elevation must be sustained this long before alerting.
    var sustainSeconds: TimeInterval = 180
    /// Step count above this in the last 5 minutes counts as "moving", which suppresses alerts.
    var sedentaryStepLimit: Int = 40
    /// Minimum quiet period between alerts.
    var cooldownSeconds: TimeInterval = 1200
    /// Added to your resting heart rate to form the baseline when no learned data exists.
    var baselineMarginBPM: Double = 12

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
