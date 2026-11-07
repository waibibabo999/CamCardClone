import SwiftUI

/// 全局 UI 常量。字体、间距、圆角、颜色统一走这里，不允许散落魔法数字。
enum Theme {
    /// CamCard's primary blue is a bright sky blue, not the darker system blue.
    static let accent = Color(red: 20 / 255, green: 181 / 255, blue: 1)
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let destructive = Color(.systemRed)

    static let cornerRadius: CGFloat = 12
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 16
}
