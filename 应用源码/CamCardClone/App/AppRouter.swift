import Foundation

/// 全局路由。导航统一走 NavigationStack + navigationDestination。
enum AppRoute: Hashable {
    case scanner
    case search
    case tags
    case detail(UUID)
}
