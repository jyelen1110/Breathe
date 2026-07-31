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
                    Stepper(value: $schedule.startMinutes, in: 0...(23 * 60), step: 15) {
                        Text("Starts \(schedule.startTimeText)")
                            .font(.footnote)
                    }
                    Stepper(value: $schedule.endMinutes, in: 15...(23 * 60 + 45), step: 15) {
                        Text("Auto-stops \(schedule.endTimeText)")
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
            if normalized.endMinutes <= normalized.startMinutes {
                normalized.endMinutes = min(normalized.startMinutes + 15, 23 * 60 + 45)
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
