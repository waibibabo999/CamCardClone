import SwiftUI

struct TagsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("标签", systemImage: "tag", description: Text("标签管理在批次 D 实现"))
            .navigationTitle("标签")
    }
}
