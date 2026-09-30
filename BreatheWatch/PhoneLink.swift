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

    /// Ships the calibration CSVs to the iPhone — but only files that grew since
    /// their last confirmed delivery, and never ones already queued. The original
    /// resend-everything design flooded the WatchConnectivity queue once enough
    /// days accumulated (~Aug 22), silently stalling all transfers.
    private let deliveredKey = "deliveredCaptureBytes.v1"

    func sendCaptureFiles() {
        guard let session, session.activationState == .activated else { return }
        CaptureLogger.shared.flush()

        let delivered = (UserDefaults.standard.dictionary(forKey: deliveredKey) as? [String: Int]) ?? [:]
        let queued = Set(session.outstandingFileTransfers.map { $0.file.fileURL.lastPathComponent })

        for url in CaptureLogger.shared.allFiles {
            let name = url.lastPathComponent
            guard !queued.contains(name) else { continue }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int).flatMap { $0 } ?? 0
            if let sentBytes = delivered[name], sentBytes >= size, size > 0 { continue }
            session.transferFile(url, metadata: ["name": name, "size": size])
        }
    }

    private func markDelivered(name: String, size: Int) {
        var delivered = (UserDefaults.standard.dictionary(forKey: deliveredKey) as? [String: Int]) ?? [:]
        delivered[name] = max(delivered[name] ?? 0, size)
        UserDefaults.standard.set(delivered, forKey: deliveredKey)
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

        // Recover from the pre-fix flood: a massively backed-up transfer queue
        // never drains, so clear it and let sendCaptureFiles re-enqueue only
        // what's actually undelivered.
        if session.outstandingFileTransfers.count > 30 {
            session.outstandingFileTransfers.forEach { $0.cancel() }
        }
        DispatchQueue.main.async { [weak self] in
            self?.sendCaptureFiles()
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard error == nil else { return }
        let name = (fileTransfer.file.metadata?["name"] as? String) ?? fileTransfer.file.fileURL.lastPathComponent
        let size = (fileTransfer.file.metadata?["size"] as? Int) ?? 0
        markDelivered(name: name, size: size)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyScheduleIfPresent(in: applicationContext)
    }
}
