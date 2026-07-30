import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject private var workMode: WorkModeManager
    @State private var settings = DetectionSettings.load()

    var body: some View {
        Form {
            Section("Alert threshold") {
                Stepper(value: $settings.elevationFraction, in: 0.10...0.40, step: 0.02) {
                    Text("+\(Int(settings.elevationFraction * 100))% over baseline")
                        .font(.footnote)
                }
                Stepper(value: $settings.sustainSeconds, in: 60...600, step: 60) {
                    Text("Sustained \(Int(settings.sustainSeconds / 60)) min")
                        .font(.footnote)
                }
            }
            Section("Quiet period") {
                Stepper(value: $settings.cooldownSeconds, in: 300...3600, step: 300) {
                    Text("\(Int(settings.cooldownSeconds / 60)) min between alerts")
                        .font(.footnote)
                }
            }
            Section {
                Text("Baseline = your 7-day resting heart rate + \(Int(settings.baselineMarginBPM)) bpm. It personalises as the Watch gathers data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onChange(of: settings) { _, updated in
            workMode.settings = updated
        }
    }
}
