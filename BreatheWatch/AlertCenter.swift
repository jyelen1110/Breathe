import Foundation
import UserNotifications
import WatchKit

/// Local notifications + haptics for stress alerts on the Watch.
final class AlertCenter: NSObject {
    static let shared = AlertCenter()

    private let categoryIdentifier = "STRESS_ALERT"

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let breathe = UNNotificationAction(
            identifier: "BREATHE",
            title: "Breathe now",
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: "DISMISS",
            title: "I'm okay",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [breathe, dismiss],
            intentIdentifiers: []
        )

        let startWork = UNNotificationAction(
            identifier: ScheduleManager.startActionIdentifier,
            title: "Start Work Mode",
            options: [.foreground]
        )
        let workReminder = UNNotificationCategory(
            identifier: ScheduleManager.categoryIdentifier,
            actions: [startWork],
            intentIdentifiers: []
        )

        let probeYes = UNNotificationAction(identifier: "PROBE_YES", title: "Yes — feeling it", options: [])
        let probeNo = UNNotificationAction(identifier: "PROBE_NO", title: "No", options: [])
        let probe = UNNotificationCategory(
            identifier: "SURGE_PROBE",
            actions: [probeYes, probeNo],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category, workReminder, probe])
    }

    /// Calibration-week check-in: asks whether a surge is happening right now.
    func sendProbe(bpm: Int) {
        WKInterfaceDevice.current().play(.notification)

        let content = UNMutableNotificationContent()
        content.title = "Quick check"
        content.body = "Heart rate \(bpm) — are you feeling a surge right now?"
        content.categoryIdentifier = "SURGE_PROBE"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "probe-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyStress(episode: StressEpisode) {
        // Immediate haptic tap — the fastest possible signal, no notification latency.
        WKInterfaceDevice.current().play(.notification)

        let content = UNMutableNotificationContent()
        content.title = "Take a moment"
        content.body = "Heart rate \(Int(episode.averageHR)) bpm — about \(episode.elevationPercent)% above your baseline while sitting still. 90 seconds of slow breathing can reset this."
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: episode.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension AlertCenter: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        if category == ScheduleManager.categoryIdentifier {
            // Reminder tapped (either the action button or the notification body):
            // both open the app, so start monitoring right away.
            NotificationCenter.default.post(name: .workModeReminderTapped, object: nil)
        } else if category == "SURGE_PROBE" {
            if response.actionIdentifier == "PROBE_YES" || response.actionIdentifier == "PROBE_NO" {
                NotificationCenter.default.post(
                    name: .probeAnswered,
                    object: nil,
                    userInfo: ["feltIt": response.actionIdentifier == "PROBE_YES"]
                )
            }
        } else {
            NotificationCenter.default.post(
                name: .stressAlertAction,
                object: nil,
                userInfo: ["action": response.actionIdentifier]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let stressAlertAction = Notification.Name("stressAlertAction")
    static let workModeReminderTapped = Notification.Name("workModeReminderTapped")
    static let probeAnswered = Notification.Name("probeAnswered")
}
