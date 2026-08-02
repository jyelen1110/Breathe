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

    /// Mirrors a completed session summary to the iPhone.
    func send(summary: MonitoringSummary) {
        guard let session else { return }
        session.transferUserInfo(["summary": summary.dictionaryRepresentation])
    }

    /// Ships the calibration CSVs to the iPhone. Whole files transfer each time
    /// and replace by name on the phone, so repeated sends are harmless.
    func sendCaptureFiles() {
        guard let session, session.activationState == .activated else { return }
        CaptureLogger.shared.flush()
        for url in CaptureLogger.shared.allFiles {
            session.transferFile(url, metadata: ["name": url.lastPathComponent])
        }
    }

    private func applyScheduleIfPresent(in context: [String: Any]) {
        guard let data = context["schedule"] as? Data,
              let schedule = try? JSONDecoder().decode(MonitoringSchedule.self, from: data)
        else { return }
        DispatchQueue.main.async {
            schedule.save()
            ScheduleManager.apply(schedule)
        }
    }
}

extension PhoneLink: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Catch up on a schedule the phone sent while this app was closed —
        // the live delegate callback only fires for changes made while running.
        applyScheduleIfPresent(in: session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyScheduleIfPresent(in: applicationContext)
    }
}
