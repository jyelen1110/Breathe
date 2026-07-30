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
}
