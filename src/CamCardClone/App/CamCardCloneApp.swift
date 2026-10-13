import SwiftUI

@main
struct CamCardCloneApp: App {
    @State private var store = BusinessCardStore()

    var body: some Scene {
        WindowGroup {
            CardHolderView()
                .environment(store)
        }
    }
}
