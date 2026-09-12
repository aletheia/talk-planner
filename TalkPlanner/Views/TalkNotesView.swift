import SwiftUI
import UniformTypeIdentifiers

/// Markdown notes for a talk: paste or type them, or import a .md / .txt file.
struct TalkNotesView: View {
    @Environment(TalkStore.self) private var store
    let talkID: UUID

    private enum Mode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case preview = "Preview"
        var id: String { rawValue }
    }

    @State private var draft: String = ""
    @State private var loaded = false
    @State private var mode: Mode = .edit
    @State private var importing = false
    @State private var importError: String?
    @State private var confirmClear = false
    @State private var showingTeleprompter = false
    @FocusState private var editorFocused: Bool

    private var talk: Talk? { store.talk(id: talkID) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch mode {
            case .edit:
                TextEditor(text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text("Paste your talk or notes here in Markdown.\n\nTip: split the script with a segment marker like `@[Intro]` on its own line. While you present, the notes and teleprompter jump to that marker when you reach the matching agenda item.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 17)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
            case .preview:
                ScrollView {
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("Nothing to preview", systemImage: "doc.text")
                            .padding(.top, 40)
                    } else {
                        MarkdownView(markdown: draft)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Teleprompter", systemImage: "text.viewfinder") { showingTeleprompter = true }
                }
                Menu {
                    if let talk, !talk.segments.isEmpty {
                        Button("Insert Segment Markers", systemImage: "flag") { insertSegmentMarkers(for: talk) }
                    }
                    Button("Import Markdown File", systemImage: "square.and.arrow.down") { importing = true }
                    if !draft.isEmpty {
                        Button("Clear Notes", systemImage: "trash", role: .destructive) { confirmClear = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                if editorFocused {
                    Button("Done") { editorFocused = false }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog("Clear all notes?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear Notes", role: .destructive) { draft = "" }
        }
        .fullScreenCover(isPresented: $showingTeleprompter) {
            TeleprompterView(markdown: draft)
        }
        .onAppear {
            guard !loaded, let talk else { return }
            draft = talk.notes
            loaded = true
        }
        .onChange(of: draft) { _, newValue in
            save(newValue)
        }
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let markdown = UTType("net.daringfireball.markdown") { types.append(markdown) }
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdownExt = UTType(filenameExtension: "markdown") { types.append(markdownExt) }
        return types
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                    importError = "The file is not readable text."
                    return
                }
                draft = text
                mode = .preview
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func save(_ notes: String) {
        guard var talk, talk.notes != notes else { return }
        talk.notes = notes
        store.update(talk)
    }

    /// Adds a `@[Title]` marker for any agenda item that doesn't already have one,
    /// so the speaker can move the generated markers to the right spot in the script.
    private func insertSegmentMarkers(for talk: Talk) {
        let existing = MarkdownParser.parse(draft)
        let present = Set(existing.filter(\.isSegmentMarker).map { $0.text.lowercased() })
        let missing = talk.segments
            .map { $0.title.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !present.contains($0.lowercased()) }
        guard !missing.isEmpty else { return }

        let markers = missing.map { MarkdownParser.segmentMarker(for: $0) }.joined(separator: "\n\n")
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = markers + "\n"
        } else {
            let separator = draft.hasSuffix("\n") ? "\n" : "\n\n"
            draft += separator + markers + "\n"
        }
    }
}
