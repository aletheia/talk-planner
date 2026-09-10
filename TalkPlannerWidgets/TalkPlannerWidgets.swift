import SwiftUI
import WidgetKit

@main
struct TalkPlannerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TalkProgressWidget()
    }
}

struct TalkProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.lucabianchi.TalkPlanner.talk-progress", provider: TalkTimelineProvider()) { entry in
            TalkProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .configurationDisplayName("Talk Progress")
        .description("Remaining time for the whole talk and for the current agenda item.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Timeline

struct TalkEntry: TimelineEntry {
    let date: Date
    let state: WidgetSessionState?
}

/// The widget never polls: the app reloads it whenever the session changes. The
/// timeline only carries the instants at which colours flip (last 30 s, overtime).
struct TalkTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TalkEntry {
        TalkEntry(date: .now, state: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TalkEntry) -> Void) {
        let state = context.isPreview ? WidgetSessionState.preview : WidgetSessionStore.load()
        completion(TalkEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TalkEntry>) -> Void) {
        let now = Date()
        guard let state = WidgetSessionStore.load(at: now) else {
            completion(Timeline(entries: [TalkEntry(date: now, state: nil)], policy: .never))
            return
        }
        var dates: Set<Date> = [now]
        for end in [state.segmentEndDate, state.overallEndDate] {
            for offset in [-30.0, 0.0] {
                let date = end.addingTimeInterval(offset)
                if date > now { dates.insert(date) }
            }
        }
        let entries = dates.sorted().map { TalkEntry(date: $0, state: state) }
        // Ask again a while after the talk should be over, so a stale file eventually clears.
        completion(Timeline(entries: entries, policy: .after(state.overallEndDate.addingTimeInterval(3 * 3600))))
    }
}

// MARK: - Colours

extension WidgetSessionState {
    func segmentTint(at date: Date) -> Color {
        if date >= segmentEndDate { return .red }
        if segmentEndDate.timeIntervalSince(date) <= 30 { return .orange }
        return .green
    }

    func overallTint(at date: Date) -> Color {
        if date >= overallEndDate { return .red }
        if overallEndDate.timeIntervalSince(date) <= 30 { return .orange }
        return .blue
    }

    func isSegmentOver(at date: Date) -> Bool { date >= segmentEndDate }
    func isOverallOver(at date: Date) -> Bool { date >= overallEndDate }
}

// MARK: - Views

struct TalkProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TalkEntry

    var body: some View {
        if let state = entry.state {
            switch family {
            case .systemMedium:
                MediumTalkView(state: state, at: entry.date)
            case .accessoryCircular:
                CircularAccessoryView(state: state, at: entry.date)
            case .accessoryRectangular:
                RectangularAccessoryView(state: state, at: entry.date)
            default:
                SmallTalkView(state: state, at: entry.date)
            }
        } else {
            IdleView(family: family)
        }
    }
}

/// Two nested live rings. `countsDown` makes them deplete like the app's gauges.
private struct LiveRings: View {
    let state: WidgetSessionState
    let at: Date
    var ringInset: CGFloat = 14

    var body: some View {
        ZStack {
            ProgressView(timerInterval: state.overallInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.circular)
                .tint(state.overallTint(at: at))
            ProgressView(timerInterval: state.segmentInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.circular)
                .tint(state.segmentTint(at: at))
                .padding(ringInset)
        }
    }
}

/// Remaining time that keeps ticking on its own. Counts up once the end passes.
private struct LiveTimer: View {
    let end: Date
    let at: Date
    var font: Font

    var body: some View {
        Text(end, style: .timer)
            .font(font)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(at >= end ? Color.red : Color.primary)
    }
}

private struct SmallTalkView: View {
    let state: WidgetSessionState
    let at: Date

    var body: some View {
        VStack(spacing: 4) {
            Text(state.segmentTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ZStack {
                LiveRings(state: state, at: at, ringInset: 12)
                VStack(spacing: -2) {
                    LiveTimer(end: state.segmentEndDate, at: at, font: .system(size: 22, weight: .semibold, design: .rounded))
                    LiveTimer(end: state.overallEndDate, at: at, font: .system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
            }
            Text(state.isSegmentOver(at: at) ? "Tap for next" : "\(state.segmentIndex + 1) of \(state.segmentCount)")
                .font(.caption2)
                .foregroundStyle(state.isSegmentOver(at: at) ? .red : .secondary)
        }
    }
}

private struct MediumTalkView: View {
    let state: WidgetSessionState
    let at: Date

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LiveRings(state: state, at: at, ringInset: 13)
                LiveTimer(end: state.segmentEndDate, at: at, font: .system(size: 22, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 30)
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.talkName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(state.segmentTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text("Item \(state.segmentIndex + 1) of \(state.segmentCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if state.isSegmentOver(at: at) {
                    Label("Tap for next item", systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                } else if let next = state.nextSegmentTitle {
                    Text("Next: \(next)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Last item")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text("Talk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(state.overallEndDate, style: .timer)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverallOver(at: at) ? .red : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CircularAccessoryView: View {
    let state: WidgetSessionState
    let at: Date

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ProgressView(timerInterval: state.segmentInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.circular)
            Text(state.segmentEndDate, style: .timer)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 10)
        }
        .widgetAccentable()
    }
}

private struct RectangularAccessoryView: View {
    let state: WidgetSessionState
    let at: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.segmentTitle)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            HStack(spacing: 6) {
                ProgressView(timerInterval: state.segmentInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                Text(state.segmentEndDate, style: .timer)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: 6) {
                ProgressView(timerInterval: state.overallInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                Text(state.overallEndDate, style: .timer)
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

private struct IdleView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "timer")
                    .font(.title3)
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Talk Planner", systemImage: "timer")
                    .font(.headline)
                    .widgetAccentable()
                Text("No talk running")
                    .font(.caption)
            }
        default:
            VStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No talk running")
                    .font(.caption.weight(.semibold))
                Text("Start one in Talk Planner")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    TalkProgressWidget()
} timeline: {
    TalkEntry(date: .now, state: .preview)
    TalkEntry(date: .now, state: nil)
}

#Preview("Medium", as: .systemMedium) {
    TalkProgressWidget()
} timeline: {
    TalkEntry(date: .now, state: .preview)
}
