import Foundation
import Combine

/// Simple persistent store for stress episodes, backed by UserDefaults.
/// Each device (Watch, iPhone) keeps its own copy; the Watch pushes new
/// episodes to the iPhone over WatchConnectivity.
final class EpisodeStore: ObservableObject {
    @Published private(set) var episodes: [StressEpisode] = []

    private let storageKey = "stressEpisodes.v1"
    private let maxStored = 500
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ episode: StressEpisode) {
        // Upsert so a resolution update from the Watch replaces the original entry.
        episodes.removeAll { $0.id == episode.id }
        episodes.append(episode)
        episodes.sort { $0.detectedAt > $1.detectedAt }
        if episodes.count > maxStored {
            episodes = Array(episodes.prefix(maxStored))
        }
        persist()
    }

    func updateResolution(id: UUID, resolution: StressEpisode.Resolution) {
        guard let index = episodes.firstIndex(where: { $0.id == id }) else { return }
        episodes[index].resolution = resolution
        persist()
    }

    func episodes(onSameDayAs date: Date, calendar: Calendar = .current) -> [StressEpisode] {
        episodes.filter { calendar.isDate($0.detectedAt, inSameDayAs: date) }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StressEpisode].self, from: data)
        else { return }
        episodes = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(episodes) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
