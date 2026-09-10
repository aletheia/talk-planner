import Foundation

/// One agenda item of a talk, with the time the speaker wants to spend on it.
struct TalkSegment: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var duration: TimeInterval

    init(id: UUID = UUID(), title: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

/// A talk: a name, an overall time budget, and the ordered agenda items.
struct Talk: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var totalDuration: TimeInterval
    var segments: [TalkSegment]
    /// Speaker notes or the full script, in Markdown. Shown on the iPhone while presenting.
    var notes: String

    init(id: UUID = UUID(), name: String, totalDuration: TimeInterval, segments: [TalkSegment] = [], notes: String = "") {
        self.id = id
        self.name = name
        self.totalDuration = totalDuration
        self.segments = segments
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, totalDuration, segments, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        totalDuration = try container.decode(TimeInterval.self, forKey: .totalDuration)
        segments = try container.decodeIfPresent([TalkSegment].self, forKey: .segments) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Time already assigned to agenda items.
    var allocatedDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Time left in the budget after the agenda items. Negative when over-allocated.
    var unallocatedDuration: TimeInterval {
        totalDuration - allocatedDuration
    }

    var isOverAllocated: Bool {
        allocatedDuration > totalDuration + 0.5
    }

    /// Segments the watch actually runs. A talk with no agenda runs as a single
    /// segment spanning the whole budget so the two gauges still make sense.
    var runnableSegments: [TalkSegment] {
        segments.isEmpty ? [TalkSegment(title: name, duration: totalDuration)] : segments
    }
}
