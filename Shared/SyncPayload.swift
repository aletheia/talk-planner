import Foundation

/// Wire format shared by the iPhone and the watch over WatchConnectivity.
enum SyncPayload {
    static let talksKey = "talks"
    static let updatedAtKey = "updatedAt"
    static let requestKey = "request"
    static let requestTalks = "talks"

    /// Notes are phone-only: they can be large and the watch never shows them.
    static func encode(_ talks: [Talk]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stripped = talks.map { talk in
            var copy = talk
            copy.notes = ""
            return copy
        }
        return try encoder.encode(stripped)
    }

    static func decode(_ data: Data) throws -> [Talk] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Talk].self, from: data)
    }

    /// Dictionary suitable for `updateApplicationContext` or a message reply.
    static func context(for talks: [Talk]) throws -> [String: Any] {
        [
            talksKey: try encode(talks),
            updatedAtKey: Date(),
        ]
    }

    static func talks(from context: [String: Any]) -> [Talk]? {
        guard let data = context[talksKey] as? Data else { return nil }
        return try? decode(data)
    }
}
