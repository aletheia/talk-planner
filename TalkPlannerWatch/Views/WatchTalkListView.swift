import SwiftUI

struct WatchTalkListView: View {
    @Environment(TalkStore.self) private var store
    @Environment(WatchConnectivityController.self) private var connectivity

    var body: some View {
        Group {
            if store.talks.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Talks")
                            .font(.headline)
                        Text("Create talks in Talk Planner on your iPhone. They appear here automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Refresh") { connectivity.requestTalks() }
                            .padding(.top, 4)
                    }
                }
            } else {
                List(store.talks) { talk in
                    NavigationLink(value: talk) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(talk.name)
                                .font(.headline)
                                .lineLimit(2)
                            Text("\(TimeFormat.compact(talk.totalDuration)) · ^[\(talk.segments.count) item](inflect: true)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Talks")
        .navigationDestination(for: Talk.self) { talk in
            WatchTalkDetailView(talk: talk)
        }
    }
}
