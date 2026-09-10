import SwiftUI

/// Pure rendering of the session at a given instant.
struct RunningContent: View {
    let session: TalkSession
    let now: Date

    private var segmentRemaining: TimeInterval { session.segmentRemaining(at: now) }
    private var overallRemaining: TimeInterval { session.overallRemaining(at: now) }
    private var segmentOver: Bool { segmentRemaining <= 0 }
    private var overallOver: Bool { overallRemaining <= 0 }

    #if os(watchOS)
    private let isCompact = true
    #else
    private let isCompact = false
    #endif

    var body: some View {
        VStack(spacing: isCompact ? 2 : 16) {
            Text(session.currentSegment.title)
                .font(isCompact ? .headline : .title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)

            DualGaugeView(
                outerValue: session.overallRemainingFraction(at: now),
                innerValue: segmentOver ? 1 : session.segmentRemainingFraction(at: now),
                outerTint: overallTint,
                innerTint: segmentTint,
                lineWidth: isCompact ? 8 : 16,
                ringGap: isCompact ? 4 : 8
            ) {
                VStack(spacing: 0) {
                    Text(TimeFormat.clock(segmentRemaining))
                        .font(.system(size: isCompact ? 34 : 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(segmentOver ? .red : .primary)
                    Text(TimeFormat.clock(overallRemaining))
                        .font(.system(size: isCompact ? 13 : 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(overallOver ? .red : .secondary)
                }
            }
            .padding(.horizontal, isCompact ? 2 : 24)
            .frame(maxWidth: isCompact ? .infinity : 360)
            .frame(maxHeight: .infinity)

            footer
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, isCompact ? 4 : 16)
        .padding(.vertical, isCompact ? 0 : 8)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: isCompact ? .infinity : nil)
    }

    @ViewBuilder
    private var footer: some View {
        if segmentOver {
            Label(session.isLastSegment ? "Tap to finish" : "Tap for next", systemImage: "hand.tap.fill")
                .font(isCompact ? .footnote.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(.red)
        } else if let next = session.nextSegment {
            Text("Next: \(next.title)")
                .font(isCompact ? .caption2 : .body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("Last item")
                .font(isCompact ? .caption2 : .body)
                .foregroundStyle(.secondary)
        }
    }

    private var segmentTint: Color {
        if segmentOver { return .red }
        let fraction = session.segmentRemainingFraction(at: now)
        if fraction < 0.15 || segmentRemaining < 30 { return .orange }
        return .green
    }

    private var overallTint: Color {
        if overallOver { return .red }
        if session.overallRemainingFraction(at: now) < 0.1 { return .orange }
        return .blue
    }
}
