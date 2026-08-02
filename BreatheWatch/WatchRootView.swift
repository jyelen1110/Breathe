import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var workMode: WorkModeManager
    @State private var showBreathing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    heartRateHeader
                    statusLine
                    workModeButton

                    if workMode.status == .running {
                        Button {
                            workMode.recordFelt()
                        } label: {
                            Label("I feel it", systemImage: "bolt.fill")
                        }
                        .tint(.orange)
                        Text("\(workMode.feltToday) logged today")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("Breathe now") {
                        BreathingView()
                    }
                    NavigationLink("Settings") {
                        WatchSettingsView()
                    }
                    NavigationLink("Diagnostics") {
                        DiagnosticsView()
                    }
                }
            }
            .navigationTitle("Breathe")
            .sheet(isPresented: $showBreathing) {
                BreathingView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workModeReminderTapped)) { _ in
            workMode.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .probeAnswered)) { note in
            guard let feltIt = note.userInfo?["feltIt"] as? Bool else { return }
            workMode.recordProbeAnswer(feltIt: feltIt)
        }
        .onReceive(NotificationCenter.default.publisher(for: .stressAlertAction)) { note in
            guard let action = note.userInfo?["action"] as? String else { return }
            if action == "BREATHE" {
                showBreathing = true
            } else if action == "DISMISS" {
                workMode.resolveLastAlert(.dismissed)
            }
        }
        .onAppear {
            workMode.refreshBaseline()
        }
    }

    private var heartRateHeader: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text(workMode.currentHR > 0 ? "\(Int(workMode.currentHR))" : "--")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                Text("bpm")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(healthDotColor)
                    .frame(width: 6, height: 6)
                Text("Baseline \(Int(workMode.baselineHR)) bpm")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var healthDotColor: Color {
        switch workMode.healthConnected {
        case .some(true): return .green
        case .some(false): return .orange
        case nil: return .gray
        }
    }

    private var statusLine: some View {
        Group {
            switch workMode.status {
            case .idle:
                Text("Work Mode is off")
                    .foregroundStyle(.secondary)
            case .starting:
                Text("Starting sensors…")
                    .foregroundStyle(.secondary)
            case .running:
                Label("Recording · \(workMode.sampleCount) readings", systemImage: "waveform.path.ecg")
                    .foregroundStyle(.teal)
            case .ended(let reason):
                Text(reason ?? "Session ended")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }

    private var workModeButton: some View {
        Group {
            if workMode.status == .running || workMode.status == .starting {
                Button("Stop Work Mode", role: .destructive) {
                    workMode.stop()
                }
            } else {
                Button {
                    workMode.start()
                } label: {
                    Label("Start Work Mode", systemImage: "play.fill")
                }
                .tint(.teal)
            }
        }
    }
}
