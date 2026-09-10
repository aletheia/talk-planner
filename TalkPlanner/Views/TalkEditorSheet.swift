import SwiftUI

/// Create or edit a talk's name and total time budget.
struct TalkEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Talk?
    private let onSave: (Talk) -> Void

    @State private var name: String
    @State private var totalDuration: TimeInterval
    @FocusState private var nameFocused: Bool

    init(talk: Talk?, onSave: @escaping (Talk) -> Void) {
        self.original = talk
        self.onSave = onSave
        _name = State(initialValue: talk?.name ?? "")
        _totalDuration = State(initialValue: talk?.totalDuration ?? 30 * 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Talk") {
                    TextField("Name", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                Section("Total Time") {
                    DurationPicker(duration: $totalDuration, components: [.hours, .minutes])
                }
            }
            .navigationTitle(original == nil ? "New Talk" : "Edit Talk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var talk = original ?? Talk(name: "", totalDuration: 0)
                        talk.name = name.trimmingCharacters(in: .whitespaces)
                        talk.totalDuration = totalDuration
                        onSave(talk)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || totalDuration <= 0)
                }
            }
            .onAppear { if original == nil { nameFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }
}
