import Foundation
import UserNotifications

/// User-configured monitoring window: on chosen weekdays, a reminder notification
/// fires at the start time (one tap launches Work Mode — watchOS does not allow
/// starting the sensor session silently from the background), and a running
/// session stops itself automatically at the end time.
struct MonitoringSchedule: Codable, Equatable {
    var enabled = false
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday. Default Mon–Fri.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var startHour = 9
    var endHour = 17

    static let storageKey = "monitoringSchedule.v1"

    static func load(from defaults: UserDefaults = .standard) -> MonitoringSchedule {
        guard let data = defaults.data(forKey: storageKey),
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return MonitoringSchedule() }
        return schedule
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    func endDate(onSameDayAs date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: date)
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
            components.hour = schedule.startHour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Work Mode time"
            content.body = "Tap to start stress monitoring until \(schedule.endHour):00."
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
