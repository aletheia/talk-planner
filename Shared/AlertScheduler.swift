import Foundation
import UserNotifications
#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

/// Plays the in-app haptics (wrist on the watch, Taptic Engine on the iPhone) and
/// schedules a local notification as a fallback so the device still buzzes if the
/// app is suspended when a segment runs out.
final class AlertScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertScheduler()

    private let segmentIdentifier = "conf-timer.segment-end"
    private let overallIdentifier = "conf-timer.talk-end"
    private var authorizationRequested = false

    #if os(iOS)
    private let notificationHaptic = UINotificationFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .light)
    #endif

    func installDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Haptics

    /// Warm up the Taptic Engine so the first buzz is not delayed (iOS only).
    func prepare() {
        #if os(iOS)
        notificationHaptic.prepare()
        impactHaptic.prepare()
        #endif
    }

    /// Gentle nudge: the current item is out of time, tap to move on.
    func playSegmentEnd() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
        #elseif os(iOS)
        notificationHaptic.notificationOccurred(.warning)
        #endif
    }

    /// Stronger cue: the whole talk budget is spent.
    func playOverallEnd() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #elseif os(iOS)
        notificationHaptic.notificationOccurred(.error)
        #endif
    }

    func playAdvance() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif os(iOS)
        impactHaptic.impactOccurred()
        #endif
    }

    func playFinished() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #elseif os(iOS)
        notificationHaptic.notificationOccurred(.success)
        #endif
    }

    // MARK: - Background fallback

    func reschedule(for session: TalkSession, now: Date = .now) {
        cancelAll()
        guard session.phase == .running else { return }

        if let end = session.currentSegmentEndDate, end > now {
            let content = UNMutableNotificationContent()
            content.title = "Time for \(session.currentSegment.title) is up"
            if let next = session.nextSegment {
                content.body = "Next: \(next.title) (\(TimeFormat.compact(next.duration)))"
            } else {
                content.body = "Last item. Tap to finish the talk."
            }
            content.sound = .default
            schedule(id: segmentIdentifier, content: content, at: end, now: now)
        }

        if let end = session.overallEndDate, end > now {
            let content = UNMutableNotificationContent()
            content.title = "\(session.talk.name) is out of time"
            content.body = "The \(TimeFormat.compact(session.talk.totalDuration)) budget is spent."
            content.sound = .default
            schedule(id: overallIdentifier, content: content, at: end, now: now)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [segmentIdentifier, overallIdentifier])
    }

    private func schedule(id: String, content: UNNotificationContent, at date: Date, now: Date) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSince(now)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// While the app is on screen it already plays its own haptic, so suppress the banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}
