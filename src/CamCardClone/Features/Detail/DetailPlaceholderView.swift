import SwiftUI

struct DetailPlaceholderView: View {
    let cardID: UUID

    var body: some View {
        VStack(spacing: Theme.spacing) {
            Text("名片详情")
                .font(.title2.bold())
            Text("详情页在批次 D 实现\nID: \(cardID.uuidString)")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("名片详情")
    }
}
