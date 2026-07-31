import Foundation
import UserNotifications

/// User-configured monitoring window: on chosen weekdays, a reminder notification
/// fires at the start time (one tap launches Work Mode — watchOS does not allow
/// starting the sensor session silently from the background), and a running
/// session stops itself automatically at the end time.
struct MonitoringSchedule: Codable, Equatable {
    var enabled = false
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday. Default Tue–Sun
    /// (the user's working days).
    var weekdays: Set<Int> = [1, 3, 4, 5, 6, 7]
    /// Window bounds in minutes since midnight, 15-minute granularity.
    var startMinutes = 11 * 60 + 30
    var endMinutes = 15 * 60 + 45

    var startTimeText: String { Self.timeText(startMinutes) }
    var endTimeText: String { Self.timeText(endMinutes) }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static let storageKey = "monitoringSchedule.v1"

    static func load(from defaults: UserDefaults = .standard) -> MonitoringSchedule {
        guard let data = defaults.data(forKey: storageKey),
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return MonitoringSchedule() }
        return schedule
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    func endDate(onSameDayAs date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: date)
    }
}

enum ScheduleManager {
    static let categoryIdentifier = "WORK_REMINDER"
    static let startActionIdentifier = "START_WORK"

    private static var reminderIdentifiers: [String] {
        (1...7).map { "workreminder-\($0)" }
    }

    /// Replaces all pending reminders with ones matching the given schedule.
    static func apply(_ schedule: MonitoringSchedule) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
        guard schedule.enabled else { return }

        for weekday in schedule.weekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = schedule.startMinutes / 60
            components.minute = schedule.startMinutes % 60

            let content = UNMutableNotificationContent()
            content.title = "Work Mode time"
            content.body = "Tap to start stress monitoring until \(schedule.endTimeText)."
            content.categoryIdentifier = categoryIdentifier
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(
                identifier: "workreminder-\(weekday)",
                content: content,
                trigger: trigger
            ))
        }
    }
}
