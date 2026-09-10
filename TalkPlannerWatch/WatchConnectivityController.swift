import Foundation
import Observation
import WatchConnectivity

/// Watch side of the sync. Mirrors whatever the iPhone last published in the
/// application context, and asks the phone directly when it is reachable and
/// nothing has been received yet.
@Observable
final class WatchConnectivityController: NSObject, WCSessionDelegate {
    private(set) var isReachable = false
    private(set) var lastReceivedDate: Date?

    private let store: TalkStore

    init(store: TalkStore) {
        self.store = store
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Ask the phone for its current list. Silently no-ops when unreachable.
    func requestTalks() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SyncPayload.requestKey: SyncPayload.requestTalks], replyHandler: { [weak self] reply in
            self?.apply(reply)
        }, errorHandler: nil)
    }

    private func apply(_ context: [String: Any]) {
        guard let talks = SyncPayload.talks(from: context) else { return }
        DispatchQueue.main.async {
            self.store.replaceAll(talks)
            self.lastReceivedDate = (context[SyncPayload.updatedAtKey] as? Date) ?? .now
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        apply(session.receivedApplicationContext)
        if store.talks.isEmpty {
            requestTalks()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable && self.store.talks.isEmpty {
                self.requestTalks()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}
