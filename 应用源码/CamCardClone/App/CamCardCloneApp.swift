import SwiftUI

@main
struct CamCardCloneApp: App {
    private static let cleanStartKey = "didClearLegacyCardData_20261108"

    @State private var store = BusinessCardStore()

    init() {
        // 覆盖安装时清掉旧版本留下的演示名片和分组；清理只执行一次。
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.cleanStartKey) {
            BusinessCardStore.resetPersistentStore()
            defaults.set(true, forKey: Self.cleanStartKey)
        }

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
                // 应用统一使用浅色外观。
                .preferredColorScheme(.light)
        }
    }
}
