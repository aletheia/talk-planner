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
                            Text("Paste your talk or notes here in Markdown.\n\nTip: use a heading that matches each agenda item (for example `## Intro`) and the notes will jump to it while you present.")
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
                Menu {
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
}
