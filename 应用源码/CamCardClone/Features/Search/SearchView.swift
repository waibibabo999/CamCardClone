import SwiftUI

struct SearchView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: [BusinessCard] {
        store.search(keyword: query)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("请输入姓名/公司/职位搜索", text: $query)
                        .focused($searchFocused)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .accessibilityAddTraits(.isSearchField)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 10)

            Divider()

            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "暂无名片" : "没有找到结果",
                    systemImage: "magnifyingglass",
                    description: Text(query.isEmpty ? "保存名片后即可搜索" : "试试姓名、公司、职位、电话或邮箱")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { card in
                    NavigationLink(value: AppRoute.detail(card.id)) {
                        CardRowView(card: card)
                    }
                }
            }
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
    }
}
