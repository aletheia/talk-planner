import Foundation
import Observation
import WatchConnectivity

/// iPhone side of the sync. Pushes the full talk list to the watch via the
/// application context (latest-wins, delivered even when the watch app is closed)
/// and answers the watch's explicit requests when it is reachable.
@Observable
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    private(set) var isSupported = WCSession.isSupported()
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isReachable = false
    private(set) var lastSyncDate: Date?
    private(set) var lastError: String?

    /// Supplies the current talks when the watch asks for them.
    var talksProvider: (() -> [Talk])?

    private var pendingTalks: [Talk]?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ talks: [Talk]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingTalks = talks
            return
        }
        do {
            try session.updateApplicationContext(try SyncPayload.context(for: talks))
            lastSyncDate = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Manual re-send from the UI.
    func resend() {
        if let talks = talksProvider?() {
            send(talks)
        }
    }

    private func refresh(from session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.refresh(from: session)
            if let error {
                self.lastError = error.localizedDescription
            }
            if activationState == .activated, let pending = self.pendingTalks {
                self.pendingTalks = nil
                self.send(pending)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Happens when the user switches to a different watch. Re-activate for the new one.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refresh(from: session) }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refresh(from: session) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[SyncPayload.requestKey] as? String == SyncPayload.requestTalks else {
            replyHandler([:])
            return
        }
        DispatchQueue.main.async {
            let talks = self.talksProvider?() ?? []
            replyHandler((try? SyncPayload.context(for: talks)) ?? [:])
        }
    }
}
