#if os(iOS)
import SwiftUI
import UIKit

/// A full-screen, auto-scrolling teleprompter for the talk script.
///
/// The text scrolls upward at an adjustable speed. Tap to play/pause, use the
/// controls to change speed and text size, or mirror the text for a beam-splitter
/// rig. When driven by a live `TalkSession`, the prompter jumps to the segment
/// marker (`@[Title]`) for the item currently being presented, so it stays on
/// track with the running talk.
struct TeleprompterView: View {
    private let blocks: [MarkdownBlock]
    /// Optional live session: when present, the prompter follows the current segment.
    private var session: TalkSession?

    @Environment(\.dismiss) private var dismiss

    @State private var running = false
    @State private var speed: Double = 30          // points per second
    @State private var fontSize: Double = 34
    @State private var mirrored = false
    @State private var controlsVisible = true
    @State private var offset: Double = 0
    @State private var contentHeight: Double = 0
    @State private var viewportHeight: Double = 0
    @State private var lastTick: Date?
    @State private var dragStartOffset: Double?
    /// Measured vertical position of each block (by block id) within the text column.
    @State private var blockOffsets: [Int: Double] = [:]

    init(markdown: String, session: TalkSession? = nil) {
        self.blocks = MarkdownParser.parse(markdown)
        self.session = session
    }

    init(blocks: [MarkdownBlock], session: TalkSession? = nil) {
        self.blocks = blocks
        self.session = session
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            scroller
                .ignoresSafeArea(edges: .horizontal)

            // Reading guide: a subtle band near the top marks where to read.
            VStack {
                Spacer().frame(height: 90)
                Rectangle()
                    .fill(Color.yellow.opacity(0.25))
                    .frame(height: 3)
                Spacer()
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()

            if controlsVisible {
                controls
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { toggleRunning() }
        .onLongPressGesture(minimumDuration: 0.4) {
            withAnimation { controlsVisible.toggle() }
        }
        .onAppear { setScreenAwake(true) }
        .onDisappear { setScreenAwake(false) }
        .onChange(of: session?.segmentIndex) { _, _ in jumpToCurrentSegment() }
    }

    private var scroller: some View {
        // A TimelineView drives the scroll while running; the text is a single
        // clipped column that we move up manually, so speed changes and segment
        // jumps stay under our control (no fighting a ScrollView's own offset).
        TimelineView(.animation(paused: !running)) { context in
            GeometryReader { geo in
                textColumn
                    .coordinateSpace(name: columnSpace)
                    .onPreferenceChange(BlockOffsetKey.self) { blockOffsets = $0 }
                    .padding(.top, 90)
                    .offset(y: -offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .highPriorityGesture(dragToScrub)
                    .clipped()
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                    .onAppear { viewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in viewportHeight = h }
                    .onChange(of: context.date) { _, now in advance(to: now) }
            }
        }
    }

    private let columnSpace = "teleprompterColumn"

    /// The script laid out as a single column, measuring each block's vertical
    /// position so segment jumps can land on the exact marker.
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                MarkdownView(blocks: [block], baseFont: .system(size: fontSize, weight: .medium))
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: BlockOffsetKey.self,
                                value: [block.id: proxy.frame(in: .named(columnSpace)).minY]
                            )
                        }
                    )
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { inner in
                Color.clear
                    .onChange(of: inner.size.height) { _, h in contentHeight = h }
                    .onAppear { contentHeight = inner.size.height }
            }
        )
    }

    /// Drag up/down to scrub through the script by hand.
    private var dragToScrub: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let base = dragStartOffset ?? offset
                if dragStartOffset == nil { dragStartOffset = base }
                let maxOffset = max(0, contentHeight - viewportHeight * 0.5)
                offset = min(maxOffset, max(0, base - value.translation.height))
            }
            .onEnded { _ in dragStartOffset = nil }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                Spacer()
                Button {
                    toggleRunning()
                } label: {
                    Image(systemName: running ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 46))
                }
                Spacer()
                Button {
                    reset()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "tortoise.fill")
                Slider(value: $speed, in: 8...120)
                Image(systemName: "hare.fill")
            }
            .font(.footnote)

            HStack(spacing: 10) {
                Image(systemName: "textformat.size.smaller")
                Slider(value: $fontSize, in: 18...72)
                Image(systemName: "textformat.size.larger")
            }
            .font(.footnote)

            HStack {
                Toggle(isOn: $mirrored) {
                    Label("Mirror", systemImage: "flip.horizontal")
                }
                .toggleStyle(.button)
                .font(.footnote)
                Spacer()
                Text("\(Int(speed)) pt/s")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .tint(.yellow)
    }

    // MARK: - Scrolling

    private func toggleRunning() {
        running.toggle()
        lastTick = running ? .now : nil
    }

    private func advance(to now: Date) {
        guard running else { lastTick = now; return }
        defer { lastTick = now }
        guard let last = lastTick else { return }
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else { return }
        let maxOffset = max(0, contentHeight - viewportHeight)
        offset = min(maxOffset, offset + dt * speed)
        if offset >= maxOffset {
            running = false
        }
    }

    private func reset() {
        withAnimation { offset = 0 }
        running = false
        lastTick = nil
    }

    /// Snap the prompter to the marker for the segment being presented.
    private func jumpToCurrentSegment() {
        guard let session else { return }
        guard let id = blocks.anchorID(matching: session.currentSegment.title) else { return }
        let maxOffset = max(0, contentHeight - viewportHeight)
        let target: Double
        if let measured = blockOffsets[id] {
            // Bring the marker just below the reading guide (90pt from the top).
            target = max(0, measured)
        } else if let index = blocks.firstIndex(where: { $0.id == id }), !blocks.isEmpty {
            // Fallback before measurements arrive: estimate from ordinal position.
            target = Double(index) / Double(blocks.count) * contentHeight
        } else {
            return
        }
        withAnimation { offset = min(maxOffset, target) }
    }

    private func setScreenAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}

/// Collects each block's measured Y position within the scrolling column.
private struct BlockOffsetKey: PreferenceKey {
    static let defaultValue: [Int: Double] = [:]
    static func reduce(value: inout [Int: Double], nextValue: () -> [Int: Double]) {
        value.merge(nextValue()) { _, new in new }
    }
}
#endif
