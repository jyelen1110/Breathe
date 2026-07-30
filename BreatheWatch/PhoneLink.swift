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
}

extension PhoneLink: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
