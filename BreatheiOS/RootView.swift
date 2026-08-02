import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }
            CaptureView()
                .tabItem { Label("Data", systemImage: "tray.and.arrow.down") }
            GuideView()
                .tabItem { Label("Guide", systemImage: "book") }
        }
        .tint(.teal)
    }
}

struct TodayView: View {
    @EnvironmentObject private var health: HealthDashboardModel
    @EnvironmentObject private var episodeStore: EpisodeStore
    @EnvironmentObject private var summaryStore: SummaryStore

    private var todayEpisodes: [StressEpisode] {
        episodeStore.episodes(onSameDayAs: Date())
    }

    private var todaySummaries: [MonitoringSummary] {
        summaryStore.summaries(onSameDayAs: Date())
    }

    private var todayMonitoredText: String {
        let seconds = todaySummaries.reduce(0.0) { $0 + $1.endedAt.timeIntervalSince($1.startedAt) }
        let readings = todaySummaries.reduce(0) { $0 + $1.sampleCount }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m monitored · \(readings) readings"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    connectionStatusRow
                    if health.connection == .notConnected {
                        Button {
                            Task { await health.requestAuthorization() }
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart.text.square")
                        }
                    }
                }

                Section("Your signals") {
                    metricRow(
                        "Resting heart rate",
                        value: health.restingHR.map { "\(Int($0)) bpm" },
                        symbol: "heart.fill", color: .red
                    )
                    metricRow(
                        "Baseline (alert reference)",
                        value: health.baselineEstimate.map { "\(Int($0)) bpm" },
                        symbol: "gauge.with.needle", color: .teal
                    )
                    metricRow(
                        "HRV (SDNN)",
                        value: health.hrvSDNN.map { "\(Int($0)) ms" },
                        symbol: "waveform.path.ecg", color: .purple
                    )
                    metricRow(
                        "Respiratory rate",
                        value: health.respiratoryRate.map { String(format: "%.1f /min", $0) },
                        symbol: "lungs.fill", color: .blue
                    )
                }

                Section("Today") {
                    if todaySummaries.isEmpty {
                        Text("No monitoring sessions recorded today. Summaries arrive from the Watch when a Work Mode session ends.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(todayMonitoredText, systemImage: "waveform.path.ecg")
                            .font(.subheadline)
                            .foregroundStyle(.teal)
                    }
                    if todayEpisodes.isEmpty {
                        Text("No stress episodes detected today.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todayEpisodes) { episode in
                            EpisodeRow(episode: episode)
                        }
                    }
                }
            }
            .navigationTitle("Breathe")
            .refreshable { await health.evaluateConnection() }
            .task { await health.evaluateConnection() }
        }
    }

    private var connectionStatusRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
            Spacer()
        }
    }

    private var statusColor: Color {
        switch health.connection {
        case .checking: return .gray
        case .connected: return .green
        case .connectedNoData: return .orange
        case .notConnected: return .red
        }
    }

    private var statusText: String {
        switch health.connection {
        case .checking: return "Checking Apple Health…"
        case .connected: return "Apple Health connected"
        case .connectedNoData: return "Connected, but no data — check permissions in the Health app"
        case .notConnected: return "Apple Health not connected"
        }
    }

    private func metricRow(_ title: String, value: String?, symbol: String, color: Color) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .foregroundStyle(color)
                .font(.subheadline)
            Spacer()
            Text(value ?? "--")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

struct GuideView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("How detection works") {
                    Text("Start Work Mode on your Watch during busy periods. It measures your heart rate every few seconds and compares it with your personal baseline (7-day resting heart rate plus a margin). If it stays elevated while you're sitting still, you get a haptic tap and a suggestion to breathe — usually within a few minutes of the stress beginning.")
                }
                Section("Why the steps matter") {
                    Text("A raised heart rate from walking or stairs is normal. Breathe only alerts when your heart rate is high and you've barely moved — the signature of mental stress, not exercise.")
                }
                Section("Tuning") {
                    Text("If you get too many alerts, raise the threshold or the sustain time in the Watch settings. Too few, lower them. Give the baseline a week or two of data before judging accuracy.")
                }
                Section("Battery") {
                    Text("Work Mode uses the workout sensor, which costs battery — expect a noticeably faster drain than normal wear. Start it for your working blocks rather than the whole day, and charge nightly.")
                }
            }
            .navigationTitle("Guide")
        }
    }
}
