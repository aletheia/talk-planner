import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The live talk screen, shared by the watch and the iPhone. Tap anywhere to move to the
/// next item; long-press to end early. Haptics come from whichever device is running it.
struct RunningTalkView: View {
    @State private var session: TalkSession
    @State private var confirmingEnd = false
    @State private var showingNotes = true
    @State private var showingTeleprompter = false
    private let notesBlocks: [MarkdownBlock]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase

    private let alerts = AlertScheduler.shared

    init(talk: Talk) {
        _session = State(initialValue: TalkSession(talk: talk))
        notesBlocks = talk.hasNotes ? MarkdownParser.parse(talk.notes) : []
    }

    var body: some View {
        Group {
            if session.phase == .finished {
                TalkSummaryView(session: session) {
                    dismiss()
                }
            } else {
                runningBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard session.phase == .ready else { return }
            session.start()
            alerts.prepare()
            alerts.requestAuthorizationIfNeeded()
            alerts.reschedule(for: session)
            setScreenAwake(true)
            publishWidgetState()
        }
        .onDisappear {
            alerts.cancelAll()
            setScreenAwake(false)
            publishWidgetState()
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the foreground: catch up on any alert the UI missed while suspended.
            if phase == .active { tick(.now) }
        }
    }

    /// Notes visible on the iPhone: the gauges shrink to a fixed band and the notes take the rest.
    private var notesVisible: Bool {
        #if os(iOS)
        return showingNotes && !notesBlocks.isEmpty
        #else
        return false
        #endif
    }

    private var runningBody: some View {
        VStack(spacing: 0) {
            gauges
                .frame(height: notesVisible ? 300 : nil)
            #if os(iOS)
            if notesVisible {
                notesPanel
            }
            #endif
        }
        .navigationTitle("\(session.segmentIndex + 1) of \(session.segments.count)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !notesBlocks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Teleprompter", systemImage: "text.viewfinder") {
                        showingTeleprompter = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showingNotes ? "Hide Notes" : "Show Notes", systemImage: showingNotes ? "doc.text.fill" : "doc.text") {
                        withAnimation { showingNotes.toggle() }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingTeleprompter) {
            TeleprompterView(blocks: notesBlocks, session: session)
        }
        #endif
        .confirmationDialog("End this talk early?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End Talk", role: .destructive) {
                session.finish()
                alerts.cancelAll()
                alerts.playFinished()
                publishWidgetState()
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    /// The rings and timers. Only this area reacts to taps, so scrolling the notes
    /// never advances the talk by accident.
    private var gauges: some View {
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 1.0 : 0.25)) { context in
            RunningContent(session: session, now: context.date)
                .onChange(of: context.date) { _, now in
                    tick(now)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onLongPressGesture(minimumDuration: 0.6) { confirmingEnd = true }
    }

    #if os(iOS)
    /// Speaker notes under the gauges. Jumps to the segment marker (`@[Title]`) or,
    /// failing that, the heading that matches the current item.
    private var notesPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                MarkdownView(blocks: notesBlocks, baseFont: .callout)
                    .padding(16)
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .onAppear { scrollToCurrentItem(proxy, animated: false) }
            .onChange(of: session.segmentIndex) { _, _ in scrollToCurrentItem(proxy, animated: true) }
        }
    }

    private func scrollToCurrentItem(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let id = notesBlocks.headingID(matching: session.currentSegment.title) else { return }
        if animated {
            withAnimation { proxy.scrollTo(id, anchor: .top) }
        } else {
            proxy.scrollTo(id, anchor: .top)
        }
    }
    #endif

    /// A talk on the phone should not be interrupted by auto-lock.
    private func setScreenAwake(_ awake: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = awake
        #endif
    }

    private func tick(_ now: Date) {
        guard session.phase == .running else { return }
        if !session.segmentAlertFired && session.isSegmentOver(at: now) {
            session.segmentAlertFired = true
            alerts.playSegmentEnd()
        }
        if !session.overallAlertFired && session.isOverallOver(at: now) {
            session.overallAlertFired = true
            alerts.playOverallEnd()
        }
    }

    private func advance() {
        guard session.phase == .running else { return }
        let wasLast = session.isLastSegment
        session.advance()
        if wasLast {
            alerts.cancelAll()
            alerts.playFinished()
        } else {
            alerts.playAdvance()
            alerts.reschedule(for: session)
        }
        publishWidgetState()
    }

    /// Mirror the session to the Home Screen widget (iPhone only).
    private func publishWidgetState() {
        #if os(iOS)
        WidgetSessionStore.publish(session)
        #endif
    }
}
