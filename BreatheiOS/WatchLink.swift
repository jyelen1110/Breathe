import Foundation
import WatchConnectivity

/// iPhone-side WatchConnectivity: receives episodes pushed from the Watch.
final class WatchLink: NSObject, ObservableObject {
    weak var episodeStore: EpisodeStore?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Pushes the latest schedule to the Watch, which applies its reminders.
    func send(schedule: MonitoringSchedule) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(schedule)
        else { return }
        try? session.updateApplicationContext(["schedule": data])
    }
}

extension WatchLink: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payload = userInfo["episode"] as? [String: Any],
              let episode = StressEpisode.from(dictionary: payload)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.episodeStore?.add(episode)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["schedule"] as? Data,
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return }
        DispatchQueue.main.async {
            schedule.save()
            NotificationCenter.default.post(name: .scheduleSynced, object: nil)
        }
    }
}

extension Notification.Name {
    static let scheduleSynced = Notification.Name("scheduleSynced")
}
