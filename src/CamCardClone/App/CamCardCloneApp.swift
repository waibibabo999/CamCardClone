import SwiftUI

@main
struct CamCardCloneApp: App {
    @State private var store = BusinessCardStore()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
            BusinessCardStore.resetPersistentStore()
        }
        #if DEBUG
        UITestSupport.seedIfNeeded()
        #endif
        _store = State(initialValue: BusinessCardStore())
    }

    var body: some Scene {
        WindowGroup {
            CardHolderView()
                .environment(store)
                // The reference environment is the light appearance captured
                // in references/screenshots/reference.
                .preferredColorScheme(.light)
        }
    }
}
