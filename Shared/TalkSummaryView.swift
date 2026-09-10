import SwiftUI

/// Shown once the talk is over: planned vs actual.
struct TalkSummaryView: View {
    let session: TalkSession
    let onDone: () -> Void

    /// Rounded to whole seconds once so elapsed, planned and the difference stay consistent.
    private var elapsed: TimeInterval { session.overallElapsed(at: session.endDate ?? .now).rounded(.up) }
    private var delta: TimeInterval { elapsed - session.talk.totalDuration }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: delta > 0 ? "clock.badge.exclamationmark" : "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(delta > 0 ? .orange : .green)
                Text("Talk Finished")
                    .font(.headline)
                VStack(spacing: 2) {
                    Text(TimeFormat.clock(elapsed))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Text("of \(TimeFormat.clock(session.talk.totalDuration)) planned")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(deltaText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(delta > 0 ? .orange : .green)
                }
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(session.talk.name)
    }

    private var deltaText: String {
        if abs(delta) < 1 { return "Right on time" }
        return delta > 0
            ? "\(TimeFormat.clock(delta)) over"
            : "\(TimeFormat.clock(-delta)) to spare"
    }
}
