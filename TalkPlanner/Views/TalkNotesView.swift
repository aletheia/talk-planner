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
    @State private var editorFocused = false
    /// A pending text insertion for the caret-aware editor.
    @State private var insertRequest: String?

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
                VStack(spacing: 0) {
                    MarkdownTextEditor(
                        text: $draft,
                        insertRequest: $insertRequest,
                        isFocused: editorFocused,
                        onFocusChange: { editorFocused = $0 }
                    )
                    .padding(.horizontal, 8)
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text("Paste your talk or notes here in Markdown.\n\nTip: split the script with a segment marker like `@[Intro]` on its own line. Use “Insert Section” below to drop a marker for an agenda item at the cursor. While you present, the notes and teleprompter jump to that marker when you reach the matching item.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 17)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    if let talk, !talk.segments.isEmpty {
                        insertSectionBar(for: talk)
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
                        Button("Append All Markers", systemImage: "flag") { insertSegmentMarkers(for: talk) }
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

    /// A bar under the editor letting the speaker drop a marker for a chosen
    /// agenda item exactly where the cursor is.
    @ViewBuilder
    private func insertSectionBar(for talk: Talk) -> some View {
        Divider()
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Insert section:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(Array(talk.segments.enumerated()), id: \.element.id) { index, segment in
                    let title = segment.title.trimmingCharacters(in: .whitespaces)
                    let placed = markerIsPlaced(title)
                    Button {
                        insertSection(title)
                    } label: {
                        Label(title.isEmpty ? "Item \(index + 1)" : title,
                              systemImage: placed ? "checkmark.circle.fill" : "flag")
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(placed ? .secondary : .accentColor)
                    .disabled(title.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func markerIsPlaced(_ title: String) -> Bool {
        guard !title.isEmpty else { return false }
        return MarkdownParser.parse(draft)
            .contains { $0.isSegmentMarker && $0.text.lowercased() == title.lowercased() }
    }

    /// Requests inserting a marker for `title` at the caret, on its own line.
    private func insertSection(_ title: String) {
        guard !title.isEmpty else { return }
        let marker = MarkdownParser.segmentMarker(for: title)
        // Surround the marker with blank lines so it always parses as its own block.
        insertRequest = "\n\(marker)\n\n"
        editorFocused = true
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
