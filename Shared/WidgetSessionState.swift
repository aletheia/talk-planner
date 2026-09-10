import Foundation
#if canImport(WidgetKit) && os(iOS)
import WidgetKit
#endif

/// Snapshot of a running talk that the iOS widget can render on its own.
/// Everything is expressed as dates so WidgetKit's live timers and progress
/// views can animate without the app being awake.
struct WidgetSessionState: Codable, Equatable {
    var talkName: String
    var segmentTitle: String
    var nextSegmentTitle: String?
    var segmentIndex: Int
    var segmentCount: Int
    var startDate: Date
    var totalDuration: TimeInterval
    var segmentStartDate: Date
    var segmentDuration: TimeInterval

    var overallEndDate: Date { startDate.addingTimeInterval(max(1, totalDuration)) }
    var segmentEndDate: Date { segmentStartDate.addingTimeInterval(max(1, segmentDuration)) }

    /// Closed ranges for `ProgressView(timerInterval:)`; always non-empty.
    var overallInterval: ClosedRange<Date> { startDate...max(overallEndDate, startDate.addingTimeInterval(1)) }
    var segmentInterval: ClosedRange<Date> { segmentStartDate...max(segmentEndDate, segmentStartDate.addingTimeInterval(1)) }

    /// A finished-long-ago session should not keep the widget stuck on stale data.
    func isStale(at date: Date) -> Bool {
        date > overallEndDate.addingTimeInterval(3 * 3600)
    }

    static let preview = WidgetSessionState(
        talkName: "Scaling SwiftUI Apps",
        segmentTitle: "State management",
        nextSegmentTitle: "Performance",
        segmentIndex: 1,
        segmentCount: 4,
        startDate: Date().addingTimeInterval(-7 * 60),
        totalDuration: 30 * 60,
        segmentStartDate: Date().addingTimeInterval(-4 * 60),
        segmentDuration: 10 * 60
    )
}

extension WidgetSessionState {
    /// Nil unless the session is actually running.
    init?(session: TalkSession) {
        guard session.phase == .running,
              let startDate = session.startDate,
              let segmentStartDate = session.segmentStartDate else { return nil }
        self.init(
            talkName: session.talk.name,
            segmentTitle: session.currentSegment.title,
            nextSegmentTitle: session.nextSegment?.title,
            segmentIndex: session.segmentIndex,
            segmentCount: session.segments.count,
            startDate: startDate,
            totalDuration: session.talk.totalDuration,
            segmentStartDate: segmentStartDate,
            segmentDuration: session.currentSegment.duration
        )
    }
}

/// Hands the running session to the widget through the shared App Group container.
enum WidgetSessionStore {
    static let appGroupIdentifier = "group.com.lucabianchi.TalkPlanner"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("widget-session.json")
    }

    static func load(at date: Date = .now) -> WidgetSessionState? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(WidgetSessionState.self, from: data) else { return nil }
        return state.isStale(at: date) ? nil : state
    }

    /// Writes the session if it is running, clears the widget otherwise, then asks
    /// WidgetKit to rebuild its timeline.
    static func publish(_ session: TalkSession) {
        save(WidgetSessionState(session: session))
    }

    static func save(_ state: WidgetSessionState?) {
        guard let fileURL else { return }
        if let state {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(state) {
                try? data.write(to: fileURL, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: fileURL)
        }
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
