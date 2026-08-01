import SwiftUI
import UserNotifications

/// Self-check screen: shows whether reminders are actually queued, whether
/// notifications are permitted, and whether heart-rate readings are arriving —
/// so problems are visible instead of guessed at.
struct DiagnosticsView: View {
    @EnvironmentObject private var workMode: WorkModeManager

    @State private var notificationStatus = "Checking…"
    @State private var nextReminders: [Date] = []
    @State private var schedule = MonitoringSchedule.load()

    var body: some View {
        Form {
            Section("Reminders") {
                row("Notifications", notificationStatus)
                row("Queued", "\(nextReminders.count)")
                if let next = nextReminders.first {
                    row("Next fires", next.formatted(date: .abbreviated, time: .shortened))
                }
                if schedule.enabled {
                    row("Window", "\(schedule.startTimeText)–\(schedule.endTimeText)")
                } else {
                    Text("Schedule is off")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("Sensor session") {
                row("Status", statusText)
                row("Readings", "\(workMode.sampleCount)")
                if let last = workMode.lastSampleAt {
                    row("Last reading", last.formatted(date: .omitted, time: .standard))
                }
                row("Current HR", workMode.currentHR > 0 ? "\(Int(workMode.currentHR)) bpm" : "--")
                row("Baseline", "\(Int(workMode.baselineHR)) bpm")
                row("Health", healthText)
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear(perform: refresh)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }

    private var statusText: String {
        switch workMode.status {
        case .idle: return "Off"
        case .starting: return "Starting"
        case .running: return "Running"
        case .ended(let reason): return reason ?? "Ended"
        }
    }

    private var healthText: String {
        switch workMode.healthConnected {
        case .some(true): return "Connected"
        case .some(false): return "Not connected"
        case nil: return "Unknown"
        }
    }

    private func refresh() {
        schedule = MonitoringSchedule.load()
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized, .provisional: text = "Allowed"
            case .denied: text = "DENIED — enable in settings"
            case .notDetermined: text = "Not asked yet"
            @unknown default: text = "Unknown"
            }
            DispatchQueue.main.async { notificationStatus = text }
        }
        center.getPendingNotificationRequests { requests in
            let dates = requests
                .filter { $0.identifier.hasPrefix("workreminder-") }
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .sorted()
            DispatchQueue.main.async { nextReminders = dates }
        }
    }
}
