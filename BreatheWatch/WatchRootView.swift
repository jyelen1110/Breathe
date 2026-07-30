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

                    NavigationLink("Breathe now") {
                        BreathingView()
                    }
                    NavigationLink("Settings") {
                        WatchSettingsView()
                    }
                }
            }
            .navigationTitle("Breathe")
            .sheet(isPresented: $showBreathing) {
                BreathingView()
            }
        }
        .onChange(of: workMode.pendingBreathingInvite) { _, invited in
            if invited { showBreathing = true }
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
            Text("Baseline \(Int(workMode.baselineHR)) bpm")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                Label(workMode.verdictDescription, systemImage: "waveform.path.ecg")
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
