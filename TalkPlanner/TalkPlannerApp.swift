import SwiftUI

@main
struct TalkPlannerApp: App {
    @State private var store: TalkStore
    @State private var connectivity: PhoneConnectivity

    init() {
        let store = TalkStore()
        let connectivity = PhoneConnectivity()
        connectivity.talksProvider = { [weak store] in store?.talks ?? [] }
        store.onChange = { [weak connectivity] talks in connectivity?.send(talks) }
        _store = State(initialValue: store)
        _connectivity = State(initialValue: connectivity)
        AlertScheduler.shared.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            TalkListView()
                .environment(store)
                .environment(connectivity)
        }
    }
}
