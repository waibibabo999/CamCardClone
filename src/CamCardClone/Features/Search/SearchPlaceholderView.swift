import SwiftUI

struct SearchPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("搜索", systemImage: "magnifyingglass", description: Text("搜索功能在批次 D 实现"))
            .navigationTitle("搜索")
    }
}
