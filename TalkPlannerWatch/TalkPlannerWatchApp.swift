import SwiftUI

@main
struct TalkPlannerWatchApp: App {
    @State private var store: TalkStore
    @State private var connectivity: WatchConnectivityController

    init() {
        let store = TalkStore()
        _store = State(initialValue: store)
        _connectivity = State(initialValue: WatchConnectivityController(store: store))
        AlertScheduler.shared.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchTalkListView()
            }
            .environment(store)
            .environment(connectivity)
        }
    }
}
