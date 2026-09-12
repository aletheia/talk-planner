import SwiftUI

/// One block of a Markdown document: heading, paragraph, list item, quote, code or rule.
struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int)
        case paragraph
        case bullet
        case numbered(Int)
        case quote
        case code
        case rule
        /// An explicit segment marker (`@[Title]`) the speaker inserts to split the
        /// script into sections that line up with the agenda items.
        case segmentMarker
    }

    let id: Int
    let kind: Kind
    let text: String

    var isHeading: Bool {
        if case .heading = kind { return true }
        return false
    }

    var isSegmentMarker: Bool {
        kind == .segmentMarker
    }
}

/// Small block-level Markdown parser. Inline styling (bold, italic, code, links)
/// is left to `AttributedString(markdown:)` when each block is rendered.
///
/// In addition to standard Markdown it recognises a segment marker on its own
/// line: `@[Segment Title]`. Speakers drop these into the script to split it into
/// sections that line up with the agenda, keeping the notes and teleprompter in
/// sync with the item they are currently on.
enum MarkdownParser {
    /// The syntax used to mark the start of a segment inside the notes.
    /// A line like `@[Intro]` starts the section for the "Intro" agenda item.
    static func segmentMarker(for title: String) -> String {
        "@[\(title.trimmingCharacters(in: .whitespaces))]"
    }

    /// Parses a segment marker (`@[Title]`) from a trimmed line, if present.
    private static func segmentMarkerText(in line: String) -> String? {
        guard line.hasPrefix("@[") , line.hasSuffix("]") else { return nil }
        let inner = line.dropFirst(2).dropLast()
        let title = inner.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String]?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(MarkdownBlock(id: blocks.count, kind: .paragraph, text: paragraph.joined(separator: " ")))
            paragraph = []
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if let lines = codeLines {
                    blocks.append(MarkdownBlock(id: blocks.count, kind: .code, text: lines.joined(separator: "\n")))
                    codeLines = nil
                } else {
                    flushParagraph()
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines?.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                continue
            }
            if line == "---" || line == "***" || line == "___" {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .rule, text: ""))
                continue
            }
            if let title = segmentMarkerText(in: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .segmentMarker, text: title))
                continue
            }
            if let (level, text) = heading(in: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(level: level), text: text))
                continue
            }
            if let text = prefixed(line, by: ["- ", "* ", "+ "]) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .bullet, text: text))
                continue
            }
            if let (number, text) = numbered(in: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .numbered(number), text: text))
                continue
            }
            if let text = prefixed(line, by: [">"]) {
                flushParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .quote, text: text.trimmingCharacters(in: .whitespaces)))
                continue
            }
            paragraph.append(line)
        }

        if let lines = codeLines {
            blocks.append(MarkdownBlock(id: blocks.count, kind: .code, text: lines.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }

    private static func heading(in line: String) -> (Int, String)? {
        var level = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", level < 6 {
            level += 1
            index = line.index(after: index)
        }
        guard level > 0, index < line.endIndex, line[index] == " " else { return nil }
        return (level, String(line[index...]).trimmingCharacters(in: .whitespaces))
    }

    private static func prefixed(_ line: String, by prefixes: [String]) -> String? {
        for prefix in prefixes where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
        return nil
    }

    private static func numbered(in line: String) -> (Int, String)? {
        guard let dot = line.firstIndex(of: "."), dot != line.startIndex else { return nil }
        let digits = line[..<dot]
        guard digits.allSatisfy(\.isNumber), let number = Int(digits) else { return nil }
        let rest = line[line.index(after: dot)...]
        guard rest.hasPrefix(" ") else { return nil }
        return (number, rest.trimmingCharacters(in: .whitespaces))
    }
}

/// Renders parsed Markdown blocks. Each block carries `.id(block.id)` so a
/// surrounding `ScrollViewReader` can jump to a heading.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]
    var baseFont: Font = .body

    init(blocks: [MarkdownBlock], baseFont: Font = .body) {
        self.blocks = blocks
        self.baseFont = baseFont
    }

    init(markdown: String, baseFont: Font = .body) {
        self.init(blocks: MarkdownParser.parse(markdown), baseFont: baseFont)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                blockView(block)
                    .id(block.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(inline(block.text))
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 6 : 2)
        case .paragraph:
            Text(inline(block.text))
                .font(baseFont)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(baseFont.weight(.bold))
                Text(inline(block.text)).font(baseFont)
            }
            .padding(.leading, 4)
        case .numbered(let number):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).").font(baseFont.monospacedDigit())
                Text(inline(block.text)).font(baseFont)
            }
            .padding(.leading, 4)
        case .quote:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                Text(inline(block.text))
                    .font(baseFont.italic())
                    .foregroundStyle(.secondary)
            }
        case .code:
            Text(block.text)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        case .rule:
            Divider()
        case .segmentMarker:
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                Text(block.text)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .padding(.top, 6)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.semibold)
        default: return .headline
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

extension Array where Element == MarkdownBlock {
    /// The block to scroll to for the given agenda item. An explicit segment marker
    /// (`@[Title]`) wins; otherwise we fall back to the first heading whose text
    /// contains the title (case-insensitive). Used to jump the notes / teleprompter
    /// to the item being presented.
    func anchorID(matching title: String) -> Int? {
        let needle = title.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        if let marker = first(where: { $0.isSegmentMarker && $0.text.lowercased() == needle })?.id {
            return marker
        }
        if let marker = first(where: { $0.isSegmentMarker && $0.text.lowercased().contains(needle) })?.id {
            return marker
        }
        return first { $0.isHeading && $0.text.lowercased().contains(needle) }?.id
    }

    /// Kept for source compatibility; segment markers now take priority over headings.
    func headingID(matching title: String) -> Int? {
        anchorID(matching: title)
    }

    /// True when the speaker has placed any explicit `@[...]` segment markers.
    var hasSegmentMarkers: Bool {
        contains { $0.isSegmentMarker }
    }
}
