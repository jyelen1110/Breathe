import Foundation
import UserNotifications

/// Watch-side scheduling: on the chosen weekdays a reminder notification fires
/// at the start time (one tap launches Work Mode — watchOS does not allow
/// starting the sensor session silently from the background), and a running
/// session stops itself automatically at the end time.
/// The MonitoringSchedule model itself lives in Shared/Models.swift.
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
