import Foundation
import Observation

/// Persists the list of talks as JSON in Application Support.
/// Both the iPhone and the watch use it; the phone is the editor, the watch a mirror.
@Observable
final class TalkStore {
    private(set) var talks: [Talk] = []

    /// Called after every local edit. The iPhone app uses it to push to the watch.
    var onChange: (([Talk]) -> Void)?

    private let fileURL: URL

    init(fileURL: URL = TalkStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("talks.json")
    }

    // MARK: - Queries

    func talk(id: UUID) -> Talk? {
        talks.first { $0.id == id }
    }

    // MARK: - Local edits (notify listeners)

    func add(_ talk: Talk) {
        talks.append(talk)
        persist(notify: true)
    }

    func update(_ talk: Talk) {
        guard let index = talks.firstIndex(where: { $0.id == talk.id }) else { return }
        talks[index] = talk
        persist(notify: true)
    }

    func delete(at offsets: IndexSet) {
        talks.remove(atOffsets: offsets)
        persist(notify: true)
    }

    func move(from source: IndexSet, to destination: Int) {
        talks.move(fromOffsets: source, toOffset: destination)
        persist(notify: true)
    }

    // MARK: - Remote replacement (watch receiving from phone)

    /// Replaces the whole list without triggering `onChange`, so a mirror
    /// never echoes data back to its source.
    func replaceAll(_ newTalks: [Talk]) {
        guard newTalks != talks else { return }
        talks = newTalks
        persist(notify: false)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        talks = (try? decoder.decode([Talk].self, from: data)) ?? []
    }

    private func persist(notify: Bool) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(talks) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if notify {
            onChange?(talks)
        }
    }
}
