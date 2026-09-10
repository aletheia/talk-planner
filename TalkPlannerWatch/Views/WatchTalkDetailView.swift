import SwiftUI

/// Preview of the agenda with the Start button.
struct WatchTalkDetailView: View {
    let talk: Talk

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    RunningTalkView(talk: talk)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack {
                    Label(TimeFormat.compact(talk.totalDuration), systemImage: "clock")
                    Spacer()
                    Text("^[\(talk.segments.count) item](inflect: true)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if talk.isOverAllocated {
                    Label("Agenda exceeds the total time", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(talk.runnableSegments.enumerated()), id: \.element.id) { index, segment in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(segment.title)
                                .lineLimit(2)
                            Spacer(minLength: 4)
                            Text(TimeFormat.clock(segment.duration))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .navigationTitle(talk.name)
    }
}
