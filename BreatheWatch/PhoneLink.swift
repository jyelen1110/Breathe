import Foundation
import WatchConnectivity

/// Watch-side WatchConnectivity: pushes episodes to the iPhone for history/trends.
final class PhoneLink: NSObject, ObservableObject {
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func send(episode: StressEpisode) {
        guard let session else { return }
        // transferUserInfo queues delivery, surviving the phone being out of reach.
        session.transferUserInfo(["episode": episode.dictionaryRepresentation])
    }

    /// Pushes the latest schedule to the iPhone so both editors stay in sync.
    func send(schedule: MonitoringSchedule) {
        guard let session, session.activationState == .activated,
              let data = try? JSONEncoder().encode(schedule)
        else { return }
        try? session.updateApplicationContext(["schedule": data])
    }
}

extension PhoneLink: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["schedule"] as? Data,
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return }
        DispatchQueue.main.async {
            schedule.save()
            ScheduleManager.apply(schedule)
        }
    }
}
