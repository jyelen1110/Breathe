import Foundation
import Combine

/// Persistent store for completed monitoring sessions, mirroring EpisodeStore.
final class SummaryStore: ObservableObject {
    @Published private(set) var summaries: [MonitoringSummary] = []

    private let storageKey = "monitoringSummaries.v1"
    private let maxStored = 200
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ summary: MonitoringSummary) {
        summaries.removeAll { $0.id == summary.id }
        summaries.append(summary)
        summaries.sort { $0.startedAt > $1.startedAt }
        if summaries.count > maxStored {
            summaries = Array(summaries.prefix(maxStored))
        }
        persist()
    }

    func summaries(onSameDayAs date: Date, calendar: Calendar = .current) -> [MonitoringSummary] {
        summaries.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MonitoringSummary].self, from: data)
        else { return }
        summaries = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(summaries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
