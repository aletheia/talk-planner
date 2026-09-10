import Foundation
import Observation

/// The running state of a talk. All timing is derived from wall-clock dates,
/// so the session stays correct if the UI stops ticking (wrist down, app suspended).
@Observable
final class TalkSession {
    enum Phase: Equatable {
        case ready
        case running
        case finished
    }

    let talk: Talk
    let segments: [TalkSegment]

    private(set) var phase: Phase = .ready
    private(set) var startDate: Date?
    private(set) var endDate: Date?
    private(set) var segmentIndex: Int = 0
    private(set) var segmentStartDate: Date?

    /// True once the end-of-segment alert has been played for the current segment.
    var segmentAlertFired = false
    /// True once the end-of-talk alert has been played.
    var overallAlertFired = false

    init(talk: Talk) {
        self.talk = talk
        self.segments = talk.runnableSegments
    }

    // MARK: - Navigation

    var currentSegment: TalkSegment {
        segments[min(segmentIndex, segments.count - 1)]
    }

    var nextSegment: TalkSegment? {
        let next = segmentIndex + 1
        return next < segments.count ? segments[next] : nil
    }

    var isLastSegment: Bool {
        segmentIndex >= segments.count - 1
    }

    func start(at date: Date = .now) {
        guard phase == .ready else { return }
        startDate = date
        segmentStartDate = date
        phase = .running
    }

    /// Moves to the next segment, or finishes the talk if this was the last one.
    func advance(at date: Date = .now) {
        guard phase == .running else { return }
        if isLastSegment {
            finish(at: date)
        } else {
            segmentIndex += 1
            segmentStartDate = date
            segmentAlertFired = false
        }
    }

    func finish(at date: Date = .now) {
        guard phase == .running else { return }
        endDate = date
        phase = .finished
    }

    // MARK: - Segment timing

    func segmentElapsed(at date: Date) -> TimeInterval {
        guard let segmentStartDate else { return 0 }
        return max(0, date.timeIntervalSince(segmentStartDate))
    }

    /// Negative when the segment is in overtime.
    func segmentRemaining(at date: Date) -> TimeInterval {
        currentSegment.duration - segmentElapsed(at: date)
    }

    /// Fraction of the current segment still available, 0...1.
    func segmentRemainingFraction(at date: Date) -> Double {
        let duration = currentSegment.duration
        guard duration > 0 else { return 0 }
        return min(1, max(0, segmentRemaining(at: date) / duration))
    }

    func isSegmentOver(at date: Date) -> Bool {
        segmentRemaining(at: date) <= 0
    }

    /// When the current segment's allotted time runs out.
    var currentSegmentEndDate: Date? {
        segmentStartDate.map { $0.addingTimeInterval(currentSegment.duration) }
    }

    // MARK: - Overall timing

    func overallElapsed(at date: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        let reference = endDate ?? date
        return max(0, reference.timeIntervalSince(startDate))
    }

    /// Negative when the talk is in overtime.
    func overallRemaining(at date: Date) -> TimeInterval {
        talk.totalDuration - overallElapsed(at: date)
    }

    /// Fraction of the whole talk still available, 0...1.
    func overallRemainingFraction(at date: Date) -> Double {
        guard talk.totalDuration > 0 else { return 0 }
        return min(1, max(0, overallRemaining(at: date) / talk.totalDuration))
    }

    func isOverallOver(at date: Date) -> Bool {
        overallRemaining(at: date) <= 0
    }

    var overallEndDate: Date? {
        startDate.map { $0.addingTimeInterval(talk.totalDuration) }
    }
}
