import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject private var workMode: WorkModeManager
    @State private var settings = DetectionSettings.load()
    @State private var schedule = MonitoringSchedule.load()

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        Form {
            Section("Schedule") {
                Toggle("Daily reminder", isOn: $schedule.enabled)
                if schedule.enabled {
                    Stepper(value: $schedule.startHour, in: 0...22) {
                        Text("Starts \(schedule.startHour):00")
                            .font(.footnote)
                    }
                    Stepper(value: $schedule.endHour, in: 1...23) {
                        Text("Auto-stops \(schedule.endHour):00")
                            .font(.footnote)
                    }
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(dayNames[weekday - 1], isOn: dayBinding(weekday))
                            .font(.footnote)
                    }
                }
            }
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
        .onChange(of: schedule) { _, updated in
            var normalized = updated
            if normalized.endHour <= normalized.startHour {
                normalized.endHour = min(normalized.startHour + 1, 23)
            }
            schedule = normalized
            normalized.save()
            ScheduleManager.apply(normalized)
        }
    }

    private func dayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { schedule.weekdays.contains(weekday) },
            set: { include in
                if include {
                    schedule.weekdays.insert(weekday)
                } else {
                    schedule.weekdays.remove(weekday)
                }
            }
        )
    }
}
