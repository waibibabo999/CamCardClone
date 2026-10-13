import SwiftUI

struct CardHolderView: View {
    @Environment(BusinessCardStore.self) private var store

    var body: some View {
        NavigationStack {
            CardHolderScreen(store: store)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .scanner:
                        ScannerView()
                    case .search:
                        SearchPlaceholderView()
                    case .tags:
                        TagsPlaceholderView()
                    case .detail(let id):
                        DetailPlaceholderView(cardID: id)
                    }
                }
        }
    }
}

private struct CardHolderScreen: View {
    @State private var viewModel: CardHolderViewModel

    @MainActor
    init(store: BusinessCardStore) {
        _viewModel = State(initialValue: CardHolderViewModel(store: store))
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                cardList
            }
        }
        .navigationTitle("名片夹")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: AppRoute.search) {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.tags) {
                    Image(systemName: "tag")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("暂无名片")
                .font(.headline)
            Text("拍摄或导入你的第一张名片")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            NavigationLink(value: AppRoute.scanner) {
                Label("扫描名片", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)
            .padding(.top, 8)
        }
        .padding()
    }

    private var cardList: some View {
        List {
            ForEach(viewModel.cards) { card in
                NavigationLink(value: AppRoute.detail(card.id)) {
                    CardRow(card: card)
                }
            }
            .onDelete { offsets in
                let doomed = offsets.map { viewModel.cards[$0] }
                doomed.forEach { viewModel.delete($0) }
            }
        }
    }
}

private struct CardRow: View {
    let card: BusinessCard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name ?? "未命名名片")
                .font(.headline)
            if let company = card.company, !company.isEmpty {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if !card.tags.isEmpty {
                Text(card.tags.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
