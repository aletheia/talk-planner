import SwiftUI

struct TalkListView: View {
    @Environment(TalkStore.self) private var store
    @State private var showingNewTalk = false

    var body: some View {
        NavigationStack {
            Group {
                if store.talks.isEmpty {
                    ContentUnavailableView {
                        Label("No Talks Yet", systemImage: "timer")
                    } description: {
                        Text("Create a talk with a name and a total time, then break it into agenda items. Start it from your Apple Watch.")
                    } actions: {
                        Button("New Talk") { showingNewTalk = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.talks) { talk in
                                NavigationLink(value: talk.id) {
                                    TalkRow(talk: talk)
                                }
                            }
                            .onDelete { store.delete(at: $0) }
                            .onMove { store.move(from: $0, to: $1) }
                        }
                        Section {
                            WatchSyncStatusView()
                        }
                    }
                }
            }
            .navigationTitle("Talks")
            .navigationDestination(for: UUID.self) { id in
                TalkDetailView(talkID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.talks.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Talk", systemImage: "plus") { showingNewTalk = true }
                }
            }
            .sheet(isPresented: $showingNewTalk) {
                TalkEditorSheet(talk: nil) { store.add($0) }
            }
        }
    }
}

private struct TalkRow: View {
    let talk: Talk

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(talk.name.isEmpty ? "Untitled Talk" : talk.name)
                .font(.headline)
            HStack(spacing: 6) {
                Label(TimeFormat.compact(talk.totalDuration), systemImage: "clock")
                Text("·")
                Text("^[\(talk.segments.count) item](inflect: true)")
                if talk.isOverAllocated {
                    Text("·")
                    Label("Over budget", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}

struct WatchSyncStatusView: View {
    @Environment(PhoneConnectivity.self) private var connectivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundStyle(statusColor)
                Text(statusText)
                Spacer()
                Button("Send Now") { connectivity.resend() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!connectivity.isSupported)
            }
            if let date = connectivity.lastSyncDate {
                Text("Last sent \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if connectivity.isPaired, let error = connectivity.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline)
    }

    private var statusText: String {
        if !connectivity.isSupported { return "Watch sync not available on this device" }
        if !connectivity.isPaired { return "No Apple Watch paired. Talks run on this iPhone." }
        if !connectivity.isWatchAppInstalled { return "Install Talk Planner on your watch" }
        return connectivity.isReachable ? "Watch connected" : "Watch app installed, syncs in background"
    }

    private var statusColor: Color {
        if !connectivity.isSupported || !connectivity.isPaired { return .secondary }
        if !connectivity.isWatchAppInstalled { return .orange }
        return connectivity.isReachable ? .green : .blue
    }
}
