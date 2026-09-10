import SwiftUI

/// Create or edit a single agenda item.
struct SegmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let original: TalkSegment?
    private let onSave: (TalkSegment) -> Void
    private let onDelete: (() -> Void)?

    @State private var title: String
    @State private var duration: TimeInterval
    @FocusState private var titleFocused: Bool

    init(segment: TalkSegment?, suggestedDuration: TimeInterval, onSave: @escaping (TalkSegment) -> Void, onDelete: (() -> Void)? = nil) {
        self.original = segment
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: segment?.title ?? "")
        _duration = State(initialValue: segment?.duration ?? suggestedDuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("What will you cover?", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                }
                Section("Time") {
                    DurationPicker(duration: $duration, components: [.minutes, .seconds])
                }
                if original != nil, let onDelete {
                    Section {
                        Button("Delete Item", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(original == nil ? "Add" : "Save") {
                        var segment = original ?? TalkSegment(title: "", duration: 0)
                        segment.title = title.trimmingCharacters(in: .whitespaces)
                        segment.duration = duration
                        onSave(segment)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || duration <= 0)
                }
            }
            .onAppear { if original == nil { titleFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }
}
