import SwiftUI

struct TalkDetailView: View {
    @Environment(TalkStore.self) private var store
    @Environment(PhoneConnectivity.self) private var connectivity
    let talkID: UUID

    @State private var editingTalk = false
    @State private var editingSegment: TalkSegment?
    @State private var addingSegment = false

    private var talk: Talk? { store.talk(id: talkID) }

    private var startFooter: String {
        connectivity.isPaired && connectivity.isWatchAppInstalled
            ? "Start from your Apple Watch, or here to run it on the phone with iPhone haptics."
            : "No Apple Watch found: run the talk here and the iPhone vibrates when an item ends."
    }

    var body: some View {
        if let talk {
            List {
                Section {
                    BudgetSummary(talk: talk)
                    NavigationLink {
                        RunningTalkView(talk: talk)
                    } label: {
                        Label("Start on iPhone", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .foregroundStyle(Color.accentColor)
                } footer: {
                    Text(startFooter)
                }

                Section("Notes") {
                    NavigationLink {
                        TalkNotesView(talkID: talk.id)
                    } label: {
                        HStack {
                            Label(talk.hasNotes ? "Speaker notes" : "Add notes or script", systemImage: "doc.text")
                            Spacer()
                            if talk.hasNotes {
                                Text("^[\(wordCount(talk.notes)) word](inflect: true)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    if talk.segments.isEmpty {
                        Text("No agenda items. The whole talk runs as a single \(TimeFormat.compact(talk.totalDuration)) segment.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(talk.segments.enumerated()), id: \.element.id) { index, segment in
                        Button {
                            editingSegment = segment
                        } label: {
                            SegmentRow(index: index + 1, segment: segment)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        var updated = talk
                        updated.segments.remove(atOffsets: offsets)
                        store.update(updated)
                    }
                    .onMove { source, destination in
                        var updated = talk
                        updated.segments.move(fromOffsets: source, toOffset: destination)
                        store.update(updated)
                    }
                    Button("Add Item", systemImage: "plus.circle.fill") {
                        addingSegment = true
                    }
                } header: {
                    Text("Agenda")
                } footer: {
                    Text("Tap an item to edit it. Drag to reorder with Edit.")
                }
            }
            .navigationTitle(talk.name.isEmpty ? "Untitled Talk" : talk.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit Talk") { editingTalk = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $editingTalk) {
                TalkEditorSheet(talk: talk) { store.update($0) }
            }
            .sheet(item: $editingSegment) { segment in
                SegmentEditorSheet(segment: segment, suggestedDuration: segment.duration) { updated in
                    var t = talk
                    if let i = t.segments.firstIndex(where: { $0.id == updated.id }) {
                        t.segments[i] = updated
                        store.update(t)
                    }
                } onDelete: {
                    var t = talk
                    t.segments.removeAll { $0.id == segment.id }
                    store.update(t)
                }
            }
            .sheet(isPresented: $addingSegment) {
                SegmentEditorSheet(segment: nil, suggestedDuration: suggestedDuration(for: talk)) { new in
                    var t = talk
                    t.segments.append(new)
                    store.update(t)
                }
            }
        } else {
            ContentUnavailableView("Talk Deleted", systemImage: "trash")
        }
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Default a new item to the remaining budget, capped at 5 minutes.
    private func suggestedDuration(for talk: Talk) -> TimeInterval {
        let remaining = talk.unallocatedDuration
        if remaining <= 0 { return 5 * 60 }
        return min(remaining, 5 * 60)
    }
}

private struct BudgetSummary: View {
    let talk: Talk

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(TimeFormat.compact(talk.totalDuration))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                Text("total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("^[\(talk.segments.count) item](inflect: true)")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, talk.allocatedDuration / max(1, talk.totalDuration)))
                .tint(talk.isOverAllocated ? .red : .accentColor)
            HStack {
                Text("\(TimeFormat.compact(talk.allocatedDuration)) planned")
                Spacer()
                if talk.isOverAllocated {
                    Label("\(TimeFormat.compact(-talk.unallocatedDuration)) over", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text("\(TimeFormat.compact(talk.unallocatedDuration)) free")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SegmentRow: View {
    let index: Int
    let segment: TalkSegment

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(segment.title.isEmpty ? "Untitled" : segment.title)
                .lineLimit(2)
            Spacer()
            Text(TimeFormat.clock(segment.duration))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
