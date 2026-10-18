import SwiftUI

struct TagManagementView: View {
    @Environment(BusinessCardStore.self) private var store
    @State private var newTag = ""
    @State private var showAddTag = false

    var body: some View {
        List {
            if store.tags.isEmpty {
                Text("还没有标签。创建标签后，可以在编辑名片时勾选。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(store.tags) { tag in
                    NavigationLink {
                        TagResultsView(tag: tag.name)
                    } label: {
                        HStack {
                            Label(tag.name, systemImage: "tag")
                            Spacer()
                            Text("\(store.filter(tag: tag.name).count)")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            try? store.deleteTag(tag.name)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("标签")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addTagButton")
            }
        }
        .alert("新建标签", isPresented: $showAddTag) {
            TextField("标签名称", text: $newTag)
            Button("创建") {
                let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    try? store.addTag(trimmed)
                }
                newTag = ""
            }
            Button("取消", role: .cancel) { newTag = "" }
        } message: {
            Text("例如：会议、教授、客户")
        }
    }
}

struct TagResultsView: View {
    @Environment(BusinessCardStore.self) private var store
    let tag: String

    private var cards: [BusinessCard] {
        store.filter(tag: tag).sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView("没有名片", systemImage: "tag", description: Text("这个标签下还没有名片"))
            } else {
                List(cards) { card in
                    NavigationLink(value: AppRoute.detail(card.id)) {
                        CardRowView(card: card)
                    }
                }
            }
        }
        .navigationTitle(tag)
    }
}
