import SwiftUI

/// iPhone editor for the monitoring schedule. Changes save locally and sync to
/// the Watch, which owns the actual reminder notifications and auto-stop.
struct ScheduleView: View {
    @EnvironmentObject private var watchLink: WatchLink
    @State private var schedule = MonitoringSchedule.load()

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $schedule.enabled)
                } footer: {
                    Text("On your chosen days, your Watch taps you at the start time — one tap begins monitoring, and it stops by itself at the end time. Changes sync to your Watch automatically.")
                }

                if schedule.enabled {
                    Section("Monitoring window") {
                        Stepper(value: $schedule.startMinutes, in: 0...(23 * 60), step: 15) {
                            LabeledContent("Starts", value: schedule.startTimeText)
                        }
                        Stepper(value: $schedule.endMinutes, in: 15...(23 * 60 + 45), step: 15) {
                            LabeledContent("Auto-stops", value: schedule.endTimeText)
                        }
                    }
                    Section("Days") {
                        ForEach(1...7, id: \.self) { weekday in
                            Toggle(dayNames[weekday - 1], isOn: dayBinding(weekday))
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .onChange(of: schedule) { _, updated in
                var normalized = updated
                if normalized.endMinutes <= normalized.startMinutes {
                    normalized.endMinutes = min(normalized.startMinutes + 15, 23 * 60 + 45)
                }
                schedule = normalized
                normalized.save()
                watchLink.send(schedule: normalized)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scheduleSynced)) { _ in
                schedule = MonitoringSchedule.load()
            }
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
