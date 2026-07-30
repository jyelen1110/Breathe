import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var episodeStore: EpisodeStore

    private var groupedByDay: [(day: Date, episodes: [StressEpisode])] {
        let groups = Dictionary(grouping: episodeStore.episodes) {
            Calendar.current.startOfDay(for: $0.detectedAt)
        }
        return groups
            .map { (day: $0.key, episodes: $0.value.sorted { $0.detectedAt > $1.detectedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                if episodeStore.episodes.isEmpty {
                    Text("Episodes detected on your Watch will appear here, so you can spot patterns — times of day, days of the week — and get ahead of them.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(group.episodes) { episode in
                                EpisodeRow(episode: episode)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct EpisodeRow: View {
    let episode: StressEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(episode.detectedAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                resolutionBadge
            }
            Text("\(Int(episode.averageHR)) bpm — \(episode.elevationPercent)% above baseline (\(Int(episode.baselineHR)) bpm)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var resolutionBadge: some View {
        switch episode.resolution {
        case .breathingCompleted:
            Label("Breathed", systemImage: "wind")
                .font(.caption)
                .foregroundStyle(.teal)
        case .dismissed:
            Text("Dismissed")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .falseAlarm:
            Text("False alarm")
                .font(.caption)
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }
}
