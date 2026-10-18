import SwiftUI

struct SearchView: View {
    @Environment(BusinessCardStore.self) private var store
    @State private var query = ""

    private var results: [BusinessCard] {
        store.search(keyword: query)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "暂无名片" : "没有找到结果",
                    systemImage: "magnifyingglass",
                    description: Text(query.isEmpty ? "保存名片后即可搜索" : "试试姓名、公司、职位、电话或邮箱")
                )
            } else {
                List(results) { card in
                    NavigationLink(value: AppRoute.detail(card.id)) {
                        CardRowView(card: card)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "姓名、公司、职位、电话、邮箱")
        .navigationTitle("搜索")
    }
}
