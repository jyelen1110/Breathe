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
        center.setNotificationCategories([category])
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
        NotificationCenter.default.post(
            name: .stressAlertAction,
            object: nil,
            userInfo: ["action": response.actionIdentifier]
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let stressAlertAction = Notification.Name("stressAlertAction")
}
